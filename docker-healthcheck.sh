#!/bin/bash
# Health check script for robot container

set -e

# Determine the correct port based on RACK_ENV
if [ "${RACK_ENV}" = "production" ]; then
    PORT=80
else
    PORT=4567
fi

# Check if the application is responding
if curl -f -s "http://localhost:${PORT}/health" > /dev/null 2>&1; then
    exit 0
else
    exit 1
fi
