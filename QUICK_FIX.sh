#!/bin/bash
# Quick fix script for migrating from pi_piper to pigpio on Raspberry Pi
# Run this on your Raspberry Pi to fix the 64-bit GPIO issue

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Robot Tank GPIO Fix (pi_piper → pigpio)${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Step 1: Install pigpio system library
echo -e "${YELLOW}Step 1: Installing pigpio library...${NC}"

# Check if pigpio is already installed
if command -v pigpiod &> /dev/null; then
    echo -e "${GREEN}✓ pigpiod already installed${NC}"
    pigpiod -v 2>&1 || echo "Version: unknown"
else
    echo "Building pigpio from source..."
    sudo apt-get update
    sudo apt-get install -y wget unzip build-essential

    # Download and build pigpio
    cd /tmp
    wget https://github.com/joan2937/pigpio/archive/master.zip -O pigpio.zip
    unzip -o pigpio.zip
    cd pigpio-master
    make
    sudo make install
    cd ~
    echo -e "${GREEN}✓ pigpio compiled and installed${NC}"
fi
echo ""

# Step 2: Enable and start pigpiod daemon
echo -e "${YELLOW}Step 2: Starting pigpiod daemon...${NC}"

# Create systemd service if it doesn't exist
if [ ! -f /etc/systemd/system/pigpiod.service ]; then
    echo "Creating pigpiod systemd service..."
    sudo tee /etc/systemd/system/pigpiod.service > /dev/null << 'PIGPIOD_EOF'
[Unit]
Description=Pigpio daemon
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/bin/pigpiod -l
ExecStop=/bin/systemctl kill pigpiod
Restart=on-failure

[Install]
WantedBy=multi-user.target
PIGPIOD_EOF
    sudo systemctl daemon-reload
fi

sudo systemctl enable pigpiod
sudo systemctl start pigpiod

# Verify daemon is running
if sudo systemctl is-active --quiet pigpiod; then
    echo -e "${GREEN}✓ pigpiod daemon is running${NC}"
else
    echo -e "${RED}✗ Failed to start pigpiod daemon${NC}"
    echo "Checking daemon status..."
    sudo systemctl status pigpiod --no-pager
    exit 1
fi
echo ""

# Step 3: Update Ruby dependencies
echo -e "${YELLOW}Step 3: Updating Ruby dependencies...${NC}"
cd ~/Workspace/robot || exit 1

# Pull latest code changes
echo "Pulling latest code..."
git pull

# Update bundler
echo "Installing/updating bundler..."
gem install bundler
rbenv rehash

# Install new gems
echo "Installing Ruby gems (this may take a few minutes)..."
bundle config set --local without 'development test'
bundle install
echo -e "${GREEN}✓ Ruby dependencies updated${NC}"
echo ""

# Step 4: Restart services
echo -e "${YELLOW}Step 4: Restarting services...${NC}"
sudo systemctl daemon-reload
sudo systemctl restart robot
sudo systemctl restart rpicam-stream

sleep 2

# Check service status
echo ""
echo -e "${BLUE}Service Status:${NC}"
if sudo systemctl is-active --quiet robot; then
    echo -e "${GREEN}✓ robot.service is running${NC}"
else
    echo -e "${RED}✗ robot.service failed${NC}"
    echo ""
    echo "Showing last 20 lines of robot service log:"
    sudo journalctl -u robot -n 20 --no-pager
fi

if sudo systemctl is-active --quiet rpicam-stream; then
    echo -e "${GREEN}✓ rpicam-stream.service is running${NC}"
else
    echo -e "${YELLOW}! rpicam-stream.service failed (check USER setting in service file)${NC}"
fi

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  Fix complete!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo "Your robot should now be accessible at:"
echo "  http://$(hostname -I | awk '{print $1}'):9292"
echo ""
echo "To view logs:"
echo "  sudo journalctl -u robot -f"
