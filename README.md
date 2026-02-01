# Robot Tank Control

A web-based control system for a robot tank running on Raspberry Pi Zero 2W. Features real-time camera streaming, GPIO motor control via DRV8833 drivers, and a mobile-responsive control panel.

## Features

- **Web Control Panel**: Responsive UI that works on desktop and mobile devices
- **Real-time Camera Streaming**: MJPEG streaming from CSI camera module
- **JSON API**: RESTful API for mobile app integration (iOS/Android)
- **GPIO Motor Control**: DRV8833 dual H-bridge motor drivers for 3 motors
- **Safety Mechanisms**: Auto-stop, emergency stop, and graceful shutdown
- **Development Mode**: Mock controller for testing without GPIO hardware
- **Future-Ready**: Abstracted control interface for GamePad support and PWM speed control

## Hardware Requirements

- Raspberry Pi Zero 2W
- 2x DRV8833 dual H-bridge motor driver boards
- 3x 3V brush motors class 130 (2 wheels + 1 turret)
- CSI camera module (ribbon cable)
- Power supply and battery for motors
- Robot tank chassis

## GPIO Pin Configuration

| Motor | Function | GPIO Pin (BCM) | DRV8833 Pin |
|-------|----------|----------------|-------------|
| Left Wheel | Forward | GPIO 17 | IN1 |
| Left Wheel | Backward | GPIO 18 | IN2 |
| Right Wheel | Forward | GPIO 22 | IN1 |
| Right Wheel | Backward | GPIO 23 | IN2 |
| Turret | Left Rotation | GPIO 27 | IN1 |
| Turret | Right Rotation | GPIO 24 | IN2 |

*Note: GPIO 12, 13, and 19 are reserved for future PWM speed control*

## Installation

There are two ways to install and run the robot tank controller:

1. **Docker** (Recommended) - Containerized, isolated, easy deployment
2. **Native** - Direct installation on Raspberry Pi OS

### Quick Start Comparison

| Method | Best For | Pros | Cons |
|--------|----------|------|------|
| **Docker** | Multi-service setups, reproducible deployments | Isolated, portable, easy updates | Slightly more resources, initial setup |
| **Native** | Dedicated robot controller, maximum performance | Direct GPIO, less overhead, simpler debugging | System-wide installation |

---

## Option 1: Docker Installation (Recommended)

### Prerequisites
- Docker and Docker Compose installed on Raspberry Pi
- Raspberry Pi Zero 2W with Raspberry Pi OS (ARM64)

### Installation Steps

```bash
# 1. Clone repository
cd ~
git clone https://github.com/matiyas/robot.git
cd robot

# 2. Run deployment script
./scripts/docker-deploy-pi.sh

# 3. Access the robot
# Open browser to http://<RASPBERRY_PI_IP>
```

### Quick Commands

```bash
# Start (development mode - no GPIO)
make dev

# Start (production mode - with GPIO)
make prod

# View logs
make logs

# Stop
make down

# Access shell
make shell
```

### Detailed Documentation

See **[DOCKER.md](docs/DOCKER.md)** for comprehensive Docker documentation including:
- Complete setup guide
- Configuration options
- Troubleshooting
- Performance tuning
- CI/CD integration

---

## Option 2: Native Installation

### Prerequisites
- Raspberry Pi Zero 2W with Raspberry Pi OS (ARM64)
- Internet connection

### Automated Installation

```bash
# 1. Clone repository
cd ~
git clone https://github.com/matiyas/robot.git
cd robot

# 2. Run installation script
chmod +x scripts/native-install.sh
./scripts/native-install.sh

# 3. Reboot (required)
sudo reboot

# 4. Start the service
sudo systemctl start robot
```

### Manual Installation Steps

If you prefer step-by-step installation:

#### 1. Update System
```bash
sudo apt-get update
sudo apt-get upgrade -y
```

#### 2. Install Dependencies
```bash
sudo apt-get install -y \
    build-essential \
    git \
    curl \
    libssl-dev \
    libreadline-dev \
    zlib1g-dev \
    libffi-dev \
    libyaml-dev \
    pkg-config \
    motion \
    v4l-utils
```

#### 3. Install rbenv and Ruby
```bash
# Install rbenv
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc

# Install ruby-build
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build

# Reload shell
source ~/.bashrc

# Install Ruby from .ruby-version
cd ~/robot
rbenv install $(cat .ruby-version)
rbenv global $(cat .ruby-version)
```

#### 4. Install Bundler and Gems
```bash
gem install bundler
rbenv rehash
cd ~/robot
bundle config set --local without 'development test'
bundle install
```

#### 5. Configure Services
```bash
# Copy motion config
sudo cp scripts/motion.conf /etc/motion/motion.conf

# Install systemd service
ROBOT_DIR=$(pwd)
sed "s|/home/pi/robot|$ROBOT_DIR|g" scripts/robot.service | \
    sudo tee /etc/systemd/system/robot.service > /dev/null

# Enable services
sudo systemctl daemon-reload
sudo systemctl enable robot motion
```

