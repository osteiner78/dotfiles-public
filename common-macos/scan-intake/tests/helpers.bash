# Shared setup for the scan-intake bats tests.
#
# Each test gets a throwaway $HOME, so the script's real paths
# (~/.config/scan-intake/.env, ~/Scans, ~/Library/Logs/scan-intake.log,
# ~/Library/LaunchAgents) all land in $BATS_TEST_TMPDIR. curl, osascript and
# launchctl are replaced by the stubs in tests/stubs/.

ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
SCRIPT="$ROOT/scan-intake"
TOKEN="tok-0123456789abcdef"
PUBLIC_HOST="paperless.test"
LAN_HOST="lan.test"

setup() {
    export HOME="$BATS_TEST_TMPDIR/home"
    export STUB_LOG="$BATS_TEST_TMPDIR/stub-log"
    export FIXTURES="$BATS_TEST_TMPDIR/fixtures"
    export PATH="$ROOT/tests/stubs:/usr/bin:/bin:/usr/sbin"
    mkdir -p "$HOME" "$STUB_LOG" "$FIXTURES/$PUBLIC_HOST" "$FIXTURES/$LAN_HOST"
    touch "$STUB_LOG/curl.log" "$STUB_LOG/curl.stdin" "$STUB_LOG/osascript.log" "$STUB_LOG/launchctl.log"

    ENV_FILE="$HOME/.config/scan-intake/.env"
    LOG="$HOME/Library/Logs/scan-intake.log"
    SCANS="$HOME/Scans"

    write_env
    stub_upload_ok "b1ad602d-0000-4000-8000-000000000001"
    stub_task SUCCESS '"related_document": 6342, "result": "Success. New document id 6342 created"'
    stub_http "$PUBLIC_HOST" tags 200 '{"count": 1, "results": []}'
}

# write_env [EXTRA_LINE...] — a valid .env (mode 600) plus optional overrides.
write_env() {
    mkdir -p "$(dirname "$ENV_FILE")"
    {
        echo "PAPERLESS_TOKEN=$TOKEN"
        echo "PAPERLESS_URL=https://$PUBLIC_HOST"
        echo "STABLE_SECS=0"
        echo "POLL_INTERVAL=0"
        echo "POLL_TIMEOUT=5"
        printf '%s\n' "$@"
    } >"$ENV_FILE"
    chmod 600 "$ENV_FILE"
}

# ── fixtures ────────────────────────────────────────────────────────────────

stub_http() { # host endpoint code [body]
    printf '%s' "$3" >"$FIXTURES/$1/$2.code"
    printf '%s' "${4:-}" >"$FIXTURES/$1/$2.body"
    rm -f "$FIXTURES/$1/$2.exit"
}

stub_transport_error() { # host endpoint curl-exit-code
    printf '%s' "$3" >"$FIXTURES/$1/$2.exit"
}

stub_upload_ok() { # uuid [host]
    stub_http "${2:-$PUBLIC_HOST}" post_document 200 "\"$1\""
}

stub_task() { # status extra-json-fields [host]
    local extra="${2:+, $2}"
    stub_http "${3:-$PUBLIC_HOST}" tasks 200 \
        "[{\"task_id\": \"b1ad602d-0000-4000-8000-000000000001\", \"status\": \"$1\"$extra}]"
}

# make_scan NAME [AGE] — a small file in outbox/. AGE backdates its mtime with
# a BSD `date -v` offset such as -2H or -200d (macOS date; GNU date differs).
make_scan() {
    mkdir -p "$SCANS/outbox"
    printf '%%PDF-1.4\n%% %s\n' "$1" >"$SCANS/outbox/$1"
    [[ -n "${2:-}" ]] && backdate "$SCANS/outbox/$1" "$2"
    return 0
}

backdate() { # path BSD-date-offset
    touch -t "$(date -v"$2" +%Y%m%d%H%M.%S)" "$1"
}

