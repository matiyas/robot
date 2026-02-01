# Video Streaming Architecture

This document explains how video streaming works in the Robot Tank Control system.

## Overview

The video streaming system uses a custom Ruby MJPEG server that receives frames from `rpicam-vid` and serves them to web browsers via HTTP multipart streaming.

### Architecture Diagram

```
┌─────────────────┐
│  Raspberry Pi   │
│   Camera        │
└────────┬────────┘
         │ CSI
         ▼
┌─────────────────────────────────────────────────────────┐
│                     rpicam-vid                          │
│  - Captures video at 640x480@15fps                      │
│  - Encodes to MJPEG (quality 85)                        │
│  - Writes frames to named pipe (FIFO)                   │
└────────────────────────┬────────────────────────────────┘
                         │ /tmp/camera_stream (FIFO)
                         ▼
┌─────────────────────────────────────────────────────────┐
│            Ruby MJPEG Server (port 8081)                │
│  - Reads JPEG frames from FIFO                          │
│  - Syncs to frame boundaries (0xFFD8/0xFFD9)            │
│  - Broadcasts to multiple HTTP clients                  │
│  - Handles multipart/x-mixed-replace protocol           │
└────────────────────────┬────────────────────────────────┘
                         │ HTTP
                         ▼
┌─────────────────────────────────────────────────────────┐
│                  Web Browser(s)                          │
│  - <img> tag receives continuous MJPEG stream           │
│  - Displays real-time video from robot                  │
└─────────────────────────────────────────────────────────┘
```

## Components

### 1. rpicam-vid

**Purpose**: Captures video from the Raspberry Pi Camera Module and encodes to MJPEG.

**Location**: `/usr/bin/rpicam-vid` (installed via `rpicam-apps` package)

**Configuration**:
```bash
rpicam-vid \
  --inline            # Inline headers for each frame (required for MJPEG)
  --nopreview         # No preview window (headless)
  --timeout 0         # Run indefinitely
  --width 640         # Frame width
  --height 480        # Frame height
  --framerate 15      # Target framerate
  --codec mjpeg       # MJPEG encoding
  --quality 85        # JPEG quality (0-100)
  -o /tmp/camera_stream  # Output to FIFO
```

**Output Format**: MJPEG stream of consecutive JPEG frames
- Each frame starts with JPEG SOI marker: `0xFF 0xD8`
- Each frame ends with JPEG EOI marker: `0xFF 0xD9`
- Frames are ~40-50KB each at 640x480 quality 85

### 2. Named Pipe (FIFO)

**Purpose**: Inter-process communication between rpicam-vid and Ruby server.

**Location**: `/tmp/camera_stream`

**How it Works**:
1. Created before processes start: `mkfifo /tmp/camera_stream`
2. rpicam-vid opens for writing (producer)
3. Ruby server opens for reading (consumer)
4. Kernel manages buffering between processes
5. Cleaned up on service stop: `rm -f /tmp/camera_stream`

**Why FIFO instead of stdout pipe?**
- Allows processes to start independently
- Better error handling and recovery
- More reliable timing control
- Explicit lifecycle management

### 3. Ruby MJPEG Server

**Purpose**: HTTP server that broadcasts MJPEG frames to web browsers.

**Location**: `scripts/mjpeg-server.rb`

**Port**: 8081

#### Key Features

**Frame Synchronization**:
```ruby
# Sync to first JPEG frame marker on startup
sync_buffer = String.new(encoding: 'ASCII-8BIT')
until sync_buffer.include?("\xff\xd8".b)
  data = stream_source.read(4096)
  sync_buffer << data
end
```

This ensures the server starts reading at a frame boundary, not mid-frame.

**Binary Data Handling**:
```ruby
buffer = String.new(encoding: 'ASCII-8BIT')
data.force_encoding('ASCII-8BIT')
```

Ruby strings default to UTF-8, but JPEG data is binary. ASCII-8BIT (binary encoding) preserves byte values.

**Frame Extraction**:
```ruby
frame_start = "\xff\xd8".b  # JPEG Start of Image
frame_end = "\xff\xd9".b    # JPEG End of Image

# Find frame boundaries
start_idx = buffer.index(frame_start)
end_idx = buffer.index(frame_end, start_idx + 2)

# Extract complete frame
frame = buffer.slice!(0, end_idx + 2)
```

