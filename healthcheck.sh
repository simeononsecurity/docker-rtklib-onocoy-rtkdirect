#!/bin/bash

# Check for at least one running instance of str2str
str2str_count=$(pgrep -c str2str)
if [ "$str2str_count" -ge 1 ]; then
    # If at least one str2str instance is found, check for either 2 instances or an ntripserver
    if [ "$(pgrep -c str2str)" -ge 2 ] || [ "$(pgrep -c ntripserver)" -ge 1 ]; then
        # Conditions met, exit with success (healthy)
        exit 0
    fi
fi

# If the conditions are not met, exit with error (unhealthy)
exit 1
