#!/usr/bin/env bats
# Phase 1 — `scan-intake --selftest`.

load helpers

@test "selftest: valid config and reachable server pass with exit 0" {
    run_intake --selftest
    assert_status 0
}

@test "selftest: queries GET /api/tags/?page_size=1" {
    run_intake --selftest
    grep -q 'URL=https://paperless.test/api/tags/?page_size=1' "$STUB_LOG/curl.log"
}

@test "selftest: sends the API version in the Accept header" {
    run_intake --selftest
    cat "$STUB_LOG/curl.log" "$STUB_LOG/curl.stdin" | grep -q 'Accept: application/json; version=9'
}

@test "selftest: API_VERSION from .env is used in the Accept header" {
    write_env "API_VERSION=10"
    run_intake --selftest
    cat "$STUB_LOG/curl.log" "$STUB_LOG/curl.stdin" | grep -q 'Accept: application/json; version=10'
}

@test "selftest: token rejected (401) fails with exit 1" {
    stub_http "$PUBLIC_HOST" tags 401 '{"detail": "Invalid token."}'
    run_intake --selftest
    assert_status 1
}

@test "selftest: .env with mode 644 fails" {
    chmod 644 "$ENV_FILE"
    run_intake --selftest
    assert_status 1
}

@test "selftest: .env inside a git working tree fails and says so" {
    git -C "$HOME" init -q
    run_intake --selftest
    assert_status 1
    [[ "$output" == *git* ]]
}

@test "selftest: a non-writable scan folder fails" {
    mkdir -p "$SCANS"/{outbox,pending,done,duplicates,failed}
    chmod 555 "$SCANS/done"
    run_intake --selftest
    chmod 755 "$SCANS/done"
    assert_status 1
}

@test "selftest: never uploads anything" {
    make_scan "20261021091350.pdf"
    run_intake --selftest
    assert_status 0
    [[ "$(curl_calls post_document)" -eq 0 ]]
    assert_in outbox "20261021091350.pdf"
}

@test "selftest: prints a summary" {
    run_intake --selftest
    assert_status 0
    [[ -n "$output" ]]
}

# ── phase 7.3 ───────────────────────────────────────────────────────────────

@test "selftest: API_VERSION=10 fails and names the problem" {
    write_env "API_VERSION=10"
    run_intake --selftest
    assert_status 1
    [[ "$output" == *"API_VERSION must be 9"* ]]
}
