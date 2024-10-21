#!/bin/bash

# Set default values for SERIAL_INPUT components
export USB_PORT="${USB_PORT:-ttyUSB0}"
export BAUD_RATE="${BAUD_RATE:-115200}"
export DATA_BITS="${DATA_BITS:-8}"
export PARITY="${PARITY:-n}"
export STOP_BITS="${STOP_BITS:-1}"
export RTCM_MSGS="${RTCM_MSGS:-\"1005(30),1006(30),1007(30),1019,1033(30),1042,1044,1045,1046,1077(1),1087(1),1097(1),1107(1),1117(1),1127(1),1137(1),1230(1)\"}"
export RAW_TCP_OUTPUT_PORT="${TCP_OUTPUT_PORT:-5015}"
export RTCM_TCP_OUTPUT_PORT="${TCP_OUTPUT_PORT:-5016}"
export TCP_INPUT_PORT="${TCP_INPUT_PORT}"
export TCP_INPUT_IP="${TCP_INPUT_IP}"
export TCP_SERVER_SETUP_SUCCESSFUL="${TCP_SERVER_SETUP_SUCCESSFUL:-0}"
export ONOCOY_USE_SSL="${ONOCOY_USE_SSL:-true}"
export ONOCOY_USE_NTRIPSERVER="${ONOCOY_USE_NTRIPSERVER:-false}"
export RTKDIRECT_USE_NTRIPSERVER="${RTKDIRECT_USE_NTRIPSERVER:-true}"
export RTKLIB_VERBOSITY="${RTKLIB_VERBOSITY:-1}"

echo "### Setting Up SERIAL_INPUT Components ###"
echo "USB_PORT: $USB_PORT"
echo "BAUD_RATE: $BAUD_RATE"
echo "DATA_BITS: $DATA_BITS"
echo "PARITY: $PARITY"
echo "STOP_BITS: $STOP_BITS"

# Construct SERIAL_INPUT using individual components only if TCP input is not used as a source
if [ -z "$TCP_INPUT_PORT" ] && [ -z "$TCP_INPUT_IP" ]; then
    export SERIAL_INPUT="serial://${USB_PORT}:${BAUD_RATE}:${DATA_BITS}:${PARITY}:${STOP_BITS}"
    echo "SERIAL_INPUT set to: $SERIAL_INPUT"
else
    echo "TCP input specified. SERIAL_INPUT will not be used."
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

# Check if LAT, LONG, and ELEVATION are specified
if [ -n "$LAT" ] && [ -n "$LONG" ] && [ -n "$ELEVATION" ]; then
    LAT_LONG_ELEVATION="-p \"$LAT $LONG $ELEVATION\""
    echo "LAT, LONG, and ELEVATION specified: $LAT_LONG_ELEVATION"
else
    echo "LAT, LONG, or ELEVATION not specified. Skipping related options."
fi

# Check if INSTRUMENT is specified
if [ -n "$INSTRUMENT" ]; then
    INSTRUMENT="-i \"$INSTRUMENT\""
    echo "INSTRUMENT specified: $INSTRUMENT"
else
    echo "INSTRUMENT not specified. Skipping related options."
fi

# Check if ANTENNA is specified
if [ -n "$ANTENNA" ]; then
    ANTENNA="-a \"$ANTENNA\""
    echo "ANTENNA specified: $ANTENNA"
else
    echo "ANTENNA not specified. Skipping related options."
fi

