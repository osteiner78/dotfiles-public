
#!/usr/bin/env bash
set -euo pipefail

LOW=${LOW:-20}     # warn at/below this %
CRIT=${CRIT:-10}   # critical warn at/below this %
STATEFILE="${XDG_CACHE_HOME:-$HOME/.cache}/battery-watch.state"
mkdir -p "$(dirname "$STATEFILE")"

# ---- helpers ----
notify() {
  # $1: urgency (low|normal|critical), $2: title, $3: body
  notify-send -u "$1" -a "battery-watch" -i "battery" \
    -h string:x-canonical-private-synchronous:battery \
    "$2" "$3"
}

get_battery_sysfs() {
  # echo "PERCENT STATUS"
  local ps
  for ps in /sys/class/power_supply/*; do
    [[ -r "$ps/type" && -r "$ps/capacity" && -r "$ps/status" ]] || continue
    grep -qi "battery" "$ps/type" || continue
    local pct status
    pct=$(<"$ps/capacity")
    status=$(<"$ps/status")            # Charging/Discharging/Full/Unknown
    echo "$pct $status"
    return 0
  done
  return 1
}

get_battery_upower() {
  # echo "PERCENT STATUS"
  command -v upower >/dev/null 2>&1 || return 1
  local dev
  dev=$(upower -e | grep -i battery | head -n1) || return 1
  local pct status
  pct=$(upower -i "$dev" | awk -F': *' '/percentage/{gsub("%","",$2);print $2}')
  status=$(upower -i "$dev" | awk -F': *' '/state/{print $2}')
  [[ -n "$pct" && -n "$status" ]] || return 1
  # Normalize status
  case "$status" in
    charging|fully-charged) status="Charging" ;;
    discharging)            status="Discharging" ;;
    *)                      status="Unknown" ;;
  esac
  echo "$pct $status"
}

read_battery() {
  get_battery_upower || get_battery_sysfs || {
    echo "0 Unknown"; return 1;
  }
}

# ---- main ----
read -r PCT STATUS < <(read_battery || echo "0 Unknown")

# Only warn while discharging
if [[ "${STATUS,,}" != "discharging" ]]; then
  echo "ok" > "$STATEFILE"
  exit 0
fi

LAST="ok"
[[ -f "$STATEFILE" ]] && LAST=$(<"$STATEFILE")

if (( PCT <= CRIT )); then
  if [[ "$LAST" != "crit" ]]; then
    notify critical "Battery critical (${PCT}%)" "Plug in the charger now."
    echo "crit" > "$STATEFILE"
  fi
elif (( PCT <= LOW )); then
  if [[ "$LAST" != "low" && "$LAST" != "crit" ]]; then
    notify normal "Battery low (${PCT}%)" "Consider plugging in."
    echo "low" > "$STATEFILE"
  fi
else
  # reset state above LOW so you get notified again next time you dip
  echo "ok" > "$STATEFILE"
fi

# Optional: auto-suspend when extremely low (uncomment if you want)
# if (( PCT <= 5 )); then systemctl suspend; fi
