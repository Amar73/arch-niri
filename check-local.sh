#!/usr/bin/env bash
# =============================================================================
# check-local.sh — локальная проверка без pacman/systemctl
# Безопасна в контейнере, CI, на не-Arch окружении.
# Проверяет: синтаксис bash-скриптов + наличие всех файлов репо.
#
# make check       — полная боевая проверка (требует Arch + живые сервисы)
# make check-local — только синтаксис и структура, работает везде
# =============================================================================
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILES_DIR="${ROOT_DIR}/files"

ok()   { printf '[OK]   %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*"; ERRORS=$((ERRORS+1)); }

ERRORS=0

# --------------------------------------------------------------------------
# 1. Синтаксис bash-скриптов
# --------------------------------------------------------------------------
echo "=== bash syntax ==="
for script in \
  install.sh sync.sh update.sh logs.sh backup.sh \
  bootstrap-dotfiles.sh post-install-check.sh check-local.sh; do
  f="${ROOT_DIR}/${script}"
  if [[ ! -f "$f" ]]; then
    fail "missing script: $script"
    continue
  fi
  if bash -n "$f" 2>/dev/null; then
    ok "syntax: $script"
  else
    fail "syntax error: $script"
    bash -n "$f"   # повторно чтобы вывести ошибку
  fi
done

# --------------------------------------------------------------------------
# 2. Наличие файлов в репо (files/)
# --------------------------------------------------------------------------
echo
echo "=== repo files ==="
expected_files=(
  "etc/greetd/config.toml"
  "home/.bashrc"
  "home/.ssh/config"
  "home/.config/niri/config.kdl"
  "home/.config/niri/conf.d/10-input.kdl"
  "home/.config/niri/conf.d/20-layout.kdl"
  "home/.config/niri/conf.d/30-environment.kdl"
  "home/.config/niri/conf.d/40-startup.kdl"
  "home/.config/niri/conf.d/45-wallpaper.kdl"
  "home/.config/niri/conf.d/50-binds.kdl"
  "home/.config/niri/conf.d/60-outputs.kdl"
  "home/.config/niri/conf.d/keymap.xkb"
  "home/.config/alacritty/alacritty.toml"
  "home/.config/waybar/config.jsonc"
  "home/.config/waybar/style.css"
  "home/.config/swaylock/config"
  "home/.config/mako/config"
  "home/.config/fuzzel/fuzzel.ini"
  "home/.config/qt6ct/qt6ct.conf"
  "home/.config/gtk-3.0/settings.ini"
  "home/.config/gtk-4.0/settings.ini"
  "home/.config/systemd/user/swayidle.service"
  "home/.config/systemd/user/cliphist-text.service"
  "home/.config/systemd/user/cliphist-images.service"
  "home/.config/mc/ini"
  "home/.local/bin/set-wallpapers"
)

for rel in "${expected_files[@]}"; do
  f="${FILES_DIR}/${rel}"
  if [[ -f "$f" ]]; then
    ok "file: files/$rel"
  else
    fail "missing: files/$rel"
  fi
done

# --------------------------------------------------------------------------
# 3. Makefile — наличие ключевых целей
# --------------------------------------------------------------------------
echo
echo "=== makefile targets ==="
for target in install check check-local sync update logs backup dots dots-local validate reload outputs packages ssh-config; do
  if grep -q "^${target}:" "${ROOT_DIR}/Makefile"; then
    ok "target: $target"
  else
    fail "missing target: $target"
  fi
done

# --------------------------------------------------------------------------
# 4. Проверка noctalia не просочился обратно
# --------------------------------------------------------------------------
echo
echo "=== no noctalia leftovers ==="
found=$(grep -r "noctalia" "${ROOT_DIR}" \
  --include="*.sh" --include="*.kdl" --include="*.service" \
  --include="*.jsonc" --include="*.ini" --include="Makefile" \
  --exclude="check-local.sh" \
  -l 2>/dev/null || true)
if [[ -z "$found" ]]; then
  ok "no noctalia references in scripts/configs"
else
  fail "noctalia references found in: $found"
fi

# --------------------------------------------------------------------------
# Итог
# --------------------------------------------------------------------------
echo
if [[ $ERRORS -eq 0 ]]; then
  echo "[OK] check-local passed — $ERRORS errors"
else
  echo "[FAIL] check-local failed — ${ERRORS} error(s)"
  exit 1
fi