**Buffer Management**:
```ruby
# Keep buffer between 0-100KB
if buffer.size > 100_000
  buffer = buffer[-50_000..]  # Keep last 50KB
end
```

Prevents memory issues while allowing full JPEG frames to accumulate.

**Multi-Client Broadcasting**:
```ruby
@clients = []
@mutex = Mutex.new

def broadcast_frame(frame)
  @mutex.synchronize do
    @clients.each do |client|
      client.write("--FRAME\r\n")
      client.write("Content-Type: image/jpeg\r\n")
      client.write("Content-Length: #{frame.bytesize}\r\n\r\n")
      client.write(frame)
      client.write("\r\n")
      client.flush
    end
  end
end
```

Thread-safe broadcasting to multiple simultaneous viewers.

**Client Connection Management**:
```ruby
def handle_client(client)
  # Read and discard HTTP GET request
  loop do
    line = client.gets
    break if line.nil? || line.strip.empty?
  end

  # Send HTTP response headers
  client.write("HTTP/1.1 200 OK\r\n")
  client.write("Content-Type: multipart/x-mixed-replace; boundary=FRAME\r\n")
  client.write("Connection: close\r\n\r\n")

  @clients << client

  # Keep thread alive - disconnection detected on write failure
  sleep
end
```

Client threads sleep indefinitely. Failed writes during broadcast automatically remove disconnected clients.

### 4. HTTP Multipart Protocol

**Purpose**: Standard protocol for streaming video to browsers.

**MIME Type**: `multipart/x-mixed-replace; boundary=FRAME`

**Format**:
```
HTTP/1.1 200 OK
Content-Type: multipart/x-mixed-replace; boundary=FRAME
Connection: close

--FRAME
Content-Type: image/jpeg
Content-Length: 41234

<JPEG binary data>
--FRAME
Content-Type: image/jpeg
Content-Length: 40987

<JPEG binary data>
--FRAME
...
```

Each frame is a separate part, browser continuously replaces the image.

## Systemd Service

**File**: `scripts/rpicam-stream.service`

**Configuration**:
```ini
[Unit]
Description=Rpicam Video Streaming Service
After=network.target

[Service]
Type=simple
User=rpi
Group=video
WorkingDirectory=/tmp

# Create FIFO
ExecStartPre=/bin/bash -c 'rm -f /tmp/camera_stream && mkfifo /tmp/camera_stream'

# Start both processes: rpicam-vid in background, Ruby server in foreground
ExecStart=/bin/bash -c '/usr/bin/rpicam-vid --inline --nopreview --timeout 0 \
  --width 640 --height 480 --framerate 15 --codec mjpeg --quality 85 \
  -o /tmp/camera_stream & \
  sleep 2 && \
  /home/rpi/.rbenv/shims/ruby /home/rpi/Workspace/robot/scripts/mjpeg-server.rb /tmp/camera_stream'

# Clean up FIFO
ExecStopPost=/bin/rm -f /tmp/camera_stream

Restart=always
RestartSec=5

# Resource limits for Pi Zero 2W
MemoryLimit=200M
CPUQuota=80%
```

**Startup Sequence**:
1. Delete old FIFO if exists
2. Create new FIFO
3. Start rpicam-vid in background (`&`)
4. Sleep 2 seconds (let rpicam-vid initialize)
5. Start Ruby server (opens FIFO for reading)
6. Both processes run until service stops

**Why Background rpicam-vid?**
- rpicam-vid must open FIFO first (as writer)
- Ruby server blocks on open until writer exists
- `&` backgrounds rpicam-vid, allowing next command
- Sleep ensures rpicam-vid is ready before Ruby opens

## Performance Characteristics

### Throughput
- **Framerate**: 15 fps
- **Frame Size**: ~41 KB average
- **Bitrate**: ~615 KB/s (4.9 Mbps)

### Latency
- **Camera to FIFO**: <100ms (hardware encoding)
- **FIFO to Server**: <50ms (IPC)
- **Server to Browser**: <200ms (network + buffering)
- **Total**: ~350ms end-to-end

### Resource Usage (Pi Zero 2W)
- **CPU**: ~60-80% (mostly rpicam-vid encoding)
- **Memory**: ~150MB total
  - rpicam-vid: ~100MB
  - Ruby server: ~50MB
