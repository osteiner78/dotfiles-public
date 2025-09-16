#!/usr/bin/env bash
set -euo pipefail

start="${1:-down}"   # initial move direction for fzf: 'down' or 'up'

# Build MRU list of normal, mapped windows.
# Output format:  ADDRESS<TAB>LABEL
# LABEL = class (normal apps) OR title (Chromium-based webapps)
pick_addr() {
  hyprctl -j clients | jq -r '
    map(
      select(.workspace.id >= 0 and .mapped == true)
      # ⬇️ exclude the picker itself (class/title "alttab")
      | select(((.class // .initialClass // "") | ascii_downcase) != "alttab")
      | select(((.title // .initialTitle // "") | ascii_downcase) != "alttab")
    )
    | sort_by(.focusHistoryID) | reverse
    | .[]
    | . as $c
    | ($c.address) + "\t" +
      (
        # keep your Chromium webapp special-case
        ( ($c.class // $c.initialClass // "") | ascii_downcase ) as $cls
        | if ($cls | test("^(chrome|chromium|google-chrome|brave|vivaldi|microsoft-edge)-"))
          then ($c.title // $c.initialTitle // "unknown")
          else ($c.class // $c.initialClass // "unknown")
          end
      )
  ' | \
  fzf \
    --with-nth=2 \
    --delimiter=$'\t' \
    --layout=reverse \
    --cycle --sync --wrap \
    --bind "tab:down,shift-tab:up,start:${start},double-click:ignore" \
    --color prompt:green,pointer:green,current-bg:-1,current-fg:green,gutter:-1,border:bright-black,current-hl:red,hl:red \
    --preview "$XDG_CONFIG_HOME/hypr/scripts/alttab/preview.sh {}" \
    --preview-window=down:70% \
  | awk -F $'\t' 'NF{print $1}'
}

addr="$(pick_addr || true)"

if [[ -n "${addr:-}" ]]; then
  hyprctl --batch -q "dispatch focuswindow address:${addr} ; dispatch alterzorder top"
fi

# Always leave the submap even on cancel
hyprctl -q dispatch submap reset
