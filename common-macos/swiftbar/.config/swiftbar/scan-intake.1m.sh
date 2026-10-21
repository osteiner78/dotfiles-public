#!/usr/bin/env bash
# <xbar.title>Scan intake</xbar.title>
# <xbar.author>Oliver</xbar.author>
# <xbar.version>1.0</xbar.version>
# <xbar.desc>Shows the scan-intake pipeline (outbox, pending, failed) and offers retry, run now and selftest.</xbar.desc>
# <xbar.dependencies>bash,jq,scan-intake</xbar.dependencies>

set -euo pipefail

PATH="$PATH:/usr/bin:/bin:/opt/homebrew/bin"

SI=$HOME/.local/bin/scan-intake
LABEL=xyz.osteiner.scan-intake
ICON="sfimage=doc.viewfinder"
# SwiftBar ignores sfcolor on the menu-bar icon; Palette rendering via sfconfig colours it.
RED="sfconfig=$(printf '%s' '{"renderingMode":"Palette","colors":["red"],"scale":"medium","weight":"regular"}' | base64)"

if [[ ! -x $SI ]]; then
    echo "scan-intake not installed | $ICON"
    exit 0
fi

json=$("$SI" status --json 2>/dev/null) || {
    echo "| $ICON $RED"
    echo "---"
    echo "scan-intake status failed | color=red"
    exit 0
}

j() { jq -r "$1" <<<"$json"; }

clean() { # text -> text without the | that starts SwiftBar parameters
    printf '%s' "${1//|/¦}"
}

q() { # value -> value quoted for a SwiftBar parameter when needed
    if [[ $1 == *[\ \"]* ]]; then
        printf '"%s"' "${1//\"/\\\"}"
    else
        printf '%s' "$1"
    fi
}

ago() { # ISO timestamp -> "5m ago"; empty when unparsable
    local ts secs
    ts=$(date -j -f '%Y-%m-%dT%H:%M:%S%z' "$1" +%s 2>/dev/null) || return 0
    secs=$(($(date +%s) - ts))
    if ((secs < 3600)); then
        echo "$((secs / 60))m ago"
    elif ((secs < 86400)); then
        echo "$((secs / 3600))h ago"
    else
        echo "$((secs / 86400))d ago"
    fi
}

action() { # label bash-path terminal refresh param...
    local label=$1 cmd=$2 terminal=$3 refresh=$4 line i=0 p
    shift 4
    line="$label | bash=$(q "$cmd")"
    for p in "$@"; do
        i=$((i + 1))
        line+=" param$i=$(q "$p")"
    done
    echo "$line terminal=$terminal refresh=$refresh"
}

outbox=$(j .counts.outbox)
pending=$(j .counts.pending)
failed=$(j .counts.failed)
url=$(j .paperless_url)
root=$(j .paths.root)
log=$(j .paths.log)
config_ok=$(j .config_ok)
loaded=$(j .agent_loaded)

queued=$((outbox + pending))
title=""
if ((queued > 0)); then title=$queued; fi
bar="$title | $ICON"
if ((failed > 0)) || [[ $config_ok == false || $loaded == false ]]; then bar+=" $RED"; fi
echo "$bar"
echo "---"

if [[ $config_ok == false ]]; then echo "Config error: $(clean "$(j .config_error)") | color=red"; fi
if [[ $loaded == false ]]; then echo "Agent not loaded | color=red"; fi

doc=$(j '.last_success.doc // empty')
if [[ -n $doc ]]; then
    when=$(ago "$(j .last_success.at)")
    echo "Last upload: $(clean "$(j .last_success.file)") → #$doc${when:+ ($when)} | href=$url/documents/$doc/details"
fi

echo "Outbox $outbox"
echo "Pending $pending"
if ((failed > 0)); then
    echo "Failed $failed | color=red"
    while IFS= read -r file && IFS= read -r err; do
        echo "--$(clean "$file")"
        echo "----$(clean "$err")"
        action "----Retry" "$SI" false true retry "$file"
    done < <(j '.failed[] | .file, .error')
else
    echo "Failed 0"
fi

echo "---"
if ((failed > 0)); then action "Retry all failed" "$SI" false true retry all; fi
action "Run now" "$(command -v launchctl)" false false kickstart "gui/$(id -u)/$LABEL"
action "Run selftest" "$SI" true false --selftest

echo "---"
action "Open Scans folder" /usr/bin/open false false "$root"
action "Open failed/" /usr/bin/open false false "$root/failed"
action "Open log" /usr/bin/open false false "$log"
echo "Open paperless | href=$url"
