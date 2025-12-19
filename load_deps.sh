#!/bin/bash

# Проверка на наличие флага установки
if [ ! -f "/workspace/ComfyUI/custom_nodes/.custom_deps_installed" ]; then
    echo "Installing custom dependencies and nodes..."

    # Установка custom nodes через ComfyUI-Manager
    comfy node install --exit-on-fail comfyui_ipadapter_plus@2.0.0
    comfy node install --exit-on-fail comfyui-base64-to-image@1.0.0

    # Создание флага, чтобы не повторять
    touch /workspace/ComfyUI/custom_nodes/.custom_deps_installed
else
    echo "Custom dependencies already installed. Skipping..."
fi
