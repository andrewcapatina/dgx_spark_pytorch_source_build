#!/bin/bash
# Build and run PyTorch development container
set -e  # Exit on error

IMAGE_NAME="pytorch-cuda13.0-dgx"

# Run the container with GPUs
# Mount local workspace folder to /host-workspace in container
docker run --runtime=nvidia -e NVIDIA_VISIBLE_DEVICES=all -it --rm \
    "$IMAGE_NAME"
# -v /home/cap/Projects/pytorch_source/rebuild-pytorch.sh:/usr/local/bin/rebuild-pytorch.sh:ro \
# -v /home/cap/Projects/pytorch_source:/host-workspace \
# -v /home/cap/Projects/pytorch_source/pytorch:/workspace/pytorch \