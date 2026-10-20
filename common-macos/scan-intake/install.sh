#!/usr/bin/env bash
# Installs the scan-intake LaunchAgent. Not stowed: the plist has to be
# rendered with absolute paths and loaded with launchctl.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABEL=xyz.osteiner.scan-intake
ENV_FILE=$HOME/.config/scan-intake/.env
PLIST=$HOME/Library/LaunchAgents/$LABEL.plist
LINK=$HOME/.local/bin/scan-intake
LOG=$HOME/Library/Logs/scan-intake.log

if [[ ! -f $ENV_FILE ]]; then
    mkdir -p "${ENV_FILE%/*}"
    cp "$DIR/.env.example" "$ENV_FILE"
    chmod 600 "$ENV_FILE"
    echo "Created $ENV_FILE."
    echo "Paste the token into PAPERLESS_TOKEN (paperless web UI -> My Profile -> API Auth Token), then rerun install.sh."
    exit 1
fi

for d in outbox pending "done" duplicates failed; do
    mkdir -p "$HOME/Scans/$d"
done
mkdir -p "${LINK%/*}" "${PLIST%/*}" "${LOG%/*}"

ln -sfn "$DIR/scan-intake" "$LINK"

sed -e "s|@SCRIPT@|$DIR/scan-intake|" -e "s|@HOME@|$HOME|" -e "s|@LOG@|$LOG|" \
    "$DIR/scan-intake.plist.in" >"$PLIST"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

"$LINK" --selftest
