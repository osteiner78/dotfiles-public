#!/usr/bin/env bats
# Phase 2 — polling the task and filing the local copy.

load helpers

UUID="b1ad602d-0000-4000-8000-000000000001"

@test "SUCCESS: file moves to done/" {
    make_scan "20261021091350.pdf"
    run_intake --once
    assert_in done "20261021091350.pdf"
    refute_in outbox "20261021091350.pdf"
}

@test "SUCCESS: logs uploaded (task, via=public) and success (doc id)" {
    make_scan "20261021091350.pdf"
    run_intake --once
    assert_log "INFO +uploaded file=\"20261021091350.pdf\" task=$UUID via=public"
    assert_log 'INFO +success file="20261021091350.pdf" doc=6342'
}

@test "polls /api/tasks/?task_id=<uuid>" {
    make_scan "20261021091350.pdf"
    run_intake --once
    grep -q "URL=https://paperless.test/api/tasks/?task_id=$UUID" "$STUB_LOG/curl.log"
}

@test "FAILURE with duplicate_documents: file moves to duplicates/" {
    stub_task FAILURE '"result": "Not consuming 20261021091350.pdf: It is a duplicate.", "duplicate_documents": [{"id": 5120, "title": "Old letter"}]'
    make_scan "20261021091350.pdf"
    run_intake --once
    assert_in duplicates "20261021091350.pdf"
}

@test "FAILURE with duplicate_documents: logs WARN duplicate with the existing id" {
    stub_task FAILURE '"result": "It is a duplicate.", "duplicate_documents": [{"id": 5120, "title": "Old letter"}]'
    make_scan "old.pdf"
    run_intake --once
    assert_log 'WARN +duplicate file="old.pdf" existing=5120'
}

@test "FAILURE whose result mentions 'Duplicate' (no duplicate_documents): duplicates/" {
    stub_task FAILURE '"result": "Not consuming old.pdf: Duplicate of Old letter (#5120)", "duplicate_documents": []'
    make_scan "old.pdf"
    run_intake --once
    assert_in duplicates "old.pdf"
}

@test "other FAILURE: file moves to failed/ with a .error file holding the result" {
    stub_task FAILURE '"result": "Error while consuming x.pdf: OCR failed\nTraceback ...", "duplicate_documents": []'
    make_scan "x.pdf"
    run_intake --once
    assert_in failed "x.pdf"
    grep -q 'OCR failed' "$SCANS/failed/x.pdf.error"
}

@test "other FAILURE: run still exits 0" {
    stub_task FAILURE '"result": "OCR failed", "duplicate_documents": []'
    make_scan "x.pdf"
    run_intake --once
    assert_status 0
}

@test "task not finished within POLL_TIMEOUT: file and .task move to pending/" {
    write_env "POLL_INTERVAL=1" "POLL_TIMEOUT=2"
    stub_task STARTED '"result": null'
    make_scan "slow.pdf"
    run_intake --once
    assert_in pending "slow.pdf"
    grep -q "$UUID" "$SCANS/pending/slow.pdf.task"
}

@test "task not finished within POLL_TIMEOUT: logged as pending" {
    write_env "POLL_INTERVAL=1" "POLL_TIMEOUT=2"
    stub_task STARTED '"result": null'
    make_scan "slow.pdf"
    run_intake --once
    assert_log "pending file=\"slow.pdf\" task=$UUID"
}

@test "running twice uploads each file only once" {
    make_scan "20261021091350.pdf"
    run_intake --once
    run_intake --once
    [[ "$(curl_calls post_document)" -eq 1 ]]
}
