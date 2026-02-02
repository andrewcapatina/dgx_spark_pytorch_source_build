# PyTorch Build from Source - DGX Docker Container

This Dockerfile builds PyTorch from source with CUDA 13.0 support for NVIDIA DGX systems.

## Prerequisites

1. **NVIDIA DGX System** with compatible GPU drivers (version 580+ for CUDA 13.x)
2. **Docker** with NVIDIA Container Toolkit installed
3. **Sufficient disk space** (~20GB for build artifacts)
4. **RAM**: At least 16GB recommended (32GB+ preferred to avoid build failures)

## Differences from Original Document

The original document had a few issues that have been corrected:

1. **Base Image**: Using official `nvidia/cuda:13.0.0-cudnn9-devel-ubuntu22.04` instead of manual CUDA installation
2. **MAGMA Installation**: Using PyTorch's official MAGMA installation script instead of conda
3. **Python Version**: Using Python 3.10 (PyTorch requires 3.10+)
4. **Build Method**: Using `pip install -e .` instead of the deprecated `setup.py` method
5. **Architecture List**: Added comprehensive CUDA architecture list for DGX systems

## Build Instructions

### Option 1: Build the Docker Image

```bash
# Build the image (this will take 30-60 minutes)
docker build -t pytorch-cuda13.0-dgx .

# Run with GPU support
docker run --runtime=nvidia -e NVIDIA_VISIBLE_DEVICES=all -it --rm pytorch-cuda13.0-dgx

# Run with specific GPUs
docker run --runtime=nvidia -e NVIDIA_VISIBLE_DEVICES=0,1 -it --rm pytorch-cuda13.0-dgx

# Run with mounted volume for your code
docker run --runtime=nvidia -e NVIDIA_VISIBLE_DEVICES=all -it --rm -v $(pwd):/workspace pytorch-cuda13.0-dgx
```

### Option 2: Build with Docker Compose

Create a `docker-compose.yml`:

```yaml
version: '3.8'
services:
  pytorch:
    build: .
    image: pytorch-cuda13.0-dgx
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
    volumes:
      - ./workspace:/workspace
    stdin_open: true
    tty: true
```

Then run:
```bash
docker-compose build
docker-compose run pytorch
```

## Verifying the Installation

Once inside the container, run:

```bash
# Quick verification
pytorch-info

# Or manually test
python3 -c "import torch; print(torch.__version__)"
python3 -c "import torch; print(torch.cuda.is_available())"
python3 -c "import torch; print(torch.cuda.get_device_name(0))"
```

## Build Time Optimization

### Using ccache
The build includes ccache for faster rebuilds. First build will be slow, subsequent builds will be much faster.

### Controlling Build Parallelism
The `MAX_JOBS` environment variable controls parallel compilation. Default is 8.

For systems with more RAM:
```bash
docker build --build-arg MAX_JOBS=16 -t pytorch-cuda13.0-dgx .
```

For systems with less RAM (to avoid OOM):
```bash
docker build --build-arg MAX_JOBS=4 -t pytorch-cuda13.0-dgx .
```

## Important Environment Variables

- `TORCH_CUDA_ARCH_LIST`: GPU architectures to compile for
  - `7.0` - Volta (V100)
  - `7.5` - Turing (T4)
  - `8.0` - Ampere (A100, A30)
  - `8.6` - Ampere (A40, A10, RTX 30xx)
  - `8.9` - Ada (L40, L4, RTX 40xx)
  - `9.0` - Hopper (H100)

Adjust based on your DGX hardware.

## Building with Additional Features

### Installing torchvision and torchaudio

Uncomment the relevant sections in the Dockerfile, or run after the initial build:

```bash
# Inside the container
cd /workspace
git clone --recursive https://github.com/pytorch/vision.git
cd vision
python3 -m pip install --no-build-isolation -v -e .

git clone --recursive https://github.com/pytorch/audio.git
cd audio
python3 -m pip install --no-build-isolation -v -e .
```

## Troubleshooting

### Out of Memory During Build
- Reduce `MAX_JOBS` to 2-4
- Close other applications
- Ensure at least 32GB RAM available

### CUDA Version Mismatch
Verify your driver supports CUDA 13.0:
```bash
nvidia-smi
```

Driver version should be 580+ for CUDA 13.x support.

### Build Fails with CUDA Errors
Ensure the CUDA toolkit is properly detected:
```bash
nvcc --version  # Should show CUDA 13.0.x
```

## Additional Notes

### Development vs Production Build

**Development Build** (current setup):
```bash
python3 -m pip install --no-build-isolation -v -e .
```
- Allows code changes without full rebuild
- Creates editable installation

**Production Build**:
```bash
python3 -m pip install --no-build-isolation -v .
```
- Creates optimized, non-editable installation
- Slightly better performance

### DGX-Specific Considerations

For DGX A100 systems:
- Ensure `8.0` is in `TORCH_CUDA_ARCH_LIST`
- Driver version ≥ 590.x recommended

For DGX H100 systems:
- Ensure `9.0` is in `TORCH_CUDA_ARCH_LIST`
- Driver version ≥ 590.x required

## Performance Testing

Once built, test GPU performance:

```python
import torch
import time

# Create large tensors
size = 10000
a = torch.randn(size, size).cuda()
b = torch.randn(size, size).cuda()

# Warm up
c = torch.matmul(a, b)

# Benchmark
start = time.time()
for _ in range(100):
    c = torch.matmul(a, b)
torch.cuda.synchronize()
end = time.time()

print(f"Average time: {(end-start)/100*1000:.2f}ms")
print(f"GPU: {torch.cuda.get_device_name(0)}")
```

## Reference Links

- [PyTorch Build from Source](https://github.com/pytorch/pytorch#from-source)
- [CUDA 13.0 Release Notes](https://docs.nvidia.com/cuda/cuda-toolkit-release-notes/)
- [NVIDIA Docker](https://github.com/NVIDIA/nvidia-docker)
- [PyTorch Forums](https://discuss.pytorch.org/)

## License

This Dockerfile follows PyTorch's BSD-style license. See the PyTorch repository for details.
