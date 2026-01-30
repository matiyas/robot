#!/bin/bash
# Multi-architecture Docker build script
# Builds for ARM64 (Raspberry Pi) and optionally AMD64

set -e

IMAGE_NAME="robot-tank"
VERSION="${1:-latest}"

echo "Building multi-architecture Docker images..."
echo "Image: ${IMAGE_NAME}:${VERSION}"
echo ""

# Check if buildx is available
if ! docker buildx version &> /dev/null; then
    echo "Error: Docker buildx is not available"
    echo "Please install Docker buildx or use Docker Desktop"
    exit 1
fi

# Create builder instance if it doesn't exist
if ! docker buildx inspect multiarch-builder &> /dev/null; then
    echo "Creating multiarch builder..."
    docker buildx create --name multiarch-builder --driver docker-container --bootstrap
fi

echo "Using multiarch-builder..."
docker buildx use multiarch-builder

# Build for ARM64 (primary target - Raspberry Pi)
echo ""
echo "Building for linux/arm64..."
docker buildx build \
    --platform linux/arm64 \
    --tag ${IMAGE_NAME}:${VERSION}-arm64 \
    --tag ${IMAGE_NAME}:${VERSION} \
    --load \
    .

echo ""
echo "✓ Build complete!"
echo ""
echo "Built images:"
docker images | grep ${IMAGE_NAME}
echo ""
echo "To build for multiple architectures and push to registry:"
echo "  docker buildx build --platform linux/arm64,linux/amd64 --tag <registry>/${IMAGE_NAME}:${VERSION} --push ."

# Optional: Build for AMD64 as well (for testing on x86 machines)
# Uncomment if needed:
# echo ""
# echo "Building for linux/amd64..."
# docker buildx build \
#     --platform linux/amd64 \
#     --tag ${IMAGE_NAME}:${VERSION}-amd64 \
#     --load \
#     .

echo ""
echo "To save the image for transfer to Raspberry Pi:"
echo "  docker save ${IMAGE_NAME}:${VERSION} | gzip > robot-tank-${VERSION}.tar.gz"
echo ""
echo "To load on Raspberry Pi:"
echo "  gunzip -c robot-tank-${VERSION}.tar.gz | docker load"
