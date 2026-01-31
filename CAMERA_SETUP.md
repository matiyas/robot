# Camera Setup Guide

This robot tank uses rpicam-apps (libcamera) for camera streaming on Raspberry Pi.

## What Changed from Motion

Previously, this project used Motion for camera streaming. We've migrated to rpicam-apps because:

- **Native support**: rpicam-apps is the official Raspberry Pi camera software
- **Better performance**: Optimized for Raspberry Pi hardware
- **Modern codebase**: Active development and support
- **CSI camera support**: Direct support for Raspberry Pi Camera Module v2 and v3

## Installation

The camera streaming is automatically installed by the setup scripts:

### Native Installation
```bash
./scripts/native-install.sh
```

This installs:
- `rpicam-apps` - Camera utilities and streaming tools
- `ffmpeg` - Video processing support
- Systemd service for automatic streaming

### Docker Installation
```bash
docker-compose -f docker-compose.prod.yml up -d
```

## Camera Streaming Service

The camera stream runs as a systemd service on native installations.

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

### Service Configuration

The service is defined in `scripts/rpicam-stream.service`:

- **Resolution**: 640x480
- **Framerate**: 15 FPS
- **Codec**: MJPEG
- **Quality**: 85
- **Port**: 8081 (TCP)

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

# In another terminal, test the stream
ffplay tcp://localhost:8081
```

## Camera Configuration

### Stream Settings

Edit `/etc/systemd/system/rpicam-stream.service` to change settings:

```ini
ExecStart=/usr/bin/rpicam-vid \
    --inline \
    --nopreview \
    --timeout 0 \
    --width 640 \           # Resolution width
    --height 480 \          # Resolution height
    --framerate 15 \        # Frames per second
    --codec mjpeg \         # Video codec
    --quality 85 \          # JPEG quality (0-100)
    --listen \
    -o tcp://0.0.0.0:8081   # Stream address and port
```

After editing, reload and restart:
```bash
sudo systemctl daemon-reload
sudo systemctl restart rpicam-stream
```

### Hardware Configuration

Camera interface settings in `/boot/firmware/config.txt` or `/boot/config.txt`:

```
camera_auto_detect=1
start_x=1
```

## Accessing the Stream

### From the Robot Web Interface
The web interface automatically displays the camera stream at:
```
http://<raspberry-pi-ip>:4567
```

### From External Applications

**VLC Media Player**:
1. Open VLC
2. Media → Open Network Stream
3. Enter: `tcp://<raspberry-pi-ip>:8081`

**ffmpeg/ffplay**:
```bash
ffplay tcp://<raspberry-pi-ip>:8081
```

**Browser** (requires additional setup):
The TCP stream can't be directly displayed in a browser. For browser viewing, you would need to:
1. Add an HTTP streaming server (like ustreamer)
2. Or convert the TCP stream to HLS/WebRTC

## Troubleshooting

### Camera Not Detected
```bash
# Check camera connection
rpicam-hello --list-cameras

# Check boot config
cat /boot/firmware/config.txt | grep camera

# Reboot if needed
sudo reboot
```

### Stream Not Working
```bash
# Check if service is running
sudo systemctl status rpicam-stream

# View error logs
sudo journalctl -u rpicam-stream -n 50

# Check if port is in use
sudo netstat -tulpn | grep 8081

# Restart the service
sudo systemctl restart rpicam-stream
```

### Permission Issues
```bash
# Add user to video group
sudo usermod -a -G video $USER

# Log out and back in for changes to take effect
```

### Low FPS or Laggy Stream
Try reducing resolution or quality in the service file:
```ini
--width 320 \
--height 240 \
--framerate 10 \
--quality 75 \
```

## Performance Notes

### Raspberry Pi Zero 2W
- **Recommended**: 640x480 @ 15fps, quality 85
- **Low CPU**: 320x240 @ 10fps, quality 75
- **Higher quality**: 640x480 @ 15fps, quality 95 (more CPU usage)

### Raspberry Pi 4/5
- Can handle higher resolutions: 1280x720 @ 30fps
- Better quality settings: quality 95+

## Migration from Motion

If you're upgrading from Motion to rpicam:

1. **Stop Motion service**:
   ```bash
   sudo systemctl stop motion
   sudo systemctl disable motion
   ```

2. **Install rpicam** (done by install script):
   ```bash
   sudo apt-get install rpicam-apps ffmpeg
   ```

3. **Install the new service**:
   ```bash
   sudo cp scripts/rpicam-stream.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable rpicam-stream
   sudo systemctl start rpicam-stream
   ```

4. **Update camera URL** in `config/settings.yml`:
   ```yaml
   camera_url: 'tcp://localhost:8081'
   ```

The old `scripts/motion.conf` file can be removed or kept as reference.

## Additional Resources

- [Raspberry Pi Camera Documentation](https://www.raspberrypi.com/documentation/computers/camera_software.html)
- [rpicam-apps GitHub](https://github.com/raspberrypi/rpicam-apps)
- [libcamera Documentation](https://libcamera.org/docs/)
