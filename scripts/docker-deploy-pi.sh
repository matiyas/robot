#!/bin/bash
# Deployment script for Raspberry Pi
# Run this on your Raspberry Pi to deploy the Docker container

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Robot Tank Docker Deployment${NC}"
echo -e "${GREEN}Raspberry Pi Setup${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# Function to print colored messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}! $1${NC}"
}

# Check if running on Raspberry Pi
if [ ! -f /proc/device-tree/model ]; then
    print_warning "Not running on Raspberry Pi"
else
    MODEL=$(cat /proc/device-tree/model)
    echo "Device: $MODEL"
fi

# Check architecture
ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ]; then
    print_warning "Expected ARM64 architecture, got: $ARCH"
fi

echo ""
echo "Checking prerequisites..."
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed"
    echo ""
    echo "Install Docker with:"
    echo "  curl -fsSL https://get.docker.com -o get-docker.sh"
    echo "  sudo sh get-docker.sh"
    echo "  sudo usermod -aG docker \$USER"
    exit 1
else
    DOCKER_VERSION=$(docker --version)
    print_success "Docker installed: $DOCKER_VERSION"
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose is not installed"
    echo ""
    echo "Install Docker Compose with:"
    echo "  sudo apt-get update"
    echo "  sudo apt-get install docker-compose-plugin"
    exit 1
else
    COMPOSE_VERSION=$(docker-compose --version)
    print_success "Docker Compose installed: $COMPOSE_VERSION"
fi

# Check if user is in docker group
if ! groups | grep -q docker; then
    print_warning "Current user is not in docker group"
    echo "Add user to docker group: sudo usermod -aG docker \$USER"
    echo "Then log out and back in"
fi

# Check for GPIO device
if [ ! -e /dev/gpiomem ]; then
    print_warning "/dev/gpiomem not found - GPIO may not work"
else
    print_success "GPIO device found"
fi

# Check for camera device
if [ ! -e /dev/video0 ]; then
    print_warning "/dev/video0 not found - Camera may not work"
    echo "Enable camera with: sudo raspi-config"
else
    print_success "Camera device found"
fi

echo ""
echo "Setting up application..."
echo ""

# Create required directories
mkdir -p logs
print_success "Created logs directory"

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        cp .env.example .env
        print_success "Created .env from template"
        print_warning "Please review and edit .env file"
    else
        print_warning ".env.example not found"
    fi
else
    print_success ".env file exists"
fi

# Get IP address for display
IP_ADDR=$(hostname -I | awk '{print $1}')

echo ""
echo "Ready to deploy!"
echo ""
echo "Would you like to:"
echo "1) Build and start the container now"
echo "2) Just build the image (don't start)"
echo "3) Exit and configure manually"
read -p "Enter choice [1-3]: " choice

case $choice in
    1)
        echo ""
        echo "Building Docker image (this may take several minutes)..."
        docker-compose -f docker-compose.prod.yml build

        print_success "Image built successfully"
        echo ""
        echo "Starting container..."
        docker-compose -f docker-compose.prod.yml up -d

        # Wait for container to be healthy
        echo ""
        echo "Waiting for application to start..."
        sleep 10

        # Check if container is running
        if docker ps | grep -q robot-tank-prod; then
            print_success "Container is running!"

            # Check health
            if curl -f -s http://localhost/health > /dev/null 2>&1; then
                print_success "Application is healthy!"
            else
                print_warning "Application may still be starting..."
            fi

            echo ""
            echo "================================"
            echo -e "${GREEN}Deployment Complete!${NC}"
            echo "================================"
            echo ""
            echo "Access your robot at:"
            echo -e "${GREEN}http://${IP_ADDR}${NC}"
            echo ""
            echo "Useful commands:"
            echo "  make logs       - View logs"
            echo "  make shell-prod - Open shell"
            echo "  make down       - Stop container"
            echo "  make restart    - Restart container"
            echo ""
        else
            print_error "Container failed to start"
            echo "Check logs with: docker-compose -f docker-compose.prod.yml logs"
            exit 1
        fi
        ;;
    2)
        echo ""
        echo "Building Docker image..."
        docker-compose -f docker-compose.prod.yml build
        print_success "Image built successfully"
        echo ""
        echo "To start the container, run:"
        echo "  docker-compose -f docker-compose.prod.yml up -d"
        ;;
    3)
        echo ""
        echo "Configuration files are ready in:"
        echo "  docker-compose.prod.yml - Production configuration"
        echo "  .env - Environment variables"
        echo ""
        echo "When ready, build and start with:"
        echo "  docker-compose -f docker-compose.prod.yml up -d"
        ;;
    *)
        print_error "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "For more information, see DOCKER.md"
