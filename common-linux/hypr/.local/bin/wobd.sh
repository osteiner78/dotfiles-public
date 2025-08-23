#!/usr/bin/env bash
set -euo pipefail

PIPE="${XDG_RUNTIME_DIR:-/run/user/$UID}/wobpipe"

rm -f "$PIPE"
mkfifo -m 600 "$PIPE"

# Open FIFO read+write ourselves so writers never block on open,
# and the pipeline gets EOF immediately when we’re killed.
exec 3<>"$PIPE"

# Line-buffer the reader; let wob read from stdin.
stdbuf -oL cat <&3 | exec wob -c "$HOME/.config/wob/wob.ini"
