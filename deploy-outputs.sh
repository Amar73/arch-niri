#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# deploy-outputs.sh — деплой конфига мониторов по hostname
#
# Копирует нужный файл из outputs/ в conf.d/60-outputs.kdl
# Запускается автоматически из install.sh и sync.sh,
# или вручную: ./deploy-outputs.sh
#
# Файлы в outputs/:
#   amar224.kdl   — 3x 1920x1080 (DP-2, DP-3, DP-4)
#   amar319.kdl   — 2x 1920x1080 (DVI-I-1, HDMI-A-1)
#   amar319-1.kdl — 1x 2560x1600 (DVI-I-2, Apple Cinema HD)
#   default.kdl   — ноутбуки и неизвестные хосты (auto)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUTS_DIR="${ROOT_DIR}/files/home/.config/niri/outputs"
TARGET_DIR="${HOME}/.config/niri/conf.d"
TARGET="${TARGET_DIR}/60-outputs.kdl"

HOST="$(hostname -s)"

# Ищем файл по hostname, фоллбэк на default
if [[ -f "${OUTPUTS_DIR}/${HOST}.kdl" ]]; then
    SRC="${OUTPUTS_DIR}/${HOST}.kdl"
    echo "[*] Outputs config: ${HOST}.kdl"
elif [[ -f "${OUTPUTS_DIR}/${HOST}.cnf" ]]; then
    # Поддержка старого расширения .cnf
    SRC="${OUTPUTS_DIR}/${HOST}.cnf"
    echo "[*] Outputs config: ${HOST}.cnf"
else
    SRC="${OUTPUTS_DIR}/default.kdl"
    echo "[*] Outputs config: default.kdl (hostname '$HOST' не найден)"
fi

mkdir -p "${TARGET_DIR}"
cp -f "$SRC" "$TARGET"

echo "[OK] Deployed: $SRC → $TARGET"

# Валидация если niri доступен
if command -v niri >/dev/null 2>&1 && [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    niri msg action reload-config 2>/dev/null \
        && echo "[OK] niri config reloaded" \
        || echo "[WARN] niri reload failed — перезайди в сессию"
else
    echo "[INFO] niri не запущен — конфиг применится при следующем входе"
fi
