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
#
# Образ один на обе роли: WORKER_ROLE переключает и манифест нод, и фоллбек.
# Ничего роле-специфичного в Dockerfile нет, вся развилка здесь.
set -e

COMFYUI_DIR="/workspace/runpod-slim/ComfyUI"
ARGS_FILE="/workspace/runpod-slim/comfyui_args.txt"
LOG_FILE="/workspace/runpod-slim/comfyui.log"
BASE_URL="${FLAMMA_BASE_URL:-https://flammaverse.com}"
WORKER_ROLE="${WORKER_ROLE:-image}"

# Фоллбек-наборы нод по ролям. Набор должен быть самодостаточным: воркфлоу своей
# роли обязан собраться на одном фоллбеке, без бэкенда. Для video это в первую
# очередь LTXSequencer — без него нет ни закольцовки, ни привязки кадров.
#
# Свои ноды держим на main осознанно: install_node подтягивает их на каждом
# старте, поэтому правка доезжает до подов без пересборки образа. Чужие пиним
# коммитом — иначе сломанное обновление приедет на под само.
FALLBACK_NODES_image=(
    "https://github.com/Asidert/ComfyUI_Base64Images	main"
    "https://github.com/Asidert/ComfyUI_DataLoader	main"
)
FALLBACK_NODES_video=(
    "https://github.com/Asidert/ComfyUI_Base64Images	main"
    "https://github.com/Asidert/ComfyUI_DataLoader	main"
    "https://github.com/WhatDreamsCost/WhatDreamsCost-ComfyUI	fbf22afdfce99587c80c4e8625f545deaa6c66a0"
    "https://github.com/kijai/ComfyUI-KJNodes	827fe6ee0ed7348d8daa988ed852bedf1272380c"
)

# Опечатка в роли не должна поднимать под молча: на дефолтном наборе видео-под
# зарегистрируется как рабочий и начнёт брать задачи, которые не умеет считать.
case "$WORKER_ROLE" in
    image|video) ;;
    *)
        echo "FATAL: unknown WORKER_ROLE '$WORKER_ROLE' (expected image|video)" >&2
        exit 1
        ;;
esac

# Без nameref (`local -n`): он требует bash >= 4.3, а скрипт хочется гонять и на
# машине разработчика, где /bin/bash может быть 3.2.
fallback_nodes() {
    case "$WORKER_ROLE" in
        video) printf '%s\n' "${FALLBACK_NODES_video[@]}" ;;
        *)     printf '%s\n' "${FALLBACK_NODES_image[@]}" ;;
    esac
}

# -----------------------------
# Кастом-ноды
# -----------------------------
fetch_node_manifest() {
    local json
    if ! json="$(curl -fsSL --retry 5 --retry-max-time 60 "$BASE_URL/worker_nodes/$WORKER_ROLE")"; then
        echo "WARNING: node manifest unavailable at $BASE_URL/worker_nodes/$WORKER_ROLE, using fallback list" >&2
        fallback_nodes
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
        fallback_nodes
    fi
}

install_node() {
    local repo="$1" ref="$2" name dir
    name="$(basename "$repo" .git)"
    dir="$COMFYUI_DIR/custom_nodes/$name"

    # Подтягиваем на каждом старте: правка своей ноды доезжает до подов без
    # пересборки образа, а чужая остаётся на том коммите, который указан в ref.
    #
    # Единый путь init+fetch вместо развилки clone/fetch: `clone --branch` берёт
    # только ветку или тег, а чужие ноды мы пиним коммитом (у KJNodes тегов нет
    # вообще). GitHub отдаёт произвольный коммит по fetch, так что --depth 1
    # сохраняется.
    if [ ! -d "$dir/.git" ]; then
        echo "Initializing $name..."
        rm -rf "$dir"
        git init -q "$dir"
        git -C "$dir" remote add origin "$repo"
    fi
    echo "Fetching $name ($ref)..."
    git -C "$dir" fetch --depth 1 origin "$ref"
    git -C "$dir" reset --hard FETCH_HEAD

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
    # COMFYUI_EXTRA_ARGS — аварийный рычаг: аргументы можно докинуть через env
    # инстанса (VAST_WORKER_ENV), не пересобирая образ.
    echo "Starting ComfyUI: $FIXED_ARGS $CUSTOM_ARGS ${COMFYUI_EXTRA_ARGS:-}"
    # Падение в нативном коде (segfault) не даёт питоновского трейсбека, а весь
    # стек ComfyUI держится на скомпилированных пакетах — torch, comfy-kitchen,
    # av. faulthandler печатает кадр, на котором процесс умер: без него в логе
    # остаётся только "signal 11", по которому искать нечего.
    export PYTHONFAULTHANDLER=1

    # Лог в файл + tail: строки готовности уезжают в логи Vast, по ним бэкенд
    # понимает, что ComfyUI поднялся.
    python3 main.py $FIXED_ARGS $CUSTOM_ARGS ${COMFYUI_EXTRA_ARGS:-} &> "$LOG_FILE" &
    comfy_pid=$!
    tail -f "$LOG_FILE" &
    tail_pid=$!

    # Без этого умерший ComfyUI неотличим от медленного: tail -f молчал бы вечно,
    # контейнер продолжал жить, а бэкенд ждал бы весь comfy_timeout. Дожидаемся
    # процесса и выходим с его кодом — падение сразу видно в логах инстанса.
    # `|| status=$?` обязателен: под `set -e` голый wait с ненулевым кодом убьёт
    # скрипт прямо здесь, и диагностика ниже не напечатается.
    status=0
    wait "$comfy_pid" || status=$?
    sleep 2
    kill "$tail_pid" 2>/dev/null || true
    if [ "$status" -gt 128 ]; then
        # 137 = SIGKILL: почти всегда OOM-killer, трейсбека в логе не будет.
        echo "ComfyUI killed by signal $((status - 128)) (status $status)" >&2
    else
        echo "ComfyUI exited with status $status" >&2
    fi
    exit "$status"
}

install_custom_nodes
start_comfyui
