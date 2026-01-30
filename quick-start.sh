#!/bin/bash
# Quick start script for Robot Tank Docker deployment

set -e

echo "================================"
echo "Robot Tank Docker Quick Start"
echo "================================"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed"
    echo "Please install Docker first: https://docs.docker.com/engine/install/debian/"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "Error: Docker Compose is not installed"
    echo "Please install Docker Compose first: https://docs.docker.com/compose/install/"
    exit 1
fi

# Create logs directory
mkdir -p logs

# Check if .env exists, if not copy from example
if [ ! -f .env ]; then
    echo "Creating .env file from .env.example..."
    cp .env.example .env
    echo "Please edit .env file to customize your configuration"
fi

# Prompt for deployment mode
echo "Select deployment mode:"
echo "1) Development (no GPIO, port 4567)"
echo "2) Production (GPIO enabled, port 80)"
read -p "Enter choice [1-2]: " choice

case $choice in
    1)
        echo ""
        echo "Starting in Development mode..."
        echo "Building Docker image..."
        docker-compose -f docker-compose.dev.yml build

        echo "Starting container..."
        docker-compose -f docker-compose.dev.yml up -d

        echo ""
        echo "✓ Development server started successfully!"
        echo ""
        echo "Access the application at: http://localhost:4567"
        echo "View logs: docker-compose -f docker-compose.dev.yml logs -f"
        echo "Stop server: docker-compose -f docker-compose.dev.yml down"
        echo ""
        echo "Or use the Makefile:"
        echo "  make logs    - View logs"
        echo "  make shell   - Open shell in container"
        echo "  make down    - Stop container"
        ;;
    2)
        echo ""
        echo "Starting in Production mode..."

        # Check if running on ARM64
        if [ "$(uname -m)" != "aarch64" ]; then
            echo "Warning: Production mode is designed for ARM64 (Raspberry Pi)"
            echo "Current architecture: $(uname -m)"
            read -p "Continue anyway? [y/N]: " confirm
            if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
                echo "Aborted"
                exit 0
            fi
        fi

        # Check if GPIO device exists
        if [ ! -e /dev/gpiomem ]; then
            echo "Warning: /dev/gpiomem not found"
            echo "GPIO control may not work properly"
        fi

        echo "Building Docker image..."
        docker-compose -f docker-compose.prod.yml build

        echo "Starting container..."
        docker-compose -f docker-compose.prod.yml up -d

        echo ""
        echo "✓ Production server started successfully!"
        echo ""
        echo "Access the application at: http://$(hostname -I | awk '{print $1}')"
        echo "View logs: docker-compose -f docker-compose.prod.yml logs -f"
        echo "Stop server: docker-compose -f docker-compose.prod.yml down"
        echo ""
        echo "Or use the Makefile:"
        echo "  make logs-prod  - View logs"
        echo "  make shell-prod - Open shell in container"
        echo "  make down       - Stop container"
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "For more commands, run: make help"
