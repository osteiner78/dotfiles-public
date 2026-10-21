#!/usr/bin/env bats
# Phase 7.1 — files that land in outbox while a run is busy are picked up by the
# same run (launchd doesn't re-fire WatchPaths for changes made during the job).

load helpers

@test "a scan saved during an upload is uploaded in the same run" {
    make_scan "a.pdf"
    drop_during_upload "b.pdf"
    run_intake --once
    assert_status 0
    assert_in done "a.pdf"
    assert_in done "b.pdf"
    [[ "$(curl_calls post_document)" -eq 2 ]]
}

@test "NON-REGRESSION: the rescan stays inside one run: one run_start line" {
    make_scan "a.pdf"
    drop_during_upload "b.pdf"
    run_intake --once
    [[ "$(grep -c 'run_start' "$LOG")" -eq 1 ]]
}

@test "a file left in outbox by a network error is attempted once per run" {
    stub_transport_error "$PUBLIC_HOST" post_document 7
    make_scan "a.pdf"
    drop_during_upload "b.pdf"
    run_intake --once
    assert_status 0
    assert_in outbox "a.pdf"
    assert_in outbox "b.pdf"
    [[ "$(grep -c 'outbox/a.pdf' "$STUB_LOG/curl.log")" -eq 1 ]]
    [[ "$(grep -c 'outbox/b.pdf' "$STUB_LOG/curl.log")" -eq 1 ]]
}

@test "the rescan stops after 3 passes even if every pass adds a file" {
    cat >"$FIXTURES/hook.src" <<'EOF'
n=$(cat "$FIXTURES/drops" 2>/dev/null || echo 0)
n=$((n + 1))
echo "$n" >"$FIXTURES/drops"
printf '%%PDF-1.4\n' >"$HOME/Scans/outbox/drop-$n.pdf"
cp "$FIXTURES/hook.src" "$FIXTURES/on_post_document"
EOF
    cp "$FIXTURES/hook.src" "$FIXTURES/on_post_document"
    make_scan "a.pdf"
    run_intake --once
    assert_status 0
    [[ "$(curl_calls post_document)" -eq 3 ]]
    assert_in done "drop-1.pdf"
    assert_in done "drop-2.pdf"
    assert_in outbox "drop-3.pdf"
}

@test "401 on a file found by the rescan stops the run and exits 1" {
    make_scan "a.pdf"
    on_upload "printf '%%PDF-1.4\\n' >\"\$HOME/Scans/outbox/b.pdf\"
printf 401 >\"\$FIXTURES/$PUBLIC_HOST/post_document.code\"
printf '{\"detail\": \"Invalid token.\"}' >\"\$FIXTURES/$PUBLIC_HOST/post_document.body\""
    run_intake --once
    assert_status 1
    assert_in done "a.pdf"
    assert_in outbox "b.pdf"
    assert_notified 'Config error'
}

@test "NON-REGRESSION: --dry-run lists outbox once and uploads nothing" {
    make_scan "a.pdf"
    run_intake --dry-run
    assert_status 0
    [[ "$output" == "would upload a.pdf" ]]
    [[ "$(curl_calls post_document)" -eq 0 ]]
}
