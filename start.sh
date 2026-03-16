#!/bin/bash
set -e

COMFYUI_DIR="/workspace/runpod-slim/ComfyUI"
VENV_DIR="$COMFYUI_DIR/.venv"
ARGS_FILE="/workspace/runpod-slim/comfyui_args.txt"
FILEBROWSER_DB="/workspace/runpod-slim/filebrowser.db"

# -----------------------------
# SSH Setup
# -----------------------------
setup_ssh() {
    mkdir -p ~/.ssh
    for type in rsa dsa ecdsa ed25519; do
        if [ ! -f "/etc/ssh/ssh_host_${type}_key" ]; then
            ssh-keygen -t $type -f "/etc/ssh/ssh_host_${type}_key" -N '' -q
        fi
    done
    if [[ $PUBLIC_KEY ]]; then
        echo "$PUBLIC_KEY" >> ~/.ssh/authorized_keys
        chmod 700 -R ~/.ssh
    else
        RANDOM_PASS=$(openssl rand -base64 12)
        echo "root:$RANDOM_PASS" | chpasswd
        echo "Generated random SSH password for root: $RANDOM_PASS"
    fi
    echo "PermitUserEnvironment yes" >> /etc/ssh/sshd_config
    /usr/sbin/sshd
}

# -----------------------------
# Environment Variables
# -----------------------------
export_env_vars() {
    ENV_FILE="/etc/environment"
    PAM_ENV_FILE="/etc/security/pam_env.conf"
    SSH_ENV="/root/.ssh/environment"
    cp "$ENV_FILE" "${ENV_FILE}.bak" 2>/dev/null || true
    cp "$PAM_ENV_FILE" "${PAM_ENV_FILE}.bak" 2>/dev/null || true
    > "$ENV_FILE"
    > "$PAM_ENV_FILE"
    mkdir -p /root/.ssh
    > "$SSH_ENV"
    printenv | grep -E '^RUNPOD_|^PATH=|^CUDA|^LD_LIBRARY_PATH|^PYTHONPATH' | while read -r line; do
        name=$(echo "$line" | cut -d= -f1)
        value=$(echo "$line" | cut -d= -f2-)
        echo "$name=\"$value\"" >> "$ENV_FILE"
        echo "$name DEFAULT=\"$value\"" >> "$PAM_ENV_FILE"
        echo "$name=\"$value\"" >> "$SSH_ENV"
        echo "export $name=\"$value\"" >> /etc/rp_environment
    done
    echo 'source /etc/rp_environment' >> ~/.bashrc
    echo 'source /etc/rp_environment' >> /etc/bash.bashrc
    chmod 644 "$ENV_FILE" "$PAM_ENV_FILE"
    chmod 600 "$SSH_ENV"
}

# -----------------------------
# Jupyter Lab
# -----------------------------
start_jupyter() {
    mkdir -p /workspace
    nohup jupyter lab \
        --allow-root \
        --no-browser \
        --port=8888 \
        --ip=0.0.0.0 \
        --FileContentsManager.preferred_dir=/workspace \
        --ServerApp.root_dir=/workspace \
        --ServerApp.terminado_settings='{"shell_command":["/bin/bash"]}' \
        --IdentityProvider.token="${JUPYTER_PASSWORD:-}" \
        &> /jupyter.log &
}

# -----------------------------
# FileBrowser
# -----------------------------
start_filebrowser() {
    if [ ! -f "$FILEBROWSER_DB" ]; then
        filebrowser config init
        filebrowser config set --address 0.0.0.0
        filebrowser config set --port 8080
        filebrowser config set --root /workspace
        filebrowser config set --auth.method=json
        filebrowser users add admin adminadmin12 --perm.admin
    fi
    nohup filebrowser &> /filebrowser.log &
}

