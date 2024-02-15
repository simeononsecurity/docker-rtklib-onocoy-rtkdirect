# Build stage for str2str and NTRIP server
FROM ubuntu:latest as builder

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Update and install necessary packages for building
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Clone RTKLIB repo from the demo5 branch
WORKDIR /app
RUN git clone -b demo5 https://github.com/rtklibexplorer/RTKLIB.git

# Build str2str
WORKDIR /app/RTKLIB/app/consapp/str2str/gcc
RUN make

# Clone and build NTRIP server
WORKDIR /app
RUN git clone https://github.com/simeononsecurity/ntripserver.git && \
    cd ntripserver && \
    make

# Final image
FROM ubuntu:latest

# Set Labels
LABEL org.opencontainers.image.source="https://github.com/simeononsecurity/docker-rtklib-onocoy-rtkdirect"
LABEL org.opencontainers.image.description="Docker Container that Takes in USB Serial GPS Receiver and Forwards the Data to Either Onocoy or RTKDirect or Both."
LABEL org.opencontainers.image.authors="simeononsecurity"

# Set ENV Variables
ENV DEBIAN_FRONTEND noninteractive
ENV container docker
ENV TERM=xterm

# Install RTKLIB, GPSD dependencies, and other necessary tools from the package manager
RUN apt update && \
    apt full-upgrade -y --no-install-recommends && \
    apt install -y rtklib gpsd gpsd-clients gpsbabel && \
    rm -rf /var/lib/apt/lists/*

# Copy the compiled str2str from the build stage
COPY --from=builder /app/RTKLIB/app/consapp/str2str/gcc/str2str /usr/local/bin/str2str

# Copy the compiled NTRIP server from the build stage
COPY --from=builder /app/ntripserver/ntripserver /usr/local/bin/ntripserver

# Set the working directory
WORKDIR /app

# Copy the script into the container
COPY docker-init.sh /app/docker-init.sh

# Make the script executable
RUN chmod +x /app/docker-init.sh

# Run the script when the container starts
CMD ["/app/docker-init.sh"]
