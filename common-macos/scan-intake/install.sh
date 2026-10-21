#!/usr/bin/env bash
# Installs the scan-intake LaunchAgent. Not stowed: the plist has to be
# rendered with absolute paths and loaded with launchctl.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABEL=xyz.osteiner.scan-intake
ENV_FILE=$HOME/.config/scan-intake/.env
PLIST=$HOME/Library/LaunchAgents/$LABEL.plist
HEALTH_LABEL=$LABEL.health
HEALTH_PLIST=$HOME/Library/LaunchAgents/$HEALTH_LABEL.plist
LINK=$HOME/.local/bin/scan-intake
LOG=$HOME/Library/Logs/scan-intake.log

ask_for_token() {
    echo "Paste the token into PAPERLESS_TOKEN in $ENV_FILE (paperless web UI -> My Profile -> API Auth Token), then rerun install.sh."
    exit 1
}

if [[ ! -f $ENV_FILE ]]; then
    mkdir -p "${ENV_FILE%/*}"
    cp "$DIR/.env.example" "$ENV_FILE"
    chmod 600 "$ENV_FILE"
    echo "Created $ENV_FILE."
    ask_for_token
fi
grep -Eq '^[[:space:]]*PAPERLESS_TOKEN=.+' "$ENV_FILE" || ask_for_token

for d in outbox pending "done" duplicates failed; do
    mkdir -p "$HOME/Scans/$d"
done
mkdir -p "${LINK%/*}" "${PLIST%/*}" "${LOG%/*}"

ln -sfn "$DIR/scan-intake" "$LINK"

sed -e "s|@SCRIPT@|$DIR/scan-intake|" -e "s|@HOME@|$HOME|" -e "s|@LOG@|$LOG|" \
    "$DIR/scan-intake.plist.in" >"$PLIST"

sed -e "s|@SCRIPT@|$DIR/scan-intake|" -e "s|@LOG@|$LOG|" \
    "$DIR/scan-intake-health.plist.in" >"$HEALTH_PLIST"

launchctl bootout "gui/$(id -u)/$HEALTH_LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$HEALTH_PLIST"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

"$LINK" --selftest
