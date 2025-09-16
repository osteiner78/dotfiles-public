
#!/usr/bin/env bash
# Alt+Tab with rofi-wayland on Hyprland
# Unbind Alt+Tab -> run rofi (Alt-release accepts) -> restore binds

set -euo pipefail

: "${XDG_CONFIG_HOME:=$HOME/.config}"
THEME="$XDG_CONFIG_HOME/rofi/alt-tab-gruvbox.rasi"   # your text-only theme

action="${1:-open-next}"           # open-next | open-prev
self="$(readlink -f "$0")"

unbind() {
  hyprctl -q --batch \
    "keyword unbind ALT, TAB ; keyword unbind ALT SHIFT, TAB"
}

restore() {
  # tiny delay to avoid race with Hypr grabbing keys instantly
  sleep 0.10
  hyprctl -q --batch \
    "keyword bind ALT, TAB, exec, $self open-next ; keyword bind ALT SHIFT, TAB, exec, $self open-prev"
}

trap restore EXIT
unbind

# If user started with Alt+Shift+Tab, preselect from end
selrow=""
[[ "$action" == "open-prev" ]] && selrow="-selected-row 999999"

# EXACTLY the working CLI you tested (plus theme + optional format)
rofi -show window -modi window \
  -theme "$THEME" \
  -window-format "{n}\n{t}" \
  -kb-accept-entry '!Alt_L,!Alt_R,Return' \
  -kb-row-down 'Alt+Tab' \
  -kb-row-up   'Alt+ISO_Left_Tab,Alt+Shift+Tab' \
  -kb-cancel 'Escape,Alt+Escape' \
  $selrow
