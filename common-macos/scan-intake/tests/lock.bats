#!/usr/bin/env bats
# Phase 8.1 — a lock in $SCAN_ROOT/.lock keeps two --once runs from uploading
# the same file.

load helpers

LOCK_HOLDER=

teardown() {
    [[ -n "$LOCK_HOLDER" ]] && kill "$LOCK_HOLDER" 2>/dev/null
    return 0
}

hold_lock() { # a live scan-intake run owns the lock (its command line says so)
    bash -c 'exec -a scan-intake-holder sleep 30' >/dev/null 2>&1 3>&- &
    LOCK_HOLDER=$!
    mkdir -p "$SCANS/.lock"
    echo "$LOCK_HOLDER" >"$SCANS/.lock/pid"
}

foreign_lock() { # the lock's pid is alive but reused by an unrelated process
    sleep 30 >/dev/null 2>&1 3>&- &
    LOCK_HOLDER=$!
    mkdir -p "$SCANS/.lock"
    echo "$LOCK_HOLDER" >"$SCANS/.lock/pid"
}

stale_lock() { # the lock's owner is gone
    local dead
    (exit 0) &
    dead=$!
    wait "$dead"
    mkdir -p "$SCANS/.lock"
    echo "$dead" >"$SCANS/.lock/pid"
}

record_lock_during_upload() {
    on_upload "cat \"\$HOME/Scans/.lock/pid\" >\"\$STUB_LOG/lock-pid\" 2>/dev/null || echo none >\"\$STUB_LOG/lock-pid\""
}

@test "lock held by a live run: no upload, file stays, exit 0" {
    hold_lock
    make_scan "a.pdf"
    run_intake --once
    assert_status 0
    [[ "$(curl_calls post_document)" -eq 0 ]]
    assert_in outbox "a.pdf"
}

@test "lock held by a live run: logs INFO skipped" {
    hold_lock
    make_scan "a.pdf"
    run_intake --once
    assert_log 'INFO +skipped reason="another run in progress"'
}

@test "NON-REGRESSION: lock held by a live run: the other run's lock is left alone" {
    hold_lock
    run_intake --once
    [[ "$(cat "$SCANS/.lock/pid")" == "$LOCK_HOLDER" ]]
}

@test "stale lock (owner gone): taken over, file uploaded, WARN stale_lock" {
    stale_lock
    make_scan "a.pdf"
    run_intake --once
    assert_status 0
    assert_in done "a.pdf"
    assert_log 'WARN +stale_lock'
}

@test "lock directory without a pid file counts as stale" {
    mkdir -p "$SCANS/.lock"
    make_scan "a.pdf"
    run_intake --once
    assert_in done "a.pdf"
    assert_log 'WARN +stale_lock'
}

@test "the lock is held during the upload and removed after a normal run" {
    make_scan "a.pdf"
    record_lock_during_upload
    run_intake --once
    assert_status 0
    [[ "$(cat "$STUB_LOG/lock-pid")" =~ ^[0-9]+$ ]]
    [[ ! -e "$SCANS/.lock" ]]
}

@test "the lock is removed after a run that stops on 401" {
    stub_http "$PUBLIC_HOST" post_document 401 '{"detail": "Invalid token."}'
    make_scan "a.pdf"
    record_lock_during_upload
    run_intake --once
    assert_status 1
    [[ "$(cat "$STUB_LOG/lock-pid")" =~ ^[0-9]+$ ]]
    [[ ! -e "$SCANS/.lock" ]]
}

@test "NON-REGRESSION: --selftest runs while a lock is held" {
    hold_lock
    run_intake --selftest
    assert_status 0
}

@test "NON-REGRESSION: --dry-run runs while a lock is held" {
    hold_lock
    make_scan "a.pdf"
    run_intake --dry-run
    assert_status 0
    [[ "$output" == "would upload a.pdf" ]]
}

# ── phase 10.4: the lock survives a reboot, and pids are reused after one ───

@test "lock pid alive but not scan-intake (reused after a crash): stale, taken over" {
    foreign_lock
    make_scan "a.pdf"
    run_intake --once
    assert_status 0
    assert_in done "a.pdf"
    assert_log 'WARN +stale_lock'
    refute_log 'skipped'
}

@test "NON-REGRESSION: the test holder really looks like scan-intake to ps" {
    hold_lock
    sleep 0.2
    [[ "$(ps -p "$LOCK_HOLDER" -o command=)" == *scan-intake* ]]
}
