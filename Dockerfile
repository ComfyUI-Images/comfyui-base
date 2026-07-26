# Образ GPU-пода (копия для repo ComfyUI-Images/comfyui-base, цель `regular`
# в docker-bake.hcl -> splugeola/comfyui:latest). Собирается scripts/build_pod.sh.
#
# Отличия от прежней версии: выкинуты JupyterLab, FileBrowser и sshd — их запуск
# убран из start.sh, а вес образа лежит на том же критическом пути, что и
# загрузка моделей. Взамен добавлены build-essential и python3.12-dev: раньше их
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
# Python берём из deadsnakes, а не из ubuntu 22.04: тамошний python3.11 — это
# релиз-кандидат (3.11.0rc1), на котором PyTorch падает по segfault в
# TorchScript. Тот же приём уже используется в Dockerfile.5090.
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    gpg-agent \
    ca-certificates \
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y --no-install-recommends \
    python3.12 \
    python3.12-venv \
    python3.12-dev \
    build-essential \
    git \
    curl \
    wget \
    ffmpeg \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# python3-pip из ubuntu тянет за собой python3.10 — ставим pip прямо для 3.12.
RUN curl -sS https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py \
    && python3.12 /tmp/get-pip.py \
    && rm /tmp/get-pip.py

RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 \
    && update-alternatives --set python3 /usr/bin/python3.12

# -----------------------------
# Python tooling
# -----------------------------
RUN python3 -m pip install --upgrade pip setuptools wheel uv

# -----------------------------
# PyTorch
# -----------------------------
RUN python3 -m pip install torch torchvision torchaudio \
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
RUN python3 -m pip install --no-cache-dir -r requirements.txt

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
