#!/usr/bin/env bash
# ~/bin/toggle-waybar.sh

if pgrep -x waybar >/dev/null; then
  pkill -x waybar
else
  uwsm app -- waybar &
fi
