#!/usr/bin/env bats
# Phase 9.3 — `scan-intake health`: selftest + stuck files + agent loaded.
# Silent when everything is fine; one notification when something is wrong.

load helpers

put_failed() { # name
    mkdir -p "$SCANS/failed"
    printf '%%PDF-1.4\n' >"$SCANS/failed/$1"
    echo "HTTP 500" >"$SCANS/failed/$1.error"
}

run_health() { run "$SCRIPT" health; }

@test "all OK: exit 0, no notification, logs INFO health ok" {
    run_health
    assert_status 0
    [[ "$(notification_count)" -eq 0 ]]
    assert_log 'INFO +health ok'
}

@test "all OK: the selftest's per-check lines are not printed" {
    run_health
    assert_status 0
    [[ "$output" != *"ok    "* ]]
}

@test "a file in failed/: exit 1, one Health check notification with Basso" {
    put_failed "x.pdf"
    run_health
    assert_status 1
    [[ "$(notification_count)" -eq 1 ]]
    assert_notified 'subtitle "Health check"'
    assert_notified 'sound name "Basso"'
    assert_notified 'failed'
}

@test "a file in failed/: logs WARN health problems=1" {
    put_failed "x.pdf"
    run_health
    assert_log 'WARN +health problems=1'
}

@test "an outbox file older than 1 h is a problem" {
    make_scan "stuck.pdf" -2H
    run_health
    assert_status 1
    assert_notified 'outbox'
}

@test "a fresh outbox file is not a problem" {
    make_scan "new.pdf"
    run_health
    assert_status 0
    [[ "$(notification_count)" -eq 0 ]]
}

@test "health never uploads or moves outbox files" {
    make_scan "stuck.pdf" -2H
    run_health
    assert_status 1
    [[ "$(curl_calls post_document)" -eq 0 ]]
    assert_in outbox "stuck.pdf"
}

@test "main agent not loaded is a problem" {
    touch "$FIXTURES/launchctl.fail"
    run_health
    assert_status 1
    assert_notified 'not loaded'
    grep -q "print gui/$(id -u)/xyz.osteiner.scan-intake" "$STUB_LOG/launchctl.log"
}

@test "a failing selftest check (token rejected) is a problem" {
    stub_http "$PUBLIC_HOST" tags 401 '{"detail": "Invalid token."}'
    run_health
    assert_status 1
    assert_notified '401'
}

@test "an invalid .env is reported in the one health notification" {
    chmod 644 "$ENV_FILE"
    run_health
    assert_status 1
    [[ "$(notification_count)" -eq 1 ]]
    assert_notified 'subtitle "Health check"'
    assert_notified 'chmod 600'
}

@test "two problems: still one notification, problems=2" {
    put_failed "x.pdf"
    make_scan "stuck.pdf" -2H
    run_health
    assert_status 1
    [[ "$(notification_count)" -eq 1 ]]
    assert_log 'WARN +health problems=2'
}

@test "with terminal-notifier: a failed/ problem opens failed/ on click" {
    use_terminal_notifier
    put_failed "x.pdf"
    run_health
    [[ "$(tn_arg -subtitle)" == "Health check" ]]
    [[ "$(tn_arg -sound)" == "Basso" ]]
    [[ "$(tn_arg -open)" =~ ^file://$SCANS/failed/?$ ]]
}

@test "with terminal-notifier: other problems open the log on click" {
    use_terminal_notifier
    touch "$FIXTURES/launchctl.fail"
    run_health
    [[ "$(tn_arg -open)" == "file://$LOG" ]]
}
