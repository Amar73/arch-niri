#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILES_DIR="${ROOT_DIR}/files"

die() { printf '\n[ERROR] %s\n' "$*" >&2; exit 1; }

backup_if_exists() {
  local path="$1"
  if [[ -e "$path" && ! -L "$path" ]]; then
    local stamp
    stamp="$(date +%F-%H%M%S)"
    cp -a "$path" "${path}.bak.${stamp}"
  fi
}

echo "[*] Sync /etc/greetd"
sudo install -d -m 755 /etc/greetd
sudo rsync -a --delete "${FILES_DIR}/etc/greetd/" /etc/greetd/

# ИСПРАВЛЕНО v6.3: rsync --delete без проверки источника —
# при пустом или несуществующем src выкашивает весь ~/.config.
# Проверяем что src существует и не пуст перед деструктивной синхронизацией.
echo "[*] Sync ~/.config"
config_src="${FILES_DIR}/home/.config"
[[ -d "$config_src" ]] \
  || die "Директория конфигов не найдена: $config_src"
[[ -n "$(ls -A "$config_src" 2>/dev/null)" ]] \
  || die "Директория конфигов пуста: $config_src"

mkdir -p "${HOME}/.config"
rsync -a --delete "$config_src/" "${HOME}/.config/"

echo "[*] Sync ~/.bashrc and ~/.ssh/config"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
backup_if_exists "$HOME/.bashrc"
backup_if_exists "$HOME/.ssh/config"
install -m 644 "${FILES_DIR}/home/.bashrc" "$HOME/.bashrc"
install -m 600 "${FILES_DIR}/home/.ssh/config" "$HOME/.ssh/config"

echo "[*] Reload user units"
systemctl --user daemon-reload

echo "[*] Restart user services"
for svc in waybar swayidle cliphist-text cliphist-images; do
  if systemctl --user is-enabled "$svc.service" >/dev/null 2>&1; then
    systemctl --user restart "$svc.service" \
      && echo "[OK] restarted: $svc" \
      || echo "[WARN] failed to restart: $svc"
  fi
done

echo "[*] Check for failed units"
failed=$(systemctl --user --failed --no-legend 2>/dev/null | awk '{print $1}' | tr '\n' ' ')
if [[ -n "$failed" ]]; then
  echo "[WARN] Failed user units: $failed"
else
  echo "[OK] No failed user units"
fi

echo "[*] Validate niri config"
niri validate || true

echo "[*] Deploy outputs config"
bash "${ROOT_DIR}/deploy-outputs.sh"

echo "[*] Validate bashrc"
bash -n "$HOME/.bashrc"

echo "[*] Validate ssh config"
ssh -G github.com >/dev/null

echo "[OK] Sync done"
