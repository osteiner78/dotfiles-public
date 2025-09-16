#!/usr/bin/env bash
set -euo pipefail

mode="${1:-toggle}"   # dark | light | toggle

current() {
  gsettings get org.gnome.desktop.interface color-scheme | tr -d "'"
}

set_mode() {
  case "$1" in
    dark)  gsettings set org.gnome.desktop.interface color-scheme prefer-dark  ;;
    light) gsettings set org.gnome.desktop.interface color-scheme prefer-light ;;
    *)     echo "unknown mode: $1" >&2; exit 1 ;;
  esac
}

if [[ "$mode" == "toggle" ]]; then
  case "$(current)" in
    prefer-dark)  mode="light" ;;
    prefer-light|default) mode="dark" ;;   # ‘default’ falls back to light in many themes
    *) mode="dark" ;;
  esac
fi

set_mode "$mode"

# Nudge portals so Flatpaks refresh the setting promptly.
# (They usually notice automatically, but this makes it immediate.)
systemctl --user try-restart xdg-desktop-portal.service || true
systemctl --user try-restart xdg-desktop-portal-hyprland.service || true
systemctl --user try-restart xdg-desktop-portal-gtk.service || true

# Optional: tell GTK/Qt apps via a desktop notification (handy feedback)
command -v notify-send >/dev/null && notify-send "Theme switched" "Mode: $mode" -a "theme-toggle" -i preferences-desktop-theme
