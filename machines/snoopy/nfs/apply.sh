#!/usr/bin/env bash
# Keep the NAS NFS mounts in snoopy's /etc/fstab in sync with fstab.nfs.
#
# Only the block between the BEGIN/END markers is managed. Every other line in
# /etc/fstab (root filesystem, swap, comments) is left exactly as it is, and the
# script refuses to write if that is not the case.
#
# First run (no markers yet): existing lines starting with 192.168.1.150:/export/
# and the "# From OpenMediaVault" comment are replaced by the managed block,
# at the position of the first such line.
#
# Usage: sudo ./apply.sh [--check]
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
FSTAB="${FSTAB:-/etc/fstab}"            # overridable for tests
SYSTEMCTL="${SYSTEMCTL:-systemctl}"     # SYSTEMCTL=: to skip (tests)
BLOCK="$HERE/fstab.nfs"
NAS_PREFIX="192.168.1.150:/export/"
OLD_COMMENT="# From OpenMediaVault (192.168.1.150)"
BEGIN="# >>> managed by ~/dotfiles/machines/snoopy/nfs (fstab.nfs) — edit there, run apply.sh >>>"
END="# <<< end managed by ~/dotfiles/machines/snoopy/nfs <<<"

die() { echo "apply.sh: $*" >&2; exit 1; }

[[ -f "$FSTAB" ]] || die "$FSTAB not found — refusing to create one (restore it first)"
[[ -f "$BLOCK" ]] || die "$BLOCK not found"

# The block may contain only NAS lines, comments and blank lines.
if grep -vE "^(#|[[:space:]]*$|${NAS_PREFIX//./\\.})" "$BLOCK" | grep -q .; then
    die "fstab.nfs contains a line that is not a ${NAS_PREFIX}* mount or a comment"
fi

tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT

nb=$(grep -cxF "$BEGIN" "$FSTAB" || true)
ne=$(grep -cxF "$END" "$FSTAB" || true)

if [[ "$nb" == 1 && "$ne" == 1 ]]; then
    awk -v b="$BEGIN" -v e="$END" -v f="$BLOCK" '
        $0==b { print; while ((getline l < f) > 0) print l; skip=1; next }
        $0==e { skip=0 }
        !skip { print }' "$FSTAB" >"$tmp"
elif [[ "$nb" == 0 && "$ne" == 0 ]]; then
    awk -v b="$BEGIN" -v e="$END" -v f="$BLOCK" -v p="$NAS_PREFIX" -v c="$OLD_COMMENT" '
        function emit() { print b; while ((getline l < f) > 0) print l; print e; done=1 }
        index($0, p)==1 || $0==c { if (!done) emit(); next }
        { print }
        END { if (!done) { print ""; emit() } }' "$FSTAB" >"$tmp"
else
    die "markers are inconsistent in $FSTAB (BEGIN x$nb, END x$ne) — fix by hand"
fi

# Safety net: everything outside the managed lines must be unchanged.
strip() { grep -vxF -e "$BEGIN" -e "$END" -e "$OLD_COMMENT" "$1" | grep -v "^${NAS_PREFIX//./\\.}" | grep -vxF -f <(grep -E '^#' "$BLOCK") | sed '/^[[:space:]]*$/d'; }
if ! diff <(strip "$FSTAB") <(strip "$tmp") >/dev/null; then
    diff -u <(strip "$FSTAB") <(strip "$tmp") || true
    die "unmanaged lines would change — aborting, $FSTAB untouched"
fi
grep -qE '^[^#].*[[:space:]]/[[:space:]]' "$tmp" || die "no root (/) entry in the result — aborting"

if cmp -s "$FSTAB" "$tmp"; then
    echo "  $FSTAB is up to date"
    exit 0
fi

if [[ "${1:-}" == "--check" ]]; then
    diff -u "$FSTAB" "$tmp" || true
    echo "  DRIFT — run: sudo $0"
    exit 1
fi

[[ "$FSTAB" != /etc/fstab || $EUID -eq 0 ]] || die "run with sudo"

if command -v findmnt >/dev/null && [[ "$FSTAB" == /etc/fstab ]]; then
    findmnt --verify --tab-file "$tmp" >/dev/null || die "findmnt --verify failed on the new fstab — aborting"
fi

backup="$FSTAB.bak-$(date +%Y%m%d-%H%M%S)"
cp -p "$FSTAB" "$backup"
diff -u "$FSTAB" "$tmp" || true
cat "$tmp" >"$FSTAB"            # keeps owner/mode of the existing file
echo "  updated $FSTAB (backup: $backup)"

$SYSTEMCTL daemon-reload
cat <<MSG
  To remount a changed share, stop what uses it, then e.g.:
    sudo umount /mnt/nfs/<name> && sudo systemctl restart mnt-nfs-<name>.automount
MSG
