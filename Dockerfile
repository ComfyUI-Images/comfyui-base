FROM nvidia/cuda:12.8.0-cudnn-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1
ENV PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

WORKDIR /workspace

# ------------------------------------------------
# System dependencies
# ------------------------------------------------
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    git \
    wget \
    curl \
    ffmpeg \
    libgl1 \
    libglib2.0-0 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN ln -sf /usr/bin/python3 /usr/bin/python

# ------------------------------------------------
# Python tooling
# ------------------------------------------------
RUN python -m pip install --upgrade pip setuptools wheel

# ------------------------------------------------
# PyTorch (CUDA 12.8 compatible)
# ------------------------------------------------
RUN pip install torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu128

# ------------------------------------------------
# Clone ComfyUI and pin commit
# ------------------------------------------------
ARG COMFYUI_COMMIT=85fc35e8fa44c6174425acb4f9167792bcc903a8

RUN git clone https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI \
    && cd /workspace/ComfyUI \
    && git checkout ${COMFYUI_COMMIT}

WORKDIR /workspace/ComfyUI

# ------------------------------------------------
# Install Python dependencies strictly from repo
# ------------------------------------------------
RUN pip install --no-cache-dir -r requirements.txt

# ------------------------------------------------
# Create standard model directories
# ------------------------------------------------
RUN mkdir -p \
    /workspace/models/checkpoints \
    /workspace/models/vae \
    /workspace/models/loras \
    /workspace/models/controlnet \
    /workspace/models/upscale_models \
    /workspace/models/clip \
    /workspace/models/embeddings \
    /workspace/models/diffusers

# ------------------------------------------------
# Copy startup scripts
# ------------------------------------------------
WORKDIR /workspace

COPY start.sh /start.sh
COPY load_deps.sh /load_deps.sh

RUN chmod +x /start.sh \
 && chmod +x /load_deps.sh

# ------------------------------------------------
# Environment
# ------------------------------------------------
ENV CLI_ARGS="--listen 0.0.0.0 --port 8188"

EXPOSE 8188

# ------------------------------------------------
# Start container
# ------------------------------------------------
CMD ["/start.sh"]
