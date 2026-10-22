#!/usr/bin/env bash
# Install the autofs NFS map for the NAS (books share, used by Calibre).
#
# Idempotent: safe to re-run. macOS major upgrades reset /etc/auto_master to the
# stock file (macOS 27 did), which silently unmounts ~/NetworkDrives and makes
# Calibre create an empty local library there. Run `install.sh --check` after
# every macOS upgrade.
#
# Usage: install.sh [--check]
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ETC="${ETC:-/etc}"                      # overridable for tests
SUDO="${SUDO-sudo}"                     # SUDO= to run without sudo (tests)
AUTOMOUNT="${AUTOMOUNT:-automount}"     # AUTOMOUNT=: to skip (tests)
MOUNT_ROOT="${MOUNT_ROOT:-$HOME/NetworkDrives}"
MAP_NAME="auto_nfs"
MAP_SRC="$HERE/$MAP_NAME"
MASTER_LINE="$MOUNT_ROOT  $MAP_NAME  -nobrowse,nosuid"

say() { printf '  %s\n' "$*"; }
stamp() { date +%Y%m%d-%H%M%S; }

master_ok() {
    [[ -f "$ETC/auto_master" ]] &&
        awk -v r="$MOUNT_ROOT" -v m="$MAP_NAME" '$1==r && $2==m {f=1} END {exit !f}' "$ETC/auto_master"
}
map_ok() { cmp -s "$MAP_SRC" "$ETC/$MAP_NAME"; }

check() {
    local rc=0
    if master_ok; then say "ok    auto_master has the $MOUNT_ROOT line"; else say "DRIFT auto_master is missing: $MASTER_LINE"; rc=1; fi
    if map_ok; then say "ok    $ETC/$MAP_NAME matches the repo"; else say "DRIFT $ETC/$MAP_NAME differs from $MAP_SRC"; rc=1; fi
    return $rc
}

if [[ "${1:-}" == "--check" ]]; then
    check && say "nothing to do" || { say "run: $0"; exit 1; }
    exit 0
fi

changed=false

if ! map_ok; then
    [[ -f "$ETC/$MAP_NAME" ]] && $SUDO cp -p "$ETC/$MAP_NAME" "$ETC/$MAP_NAME.bak-$(stamp)"
    $SUDO cp "$MAP_SRC" "$ETC/$MAP_NAME"
    $SUDO chmod 644 "$ETC/$MAP_NAME"
    say "installed $ETC/$MAP_NAME"
    changed=true
fi

if ! master_ok; then
    $SUDO cp -p "$ETC/auto_master" "$ETC/auto_master.bak-$(stamp)"
    printf '%s\n' "$MASTER_LINE" | $SUDO tee -a "$ETC/auto_master" >/dev/null
    say "added to $ETC/auto_master: $MASTER_LINE"
    changed=true
fi

if [[ "$changed" == true ]]; then
    $SUDO $AUTOMOUNT -cv
else
    say "already up to date"
fi

# Verify (skipped in tests, where AUTOMOUNT=:)
[[ "$AUTOMOUNT" == ":" ]] && exit 0
if ! mount | grep -qF "map $MAP_NAME on"; then
    say "WARNING: $MAP_NAME is not mounted by autofs — check 'mount | grep autofs'"
    exit 1
fi
ls "$MOUNT_ROOT/books" >/dev/null && say "ok    $MOUNT_ROOT/books is reachable"
if command -v python3 >/dev/null; then
    python3 - "$MOUNT_ROOT/books/.locktest-$$" <<'PY' && say "ok    NFS locking works"
import fcntl, os, sys
p = sys.argv[1]
f = open(p, "w")
fcntl.lockf(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
f.close(); os.remove(p)
PY
fi
