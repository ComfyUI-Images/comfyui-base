#!/bin/bash

COMFYUI_DIR=$1

# Проверка на наличие флага установки
if [ ! -f "$COMFYUI_DIR/custom_nodes/.custom_deps_installed" ]; then
    echo "Installing custom dependencies and nodes..."

    # Установка custom nodes через ComfyUI-Manager
    comfy node install --exit-on-fail comfyui_ipadapter_plus@2.0.0
    comfy node install --exit-on-fail comfyui-base64-to-image@1.0.0

    CVT="8894b6af3f93a899ba9d2f268ddc45aa"

    curl --fail --retry 5 --retry-max-time 0 -C - -L -H "Authorization: Bearer ${CVT}" \
        -o $COMFYUI_DIR/models/checkpoints/pornmaster_proSDXLV7.safetensors \
        "https://civitai.com/api/download/models/2043971?type=Model&format=SafeTensor&size=pruned&fp=fp16"

    curl --fail --retry 5 --retry-max-time 0 -C - -L -H "Authorization: Bearer ${CVT}" \
        -o $COMFYUI_DIR/models/loras/Seductive_Expression_SDXL-000040.safetensors \
        "https://civitai.com/api/download/models/2188184?type=Model&format=SafeTensor"
    
    curl --fail --retry 5 --retry-max-time 0 -C - -L -H "Authorization: Bearer ${CVT}" \
        -o $COMFYUI_DIR/models/loras/Seductive_Finger_Lips_Expression_SDXL-000046.safetensors \
        "https://civitai.com/api/download/models/2277333?type=Model&format=SafeTensor"
    
    # === CLIP-VISION MODELS ===
    curl --fail --retry 5 --retry-max-time 0 -C - -L \
        -o $COMFYUI_DIR/models/clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors \
        "https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors"
    
    curl --fail --retry 5 --retry-max-time 0 -C - -L \
        -o $COMFYUI_DIR/models/clip_vision/CLIP-ViT-bigG-14-laion2B-39B-b160k.safetensors \
        "https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/image_encoder/model.safetensors"
    
    # === SDXL IPADAPTER MODELS ===
    curl --fail --retry 5 --retry-max-time 0 -C - -L \
        -o $COMFYUI_DIR/models/ipadapter/ip-adapter_sdxl_vit-h.safetensors \
        "https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter_sdxl_vit-h.safetensors"
    
    curl --fail --retry 5 --retry-max-time 0 -C - -L \
        -o $COMFYUI_DIR/models/ipadapter/ip-adapter-plus_sdxl_vit-h.safetensors \
        "https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter-plus_sdxl_vit-h.safetensors"
    
    curl --fail --retry 5 --retry-max-time 0 -C - -L \
        -o $COMFYUI_DIR/models/ipadapter/ip-adapter-plus-face_sdxl_vit-h.safetensors \
        "https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter-plus-face_sdxl_vit-h.safetensors"
    
    curl --fail --retry 5 --retry-max-time 0 -C - -L \
        -o $COMFYUI_DIR/models/ipadapter/ip-adapter_sdxl.safetensors \
        "https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter_sdxl.safetensors"
    
    # === FACEID PLUS V2 MODELS ===
    curl --fail --retry 5 --retry-max-time 0 -C - -L \
        -o $COMFYUI_DIR/models/ipadapter/ip-adapter-faceid-plusv2_sd15.bin \
        "https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sd15.bin"
    
    curl --fail --retry 5 --retry-max-time 0 -C - -L \
        -o $COMFYUI_DIR/models/ipadapter/ip-adapter-faceid-plusv2_sdxl.bin \
        "https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl.bin"

    # === FACEID PLUS V2 LoRAs ===
    curl --fail --retry 5 --retry-max-time 0 -C - -L \
        -o $COMFYUI_DIR/models/loras/ip-adapter-faceid-plusv2_sd15_lora.safetensors \
        "https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sd15_lora.safetensors"
    
    curl --fail --retry 5 --retry-max-time 0 -C - -L \
        -o $COMFYUI_DIR/models/loras/ip-adapter-faceid-plusv2_sdxl_lora.safetensors \
        "https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl_lora.safetensors"

    # Создание флага, чтобы не повторять
    touch $COMFYUI_DIR/custom_nodes/.custom_deps_installed
else
    echo "Custom dependencies already installed. Skipping..."
fi
