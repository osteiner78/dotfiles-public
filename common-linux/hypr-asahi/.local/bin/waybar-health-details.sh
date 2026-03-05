#!/usr/bin/env bash
set -euo pipefail
UNITS=(waybar hypridle swayosd libinput-gestures hyprpolkitagent)

echo "Status:"
/usr/bin/systemctl --user --no-pager is-active "${UNITS[@]}" | nl -ba

echo; echo "Recent errors (last 50 lines each):"
for u in "${UNITS[@]}"; do
  echo "---- $u ----"
  /usr/bin/journalctl --user -u "$u" -p err -n 50 --no-pager || true
done

echo; read -p "Press Enter to close"
