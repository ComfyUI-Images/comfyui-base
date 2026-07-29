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
# v0.29.0 (2026-07-28). Подняли с 0.12.x ради LTX 2.3: воркфлоу видео требует
# LTXAVTextEncoderLoader (0.14.1), LTXVCropGuides (0.16.4), LTXVConcatAVLatent и
# LTXVSeparateAVLatent (0.17.2) — в прежнем пине этих нод просто нет.
# Пин остаётся коммитом, а не тегом: тег можно передвинуть, ветка уедет сама, а
# ловить сломанное обновление пришлось бы на уже оплаченной GPU. Откат при
# регрессе: v0.28.0 = 700821e1364eaab0e8f21c538a2131719fec57bf.
ARG COMFYUI_VERSION=a8c44f9b2a0678ac4082e3529a3f43db7472acfe
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /workspace/runpod-slim/ComfyUI \
    && cd /workspace/runpod-slim/ComfyUI \
    && git checkout ${COMFYUI_VERSION}

WORKDIR /workspace/runpod-slim/ComfyUI

# -----------------------------
# Install ComfyUI dependencies
# -----------------------------
# Ставим в системный python: start.sh запускает ComfyUI им же, без venv.
RUN python3 -m pip install --no-cache-dir -r requirements.txt

# ComfyUI_Base64Images импортирует cv2 на уровне модуля (нужен только классу
# LoadImageFromBase64), но requirements.txt у ноды нет — раньше opencv приезжал
# транзитом из KJNodes, которые мы убрали. headless-сборка: GUI-функции на
# сервере не нужны, а весит вдвое меньше.
RUN python3 -m pip install --no-cache-dir opencv-python-headless

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
