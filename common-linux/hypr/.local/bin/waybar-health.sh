
#!/usr/bin/env bash
set -euo pipefail

args=("$@")
failed=()
inactive=()
lines=()

SYSTEMCTL=/usr/bin/systemctl

sys_units=()
proc_specs=()   # entries like "proc:NAME" or "cmd:PATTERN"

# Split inputs into systemd units vs process specs
for a in "${args[@]}"; do
  if [[ "$a" == *.service || "$a" == *.socket || "$a" == *.timer || "$a" == *.target ]]; then
    sys_units+=("$a")
  elif [[ "$a" == proc:* || "$a" == cmd:* ]]; then
    proc_specs+=("$a")
  else
    # Default to systemd if it looks like a unit, otherwise assume process name
    if [[ "$a" == *.* ]]; then
      sys_units+=("$a")
    else
      proc_specs+=("proc:$a")
    fi
  fi
done

# Query systemd units (batch) if any
statuses=()
if ((${#sys_units[@]})); then
  if ! mapfile -t statuses < <("$SYSTEMCTL" --user is-active "${sys_units[@]}" 2>/dev/null); then
    printf '{"text":" ERR","class":"bad","tooltip":"systemctl --user failed"}'
    exit 0
  fi
fi

# Classify systemd units
for i in "${!sys_units[@]}"; do
  u="${sys_units[$i]}"; s="${statuses[$i]:-unknown}"
  case "$s" in
    active)
      lines+=("✓ ${u} (active)")
      ;;
    inactive|deactivating)
      inactive+=("$u")
      lines+=("△ ${u} (${s})")
      ;;
    failed)
      failed+=("$u")
      lines+=("✗ ${u} (failed)")
      ;;
    *)
      failed+=("$u")
      lines+=("? ${u} (${s})")
      ;;
  esac
done

# Classify process specs
for spec in "${proc_specs[@]}"; do
  case "$spec" in
    proc:*)
      name="${spec#proc:}"
      # exact match on process name
      if pgrep -x "$name" >/dev/null 2>&1; then
        lines+=("✓ ${name} (running)")
      else
        inactive+=("$name")
        lines+=("△ ${name} (not running)")
      fi
      ;;
    cmd:*)
      pat="${spec#cmd:}"
      # match pattern anywhere in cmdline
      if pgrep -af -- "$pat" >/dev/null 2>&1; then
        lines+=("✓ ${pat} (running)")
      else
        inactive+=("$pat")
        lines+=("△ ${pat} (not running)")
      fi
      ;;
  esac
done

# Summary text/class
if ((${#failed[@]})); then
  text=" ${#failed[@]}"
  cls="bad"
elif ((${#inactive[@]})); then
  text="󰓦 ${#inactive[@]}"
  cls="warn"
else
  text="󰄬"
  cls="ok"
fi

# Tooltip = one line per service
tooltip="$(printf '%s\n' "${lines[@]}")"

# JSON-escape helper
escape_json() {
  local s="$1"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  printf '%s' "$s"
}

printf '{"text":"%s","class":"%s","tooltip":"%s"}' \
  "$(escape_json "$text")" \
  "$(escape_json "$cls")"  \
  "$(escape_json "$tooltip")"
