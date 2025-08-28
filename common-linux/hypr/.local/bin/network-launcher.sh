#!/usr/bin/env bash
set -euo pipefail

command -v fzf >/dev/null || { echo "fzf not found"; exit 127; }

# --- ordered menu + map ---
declare -a ORDER=()
declare -A MAP=()

add_item() {
  local label=$1 cmd=$2
  ORDER+=("$label")
  MAP["$label"]="$cmd"
}

# Define items IN THE ORDER YOU WANT
add_item "wifi-scanner (simple wifi selection script)" "$HOME/.local/bin/wifi-scanner.sh"
add_item "netscanner (Terminal Network scanner & diagnostic tool)" "sudo $HOME/.local/bin/netscanner"
add_item "trippy (A network diagnostic tool)" "sudo $HOME/.local/bin/trip www.osteiner.xyz"

# One-shot selection — 'q' or ESC aborts
sel=$(printf '%s\n' "${ORDER[@]}" | \
  fzf --prompt="Network Tools> " \
      --height=100% --reverse \
      --bind 'q:abort')

[[ -n "${sel:-}" ]] || exit 0

cmd=${MAP[$sel]}
clear
echo "Launching: $cmd"
echo

# Run via a shell so ~, vars, and pipes work; no eval.
bash -lc "$cmd"
