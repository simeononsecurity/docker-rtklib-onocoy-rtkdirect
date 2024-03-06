#!/bin/bash

# Set default values for SERIAL_INPUT components
export USB_PORT="${USB_PORT:-ttyUSB0}"
export BAUD_RATE="${BAUD_RATE:-921600}"
export DATA_BITS="${DATA_BITS:-8}"
export PARITY="${PARITY:-n}"
export STOP_BITS="${STOP_BITS:-1}"
export RTCM_MSGS="${RTCM_MSGS:-\"1006(30), 1008(30), 1019, 1020, 1033(30), 1042, 1044, 1045, 1046, 1077, 1087, 1097, 1107, 1117, 1127, 1137, 1230\"}"
export TCP_OUTPUT_PORT="${TCP_OUTPUT_PORT:-5015}"
export TCP_INPUT_PORT="${TCP_INPUT_PORT}"
export TCP_INPUT_IP="${TCP_INPUT_IP}"
export TCP_SERVER_SETUP_SUCCESSFUL="${TCP_SERVER_SETUP_SUCCESSFUL:-0}"

# Construct SERIAL_INPUT using individual components only if TCP input is not use as a source
if [ -z "$TCP_INPUT_PORT" ] && [ -z "$TCP_INPUT_IP" ]; then
    export SERIAL_INPUT="serial://$USB_PORT:$BAUD_RATE:$DATA_BITS:$PARITY:$STOP_BITS"
fi

# Exit immediately if a command fails
set -e

# Function to run a command and restart it if it fails
run_and_retry() {
    until "$@"; do
        echo "$@ crashed with exit code $?. Respawning.." >&2
        sleep 1
    done
}

# Check if LAT, LONG, and ELEVATION are specified
if [ -n "$LAT" ] && [ -n "$LONG" ] && [ -n "$ELEVATION" ]; then
    LAT_LONG_ELEVATION="-p \"$LAT $LONG $ELEVATION\""
fi

# Check if INSTRUMENT is specified
if [ -n "$INSTRUMENT" ]; then
    INSTRUMENT="-i \"$INSTRUMENT\""
fi

# Check if ANTENNA is specified
if [ -n "$ANTENNA" ]; then
    ANTENNA="-a \"$ANTENNA\""
fi

# Function for running the second command
run_onocoy_server() {
    if [ -n "$PASSWORD" ] && [ -n "$ONOCOY_USERNAME" ]; then
        if [ -n "$ONOCOY_MOUNTPOINT" ]; then
            sleep 1
            run_and_retry ntripserver -M 2 -H 127.0.0.1 -P $TCP_OUTPUT_PORT -O 1 -a servers.onocoy.com -p 2101 -m "$ONOCOY_MOUNTPOINT" -n "$ONOCOY_USERNAME" -c "$PASSWORD" &
        else
            run_and_retry str2str -in tcpcli://127.0.0.1:$TCP_OUTPUT_PORT#rtcm3 -out ntrips://:$PASSWORD@servers.onocoy.com:2101/$ONOCOY_USERNAME#rtcm3 -msg "$RTCM_MSGS" $LAT_LONG_ELEVATION $INSTRUMENT $ANTENNA -t 0 &
        fi
    fi
}

# Function for running the third command
run_rtkdirect_server() {
    if [ -n "$PORT_NUMBER" ]; then
        sleep 1
        run_and_retry str2str -in tcpcli://127.0.0.1:$TCP_OUTPUT_PORT#rtcm3 -out tcpcli://ntrip.rtkdirect.com:$PORT_NUMBER#rtcm3 -msg "$RTCM_MSGS" $LAT_LONG_ELEVATION $INSTRUMENT $ANTENNA -t 0 &
    fi
}

# Run the first command only if all required parameters are specified
if [ -n "$SERIAL_INPUT" ]; then
    echo "SERIAL_INPUT is \"$SERIAL_INPUT\""
    run_and_retry str2str -in "$SERIAL_INPUT" -out tcpsvr://0.0.0.0:$TCP_OUTPUT_PORT -b 1 -t 0 &
    TCP_SERVER_SETUP_SUCCESSFUL=1
else
    echo "No Serial / USB Option Specified, Checking for TCP Input Options..."
    if [ -n "$TCP_INPUT_PORT" ] && [ -n "$TCP_INPUT_IP" ]; then
        echo "TCP Input IP and Port are specified. Processing with TCP Input..."
        run_and_retry str2str -in tcpcli://$TCP_INPUT_IP:$TCP_INPUT_PORT -out tcpsvr://0.0.0.0:$TCP_OUTPUT_PORT -b 1 -t 0 &
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
