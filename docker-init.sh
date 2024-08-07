#!/bin/bash

# Set default values for SERIAL_INPUT components
export USB_PORT="${USB_PORT:-ttyUSB0}"
export BAUD_RATE="${BAUD_RATE:-115200}"
export DATA_BITS="${DATA_BITS:-8}"
export PARITY="${PARITY:-n}"
export STOP_BITS="${STOP_BITS:-1}"
export RTCM_MSGS="${RTCM_MSGS:-\"1005(30),1006(30),1007(30),1019,1033(30),1042,1044,1045,1046,1077(1),1087(1),1097(1),1107(1),1117(1),1127(1),1137(1),1230(1)\"}"
export TCP_OUTPUT_PORT="${TCP_OUTPUT_PORT:-5015}"
export TCP_INPUT_PORT="${TCP_INPUT_PORT}"
export TCP_INPUT_IP="${TCP_INPUT_IP}"
export TCP_SERVER_SETUP_SUCCESSFUL="${TCP_SERVER_SETUP_SUCCESSFUL:-0}"
export ONOCOY_USE_SSL="${ONOCOY_USE_SSL:-true}"
export ONOCOY_USE_NTRIPSERVER="${ONOCOY_USE_NTRIPSERVER:-true}"
export RTKDIRECT_USE_NTRIPSERVER="${RTKDIRECT_USE_NTRIPSERVER:-true}"

# Construct SERIAL_INPUT using individual components only if TCP input is not use as a source
if [ -z "$TCP_INPUT_PORT" ] && [ -z "$TCP_INPUT_IP" ]; then
    export SERIAL_INPUT="serial://ttyS0fake0:${BAUD_RATE}:${DATA_BITS}:${PARITY}:${STOP_BITS}"
    export SERIAL_INPUT2="serial://ttyS0fake1:${BAUD_RATE}:${DATA_BITS}:${PARITY}:${STOP_BITS}"
    export SERIAL_INPUT3="serial://ttyS0fake2:${BAUD_RATE}:${DATA_BITS}:${PARITY}:${STOP_BITS}"
fi

# Exit immediately if a command fails
set -e

# Function to run a command and restart it if it fails
run_and_retry() {
    while true; do
        if "$@"; then
            echo "$@ ended successfully - monitoring for restart." >&2
        else
            echo "$@ crashed with exit code $?. Respawning.." >&2
        fi
        sleep 1
    done
}

# Function to handle errors
handle_error() {
    echo "Error occurred: $1"
    exit 1
}

# Function to set up virtual serial bus and devices using socat
setup_virtual_devices() {
    local bus_path="/tmp/ttyS0mux"
    local real_device="/dev/${USB_PORT}"
    local fake_devices=("/dev/ttyS0fake0" "/dev/ttyS0fake1" "/dev/ttyS0fake2")

    echo "Setting up virtual serial bus and devices using socat..."

    # Remove any existing socket file
    if [ -e "${bus_path}" ]; then
        echo "Removing existing socket file ${bus_path}"
        rm -f ${bus_path}
    fi

    # 1. Start the socat-mux.sh script to create a UNIX domain socket listener
    echo "Starting socat-mux.sh..."
    socat-mux.sh -d -d UNIX-L:${bus_path},fork FILE:${real_device},raw,echo=0 &> /dev/null &
    mux_pid=$!
    sleep 2  # Initial wait for the mux to set up the socket

    # Check if socat-mux.sh is running and if the socket file was created
    if kill -0 $mux_pid 2>/dev/null && [ -S ${bus_path} ]; then
        echo "socat-mux.sh started successfully."
    else
        handle_error "Failed to start socat-mux.sh."
    fi

    # 2. Create fake devices attached to the bus using socat
    for fake_device in "${fake_devices[@]}"; do
        echo "Creating fake device ${fake_device}..."
        socat -d -d PTY,raw,echo=0,link=${fake_device} UNIX:${bus_path} &> /dev/null &
        if [ $? -ne 0 ]; then
            handle_error "Failed to create ${fake_device}."
        else
            echo "${fake_device} created successfully."
        fi
    done

    echo "Virtual devices created: ${fake_devices[*]}"
    ls -la ${fake_devices[@]}
}