# on_upload SCRIPT — bash code the curl stub runs once, during the next
# post_document call (after its response is decided). It sees $HOME, $FIXTURES
# and $STUB_LOG.
on_upload() {
    printf '%s\n' "$1" >"$FIXTURES/on_post_document"
}

# drop_during_upload NAME — a scan lands in outbox while the first upload runs.
drop_during_upload() {
    on_upload "printf '%%PDF-1.4\\n' >\"\$HOME/Scans/outbox/$1\""
}

run_intake() {
    run "$SCRIPT" "$@"
}

# use_terminal_notifier — put the fake terminal-notifier on PATH, so the
# script sends clickable notifications instead of using osascript.
use_terminal_notifier() {
    export PATH="$ROOT/tests/stubs-tn:$PATH"
    touch "$STUB_LOG/terminal-notifier.log"
}

# tn_calls — number of terminal-notifier calls.
tn_calls() {
    grep -c . "$STUB_LOG/terminal-notifier.log" 2>/dev/null || true
}

# tn_arg FLAG [CALL] — the value after FLAG in call number CALL (default: the
# last call); empty and status 1 when the flag is absent.
tn_arg() {
    local line
    if [[ -n "${2:-}" ]]; then
        line="$(sed -n "${2}p" "$STUB_LOG/terminal-notifier.log")"
    else
        line="$(tail -n 1 "$STUB_LOG/terminal-notifier.log")"
    fi
    awk -v RS='\037' -v flag="$1" 'found { print; ok = 1; exit } $0 == flag { found = 1 } END { exit !ok }' <<<"$line"
}

# write_success_log — a log with two uploads; the latest is doc 6342.
write_success_log() {
    mkdir -p "${LOG%/*}"
    cat >"$LOG" <<'LOG'
2026-10-20T08:00:00+0200 INFO  run_start outbox=1 pending=0
2026-10-20T08:00:40+0200 INFO  success file="old.pdf" doc=6000 secs=35
2026-10-21T09:14:03+0200 INFO  run_start outbox=1 pending=0
2026-10-21T09:14:41+0200 INFO  success file="Portail clients.pdf" doc=6342 secs=36
LOG
}

# ── assertions ──────────────────────────────────────────────────────────────

assert_in() { # subdir name
    [[ -f "$SCANS/$1/$2" ]] || {
        echo "expected $1/$2; tree:"
        find "$SCANS" -type f | sed "s|$SCANS/||" | sort
        return 1
    }
}

refute_in() { # subdir name
    [[ ! -e "$SCANS/$1/$2" ]] || {
        echo "did not expect $1/$2"
        return 1
    }
}

assert_log() { # extended regex, matched against the log file
    grep -Eq -- "$1" "$LOG" 2>/dev/null || {
        echo "log has no line matching: $1"
        echo "--- log ---"
        cat "$LOG" 2>/dev/null
        return 1
    }
}

refute_log() {
    ! grep -Eq -- "$1" "$LOG" 2>/dev/null || {
        echo "log unexpectedly matches: $1"
        grep -E -- "$1" "$LOG"
        return 1
    }
}

assert_notified() { # extended regex, matched against the osascript calls
    grep -Eq -- "$1" "$STUB_LOG/osascript.log" || {
        echo "no notification matching: $1"
        echo "--- notifications ---"
        cat "$STUB_LOG/osascript.log"
        return 1
    }
}

refute_notified() {
    ! grep -Eq -- "$1" "$STUB_LOG/osascript.log" || {
        echo "unexpected notification matching: $1"
        grep -E -- "$1" "$STUB_LOG/osascript.log"
        return 1
    }
}

notification_count() {
    grep -c . "$STUB_LOG/osascript.log" || true
}

curl_calls() { # endpoint-path fragment, e.g. post_document or tasks
    grep -c -- "$1" "$STUB_LOG/curl.log" || true
}

assert_status() { # expected exit status of the last `run`
    [[ "$status" -eq "$1" ]] || {
        echo "expected exit $1, got $status"
        echo "--- output ---"
        echo "$output"
        return 1
    }
}
