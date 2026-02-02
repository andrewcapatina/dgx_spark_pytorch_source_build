# Quick Start Guide

## Prerequisites Check

Before building, ensure you have:

1. **NVIDIA DGX system** or system with NVIDIA GPU
2. **NVIDIA Driver 580+** for CUDA 13.0 support
3. **Docker** and **nvidia-container-toolkit** installed
4. **20GB+ free disk space**
5. **16GB+ RAM** (32GB+ recommended)

## Quick Commands

### Build and Run

```bash
# Make build script executable
chmod +x build.sh

# Run automated build (recommended)
./build.sh

# Or build manually
docker build -t pytorch-cuda13.0-dgx .

# Run container
docker run --runtime=nvidia -e NVIDIA_VISIBLE_DEVICES=all -it --rm pytorch-cuda13.0-dgx
```

### Verify Installation

```bash
# Inside container, run:
pytorch-info

# Or from outside:
docker run --runtime=nvidia -e NVIDIA_VISIBLE_DEVICES=all --rm pytorch-cuda13.0-dgx pytorch-info
```

### Expected Output

```
PyTorch Build Information:
PyTorch version: 2.x.x+gitXXXXXXX
CUDA available: True
CUDA version: 13.0
cuDNN version: 9XXXX
Number of GPUs: X
GPU 0: NVIDIA A100-SXM4-80GB
```

## Common Issues

### Issue: "CUDA not available" 
**Solution**: Ensure you're using `--runtime=nvidia -e NVIDIA_VISIBLE_DEVICES=all` flags when running docker

### Issue: "Out of memory during build"
**Solution**: 
1. Close other applications
2. Reduce MAX_JOBS in Dockerfile to 2-4
3. Use the build script to set custom MAX_JOBS

### Issue: "Driver version mismatch"
**Solution**: Upgrade NVIDIA driver to version 580+
```bash
# Check current driver
nvidia-smi

# Update driver (Ubuntu)
sudo apt update
sudo apt install nvidia-driver-580
```

### Issue: "Docker daemon not running"
**Solution**:
```bash
sudo systemctl start docker
sudo systemctl enable docker
```

## Using with Jupyter

```bash
# Start with docker-compose (includes Jupyter)
docker-compose --profile jupyter up

# Access Jupyter at: http://localhost:8888
```

## Development Workflow

```bash
# Run with mounted workspace
docker run --runtime=nvidia -e NVIDIA_VISIBLE_DEVICES=all -it --rm \
  -v $(pwd)/workspace:/workspace \
  pytorch-cuda13.0-dgx

# Inside container, your code in ./workspace is accessible
cd /workspace
python3 your_script.py
```

## Testing GPU Performance

Create a test file `test_gpu.py`:

```python
import torch
import time

print(f"PyTorch version: {torch.__version__}")
print(f"CUDA available: {torch.cuda.is_available()}")
print(f"CUDA version: {torch.version.cuda}")
print(f"GPU count: {torch.cuda.device_count()}")

if torch.cuda.is_available():
    print(f"GPU name: {torch.cuda.get_device_name(0)}")
    
    # Simple performance test
    size = 5000
    a = torch.randn(size, size).cuda()
    b = torch.randn(size, size).cuda()
    
    # Warm up
    c = torch.matmul(a, b)
    torch.cuda.synchronize()
    
    # Benchmark
    start = time.time()
    for _ in range(100):
        c = torch.matmul(a, b)
    torch.cuda.synchronize()
    elapsed = time.time() - start
    
    print(f"\nPerformance: {elapsed/100*1000:.2f}ms per matrix multiplication")
    print(f"({size}x{size} @ {size}x{size})")
```

Run it:
```bash
docker run --runtime=nvidia -e NVIDIA_VISIBLE_DEVICES=all --rm \
  -v $(pwd):/workspace \
  pytorch-cuda13.0-dgx \
  python3 /workspace/test_gpu.py
```

## Next Steps

1. Read the full [README.md](README.md) for detailed information
2. Check [Dockerfile](Dockerfile) for build customization options
3. Modify `TORCH_CUDA_ARCH_LIST` based on your GPU architecture
4. Add additional packages as needed in Dockerfile

## Support

- PyTorch Forums: https://discuss.pytorch.org/
- PyTorch GitHub: https://github.com/pytorch/pytorch/issues
- CUDA Documentation: https://docs.nvidia.com/cuda/

## Key Files

- `Dockerfile` - Main build definition
- `docker-compose.yml` - Orchestration config
- `build.sh` - Automated build script with checks
- `README.md` - Comprehensive documentation
- `QUICKSTART.md` - This file
