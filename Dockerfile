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

# Change to str2str dir
WORKDIR /app/RTKLIB/app/consapp/str2str/gcc
# Check out the specific tag and create a new branch from it
RUN git checkout tags/b34j -b docker-b34j
# Build str2str
RUN make

# Clone and build NTRIP server
WORKDIR /app
RUN git clone https://github.com/simeononsecurity/ntripserver.git && \
    cd ntripserver && \
    make

# Set the working directory
WORKDIR /usr/src/ttybus

# Clone the ttybus repository
RUN git clone https://github.com/danielinux/ttybus.git .

# Set build arguments
ARG CFLAGS=-Wall
ARG LDFLAGS=-lm

# Build ttybus binaries
RUN make CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS"

# Final image
FROM ubuntu:latest

# Set Labels
LABEL org.opencontainers.image.source="https://github.com/simeononsecurity/docker-rtklib-onocoy-rtkdirect"
LABEL org.opencontainers.image.description="Docker Container that Takes in USB/TCPIP Serial GPS Receiver and Forwards the Data to Either Onocoy or RTKDirect or Both."
LABEL org.opencontainers.image.authors="simeononsecurity"

# Set ENV Variables
ENV DEBIAN_FRONTEND noninteractive
ENV container docker
ENV TERM=xterm

# Install RTKLIB, GPSD dependencies, stunnel, and other necessary tools from the package manager
RUN apt update && \
    apt full-upgrade -y --no-install-recommends && \
    apt install -y gpsd gpsd-clients gpsbabel procps stunnel4 && \
    rm -rf /var/lib/apt/lists/*

# Copy the compiled str2str from the build stage
COPY --from=builder /app/RTKLIB/app/consapp/str2str/gcc/str2str /usr/local/bin/str2str

# Copy the compiled NTRIP server from the build stage
COPY --from=builder /app/ntripserver/ntripserver /usr/local/bin/ntripserver

# Copy tty binaries from the build stage
COPY --from=builder /usr/src/ttybus/tty_bus /usr/local/bin/
COPY --from=builder /usr/src/ttybus/tty_fake /usr/local/bin/
COPY --from=builder /usr/src/ttybus/tty_plug /usr/local/bin/
COPY --from=builder /usr/src/ttybus/tty_attach /usr/local/bin/
COPY --from=builder /usr/src/ttybus/dpipe /usr/local/bin/

# Copy the healthcheck script into the container
COPY healthcheck.sh /usr/local/bin/healthcheck.sh

# Make sure the script is executable
RUN chmod +x /usr/local/bin/healthcheck.sh

# Healthcheck configuration
#HEALTHCHECK --interval=30s --timeout=60s --start-period=30s --retries=3 CMD /usr/local/bin/healthcheck.sh

# Set the working directory
WORKDIR /app

# Copy the script into the container
COPY docker-init.sh /app/docker-init.sh

# Make the script executable
RUN chmod +x /app/docker-init.sh

# Copy stunnel configuration
COPY stunnel.conf /etc/stunnel/stunnel.conf

# Generate a self-signed certificate for stunnel
RUN mkdir -p /etc/stunnel && \
    openssl req -new -x509 -days 365 -nodes \
    -out /etc/stunnel/stunnel.pem -keyout /etc/stunnel/stunnel.pem \
    -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=localhost"

# Start stunnel and the main application
CMD ["/app/docker-init.sh"]
