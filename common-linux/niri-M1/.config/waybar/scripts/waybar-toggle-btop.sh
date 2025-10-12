#!/usr/bin/env bash
# Toggle a floating "Activity" btop terminal under Niri

TITLE="Activity"

id="$(niri msg --json windows \
  | jq -r --arg t "$TITLE" '.[] | select(.title == $t) | .id' \
  | head -n1)"

if [ -n "$id" ]; then
  niri msg action close-window --id "$id" >/dev/null 2>&1 || true
else
  nohup alacritty -t "$TITLE" -e btop >/dev/null 2>&1 &
fi
