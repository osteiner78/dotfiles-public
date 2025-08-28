#!/usr/bin/env bash
# <xbar.title>HA In/Out Temps</xbar.title>
# <xbar.author>Oliver + ChatGPT</xbar.author>
# <xbar.version>1.2</xbar.version>
# <xbar.desc>Shows inside/outside temps in one API call.</xbar.desc>
# <xbar.dependencies>bash,curl,jq</xbar.dependencies>

set -eo pipefail

# --- CONFIG ---
HA_URL="${HA_URL:-https://home.osteiner.xyz}"
HA_TOKEN="${HA_TOKEN:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiI2ZjA2NWJkY2EwYTk0YzlkODkxMDAyZWQwYTAyZGExMCIsImlhdCI6MTc1NjI2MTQ2OSwiZXhwIjoyMDcxNjIxNDY5fQ.za-Wv8xq8W1XZu46fqOp_8YCx2_c1mUv9JD6xlbcTjM}"
IN_SENSOR="${IN_SENSOR:-sensor.aqara_temperature_sensor_bedroom_temperature}"
OUT_SENSOR="${OUT_SENSOR:-sensor.aqara_temperature_sensor_terrace_temperature}"
TIMEOUT="${TIMEOUT:-4}"
# ---------------

json="$(curl -fsS --max-time "$TIMEOUT" \
  -H "Authorization: Bearer ${HA_TOKEN}" \
  -H "Content-Type: application/json" \
  "${HA_URL%/}/api/states" 2>/dev/null || true)"

get_temp() {
  local entity="$1"
  jq -r --arg e "$entity" '
    map(select(.entity_id==$e)) | .[0].state
  ' <<<"$json" \
  | awk '{ if ($0+0==$0) printf("%.0f\n",$0); else print "?" }'
}

in_temp="$(get_temp "$IN_SENSOR")"
out_temp="$(get_temp "$OUT_SENSOR")"

# Menubar line (compact)
echo "${in_temp}°｜${out_temp}° | sfimage=thermometer.medium"

# Dropdown
echo "---"
echo "Inside ($IN_SENSOR): ${in_temp} °"
echo "Outside ($OUT_SENSOR): ${out_temp} °"
echo "Refresh | refresh=true"
