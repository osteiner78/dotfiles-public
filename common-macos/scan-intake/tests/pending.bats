#!/usr/bin/env bats
# Phase 3 — re-checking pending/ at the start of every run.

load helpers

UUID="b1ad602d-0000-4000-8000-000000000001"

make_pending() { # name [age-of-.task]
    mkdir -p "$SCANS/pending"
    printf '%%PDF-1.4\n' >"$SCANS/pending/$1"
    echo "$UUID" >"$SCANS/pending/$1.task"
    [[ -n "${2:-}" ]] && backdate "$SCANS/pending/$1.task" "$2"
    return 0
}

@test "pending task now SUCCESS: file moves to done/ and the .task file is removed" {
    make_pending "slow.pdf"
    run_intake --once
    assert_in done "slow.pdf"
    [[ ! -e "$SCANS/pending/slow.pdf.task" ]]
}

@test "pending task now a duplicate FAILURE: file moves to duplicates/" {
    stub_task FAILURE '"result": "It is a duplicate.", "duplicate_documents": [{"id": 5120}]'
    make_pending "slow.pdf"
    run_intake --once
    assert_in duplicates "slow.pdf"
}

@test "pending task still STARTED and fresh: file stays in pending/" {
    stub_task STARTED '"result": null'
    make_pending "slow.pdf"
    run_intake --once
    [[ "$(curl_calls tasks)" -ge 1 ]]
    assert_in pending "slow.pdf"
}

@test "pending task still STARTED after 24 h: failed/ with 'no result from paperless'" {
    stub_task STARTED '"result": null'
    make_pending "slow.pdf" -25H
    run_intake --once
    assert_in failed "slow.pdf"
    grep -q 'no result from paperless' "$SCANS/failed/slow.pdf.error"
}

@test "pending task still STARTED after 24 h: Error notification" {
    stub_task STARTED '"result": null'
    make_pending "slow.pdf" -25H
    run_intake --once
    assert_notified 'Error'
    assert_notified 'no result from paperless'
}

@test "pending files are counted in run_start" {
    stub_task STARTED '"result": null'
    make_pending "slow.pdf"
    run_intake --once
    assert_log 'run_start outbox=0 pending=1'
}

@test "a .task whose file has disappeared does not crash the run" {
    make_pending "gone.pdf"
    rm "$SCANS/pending/gone.pdf"
    run_intake --once
    assert_status 0
}
