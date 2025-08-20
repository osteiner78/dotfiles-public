
#!/usr/bin/env bash

has() {
  local verbose=false
  if [[ $1 == '-v' ]]; then
    verbose=true
    shift
  fi
  for c in "$@"; do c="${c%% *}"
    if ! command -v "$c" &> /dev/null; then
      [[ "$verbose" == true ]] && err "$c not found"
      return 1
    fi
  done
}

err() { printf '\e[31m%s\e[0m\n' "$*" >&2; }
die() { (( $# > 0 )) && err "$*"; exit 1; }

has -v nmcli fzf || die

# Pick the first Wi-Fi interface for disconnects (override with IFACE=wlp1s0f0 ./script)
IFACE="${IFACE:-$(nmcli -t -f DEVICE,TYPE device | awk -F: '$2=="wifi"{print $1; exit}')}"

nmcli -f 'bssid,signal,bars,freq,rate,ssid' --color yes device wifi |
  fzf \
    --with-nth=2.. \
    --ansi \
    --height=40% \
    --reverse \
    --cycle \
    --inline-info \
    --header-lines=1 \
    --header="Enter: connect  •  Ctrl-R: rescan  •  Ctrl-D: disconnect  •  Esc/q: quit" \
    --bind="enter:execute:nmcli -a device wifi connect {1}" \
    --bind="ctrl-r:execute-silent(nmcli device wifi rescan)+reload(nmcli -f 'bssid,signal,bars,freq,ssid' --color yes device wifi)" \
    --bind="ctrl-d:execute-silent(nmcli device disconnect ${IFACE})+reload(nmcli -f 'bssid,signal,bars,freq,ssid' --color yes device wifi)" \
    --bind='q:abort'
