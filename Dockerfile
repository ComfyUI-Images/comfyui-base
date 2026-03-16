FROM nvidia/cuda:12.8.0-cudnn-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1
ENV PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

WORKDIR /workspace

# -----------------------------
# System dependencies
# -----------------------------
RUN apt-get update && apt-get install -y \
    python3.11 \
    python3.11-venv \
    python3-pip \
    git \
    curl \
    wget \
    ffmpeg \
    openssh-server \
    openssl \
    libgl1 \
    libglib2.0-0 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/run/sshd \
    && ln -sf /usr/bin/python3.11 /usr/bin/python3

# -----------------------------
# Python tooling
# -----------------------------
RUN python3 -m pip install --upgrade pip setuptools wheel uv jupyterlab

# -----------------------------
# Install FileBrowser
# -----------------------------
RUN curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash

# -----------------------------
# PyTorch
# -----------------------------
RUN pip install torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu128

# -----------------------------
# Create RunPod directories
# -----------------------------
RUN mkdir -p /workspace/runpod-slim

# -----------------------------
# Clone ComfyUI (fixed tag)
# -----------------------------
ARG COMFYUI_VERSION=85fc35e8fa44c6174425acb4f9167792bcc903a8
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /workspace/runpod-slim/ComfyUI \
    && cd /workspace/runpod-slim/ComfyUI \
    && git checkout ${COMFYUI_VERSION}

WORKDIR /workspace/runpod-slim/ComfyUI

# -----------------------------
# Install ComfyUI dependencies
# -----------------------------
RUN pip install --no-cache-dir -r requirements.txt

# -----------------------------
# Copy start scripts
# -----------------------------
WORKDIR /workspace
COPY start.sh /start.sh
COPY load_deps.sh /load_deps.sh

RUN chmod +x /start.sh /load_deps.sh

# -----------------------------
# Ports for SSH, FileBrowser, Jupyter, ComfyUI
# -----------------------------
EXPOSE 22 8080 8188 8888

CMD ["/start.sh"]