#### 6. Set Permissions
```bash
sudo usermod -a -G video $USER
sudo usermod -a -G gpio $USER
```

#### 7. Reboot
```bash
sudo reboot
```

### Testing Native Installation

```bash
# Test installation
./scripts/test-native-setup.sh

# Check service status
sudo systemctl status robot

# View logs
sudo journalctl -u robot -f
```

### Detailed Native Installation Documentation

See **[NATIVE_INSTALLATION.md](docs/NATIVE_INSTALLATION.md)** for comprehensive guide including:
- Detailed installation steps
- Configuration options
- Performance optimization
- Troubleshooting
- Uninstallation

---

## Quick Reference: System Dependencies

Based on tested Docker configuration, here's what gets installed:

```bash
# Core packages (required)
build-essential # GCC, G++, make (for Ruby compilation)
git             # Version control
curl            # HTTP client
libssl-dev      # OpenSSL headers (required for Ruby and gems)
libreadline-dev # Readline library (required for Ruby)
zlib1g-dev      # Compression library (required for Ruby)
libffi-dev      # FFI library (required for Ruby fiddle extension)
libyaml-dev     # YAML library (required for Ruby psych extension)
pkg-config      # Package configuration

# Ruby version management
rbenv           # Ruby version manager (installed via git)
ruby-build      # rbenv plugin for installing Ruby

# Application packages
motion          # Camera streaming
v4l-utils       # Camera utilities

# Ruby gems (installed via bundler)
puma            # Web server
sinatra         # Web framework
pi_piper        # GPIO control
```

**Note**: Ruby is installed via rbenv using the version specified in `.ruby-version` (currently 3.2.2)

---

## Verification

After installation (Docker or Native), verify it's working:

```bash
# Check health
curl http://<PI_IP_ADDRESS>/health

# Check status
curl http://<PI_IP_ADDRESS>/api/v1/status

# Test movement
curl -X POST http://<PI_IP_ADDRESS>/api/v1/move \
  -H "Content-Type: application/json" \
  -d '{"direction":"forward","duration":1000}'

# Access web interface
# Open browser to http://<PI_IP_ADDRESS>
```

## Development

### Local Development (Without GPIO)

You can develop and test the application on your computer without GPIO hardware:

```bash
bundle install
bundle exec ruby app/robot_app.rb
```

The app will run in development mode using MockController. Access at `http://localhost:4567`

### Auto-reload in Development

```bash
bundle exec rerun ruby app/robot_app.rb
```

### Test API Endpoints

```bash
# Check status
curl http://localhost:4567/api/v1/status

# Move forward for 1 second
curl -X POST http://localhost:4567/api/v1/move \
  -H "Content-Type: application/json" \
  -d '{"direction":"forward","duration":1000}'

# Emergency stop
curl -X POST http://localhost:4567/api/v1/stop
```

## API Documentation

### Base URL

Production: `http://<PI_IP_ADDRESS>`
Development: `http://localhost:4567`

### Endpoints

#### Move Robot

```http
POST /api/v1/move
Content-Type: application/json

{
  "direction": "forward|backward|left|right",
  "duration": 1000  // milliseconds (optional)
}
```

**Response:**
```json
{
  "success": true,
  "action": "forward",
  "duration": 1000
}
```

#### Control Turret

```http
POST /api/v1/turret
Content-Type: application/json

{
  "direction": "left|right",
  "duration": 500  // milliseconds (optional)
}
```

**Response:**
```json
{
  "success": true,
  "action": "turret_left",
  "duration": 500
}
```

#### Emergency Stop

```http
POST /api/v1/stop
```

**Response:**
```json
{
  "success": true,
  "action": "stop_all"
}
```

#### Get Status

```http
GET /api/v1/status
```

**Response:**
```json
{
  "success": true,
  "connected": true,
  "gpio_enabled": true,
  "camera_url": "http://192.168.1.100:8081/stream"
}
```

#### Get Camera URL

```http
GET /api/v1/camera
```

**Response:**
```json
{
  "success": true,
  "stream_url": "http://192.168.1.100:8081/stream"
}
```

### Error Responses

All endpoints return error responses in this format:

```json
{
  "success": false,
  "error": "Error message"
}
```

HTTP status codes:
- `200` - Success
- `400` - Bad request (invalid parameters)
- `401` - Unauthorized (when authentication is enabled)
- `500` - Internal server error

## Configuration

### Application Settings

Edit `config/settings.yml`:

```yaml
production:
  host: '0.0.0.0'
  port: 80
  gpio_enabled: true
  camera_url: 'http://localhost:8081/stream'
  movement_timeout: 5000  # Max movement duration (ms)
  turret_timeout: 2000    # Max turret rotation duration (ms)
  log_level: 'info'
  auth_enabled: false     # Enable authentication (future)
```

