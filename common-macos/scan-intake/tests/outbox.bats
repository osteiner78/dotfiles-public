#!/usr/bin/env bats
# Phase 2 — which files in outbox/ get picked up.

load helpers

@test "pdf, jpg, jpeg, png, tif and tiff are uploaded" {
    for ext in pdf jpg jpeg png tif tiff; do make_scan "scan.$ext"; done
    run_intake --once
    [[ "$(curl_calls post_document)" -eq 6 ]]
}

@test "other extensions (.txt) are left in outbox and not uploaded" {
    make_scan "notes.txt"
    make_scan "control.pdf"
    run_intake --once
    [[ "$(curl_calls post_document)" -eq 1 ]]
    assert_in outbox "notes.txt"
}

@test "dotfiles are skipped" {
    make_scan ".hidden.pdf"
    make_scan "control.pdf"
    run_intake --once
    [[ "$(curl_calls post_document)" -eq 1 ]]
}

@test "AppleDouble ._ files are skipped" {
    make_scan "._20261021091350.pdf"
    make_scan "control.pdf"
    run_intake --once
    [[ "$(curl_calls post_document)" -eq 1 ]]
}

@test "a directory named like a pdf is skipped" {
    mkdir -p "$SCANS/outbox/folder.pdf"
    run_intake --once
    assert_status 0
    [[ "$(curl_calls post_document)" -eq 0 ]]
}

@test "empty outbox: exits 0 without uploading" {
    run_intake --once
    assert_status 0
    [[ "$(curl_calls post_document)" -eq 0 ]]
}

@test "a file still being written is skipped and stays in outbox" {
    write_env "STABLE_SECS=2"
    make_scan "growing.pdf"
    make_scan "control.pdf"
    # Append every 0.3 s for 4 s, so any 2-second stability window sees a change.
    (for _ in $(seq 1 13); do echo x >>"$SCANS/outbox/growing.pdf"; sleep 0.3; done) &
    run_intake --once
    wait
    [[ "$(curl_calls post_document)" -eq 1 ]]
    assert_in outbox "growing.pdf"
}

@test "a stable file is uploaded after the stability window" {
    write_env "STABLE_SECS=1"
    make_scan "stable.pdf"
    run_intake --once
    assert_in done "stable.pdf"
}

@test "file names with spaces and quotes are handled" {
    make_scan 'Rechnung "Mai" 2026.pdf'
    run_intake --once
    assert_in done 'Rechnung "Mai" 2026.pdf'
}
