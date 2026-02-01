# Camera Setup Guide

This robot tank uses rpicam-apps with a custom Ruby MJPEG server for camera streaming on Raspberry Pi.

## Quick Start

### Installation
```bash
./scripts/native-install.sh
```

This installs:
- `rpicam-apps` - Official Raspberry Pi camera software
- Ruby MJPEG HTTP server - Multi-client browser streaming
- Systemd service for automatic streaming

### Service Management
```bash
# Start the stream
sudo systemctl start rpicam-stream

# Stop the stream
sudo systemctl stop rpicam-stream

# Check status
sudo systemctl status rpicam-stream

# View logs
sudo journalctl -u rpicam-stream -f
```

### Accessing the Stream

**Web Interface** (Recommended):
```
http://<raspberry-pi-ip>:4567
```
The robot control panel includes the camera stream.

**Direct Camera Stream**:
```
http://<raspberry-pi-ip>:8081
```
MJPEG stream compatible with any browser.

## Architecture Overview

The streaming system uses three components:

1. **rpicam-vid**: Captures video from Pi Camera, encodes to MJPEG
2. **Named Pipe (FIFO)**: Transfers frames between processes
3. **Ruby MJPEG Server**: Serves HTTP multipart stream to browsers

```
Camera → rpicam-vid → FIFO → Ruby Server → HTTP → Browser(s)
```

For detailed architecture, troubleshooting, and advanced configuration, see:
**[VIDEO_STREAMING.md](VIDEO_STREAMING.md)** - Comprehensive streaming documentation

## Configuration

### Stream Settings

Default configuration in `scripts/rpicam-stream.service`:
- **Resolution**: 640x480
- **Framerate**: 15 FPS
- **Codec**: MJPEG
- **Quality**: 85
- **Port**: 8081 (HTTP)

### Changing Settings

Edit the service file after installation:
```bash
sudo nano /etc/systemd/system/rpicam-stream.service
```

Modify rpicam-vid parameters:
```bash
--width 1280 --height 720  # Change resolution
--framerate 30              # Change framerate
--quality 95                # Change JPEG quality
```

After editing:
```bash
sudo systemctl daemon-reload
sudo systemctl restart rpicam-stream
```

**Note**: Higher resolution/framerate requires more CPU and bandwidth.

## Testing the Camera

### 1. Check Camera Detection
```bash
rpicam-hello --list-cameras
```

Expected output:
```
Available cameras
-----------------
0 : imx219 [3280x2464] (/base/soc/i2c0mux/i2c@1/imx219@10)
```

### 2. Take a Test Photo
```bash
rpicam-still -o test.jpg
```

### 3. Test Video Stream
```bash
# Start the streaming service
sudo systemctl start rpicam-stream

# Test in browser
# Open: http://<raspberry-pi-ip>:8081

# Or test with curl
curl -v http://localhost:8081 | head -c 1000 | xxd
```

You should see JPEG markers (`ff d8` start, `ff d9` end) in the output.

## Troubleshooting

### Camera Not Detected
```bash
# Check camera connection
rpicam-hello --list-cameras

# Enable camera interface
sudo raspi-config
# → Interface Options → Camera → Enable

# Reboot
sudo reboot
```

### Stream Shows "Camera stream unavailable"
```bash
# Check if service is running
sudo systemctl status rpicam-stream

# View error logs
sudo journalctl -u rpicam-stream -n 50

# Check if Ruby server is listening
sudo netstat -tulpn | grep 8081

# Restart the service
sudo systemctl restart rpicam-stream
```

### Stream Freezes After 1 Second
This was a known issue, now fixed. If you experience this:
```bash
# Pull latest changes
git pull

# Update the service
sudo cp scripts/rpicam-stream.service /etc/systemd/system/
sudo cp scripts/mjpeg-server.rb /home/pi/robot/scripts/
sudo systemctl daemon-reload
sudo systemctl restart rpicam-stream
```

### Permission Issues
```bash
# Add user to video group
sudo usermod -a -G video $USER

# Log out and back in for changes to take effect
```

### Low FPS or Laggy Stream
Reduce resolution or quality for better performance on Pi Zero 2W:

Edit `/etc/systemd/system/rpicam-stream.service`:
```bash
--width 320 --height 240    # Lower resolution
--framerate 10               # Lower framerate
--quality 75                 # Lower quality
```

Then:
```bash
sudo systemctl daemon-reload
sudo systemctl restart rpicam-stream
```

## Performance Recommendations

### Raspberry Pi Zero 2W (512MB RAM)
- **Recommended**: 640x480 @ 15fps, quality 85
- **Low CPU**: 320x240 @ 10fps, quality 75
- **Clients**: Up to 5 simultaneous browsers

### Raspberry Pi 4/5
- **High Quality**: 1280x720 @ 30fps, quality 95
- **Full HD**: 1920x1080 @ 15fps, quality 85
- **Clients**: 10+ simultaneous browsers

## Hardware Configuration

### Camera Module Support
- Raspberry Pi Camera Module v1 (OV5647) ✅
- Raspberry Pi Camera Module v2 (IMX219) ✅
- Raspberry Pi Camera Module v3 (IMX708) ✅
- Raspberry Pi HQ Camera (IMX477) ✅

### Boot Configuration
Camera interface is enabled via `raspi-config`. Manual configuration in `/boot/firmware/config.txt`:
```
camera_auto_detect=1
```

No additional configuration needed for modern Raspberry Pi OS.

## What Changed from Motion

Previously, this project used Motion for camera streaming. We migrated to rpicam-apps because:

- **Native support**: Official Raspberry Pi camera software
- **Better performance**: Hardware-accelerated encoding
- **Modern codebase**: Active development and support
- **Browser compatibility**: HTTP MJPEG works in all browsers
- **Multi-client**: Ruby server handles multiple simultaneous viewers

### Migration Steps

If upgrading from Motion:

1. **Stop Motion service**:
   ```bash
   sudo systemctl stop motion
   sudo systemctl disable motion
   ```

2. **Run native-install.sh** (installs rpicam and new service):
   ```bash
   ./scripts/native-install.sh
   ```

3. **Update camera URL** in `config/settings.yml`:
   ```yaml
   camera_url: 'http://localhost:8081'
   ```

4. **Reboot**:
   ```bash
   sudo reboot
   ```

The old `scripts/motion.conf` file can be removed.

## Advanced Topics

For advanced configuration and troubleshooting, see:
- **[VIDEO_STREAMING.md](VIDEO_STREAMING.md)** - Comprehensive architecture documentation
  - Frame synchronization
  - Buffer management
  - Multi-client broadcasting
  - Performance tuning
  - Security considerations

## Additional Resources

- [Raspberry Pi Camera Documentation](https://www.raspberrypi.com/documentation/computers/camera_software.html)
- [rpicam-apps GitHub](https://github.com/raspberrypi/rpicam-apps)
- [libcamera Documentation](https://libcamera.org/docs/)
- [MJPEG Streaming Protocol](https://en.wikipedia.org/wiki/Motion_JPEG#M-JPEG_over_HTTP)
