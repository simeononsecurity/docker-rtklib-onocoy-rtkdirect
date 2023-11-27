# Use Ubuntu as the base image
FROM ubuntu:latest

# Set Labels
LABEL org.opencontainers.image.source="https://github.com/simeononsecurity/docker-rtklib-onocoy-rtkdirect"
LABEL org.opencontainers.image.description=" Docker Container that Takes in USB Serial GPS Reciever and Forwards the Data to Either Onocoy or RTKDirect or Both."
LABEL org.opencontainers.image.authors="simeononsecurity"

# Set ENV Variables
ENV DEBIAN_FRONTEND noninteractive
ENV container docker
ENV TERM=xterm

# Install RTKLIB from the package manager
RUN apt update && \
    apt full-upgrade -y --no-install-recommends && \
    apt install -y rtklib --no-install-recommends && \
    rm -rf /var/lib/apt/lists/* 

# Set the working directory
WORKDIR /app

# Copy the script into the container
COPY docker-init.sh /app/docker-init.sh

# Make the script executable
RUN chmod +x /app/docker-init.sh

# Run the script when the container starts
CMD ["/app/docker-init.sh"]
