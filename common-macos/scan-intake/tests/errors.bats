#!/usr/bin/env bats
# Phase 3 — HTTP errors from post_document.

load helpers

@test "401: file stays in outbox" {
    stub_http "$PUBLIC_HOST" post_document 401 '{"detail": "Invalid token."}'
    make_scan "a.pdf"
    run_intake --once
    [[ "$(curl_calls post_document)" -eq 1 ]]
    assert_in outbox "a.pdf"
}

@test "401: 'Config error' notification about the token" {
    stub_http "$PUBLIC_HOST" post_document 401 '{"detail": "Invalid token."}'
    make_scan "a.pdf"
    run_intake --once
    assert_notified 'Config error'
    assert_notified '[Tt]oken'
}

@test "401: exits 1 (treated as a config error)" {
    stub_http "$PUBLIC_HOST" post_document 401 '{"detail": "Invalid token."}'
    make_scan "a.pdf"
    run_intake --once
    assert_status 1
}

@test "401: stops the run after the first file" {
    stub_http "$PUBLIC_HOST" post_document 401 '{"detail": "Invalid token."}'
    make_scan "a.pdf"
    make_scan "b.pdf"
    run_intake --once
    [[ "$(curl_calls post_document)" -eq 1 ]]
}

@test "403: file stays in outbox and the run stops" {
    stub_http "$PUBLIC_HOST" post_document 403 '{"detail": "Forbidden."}'
    make_scan "a.pdf"
    make_scan "b.pdf"
    run_intake --once
    assert_in outbox "a.pdf"
    [[ "$(curl_calls post_document)" -eq 1 ]]
}

@test "413: file moves to failed/ with 'too large for reverse proxy' in .error" {
    stub_http "$PUBLIC_HOST" post_document 413 '<html>413 Request Entity Too Large</html>'
    make_scan "big.pdf"
    run_intake --once
    assert_in failed "big.pdf"
    grep -q 'too large for reverse proxy' "$SCANS/failed/big.pdf.error"
}

@test "413: Error notification 'too large for the reverse proxy' with Basso" {
    stub_http "$PUBLIC_HOST" post_document 413 ''
    make_scan "big.pdf"
    run_intake --once
    assert_notified 'too large for the reverse proxy'
    assert_notified 'sound name "Basso"'
}

@test "413: logged as ERROR failed with http=413" {
    stub_http "$PUBLIC_HOST" post_document 413 ''
    make_scan "big.pdf"
    run_intake --once
    assert_log 'ERROR +failed file="big.pdf" http=413'
}

@test "500: file moves to failed/ and .error holds the response body" {
    stub_http "$PUBLIC_HOST" post_document 500 'Internal Server Error: disk full'
    make_scan "a.pdf"
    run_intake --once
    assert_in failed "a.pdf"
    grep -q 'disk full' "$SCANS/failed/a.pdf.error"
}

@test "500 on one file does not stop the others" {
    stub_http "$PUBLIC_HOST" post_document 500 'boom'
    make_scan "a.pdf"
    make_scan "b.pdf"
    run_intake --once
    assert_status 0
    [[ "$(curl_calls post_document)" -eq 2 ]]
}

# ── phase 7.3: a rejected token is logged as "rejected", not "failed" ──────

@test "401: logged as ERROR rejected with http=401, not as failed" {
    stub_http "$PUBLIC_HOST" post_document 401 '{"detail": "Invalid token."}'
    make_scan "a.pdf"
    run_intake --once
    assert_log 'ERROR +rejected file="a.pdf" http=401'
    refute_log 'failed file="a.pdf"'
}

@test "403: logged as ERROR rejected with http=403" {
    stub_http "$PUBLIC_HOST" post_document 403 '{"detail": "Forbidden."}'
    make_scan "a.pdf"
    run_intake --once
    assert_log 'ERROR +rejected file="a.pdf" http=403'
    refute_log 'failed file="a.pdf"'
}

# ── phase 10.2: no final answer → WARN upload_error, file stays in outbox ──

@test "curl error without an HTTP answer (35): stays in outbox, WARN upload_error, no notification" {
    stub_transport_error "$PUBLIC_HOST" post_document 35
    make_scan "a.pdf"
    run_intake --once
    assert_status 0
    assert_in outbox "a.pdf"
    assert_log 'WARN +upload_error file="a.pdf" reason="curl exit 35'
    refute_log 'failed file="a.pdf"'
    [[ "$(notification_count)" -eq 0 ]]
}

@test "no task id in the response: stays in outbox, WARN upload_error" {
    stub_http "$PUBLIC_HOST" post_document 200 '{}'
    make_scan "a.pdf"
    run_intake --once
    assert_status 0
    assert_in outbox "a.pdf"
    assert_log 'WARN +upload_error file="a.pdf" reason="no task id in response"'
    refute_log 'failed file="a.pdf"'
}

@test "NON-REGRESSION: 500 still logs ERROR failed and moves to failed/" {
    stub_http "$PUBLIC_HOST" post_document 500 'boom'
    make_scan "a.pdf"
    run_intake --once
    assert_in failed "a.pdf"
    assert_log 'ERROR +failed file="a.pdf" http=500'
}
