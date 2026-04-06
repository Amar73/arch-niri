#!/usr/bin/env bash
set -Eeuo pipefail

log() { printf '\n[%s] %s\n' "$(date +'%F %T')" "$*"; }
die() { printf '\n[ERROR] %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] && die "Запускай от обычного пользователя, не от root."

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILES_DIR="${ROOT_DIR}/files"

need() {
  command -v "$1" >/dev/null 2>&1 || die "Не найдено: $1. На чистом Arch: sudo pacman -S $1"
}

install_yay() {
  if command -v yay >/dev/null 2>&1; then
    log "yay уже установлен"
    return 0
  fi
  local tmpdir
  tmpdir="$(mktemp -d)"
  log "Установка yay"
  git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
  (cd "$tmpdir/yay" && makepkg -si --noconfirm)
  rm -rf "$tmpdir"
}

install_official_packages() {
  log "Обновление системы"
  sudo pacman -Syu --noconfirm

  log "Установка официальных пакетов"
  sudo pacman -S --needed --noconfirm \
    base-devel git rsync curl wget unzip \
    niri \
    waybar \
    btop jq \
    greetd greetd-tuigreet \
    networkmanager seatd \
    pipewire wireplumber pipewire-pulse \
    xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
    alacritty fuzzel mako \
    swaybg swayidle swaylock \
    wl-clipboard cliphist \
    polkit-gnome \
    brightnessctl playerctl \
    pulsemixer \
    grim slurp \
    mesa vulkan-icd-loader \
    qt6-wayland qt6-svg qt6-multimedia \
    qt6ct kvantum nwg-look \
    noto-fonts noto-fonts-cjk noto-fonts-emoji \
    ttf-jetbrains-mono-nerd \
    adw-gtk-theme papirus-icon-theme \
    xwayland-satellite \
    keychain openssh
}

enable_system_services() {
  log "Включение system services"
  sudo systemctl enable NetworkManager.service
  sudo systemctl enable seatd.service
  sudo systemctl enable greetd.service
}

setup_locale() {
  log "Настройка локали"
  # Генерируем обе локали если ещё не сгенерированы
  if ! locale -a 2>/dev/null | grep -q "ru_RU.utf8"; then
    sudo sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
    sudo sed -i 's/^#ru_RU.UTF-8/ru_RU.UTF-8/' /etc/locale.gen
    sudo locale-gen
  fi
  # Выставляем русский LANG чтобы приложения (браузеры и др.) были на русском
  # LC_COLLATE=C — быстрая сортировка в терминале без регистрозависимых проблем
  if [[ ! -f /etc/locale.conf ]] || ! grep -q "LANG=" /etc/locale.conf; then
    sudo tee /etc/locale.conf > /dev/null << 'EOF'
LANG=ru_RU.UTF-8
LC_COLLATE=C
EOF
    echo "[OK] /etc/locale.conf создан (LANG=ru_RU.UTF-8)"
  else
    echo "[OK] /etc/locale.conf уже существует: $(cat /etc/locale.conf | head -1)"
  fi
}

add_groups() {
  log "Добавление пользователя в группы"
  sudo usermod -aG video,input,seat "$USER" || true
}

install_aur_packages() {
  log "Установка AUR-пакетов (yay)"
  yay -S --needed --noconfirm bibata-cursor-theme
  # qt5-wayland — в extra как отдельный пакет, на новых ядрах может быть в qt5-base
  yay -S --needed --noconfirm qt5-wayland 2>/dev/null \
    || log "WARN: qt5-wayland не найден — возможно включён в qt5-base, пропускаем"
}

install_niri_start() {
  log "Установка niri-start wrapper"
  sudo tee /usr/local/bin/niri-start > /dev/null << 'EOF'
#!/bin/bash
exec dbus-run-session niri
EOF
  sudo chmod +x /usr/local/bin/niri-start
  echo "[OK] /usr/local/bin/niri-start создан"
}

backup_if_exists() {
  local path="$1"
  if [[ -e "$path" && ! -L "$path" ]]; then
    local stamp; stamp="$(date +%F-%H%M%S)"
    cp -a "$path" "${path}.bak.${stamp}"
  fi
}

deploy_dotfiles() {
  log "Копирование .bashrc и .ssh/config"
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  backup_if_exists "$HOME/.bashrc"
  backup_if_exists "$HOME/.ssh/config"
  install -m 644 "${FILES_DIR}/home/.bashrc"    "$HOME/.bashrc"
  install -m 600 "${FILES_DIR}/home/.ssh/config" "$HOME/.ssh/config"
}

deploy_files() {
  log "Копирование конфигов"

  sudo install -d -m 755 /etc/greetd
  sudo rsync -a "${FILES_DIR}/etc/greetd/" /etc/greetd/

  mkdir -p "${HOME}/.config"

  local config_src="${FILES_DIR}/home/.config"
  [[ -d "$config_src" ]] \
    || die "Директория конфигов не найдена: $config_src"
  [[ -n "$(ls -A "$config_src" 2>/dev/null)" ]] \
    || die "Директория конфигов пуста: $config_src"

  rsync -a --delete "$config_src/" "${HOME}/.config/"

  mkdir -p "${HOME}/Screenshots"
  deploy_dotfiles

  # Деплой конфига мониторов по hostname
  log "Деплой конфига мониторов"
  bash "${ROOT_DIR}/deploy-outputs.sh"
}

enable_user_services() {
  log "Включение user services"
  systemctl --user daemon-reload
  systemctl --user enable swayidle.service
  systemctl --user enable cliphist-text.service
  systemctl --user enable cliphist-images.service
  # waybar запускается через niri spawn-at-startup, не через systemd unit
}

print_summary() {
  cat <<'EOF'

========================================
Готово
========================================

Дальше:
  sudo reboot

Если после reboot greeter не пускает — очисти кеш tuigreet:
  sudo rm -f /var/cache/tuigreet/*

После входа:
  make check
  make logs
  bash -n ~/.bashrc
  ssh -G github.com >/dev/null

Диагностика раскладок waybar:
  niri msg --json keyboard-layouts | jq .
  niri msg event-stream | grep -i keyboard

EOF
}

main() {
  need sudo
  need pacman
  # git и rsync могут отсутствовать на минимальном Arch — ставим их первыми
  if ! command -v git >/dev/null 2>&1 || ! command -v rsync >/dev/null 2>&1; then
    log "Предустановка git и rsync"
    sudo pacman -S --needed --noconfirm git rsync
  fi

  install_official_packages
  enable_system_services
  setup_locale
  add_groups
  install_yay
  install_aur_packages
  install_niri_start
  deploy_files
  enable_user_services
  print_summary
}

main "$@"
