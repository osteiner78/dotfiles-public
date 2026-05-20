#!/bin/bash
# collect_logs.sh — Cross-platform system log collector (Linux + macOS)
# Usage: collect_logs.sh [hours=24] [max_docker_lines=50]

HOURS=${1:-24}
MAX_DOCKER=${2:-50}
TS=$(date '+%Y-%m-%d %H:%M:%S')
OS=$(uname -s)

sep() { echo ""; echo "════════════════════════════════════════"; echo "  $1"; echo "════════════════════════════════════════"; }

echo "LOG COLLECTION REPORT"
echo "Generated : $TS"
echo "Window    : last ${HOURS} hour(s)"
echo "Host      : $(hostname)"
echo "OS        : $OS $(uname -r)"

# ── Linux-specific sources ─────────────────────────────────────────────────
if [ "$OS" = "Linux" ]; then

  sep "FAILED SYSTEMD UNITS"
  systemctl list-units --failed --no-legend 2>/dev/null || echo "(none)"

  sep "JOURNALCTL ERRORS (err/crit/alert/emerg)"
  journalctl --since "${HOURS} hours ago" -p err..emerg --no-pager -o short-iso 2>/dev/null \
    | sort | uniq -c | sort -rn | head -150 || echo "(none or journald unavailable)"

  sep "JOURNALCTL WARNINGS"
  journalctl --since "${HOURS} hours ago" -p warning --no-pager -o short-iso 2>/dev/null \
    | sort | uniq -c | sort -rn | head -100 || echo "(none)"

  sep "KERNEL RING BUFFER (err/warn/crit/emerg)"
  dmesg -T -l err,warn,crit,emerg 2>/dev/null | tail -80 || echo "(none or unavailable)"

  sep "AUTH FAILURES (SSH, PAM, sudo)"
  journalctl --since "${HOURS} hours ago" -u sshd -u ssh --no-pager -o short-iso 2>/dev/null \
    | grep -iE "(fail|invalid|refused|denied|error|disconnect)" \
    | sort | uniq -c | sort -rn | head -60
  if [ -f /var/log/auth.log ]; then
    echo "--- /var/log/auth.log (recent failures) ---"
    grep -iE "(fail|invalid|refused|denied|error)" /var/log/auth.log \
      | tail -200 | sort | uniq -c | sort -rn | head -40
  fi

  sep "OOM KILLS"
  journalctl --since "${HOURS} hours ago" -k --no-pager 2>/dev/null \
    | grep -iE "oom|killed process|out of memory" | head -20 || echo "(none)"

fi

# ── macOS-specific sources ─────────────────────────────────────────────────
if [ "$OS" = "Darwin" ]; then

  sep "SYSTEM LOG (errors/faults, last ${HOURS}h)"
  # 'log show' can be slow on large windows — capped to 500 lines
  log show --last "${HOURS}h" --style syslog 2>/dev/null \
    | grep -iE "(error|fault|critical|warn|fail)" \
    | sort | uniq -c | sort -rn | head -150 || echo "(log command unavailable)"

  sep "CRASH REPORTS (recent)"
  find ~/Library/Logs/DiagnosticReports /Library/Logs/DiagnosticReports \
    -maxdepth 1 -name "*.crash" -newer /proc/1 2>/dev/null \
    | head -20 \
    | while read -r f; do echo "CRASH: $f"; head -5 "$f"; echo "---"; done \
    || echo "(none found)"

  sep "KERNEL / PANIC LOGS"
  find /Library/Logs -name "*.panic" -o -name "*.ips" 2>/dev/null | head -10 \
    | while read -r f; do echo "PANIC: $f ($(date -r "$f"))"; done \
    || echo "(none)"

  sep "AUTH FAILURES"
  log show --last "${HOURS}h" --predicate 'process == "sshd" OR process == "sudo"' \
    --style syslog 2>/dev/null \
    | grep -iE "(fail|invalid|refused|denied|error)" \
    | sort | uniq -c | sort -rn | head -40 || echo "(none)"

fi

# ── Cross-platform: Docker ─────────────────────────────────────────────────
sep "DOCKER CONTAINER STATUS"
if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
  docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.RunningFor}}\t{{.Image}}" 2>/dev/null

  echo ""
  echo "--- Containers not running ---"
  docker ps -a --format "{{.Names}}\t{{.Status}}" 2>/dev/null \
    | grep -iv "up " | head -20 || echo "(all running)"

  sep "DOCKER CONTAINER LOGS (filtered, last ${HOURS}h)"
  for cname in $(docker ps -a --format "{{.Names}}" 2>/dev/null); do
    echo ""
    echo "--- $cname ---"
    raw=$(docker logs --since "${HOURS}h" "$cname" 2>&1 \
      | grep -iE "(error|warn|critical|fail|exception|fatal|traceback|panic|oom|killed)" \
      | sort | uniq -c | sort -rn | head -n "$MAX_DOCKER")
    [ -z "$raw" ] && echo "(no errors/warnings in window)" || echo "$raw"
  done
else
  echo "(docker not available or daemon not running)"
fi

# ── Cross-platform: Disk and Memory ───────────────────────────────────────
sep "DISK USAGE"
df -h 2>/dev/null | grep -v "^tmpfs\|^devtmpfs\|^udev\|^map \|Filesystem" | head -20
echo ""
echo "--- Inodes (Linux only) ---"
df -i 2>/dev/null | grep -v "^tmpfs\|^devtmpfs\|^udev\|Filesystem" | head -10

sep "MEMORY SNAPSHOT"
if [ "$OS" = "Linux" ]; then
  free -h
elif [ "$OS" = "Darwin" ]; then
  vm_stat | head -20
  echo ""
  echo "--- Memory pressure ---"
  memory_pressure 2>/dev/null | head -5 || echo "(memory_pressure unavailable)"
fi

# ── Cross-platform: Disk health ───────────────────────────────────────────
sep "DISK HEALTH"
if command -v smartctl &>/dev/null; then
  for disk in $(lsblk -dno NAME,TYPE 2>/dev/null | awk '$2=="disk"{print "/dev/"$1}'); do
    echo "--- $disk ---"
    smartctl -H "$disk" 2>/dev/null | grep -E "SMART overall|result:" || echo "(unavailable)"
  done
elif [ "$OS" = "Darwin" ]; then
  echo "(use Disk Utility or 'diskutil info disk0' for macOS disk health)"
else
  echo "(smartmontools not installed — apt/brew install smartmontools)"
fi

# ── Cross-platform: Recent log files with errors ──────────────────────────
sep "OTHER LOG FILES (recent errors in /var/log)"
find /var/log -maxdepth 2 -type f -name "*.log" 2>/dev/null \
  | grep -vE "\.(gz|bz2|xz|zst)$" \
  | while read -r f; do
      hits=$(grep -csiE "(error|critical|fail|exception|fatal)" "$f" 2>/dev/null || echo 0)
      if [ "$hits" -gt 0 ] 2>/dev/null; then
        echo ""
        echo "--- $f ($hits matching lines) ---"
        grep -siE "(error|critical|fail|exception|fatal)" "$f" 2>/dev/null \
          | sort | uniq -c | sort -rn | head -20
      fi
    done

echo ""
echo "════ END OF LOG COLLECTION ════"
