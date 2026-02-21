#!/bin/bash
# Build and run PyTorch development container
set -e  # Exit on error

IMAGE_NAME="pytorch-cuda13.0-dgx"

# Run the container with GPUs
# Mount local workspace folder to /host-workspace in container
docker run --memory=123g --runtime=nvidia -e NVIDIA_VISIBLE_DEVICES=all -it --rm \
    "$IMAGE_NAME"