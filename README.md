# docker-rtklib-onocoy-rtkdirect
Docker Container that Takes in USB Serial GPS Reciever and Forwards the Data to Either Onocoy or RTKDirect or Both.

This repository contains Dockerfiles and a script to set up a Docker image for running RTKLIB, a toolkit for real-time kinematic (RTK) positioning. The Docker image is based on the latest Ubuntu release.

## Dockerfile

The `Dockerfile` in this repository sets up the Docker image. It follows these main steps:

1. Uses Ubuntu as the base image.
2. Installs RTKLIB from the package manager.
3. Sets the working directory to `/app`.
4. Copies the `docker-init.sh` script into the container.
5. Makes the script executable.
6. Defines the command to run the script when the container starts.

Here's a breakdown of the Dockerfile:

```Dockerfile
# Use Ubuntu as the base image
FROM ubuntu:latest

# Install RTKLIB from the package manager
RUN apt update && \
    apt full-upgrade -y --no-install-recommends && \
    apt install -y rtklib --no-install-recommends

# Set the working directory
WORKDIR /app

# Copy the script into the container
COPY docker-init.sh /app/docker-init.sh

# Make the script executable
RUN chmod +x /app/docker-init.sh

# Run the script when the container starts
CMD ["/app/docker-init.sh"]
```

## Initialization Script

The `docker-init.sh` script sets up environment variables and runs `str2str` commands for RTKLIB. It accepts various parameters, allowing customization of the RTKLIB configuration.

```bash
#!/bin/bash

# Set environment variables
export TCP_SERVER_OUTPUT="tcpsvr://:5015#rtcm3"
export ONOCOY_USERNAME="$ONOCOY_USERNAME"

# ... (other environment variable setups)

# Exit immediately if a command fails
set -e

# Run the first command only if all required parameters are specified
if [ -n "$SERIAL_INPUT" ] && [ -n "$TCP_SERVER_OUTPUT" ]; then
    str2str -in "$SERIAL_INPUT" -out "$TCP_SERVER_OUTPUT" -b 1 -t 0 &

    # Run the second command only if all required parameters are specified
    if [ -n "$PASSWORD" ] && [ -n "$ONOCOY_USERNAME" ] && [ -n "$NTRIPS_OUTPUT" ]; then
        str2str -in tcpcli://localhost:5015#rtcm3 -out "ntrips://:$PASSWORD@servers.onocoy.com:2101/$ONOCOY_USERNAME#rtcm3" $RTCM_MSG_COMMON &
    fi

    # Run the third command only if all required parameters are specified
    if [ -n "$PORT_NUMBER" ]; then
        str2str -in tcpcli://localhost:5015#rtcm3 -out "tcpcli://ntrip.rtkdirect.com:$PORT_NUMBER#rtcm3" $RTCM_MSG_COMMON &
    fi
fi

# Reset the 'exit immediately' option
set +e
```

This script sets up environment variables, configures `str2str` commands based on specified parameters, and runs them in the background.

Feel free to customize the script and Dockerfile to meet your specific RTKLIB configuration requirements.