#!/bin/bash

# Set environment variables
export ONOCOY_USERNAME="$ONOCOY_USERNAME"

# Set default values for SERIAL_INPUT components
export USB_PORT="${USB_PORT:-ttyUSB0}"
export BAUD_RATE="${BAUD_RATE:-921600}"
export DATA_BITS="${DATA_BITS:-8}"
export PARITY="${PARITY:-n}"
export STOP_BITS="${STOP_BITS:-1}"

# Construct SERIAL_INPUT using individual components
export SERIAL_INPUT="serial://$USB_PORT:$BAUD_RATE:$DATA_BITS:$PARITY:$STOP_BITS#rtcm3"

# Set RTCM_MSG_COMMON without latitude, longitude, and elevation
export RTCM_MSG_COMMON="-msg \"1006(30), 1008(30), 1012(30), 1033(30), 1077, 1087, 1097, 1107, 1117, 1127, 1137, 1230\" -t 0"

# Check if LAT, LONG, and ELEVATION are specified
if [ -n "$LAT" ] && [ -n "$LONG" ] && [ -n "$ELEVATION" ]; then
    RTCM_MSG_COMMON="-p \"$LAT $LONG $ELEVATION\" $RTCM_MSG_COMMON"
fi

# Exit immediately if a command fails
set -e

# Run the first command only if all required parameters are specified
if [ -n "$SERIAL_INPUT" ]; then
    str2str -in "$SERIAL_INPUT" -out tcpsvr://:5016#rtcm3 -b 1 -t 0 &
fi

# Run the second command only if all required parameters are specified
if [ -n "$PASSWORD" ] && [ -n "$ONOCOY_USERNAME" ]; then
    str2str -in tcpcli://127.0.0.1:5015#rtcm3 -out ntrips://:$PASSWORD@servers.onocoy.com:2101/$ONOCOY_USERNAME#rtcm3 $RTCM_MSG_COMMON &
fi

# Run the third command only if all required parameters are specified
if [ -n "$PORT_NUMBER" ]; then
    str2str -in tcpcli://127.0.0.1:5016#rtcm3 -out tcpcli://ntrip.rtkdirect.com:$PORT_NUMBER#rtcm3 $RTCM_MSG_COMMON &
fi

# Reset the 'exit immediately' option
set +e