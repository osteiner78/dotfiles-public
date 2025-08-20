
# ~/.local/bin/run-waybar.sh
#!/usr/bin/env bash
set -euo pipefail

export WAYBAR_DISABLE_APPEARANCE=1
export WAYBAR_DISABLE_PORTAL_APPEARANCE=1
export XDG_DESKTOP_PORTAL_DIR=/dev/null

have_socket() {
  [[ -n "${WAYLAND_DISPLAY:-}" && -n "${XDG_RUNTIME_DIR:-}" && -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]]
}

# wait for the Wayland socket (up to ~10s)
for i in {1..200}; do have_socket && break; sleep 0.05; done

log="${XDG_RUNTIME_DIR:-/tmp}/waybar-autorestart.log"
backoff=1

# exit cleanly if Hyprland is stopping
trap 'exit 0' TERM INT

while have_socket; do
  echo "$(date) starting waybar" >>"$log"
  set +e                 # <-- don't let a crash/kill abort the script
  waybar &
  pid=$!
  wait "$pid"
  code=$?
  set -e
  echo "$(date) waybar exited code $code" >>"$log"

  have_socket || break
  sleep "$backoff"
  (( backoff < 5 )) && ((backoff++))
done
