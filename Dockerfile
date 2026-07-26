# Образ GPU-пода (копия для repo ComfyUI-Images/comfyui-base, цель `regular`
# в docker-bake.hcl -> splugeola/comfyui:latest). Собирается scripts/build_pod.sh.
#
# Отличия от прежней версии: выкинуты JupyterLab, FileBrowser и sshd — их запуск
# убран из start.sh, а вес образа лежит на том же критическом пути, что и
# загрузка моделей. Взамен добавлены build-essential и python3.11-dev: раньше их
# ставил apt-get на каждом старте пода, теперь это build-time слой, нужный
# кастом-нодам с C-расширениями (список нод редактируется из админки).
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
    python3.11-dev \
    python3-pip \
    build-essential \
    git \
    curl \
    wget \
    ffmpeg \
    libgl1 \
    libglib2.0-0 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN ln -sf /usr/bin/python3.11 /usr/bin/python3

# -----------------------------
# Python tooling
# -----------------------------
RUN python3 -m pip install --upgrade pip setuptools wheel uv

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
# Ставим в системный python: start.sh запускает ComfyUI им же, без venv.
RUN pip install --no-cache-dir -r requirements.txt

# -----------------------------
# Copy start script
# -----------------------------
WORKDIR /workspace
COPY start.sh /start.sh

RUN chmod +x /start.sh

# -----------------------------
# Port for ComfyUI
# -----------------------------
EXPOSE 8188

CMD ["/start.sh"]
