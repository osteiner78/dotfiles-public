#!/usr/bin/env bats
# Phase 2 — the upload request: endpoint, headers, filename handling, secrecy.

load helpers

post_args() { grep 'post_document' "$STUB_LOG/curl.log"; }

@test "uploads to the public post_document endpoint" {
    make_scan "20261021091350.pdf"
    run_intake --once
    grep -q 'URL=https://paperless.test/api/documents/post_document/' "$STUB_LOG/curl.log"
}

@test "ScanSnap-style name is uploaded with the neutral filename scan.pdf" {
    make_scan "20261021091350.pdf"
    run_intake --once
    post_args | grep -q 'filename=scan.pdf'
}

@test "neutral filename keeps the real extension (jpg -> scan.jpg)" {
    make_scan "20261021091350.jpg"
    run_intake --once
    post_args | grep -q 'filename=scan.jpg'
}

@test "neutral upload sets the title 'Scan YYYY-MM-DD HH.MM'" {
    make_scan "20261021091350.pdf"
    run_intake --once
    post_args | grep -Eq 'title=Scan [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}\.[0-9]{2}'
}

@test "deliberately dated name 'YYYY-MM-DD - Title.pdf' is uploaded under its own name" {
    make_scan "2026-01-15 - Test.pdf"
    run_intake --once
    post_args | grep -q '2026-01-15 - Test.pdf'
    ! post_args | grep -q 'filename=scan'
}

# Real curl splits an unquoted -F value on ';' and ',' and fails with exit 26.
@test "dated name with ';' and ',' is sent as a quoted filename" {
    make_scan "2026-01-15 - A; B, C.pdf"
    run_intake --once
    post_args | grep -qF 'filename="2026-01-15 - A; B, C.pdf"'
}

@test "path with ';' is sent as a quoted document path" {
    make_scan "Brief; Mai.pdf"
    run_intake --once
    post_args | grep -qF "document=@\"$SCANS/outbox/Brief; Mai.pdf\""
}

@test "double quote in a dated name is backslash-escaped inside the quoted filename" {
    make_scan '2026-01-15 - "Q".pdf'
    run_intake --once
    post_args | grep -qF 'filename="2026-01-15 - \"Q\".pdf"'
}

@test "date without ' - ' separator is not treated as deliberate (neutral filename)" {
    make_scan "2026-01-15Test.pdf"
    run_intake --once
    post_args | grep -q 'filename=scan.pdf'
}

@test "no tags, correspondent or document_type are sent" {
    make_scan "20261021091350.pdf"
    run_intake --once
    [[ "$(curl_calls post_document)" -eq 1 ]]
    ! post_args | grep -Eq 'tags=|correspondent=|document_type='
}

@test "token never appears in curl argv (visible in ps)" {
    make_scan "20261021091350.pdf"
    run_intake --once
    [[ -s "$STUB_LOG/curl.log" ]]
    ! grep -q "$TOKEN" "$STUB_LOG/curl.log"
}

@test "token is sent as an Authorization header on stdin" {
    make_scan "20261021091350.pdf"
    run_intake --once
    grep -q "Authorization: Token $TOKEN" "$STUB_LOG/curl.stdin"
}

@test "token never appears in the log" {
    make_scan "20261021091350.pdf"
    run_intake --once --verbose
    [[ -s "$LOG" ]]
    ! grep -q "$TOKEN" "$LOG"
}

@test "upload uses --fail-with-body, --connect-timeout 10 and --max-time 600" {
    make_scan "20261021091350.pdf"
    run_intake --once
    local args
    args="$(post_args | tr '\037' ' ')"
    [[ "$args" == *"--fail-with-body"* ]]
    [[ "$args" == *"--connect-timeout 10"* ]]
    [[ "$args" == *"--max-time 600"* ]]
}

@test "--verbose adds DEBUG lines" {
    make_scan "20261021091350.pdf"
    run_intake --once --verbose
    assert_log ' DEBUG '
}

@test "without --verbose there are no DEBUG lines" {
    make_scan "20261021091350.pdf"
    run_intake --once
    [[ -s "$LOG" ]]
    refute_log ' DEBUG '
}