### GPIO Pin Mapping

Edit `config/gpio_pins.yml` if your wiring differs:

```yaml
motor_left:
  in1: 17  # Forward
  in2: 18  # Backward
  enable: 12  # Future PWM
```

### Camera Settings

Edit `scripts/motion.conf` to adjust camera settings:

```conf
width 640
height 480
framerate 15
quality 85
stream_port 8081
```

## Usage

### Web Interface

1. Connect to the same WiFi network as your Raspberry Pi
2. Open a browser and navigate to `http://<PI_IP_ADDRESS>`
3. Use the on-screen controls to drive the robot

**Controls:**
- **D-pad**: Forward, backward, left, right
- **Turret buttons**: Rotate turret left/right
- **Emergency Stop**: Immediately stops all motors

### Mobile Apps

Use the JSON API to build custom mobile applications. Example using fetch API:

```javascript
// Move forward for 1 second
fetch('http://PI_IP/api/v1/move', {
  method: 'POST',
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({direction: 'forward', duration: 1000})
})
.then(response => response.json())
.then(data => console.log(data));
```

## Troubleshooting

### Camera Not Working

```bash
# Check camera is detected
vcgencmd get_camera

# Test camera
raspistill -o test.jpg

# Check Motion logs
sudo journalctl -u motion -f

# Restart Motion
sudo systemctl restart motion
```

### Motors Not Responding

```bash
# Check GPIO permissions
groups  # Should include 'gpio'

# Test GPIO pins
gpio readall  # If wiringPi installed

# Check app logs
sudo journalctl -u robot -f
```

### Service Won't Start

```bash
# Check service status
sudo systemctl status robot

# View detailed logs
sudo journalctl -u robot -n 50

# Restart service
sudo systemctl restart robot
```

### High CPU Usage

```bash
# Check resource usage
top -b -n 1 | grep -E "ruby|motion"

# Reduce camera quality in motion.conf:
# width 640 -> 480
# framerate 15 -> 10
# quality 85 -> 75
```

## Project Structure

```
robot/
├── app/
│   ├── robot_app.rb              # Main Sinatra application
│   ├── models/
│   │   └── robot.rb              # Robot control model
│   ├── services/
│   │   ├── control_interface.rb  # Abstract controller
│   │   ├── gpio_controller.rb    # GPIO implementation
│   │   └── mock_controller.rb    # Development mock
│   └── helpers/
│       └── api_helpers.rb        # API utilities
├── lib/
│   ├── gpio_manager.rb           # GPIO lifecycle
│   └── safety_handler.rb         # Safety mechanisms
├── public/
│   ├── css/style.css             # Responsive styles
│   └── js/
│       ├── api-client.js         # API wrapper
│       └── robot-controller.js   # UI controller
├── views/
│   ├── layout.erb                # HTML layout
│   └── index.erb                 # Control panel
├── config/
│   ├── settings.yml              # App configuration
│   └── gpio_pins.yml             # GPIO mappings
└── scripts/
    ├── setup.sh                  # Installation script
    ├── motion.conf               # Camera config
    └── robot.service             # Systemd service
```

## Future Enhancements

- [ ] PWM speed control for variable motor speeds
- [ ] GamePad controller support (USB or Bluetooth)
- [ ] Authentication (HTTP Basic Auth or JWT)
- [ ] Battery voltage monitoring
- [ ] Ultrasonic distance sensors
- [ ] IMU for orientation tracking
- [ ] Recording and playback of movement sequences
- [ ] Autonomous navigation modes

## Architecture

The project uses a clean abstraction layer that separates hardware control from business logic:

- **ControlInterface**: Abstract base class defining control methods
- **GpioController**: Hardware implementation using pi_piper gem
- **MockController**: Development implementation for testing
- **Robot Model**: High-level orchestration and business logic
- **Sinatra App**: HTTP API and web interface

This architecture makes it easy to:
- Test without hardware
- Swap control implementations (GPIO → GamePad)
- Add authentication
- Extend with new features

## Contributing

Pull requests are welcome! Please follow these guidelines:

1. Test in development mode first
2. Ensure backward compatibility
3. Update documentation
4. Follow existing code style

## License

MIT License - feel free to use this project for your own robot!

## Safety

- Always test in a safe environment
- Keep the emergency stop button accessible
- Monitor battery levels
- Use appropriate voltage regulators
- Ensure proper motor driver heat dissipation

## Credits

- Built with [Sinatra](http://sinatrarb.com/)
- GPIO control via [pi_piper](https://github.com/jwhitehorn/pi_piper)
- Camera streaming via [Motion](https://motion-project.github.io/)
- Runs on [Raspberry Pi](https://www.raspberrypi.org/)

## Support

For issues, questions, or suggestions:
- Open an issue on GitHub
- Check the troubleshooting section above
- Review system logs: `sudo journalctl -u robot -f`
