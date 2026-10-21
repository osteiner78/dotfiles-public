#!/usr/bin/env bats
# Phase 1 — loading ~/.config/scan-intake/.env and creating the folders.

load helpers

@test "missing .env: exits 1" {
    rm "$ENV_FILE"
    run_intake --once
    assert_status 1
}

@test "missing .env: notifies Config error" {
    rm "$ENV_FILE"
    run_intake --once
    assert_notified 'Config error'
}

@test "empty token: exits 1 with Config error notification" {
    write_env
    sed -i '' 's/^PAPERLESS_TOKEN=.*/PAPERLESS_TOKEN=/' "$ENV_FILE"
    run_intake --once
    assert_status 1
    assert_notified 'Config error'
}

@test ".env with mode 644: refuses to run" {
    chmod 644 "$ENV_FILE"
    run_intake --once
    assert_status 1
}

@test ".env with mode 644: notification says how to fix it (chmod 600)" {
    chmod 644 "$ENV_FILE"
    run_intake --once
    assert_notified 'chmod 600'
}

@test ".env with mode 644: nothing is uploaded and the scan stays in outbox" {
    make_scan "20261021091350.pdf"
    chmod 644 "$ENV_FILE"
    run_intake --once
    assert_status 1
    [[ "$(curl_calls post_document)" -eq 0 ]]
    assert_in outbox "20261021091350.pdf"
}

@test ".env is parsed, not sourced: command substitution is not executed" {
    write_env 'NOTIFY_SUCCESS=$(touch "$HOME/pwned-subst")' 'LAN_FALLBACK_URL=`touch "$HOME/pwned-backtick"`'
    run_intake --once
    assert_log 'run_start'
    [[ ! -e "$HOME/pwned-subst" ]]
    [[ ! -e "$HOME/pwned-backtick" ]]
}

@test ".env is parsed, not sourced: a bare command line is not executed" {
    write_env "touch $HOME/pwned-bare"
    run_intake --once
    assert_log 'run_start'
    [[ ! -e "$HOME/pwned-bare" ]]
}

@test ".env keys outside the whitelist are ignored (PATH cannot be overridden)" {
    write_env "PATH=/nonexistent"
    run_intake --selftest
    assert_status 0
}

@test ".env comments and blank lines are accepted" {
    write_env "# a comment" "" "   # indented comment"
    run_intake --once
    assert_status 0
}

# Phase 10.5 changed this contract: SCAN_ROOT is no longer a .env key, because
# install.sh and the LaunchAgent always use ~/Scans.
@test ".env SCAN_ROOT is ignored: ~/Scans is always used" {
    write_env "SCAN_ROOT=$HOME/OtherScans"
    make_scan "a.pdf"
    run_intake --once
    assert_status 0
    assert_in done "a.pdf"
    [[ ! -e "$HOME/OtherScans" ]]
}

@test "first run creates outbox, pending, done, duplicates and failed" {
    run_intake --once
    for d in outbox pending done duplicates failed; do
        [[ -d "$SCANS/$d" ]] || { echo "missing $d/"; return 1; }
    done
}

@test "no flag behaves like --once" {
    run_intake
    assert_status 0
    assert_log 'run_start'
}

# ── phase 7.3: only API version 9 works with the task API used here ─────────

@test "API_VERSION=10: exits 1 with a config_error naming API_VERSION" {
    write_env "API_VERSION=10"
    make_scan "a.pdf"
    run_intake --once
    assert_status 1
    assert_log 'ERROR +config_error reason=".*API_VERSION must be 9'
}

@test "API_VERSION=10: Config error notification, nothing uploaded, scan stays in outbox" {
    write_env "API_VERSION=10"
    make_scan "a.pdf"
    run_intake --once
    assert_notified 'Config error'
    [[ "$(curl_calls post_document)" -eq 0 ]]
    assert_in outbox "a.pdf"
}

@test "NON-REGRESSION: API_VERSION=9 set explicitly is accepted" {
    write_env "API_VERSION=9"
    make_scan "a.pdf"
    run_intake --once
    assert_status 0
    assert_in done "a.pdf"
}
