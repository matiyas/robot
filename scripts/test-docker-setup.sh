#!/bin/bash
# Test script to validate Docker setup
# Run this to verify all Docker files are correctly configured

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FAILED=0

echo "Testing Docker setup..."
echo ""

check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $1 exists"
    else
        echo -e "${RED}✗${NC} $1 missing"
        FAILED=1
    fi
}

check_executable() {
    if [ -x "$1" ]; then
        echo -e "${GREEN}✓${NC} $1 is executable"
    else
        echo -e "${RED}✗${NC} $1 is not executable"
        FAILED=1
    fi
}

echo "Checking Docker files..."
check_file "Dockerfile"
check_file "docker-compose.yml"
check_file "docker-compose.dev.yml"
check_file "docker-compose.prod.yml"
check_file ".dockerignore"
check_file ".env.example"

echo ""
echo "Checking configuration files..."
check_file "config/puma.rb"
check_file "config/settings.yml"
check_file "config/gpio_pins.yml"

echo ""
echo "Checking scripts..."
check_file "docker-entrypoint.sh"
check_file "docker-healthcheck.sh"
check_file "quick-start.sh"
check_file "Makefile"

check_executable "docker-entrypoint.sh"
check_executable "docker-healthcheck.sh"
check_executable "quick-start.sh"

echo ""
echo "Checking documentation..."
check_file "DOCKER.md"
check_file "DOCKER_SETUP_SUMMARY.md"

echo ""
echo "Validating docker-compose files..."

# Check if docker-compose can parse the files
if command -v docker-compose &> /dev/null; then
    if docker-compose -f docker-compose.yml config > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} docker-compose.yml is valid"
    else
        echo -e "${RED}✗${NC} docker-compose.yml has syntax errors"
        FAILED=1
    fi

    if docker-compose -f docker-compose.dev.yml config > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} docker-compose.dev.yml is valid"
    else
        echo -e "${RED}✗${NC} docker-compose.dev.yml has syntax errors"
        FAILED=1
    fi

    if docker-compose -f docker-compose.prod.yml config > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} docker-compose.prod.yml is valid"
    else
        echo -e "${RED}✗${NC} docker-compose.prod.yml has syntax errors"
        FAILED=1
    fi
else
    echo -e "${YELLOW}!${NC} docker-compose not installed, skipping validation"
fi

echo ""
echo "Checking for common issues..."

# Check if Gemfile.lock is excluded
if grep -q "Gemfile.lock" .dockerignore; then
    echo -e "${YELLOW}!${NC} Warning: Gemfile.lock is excluded in .dockerignore"
    echo "  This may cause dependency issues. Consider including it."
fi

# Check if logs directory is in .gitignore
if grep -q "logs/" .gitignore; then
    echo -e "${GREEN}✓${NC} logs/ is in .gitignore"
else
    echo -e "${YELLOW}!${NC} Warning: logs/ not in .gitignore"
fi

echo ""
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC}"
    echo ""
    echo "You can now:"
    echo "1. Run './quick-start.sh' for interactive setup"
    echo "2. Run 'make dev' to start development mode"
    echo "3. Run 'make prod' to start production mode"
    echo ""
    exit 0
else
    echo -e "${RED}Some checks failed!${NC}"
    echo "Please fix the issues above and run this script again."
    exit 1
fi