# Check if LAT, LONG, and ELEVATION are specified
if [ -n "$LAT" ] && [ -n "$LONG" ] && [ -n "$ELEVATION" ]; then
    LAT_LONG_ELEVATION="-p \"$LAT $LONG $ELEVATION\""
    echo "LAT LOG ELEVATION: $LAT_LONG_ELEVATION"
fi

# Check if INSTRUMENT is specified
if [ -n "$INSTRUMENT" ]; then
    INSTRUMENT="-i \"$INSTRUMENT\""
    echo "INSTRUMENT: $INSTRUMENT"
fi

# Check if ANTENNA is specified
if [ -n "$ANTENNA" ]; then
    ANTENNA="-a \"$ANTENNA\""
    echo "ANTENNA: $ANTENNA"
fi

# Function for running the second command
run_onocoy_server() {
    # Fix legacy containers password to new onocoy_password var
    if [ -n "$PASSWORD" ] && [ -z "$ONOCOY_PASSWORD" ]; then
        ONOCOY_PASSWORD=$PASSWORD
    fi
    if [ -n "$ONOCOY_PASSWORD" ] && [ -n "$ONOCOY_USERNAME" ]; then
        echo "ONOCOY_USERNAME: $ONOCOY_PASSWORD"
        echo "ONOCOY_USERNAME: $ONOCOY_USERNAME"
        if [ -n "$ONOCOY_MOUNTPOINT" ] || [ "$ONOCOY_USE_NTRIPSERVER" = true ]; then
            sleep 1
            echo "ONOCOY_MOUNTPOINT: $ONOCOY_MOUNTPOINT"
            echo "STARTING NTRIPSERVER ONOCOY NTRIPv2 SERVER...."
            if [ "$ONOCOY_USE_SSL" = true ]; then
                stunnel /etc/stunnel/stunnel.conf &
                run_and_retry eval $NTRIPSERVERINPUT1 -O 1 -a "127.0.0.1" -p "2101" -m "$ONOCOY_MOUNTPOINT" -n "$ONOCOY_USERNAME" -c "$ONOCOY_PASSWORD" -R 5 &
            else
                run_and_retry eval $NTRIPSERVERINPUT1 -O 1 -a "servers.onocoy.com" -p "2101" -m "$ONOCOY_MOUNTPOINT" -n "$ONOCOY_USERNAME" -c "$ONOCOY_PASSWORD" -R 5 &
            fi
        else
            echo "STARTING RTKLIB ONOCOY NTRIPv1 SERVER...."
            if [ "$ONOCOY_USE_SSL" = true ]; then
                stunnel /etc/stunnel/stunnel.conf &
                run_and_retry eval $STR2STRINPUT1 -out "ntrips://:${ONOCOY_PASSWORD}@127.0.0.1:2101/${ONOCOY_USERNAME}#rtcm3" -msg "$RTCM_MSGS" $LAT_LONG_ELEVATION $INSTRUMENT $ANTENNA -b 0 -t 5 -s 30000 -r 30000 -n 1 &
            else
                run_and_retry eval $STR2STRINPUT1 -out "ntrips://:${ONOCOY_PASSWORD}@servers.onocoy.com:2101/${ONOCOY_USERNAME}#rtcm3" -msg "$RTCM_MSGS" $LAT_LONG_ELEVATION $INSTRUMENT $ANTENNA -b 0 -t 5 -s 30000 -r 30000 -n 1 &
            fi
        fi
    fi
}

# Function for running the third command
run_rtkdirect_server() {
    if [ -n "$RTKDIRECT_PASSWORD" ] && [ -n "$RTKDIRECT_USERNAME" ] && [ -n "$RTKDIRECT_MOUNTPOINT" ]; then
        echo "RTKDIRECT_PASSWORD: $RTKDIRECT_PASSWORD"
        echo "RTKDIRECT_USERNAME: $RTKDIRECT_USERNAME"
        echo "RTKDIRECT_MOUNTPOINT: $RTKDIRECT_MOUNTPOINT"
        if [ "$RTKDIRECT_USE_NTRIPSERVER" = true ]; then
            sleep 1
            echo "STARTING NTRIPSERVER RTKDIRECT NTRIPv2 SERVER...."
            run_and_retry eval $NTRIPSERVERINPUT2 -O 1 -a "ntrip.rtkdirect.com" -p "2101" -m "$RTKDIRECT_MOUNTPOINT" -n "$RTKDIRECT_USERNAME" -c "$RTKDIRECT_PASSWORD" -R 5 &
        else
            echo "STARTING RTKLIB RTKDIRECT NTRIPv1 SERVER...."
            run_and_retry eval $STR2STRINPUT2 -out "ntrips://${RTKDIRECT_USERNAME}:${RTKDIRECT_PASSWORD}@ntrip.rtkdirect.com:2101/${RTKDIRECT_MOUNTPOINT}#rtcm3" -msg "$RTCM_MSGS" $LAT_LONG_ELEVATION $INSTRUMENT $ANTENNA -b 0 -t 5 -s 30000 -r 30000 -n 1 &
        fi
    fi
}

