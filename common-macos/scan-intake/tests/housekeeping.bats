#!/usr/bin/env bats
# Phase 3 — done/ retention, log rotation and --dry-run.

load helpers

make_done() { # name age
    mkdir -p "$SCANS/done"
    printf '%%PDF-1.4\n' >"$SCANS/done/$1"
    backdate "$SCANS/done/$1" "$2"
}

@test "done/ file older than 180 days is deleted" {
    make_done "old.pdf" -181d
    run_intake --once
    refute_in done "old.pdf"
}

@test "done/ deletion is logged" {
    make_done "old.pdf" -181d
    run_intake --once
    assert_log 'deleted file="old.pdf"'
}

@test "done/ file younger than 180 days is kept (while an older one is deleted)" {
    make_done "recent.pdf" -179d
    make_done "old.pdf" -181d
    run_intake --once
    refute_in done "old.pdf"
    assert_in done "recent.pdf"
}

@test "DONE_RETENTION_DAYS from .env overrides 180" {
    write_env "DONE_RETENTION_DAYS=30"
    make_done "month.pdf" -31d
    run_intake --once
    refute_in done "month.pdf"
}

@test "log larger than 5 MB is rotated to scan-intake.log.1" {
    mkdir -p "$(dirname "$LOG")"
    head -c 5242881 /dev/zero | tr '\0' 'x' >"$LOG"
    run_intake --once
    [[ -f "$LOG.1" ]]
    [[ ! -e "$LOG" || "$(wc -c <"$LOG")" -lt 5242880 ]]
}

@test "log rotation keeps 3 old logs" {
    mkdir -p "$(dirname "$LOG")"
    for n in 1 2 3; do echo "old $n" >"$LOG.$n"; done
    head -c 5242881 /dev/zero | tr '\0' 'x' >"$LOG"
    run_intake --once
    [[ ! -e "$LOG.4" ]]
    grep -q 'old 2' "$LOG.3"
}

@test "log smaller than 5 MB is not rotated" {
    run_intake --once
    [[ -s "$LOG" ]]
    [[ ! -e "$LOG.1" ]]
}

@test "--dry-run: nothing is uploaded and the scan stays in outbox" {
    make_scan "20261021091350.pdf"
    run_intake --dry-run
    assert_status 0
    [[ "$(curl_calls post_document)" -eq 0 ]]
    assert_in outbox "20261021091350.pdf"
}

@test "--dry-run: old done/ files are not deleted" {
    make_done "old.pdf" -181d
    run_intake --dry-run
    assert_status 0
    assert_in done "old.pdf"
}

@test "--dry-run: says what it would upload" {
    make_scan "20261021091350.pdf"
    run_intake --dry-run
    [[ "$output" == *"20261021091350.pdf"* ]]
}
