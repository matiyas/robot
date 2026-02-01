# Native Installation Guide
## Raspberry Pi Zero 2W with Raspberry Pi OS (ARM64)

This guide provides complete instructions for installing and running the Robot Tank Control application natively (without Docker) on Raspberry Pi Zero 2W.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Installation](#quick-installation)
- [Manual Installation](#manual-installation)
- [Configuration](#configuration)
- [Starting the Application](#starting-the-application)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Uninstallation](#uninstallation)

---

## Prerequisites

### Hardware
- Raspberry Pi Zero 2W
- MicroSD card (16GB+ recommended)
- Power supply (5V 2.5A recommended)
- Camera module (optional, for video streaming)
- GPIO hardware (motors, motor drivers) for production use

### Software
- Raspberry Pi OS (64-bit) - Bookworm or later
- Internet connection for downloading packages
- SSH access or direct console

### Recommended: Fresh Raspberry Pi OS Installation

```bash
# Check your OS version
cat /etc/os-release

# Should show:
# - Debian 12 (Bookworm) or newer
# - 64-bit (aarch64)

# Verify architecture
uname -m
# Should return: aarch64
```

---

## Quick Installation

### One-Command Installation

The easiest way to install is using the automated script:

```bash
# 1. Clone the repository
cd ~
git clone https://github.com/matiyas/robot.git
cd robot

# 2. Run the installation script
chmod +x scripts/native-install.sh
./scripts/native-install.sh

# 3. Reboot (required)
sudo reboot

# 4. After reboot, start the service
sudo systemctl start robot
```

The installation script will:
- ✓ Update system packages
- ✓ Install rbenv (Ruby version manager)
- ✓ Install Ruby via rbenv from .ruby-version
- ✓ Install Motion for camera streaming
- ✓ Install all Ruby gems
- ✓ Configure camera interface
- ✓ Set up systemd services
- ✓ Configure user permissions

**Total installation time: 10-15 minutes** (depending on Pi Zero 2W speed and internet connection)

---

## Manual Installation

If you prefer to install step by step:

### Step 1: Update System

```bash
sudo apt-get update
sudo apt-get upgrade -y
```

### Step 2: Install System Dependencies

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

**Package explanations:**
- `build-essential` - C/C++ compiler and tools (required for Ruby compilation)
- `git` - Version control
- `curl` - HTTP client
- `libssl-dev` - OpenSSL development headers (required for gem compilation)
- `libreadline-dev` - Readline library (required for Ruby compilation)
- `zlib1g-dev` - Compression library (required for Ruby compilation)
- `libffi-dev` - Foreign Function Interface library (required for Ruby fiddle extension)
- `libyaml-dev` - YAML library (required for Ruby psych extension)
- `pkg-config` - Package configuration tool
- `motion` - Camera streaming server
- `v4l-utils` - Video4Linux utilities

### Step 3: Install rbenv

rbenv is a Ruby version manager that allows you to install and manage multiple Ruby versions.

```bash
# Clone rbenv
git clone https://github.com/rbenv/rbenv.git ~/.rbenv

# Add rbenv to your shell
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc

# Clone ruby-build plugin
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build

# Reload shell configuration
source ~/.bashrc
```

### Step 4: Install Ruby via rbenv

The project includes a `.ruby-version` file that specifies the required Ruby version.

```bash
cd ~/robot

# Install the Ruby version specified in .ruby-version
rbenv install $(cat .ruby-version)

# Set it as the global version
rbenv global $(cat .ruby-version)

# Verify Ruby is installed correctly
ruby --version
# Should show the version from .ruby-version
```

**Note**: Installing Ruby from source takes 10-20 minutes on Raspberry Pi Zero 2W.

### Step 5: Install Bundler

```bash
gem install bundler
rbenv rehash
```

### Step 6: Install Ruby Gems

```bash
cd ~/robot

# For production (excludes dev/test gems)
bundle config set --local without 'development test'
bundle install

# For development (includes all gems)
bundle install
```

**Note**: Installing gems on Pi Zero 2W takes 5-10 minutes due to native extension compilation.

### Step 7: Configure Camera (Optional)

#### For Raspberry Pi OS Bookworm (newer)

```bash
# Edit config
sudo nano /boot/firmware/config.txt

# Add these lines if not present:
camera_auto_detect=1
start_x=1
gpu_mem=128
```

#### For older Raspberry Pi OS

```bash
# Edit config
sudo nano /boot/config.txt

# Add these lines:
start_x=1
gpu_mem=128

# Load camera module
sudo modprobe bcm2835_v4l2
echo "bcm2835_v4l2" | sudo tee -a /etc/modules
```

### Step 8: Configure Motion

```bash
# Copy motion configuration
sudo cp scripts/motion.conf /etc/motion/motion.conf

# Enable Motion daemon
sudo sed -i 's/start_motion_daemon=no/start_motion_daemon=yes/' /etc/default/motion

# Enable and start Motion
sudo systemctl enable motion
sudo systemctl start motion
```

### Step 9: Install Systemd Service

```bash
# Copy service file with correct paths
ROBOT_DIR=$(pwd)
sed "s|/home/pi/robot|$ROBOT_DIR|g" scripts/robot.service | \
    sed "s|User=pi|User=$USER|g" | \
    sudo tee /etc/systemd/system/robot.service > /dev/null

# Reload systemd and enable service
sudo systemctl daemon-reload
sudo systemctl enable robot
```

### Step 10: Set User Permissions

```bash
# Add user to required groups
sudo usermod -a -G video $USER
sudo usermod -a -G gpio $USER

# Verify groups
groups
```

**Important**: You must log out and back in (or reboot) for group changes to take effect.

### Step 11: Reboot

```bash
sudo reboot
```

---

## Configuration

### Application Settings

Edit `config/settings.yml`:

```yaml
production:
  host: '0.0.0.0'
  port: 80
  gpio_enabled: true
  camera_url: 'http://localhost:8081/stream'
  movement_timeout: 5000
  turret_timeout: 2000
  log_level: 'info'
```

### GPIO Pin Configuration

Edit `config/gpio_pins.yml` if your wiring differs:

```yaml
motor_left:
  in1: 17  # Forward
  in2: 18  # Backward
  enable: 12  # Future PWM

motor_right:
  in1: 22  # Forward
  in2: 23  # Backward
  enable: 13  # Future PWM

motor_turret:
  in1: 27  # Left rotation
  in2: 24  # Right rotation
  enable: 19  # Future PWM
```

### Motion Configuration

Edit camera settings in `scripts/motion.conf`:

```conf
width 640
height 480
framerate 15
quality 85
stream_port 8081
```

For better performance on Pi Zero 2W, consider:
- Reduce width/height to 480x360
- Lower framerate to 10
- Reduce quality to 75

---

## Starting the Application

### Using Systemd (Recommended for Production)

```bash
# Start the service
sudo systemctl start robot

# Check status
sudo systemctl status robot

# View logs
sudo journalctl -u robot -f

# Enable auto-start on boot
sudo systemctl enable robot

# Stop the service
sudo systemctl stop robot

# Restart the service
sudo systemctl restart robot
```

### Manual Start (for Testing/Development)

#### Production Mode (with GPIO)

```bash
cd ~/robot
RACK_ENV=production bundle exec puma -C config/puma.rb
```

#### Development Mode (without GPIO)

```bash
cd ~/robot
bundle exec ruby app/robot_app.rb
```

Access at:
- Production: `http://<PI_IP_ADDRESS>`
- Development: `http://<PI_IP_ADDRESS>:4567`

---

## Testing

### Test Installation

Run the automated test script:

```bash
cd ~/robot
./scripts/test-native-setup.sh
```

This checks:
- ✓ System commands installed
- ✓ Build tools present
- ✓ Libraries available
- ✓ Ruby gems installed
- ✓ Services configured
- ✓ User permissions
- ✓ Camera and GPIO devices

### Test Camera

```bash
# Check camera detection
libcamera-hello --list-cameras

# Take a test photo
libcamera-still -o test.jpg

# Check Motion service
sudo systemctl status motion

# View Motion stream
curl http://localhost:8081
```

### Test Application

```bash
# Check if service is running
sudo systemctl status robot

# Test health endpoint
curl http://localhost/health

# Test status endpoint
curl http://localhost/api/v1/status

# Test movement (MockController in dev, GPIO in prod)
curl -X POST http://localhost/api/v1/move \
  -H "Content-Type: application/json" \
  -d '{"direction":"forward","duration":1000}'
```

### Test GPIO (Production Only)

```bash
# Check GPIO device
ls -l /dev/gpiomem

# Check GPIO group membership
groups | grep gpio

# Test with GPIO library (in Ruby console)
bundle exec pry
require './app/robot_app'
# Try movement commands
```

---

## Troubleshooting

### Service Won't Start

```bash
# Check detailed logs
sudo journalctl -u robot -n 50

# Check for errors in application
cd ~/robot
bundle exec ruby app/robot_app.rb
# Look for error messages

# Verify gems are installed
bundle check

# Reinstall gems if needed
bundle install
```

### Camera Not Working

```bash
# Check camera is detected
libcamera-hello --list-cameras

# For older Pi OS
raspistill -o test.jpg

# Check Motion logs
sudo journalctl -u motion -f

# Restart Motion
sudo systemctl restart motion

# Check Motion configuration
cat /etc/motion/motion.conf | grep -E "width|height|framerate"

# Check video device
ls -l /dev/video0
```

### GPIO Not Working

```bash
# Check GPIO device exists
ls -l /dev/gpiomem

# Check user is in gpio group
groups | grep gpio

# If not in group, add user
sudo usermod -a -G gpio $USER
# Then log out and back in

# Check GPIO with Python
python3 -c "import RPi.GPIO as GPIO; print('GPIO OK')"
```

### High CPU Usage

```bash
# Check process usage
top -b -n 1 | grep -E "ruby|motion"

# Reduce camera quality
sudo nano /etc/motion/motion.conf
# Set: width 480, height 360, framerate 10

# Restart Motion
sudo systemctl restart motion

# Reduce Puma workers
# Edit config/puma.rb
# Set: workers 0  # Single mode
```

### Port 80 Permission Denied

```bash
# Option 1: Use port 4567 instead
# Edit config/settings.yml
# production:
#   port: 4567

# Option 2: Use authbind (allows non-root to bind port 80)
sudo apt-get install authbind
sudo touch /etc/authbind/byport/80
sudo chmod 777 /etc/authbind/byport/80

# Start with authbind
authbind bundle exec puma -C config/puma.rb

# Option 3: Use systemd service (handles privileges)
sudo systemctl start robot
```

### Gem Installation Fails

```bash
# Make sure development headers are installed
sudo apt-get install -y ruby-dev build-essential libssl-dev

# Clear bundler cache
bundle clean --force

# Reinstall
bundle install

# If specific gem fails (e.g., eventmachine)
gem install eventmachine -- --with-openssl-dir=/usr

# Then retry bundle install
bundle install
```

### Service Logs Show "No such file or directory"

```bash
# Check service file paths
cat /etc/systemd/system/robot.service

# Update paths to match your installation
sudo systemctl edit --full robot.service

# Or reinstall service with correct paths
ROBOT_DIR=$(pwd)
sed "s|/home/pi/robot|$ROBOT_DIR|g" scripts/robot.service | \
    sudo tee /etc/systemd/system/robot.service > /dev/null

sudo systemctl daemon-reload
sudo systemctl restart robot
```

### Network Not Accessible

```bash
# Find your IP address
hostname -I

# Check if application is listening
sudo netstat -tlnp | grep -E '(:80|:4567)'

# Test locally first
curl http://localhost/health

# Check firewall (usually not enabled on Pi OS)
sudo iptables -L

# Test from another device on same network
ping <PI_IP_ADDRESS>
curl http://<PI_IP_ADDRESS>/health
```

---

## Performance Optimization

### For Raspberry Pi Zero 2W

The Pi Zero 2W has limited resources. Optimize for better performance:

#### Puma Configuration

Edit `config/puma.rb`:

```ruby
# Single mode (no worker processes)
workers 0

# Reduce threads
threads 2, 3
```

#### Motion Configuration

Edit `/etc/motion/motion.conf`:

```conf
# Reduce resolution
width 480
height 360

# Lower framerate
framerate 10

# Reduce quality
quality 75

# Limit detection (if using motion detection)
threshold 2000
```

#### System Tuning

```bash
# Reduce GPU memory if camera not used
sudo nano /boot/firmware/config.txt
# Set: gpu_mem=64

# Disable unnecessary services
sudo systemctl disable bluetooth
sudo systemctl disable avahi-daemon

# Reduce swap usage
sudo sysctl vm.swappiness=10
```

---

## Uninstallation

### Remove Services Only

```bash
cd ~/robot
./scripts/native-uninstall.sh
```

This removes:
- Robot systemd service
- Optionally Motion service

Keeps:
- Ruby and system packages
- Application code
- Motion (if not selected for removal)

### Complete Removal

```bash
# Stop and remove services
sudo systemctl stop robot motion
sudo systemctl disable robot motion
sudo rm /etc/systemd/system/robot.service
sudo systemctl daemon-reload

# Remove application
rm -rf ~/robot

# Remove packages (optional)
sudo apt-get remove motion
sudo apt-get autoremove

# Ruby stays installed (might be used by system)
# To remove Ruby (careful!):
# sudo apt-get remove ruby ruby-dev
```

---

## Dependency List

### System Packages

Based on the Docker configuration, here's what gets installed:

```bash
# Core requirements
build-essential     # GCC, G++, make, etc. (for Ruby compilation)
git                 # Version control
curl                # HTTP client

# Ruby compilation dependencies
libssl-dev          # OpenSSL headers (for Ruby and gems)
libreadline-dev     # Readline library (for Ruby REPL)
zlib1g-dev          # Compression library (for Ruby)
libffi-dev          # FFI library (for Ruby fiddle extension)
libyaml-dev         # YAML library (for Ruby psych extension)
pkg-config          # Package configuration

# Ruby version management
rbenv               # Ruby version manager (installed via git)
ruby-build          # rbenv plugin for installing Ruby versions

# Camera streaming
motion              # Motion detection and streaming
v4l-utils           # Video4Linux utilities

# Optional but recommended
vim                 # Text editor
htop                # Process monitor
```

**Note**: Ruby is NOT installed via apt packages. Instead, rbenv compiles the specific Ruby version from source as defined in the `.ruby-version` file.

### Ruby Gems

From `Gemfile`:

```ruby
# Production gems
gem 'puma', '~> 6.4'              # Web server
gem 'sinatra', '~> 3.2'           # Web framework
gem 'sinatra-contrib', '~> 3.2'  # Sinatra extensions
gem 'pi_piper', '~> 2.0'          # GPIO control
```

---

## Comparison: Native vs Docker

| Feature | Native Installation | Docker |
|---------|-------------------|--------|
| Installation Time | 10-15 minutes | 5-10 minutes |
| Disk Space | ~500 MB | ~1.5 GB |
| Memory Usage | ~50 MB | ~60 MB |
| Startup Time | < 3 seconds | < 5 seconds |
| Update Process | git pull + bundle install | docker-compose pull |
| System Integration | Direct | Containerized |
| GPIO Access | Direct | Requires privileged mode |
| Debugging | Easier | Slightly harder |
| Isolation | None | Full |
| Best For | Single purpose Pi | Multiple services |

---

## Auto-Start on Boot

### Using Systemd (Recommended)

Already configured by installation script:

```bash
# Enable auto-start
sudo systemctl enable robot

# Disable auto-start
sudo systemctl disable robot

# Check if enabled
systemctl is-enabled robot
```

### Boot Order

Services start in this order:
1. Network
2. Motion (camera)
3. Robot (application)

---

## Updating the Application

```bash
# Stop service
sudo systemctl stop robot

# Pull latest code
cd ~/robot
git pull

# Update dependencies
bundle install

# Restart service
sudo systemctl start robot

# Check status
sudo systemctl status robot
```

---

## Development Workflow

For developing on the Pi:

```bash
# Install development gems
bundle config unset without
bundle install

# Run with auto-reload
bundle exec rerun ruby app/robot_app.rb

# Run tests
bundle exec rspec

# Check code style
bundle exec rubocop
```

---

## Support

### Documentation
- Main README: `README.md`
- Docker guide: `DOCKER.md`
- This guide: `NATIVE_INSTALLATION.md`

### Scripts
- Installation: `scripts/native-install.sh`
- Testing: `scripts/test-native-setup.sh`
- Uninstall: `scripts/native-uninstall.sh`

### Logs
```bash
# Application logs
sudo journalctl -u robot -f

# Motion logs
sudo journalctl -u motion -f

# System logs
sudo journalctl -xe
```

### Common Commands Reference

```bash
# Service management
sudo systemctl start robot
sudo systemctl stop robot
sudo systemctl restart robot
sudo systemctl status robot
sudo journalctl -u robot -f

# Test commands
curl http://localhost/health
curl http://localhost/api/v1/status

# Network
hostname -I
sudo netstat -tlnp | grep ruby

# Processes
ps aux | grep ruby
htop
```

---

## Summary

Native installation provides:
- ✓ Direct system integration
- ✓ Lower resource usage
- ✓ Faster startup
- ✓ Easier debugging
- ✓ Simple updates

Choose native installation when:
- Running dedicated robot controller
- Want maximum performance
- Prefer simpler setup
- Don't need containerization

Choose Docker when:
- Running multiple services
- Want isolation
- Need reproducible environments
- Plan to deploy across multiple Pis

---

**Installation complete! Your Robot Tank is ready to roll! 🤖**
