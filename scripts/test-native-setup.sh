#!/bin/bash
# Test script to verify native installation on Raspberry Pi

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FAILED=0

echo "Testing Native Installation..."
echo ""

check_command() {
    if command -v "$1" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $1 is installed"
        if [ -n "$2" ]; then
            VERSION=$($1 $2 2>&1 | head -1)
            echo "  Version: $VERSION"
        fi
    else
        echo -e "${RED}✗${NC} $1 is NOT installed"
        FAILED=1
    fi
}

check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $1 exists"
    else
        echo -e "${RED}✗${NC} $1 missing"
        FAILED=1
    fi
}

check_service() {
    if systemctl list-unit-files | grep -q "$1.service"; then
        echo -e "${GREEN}✓${NC} $1 service is installed"
        if systemctl is-enabled "$1" &> /dev/null; then
            echo "  Status: enabled"
        else
            echo "  Status: disabled"
        fi
    else
        echo -e "${YELLOW}!${NC} $1 service not found"
    fi
}

check_group() {
    if groups | grep -q "$1"; then
        echo -e "${GREEN}✓${NC} User is in $1 group"
    else
        echo -e "${YELLOW}!${NC} User is NOT in $1 group"
        echo "  Run: sudo usermod -a -G $1 \$USER"
    fi
}

echo "Checking System Commands..."
check_command ruby "--version"
check_command bundle "--version"
check_command git "--version"
check_command motion "-h"

echo ""
echo "Checking rbenv Setup..."
check_command rbenv "--version"
if [ -f ".ruby-version" ]; then
    EXPECTED_VERSION=$(cat .ruby-version)
    ACTUAL_VERSION=$(ruby -v | awk '{print $2}' | cut -d'p' -f1)
    if [ "$ACTUAL_VERSION" = "$EXPECTED_VERSION" ]; then
        echo -e "${GREEN}✓${NC} Ruby version matches .ruby-version ($EXPECTED_VERSION)"
    else
        echo -e "${YELLOW}!${NC} Ruby version mismatch: expected $EXPECTED_VERSION, got $ACTUAL_VERSION"
    fi
else
    echo -e "${YELLOW}!${NC} .ruby-version file not found"
fi

echo ""
echo "Checking Build Tools..."
check_command gcc "--version"
check_command make "--version"
check_command pkg-config "--version"

echo ""
echo "Checking Libraries..."
if pkg-config --exists libssl; then
    echo -e "${GREEN}✓${NC} libssl is installed"
else
    echo -e "${RED}✗${NC} libssl is NOT installed"
    FAILED=1
fi

echo ""
echo "Checking Project Files..."
check_file "Gemfile"
check_file "app/robot_app.rb"
check_file "config.ru"
check_file "config/settings.yml"
check_file "config/puma.rb"

echo ""
echo "Checking Ruby Gems..."
if bundle check &> /dev/null; then
    echo -e "${GREEN}✓${NC} All gems are installed"
else
    echo -e "${RED}✗${NC} Some gems are missing"
    echo "  Run: bundle install"
    FAILED=1
fi

echo ""
echo "Checking Services..."
check_service "robot"
check_service "motion"

echo ""
echo "Checking User Groups..."
check_group "video"
check_group "gpio"

echo ""
echo "Checking Camera..."
if [ -e /dev/video0 ]; then
    echo -e "${GREEN}✓${NC} Camera device /dev/video0 exists"
else
    echo -e "${YELLOW}!${NC} Camera device /dev/video0 not found"
    echo "  Enable camera: sudo raspi-config"
fi

echo ""
echo "Checking GPIO..."
if [ -e /dev/gpiomem ]; then
    echo -e "${GREEN}✓${NC} GPIO device /dev/gpiomem exists"
else
    echo -e "${YELLOW}!${NC} GPIO device /dev/gpiomem not found"
fi

echo ""
echo "Checking Configuration Files..."
if [ -f /etc/motion/motion.conf ]; then
    echo -e "${GREEN}✓${NC} Motion configuration exists"
else
    echo -e "${YELLOW}!${NC} Motion configuration not found"
fi

if [ -f /etc/systemd/system/robot.service ]; then
    echo -e "${GREEN}✓${NC} Robot service file exists"
else
    echo -e "${YELLOW}!${NC} Robot service file not found"
fi

echo ""
echo "Testing Application..."
if [ -f app/robot_app.rb ]; then
    if ruby -c app/robot_app.rb > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Application syntax is valid"
    else
        echo -e "${RED}✗${NC} Application has syntax errors"
        FAILED=1
    fi
fi

echo ""
echo "Checking Network..."
IP_ADDR=$(hostname -I | awk '{print $1}')
if [ -n "$IP_ADDR" ]; then
    echo -e "${GREEN}✓${NC} Network configured"
    echo "  IP Address: $IP_ADDR"
    echo "  Access at: http://$IP_ADDR"
else
    echo -e "${YELLOW}!${NC} No network IP found"
fi

echo ""
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC}"
    echo ""
    echo "Your installation appears to be complete."
    echo ""
    echo "To start the robot:"
    echo "  sudo systemctl start robot"
    echo ""
    echo "To check status:"
    echo "  sudo systemctl status robot"
    echo ""
    exit 0
else
    echo -e "${RED}Some checks failed!${NC}"
    echo "Please review the errors above and fix them."
    exit 1
fi
