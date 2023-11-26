# RTKLIB Docker Image for ONOCOY and RTKDIRECT

This Docker image provides a convenient setup for running [RTKLIB](https://www.rtklib.com/) with support for [ONOCOY](https://www.onocoy.com/) and [RTKDIRECT](https://rtkdirect.com/) services. 

The image follows the guides we created for the individual services. If you'd like to do this manually, without Docker, please read the articles listed below:

- https://simeononsecurity.com/other/onocoy-gps-gnss-reciever-basestation-on-a-budget/
- https://simeononsecurity.com/other/diy-rtkdirect-reference-station-guide/
- https://simeononsecurity.com/other/triple-mining-geodnet-onocoy-rtkdirect-gps-revolution/

Follow the instructions below to use this image effectively.

## Prerequisites

Before using this Docker image, make sure you have the following prerequisites installed on your system:

- Docker: [Install Docker](https://docs.docker.com/get-docker/)
- Docker Compose (optional): [Install Docker Compose](https://docs.docker.com/compose/install/) if you prefer using Docker Compose for managing containers.

### Hardware

For recommended hardware for this project please read the following:

- https://simeononsecurity.com/other/triple-mining-geodnet-onocoy-rtkdirect-gps-revolution/#hardware-requirements
- https://simeononsecurity.com/other/unveiling-best-gps-antennas-onocoy-geodnet/
- https://simeononsecurity.com/other/affordable-precision-positioning-gnss-modules/

## Getting Started

1. **Pull the Docker Image**

   Pull the latest version of the Docker image from Docker Hub:

   ```bash
   docker pull simeononsecurity/docker-rtklib-onocoy-rtkdirect:latest
   ```

2. **Run the Docker Container**

   Run the Docker container, ensuring that you provide the necessary environment variables and parameters:

   ```bash
   docker run \
     -td \
     --restart unless-stopped \
     --name sosrtk \
     -e USB_PORT=<YOUR_USB_PORT> \
     -e BAUD_RATE=<YOUR_SERIAL_BAUD_RATE> \
     -e DATA_BITS=<YOUR_SERIAL_DATA_BITS> \
     -e PARITY=<YOUR_SERIAL_PARITY> \
     -e STOP_BITS=<YOUR_SERIAL_STOP_BITS> \
     -e ONOCOY_USERNAME=<YOUR_ONOCOY_MOUNTPOINT_USERNAME> \
     -e PASSWORD=<YOUR_ONOCOY_MOUNTPOINT_PASSWORD> \
     -e PORT_NUMBER=<YOUR_RTKLIB_PORT_NUMBER> \
     -e LAT=<OPTIONAL_YOUR_LATITUDE> \
     -e LONG=<OPTIONAL_YOUR_LONGITUDE> \
     -e ELEVATION=<OPTIONAL_YOUR_ELEVATION_FROM_SEA_LEVEL_IN_METERS> \
     -e INSTRUMENT=<OPTIONAL_YOUR_GPS_RECEIVER_DESCRIPTION> \
     -e ANTENNA=<OPTIONAL_YOUR_ANTENNA_DESCRIPTION> \
     simeononsecurity/docker-rtklib-onocoy-rtkdirect:latest
   ```

   Ensure you replace the placeholder values (`<...>`) with your specific configuration.

   Ex.
   ```bash
   docker run \
    -td \
    --restart unless-stopped \
    --name sosrtk \
    -e USB_PORT=/dev/ttyUSB0 \
    -e BAUD_RATE=921600 \
    -e DATA_BITS=8 \
    -e PARITY=n \
    -e STOP_BITS=1 \
    -e ONOCOY_USERNAME=your_onocoy_mountpoint_username \
    -e PASSWORD=your_onocoy_mountpoint_password \
    -e PORT_NUMBER=2101 \
    -e LAT=37.7749 \
    -e LONG=-122.4194 \
    -e ELEVATION=50 \
    -e INSTRUMENT="Your GPS Receiver" \
    -e ANTENNA="Your Antenna" \
    simeononsecurity/docker-rtklib-onocoy-rtkdirect:latest
   ```

3. **Monitor Logs**

   Monitor the container logs to check for any issues or to observe the RTKLIB operation:

   ```bash
   docker logs sosrtk
   ```

4. **Customize Configuration**

   If needed, you can customize the `docker-init.sh` script and rebuild the Docker image with your changes.

## Docker Compose (Optional)

If you prefer using Docker Compose, create a `docker-compose.yml` file with your desired configuration and run:

```bash
docker-compose up -d
```

This will start the container in detached mode.

## Notes

- Ensure that your system allows access to the specified USB port and that the necessary permissions are set.
- Adjust environment variables according to your specific requirements.

Now you have a Dockerized RTKLIB setup with ONOCOY and RTKDIRECT support. Customize the configuration based on your needs and enjoy precise real-time kinematic positioning!

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

<a href="https://simeononsecurity.com" target="_blank" rel="noopener noreferrer">
  <h2>Explore the World of Cybersecurity</h2>
</a>
<a href="https://simeononsecurity.com" target="_blank" rel="noopener noreferrer">
  <img src="https://simeononsecurity.com/img/banner.png" alt="SimeonOnSecurity Logo" width="300" height="300">
</a>