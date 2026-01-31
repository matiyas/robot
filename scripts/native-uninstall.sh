#!/bin/bash
# Uninstall script for Robot Tank Control native installation

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Robot Tank Control - Uninstall${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo "This will remove the robot services but keep:"
echo "  • Ruby and system packages"
echo "  • rpicam-apps"
echo "  • Application code"
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
fi

echo ""
echo "Stopping services..."

# Stop services
if systemctl list-unit-files | grep -q "robot.service"; then
    sudo systemctl stop robot 2>/dev/null || true
    sudo systemctl disable robot 2>/dev/null || true
    echo -e "${GREEN}✓${NC} Robot service stopped and disabled"
fi

if systemctl list-unit-files | grep -q "rpicam-stream.service"; then
    sudo systemctl stop rpicam-stream 2>/dev/null || true
    sudo systemctl disable rpicam-stream 2>/dev/null || true
    echo -e "${GREEN}✓${NC} rpicam streaming service stopped and disabled"
fi

if systemctl list-unit-files | grep -q "pigpiod.service"; then
    sudo systemctl stop pigpiod 2>/dev/null || true
    sudo systemctl disable pigpiod 2>/dev/null || true
    echo -e "${GREEN}✓${NC} pigpiod service stopped and disabled"
fi

echo ""
echo "Removing service files..."

# Remove service files
if [ -f /etc/systemd/system/robot.service ]; then
    sudo rm /etc/systemd/system/robot.service
    echo -e "${GREEN}✓${NC} Removed robot service file"
fi

if [ -f /etc/systemd/system/rpicam-stream.service ]; then
    sudo rm /etc/systemd/system/rpicam-stream.service
    echo -e "${GREEN}✓${NC} Removed rpicam-stream service file"
fi

if [ -f /etc/systemd/system/pigpiod.service ]; then
    sudo rm /etc/systemd/system/pigpiod.service
    echo -e "${GREEN}✓${NC} Removed pigpiod service file"
fi

# Clean up FIFO
if [ -p /tmp/camera_stream ]; then
    sudo rm -f /tmp/camera_stream
    echo -e "${GREEN}✓${NC} Removed camera stream FIFO"
fi

sudo systemctl daemon-reload
echo -e "${GREEN}✓${NC} Systemd reloaded"

echo ""
echo -e "${GREEN}Uninstall complete!${NC}"
echo ""
echo "The application code is still in place."
echo "System packages (Ruby, rpicam-apps, pigpio, etc.) are still installed."
echo ""
echo "To completely remove the application:"
echo "  rm -rf $(pwd)"
echo ""
echo "To remove system packages:"
echo "  sudo apt-get remove rpicam-apps pigpio"
echo ""
