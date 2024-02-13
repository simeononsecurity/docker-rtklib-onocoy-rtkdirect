# Use Ubuntu as the base image
FROM ubuntu:latest

# Set Labels
LABEL org.opencontainers.image.source="https://github.com/simeononsecurity/docker-rtklib-onocoy-rtkdirect"
LABEL org.opencontainers.image.description="Docker Container that Takes in USB Serial GPS Receiver and Forwards the Data to Either Onocoy or RTKDirect or Both."
LABEL org.opencontainers.image.authors="simeononsecurity"

# Set ENV Variables
ENV DEBIAN_FRONTEND noninteractive
ENV container docker
ENV TERM=xterm

# Install RTKLIB and NTRIPSERVER dependencies from the package manager
RUN apt update && \
    apt full-upgrade -y --no-install-recommends && \
    apt install -y rtklib && \
    apt install -y gpsd gpsd-clients gpsbabel git make build-essential && \
    rm -rf /var/lib/apt/lists/* 

# Set the working directory
WORKDIR /app

# Download and Install NTRIP Server with SimeonOnSecurity Baud Rate Patch
RUN git clone https://github.com/simeononsecurity/ntripserver.git && \
    cd ./ntripserver && \
    make

# Copy the script into the container
COPY docker-init.sh /app/docker-init.sh

# Make the script executable
RUN chmod +x /app/docker-init.sh

# Run the script when the container starts
CMD ["/app/docker-init.sh"]
