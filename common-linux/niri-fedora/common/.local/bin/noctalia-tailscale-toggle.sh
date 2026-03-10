#!/bin/bash

# 1. Get current status
# Status "true" means it's connected/up
IS_ONLINE=$(tailscale status --self --json 2>/dev/null | jq -r '.Self.Online' 2>/dev/null)

# 2. Toggle flow
if [[ "$1" == "toggle" ]]; then
    if [[ "$IS_ONLINE" == "true" ]]; then
        tailscale down
        TARGET="false"
    else
        tailscale up
        TARGET="true"
    fi
    
    # Wait for status to reach TARGET (up to 5 seconds)
    for i in {1..50}; do
        IS_ONLINE=$(tailscale status --self --json 2>/dev/null | jq -r '.Self.Online' 2>/dev/null)
        if [[ "$TARGET" == "true" && "$IS_ONLINE" == "true" ]]; then
            break
        elif [[ "$TARGET" == "false" && "$IS_ONLINE" != "true" ]]; then
            break
        fi
        sleep 0.1
    done
fi

# 3. Final Output Mapping
if [[ "$IS_ONLINE" == "true" ]]; then
    IP=$(tailscale ip -4 2>/dev/null)
    echo "{\"text\": \"$IP\", \"class\": \"connected\"}"
else
    echo "{\"text\": \"down\", \"class\": \"disconnected\"}"
fi
