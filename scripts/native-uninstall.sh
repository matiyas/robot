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
echo "  • Motion"
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

if systemctl list-unit-files | grep -q "motion.service"; then
    read -p "Also stop Motion service? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo systemctl stop motion 2>/dev/null || true
        sudo systemctl disable motion 2>/dev/null || true
        echo -e "${GREEN}✓${NC} Motion service stopped and disabled"
    fi
fi

echo ""
echo "Removing service files..."

# Remove service files
if [ -f /etc/systemd/system/robot.service ]; then
    sudo rm /etc/systemd/system/robot.service
    echo -e "${GREEN}✓${NC} Removed robot service file"
fi

sudo systemctl daemon-reload
echo -e "${GREEN}✓${NC} Systemd reloaded"

echo ""
echo -e "${GREEN}Uninstall complete!${NC}"
echo ""
echo "The application code is still in place."
echo "System packages (Ruby, Motion, etc.) are still installed."
echo ""
echo "To completely remove the application:"
echo "  rm -rf $(pwd)"
echo ""
echo "To remove Motion:"
echo "  sudo apt-get remove motion"
echo ""
