# RTKLIB and NTRIPSERVER Docker Image for ONOCOY and RTKDIRECT

[![Docker Image CI](https://github.com/simeononsecurity/docker-rtklib-onocoy-rtkdirect/actions/workflows/docker-image.yml/badge.svg)](https://github.com/simeononsecurity/docker-rtklib-onocoy-rtkdirect/actions/workflows/docker-image.yml)

This Docker image provides a convenient setup for running [RTKLIB](https://www.rtklib.com/) and [NTRIPSERVER](https://github.com/simeononsecurity/ntripserver) with support for [ONOCOY](https://www.onocoy.com/) and [RTKDIRECT](https://rtkdirect.com/) services. 

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

    > You don't have to specify both Onocoy and RTKDirect credentials. The backend script is smart and looks to see if they have been set. You can use one or both and this should function perfectly.

   > If the environment variable `ONCOCOY_MOUNTPOINT` or `ONOCOY_USE_NTRIPSERVER` or `RTKDIRECT_USE_NTRIPSERVER` is specified, the docker container will use **NTRIPSERVER** for Onocoy or RTKDirect respectively, otherwise it'll use **RTKLIB** for the connection to Onocoy and/or RTKDirect. The container will still use RTKLIB for the splitting of the feed no matter what.
   > `LAT`, `LONG`, `ELEVATION`, `INSTRAMENT`, and `ANTENNA` are all optional and are only used if RTKLIB is being used and NTRIPSERVER is not.

   > You may specify `TCP_OUTPUT_PORT` to change the tcp server's output port if using docker's [host networking mode](https://docs.docker.com/network/#drivers). Otherwise use the appropriate docker [port mappings](https://docs.docker.com/network/#published-ports).

   > You can host any RTKLIB or tcp server instance on another machine and retreive the data using our dockers tcp client mode by defining `TCP_INPUT_IP` and `TCP_INPUT_PORT`. In which you'll specify your tcp servers ip and port.

   ```bash
   docker run \
     -td \
     --restart unless-stopped \
     --name sosrtk \
     --device=/dev/<YOUR_USB_PORT> \
     -e USB_PORT=<YOUR_USB_PORT> \
     -e BAUD_RATE=<YOUR_SERIAL_BAUD_RATE> \
     -e DATA_BITS=<YOUR_SERIAL_DATA_BITS> \
     -e PARITY=<YOUR_SERIAL_PARITY> \
     -e STOP_BITS=<YOUR_SERIAL_STOP_BITS> \
     -e ONOCOY_MOUNTPOINT=<YOUR_ONOCOY_MOUNTPOINT> \ 
     -e ONOCOY_USERNAME=<YOUR_ONOCOY_MOUNTPOINT_USERNAME> \
     -e ONOCOY_PASSWORD=<YOUR_ONOCOY_MOUNTPOINT_PASSWORD> \
     -e RTKDIRECT_MOUNTPOINT=<YOUR_RTKDIRECT_MOUNTPOINT> \
     -e RTKDIRECT_USERNAME=<YOUR_RTKDIRECT_MOUNTPOINT_USERNAME> \
     -e RTKDIRECT_PASSWORD=<YOUR_RTKDIRECT_MOUNTPOINT_PASSWORD> \
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
    --device=/dev/ttyUSB0 \
    -e USB_PORT=ttyUSB0 \
    -e BAUD_RATE=921600 \
    -e DATA_BITS=8 \
    -e PARITY=n \
    -e STOP_BITS=1 \
    -e ONOCOY_MOUNTPOINT=YOUR_ONOCOY_MOUNTPOINT \
    -e ONOCOY_USERNAME=YOUR_ONOCOY_MOUNTPOINT_USERNAME \
    -e ONOCOY_PASSWORD=YOUR_ONOCOY_MOUNTPOINT_PASSWORD \
    -e RTKDIRECT_MOUNTPOINT=YOUR_RTKDIRECT_MOUNTPOINT \
    -e RTKDIRECT_USERNAME=YOUR_RTKDIRECT_MOUNTPOINT_USERNAME \
    -e RTKDIRECT_PASSWORD=YOUR_RTKDIRECT_MOUNTPOINT_PASSWORD \
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

This script sets up environment variables, configures `str2str` commands based on specified parameters, and runs them in the background.

Feel free to customize the script and Dockerfile to meet your specific RTKLIB configuration requirements.

<a href="https://simeononsecurity.com" target="_blank" rel="noopener noreferrer">
  <h2>Explore the World of Cybersecurity</h2>
</a>
<a href="https://simeononsecurity.com" target="_blank" rel="noopener noreferrer">
  <img src="https://simeononsecurity.com/img/banner.png" alt="SimeonOnSecurity Logo" width="300" height="300">
</a>

## References
- https://kb.shawnchen.info/knowledge-base/docker/give-access-to-host-usb-for-serial-device-on-docker-container/
