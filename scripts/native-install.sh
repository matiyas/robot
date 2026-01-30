#!/bin/bash
# Complete native installation script for Robot Tank Control
# on Raspberry Pi Zero 2W with Raspberry Pi OS (ARM64)
#
# This script installs all dependencies and configures the system
# for running the robot control application natively (without Docker)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored messages
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}! $1${NC}"
}

print_info() {
    echo -e "${BLUE}→ $1${NC}"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run as root. Run as normal user with sudo privileges."
    exit 1
fi

print_header "Robot Tank Control - Native Installation"
echo ""
echo "This script will install all dependencies and configure"
echo "your Raspberry Pi Zero 2W to run the robot tank controller."
echo ""

# Verify system
print_info "Checking system..."
if [ -f /proc/device-tree/model ]; then
    MODEL=$(cat /proc/device-tree/model)
    echo "Device: $MODEL"
else
    print_warning "Not running on Raspberry Pi"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check architecture
ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ] && [ "$ARCH" != "armv7l" ]; then
    print_warning "Expected ARM architecture, got: $ARCH"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

print_success "System check passed"
echo ""

# Update system
print_header "Step 1: Updating System"
print_info "This may take a few minutes..."
sudo apt-get update
sudo apt-get upgrade -y
print_success "System updated"
echo ""

# Install build tools and dependencies
print_header "Step 2: Installing Build Tools and Dependencies"
print_info "Installing build essentials and development libraries..."
sudo apt-get install -y \
    build-essential \
    git \
    curl \
    libssl-dev \
    libreadline-dev \
    zlib1g-dev \
    libffi-dev \
    libyaml-dev \
    pkg-config

print_success "Build tools installed"
echo ""

# Install rbenv and ruby-build
print_header "Step 3: Installing rbenv"
print_info "Installing rbenv for Ruby version management..."

# Check if rbenv is already installed
if [ -d "$HOME/.rbenv" ]; then
    print_warning "rbenv already installed at $HOME/.rbenv"
else
    git clone https://github.com/rbenv/rbenv.git ~/.rbenv
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
    echo 'eval "$(rbenv init -)"' >> ~/.bashrc
    print_success "rbenv installed"
fi

# Install ruby-build plugin
if [ -d "$HOME/.rbenv/plugins/ruby-build" ]; then
    print_warning "ruby-build already installed"
else
    git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
    print_success "ruby-build plugin installed"
fi

# Initialize rbenv for this session
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

echo ""

# Install Ruby version from .ruby-version
print_header "Step 4: Installing Ruby"
print_info "Installing Ruby version from .ruby-version file..."

if [ -f "$PROJECT_DIR/.ruby-version" ]; then
    RUBY_VERSION=$(cat "$PROJECT_DIR/.ruby-version")
    print_info "Target Ruby version: $RUBY_VERSION"

    # Check if this Ruby version is already installed
    if rbenv versions | grep -q "$RUBY_VERSION"; then
        print_warning "Ruby $RUBY_VERSION already installed"
    else
        print_info "Installing Ruby $RUBY_VERSION (this may take 10-20 minutes on Pi Zero 2W)..."
        rbenv install "$RUBY_VERSION"
        print_success "Ruby $RUBY_VERSION installed"
    fi

    # Set global Ruby version
    rbenv global "$RUBY_VERSION"
    rbenv rehash

    INSTALLED_VERSION=$(ruby --version)
    print_success "Ruby active: $INSTALLED_VERSION"
else
    print_error ".ruby-version file not found in $PROJECT_DIR"
    exit 1
fi
echo ""

# Install Bundler
print_header "Step 5: Installing Bundler"
print_info "Installing Ruby Bundler for dependency management..."
gem install bundler
rbenv rehash
BUNDLER_VERSION=$(bundle --version)
print_success "Bundler installed: $BUNDLER_VERSION"
echo ""

# Install Motion for camera streaming
print_header "Step 6: Installing Motion (Camera Streaming)"
print_info "Installing Motion and video utilities..."
sudo apt-get install -y motion v4l-utils
print_success "Motion installed"
echo ""

# Navigate to project directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"
print_info "Project directory: $PROJECT_DIR"
echo ""

# Install Ruby gems
print_header "Step 7: Installing Ruby Dependencies"
print_info "This will install all required Ruby gems..."
print_info "This may take 5-10 minutes on Raspberry Pi Zero 2W..."

if [ -f Gemfile ]; then
    # Install gems
    bundle config set --local deployment 'false'
    bundle config set --local without 'development test'
    bundle install
    print_success "Ruby dependencies installed"
else
    print_error "Gemfile not found in $PROJECT_DIR"
    exit 1
fi
echo ""

# Configure camera
print_header "Step 8: Configuring Camera"
print_info "Enabling camera interface..."

# For newer Raspberry Pi OS (Bookworm+)
if [ -f /boot/firmware/config.txt ]; then
    BOOT_CONFIG="/boot/firmware/config.txt"
else
    BOOT_CONFIG="/boot/config.txt"
fi

# Enable camera
if ! sudo grep -q "^camera_auto_detect=1" $BOOT_CONFIG; then
    echo "camera_auto_detect=1" | sudo tee -a $BOOT_CONFIG > /dev/null
    print_success "Camera auto-detect enabled"
fi

if ! sudo grep -q "^start_x=1" $BOOT_CONFIG; then
    echo "start_x=1" | sudo tee -a $BOOT_CONFIG > /dev/null
    print_success "Camera enabled in config"
