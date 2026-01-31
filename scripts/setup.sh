#!/bin/bash
# Setup script for Robot Tank Control on Raspberry Pi Zero 2W

set -e

echo "=========================================="
echo "Robot Tank Control - Setup Script"
echo "=========================================="
echo ""

# Check if running on Raspberry Pi
if [ ! -f /proc/device-tree/model ]; then
  echo "Warning: This doesn't appear to be a Raspberry Pi"
  read -p "Continue anyway? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Update system
echo "Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install build tools and development libraries
echo "Installing build tools and development libraries..."
sudo apt-get install -y build-essential git curl libssl-dev libreadline-dev zlib1g-dev libffi-dev libyaml-dev

# Install rbenv
echo "Installing rbenv..."
if [ ! -d "$HOME/.rbenv" ]; then
    git clone https://github.com/rbenv/rbenv.git ~/.rbenv
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
    echo 'eval "$(rbenv init -)"' >> ~/.bashrc
fi

if [ ! -d "$HOME/.rbenv/plugins/ruby-build" ]; then
    git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
fi

# Initialize rbenv for this session
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

# Navigate to project directory
cd "$(dirname "$0")/.."

# Install Ruby from .ruby-version
echo "Installing Ruby..."
if [ -f .ruby-version ]; then
    RUBY_VERSION=$(cat .ruby-version)
    echo "Installing Ruby $RUBY_VERSION..."
    rbenv install -s $RUBY_VERSION
    rbenv global $RUBY_VERSION
    rbenv rehash
else
    echo "Error: .ruby-version file not found"
    exit 1
fi

# Install rpicam for camera streaming
echo "Installing rpicam-apps (camera streaming)..."
sudo apt-get install -y rpicam-apps ffmpeg

# Install bundler
echo "Installing Bundler..."
gem install bundler
rbenv rehash

# Install project dependencies
echo "Installing project dependencies..."
bundle install

# Configure rpicam streaming
echo "Configuring rpicam streaming service..."
if [ -f scripts/rpicam-stream.service ]; then
    sudo cp scripts/rpicam-stream.service /etc/systemd/system/
    sudo systemctl daemon-reload
fi

# Enable camera interface
echo "Enabling camera interface..."
if ! grep -q "start_x=1" /boot/config.txt; then
  echo "start_x=1" | sudo tee -a /boot/config.txt
fi
if ! grep -q "gpu_mem=128" /boot/config.txt; then
  echo "gpu_mem=128" | sudo tee -a /boot/config.txt
fi

# Load camera module
if ! lsmod | grep -q bcm2835_v4l2; then
  echo "Loading camera module..."
  sudo modprobe bcm2835_v4l2
  echo "bcm2835_v4l2" | sudo tee -a /etc/modules
fi

# Enable and start rpicam streaming
echo "Enabling rpicam streaming service..."
sudo systemctl enable rpicam-stream
sudo systemctl start rpicam-stream

# Install systemd service for robot app
echo "Installing robot control service..."
sudo cp scripts/robot.service /etc/systemd/system/
sudo sed -i "s|/home/pi/robot|$(pwd)|g" /etc/systemd/system/robot.service
sudo systemctl daemon-reload
sudo systemctl enable robot

# Set permissions
echo "Setting permissions..."
sudo usermod -a -G video $USER
sudo usermod -a -G gpio $USER

echo ""
echo "=========================================="
echo "Setup complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Reboot your Raspberry Pi: sudo reboot"
echo "2. After reboot, test the camera: rpicam-still -o test.jpg"
echo "3. Start the robot service: sudo systemctl start robot"
echo "4. Access the control panel: http://$(hostname -I | awk '{print $1}'):4567"
echo ""
echo "For development mode (without GPIO):"
echo "  bundle exec ruby app/robot_app.rb"
echo ""
echo "Check logs:"
echo "  sudo journalctl -u robot -f"
echo "  sudo journalctl -u rpicam-stream -f"
echo ""
