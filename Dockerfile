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
