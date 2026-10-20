#!/usr/bin/env bats
# Phase 3 — transport errors (curl exit 6 resolve, 7 connect, 28 timeout) and
# the optional LAN fallback.

load helpers

@test "connect error, no fallback: file stays in outbox and run exits 0" {
    stub_transport_error "$PUBLIC_HOST" post_document 7
    make_scan "a.pdf"
    run_intake --once
    assert_status 0
    assert_in outbox "a.pdf"
}

@test "resolve (6) and timeout (28) errors also leave the file in outbox" {
    for code in 6 28; do
        stub_transport_error "$PUBLIC_HOST" post_document "$code"
        make_scan "a$code.pdf"
        run_intake --once
        assert_in outbox "a$code.pdf"
    done
    # a6.pdf is retried by the second run, hence 3 attempts.
    [[ "$(curl_calls post_document)" -eq 3 ]]
}

@test "connect error: logged as network_error with the curl exit code" {
    stub_transport_error "$PUBLIC_HOST" post_document 7
    make_scan "a.pdf"
    run_intake --once
    assert_log 'network_error file="a.pdf" curl=7'
}

@test "connect error on a fresh file: no notification" {
    stub_transport_error "$PUBLIC_HOST" post_document 7
    make_scan "a.pdf"
    run_intake --once
    [[ "$(curl_calls post_document)" -eq 1 ]]
    [[ "$(notification_count)" -eq 0 ]]
}

@test "files waiting more than 1 h: one 'Waiting' notification per run with the count" {
    stub_transport_error "$PUBLIC_HOST" post_document 7
    make_scan "a.pdf" -2H
    make_scan "b.pdf" -2H
    run_intake --once
    [[ "$(notification_count)" -eq 1 ]]
    assert_notified 'Waiting'
    assert_notified '2 scans queued'
}

@test "LAN fallback: used when the public URL has a connect error" {
    write_env "LAN_FALLBACK_URL=http://$LAN_HOST:8000"
    stub_transport_error "$PUBLIC_HOST" post_document 7
    stub_upload_ok "b1ad602d-0000-4000-8000-000000000001" "$LAN_HOST"
    stub_task SUCCESS '"related_document": 6342' "$LAN_HOST"
    make_scan "a.pdf"
    run_intake --once
    assert_in done "a.pdf"
    assert_log 'uploaded file="a.pdf" .*via=lan'
}

@test "LAN fallback: the task is polled on the LAN host it was uploaded to" {
    write_env "LAN_FALLBACK_URL=http://$LAN_HOST:8000"
    stub_transport_error "$PUBLIC_HOST" post_document 7
    stub_transport_error "$PUBLIC_HOST" tasks 7
    stub_upload_ok "b1ad602d-0000-4000-8000-000000000001" "$LAN_HOST"
    stub_task SUCCESS '"related_document": 6342' "$LAN_HOST"
    make_scan "a.pdf"
    run_intake --once
    grep -q "URL=http://$LAN_HOST:8000/api/tasks/" "$STUB_LOG/curl.log"
}

@test "LAN fallback: not used for HTTP errors (500 goes to failed/)" {
    write_env "LAN_FALLBACK_URL=http://$LAN_HOST:8000"
    stub_http "$PUBLIC_HOST" post_document 500 'boom'
    make_scan "a.pdf"
    run_intake --once
    assert_in failed "a.pdf"
    ! grep -q "URL=http://$LAN_HOST" "$STUB_LOG/curl.log"
}

@test "LAN fallback empty (default): the LAN host is never contacted" {
    stub_transport_error "$PUBLIC_HOST" post_document 7
    make_scan "a.pdf"
    run_intake --once
    [[ "$(curl_calls post_document)" -eq 1 ]]
    ! grep -q "$LAN_HOST" "$STUB_LOG/curl.log"
}
