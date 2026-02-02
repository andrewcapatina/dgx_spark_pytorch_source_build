# Dockerfile for building PyTorch from source on DGX with CUDA 13.0
# Base image with CUDA 13.0 and cuDNN support
FROM nvidia/cuda:13.0.0-cudnn-devel-ubuntu22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    CUDA_HOME=/usr/local/cuda \
    CUDA_PATH=/usr/local/cuda \
    CUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda \
    CUDNN_LIB_DIR=/usr/local/cuda/lib64 \
    CUDA_BIN_PATH=/usr/local/cuda/bin \
    PATH=/usr/local/cuda/bin:${PATH} \
    LD_LIBRARY_PATH=/usr/local/cuda/lib64:${LD_LIBRARY_PATH} \
    TORCH_CUDA_ARCH_LIST="12.1" \
    FORCE_CUDA=1 \
    USE_CUDA=1 \
    MAX_JOBS=8 \
    CXXFLAGS="-Wno-stringop-overflow"

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    ccache \
    curl \
    git \
    libjpeg-dev \
    libpng-dev \
    libgomp1 \
    ninja-build \
    software-properties-common \
    wget \
    gpg \
    && rm -rf /var/lib/apt/lists/*

# Install CMake 3.27+ (PyTorch requires >= 3.27)
# Ubuntu 22.04 only has 3.22, so we install from Kitware's official repository
RUN wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | \
    gpg --dearmor - | tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null && \
    echo 'deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ jammy main' | \
    tee /etc/apt/sources.list.d/kitware.list >/dev/null && \
    apt-get update && \
    apt-get install -y cmake && \
    rm -rf /var/lib/apt/lists/*

# Verify CMake version
RUN cmake --version && \
    python3 -c "import re; v=__import__('subprocess').check_output(['cmake', '--version']).decode(); \
    ver=re.search(r'(\d+\.\d+)', v).group(1); \
    major,minor=map(int,ver.split('.')); \
    assert major>3 or (major==3 and minor>=27), f'CMake {ver} is too old, need >=3.27'"

# Install Python 3.10 and dependencies
RUN add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    python3.10 \
    python3.10-dev \
    python3.10-distutils \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Set Python 3.10 as default
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3.10 1

# Upgrade pip and install Python build dependencies
RUN python3 -m pip install --upgrade pip setuptools wheel

# Install PyTorch Python dependencies
RUN pip install --no-cache-dir \
    numpy \
    pyyaml \
    typing_extensions \
    sympy \
    filelock \
    networkx \
    jinja2 \
    fsspec

# Clone PyTorch repository
COPY pytorch /workspace/pytorch/
#RUN git clone --recursive https://github.com/pytorch/pytorch.git /workspace/pytorch

WORKDIR /workspace/pytorch

# Update submodules (important for a complete build)
RUN git submodule sync && \
    git submodule update --init --recursive

RUN cd /workspace/pytorch

# Install MKL (Math Kernel Library) for optimized CPU operations
# MKL is optimized for Intel CPUs but works on AMD too
# For AMD CPUs, you can optionally use OpenBLAS instead (see comments below)

# TODO: Install cuBLASS instead
# RUN pip install --no-cache-dir mkl-static mkl-include

# Alternative for AMD CPUs (comment out MKL above and uncomment below):
# RUN apt-get update && apt-get install -y libopenblas-dev && \
#     pip install --no-cache-dir numpy

# Install MAGMA using PyTorch's conda installation script
# Note: Use bash to execute the script, and specify CUDA version 13.0
RUN bash .ci/docker/common/install_magma.sh 13.0

RUN make triton

# Set CMAKE_PREFIX_PATH for finding libraries
# This tells CMake where to find CUDA, cuDNN, MKL, MAGMA, and other dependencies
ENV CMAKE_PREFIX_PATH=/usr/local/cuda:/usr/local:/usr:${CMAKE_PREFIX_PATH}

# Build PyTorch from source
# Using python setup.py develop for development mode (faster rebuilds)
# Use 'python setup.py install' for production builds
RUN CMAKE_PREFIX_PATH="/usr/local/cuda:/usr/local:/usr:${CMAKE_PREFIX_PATH}" \
    python3 -m pip install --no-build-isolation -v -e .

# Create symlinks for faster incremental rebuilds during development
RUN bash -c "cd /workspace/pytorch/torch/lib && ln -sf ../../build/lib/libtorch_cpu.* ."

# Verify installation
RUN python3 -c "import torch; print(f'PyTorch version: {torch.__version__}'); print(f'CUDA available: {torch.cuda.is_available()}'); print(f'CUDA version: {torch.version.cuda}')"

# Optional: Install torchvision and torchaudio from source
# Uncomment if needed
# RUN git clone --recursive https://github.com/pytorch/vision.git /workspace/vision && \
#     cd /workspace/vision && \
#     python3 -m pip install --no-build-isolation -v -e .

# RUN git clone --recursive https://github.com/pytorch/audio.git /workspace/audio && \
#     cd /workspace/audio && \
#     python3 -m pip install --no-build-isolation -v -e .

# Set working directory for user code
WORKDIR /workspace

# Add helpful runtime info
RUN echo '#!/bin/bash\n\
echo "PyTorch Build Information:"\n\
python3 -c "import torch; print(f\"PyTorch version: {torch.__version__}\")"\n\
python3 -c "import torch; print(f\"CUDA available: {torch.cuda.is_available()}\")"\n\
python3 -c "import torch; print(f\"CUDA version: {torch.version.cuda}\")"\n\
python3 -c "import torch; print(f\"cuDNN version: {torch.backends.cudnn.version()}\")"\n\
python3 -c "import torch; print(f\"Number of GPUs: {torch.cuda.device_count()}\")"\n\
if [ $(python3 -c "import torch; print(torch.cuda.device_count())") -gt 0 ]; then\n\
    python3 -c "import torch; print(f\"GPU 0: {torch.cuda.get_device_name(0)}\")"\n\
fi\n\
nvidia-smi\n\
' > /usr/local/bin/pytorch-info && \
chmod +x /usr/local/bin/pytorch-info

# Copy development scripts and test files
COPY rebuild-pytorch.sh /workspace/rebuild-pytorch.sh
RUN chmod +x /workspace/rebuild-pytorch.sh
# COPY serialize.py /workspace/serialize.py
# COPY deserialize.py /workspace/deserialize.py
# COPY entrypoint.sh /workspace/entrypoint.sh
COPY rebuild-pytorch /workspace/rebuild-pytorch.sh

CMD ["/bin/bash"]

# Install PyTorch Test Python dependencies
RUN pip install --no-cache-dir \
    expecttest \
    tzdata