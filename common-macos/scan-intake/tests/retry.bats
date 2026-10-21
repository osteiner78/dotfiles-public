#!/usr/bin/env bats
# Phase 8.3 — `scan-intake retry <file|all>` moves files from failed/ back to
# outbox. It never uploads; the LaunchAgent picks them up.

load helpers

put_failed() { # name [error]
    mkdir -p "$SCANS/failed"
    printf '%%PDF-1.4\n%% %s\n' "$1" >"$SCANS/failed/$1"
    printf '%s\n' "${2:-HTTP 500}" >"$SCANS/failed/$1.error"
}

@test "retry <file>: moves it to outbox and deletes its .error" {
    put_failed "x.pdf"
    run "$SCRIPT" retry x.pdf
    assert_status 0
    assert_in outbox "x.pdf"
    refute_in failed "x.pdf"
    refute_in failed "x.pdf.error"
}

@test "retry <file>: prints 'requeued <file>' and logs INFO requeued" {
    put_failed "x.pdf"
    run "$SCRIPT" retry x.pdf
    [[ "$output" == "requeued x.pdf" ]]
    assert_log 'INFO +requeued file="x.pdf"'
}

@test "retry <file>: leaves the other failed files alone" {
    put_failed "x.pdf"
    put_failed "y.pdf"
    run "$SCRIPT" retry x.pdf
    assert_status 0
    assert_in failed "y.pdf"
    assert_in failed "y.pdf.error"
}

@test "retry all: moves every failed file and removes every .error" {
    put_failed "x.pdf"
    put_failed "y.pdf"
    run "$SCRIPT" retry all
    assert_status 0
    assert_in outbox "x.pdf"
    assert_in outbox "y.pdf"
    [[ -z "$(find "$SCANS/failed" -type f)" ]]
    [[ ! -e "$SCANS/outbox/x.pdf.error" ]]
}

@test "retry all with nothing in failed/: 'nothing to retry', exit 0" {
    mkdir -p "$SCANS/failed"
    run "$SCRIPT" retry all
    assert_status 0
    [[ "$output" == "nothing to retry" ]]
}

@test "retry of an unknown file: exit 2, nothing moved" {
    put_failed "x.pdf"
    run "$SCRIPT" retry nope.pdf
    assert_status 2
    [[ "$output" == *"nope.pdf"* ]]
    assert_in failed "x.pdf"
}

@test "retry without an argument: exit 2 with a usage line naming retry" {
    run "$SCRIPT" retry
    assert_status 2
    [[ "$output" == *"retry <file|all>"* ]]
}

@test "retry of a .error file: exit 2, nothing moved" {
    put_failed "x.pdf"
    run "$SCRIPT" retry x.pdf.error
    assert_status 2
    [[ "$output" == *"x.pdf.error"* ]]
    assert_in failed "x.pdf.error"
    refute_in outbox "x.pdf.error"
}

@test "retry with a path outside failed/: exit 2, nothing moved" {
    mkdir -p "$SCANS/done"
    printf '%%PDF-1.4\n' >"$SCANS/done/z.pdf"
    mkdir -p "$SCANS/failed"
    run "$SCRIPT" retry ../done/z.pdf
    assert_status 2
    [[ "$output" == *"z.pdf"* ]]
    assert_in done "z.pdf"
    refute_in outbox "z.pdf"
}

@test "retry never touches duplicates/" {
    mkdir -p "$SCANS/duplicates" "$SCANS/failed"
    printf '%%PDF-1.4\n' >"$SCANS/duplicates/d.pdf"
    run "$SCRIPT" retry d.pdf
    assert_status 2
    [[ "$output" == *"d.pdf"* ]]
    assert_in duplicates "d.pdf"
}

@test "retry makes no network calls" {
    put_failed "x.pdf"
    run "$SCRIPT" retry all
    assert_status 0
    [[ ! -s "$STUB_LOG/curl.log" ]]
}

@test "retry handles spaces and double quotes in the name" {
    put_failed 'Rechnung "Mai" 2026.pdf'
    run "$SCRIPT" retry 'Rechnung "Mai" 2026.pdf'
    assert_status 0
    assert_in outbox 'Rechnung "Mai" 2026.pdf'
    refute_in failed 'Rechnung "Mai" 2026.pdf.error'
}

@test "retry when the name already exists in outbox: both files kept" {
    put_failed "x.pdf"
    mkdir -p "$SCANS/outbox"
    echo "newer scan" >"$SCANS/outbox/x.pdf"
    run "$SCRIPT" retry x.pdf
    assert_status 0
    [[ "$(cat "$SCANS/outbox/x.pdf")" == "newer scan" ]]
    [[ "$(find "$SCANS/outbox" -name '*-x.pdf' | wc -l)" -eq 1 ]]
    refute_in failed "x.pdf"
}

# ── phase 10.5: ~/Scans is the only root, even with a broken .env ──────────

@test "NON-REGRESSION: retry works with an invalid .env (mode 644): uses ~/Scans" {
    put_failed "x.pdf"
    chmod 644 "$ENV_FILE"
    run "$SCRIPT" retry x.pdf
    assert_status 0
    assert_in outbox "x.pdf"
}

@test "retry ignores SCAN_ROOT in .env" {
    write_env "SCAN_ROOT=$HOME/Other"
    put_failed "x.pdf"
    run "$SCRIPT" retry x.pdf
    assert_status 0
    assert_in outbox "x.pdf"
}
