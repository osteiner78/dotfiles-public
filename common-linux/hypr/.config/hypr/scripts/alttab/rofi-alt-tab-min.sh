
#!/usr/bin/env bash
# Minimal Alt+Tab for rofi-wayland under Hyprland.
# Unbind -> tiny pause -> run EXACT working rofi -> restore.

set -euo pipefail

self="$(readlink -f "$0")"

unbind() {
  hyprctl -q --batch \
    "keyword unbind ALT, TAB ; keyword unbind ALT SHIFT, TAB"
}

restore() {
  # small delay to avoid grab race
  sleep 0.10
  hyprctl -q --batch \
    "keyword bind ALT, TAB, exec, $self ; keyword bind ALT SHIFT, TAB, exec, $self"
}

trap restore EXIT
unbind

# brief pause so Hypr releases the grab before rofi grabs
sleep 0.08

# EXACT same bindings as your working terminal command
rofi -no-lazy-grab -show window -modi window \
  -kb-accept-entry '!Alt_L,!Alt_R,Return' \
  -kb-row-down 'Alt+Tab' \
  -kb-row-up   'Alt+ISO_Left_Tab,Alt+Shift+Tab' \
  -kb-cancel 'Escape,Alt+Escape'