# Function for running the third command
run_onocoy_server() {
    if [ -n "$ONOCOY_PASSWORD" ] && [ -n "$ONOCOY_USERNAME" ]; then
        echo "### Starting ONOCOY Server Setup ###"
        echo "ONOCOY_PASSWORD: $ONOCOY_PASSWORD"
        echo "ONOCOY_USERNAME: $ONOCOY_USERNAME"
        echo "ONOCOY_MOUNTPOINT: $ONOCOY_MOUNTPOINT"
        
        if [ "$ONOCOY_USE_SSL" = true ]; then
            echo "ONOCOY_USE_SSL is enabled. Using secure connection."
            if [ "$ONOCOY_USE_NTRIPSERVER" = true ]; then
                echo "ONOCOY_USE_NTRIPSERVER is enabled."
                if [ -n "$ONOCOY_MOUNTPOINT" ]; then
                    echo "Starting stunnel and NTRIP server with SSL and mountpoint."
                    stunnel /etc/stunnel/stunnel.conf &
                    run_and_retry ntripserver -M 2 -H "127.0.0.1" -P "${RTCM_TCP_OUTPUT_PORT}" -O 1 -a "127.0.0.1" -p "2101" -m "$ONOCOY_MOUNTPOINT" -n "$ONOCOY_USERNAME" -c "$ONOCOY_PASSWORD" -R 5 &
                else
                    echo "Starting stunnel and NTRIP server with SSL and no mountpoint."
                    stunnel /etc/stunnel/stunnel.conf &
                    run_and_retry ntripserver -M 2 -H "127.0.0.1" -P "${RTCM_TCP_OUTPUT_PORT}" -O 3 -a "127.0.0.1" -p "2101" -m "$ONOCOY_USERNAME" -c "$ONOCOY_PASSWORD" -R 5 &
                fi
            else
                echo "Starting stunnel and str2str with SSL."
                stunnel /etc/stunnel/stunnel.conf &
                run_and_retry str2str -in "tcpcli://127.0.0.1:${RTCM_TCP_OUTPUT_PORT}#rtcm3" -out "ntrips://:${ONOCOY_PASSWORD}@127.0.0.1:2101/${ONOCOY_USERNAME}#rtcm3" -msg "$RTCM_MSGS" $LAT_LONG_ELEVATION $INSTRUMENT $ANTENNA -b 0 -t $RTKLIB_VERBOSITY -s 30000 -r 30000 -n 1 &
            fi
        else
            echo "ONOCOY_USE_SSL is disabled. Using non-secure connection."
            if [ "$ONOCOY_USE_NTRIPSERVER" = true ]; then
                echo "ONOCOY_USE_NTRIPSERVER is enabled."
                if [ -n "$ONOCOY_MOUNTPOINT" ]; then
                    echo "Starting NTRIP server without SSL and with mountpoint."
                    run_and_retry ntripserver -M 2 -H "127.0.0.1" -P "${RTCM_TCP_OUTPUT_PORT}" -O 1 -a "servers.onocoy.com" -p "2101" -m "$ONOCOY_MOUNTPOINT" -n "$ONOCOY_USERNAME" -c "$ONOCOY_PASSWORD" -R 5 &
                else
                    echo "Starting NTRIP server without SSL and no mountpoint."
                    run_and_retry ntripserver -M 2 -H "127.0.0.1" -P "${RTCM_TCP_OUTPUT_PORT}" -O 3 -a "servers.onocoy.com" -p "2101" -m "$ONOCOY_USERNAME" -c "$ONOCOY_PASSWORD" -R 5 &
                fi
            else
                echo "Starting str2str without SSL."
                run_and_retry str2str -in "tcpcli://127.0.0.1:${RTCM_TCP_OUTPUT_PORT}#rtcm3" -out "ntrips://:${ONOCOY_PASSWORD}@servers.onocoy.com:2101/${ONOCOY_USERNAME}#rtcm3" -msg "$RTCM_MSGS" $LAT_LONG_ELEVATION $INSTRUMENT $ANTENNA -b 0 -t $RTKLIB_VERBOSITY -s 30000 -r 30000 -n 1 &
            fi
        fi
    fi
}

