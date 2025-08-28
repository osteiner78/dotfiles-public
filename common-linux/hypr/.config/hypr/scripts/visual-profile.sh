#!/usr/bin/env bash
set -euo pipefail

# ---- config/state ----
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hypr-visual-profile"
STATE_FILE="$CACHE_DIR/state"          # last applied: "battery" or "fancy"
OVERRIDE_FILE="$CACHE_DIR/override"    # lines: mode=<battery|fancy>, source=<AC|BAT>
SYS_STATUS="/sys/class/power_supply/macsmc-battery/status"

mkdir -p "$CACHE_DIR"

# ---- helpers ----
notify() {
  local msg="$1" icon="${2:-preferences-system}" quiet="${3:-0}"
  [ "$quiet" = "1" ] && return 0
  notify-send -a Hyprland "Battery saver" "$msg" -u low -i "$icon" || true
}

power_source() {
  # BAT if Discharging; otherwise AC (Charging/Full/Not charging)
  if grep -qx Discharging "$SYS_STATUS" 2>/dev/null; then echo "BAT"; else echo "AC"; fi
}

read_state()     { [ -f "$STATE_FILE" ] && cat "$STATE_FILE" || echo ""; }
write_state()    { printf '%s\n' "$1" > "$STATE_FILE"; }
read_override()  { [ -f "$OVERRIDE_FILE" ] && cat "$OVERRIDE_FILE" || echo ""; }
clear_override() { rm -f "$OVERRIDE_FILE"; }

apply_battery() {
  hyprctl keyword decoration:blur:enabled 0
  hyprctl keyword decoration:active_opacity 0.98
  hyprctl keyword decoration:inactive_opacity 0.94
  hyprctl keyword decoration:shadow:range 3
  hyprctl keyword decoration:shadow:render_power 2
  hyprctl keyword animation "global, 1, 5, default"
}

apply_fancy() {
  hyprctl keyword decoration:blur:enabled 1
  hyprctl keyword decoration:active_opacity 0.95
  hyprctl keyword decoration:inactive_opacity 0.85
  hyprctl keyword decoration:shadow:range 4
  hyprctl keyword decoration:shadow:render_power 3
  hyprctl keyword animation "global, 1, 6, default"
}

apply_mode() {
  # $1 = battery|fancy ; $2 = quiet(0/1)
  local target="$1" quiet="${2:-0}" last
  last="$(read_state)"
  if [ "$last" = "$target" ]; then
    # no-op, no notification
    return 0
  fi
  case "$target" in
    battery) apply_battery; write_state battery; notify "Visual effects trimmed (battery)" battery-low "$quiet" ;;
    fancy)   apply_fancy;   write_state fancy;   notify "Visual effects restored"         battery-good "$quiet" ;;
    *) echo "invalid target: $target" >&2; exit 2 ;;
  esac
}

auto_target() {
  # pure auto: derive target from current power source
  [ "$(power_source)" = "BAT" ] && echo battery || echo fancy
}

effective_target() {
  # considers override; clears it if power source changed
  local src cur overr mode o_src
  cur="$(power_source)"
  overr="$(read_override)"
  if [ -n "$overr" ]; then
    mode="$(printf '%s\n' "$overr" | awk -F= '/^mode=/{print $2}')"
    o_src="$(printf '%s\n' "$overr" | awk -F= '/^source=/{print $2}')"
    if [ "$o_src" = "$cur" ] && [ -n "$mode" ]; then
      echo "$mode"
      return
    else
      # source flipped → override expires
      clear_override
    fi
  fi
  auto_target
}

set_override() {
  # $1 = battery|fancy ; pins to current source until it flips
  local cur
  cur="$(power_source)"
  printf 'mode=%s\nsource=%s\n' "$1" "$cur" > "$OVERRIDE_FILE"
}

override_for_current_source() {
  # prints "battery" or "fancy" if override applies to CURRENT source; else prints nothing
  [ -f "$OVERRIDE_FILE" ] || return 1
  local cur mode o_src
  cur="$(power_source)"
  mode="$(awk -F= '/^mode=/{print $2}'   "$OVERRIDE_FILE")"
  o_src="$(awk -F= '/^source=/{print $2}' "$OVERRIDE_FILE")"
  [ "$o_src" = "$cur" ] && [ -n "$mode" ] && printf '%s\n' "$mode"
}

# ---- CLI ----
QUIET=0
MODE="--help"
for a in "$@"; do
  case "$a" in
    --quiet) QUIET=1 ;;
    --battery|--fancy|--toggle|--auto|--clear-override) MODE="$a" ;;
    *) MODE="--help" ;;
  esac
done

case "$MODE" in
  --battery) clear_override;            apply_mode battery "$QUIET" ;;
  --fancy)   clear_override;            apply_mode fancy   "$QUIET" ;;
  --clear-override)                     clear_override;    apply_mode "$(auto_target)" "$QUIET" ;;
  --auto)
    apply_mode "$(effective_target)" "$QUIET"
    ;;
  --toggle)
    # If an override for the current power source exists -> clear it and return to AUTO.
    if cur_overr="$(override_for_current_source)"; then
      clear_override
      apply_mode "$(auto_target)" "$QUIET"
      exit 0
    fi
    # Otherwise create an override: opposite of AUTO target.
    auto="$(auto_target)"
    if [ "$auto" = "battery" ]; then
      set_override fancy
      apply_mode fancy "$QUIET"
    else
      set_override battery
      apply_mode battery "$QUIET"
    fi
    ;;
esac
