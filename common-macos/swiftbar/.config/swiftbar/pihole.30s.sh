#!/usr/bin/env bash
# <xbar.title>Pi-hole Toggle</xbar.title>
# <xbar.author>Oliver</xbar.author>
# <xbar.version>1.0</xbar.version>
# <xbar.desc>Shows Pi-hole v6 blocking status and toggles it on/off.</xbar.desc>
# <xbar.dependencies>bash,curl,jq</xbar.dependencies>

set -euo pipefail

# --- CONFIG ---
PIHOLE_URL="${PIHOLE_URL:-http://192.168.1.100}"
PIHOLE_PASSWORD="${PIHOLE_PASSWORD:-4wDwnwj8tqUmvmyxjOkGUhkG0Ll12J2EdMjj22zWtmg=}"
TIMEOUT="${TIMEOUT:-4}"
# --------------

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"


get_sid() {
    curl -fsS --max-time "$TIMEOUT" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "{\"password\": \"${PIHOLE_PASSWORD}\"}" \
        "${PIHOLE_URL}/api/auth" |
        jq -r '.session.sid // empty'
}

get_blocking() {
    local sid="$1"
    curl -fsS --max-time "$TIMEOUT" \
        -H "X-FTL-SID: ${sid}" \
        "${PIHOLE_URL}/api/dns/blocking" |
        jq -r '.blocking'
}

set_blocking() {
    local sid="$1" state="$2" # state: true | false (JSON boolean)
    curl -fsS --max-time "$TIMEOUT" \
        -X POST \
        -H "Content-Type: application/json" \
        -H "X-FTL-SID: ${sid}" \
        -d "{\"blocking\": ${state}}" \
        "${PIHOLE_URL}/api/dns/blocking" >/dev/null
}

toggle() {
    local sid
    sid="$(get_sid)" || {
        echo "Pi-hole auth failed" >&2
        exit 1
    }
    local current
    current="$(get_blocking "$sid")"
    if [ "$current" = "enabled" ]; then
        set_blocking "$sid" "false"
    else
        set_blocking "$sid" "true"
    fi
}

case "${1:-}" in
toggle)
    toggle
    exit 0
    ;;
esac

# --- Menubar ---
sid="$(get_sid 2>/dev/null || true)"

if [ -z "$sid" ]; then
    echo "| sfimage=shield.slash sfcolor=#8E8E93 tooltip='Pi-hole: unreachable'"
    echo "---"
    echo "Could not connect to Pi-hole at ${PIHOLE_URL}"
    echo "Refresh | refresh=true"
    exit 0
fi

blocking="$(get_blocking "$sid" 2>/dev/null || echo "unknown")"

if [ "$blocking" = "enabled" ]; then
    echo "| sfimage=shield sfcolor=#34C759 tooltip='Pi-hole: blocking'"
else
    echo "| sfimage=shield.slash sfcolor=#FF3B30 tooltip='Pi-hole: disabled'"
fi

echo "---"
if [ "$blocking" = "enabled" ]; then
    echo "Pi-hole: blocking | color=#34C759"
    echo "Disable Pi-hole | bash=\"$0\" param1=toggle terminal=false refresh=true"
else
    echo "Pi-hole: disabled | color=#FF3B30"
    echo "Enable Pi-hole | bash=\"$0\" param1=toggle terminal=false refresh=true"
fi
echo "---"
echo "Refresh | refresh=true"
echo "${PIHOLE_URL} | color=#8E8E93"
