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
    CHARS_URL="https://flammaverse.com/loras/chars.txt"
    TMP_FILE="/tmp/chars.txt"
    
    echo "Fetching character list…"
    curl -fsSL "$CHARS_URL" -o "$TMP_FILE"
    
    COUNT=0
    while IFS= read -r char || [ -n "$char" ]; do 
        # strip CR (Windows line endings)
        char="$(printf '%s' "$char" | tr -d '\r')"
        # skip empty lines
        [ -z "$char" ] && continue
        # skip comments
        case "$char" in
            \#*) continue ;;
        esac
        echo "Downloading: $char.safetensors into $TARGET_DIR"
        curl --fail --retry 5 --retry-max-time 0 -C - -L \
            -o "$TARGET_DIR/$char.safetensors" \
            "https://flammaverse.com/loras/$char.safetensors"
        COUNT=$((COUNT + 1))
    done < "$TMP_FILE"
    rm -f "$TMP_FILE"
    echo "Downloaded $COUNT character LoRA(s)"

    # curl --fail --retry 5 --retry-max-time 0 -C - -L -H "Authorization: Bearer ${HFT}" \
    #     -o $COMFYUI_DIR/models/diffusion_models/z_image_turbo-Q4_K_S.gguf \
    #     "https://huggingface.co/jayn7/Z-Image-Turbo-GGUF/resolve/main/z_image_turbo-Q4_K_S.gguf?download=true"

    curl --fail --retry 5 --retry-max-time 0 -C - -L -H "Authorization: Bearer ${CVT}" \
        -o $COMFYUI_DIR/models/diffusion_models/pornmasterZImage_v1.safetensors \
        "https://civitai.com/api/download/models/2625016?type=Model&format=SafeTensor&size=pruned&fp=bf16"

    # curl --fail --retry 5 --retry-max-time 0 -C - -L -H "Authorization: Bearer ${CVT}" \
    #     -o $COMFYUI_DIR/models/diffusion_models/moodyPornMix_zitV6.safetensors \
    #     "https://civitai.com/api/download/models/2602723?type=Model&format=SafeTensor&size=full&fp=fp16"
    
    curl --fail --retry 5 --retry-max-time 0 -C - -L -H "Authorization: Bearer ${CVT}" \
        -o $COMFYUI_DIR/models/loras/zit/Mystic-XXX-ZIT-V5.safetensors \
        "https://civitai.com/api/download/models/2581135?type=Model&format=SafeTensor"

    curl --fail --retry 5 --retry-max-time 0 -C - -L -H "Authorization: Bearer ${HFT}" \
        -o $COMFYUI_DIR/models/text_encoders/qwen_3_4b.safetensors \
        "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors?download=true"

    curl --fail --retry 5 --retry-max-time 0 -C - -L -H "Authorization: Bearer ${HFT}" \
        -o $COMFYUI_DIR/models/vae/ae.safetensors \
        "https://huggingface.co/StableDiffusionVN/Flux/resolve/main/Vae/flux_vae.safetensors?download=true"

    touch $COMFYUI_DIR/custom_nodes/.custom_deps_installed
else
    echo "Custom dependencies already installed. Skipping..."
fi
