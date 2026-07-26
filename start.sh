#!/bin/bash
# Точка входа GPU-пода (копия для repo ComfyUI-Images/comfyui-base, образ
# splugeola/comfyui:latest). Собирается через scripts/build_pod.sh.
#
# Задача скрипта — поднять ComfyUI как можно быстрее, потому что за время старта
# мы уже платим за арендованную GPU. Поэтому здесь нет ни FileBrowser, ни Jupyter,
# ни sshd, ни apt-get: всё, что можно, запечено в образ.
#
# Модели скрипт НЕ качает. Раньше это делал load_deps.sh до старта ComfyUI, и
# бэкенд не видел ни прогресса, ни прогноза — только таймаут. Теперь ComfyUI
# стартует пустым, а модели тянет нода ComfyUI_DataLoader воркфлоу, который шлёт
# бэкенд; она же по WS отдаёт скорость и ETA, по которым медленный под гасится.
#
# Список кастом-нод тоже не захардкожен: он приходит с бэкенда
# (GET /worker_nodes/<role>, редактируется в админке «Лоры и модели» →
# «Кастом-ноды воркера»). Встроенный список ниже — только фоллбек, чтобы сбой
# бэкенда не оставил под без нод, без которых воркфлоу не соберётся.
set -e

COMFYUI_DIR="/workspace/runpod-slim/ComfyUI"
ARGS_FILE="/workspace/runpod-slim/comfyui_args.txt"
LOG_FILE="/workspace/runpod-slim/comfyui.log"
BASE_URL="${FLAMMA_BASE_URL:-https://flammaverse.com}"
WORKER_ROLE="${WORKER_ROLE:-image}"

FALLBACK_NODES=(
    "https://github.com/Asidert/ComfyUI_Base64Images	main"
    "https://github.com/Asidert/ComfyUI_DataLoader	main"
)

# -----------------------------
# Кастом-ноды
# -----------------------------
fetch_node_manifest() {
    local json
    if ! json="$(curl -fsSL --retry 5 --retry-max-time 60 "$BASE_URL/worker_nodes/$WORKER_ROLE")"; then
        echo "WARNING: node manifest unavailable at $BASE_URL/worker_nodes/$WORKER_ROLE, using fallback list" >&2
        printf '%s\n' "${FALLBACK_NODES[@]}"
        return 0
    fi
    if ! printf '%s' "$json" | python3 -c '
import json, sys
try:
    nodes = json.load(sys.stdin).get("nodes") or []
except Exception:
    raise SystemExit(1)
rows = [
    (repo, str(node.get("ref") or "main").strip() or "main")
    for node in nodes
    for repo in [str(node.get("repo") or "").strip()]
    if repo.startswith("https://github.com/")
]
if not rows:
    raise SystemExit(1)
for repo, ref in rows:
    print(repo, ref, sep="\t")
'; then
        echo "WARNING: node manifest is empty or malformed, using fallback list" >&2
        printf '%s\n' "${FALLBACK_NODES[@]}"
    fi
}

install_node() {
    local repo="$1" ref="$2" name dir
    name="$(basename "$repo" .git)"
    dir="$COMFYUI_DIR/custom_nodes/$name"

    # Репозитории свои и крошечные, поэтому подтягиваем их на каждом старте:
    # правка ноды доезжает до подов без пересборки образа.
    if [ -d "$dir/.git" ]; then
        echo "Updating $name ($ref)..."
        git -C "$dir" fetch --depth 1 origin "$ref"
        git -C "$dir" reset --hard FETCH_HEAD
    else
        echo "Cloning $name ($ref)..."
        rm -rf "$dir"
        git clone --depth 1 --branch "$ref" "$repo" "$dir"
    fi

    if [ -f "$dir/requirements.txt" ]; then
        python3 -m pip install --no-cache-dir -r "$dir/requirements.txt"
    fi
    if [ -f "$dir/install.py" ]; then
        (cd "$dir" && python3 install.py)
    fi
    if [ -f "$dir/setup.py" ]; then
        python3 -m pip install --no-cache-dir -e "$dir"
    fi
}

install_custom_nodes() {
    mkdir -p "$COMFYUI_DIR/custom_nodes"

    while IFS=$'\t' read -r repo ref; do
        [ -z "$repo" ] && continue
        # Сбой одной ноды не должен мешать ComfyUI подняться: бэкенд всё равно
        # забракует под на синке моделей или на warmup — и сделает это быстрее,
        # чем истечёт таймаут ожидания ответа от так и не стартовавшего ComfyUI.
        install_node "$repo" "$ref" \
            || echo "WARNING: failed to install custom node $repo ($ref)" >&2
    done < <(fetch_node_manifest)
}

# -----------------------------
# ComfyUI
# -----------------------------
start_comfyui() {
    cd "$COMFYUI_DIR"
    FIXED_ARGS="--listen 0.0.0.0 --port 8188"
    [ ! -f "$ARGS_FILE" ] && echo "# Custom ComfyUI arguments" > "$ARGS_FILE"
    CUSTOM_ARGS="$(grep -v '^#' "$ARGS_FILE" | tr '\n' ' ')"
    # Лог в файл + tail на переднем плане: держит PID 1 и отдаёт строки готовности
    # в логи Vast, по которым бэкенд понимает, что ComfyUI поднялся.
    nohup python3 main.py $FIXED_ARGS $CUSTOM_ARGS &> "$LOG_FILE" &
    tail -f "$LOG_FILE"
}

install_custom_nodes
start_comfyui
