#!/bin/bash
set -e

# Docker entrypoint script for robot application

echo "Starting Robot Tank Application..."
echo "Environment: ${RACK_ENV}"
echo "Port: ${PORT:-4567}"

# Create logs directory if it doesn't exist
mkdir -p /app/logs

# Wait for any dependencies (if needed in future)
# For now, just start the application

# Start rpicam streaming in background if camera device is available
if [ -e /dev/video0 ] && [ "${RACK_ENV}" = "production" ]; then
  echo "Camera device detected, starting rpicam streaming..."
  rpicam-vid --inline --nopreview --timeout 0 --width 640 --height 480 --framerate 15 --codec mjpeg --quality 85 --listen -o tcp://0.0.0.0:8081 &
fi

# Execute the main command
exec "$@"
