#!/usr/bin/env bash
# <xbar.title>Tailscale Toggle</xbar.title>
# <xbar.author>Oliver</xbar.author>
# <xbar.version>1.0</xbar.version>
# <xbar.desc>Shows Tailscale connection status and toggles it on/off.</xbar.desc>
# <xbar.dependencies>bash,jq,Tailscale</xbar.dependencies>

set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

TAILSCALE="/Applications/Tailscale.app/Contents/MacOS/Tailscale"

get_status() {
    "$TAILSCALE" status --json 2>/dev/null \
        | jq '{state: .BackendState, ip: (.Self.TailscaleIPs[0] // null)}'
}

toggle() {
    local state
    state="$(get_status | jq -r '.state')"
    if [ "$state" = "Running" ]; then
        "$TAILSCALE" down
        local target="Stopped"
    else
        "$TAILSCALE" up
        local target="Running"
    fi

    # Wait up to 5s for state to reach target
    for _ in {1..50}; do
        state="$(get_status | jq -r '.state')"
        [ "$state" = "$target" ] && break
        sleep 0.1
    done
}

case "${1:-}" in
    toggle) toggle; exit 0 ;;
esac

# --- Menubar ---
status="$(get_status)"
state="$(jq -r '.state' <<<"$status")"
ip="$(jq -r '.ip // ""' <<<"$status")"

if [ "$state" = "Running" ]; then
    echo "| sfimage=network sfcolor=#34C759 tooltip='Tailscale: connected'"
else
    echo "| sfimage=network.slash sfcolor=#8E8E93 tooltip='Tailscale: disconnected'"
fi

echo "---"
if [ "$state" = "Running" ]; then
    echo "Tailscale: connected | color=#34C759"
    echo "IP: ${ip}"
    echo "Disconnect | bash=\"$0\" param1=toggle terminal=false refresh=true"
else
    echo "Tailscale: disconnected | color=#8E8E93"
    echo "Connect | bash=\"$0\" param1=toggle terminal=false refresh=true"
fi
echo "---"
echo "Refresh | refresh=true"
