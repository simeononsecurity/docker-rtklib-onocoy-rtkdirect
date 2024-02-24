#!/bin/bash

# Set default values for SERIAL_INPUT components
export USB_PORT="${USB_PORT:-ttyUSB0}"
export BAUD_RATE="${BAUD_RATE:-921600}"
export DATA_BITS="${DATA_BITS:-8}"
export PARITY="${PARITY:-n}"
export STOP_BITS="${STOP_BITS:-1}"
export RTCM_MSGS="${RTCM_MSGS:-\"1006(30), 1008(30), 1019, 1020, 1033(30), 1042, 1044, 1045, 1046, 1077, 1087, 1097, 1107, 1117, 1127, 1137, 1230\"}"

# Construct SERIAL_INPUT using individual components
export SERIAL_INPUT="serial://$USB_PORT:$BAUD_RATE:$DATA_BITS:$PARITY:$STOP_BITS"

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

# Exit immediately if a command fails
set -e

# Run the first command only if all required parameters are specified
if [ -n "$SERIAL_INPUT" ]; then
    echo "SERIAL_INPUT is \"$SERIAL_INPUT\""
    str2str -in "$SERIAL_INPUT" -out tcpsvr://0.0.0.0:5015 -b 1 -t 0 &
fi

# Run the second command only if all required parameters are specified
if [ -n "$PASSWORD" ] && [ -n "$ONOCOY_USERNAME" ]; then
    if [ -n "$ONOCOY_MOUNTPOINT" ]; then
        sleep 1
        ntripserver -M 2 -H 127.0.0.1 -P 5015 -O 1 -a servers.onocoy.com -p 2101 -m "$ONOCOY_MOUNTPOINT" -n "$ONOCOY_USERNAME" -c "$PASSWORD"
    else
        str2str -in tcpcli://127.0.0.1:5015#rtcm3 -out ntrips://:$PASSWORD@servers.onocoy.com:2101/$ONOCOY_USERNAME#rtcm3 -msg "$RTCM_MSGS" $LAT_LONG_ELEVATION $INSTRUMENT $ANTENNA -t 0 &
    fi
fi

# Run the third command only if all required parameters are specified
if [ -n "$PORT_NUMBER" ]; then
    sleep 1
    str2str -in tcpcli://127.0.0.1:5015#rtcm3 -out tcpcli://ntrip.rtkdirect.com:$PORT_NUMBER#rtcm3 -msg "$RTCM_MSGS" $LAT_LONG_ELEVATION $INSTRUMENT $ANTENNA -t 0 &
fi

# Keep the script running indefinitely
while true; do
    sleep 1
done

# Reset the 'exit immediately' option
set +e
