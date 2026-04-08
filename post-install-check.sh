#!/usr/bin/env bash
set -Eeuo pipefail

ok()   { printf '[OK]   %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*"; }

check_cmd() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "command: $cmd"
  else
    fail "command missing: $cmd"
  fi
}

echo "=== commands ==="
for cmd in niri niri-session alacritty fuzzel mako waybar swayidle swaylock \
           wl-paste cliphist tuigreet nwg-look qt6ct ssh keychain yay btop jq pulsemixer; do
  check_cmd "$cmd"
done

echo
echo "=== package checks ==="
for pkg in \
  niri greetd greetd-tuigreet alacritty fuzzel mako waybar swayidle swaylock btop jq \
  wl-clipboard cliphist xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
  pipewire wireplumber pipewire-pulse pulsemixer \
  qt6ct kvantum nwg-look noto-fonts papirus-icon-theme \
  keychain openssh; do
  if pacman -Q "$pkg" >/dev/null 2>&1; then
    ok "package: $pkg"
  else
    fail "package missing: $pkg"
  fi
done

echo
echo "=== optional packages ==="
# qt5-wayland — может быть включён в qt5-base на новых версиях
pacman -Q qt5-wayland >/dev/null 2>&1 \
  && ok "package: qt5-wayland" \
  || warn "qt5-wayland не найден отдельно — возможно в qt5-base, это нормально"

echo
echo "=== AUR packages ==="
pacman -Q bibata-cursor-theme >/dev/null 2>&1 \
  && ok "package: bibata-cursor-theme (AUR)" \
  || warn "bibata-cursor-theme не найден — установи: yay -S bibata-cursor-theme"

echo
echo "=== config files ==="
for f in \
  /etc/greetd/config.toml \
  "$HOME/.bashrc" \
  "$HOME/.ssh/config" \
  "$HOME/.config/niri/config.kdl" \
  "$HOME/.config/niri/conf.d/keymap.xkb" \
  "$HOME/.config/alacritty/alacritty.toml" \
  "$HOME/.config/waybar/config.jsonc" \
  "$HOME/.config/waybar/style.css" \
  "$HOME/.config/swaylock/config" \
  "$HOME/.config/systemd/user/swayidle.service" \
  "$HOME/.config/systemd/user/cliphist-text.service" \
  "$HOME/.config/systemd/user/cliphist-images.service" \
  "$HOME/.config/mako/config" \
  "$HOME/.config/fuzzel/fuzzel.ini" \
  "$HOME/.config/qt6ct/qt6ct.conf" \
  "$HOME/.config/gtk-3.0/settings.ini" \
  "$HOME/.config/gtk-4.0/settings.ini"; do
  [[ -f "$f" ]] && ok "file: $f" || fail "missing file: $f"
done

echo
echo "=== syntax checks ==="
bash -n "$HOME/.bashrc" >/dev/null 2>&1 \
  && ok "bashrc syntax valid" || fail "bashrc syntax invalid"

ssh -G github.com >/dev/null 2>&1 \
  && ok "ssh config parses" || fail "ssh config parse failed"

echo
echo "=== system services ==="
systemctl is-enabled NetworkManager.service >/dev/null 2>&1 && ok "NetworkManager enabled" || warn "NetworkManager not enabled"
systemctl is-enabled seatd.service          >/dev/null 2>&1 && ok "seatd enabled"          || warn "seatd not enabled"
systemctl is-enabled greetd.service         >/dev/null 2>&1 && ok "greetd enabled"         || warn "greetd not enabled"

echo
echo "=== user services ==="
systemctl --user is-enabled swayidle.service        >/dev/null 2>&1 && ok "swayidle.service enabled"        || warn "swayidle.service not enabled"
systemctl --user is-enabled cliphist-text.service   >/dev/null 2>&1 && ok "cliphist-text.service enabled"   || warn "cliphist-text.service not enabled"
systemctl --user is-enabled cliphist-images.service >/dev/null 2>&1 && ok "cliphist-images.service enabled" || warn "cliphist-images.service not enabled"

echo
echo "=== niri-start wrapper ==="
if [[ -x /usr/local/bin/niri-start ]]; then
  ok "/usr/local/bin/niri-start exists and executable"
else
  fail "/usr/local/bin/niri-start missing — запусти: make sync"
fi
niri validate >/dev/null 2>&1 \
  && ok "niri config valid" || fail "niri config invalid"

echo
echo "=== niri keyboard layouts ==="
if niri msg --json keyboard-layouts >/dev/null 2>&1; then
  _kl_json="$(niri msg --json keyboard-layouts 2>/dev/null)"
  _kl_out="$(echo "$_kl_json" | jq -r '
    if .names != null then
      "Layouts: " + (.names | join(", ")) +
      "\nActive:  " + (.names[.current_idx] // "?")
    elif .keyboard_layouts != null and .keyboard_layouts.layouts != null then
      "Layouts: " + ([.keyboard_layouts.layouts[].name] | join(", ")) +
      "\nActive:  " + (.keyboard_layouts.layouts[.keyboard_layouts.current_idx].name // "?")
    else
      "WARN: неожиданная структура JSON: " + (. | tostring)
    end
  ' 2>/dev/null || echo "WARN: jq не смог распарсить ответ niri")"
  echo "$_kl_out"
  ok "keyboard-layouts IPC работает"
else
  warn "niri msg --json keyboard-layouts недоступен — запущен ли niri?"
fi
