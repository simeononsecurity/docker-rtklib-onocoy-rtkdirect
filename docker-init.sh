#!/bin/bash

# Set default values for SERIAL_INPUT components
export USB_PORT="${USB_PORT:-ttyUSB0}"
export BAUD_RATE="${BAUD_RATE:-921600}"
export DATA_BITS="${DATA_BITS:-8}"
export PARITY="${PARITY:-n}"
export STOP_BITS="${STOP_BITS:-1}"

# Construct SERIAL_INPUT using individual components
export SERIAL_INPUT="serial://$USB_PORT:$BAUD_RATE:$DATA_BITS:$PARITY:$STOP_BITS#rtcm3"

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
    str2str -in "$SERIAL_INPUT" -out tcpsvr://:5016#rtcm3 -b 1 -t 0 &
fi

# Run the second command only if all required parameters are specified
if [ -n "$PASSWORD" ] && [ -n "$ONOCOY_USERNAME" ]; then
    str2str -in tcpcli://127.0.0.1:5015#rtcm3 -out ntrips://:$PASSWORD@servers.onocoy.com:2101/$ONOCOY_USERNAME#rtcm3 -msg "1006(10), 1033(10), 1077, 1087, 1097, 1107, 1117, 1127, 1137, 1230" $LAT_LONG_ELEVATION $INSTRUMENT $ANTENNA -t 0 &
fi

# Run the third command only if all required parameters are specified
if [ -n "$PORT_NUMBER" ]; then
    str2str -in tcpcli://127.0.0.1:5015#rtcm3 -out tcpcli://ntrip.rtkdirect.com:$PORT_NUMBER#rtcm3 -msg "1006(10), 1033(10), 1077, 1087, 1097, 1107, 1117, 1127, 1137, 1230" $LAT_LONG_ELEVATION $INSTRUMENT $ANTENNA -t 0 &
fi

# Keep the script running indefinitely
while true; do
    sleep 1  # You can adjust the sleep duration as needed
done

# Reset the 'exit immediately' option
set +e
