
#!/usr/bin/env bash
# <xbar.title>Btop in Alacritty (Toggle, minimal)</xbar.title>
# <xbar.version>2.0</xbar.version>
# <xbar.author>Oliver</xbar.author>
# <xbar.desc>Toggle a centered Alacritty+btop popup (grid-first, simple).</xbar.desc>
# <xbar.dependencies>bash,yabai,jq,Alacritty,btop</xbar.dependencies>

set -euo pipefail

# --- settings ---
TITLE="btop-floating"   # window title to match
COLS=150                # ≈1200 px wide with typical font metrics
LINES=46                # ≈800 px high (adjust to taste)
CHAR_W=4                # px-per-column approximation
LINE_H=12               # px-per-row approximation
# -----------------

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

btop_ids() {
  yabai -m query --windows \
  | jq -r --arg T "$TITLE" \
    '[.[] | select((.app|ascii_downcase)=="alacritty" and .title==$T)] | sort_by(-.id) | .[].id'
}

launch_btop_centered() {
  # center on the currently focused display using our grid->pixel estimate
  read -r fx fy fw fh <<<"$(yabai -m query --displays --display \
    | jq -r '.frame | "\((.x|floor)) \((.y|floor)) \((.w|floor)) \((.h|floor))"')"

  ww=$(( COLS * CHAR_W ))
  wh=$(( LINES * LINE_H ))
  x=$(( fx + (fw - ww)/2 ))
  y=$(( fy + (fh - wh)/2 ))

  alacritty --title "$TITLE" \
    -o window.dimensions.columns="$COLS" \
    -o window.dimensions.lines="$LINES" \
    -o window.position.x="$x" \
    -o window.position.y="$y" \
    --command btop >/dev/null 2>&1 &
}

toggle() {
  ids="$(btop_ids || true)"
  if [ -z "$ids" ]; then
    launch_btop_centered
    return
  fi

  first_id="$(printf '%s\n' "$ids" | head -n1)"
  front_id="$(yabai -m query --windows --window | jq -r '.id')"

  if [ "$front_id" != "null" ] && printf '%s\n' "$ids" | grep -qx "$front_id"; then
    yabai -m window "$front_id" --close >/dev/null 2>&1 || true
  else
    yabai -m window "$first_id" --focus >/dev/null 2>&1 || true
  fi
}

case "${1:-}" in
  toggle) toggle; exit 0 ;;
esac

# Menubar
echo "| sfimage=cpu tooltip='Btop toggle' bash=\"$0\" param1=toggle terminal=false refresh=false"
echo "---"
echo "Toggle btop | bash=\"$0\" param1=toggle terminal=false refresh=false"
