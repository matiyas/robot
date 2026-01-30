#!/bin/bash
# Complete dependency installation reference
# Based on tested Docker configuration for Debian Trixie ARM64
#
# This script shows all dependencies needed for native installation
# Use this as a reference or run it directly on Raspberry Pi OS (ARM64)

set -e

echo "Robot Tank Control - Dependencies Reference"
echo "Based on Docker configuration (Debian Trixie ARM64)"
echo ""
echo "This will install all required system packages and Ruby gems"
echo ""

# System packages from Dockerfile
SYSTEM_PACKAGES=(
    # Core Ruby
    ruby
    ruby-dev
    
    # Build tools
    build-essential
    
    # Version control
    git
    
    # HTTP client
    curl
    
    # Camera streaming
    motion
    
    # OpenSSL (required for eventmachine gem compilation)
    libssl-dev
    
    # Optional but recommended
    pkg-config
    v4l-utils
)

echo "System packages to be installed:"
printf '  - %s\n' "${SYSTEM_PACKAGES[@]}"
echo ""

# Install system packages
echo "Installing system packages..."
sudo apt-get update
sudo apt-get install -y "${SYSTEM_PACKAGES[@]}"

echo ""
echo "Installed versions:"
ruby --version
gcc --version | head -1
pkg-config --version

echo ""
echo "Installing Bundler..."
sudo gem install bundler

echo ""
echo "Ruby gems (from Gemfile):"
echo "  Production gems:"
echo "    - puma ~> 6.4 (web server)"
echo "    - sinatra ~> 3.2 (web framework)"
echo "    - sinatra-contrib ~> 3.2 (extensions)"
echo "    - pi_piper ~> 2.0 (GPIO control)"
echo ""
echo "  Development gems (optional):"
echo "    - pry ~> 0.14 (console)"
echo "    - pry-byebug ~> 3.10 (debugger)"
echo "    - rerun ~> 0.14 (auto-reload)"
echo "    - rubocop (linter)"
echo ""
echo "  Test gems (optional):"
echo "    - rspec ~> 3.13 (testing)"
echo "    - rack-test ~> 2.1 (API testing)"
echo "    - simplecov ~> 0.22 (coverage)"
echo ""

if [ -f Gemfile ]; then
    echo "Installing Ruby gems from Gemfile..."
    echo ""
    read -p "Install production gems only? (Y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        bundle config set --local without 'development test'
        echo "Installing production gems (excluding dev/test)..."
    else
        echo "Installing all gems (including dev/test)..."
    fi
    
    bundle install
    echo ""
    echo "Gems installed successfully!"
else
    echo "Gemfile not found. Run this script from the project directory."
    exit 1
fi

echo ""
echo "Dependency installation complete!"
echo ""
echo "Summary:"
echo "  - System packages: ${#SYSTEM_PACKAGES[@]} installed"
echo "  - Ruby gems: $(bundle list | grep -c '^\*') installed"
echo ""
echo "Next steps:"
echo "  1. Configure camera: See NATIVE_INSTALLATION.md"
echo "  2. Set up services: ./scripts/native-install.sh"
echo "  3. Test setup: ./scripts/test-native-setup.sh"
echo ""
