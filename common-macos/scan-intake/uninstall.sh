#!/usr/bin/env bash
# Removes the LaunchAgent and the ~/.local/bin symlink; ~/Scans and .env stay.

set -euo pipefail

LABEL=xyz.osteiner.scan-intake

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
[[ -L $HOME/.local/bin/scan-intake ]] && rm "$HOME/.local/bin/scan-intake"
exit 0