fi

if ! sudo grep -q "^gpu_mem=128" $BOOT_CONFIG; then
    echo "gpu_mem=128" | sudo tee -a $BOOT_CONFIG > /dev/null
    print_success "GPU memory allocated"
fi

print_success "Camera configuration updated"
echo ""

# Configure Motion
print_header "Step 9: Configuring Motion Daemon"
if [ -f scripts/motion.conf ]; then
    print_info "Copying Motion configuration..."
    sudo cp scripts/motion.conf /etc/motion/motion.conf

    # Enable Motion daemon
    if [ -f /etc/default/motion ]; then
        sudo sed -i 's/start_motion_daemon=no/start_motion_daemon=yes/' /etc/default/motion
    fi

    print_success "Motion configured"
else
    print_warning "Motion config not found, using defaults"
fi
echo ""

# Setup systemd service
print_header "Step 10: Installing Systemd Service"
if [ -f scripts/robot.service ]; then
    print_info "Installing robot control service..."

    # Update paths in service file
    sed "s|/home/pi/robot|$PROJECT_DIR|g" scripts/robot.service | \
        sed "s|User=pi|User=$USER|g" | \
        sudo tee /etc/systemd/system/robot.service > /dev/null

    sudo systemctl daemon-reload
    print_success "Service installed"
else
    print_warning "Service file not found, skipping"
fi
echo ""

# Set permissions
print_header "Step 11: Setting User Permissions"
print_info "Adding user to required groups..."

# Add to video group for camera access
if groups $USER | grep -q video; then
    print_success "User already in video group"
else
    sudo usermod -a -G video $USER
    print_success "User added to video group"
fi

# Add to gpio group for GPIO access
if groups $USER | grep -q gpio; then
    print_success "User already in gpio group"
else
    sudo usermod -a -G gpio $USER
    print_success "User added to gpio group"
fi

print_warning "You may need to log out and back in for group changes to take effect"
echo ""

# Enable services
print_header "Step 12: Configuring Services"
read -p "Enable Motion service to start on boot? (Y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    sudo systemctl enable motion
    print_success "Motion service enabled"
else
    print_info "Motion service not enabled"
fi

read -p "Enable Robot service to start on boot? (Y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    sudo systemctl enable robot
    print_success "Robot service enabled"
else
    print_info "Robot service not enabled"
fi
echo ""

# Create logs directory
print_info "Creating logs directory..."
mkdir -p "$PROJECT_DIR/logs"
print_success "Logs directory created"
echo ""

# Summary
print_header "Installation Complete!"
echo ""
echo "Your Raspberry Pi is now configured to run the Robot Tank Controller."
echo ""
print_info "What was installed:"
echo "  • Ruby $(ruby --version | awk '{print $2}')"
echo "  • Bundler $(bundle --version | awk '{print $3}')"
echo "  • Motion (camera streaming)"
echo "  • All Ruby dependencies"
echo "  • Systemd services configured"
echo ""

print_info "Important Next Steps:"
echo ""
echo "1. REBOOT YOUR RASPBERRY PI (required for camera and group changes)"
echo "   ${GREEN}sudo reboot${NC}"
echo ""
echo "2. After reboot, verify camera works:"
echo "   ${GREEN}libcamera-hello --list-cameras${NC}"
echo "   ${GREEN}libcamera-still -o test.jpg${NC}"
echo ""
echo "3. Test Motion service:"
echo "   ${GREEN}sudo systemctl status motion${NC}"
echo "   ${GREEN}sudo systemctl start motion${NC}"
echo ""
echo "4. Start the robot service:"
echo "   ${GREEN}sudo systemctl start robot${NC}"
echo "   ${GREEN}sudo systemctl status robot${NC}"
echo ""
echo "5. Access the control panel:"
IP_ADDR=$(hostname -I | awk '{print $1}')
if [ -n "$IP_ADDR" ]; then
    echo "   ${GREEN}http://${IP_ADDR}${NC}"
else
    echo "   ${GREEN}http://<YOUR_PI_IP_ADDRESS>${NC}"
fi
echo ""

print_info "Manual Start (for testing):"
echo "  ${GREEN}cd $PROJECT_DIR${NC}"
echo "  ${GREEN}RACK_ENV=production bundle exec puma -C config/puma.rb${NC}"
echo ""

print_info "Development Mode (no GPIO):"
echo "  ${GREEN}cd $PROJECT_DIR${NC}"
echo "  ${GREEN}bundle exec ruby app/robot_app.rb${NC}"
echo ""

print_info "View Logs:"
echo "  ${GREEN}sudo journalctl -u robot -f${NC}"
echo "  ${GREEN}sudo journalctl -u motion -f${NC}"
echo "  ${GREEN}tail -f $PROJECT_DIR/logs/*.log${NC}"
echo ""

print_info "Troubleshooting:"
echo "  ${GREEN}./scripts/test-native-setup.sh${NC} - Test installation"
echo "  ${GREEN}./scripts/native-uninstall.sh${NC} - Uninstall services"
echo ""

print_header "Ready to reboot!"
echo ""
read -p "Reboot now? (Y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    print_info "Rebooting in 3 seconds..."
    sleep 3
    sudo reboot
else
    print_warning "Remember to reboot before using the robot!"
    print_info "Run: ${GREEN}sudo reboot${NC}"
fi
