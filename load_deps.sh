#!/bin/bash

COMFYUI_DIR=$1
cd $COMFYUI_DIR

HFT="${HUGGINGFACE_TOKEN}"
CVT="${CIVITAI_TOKEN}"

if [ -z "$HFT" ]; then
    echo "Error: HUGGINGFACE_TOKEN is not set. Set it as an environment variable."
    exit 1
fi

if [ -z "$CVT" ]; then
    echo "Error: CIVITAI_TOKEN is not set. Set it as an environment variable."
    exit 1
fi

# Проверка на наличие флага установки
if [ ! -f "$COMFYUI_DIR/custom_nodes/.custom_deps_installed" ]; then
    echo "Installing custom dependencies and nodes..."
    comfy --skip-prompt tracking disable

    mkdir -p $COMFYUI_DIR/models/checkpoints $COMFYUI_DIR/models/loras $COMFYUI_DIR/models/loras/zit $COMFYUI_DIR/models/loras/chars $COMFYUI_DIR/models/ipadapter $COMFYUI_DIR/models/clip_vision

    TARGET_DIR="$COMFYUI_DIR/models/loras/chars"
    CHARS_URL="https://flammaverse.com/loras_list"
    TMP_FILE="/tmp/loras_list.txt"
    
    echo "Fetching character list…"
    curl -fsSL "$CHARS_URL" -o "$TMP_FILE"
    
    COUNT=0
    while IFS= read -r char || [ -n "$char" ]; do 
        # strip CR (на всякий случай)
        char="$(printf '%s' "$char" | tr -d '\r')"
        # skip empty lines
        [ -z "$char" ] && continue
    
        echo "Downloading: $char.safetensors into $TARGET_DIR"
        curl --fail --retry 5 --retry-max-time 0 -C - -L \
            -o "$TARGET_DIR/$char.safetensors" \
            "https://flammaverse.com/loras/$char.safetensors"
    
        COUNT=$((COUNT + 1))
    done < "$TMP_FILE"
    
    rm -f "$TMP_FILE"
    echo "Downloaded $COUNT character LoRA(s)"

    curl --fail --retry 5 --retry-max-time 0 -C - -L \
        -o "$COMFYUI_DIR/models/diffusion_models/pornmasterZImage_turboV35Bf16.safetensors" \
        "https://flammaverse.com/loras/models/diffusion_models/pornmasterZImage_turboV35Bf16.safetensors"
    
    curl --fail --retry 5 --retry-max-time 0 -C - -L \
        -o "$COMFYUI_DIR/models/text_encoders/qwen_3_4b.safetensors" \
        "https://flammaverse.com/loras/models/text_encoders/qwen_3_4b.safetensors"
    
    curl --fail --retry 5 --retry-max-time 0 -C - -L \
        -o "$COMFYUI_DIR/models/vae/ae.safetensors" \
        "https://flammaverse.com/loras/models/vae/ae.safetensors"

    touch $COMFYUI_DIR/custom_nodes/.custom_deps_installed
else
    echo "Custom dependencies already installed. Skipping..."
fi