# Run the first command only if all required parameters are specified
if [ -n "$SERIAL_INPUT" ]; then
    echo "SERIAL_INPUT: \"$SERIAL_INPUT\""
    echo "SERIAL_INPUT2: \"$SERIAL_INPUT2\""
    echo "SERIAL_INPUT3: \"$SERIAL_INPUT3\""
    echo "TCP_OUTPUT_PORT is \"$TCP_OUTPUT_PORT\""
    echo "STARTING RTKLIB SERIAL INPUT TCPSERVER...."
    setup_virtual_devices
    run_and_retry str2str -in "$SERIAL_INPUT3" -out "tcpsvr://0.0.0.0:${TCP_OUTPUT_PORT}" -b 1 -t 5 -s 30000 -r 30000 -n 1 &
    export NTRIPSERVERINPUT1="ntripserver -M 1 -i \"/dev/ttyS0fake1\" -b \"${BAUD_RATE}\""
    export STR2STRINPUT1="str2str -in \"$SERIAL_INPUT\#rtcm3\""
    export NTRIPSERVERINPUT2="ntripserver -M 1 -i \"/dev/ttyS0fake2\" -b \"${BAUD_RATE}\""
    export STR2STRINPUT2="str2str -in \"$SERIAL_INPUT2\#rtcm3\""
    TCP_SERVER_SETUP_SUCCESSFUL=1
else
    echo "No Serial / USB Option Specified, Checking for TCP Input Options..."
    if [ -n "$TCP_INPUT_PORT" ] && [ -n "$TCP_INPUT_IP" ]; then
        echo "TCP Input IP and Port are specified. Processing with TCP Input..."
        echo "TCP_INPUT_PORT is \"$TCP_INPUT_PORT\""
        echo "TCP_INPUT_IP is \"$TCP_INPUT_IP\""
        echo "TCP_OUTPUT_PORT is \"$TCP_OUTPUT_PORT\""
        echo "STARTING RTKLIB TCP INPUT TCPSERVER...."
        run_and_retry str2str -in "tcpcli://${TCP_INPUT_IP}:${TCP_INPUT_PORT}" -out "tcpsvr://0.0.0.0:${TCP_OUTPUT_PORT}" -b 1 -t 5 -s 30000 -r 30000 -n 1 &
        export NTRIPSERVERINPUT1="ntripserver -M 2 -H \"127.0.0.1\" -P \"${TCP_OUTPUT_PORT}\""
        export STR2STRINPUT1="str2str -in \"tcpcli://127.0.0.1:${TCP_OUTPUT_PORT}#rtcm3\""
        export NTRIPSERVERINPUT2="ntripserver -M 2 -H \"127.0.0.1\" -P \"${TCP_OUTPUT_PORT}\""
        export STR2STRINPUT2="str2str -in \"tcpcli://127.0.0.1:${TCP_OUTPUT_PORT}#rtcm3\""
        TCP_SERVER_SETUP_SUCCESSFUL=1
    else
        echo "TCP Input IP or Port not specified. Please define TCP_INPUT_IP and TCP_INPUT_PORT."
        TCP_SERVER_SETUP_SUCCESSFUL=0
    fi
fi

# Call functions based on the success of the TCP server setup
if [ "$TCP_SERVER_SETUP_SUCCESSFUL" -eq 1 ]; then
    echo "TCP server setup successful. Running command blocks..."
    run_onocoy_server
    run_rtkdirect_server
else
    echo "TCP server setup failed. Skipping command blocks..."
    exit 1
fi

# Keep the script running indefinitely
while true; do
    sleep 1
done

# Reset the 'exit immediately' option
set +e

