#!/bin/bash
# Build script for PyTorch on DGX with CUDA 13.0
# This script performs pre-build checks and builds the Docker image

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "======================================"
echo "PyTorch DGX Build Script"
echo "======================================"
echo ""

# Function to print colored messages
print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_info() {
    echo -e "[i] $1"
}

# Check if running with sudo (not recommended)
if [ "$EUID" -eq 0 ]; then 
    print_warning "Running as root. It's recommended to run Docker as a non-root user."
fi

# Check Docker installation
print_info "Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi
print_success "Docker is installed: $(docker --version)"

# Check NVIDIA Docker runtime
print_info "Checking NVIDIA Docker runtime..."
if ! docker run --rm --runtime=nvidia -e NVIDIA_VISIBLE_DEVICES=all nvidia/cuda:13.0.0-base-ubuntu22.04 nvidia-smi &> /dev/null; then
    print_error "NVIDIA Docker runtime is not properly configured."
    print_info "Please install nvidia-container-toolkit:"
    print_info "  https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html"
    exit 1
fi
print_success "NVIDIA Docker runtime is configured"

# Check NVIDIA driver version
print_info "Checking NVIDIA driver version..."
DRIVER_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n 1)
DRIVER_MAJOR=$(echo $DRIVER_VERSION | cut -d. -f1)

if [ "$DRIVER_MAJOR" -lt 580 ]; then
    print_error "NVIDIA driver version $DRIVER_VERSION is too old for CUDA 13.0"
    print_error "Please upgrade to driver version 580 or newer"
    exit 1
fi
print_success "NVIDIA driver version: $DRIVER_VERSION (compatible with CUDA 13.0)"

# Check available disk space
print_info "Checking available disk space..."
AVAILABLE_SPACE=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')
if [ "$AVAILABLE_SPACE" -lt 20 ]; then
    print_warning "Low disk space: ${AVAILABLE_SPACE}GB available"
    print_warning "At least 20GB recommended for build. Continue? (y/n)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    print_success "Sufficient disk space: ${AVAILABLE_SPACE}GB available"
fi

# Check available RAM
print_info "Checking available RAM..."
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
if [ "$TOTAL_RAM" -lt 16 ]; then
    print_warning "System has ${TOTAL_RAM}GB RAM. At least 16GB recommended."
    print_warning "Consider reducing MAX_JOBS in Dockerfile to avoid OOM errors."
fi
print_success "Total RAM: ${TOTAL_RAM}GB"

# Check GPU information
print_info "Detecting GPUs..."
echo ""
nvidia-smi --query-gpu=index,name,compute_cap --format=csv,noheader | while IFS=',' read -r idx name compute_cap; do
    print_success "GPU $idx: $name (Compute Capability: $compute_cap)"
done
echo ""

# Ask for build options
echo "======================================"
echo "Build Configuration"
echo "======================================"
echo ""

# Number of parallel jobs
read -p "Enter number of parallel build jobs (default: 8, lower for less RAM): " MAX_JOBS
MAX_JOBS=${MAX_JOBS:-8}
print_info "Using MAX_JOBS=$MAX_JOBS"

# Build tag
read -p "Enter Docker image tag (default: pytorch-cuda13.0-dgx:latest): " IMAGE_TAG
IMAGE_TAG=${IMAGE_TAG:-pytorch-cuda13.0-dgx:latest}
print_info "Building image: $IMAGE_TAG"

echo ""
echo "======================================"
echo "Starting Build"
echo "======================================"
echo ""
print_warning "This will take approximately 30-60 minutes..."
echo ""

# Build the Docker image
if docker build --build-arg MAX_JOBS=$MAX_JOBS -t $IMAGE_TAG .; then
    echo ""
    echo "======================================"
    print_success "Build completed successfully!"
    echo "======================================"
    echo ""
    print_info "To run the container:"
    echo "  docker run --runtime=nvidia -e NVIDIA_VISIBLE_DEVICES=all -it --rm $IMAGE_TAG"
    echo ""
    print_info "To run with mounted workspace:"
    echo "  docker run --runtime=nvidia -e NVIDIA_VISIBLE_DEVICES=all -it --rm -v \$(pwd)/workspace:/workspace $IMAGE_TAG"
    echo ""
    print_info "To verify installation:"
    echo "  docker run --runtime=nvidia -e NVIDIA_VISIBLE_DEVICES=all --rm $IMAGE_TAG pytorch-info"
    echo ""
else
    echo ""
    echo "======================================"
    print_error "Build failed!"
    echo "======================================"
    echo ""
    print_info "Common issues:"
    echo "  - Out of memory: Reduce MAX_JOBS in Dockerfile"
    echo "  - Network errors: Check internet connection"
    echo "  - CUDA errors: Verify NVIDIA driver compatibility"
    echo ""
    exit 1
fi