# -----------------------------
# ComfyUI Setup + Custom Nodes
# -----------------------------
setup_comfyui() {
    if [ ! -d "$COMFYUI_DIR" ] || [ ! -d "$VENV_DIR" ]; then
        echo "First time setup: Installing ComfyUI and dependencies..."

        if [ ! -d "$COMFYUI_DIR" ]; then
            cd /workspace/runpod-slim
            git clone https://github.com/comfyanonymous/ComfyUI.git
        fi

        if [ ! -d "$COMFYUI_DIR/custom_nodes/ComfyUI-Manager" ]; then
            mkdir -p "$COMFYUI_DIR/custom_nodes"
            cd "$COMFYUI_DIR/custom_nodes"
            git clone https://github.com/ltdrdata/ComfyUI-Manager.git
        fi

        CUSTOM_NODES=(
            "https://github.com/kijai/ComfyUI-KJNodes"
            "https://github.com/MoonGoblinDev/Civicomfy"
            "https://github.com/MadiatorLabs/ComfyUI-RunpodDirect"
            "https://github.com/rgthree/rgthree-comfy"
            "https://github.com/city96/ComfyUI-GGUF"
            "https://github.com/ssitu/ComfyUI_UltimateSDUpscale"
            "https://github.com/cubiq/ComfyUI_essentials"
            "https://github.com/Asidert/ComfyUI_Base64Images"
        )

        for repo in "${CUSTOM_NODES[@]}"; do
            repo_name=$(basename "$repo")
            if [ ! -d "$COMFYUI_DIR/custom_nodes/$repo_name" ]; then
                cd "$COMFYUI_DIR/custom_nodes"
                git clone "$repo"
            fi
        done

        # Create virtual environment if not exists
        if [ ! -d "$VENV_DIR" ]; then
            cd $COMFYUI_DIR
            python3.11 -m venv --system-site-packages $VENV_DIR
            source $VENV_DIR/bin/activate
        
            # Обновляем pip/setuptools/wheel безопасно
            pip install --upgrade pip setuptools wheel --no-cache-dir
        
            cd "$COMFYUI_DIR/custom_nodes"
            for node_dir in */; do
                if [ -d "$node_dir" ]; then
                    cd "$COMFYUI_DIR/custom_nodes/$node_dir"
                    [ -f requirements.txt ] && pip install --no-cache-dir -r requirements.txt
                    [ -f install.py ] && python install.py
                    [ -f setup.py ] && pip install --no-cache-dir -e .
                fi
            done
        fi
    else
        source $VENV_DIR/bin/activate
        cd "$COMFYUI_DIR/custom_nodes"
        for node_dir in */; do
            if [ -d "$node_dir" ]; then
                cd "$COMFYUI_DIR/custom_nodes/$node_dir"
                [ -f requirements.txt ] && pip install --no-cache-dir -r requirements.txt
                [ -f install.py ] && python install.py
                [ -f setup.py ] && pip install --no-cache-dir -e .
            fi
        done
    fi

    if [ ! -f "$COMFYUI_DIR/custom_nodes/.custom_deps_installed" ]; then
        cd /
        ./load_deps.sh "$COMFYUI_DIR"
    fi
}

# -----------------------------
# Start ComfyUI
# -----------------------------
start_comfyui() {
    cd "$COMFYUI_DIR"
    FIXED_ARGS="--listen 0.0.0.0 --port 8188"
    [ ! -f "$ARGS_FILE" ] && echo "# Custom ComfyUI arguments" > "$ARGS_FILE"
    CUSTOM_ARGS=$(grep -v '^#' "$ARGS_FILE" | tr '\n' ' ')
    nohup python main.py $FIXED_ARGS $CUSTOM_ARGS &> /workspace/runpod-slim/comfyui.log &
    tail -f /workspace/runpod-slim/comfyui.log
}

# -----------------------------
# Main
# -----------------------------
setup_ssh
export_env_vars
start_filebrowser
start_jupyter
setup_comfyui
start_comfyui
