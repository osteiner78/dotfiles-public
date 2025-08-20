#!/usr/bin/env bash
set -euo pipefail

# Oneshoot units we’re allowed to auto-clear if they show up as failed
ALLOW_CLEAR=("waypaper.service")

# If any whitelisted unit is currently failed, clear its failed flag
mapfile -t FAILED < <(systemctl --user --failed --plain --no-legend --no-pager | awk '{print $1}')
for u in "${FAILED[@]}"; do
  for w in "${ALLOW_CLEAR[@]}"; do
    [[ "$u" == "$w" ]] && systemctl --user reset-failed "$u" >/dev/null 2>&1 || true
  done
done

# Show current failures after cleanup
systemctl --user --failed --no-pager
echo
read -p "Press Enter to close"
