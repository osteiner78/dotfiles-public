#!/usr/bin/env bats
# Phase 2 — macOS notifications (osascript is stubbed and only recorded).

load helpers

@test "success: 'Uploaded' notification titled 'Scan intake' with file name and document id" {
    make_scan "20261021091350.pdf"
    run_intake --once
    assert_notified 'Scan intake'
    assert_notified 'Uploaded'
    assert_notified '20261021091350\.pdf.*#6342'
}

@test "success: no error sound" {
    make_scan "20261021091350.pdf"
    run_intake --once
    [[ "$(notification_count)" -eq 1 ]]
    refute_notified 'Basso'
}

@test "NOTIFY_SUCCESS=false: no notification on success" {
    write_env "NOTIFY_SUCCESS=false"
    make_scan "20261021091350.pdf"
    run_intake --once
    assert_in done "20261021091350.pdf"
    [[ "$(notification_count)" -eq 0 ]]
}

@test "duplicate: 'Duplicate, skipped' notification with the existing id" {
    stub_task FAILURE '"result": "It is a duplicate.", "duplicate_documents": [{"id": 5120, "title": "Old letter"}]'
    make_scan "old.pdf"
    run_intake --once
    assert_notified 'Duplicate, skipped'
    assert_notified '5120'
}

@test "processing failure: 'Error' notification with the first line of the message and Basso sound" {
    stub_task FAILURE '"result": "OCR failed on page 2\nTraceback (most recent call last)", "duplicate_documents": []'
    make_scan "x.pdf"
    run_intake --once
    assert_notified 'subtitle "Error"'
    assert_notified 'OCR failed on page 2'
    refute_notified 'Traceback'
    assert_notified 'sound name "Basso"'
}

@test "double quotes in the file name are escaped for AppleScript" {
    make_scan 'Rechnung "Mai".pdf'
    run_intake --once
    assert_notified 'Rechnung \\"Mai\\"\.pdf'
}

@test "five files: five individual notifications" {
    for i in 1 2 3 4 5; do make_scan "scan$i.pdf"; done
    run_intake --once
    [[ "$(notification_count)" -eq 5 ]]
}

@test "seven files: one summary notification instead of seven" {
    for i in 1 2 3 4 5 6 7; do make_scan "scan$i.pdf"; done
    run_intake --once
    [[ "$(notification_count)" -eq 1 ]]
    assert_notified '7 scans uploaded'
}

@test "seven files: the log still has all seven success lines" {
    for i in 1 2 3 4 5 6 7; do make_scan "scan$i.pdf"; done
    run_intake --once
    [[ "$(grep -c ' success ' "$LOG")" -eq 7 ]]
}
