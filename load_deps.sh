#!/bin/bash
# Синхронизация моделей воркера с сервером Flamma (копия для repo comfyui-base).
#
# Заменяет захардкоженные curl'ы в init-скрипте: список файлов управляется из
# админки («Контент → Лоры», колонка «Воркерам») и отдаётся эндпоинтом
# GET /worker_models/<role> -> {"files": [{"path", "target", "size_bytes", "url"}]}.
# role — тип воркера (для генерации изображений: image). target — путь
# назначения относительно корня ComfyUI (models/... как есть, chars/ и прочие
# лоры -> models/loras/...).
#
# Скрипт идемпотентен: файлы с совпадающим размером пропускает, качает во
# временный .part с ретраями и докачкой, после проверки размера атомарно
# переименовывает. Запускать на каждом старте пода — новые галочки в админке
# подтянутся без пересборки образа.

set -euo pipefail

COMFYUI_DIR="${1:?usage: $0 /path/to/ComfyUI [role]}"
WORKER_ROLE="${2:-image}"
BASE_URL="${FLAMMA_BASE_URL:-https://flammaverse.com}"

echo "Fetching model list from $BASE_URL/worker_models/$WORKER_ROLE…"
SYNC_JSON="$(curl -fsSL --retry 5 --retry-max-time 120 "$BASE_URL/worker_models/$WORKER_ROLE")"

file_size() {
    stat -c%s "$1" 2>/dev/null || stat -f%z "$1"
}

COUNT=0
SKIPPED=0
while IFS=$'\t' read -r url target size; do
    [ -z "$target" ] && continue
    dest="$COMFYUI_DIR/$target"
    mkdir -p "$(dirname "$dest")"

    if [ -f "$dest" ] && [ "$(file_size "$dest")" = "$size" ]; then
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    echo "Downloading: $target ($size bytes)"
    # Старый .part может быть от другой версии файла — начинаем закачку заново;
    # -C - докачивает только внутри ретраев этого же вызова curl.
    rm -f "$dest.part"
    curl --fail --retry 5 --retry-max-time 0 -C - -L \
        -o "$dest.part" \
        "$BASE_URL$url"

    actual="$(file_size "$dest.part")"
    if [ "$actual" != "$size" ]; then
        echo "Error: size mismatch for $target (expected $size, got $actual)" >&2
        exit 1
    fi
    mv -f "$dest.part" "$dest"
    COUNT=$((COUNT + 1))
done < <(printf '%s' "$SYNC_JSON" | python3 -c '
import json, sys
data = json.load(sys.stdin)
for item in data.get("files", []):
    print(item["url"], item["target"], item["size_bytes"], sep="\t")
')

echo "Models sync done: downloaded $COUNT, up-to-date $SKIPPED"
