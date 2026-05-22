#!/bin/bash
# Configuration
PIHOLE_IP="192.168.1.100"
APP_PASSWORD="4wDwnwj8tqUmvmyxjOkGUhkG0Ll12J2EdMjj22zWtmg="
SID_FILE="/tmp/pihole_sid_${PIHOLE_IP//./_}"

# Function to perform authentication and cache the SID
authenticate() {
    local session
    session=$(curl -s -X POST "http://$PIHOLE_IP/api/auth" -d "{\"password\":\"$APP_PASSWORD\"}")
    local sid
    sid=$(echo "$session" | jq -r '.session.sid // empty')
    if [[ -n "$sid" ]]; then
        echo "$sid" > "$SID_FILE"
        echo "$sid"
    else
        return 1
    fi
}

# 1. Load cached SID or authenticate
if [[ -f "$SID_FILE" ]]; then
    SID=$(cat "$SID_FILE")
else
    SID=$(authenticate)
fi

# 2. Try to fetch status using the current SID
# We check the HTTP status code to detect expired sessions (401/403)
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "http://$PIHOLE_IP/api/dns/blocking" -H "X-FTL-SID: $SID")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | head -n -1)

# 3. If SID is missing or session is invalid, re-authenticate and retry
if [[ -z "$SID" || "$HTTP_CODE" == "401" || "$HTTP_CODE" == "403" ]]; then
    SID=$(authenticate)
    if [[ -z "$SID" ]]; then
        echo "{\"text\": \"Auth Fail\", \"icon\": \"alert-triangle\", \"class\": \"error\"}"
        exit 1
    fi
    # Retry the request with the new SID
    BODY=$(curl -s -X GET "http://$PIHOLE_IP/api/dns/blocking" -H "X-FTL-SID: $SID")
fi

CURRENT_STATUS=$(echo "$BODY" | jq -r '.blocking')
HEADER="X-FTL-SID: $SID"

# 4. Get Status & Toggle flow
if [[ "$1" == "toggle" ]]; then
    # Ternary-style logic for the boolean payload
    [[ "$CURRENT_STATUS" == "enabled" ]] && TARGET=false || TARGET=true
    
    # Perform the toggle
    NEW_STATE=$(curl -s -X POST "http://$PIHOLE_IP/api/dns/blocking" \
         -H "$HEADER" \
         -H "Content-Type: application/json" \
         -d "{\"blocking\": $TARGET}" | jq -r '.blocking')
    BLOCKING=$NEW_STATE
else
    BLOCKING=$CURRENT_STATUS
fi

# 5. Final Output Mapping
if [[ "$BLOCKING" == "enabled" ]]; then
    echo "{\"text\": \"on\", \"icon\": \"barrier-block\", \"class\": \"active\"}"
else
    echo "{\"text\": \"off\", \"icon\": \"barrier-block\", \"class\": \"inactive\"}"
fi
