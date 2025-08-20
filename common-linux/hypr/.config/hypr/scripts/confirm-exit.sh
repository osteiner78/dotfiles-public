#!/usr/bin/env bash
set -euo pipefail

# Menu entries (first is preselected)
MENU=$'Cancel\nLogout\nReboot\nShutdown'

choice=$(printf "%s\n" "$MENU" | wofi --dmenu \
  --prompt "Power menu" --location=center \
  --width=360 --height=250 --hide-scroll --cache-file=/dev/null)

case "$choice" in
  Logout)   hyprctl dispatch exit ;;
  Reboot)   systemctl reboot ;;
  Shutdown) systemctl poweroff ;;
  *)        exit 0 ;;
esac
