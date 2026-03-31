#!/usr/bin/env bash
set -Eeuo pipefail

log() { printf '\n[%s] %s\n' "$(date +'%F %T')" "$*"; }
die() { printf '\n[ERROR] %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] && die "Запускай от обычного пользователя, не от root."

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILES_DIR="${ROOT_DIR}/files"

need() {
  command -v "$1" >/dev/null 2>&1 || die "Не найдено: $1"
}

# ИСПРАВЛЕНО v6.3: paru → yay
# ИСПРАВЛЕНО v6.3: убран trap EXIT (глобальный — перезаписывал любой последующий)
#   Заменён на явную очистку tmpdir после makepkg
install_yay() {
  if command -v yay >/dev/null 2>&1; then
    log "yay уже установлен"
    return 0
  fi

  local tmpdir
  tmpdir="$(mktemp -d)"
  log "Установка yay"
  git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
  (
    cd "$tmpdir/yay"
    makepkg -si --noconfirm
  )
  # Явная очистка вместо trap EXIT — безопасна для вложенных вызовов
  rm -rf "$tmpdir"
}

remove_conflicts() {
  if pacman -Q quickshell >/dev/null 2>&1; then
    log "Удаляю quickshell"
    sudo pacman -Rns --noconfirm quickshell
  fi

  if pacman -Q quickshell-git >/dev/null 2>&1; then
    log "Удаляю quickshell-git"
    yay -Rns --noconfirm quickshell-git || true
  fi
}

install_official_packages() {
  log "Обновление системы"
  sudo pacman -Syu --noconfirm

  log "Установка официальных пакетов"
  sudo pacman -S --needed --noconfirm \
    base-devel git rsync curl wget unzip \
    niri \
    waybar \
    btop \
    greetd greetd-tuigreet \
    networkmanager seatd \
    pipewire wireplumber \
    xdg-desktop-portal xdg-desktop-portal-wlr \
    alacritty fuzzel mako \
    swaybg swayidle swaylock \
    wl-clipboard cliphist \
    polkit-gnome \
    brightnessctl playerctl \
    grim slurp \
    mesa vulkan-icd-loader \
    qt6-wayland qt6-svg qt6-multimedia qt5-compat \
    qt6ct kvantum nwg-look \
    noto-fonts noto-fonts-cjk noto-fonts-emoji \
    ttf-jetbrains-mono-nerd \
    adw-gtk-theme papirus-icon-theme bibata-cursor-theme \
    xwayland-satellite \
    keychain openssh
}

enable_system_services() {
  log "Включение system services"
  sudo systemctl enable NetworkManager.service
  sudo systemctl enable seatd.service
  sudo systemctl enable greetd.service
}

add_groups() {
  log "Добавление пользователя в группы"
  sudo usermod -aG video,input,seat "$USER" || true
}

install_noctalia() {
  log "Установка Noctalia"
  yay -S --needed --noconfirm noctalia-shell
}

backup_if_exists() {
  local path="$1"
  if [[ -e "$path" && ! -L "$path" ]]; then
    local stamp
    stamp="$(date +%F-%H%M%S)"
    cp -a "$path" "${path}.bak.${stamp}"
  fi
}

deploy_dotfiles() {
  log "Копирование пользовательских bashrc и ssh config"
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  backup_if_exists "$HOME/.bashrc"
  backup_if_exists "$HOME/.ssh/config"
  install -m 644 "${FILES_DIR}/home/.bashrc" "$HOME/.bashrc"
  install -m 600 "${FILES_DIR}/home/.ssh/config" "$HOME/.ssh/config"
}

deploy_files() {
  log "Копирование конфигов"

  sudo install -d -m 755 /etc/greetd
  sudo rsync -a "${FILES_DIR}/etc/greetd/" /etc/greetd/

  mkdir -p "${HOME}/.config"

  # ИСПРАВЛЕНО v6.3: добавлена защита перед rsync --delete.
  # Пустой или несуществующий src при --delete выкосит весь ~/.config
  local config_src="${FILES_DIR}/home/.config"
  [[ -d "$config_src" ]] \
    || die "Директория конфигов не найдена: $config_src"
  [[ -n "$(ls -A "$config_src" 2>/dev/null)" ]] \
    || die "Директория конфигов пуста: $config_src"

  rsync -a --delete "$config_src/" "${HOME}/.config/"

  mkdir -p "${HOME}/Pictures"
  deploy_dotfiles
}

enable_user_services() {
  log "Включение user services"
  systemctl --user daemon-reload
  systemctl --user enable noctalia.service
  systemctl --user enable swayidle.service
  systemctl --user enable cliphist-text.service
  systemctl --user enable cliphist-images.service
}

print_summary() {
  cat <<'EOF'

========================================
Готово
========================================

Дальше:
  sudo reboot

После входа:
  make check
  make logs
  bash -n ~/.bashrc
  ssh -G github.com >/dev/null

EOF
}

main() {
  need sudo
  need pacman
  need git
  need rsync

  install_official_packages
  enable_system_services
  add_groups
  install_yay
  remove_conflicts
  install_noctalia
  deploy_files
  enable_user_services
  print_summary
}

main "$@"