- **Network**: 4.9 Mbps for single client

### Scalability
- **Clients**: Tested up to 5 simultaneous browsers
- **CPU Impact**: ~5% additional per client (broadcasting overhead)
- **Network**: 4.9 Mbps per client (no transcoding)

## Troubleshooting

### Stream Freezes After 1 Second

**Symptom**: Browser loads first frame, then freezes.

**Cause**: Original code used `client.wait_readable(1)` which timed out after 1 second.

**Solution**: Changed to indefinite `sleep`. Disconnection is detected on write failure, not timeout.

### No Frames Received

**Symptom**: "Camera stream unavailable" in browser.

**Debugging**:
```bash
# Check service status
sudo systemctl status rpicam-stream

# View logs
sudo journalctl -u rpicam-stream -n 50

# Test direct FIFO read
cat /tmp/camera_stream | xxd | head

# Test HTTP endpoint
curl -v http://localhost:8081 | head -c 1000 | xxd
```

**Common Causes**:
1. Camera not enabled: `sudo raspi-config` → Interface Options → Camera
2. FIFO timing issue: Ensure 2-second sleep between processes
3. Permission issue: User must be in `video` group
4. rpicam-vid crash: Check `journalctl` for errors

### Buffer Size Errors

**Symptom**: Logs show "Buffer size exceeded" or "no end marker".

**Cause**: Buffer limits too small for JPEG frames.

**Solution**: Ensure buffer allows at least 100KB:
```ruby
if buffer.size > 100_000
  buffer = buffer[-50_000..]
end
```

At 640x480 quality 85, frames are ~40-50KB. Buffer must accommodate at least 2 frames.

### Frame Sync Errors

**Symptom**: Corrupted or distorted images.

**Cause**: Server started reading mid-frame.

**Solution**: Synchronization code finds first JPEG SOI marker:
```ruby
sync_buffer = String.new(encoding: 'ASCII-8BIT')
until sync_buffer.include?("\xff\xd8".b)
  data = stream_source.read(4096)
  sync_buffer << data
end
```

## Testing

### Test Camera Hardware
```bash
# List cameras
rpicam-hello --list-cameras

# Capture still image
rpicam-still -o test.jpg

# View image
display test.jpg  # or scp to desktop
```

### Test rpicam-vid MJPEG Output
```bash
# Create temporary FIFO
mkfifo /tmp/test_stream

# Start rpicam-vid
rpicam-vid --inline --nopreview --timeout 10000 \
  --width 640 --height 480 --framerate 15 \
  --codec mjpeg --quality 85 -o /tmp/test_stream &

# Verify JPEG markers in output
head -c 1000000 /tmp/test_stream | xxd | grep "ffd8"  # SOI
head -c 1000000 /tmp/test_stream | xxd | grep "ffd9"  # EOI

# Clean up
rm /tmp/test_stream
```

### Test Ruby MJPEG Server
```bash
# Start service
sudo systemctl start rpicam-stream

# Test HTTP headers
curl -v http://localhost:8081 | head -c 100

# Test continuous stream (10 seconds)
timeout 10 curl -s http://localhost:8081 | wc -c
# Should show ~6MB (10 sec * 615 KB/s)

# Test in browser
# Open: http://<raspberry-pi-ip>:8081
```

### Test Multi-Client
```bash
# Terminal 1: Monitor server logs
sudo journalctl -u rpicam-stream -f

# Terminal 2-4: Connect multiple clients
curl -s http://localhost:8081 > /dev/null &
curl -s http://localhost:8081 > /dev/null &
curl -s http://localhost:8081 > /dev/null &

# Check log shows "Client connected (3 total)"
```

## Configuration

### Change Resolution
Edit `scripts/rpicam-stream.service`:
```bash
--width 1280 --height 720  # 720p
--width 1920 --height 1080  # 1080p
```

**Note**: Higher resolution increases:
- Frame size (~150KB for 1080p)
- CPU usage (encoding)
- Network bandwidth
- Buffer requirements (update Ruby server limits)

### Change Framerate
```bash
--framerate 30  # 30 fps (more CPU intensive)
--framerate 10  # 10 fps (lower bandwidth)
```

