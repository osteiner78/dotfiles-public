#!/usr/bin/env bash
# Removes the LaunchAgents and the ~/.local/bin symlink; ~/Scans and .env stay.

set -euo pipefail

LABEL=xyz.osteiner.scan-intake

for label in "$LABEL.health" "$LABEL"; do
    launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
    rm -f "$HOME/Library/LaunchAgents/$label.plist"
done
[[ -L $HOME/.local/bin/scan-intake ]] && rm "$HOME/.local/bin/scan-intake"
exit 0
