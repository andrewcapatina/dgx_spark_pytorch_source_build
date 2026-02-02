#!/bin/bash
# Quick rebuild script for PyTorch development
# Use this after modifying PyTorch source files for fast incremental builds

set -e

echo "Starting PyTorch incremental rebuild..."
cd /workspace/pytorch

# Quick build (only rebuilds changed files)
python setup.py build

echo "Build complete! The symlinks in torch/lib/ now point to the updated libraries."
echo "You can test your changes immediately without reinstalling."
