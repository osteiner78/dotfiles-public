#!/usr/bin/env bash
set -euo pipefail

PIPE="${XDG_RUNTIME_DIR:-/run/user/$UID}/wobpipe"

cleanup() { rm -f "$PIPE"; }
trap cleanup EXIT INT TERM

# Fresh FIFO each session with strict perms
rm -f "$PIPE"
mkfifo -m 600 "$PIPE"

# stdbuf -> line buffering so single numbers flush immediately
# Tail keeps the pipe 'open' to avoid writers blocking when wob restarts
while true; do
  stdbuf -oL tail -n +1 -f "$PIPE" | wob -c "$HOME/.config/wob/wob.ini" || true
  # If wob exits (e.g., compositor restart), loop and reattach
  sleep 0.2
done
