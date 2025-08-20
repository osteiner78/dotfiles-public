#!/usr/bin/env bash
set -euo pipefail

: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${XDG_CACHE_HOME:=$HOME/.cache}"
CONFIG_DIR="$XDG_CONFIG_HOME"
CACHE_DIR="$XDG_CACHE_HOME"

STYLE_CSS="$CONFIG_DIR/wofi/alt-tab.css"
ICON_CACHE="$CACHE_DIR/wofi-alt-tab-icons"
mkdir -p "$ICON_CACHE"

mode="${1:-show}"

wofi_running() {
  hyprctl -j clients | jq -e '.[] | select(.class=="wofi")' >/dev/null 2>&1
}
send_to_wofi() { hyprctl -q dispatch sendshortcut , "$1", class:^\(wofi\)\$; }
escape() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

resolve_icon() {
  local hint; hint="${1-}"; [[ -z "$hint" ]] && { echo ""; return; }
  local cache_path="$ICON_CACHE/${hint}.path"
  [[ -s "$cache_path" ]] && { cat "$cache_path"; return; }
  local desktop icon found
  desktop="$(grep -ril -E "^(StartupWMClass|Name)=${hint}$" \
             "$HOME/.local/share/applications" /usr/share/applications 2>/dev/null | head -n1 || true)"
  if [[ -n "$desktop" ]]; then
    icon="$(grep -E '^Icon=' "$desktop" | tail -n1 | cut -d= -f2- || true)"; [[ -z "${icon:-}" ]] && icon="$hint"
  else
    icon="$hint"
  fi
  for base in "$HOME/.local/share/icons" "$HOME/.icons" /usr/share/icons /usr/share/pixmaps; do
    [[ -d "$base" ]] || continue
    found="$(find "$base" -type f \( -name "${icon}.svg" -o -name "${icon}.png" \) 2>/dev/null | head -n1 || true)"
    [[ -n "$found" ]] && break
  done
  printf '%s' "${found:-}" > "$cache_path"
  printf '%s' "${found:-}"
}

# 1) Collect windows (newest focus first), skip special workspaces (<0)
mapfile -t LINES < <(
  hyprctl -j clients | jq -r '
    sort_by(.focusHistoryID) | reverse |
    .[] | select(.workspace.id >= 0) |
    [
      .address,
      (.initialClass // .class // .initialTitle // .title // "app"),
      (.title // "—")
    ] | @tsv'
)

# 2) Build display lines + keep a parallel map (display -> address)
buf=""
declare -A MAP=()   # key: escaped display line, value: address
for line in "${LINES[@]}"; do
  addr="${line%%$'\t'*}"
  rest="${line#*$'\t'}"
  cls="${rest%%$'\t'*}"
  ttl="${rest#*$'\t'}"
  ttl_e="$(printf '%s' "${ttl:-—}" | escape)"
  cls_e="$(printf '%s' "${cls:-app}" | escape)"
  disp="${ttl_e}  [${cls_e}]"
  MAP["$disp"]="$addr"
  if icon_path="$(resolve_icon "${cls:-}")"; [[ -n "$icon_path" ]]; then
    buf+="${disp}\0icon\x1f${icon_path}\n"
  else
    buf+="${disp}\n"
  fi
done

# 3) If Wofi already shown, move selection; else show it
if [[ "$mode" == "--show-or-next" ]]; then
  if wofi_running; then send_to_wofi Down; exit 0; fi
elif [[ "$mode" == "--show-or-prev" ]]; then
  if wofi_running; then send_to_wofi Up; exit 0; fi
fi

choice="$(
  printf '%b' "$buf" | \
  wofi --dmenu \
       --normal-window \
       --allow-images \
       --prompt "" \
       --style "$STYLE_CSS" \
       --width 900 --height 520 --location center \
       --matching fuzzy \
       || true
)"

# 4) Map chosen display text back to address and focus it
choice="${choice%$'\n'}"   # strip trailing newline if any
addr_sel="${MAP[$choice]:-}"
if [[ -n "$addr_sel" ]]; then
  hyprctl -q --batch "dispatch focuswindow address:${addr_sel} ; dispatch alterzorder top"
fi