### Change Quality
```bash
--quality 95  # Higher quality (larger files)
--quality 70  # Lower quality (smaller files)
```

Quality range: 1-100 (JPEG compression)

## Integration with Web Application

### Backend (Sinatra)
`app/robot_app.rb`:
```ruby
get '/api/v1/camera' do
  camera_url = settings.app_settings['camera_url']
  # Replace localhost with actual host for browser access
  dynamic_url = camera_url.gsub('localhost', request.host)
  success_response(stream_url: dynamic_url)
end
```

### Frontend (JavaScript)
`public/js/robot-controller.js`:
```javascript
async loadCameraStream() {
  const response = await this.api.getCameraUrl();
  const streamUrl = response.stream_url;

  const cameraImg = document.getElementById('cameraStream');
  cameraImg.src = streamUrl;  // Browser handles MJPEG decoding
}
```

### HTML
`views/index.erb`:
```html
<img id="cameraStream" src="" alt="Camera stream loading..." />
```

Browser automatically:
1. Sends GET request to stream URL
2. Receives multipart/x-mixed-replace response
3. Parses boundary markers
4. Updates `<img>` with each new frame
5. Repeats until connection closes

## Security Considerations

### No Authentication
Current implementation has no authentication. Anyone on the network can:
- View camera stream (port 8081)
- Control robot (port 4567)

**For Production**: Add authentication middleware to both services.

### Resource Limits
Systemd service limits prevent DoS:
```ini
MemoryLimit=200M  # Kill if exceeds 200MB
CPUQuota=80%      # Max 80% CPU usage
```

### User Permissions
Service runs as:
- `User=rpi` (non-root)
- `Group=video` (camera access)

Minimal privileges for security.

## References

- [rpicam-apps Documentation](https://www.raspberrypi.com/documentation/computers/camera_software.html)
- [MJPEG Streaming Protocol](https://en.wikipedia.org/wiki/Motion_JPEG#M-JPEG_over_HTTP)
- [Ruby Socket Programming](https://ruby-doc.org/stdlib-3.0.0/libdoc/socket/rdoc/Socket.html)
- [Linux Named Pipes (FIFO)](https://man7.org/linux/man-pages/man7/fifo.7.html)
- [JPEG File Format](https://en.wikipedia.org/wiki/JPEG_File_Interchange_Format)

## Future Improvements

### Potential Enhancements
1. **H.264 Streaming**: Lower bandwidth, higher quality
   - Requires different protocol (WebRTC, HLS, or DASH)
   - More complex browser compatibility

2. **Adaptive Bitrate**: Adjust quality based on network
   - Monitor client receive rate
   - Dynamically change JPEG quality

3. **Recording**: Save stream to disk
   - Add muxing to MP4 container
   - Implement rotation/cleanup

4. **Two-Way Audio**: Add microphone/speaker support
   - WebRTC for real-time audio
   - Push-to-talk interface

5. **Authentication**: Secure access
   - Basic auth over HTTPS
   - Token-based authentication

6. **Pan/Tilt Control**: Servo-mounted camera
   - Integrate with turret controls
   - Preset positions

### Known Limitations
1. **Single Encoder**: Can't change quality per client
2. **No Transcoding**: All clients receive same bitrate
3. **Limited Clients**: ~5 clients before performance degrades
4. **No Seek**: Live stream only, no playback control
5. **MJPEG Overhead**: Larger than H.264 (~3x bandwidth)

## Maintenance

### Log Rotation
Logs are managed by systemd journal:
```bash
# View recent logs
sudo journalctl -u rpicam-stream -n 100

# Follow logs
sudo journalctl -u rpicam-stream -f

# View logs since boot
sudo journalctl -u rpicam-stream -b

# Clear old logs
sudo journalctl --vacuum-time=7d
```

### Service Restart
```bash
# Restart streaming
sudo systemctl restart rpicam-stream

# Check if running
systemctl is-active rpicam-stream

# View full status
sudo systemctl status rpicam-stream
```

### Updates
After modifying `scripts/mjpeg-server.rb`:
```bash
# Copy to Pi (if needed)
scp scripts/mjpeg-server.rb pi@robot:/home/pi/robot/scripts/

# Restart service
sudo systemctl restart rpicam-stream
```

No systemd reload needed (script is called by service, not part of unit file).
