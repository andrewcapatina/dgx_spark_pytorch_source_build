#!/bin/bash
# Build and run PyTorch development container
set -e  # Exit on error

IMAGE_NAME="pytorch-cuda13.0-dgx"

echo "Building Docker image: $IMAGE_NAME..."
echo "This may take 30+ minutes for the initial build..."

# Build the image
docker build -t "$IMAGE_NAME" .