#!/bin/bash

# Check for at least one running instance of str2str
str2str_count=$(pgrep -c str2str)
if [ "$str2str_count" -lt 1 ]; then
    # If no str2str instance is found, exit with error (unhealthy)
    exit 1
fi

# Initial count of ntripserver and adjusted str2str count
ntripserver_count=0
str2str_count=1

# Boolean flag for server checks
ntripservercheck=false
str2strcheck=false

# Adjust ntripserver and str2str count based on conditions that require them in the docker-init.sh
if [ "$RTKDIRECT_USE_NTRIPSERVER" = true ] && [ -n "$RTKDIRECT_USERNAME" ] && [ -n "$RTKDIRECT_MOUNTPOINT" ] && [ -n "$RTKDIRECT_PASSWORD" ]; then
    ntripserver_count=$((ntripserver_count + 1))
elif [ "$RTKDIRECT_USE_NTRIPSERVER" != true ] && [ -n "$RTKDIRECT_USERNAME" ] && [ -n "$RTKDIRECT_MOUNTPOINT" ] && [ -n "$RTKDIRECT_PASSWORD" ]; then
    str2str_count=$((str2str_count + 1))
fi

if [ -n "$ONOCOY_MOUNTPOINT" ] || [ "$ONOCOY_USE_NTRIPSERVER" = true ]; then
    ntripserver_count=$((ntripserver_count + 1))
elif [ -z "$ONOCOY_MOUNTPOINT" ] && [ "$ONOCOY_USE_NTRIPSERVER" != true ] && [ -n "$ONOCOY_USERNAME" ] && [ -n "$ONOCOY_PASSWORD" ]; then
    str2str_count=$((str2str_count + 1))
fi

# Check NTRIPSERVER Count
if [ "$ntripserver_count" -eq 0 ]; then
    echo "No NTRIPSERVER check... Skipping..."
    ntripservercheck=true
else
    # If ntripserver is needed, check if the required number of ntripserver instances are running
    if [ "$(pgrep -c ntripserver)" -ge "$ntripserver_count" ]; then
        ntripservercheck=true
    else
        ntripservercheck=false
    fi
fi

# Check STR2STR Count
if [ "$str2str_count" -eq 1 ]; then
    echo "No STR2STR check... Skipping..."
    str2strcheck=true
else
    # If str2str is needed, check if the required number of str2str instances are running
    if [ "$(pgrep -c str2str)" -ge "$str2str_count" ]; then
        str2strcheck=true
    else
        str2strcheck=false
    fi
fi

if [ "$ntripservercheck" = false ] || [ "$str2strcheck" = false ]; then
    # If either check is false, exit with error (unhealthy)
    exit 1
else
    # If both checks are true, exit with success (healthy)
    exit 0
fi