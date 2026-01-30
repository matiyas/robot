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
    local text="$1"
    local length=${#text}
    local min_length=40
    local bar_length=$((length > min_length ? length : min_length))
    local separator=$(printf '=%.0s' $(seq 1 $bar_length))
    echo -e "${BLUE}${separator}${NC}"
    echo -e "${BLUE}$text${NC}"
    echo -e "${BLUE}${separator}${NC}"
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

# Navigate to project directory (needed for later steps)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"
print_info "Project directory: $PROJECT_DIR"
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

# Optimize for low-RAM devices (like Pi Zero 2W with 512MB RAM)
print_header "Step 4: Optimizing for Low-RAM Devices"
TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
print_info "Detected RAM: ${TOTAL_RAM}MB"

if [ "$TOTAL_RAM" -lt 1024 ]; then
    print_warning "Low RAM detected. Optimizing for 512MB devices..."

    # Check current swap
    SWAP_SIZE=$(free -m | awk '/^Swap:/{print $2}')
    print_info "Current swap: ${SWAP_SIZE}MB"

    # Increase swap if needed (to prevent OOM during Ruby compilation)
    if [ "$SWAP_SIZE" -lt 1024 ]; then
        print_info "Increasing swap space to 1GB for Ruby compilation..."

        # Check if dphys-swapfile is available (older Raspberry Pi OS)
        if command -v dphys-swapfile >/dev/null 2>&1; then
            print_info "Using dphys-swapfile for swap management..."

            # Stop swap
            sudo dphys-swapfile swapoff || true

            # Configure new swap size
            sudo sed -i 's/^CONF_SWAPSIZE=.*/CONF_SWAPSIZE=1024/' /etc/dphys-swapfile

            # Recreate and enable swap
            sudo dphys-swapfile setup
            sudo dphys-swapfile swapon
        else
            # Modern Raspberry Pi OS without dphys-swapfile
            print_info "Using manual swap management..."

            # Find existing swap device/file
            SWAP_DEVICE=$(swapon --show=NAME --noheadings | head -n1)

            # Check if using zram (compressed RAM swap)
            if echo "$SWAP_DEVICE" | grep -q "zram"; then
                print_warning "Detected zram swap (compressed RAM)"
                print_info "Disabling zram and creating disk-based swap..."

                # Turn off zram swap
                sudo swapoff "$SWAP_DEVICE" 2>/dev/null || true

                # Use traditional swap file location
                SWAP_FILE="/swapfile"
            else
                # Traditional swap file
                SWAP_FILE="$SWAP_DEVICE"
                if [ -z "$SWAP_FILE" ]; then
                    SWAP_FILE="/swapfile"
                fi

                print_info "Swap file: $SWAP_FILE"
                # Turn off existing swap
                sudo swapoff "$SWAP_FILE" 2>/dev/null || true
            fi

            # Create new 1GB swap file on disk
            print_info "Creating 1GB swap file at $SWAP_FILE..."
            sudo dd if=/dev/zero of="$SWAP_FILE" bs=1M count=1024 status=progress 2>/dev/null || \
                sudo dd if=/dev/zero of="$SWAP_FILE" bs=1M count=1024
            sudo chmod 600 "$SWAP_FILE"
            sudo mkswap "$SWAP_FILE"
            sudo swapon "$SWAP_FILE"

            print_success "Created 1GB swap file at $SWAP_FILE"
        fi

        NEW_SWAP=$(free -m | awk '/^Swap:/{print $2}')
        print_success "Swap increased to ${NEW_SWAP}MB"
    fi

    # Limit parallel make jobs to 1 to prevent OOM
    export MAKE_OPTS="-j1"
    print_info "Ruby compilation will use single-threaded build (MAKE_OPTS=-j1)"
    print_warning "This will be slower but prevents system freezes"
else
    # For devices with more RAM, use 2 parallel jobs for faster compilation
    export MAKE_OPTS="-j2"
    print_info "Ruby compilation will use 2 parallel jobs"
fi
print_success "System optimized for Ruby compilation"
echo ""

# Install Ruby version from .ruby-version
print_header "Step 5: Installing Ruby"
print_info "Installing Ruby version from .ruby-version file..."

if [ -f "$PROJECT_DIR/.ruby-version" ]; then
    RUBY_VERSION=$(cat "$PROJECT_DIR/.ruby-version")
    print_info "Target Ruby version: $RUBY_VERSION"

    # Check if this Ruby version is already installed
    if rbenv versions | grep -q "$RUBY_VERSION"; then
        print_warning "Ruby $RUBY_VERSION already installed"
    else
        print_info "Installing Ruby $RUBY_VERSION..."
        print_warning "This may take 20-40 minutes on Pi Zero 2W with limited RAM"
        print_info "The system may appear slow during compilation - this is normal"
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
print_header "Step 6: Installing Bundler"
print_info "Installing Ruby Bundler for dependency management..."
gem install bundler
rbenv rehash
BUNDLER_VERSION=$(bundle --version)
print_success "Bundler installed: $BUNDLER_VERSION"
echo ""

# Install Motion for camera streaming
print_header "Step 7: Installing Motion (Camera Streaming)"
print_info "Installing Motion and video utilities..."
sudo apt-get install -y motion v4l-utils
print_success "Motion installed"
echo ""

# Install Ruby gems
print_header "Step 8: Installing Ruby Dependencies"
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
print_header "Step 9: Configuring Camera"
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
print_header "Step 10: Configuring Motion Daemon"
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
print_header "Step 11: Installing Systemd Service"
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
print_header "Step 12: Setting User Permissions"
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
print_header "Step 13: Configuring Services"
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
