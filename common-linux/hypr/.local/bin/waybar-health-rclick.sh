#!/usr/bin/env bash
# Show a compact, readable health report for the user session.
set -euo pipefail

# --- styling helpers (no-op if not a TTY) ---
if [[ -t 1 ]]; then
  BOLD=$(tput bold); DIM=$(tput dim); RED=$(tput setaf 1); GRN=$(tput setaf 2)
  YLW=$(tput setaf 3); CYA=$(tput setaf 6); RST=$(tput sgr0)
else
  BOLD=""; DIM=""; RED=""; GRN=""; YLW=""; CYA=""; RST=""
fi
hr(){ printf '%s\n' "${DIM}────────────────────────────────────────────────────────────${RST}"; }

clear
printf "%sWaybar health — user session%s\n" "$BOLD" "$RST"
hr

# 1) Failed user units (if any)
printf "%s[ Failed user units ]%s\n" "$CYA" "$RST"
if FAILED=$(systemctl --user --failed --plain --no-legend --no-pager 2>/dev/null) && [[ -n "$FAILED" ]]; then
  echo "$FAILED"
else
  printf "%sNone%s\n" "$GRN" "$RST"
fi
hr

# 2) Recent errors this boot (priority >= err)
printf "%s[ Recent errors (this boot) ]%s\n" "$CYA" "$RST"
if ! journalctl --version &>/dev/null; then
  printf "%sjournalctl not found%s\n" "$RED" "$RST"
else
  # Show last 200 error-or-worse lines, with precise timestamps
  journalctl --user -b -p err --no-pager -o short-precise 2>/dev/null | tail -n 200 || true
fi
hr

# 3) Core dumps this boot (if coredumpctl is available)
if command -v coredumpctl >/dev/null 2>&1; then
  printf "%s[ Core dumps (this boot) ]%s\n" "$CYA" "$RST"
  if CORES=$(coredumpctl --user --since=boot --no-pager --no-legend 2>/dev/null | tail -n 10) && [[ -n "$CORES" ]]; then
    echo "$CORES"
  else
    printf "%sNone%s\n" "$GRN" "$RST"
  fi
  hr
fi

echo
read -rp "Press Enter to close"