# Function for running the RTKDirect command
run_rtkdirect_server() {
    if [ -n "$RTKDIRECT_PASSWORD" ] && [ -n "$RTKDIRECT_USERNAME" ] && [ -n "$RTKDIRECT_MOUNTPOINT" ]; then
        echo "### Starting RTKDirect Server Setup ###"
        echo "RTKDIRECT_PASSWORD: $RTKDIRECT_PASSWORD"
        echo "RTKDIRECT_USERNAME: $RTKDIRECT_USERNAME"
        echo "RTKDIRECT_MOUNTPOINT: $RTKDIRECT_MOUNTPOINT"
        if [ "$RTKDIRECT_USE_NTRIPSERVER" = true ]; then
            echo "Starting NTRIP server for RTKDirect."
            run_and_retry ntripserver -M 2 -H "127.0.0.1" -P "${RTCM_TCP_OUTPUT_PORT}" -O 1 -a "ntrip.rtkdirect.com" -p "2101" -m "$RTKDIRECT_MOUNTPOINT" -n "$RTKDIRECT_USERNAME" -c "$RTKDIRECT_PASSWORD" -R 5 &
        else
            echo "Starting str2str for RTKDirect."
            run_and_retry str2str -in "tcpcli://127.0.0.1:${RTCM_TCP_OUTPUT_PORT}#rtcm3" -out "ntrips://${RTKDIRECT_USERNAME}:${RTKDIRECT_PASSWORD}@ntrip.rtkdirect.com:2101/${RTKDIRECT_MOUNTPOINT}#rtcm3" -msg "$RTCM_MSGS" $LAT_LONG_ELEVATION $INSTRUMENT $ANTENNA -b 0 -t $RTKLIB_VERBOSITY -s 30000 -r 30000 -n 1 &
        fi
    fi
}

# Run the first command only if all required parameters are specified
if [ -n "$SERIAL_INPUT" ]; then
    echo "### Starting RTKLIB SERIAL INPUT TCPSERVER ###"
    echo "SERIAL_INPUT: $SERIAL_INPUT"
    echo "RTCM_TCP_OUTPUT_PORT: $RTCM_TCP_OUTPUT_PORT"
    run_and_retry str2str -in "$SERIAL_INPUT" -out "tcpsvr://0.0.0.0:${RAW_TCP_OUTPUT_PORT}" -b 1 -t $RTKLIB_VERBOSITY -s 30000 -r 30000 -n 1 &
    run_and_retry str2str -in "tcpcli://127.0.0.1:${RAW_TCP_OUTPUT_PORT}#rtcm3" -out "tcpsvr://0.0.0.0:${RTCM_TCP_OUTPUT_PORT}#rtcm3" -msg "$RTCM_MSGS" -b 1 -t $RTKLIB_VERBOSITY -s 30000 -r 30000 -n 1 &
    TCP_SERVER_SETUP_SUCCESSFUL=1
else
    echo "No Serial / USB Option Specified. Checking for TCP Input Options..."
    if [ -n "$TCP_INPUT_PORT" ] && [ -n "$TCP_INPUT_IP" ]; then
        echo "TCP Input IP and Port are specified. Proceeding with TCP Input..."
        echo "TCP_INPUT_PORT: $TCP_INPUT_PORT"
        echo "TCP_INPUT_IP: $TCP_INPUT_IP"
        echo "RTCM_TCP_OUTPUT_PORT: $RTCM_TCP_OUTPUT_PORT"
        echo "### Starting RTKLIB TCP INPUT TCPSERVER ###"
        run_and_retry str2str -in "tcpcli://${TCP_INPUT_IP}:${TCP_INPUT_PORT}" -out "tcpsvr://0.0.0.0:${RAW_TCP_OUTPUT_PORT}" -b 1 -t $RTKLIB_VERBOSITY -s 30000 -r 30000 -n 1 &
        run_and_retry str2str -in "tcpcli://127.0.0.1:${RAW_TCP_OUTPUT_PORT}#rtcm3" -out "tcpsvr://0.0.0.0:${RTCM_TCP_OUTPUT_PORT}#rtcm3" -msg "$RTCM_MSGS" -b 1 -t $RTKLIB_VERBOSITY -s 30000 -r 30000 -n 1 &
        TCP_SERVER_SETUP_SUCCESSFUL=1
    else
        echo "TCP Input IP or Port not specified. Please define TCP_INPUT_IP and TCP_INPUT_PORT."
        TCP_SERVER_SETUP_SUCCESSFUL=0
    fi
fi

# Call functions based on the success of the TCP server setup
if [ "$TCP_SERVER_SETUP_SUCCESSFUL" -eq 1 ]; then
    echo "TCP server setup successful. Running additional command blocks..."
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
