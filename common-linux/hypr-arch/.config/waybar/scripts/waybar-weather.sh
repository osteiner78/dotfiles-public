#!/usr/bin/env bash
set -euo pipefail

# --- Location (Vila Mariana) ---
LAT="-23.59"
LON="-46.64"
TZ="America/Sao_Paulo"

# --- Config ---
CACHE="${HOME}/.cache/weather_waybar.json"
CACHE_TTL=300  # seconds
API="https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}&timezone=${TZ}&current_weather=true&hourly=precipitation_probability&forecast_days=1"

# --- Nerd Font weather icons (mono/propo both fine) ---
icon_for_code() {
  local c="$1" day="$2"
  case "$c" in
    0)  [[ "$day" -eq 1 ]] && echo "" || echo "" ;;  # clear day/night
    1)  [[ "$day" -eq 1 ]] && echo "" || echo "" ;;  # mostly clear
    2)  echo "" ;;                                    # partly cloudy
    3)  echo "" ;;                                    # overcast
    45|48) echo "" ;;                                # fog
    51|53|55) echo "" ;;                             # drizzle
    56|57) echo "" ;;                                # freezing drizzle
    61|63|65) echo "" ;;                             # rain
    66|67) echo "" ;;                                # freezing rain
    71|73|75|77) echo "" ;;                          # snow
    80|81|82) echo "" ;;                             # showers
    85|86) echo "" ;;                                # snow showers
    95|96|99) echo "" ;;                             # thunder
    *) echo "" ;;
  esac
}

class_for_code() {
  case "$1" in
    0|1|2) echo "clear" ;;
    3)     echo "clouds" ;;
    45|48) echo "fog" ;;
    51|53|55|56|57|61|63|65|66|67|80|81|82) echo "rain" ;;
    71|73|75|77|85|86) echo "snow" ;;
    95|96|99) echo "thunder" ;;
    *) echo "unknown" ;;
  esac
}

# --- Fetch with tiny cache ---
now=$(date +%s)
if [[ -f "$CACHE" ]] && (( now - $(stat -c %Y "$CACHE" 2>/dev/null || echo 0) < CACHE_TTL )); then
  json="$(cat "$CACHE" 2>/dev/null || true)"
else
  json="$(curl -fsS --max-time 6 "$API" || true)"
  if [[ -n "${json:-}" ]]; then
    mkdir -p "$(dirname "$CACHE")"
    printf '%s' "$json" > "$CACHE"
  fi
fi

# If still empty, output a safe placeholder
if [[ -z "${json:-}" ]]; then
  jq -cn --arg text "--" --arg tooltip "weather fetch failed" \
    '{text:$text, tooltip:$tooltip, class:"weather error", alt:"weather", icon:""}'
  exit 0
fi

# --- Parse fields ---
temp=$(jq -r '.current_weather.temperature // empty' <<<"$json")
code=$(jq -r '.current_weather.weathercode // empty' <<<"$json")
is_day=$(jq -r '.current_weather.is_day // 1' <<<"$json")
wind=$(jq -r '.current_weather.windspeed // empty' <<<"$json")
time_now=$(jq -r '.current_weather.time // empty' <<<"$json")

# next-hour rain probability (best-effort)
# Map current time to the matching hourly index if available; otherwise fallback to first item
idx=$(jq -r --arg t "$time_now" '
  (.hourly.time // []) as $tt
  | ([$tt[] | tojson] | index(($t|tojson))) // 0
' <<<"$json")
pop=$(jq -r --argjson i "${idx:-0}" '.hourly.precipitation_probability[$i] // empty' <<<"$json")

# Guard missing numbers
[[ -z "$temp" ]] && temp="--"
[[ -z "$wind" ]] && wind="--"
[[ -z "$code" ]] && code="0"
[[ -z "$pop"  ]] && pop=""

icon="$(icon_for_code "$code" "$is_day")"
klass="$(class_for_code "$code")"

# Display text and tooltip
text="${temp}°C"
tooltip=$(
  printf "Temp: %s°C\nWind: %s km/h\nCode: %s (WMO)" "$temp" "$wind" "$code"
  if [[ -n "$pop" ]]; then printf "\nNext-hour rain: %s%%" "$pop"; fi
  printf "\nSource: open-meteo.com"
)

# --- One-line JSON for Waybar ---
# Expose BOTH 'icon' and 'text' so you can use "format": "{icon} {text}"
jq -cn --arg icon "$icon" --arg text "$text" --arg tooltip "$tooltip" --arg klass "$klass" \
  '{text:($icon + " " + $text), tooltip:$tooltip, class:("weather " + $klass), alt:"weather"}'
