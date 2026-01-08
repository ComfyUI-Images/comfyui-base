#!/bin/bash

COMFYUI_DIR=$1
cd $COMFYUI_DIR

# Проверка на наличие флага установки
if [ ! -f "$COMFYUI_DIR/custom_nodes/.custom_deps_installed" ]; then
    echo "Installing custom dependencies and nodes..."

    # Установка custom nodes через ComfyUI-Manager
    comfy --skip-prompt tracking disable
    # comfy node install rgthree-comfy
    # comfy node install comfyui_ultimatesdupscale
    # comfy node install comfyui_essentials
    # comfy node install ComfyUI_Base64Images
    # comfy node show installed

    # mkdir -p $COMFYUI_DIR/models/checkpoints $COMFYUI_DIR/models/loras $COMFYUI_DIR/models/ipadapter $COMFYUI_DIR/models/clip_vision

    CVT="8894b6af3f93a899ba9d2f268ddc45aa"
    HFT="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"

    # curl --fail --retry 5 --retry-max-time 0 -C - -L -H "Authorization: Bearer ${HFT}" \
    #     -o $COMFYUI_DIR/models/diffusion_models/z_image_turbo-Q4_K_S.gguf \
    #     "https://huggingface.co/jayn7/Z-Image-Turbo-GGUF/resolve/main/z_image_turbo-Q4_K_S.gguf?download=true"
    
    # curl --fail --retry 5 --retry-max-time 0 -C - -L -H "Authorization: Bearer ${CVT}" \
    #     -o $COMFYUI_DIR/models/loras/Mystic-XXX-ZIT-v3.safetensors \
    #     "https://civitai.com/api/download/models/2530056?type=Model&format=SafeTensor"

    # curl --fail --retry 5 --retry-max-time 0 -C - -L -H "Authorization: Bearer ${HFT}" \
    #     -o $COMFYUI_DIR/models/text_encoders/qwen_3_4b.safetensors \
    #     "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors?download=true"

    # curl --fail --retry 5 --retry-max-time 0 -C - -L -H "Authorization: Bearer ${HFT}" \
    #     -o $COMFYUI_DIR/models/vae/flux_vae.safetensors \
    #     "https://huggingface.co/StableDiffusionVN/Flux/resolve/main/Vae/flux_vae.safetensors?download=true"

    TARGET_DIR="$COMFYUI_DIR/models/loras/chars"
    mkdir -p "$TARGET_DIR"

    git clone https://github.com/Asidert/FLM_C.git "$TARGET_DIR"
    cd "$TARGET_DIR"

    for file in *.zip; do
        if [ -f "$file" ]; then
            new_name="${file%.zip}.safetensors"
            mv "$file" "$new_name"
            echo "Переименован: $file -> $new_name"
        fi
    done

    # Создание флага, чтобы не повторять
    touch $COMFYUI_DIR/custom_nodes/.custom_deps_installed
else
    echo "Custom dependencies already installed. Skipping..."
fi
