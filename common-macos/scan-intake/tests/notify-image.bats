#!/usr/bin/env bats
# Phase 11 — a picture inside terminal-notifier notifications (-contentImage):
# page 1 of the scan for Uploaded/Duplicate, the system stop icon for errors, the
# caution icon for Waiting. Images are made with sips (checked 2026-10-22: 0.1 s
# per page, never hangs; qlmanage hangs on unreadable files). osascript can't show
# images, so that path stays as it is.

load helpers

CORETYPES=/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources

# reference PNG, rendered the way the plan specifies (sips, longest side 256 px)
render() { # source out
    sips -s format png -Z 256 "$1" --out "$2" >/dev/null 2>&1
}

assert_image_of() { # source [call]
    local img ref="$BATS_TEST_TMPDIR/ref.png"
    img="$(tn_image "${2:-}")" || {
        echo "no -contentImage on call ${2:-last}"
        cat "$STUB_LOG/terminal-notifier.log"
        return 1
    }
    render "$1" "$ref"
    cmp -s "$img" "$ref" || {
        echo "image differs from a 256 px rendering of $1"
        return 1
    }
}

refute_image() { # [call]
    ! tn_image "${1:-}" >/dev/null || {
        echo "unexpected -contentImage on call ${1:-last}"
        return 1
    }
}

failing_sips() {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    printf '#!/usr/bin/env bash\necho "sips: failed" >&2\nexit 13\n' >"$BATS_TEST_TMPDIR/bin/sips"
    chmod +x "$BATS_TEST_TMPDIR/bin/sips"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

six_failing_scans() {
    local i
    stub_task FAILURE '"result": "Corrupt PDF"'
    for i in 1 2 3 4 5 6; do make_scan "s$i.pdf"; done
}

# ── NON-REGRESSION (pass before and after phase 11) ─────────────────────────

@test "NON-REGRESSION: real PDF, terminal-notifier: title, subtitle, message and click target unchanged" {
    use_terminal_notifier
    make_real_scan "a.pdf"
    run_intake --once
    assert_status 0
    [[ "$(tn_calls)" -eq 1 ]]
    [[ "$(tn_arg -title)" == "Scan intake" ]]
    [[ "$(tn_arg -subtitle)" == "Uploaded" ]]
    [[ "$(tn_arg -message)" == "a.pdf → document #6342" ]]
    [[ "$(tn_arg -open)" == "https://$PUBLIC_HOST/documents/6342/details" ]]
}

@test "NON-REGRESSION: real PDF without terminal-notifier: one osascript notification, no image" {
    make_real_scan "a.pdf"
    run_intake --once
    [[ "$(notification_count)" -eq 1 ]]
    assert_notified 'a\.pdf → document #6342'
    refute_notified 'contentImage|\.png'
}

@test "NON-REGRESSION: real PDF ends up byte-identical in done/" {
    use_terminal_notifier
    make_real_scan "a.pdf"
    run_intake --once
    assert_in done "a.pdf"
    cmp -s "$SCANS/done/a.pdf" "$ROOT/tests/data/page.pdf"
}

# ── NEW BEHAVIOUR (fail before phase 11) ────────────────────────────────────

@test "Uploaded: the notification shows page 1 of the scan" {
    use_terminal_notifier
    make_real_scan "a.pdf"
    run_intake --once
    assert_image_of "$ROOT/tests/data/page.pdf"
}

@test "Uploaded: the image is a PNG at most 256 px on its longer side" {
    use_terminal_notifier
    make_real_scan "a.pdf"
    run_intake --once
    local img w h
    img="$(tn_image)"
    [[ -n "$img" ]]
    [[ "$(file -b "$img")" == PNG* ]]
    w=$(sips -g pixelWidth "$img" | awk '/pixelWidth/ { print $2 }')
    h=$(sips -g pixelHeight "$img" | awk '/pixelHeight/ { print $2 }')
    ((w <= 256 && h <= 256 && (w == 256 || h == 256)))
}

@test "Duplicate: the notification shows page 1 of the scan" {
    use_terminal_notifier
    stub_task FAILURE '"result": "It is a duplicate.", "duplicate_documents": [{"id": 5120, "title": "Old letter"}]'
    make_real_scan "a.pdf"
    run_intake --once
    [[ "$(tn_arg -subtitle)" == "Duplicate, skipped" ]]
    assert_image_of "$ROOT/tests/data/page.pdf"
}

@test "Error from paperless: the stop icon, not the scan" {
    use_terminal_notifier
    stub_task FAILURE '"result": "Corrupt PDF"'
    make_real_scan "a.pdf"
    run_intake --once
    [[ "$(tn_arg -subtitle)" == "Error" ]]
    assert_image_of "$CORETYPES/AlertStopIcon.icns"
}

@test "413 error: the stop icon" {
    use_terminal_notifier
    stub_http "$PUBLIC_HOST" post_document 413 ''
    make_scan "big.pdf"
    run_intake --once
    [[ "$(tn_arg -subtitle)" == "Error" ]]
    assert_image_of "$CORETYPES/AlertStopIcon.icns"
}

@test "Config error: the stop icon" {
    use_terminal_notifier
    chmod 644 "$ENV_FILE"
    run_intake --once
    [[ "$(tn_arg -subtitle)" == "Config error" ]]
    assert_image_of "$CORETYPES/AlertStopIcon.icns"
}

@test "Health check with a problem: the stop icon" {
    use_terminal_notifier
    mkdir -p "$SCANS/failed"
    printf '%%PDF-1.4\n' >"$SCANS/failed/x.pdf"
    run "$SCRIPT" health
    assert_status 1
    [[ "$(tn_arg -subtitle)" == "Health check" ]]
    assert_image_of "$CORETYPES/AlertStopIcon.icns"
}

@test "Waiting (paperless unreachable for over 1 h): the caution icon" {
    use_terminal_notifier
    stub_transport_error "$PUBLIC_HOST" post_document 7
    make_scan "old.pdf" -2H
    run_intake --once
    [[ "$(tn_arg -subtitle)" == "Waiting" ]]
    assert_image_of "$CORETYPES/AlertCautionBadgeIcon.icns"
}

@test "Summary with errors (more than 5 results): the stop icon" {
    use_terminal_notifier
    six_failing_scans
    run_intake --once
    [[ "$(tn_calls)" -eq 1 ]]
    [[ "$(tn_arg -subtitle)" == "Summary" ]]
    assert_image_of "$CORETYPES/AlertStopIcon.icns"
}

@test "two uploads: each notification shows its own scan" {
    use_terminal_notifier
    make_real_scan "a.pdf"
    make_real_scan "b.pdf"
    run_intake --once
    [[ "$(tn_calls)" -eq 2 ]]
    assert_image_of "$ROOT/tests/data/page.pdf" 1
    assert_image_of "$ROOT/tests/data/page.pdf" 2
}

# ── FAILURE MODES (fail before phase 11 unless marked) ──────────────────────

@test "file name with spaces, ';', quotes and umlauts: still gets its thumbnail" {
    use_terminal_notifier
    make_real_scan 'Brief "Mai"; Gebühr ä.pdf'
    run_intake --once
    assert_in done 'Brief "Mai"; Gebühr ä.pdf'
    assert_image_of "$ROOT/tests/data/page.pdf"
}

@test "file name starting with a dash: still gets its thumbnail" {
    use_terminal_notifier
    make_real_scan "-x.pdf"
    run_intake --once
    assert_in done "-x.pdf"
    assert_image_of "$ROOT/tests/data/page.pdf"
}

@test "JPEG scan: the notification shows the image" {
    use_terminal_notifier
    mkdir -p "$SCANS/outbox"
    sips -s format jpeg "$ROOT/tests/data/page.pdf" --out "$BATS_TEST_TMPDIR/scan.jpg" >/dev/null 2>&1
    cp "$BATS_TEST_TMPDIR/scan.jpg" "$SCANS/outbox/scan.jpg"
    run_intake --once
    assert_image_of "$BATS_TEST_TMPDIR/scan.jpg"
}

@test "very large page (3000x4000 px): the thumbnail is still at most 256 px" {
    use_terminal_notifier
    local big="$BATS_TEST_TMPDIR/big.png"
    render "$ROOT/tests/data/page.pdf" "$big"
    sips -z 4000 3000 "$big" >/dev/null 2>&1
    mkdir -p "$SCANS/outbox"
    sips -s format pdf "$big" --out "$SCANS/outbox/big.pdf" >/dev/null 2>&1
    run_intake --once
    local img w h
    img="$(tn_image)"
    [[ -n "$img" ]]
    w=$(sips -g pixelWidth "$img" | awk '/pixelWidth/ { print $2 }')
    h=$(sips -g pixelHeight "$img" | awk '/pixelHeight/ { print $2 }')
    ((w > 0 && w <= 256 && h > 0 && h <= 256))
}

@test "NON-REGRESSION: unreadable PDF: the notification is still sent, without an image" {
    use_terminal_notifier
    make_scan "a.pdf"
    run_intake --once
    assert_status 0
    [[ "$(tn_calls)" -eq 1 ]]
    [[ "$(tn_arg -subtitle)" == "Uploaded" ]]
    refute_image
}

@test "NON-REGRESSION: sips fails: notifications still go out, without an image" {
    use_terminal_notifier
    failing_sips
    make_real_scan "a.pdf"
    run_intake --once
    assert_status 0
    [[ "$(tn_calls)" -eq 1 ]]
    refute_image
}

@test "NON-REGRESSION: no -contentImage flag at all when there is no image to show" {
    use_terminal_notifier
    make_scan "a.pdf"
    run_intake --once
    [[ "$(tn_calls)" -eq 1 ]]
    ! tn_arg -contentImage >/dev/null
}

@test "NON-REGRESSION: Summary without errors: no image" {
    use_terminal_notifier
    local i
    for i in 1 2 3 4 5 6; do make_real_scan "s$i.pdf"; done
    run_intake --once
    [[ "$(tn_calls)" -eq 1 ]]
    [[ "$(tn_arg -subtitle)" == "Summary" ]]
    refute_image
}

@test "no thumbnail files are left in TMPDIR after a run" {
    use_terminal_notifier
    export TMPDIR="$BATS_TEST_TMPDIR/tmp"
    mkdir -p "$TMPDIR"
    make_real_scan "a.pdf"
    stub_task FAILURE '"result": "Corrupt PDF"'
    make_real_scan "b.pdf"
    run_intake --once
    [[ -n "$(tn_image 1)" || -n "$(tn_image 2)" ]]
    [[ -z "$(find "$TMPDIR" -type f)" ]] || {
        echo "left behind:"
        find "$TMPDIR" -type f
        return 1
    }
}

@test "terminal-notifier fails: osascript fallback, and no thumbnail left in TMPDIR" {
    use_terminal_notifier
    echo 1 >"$FIXTURES/terminal-notifier.exit"
    export TMPDIR="$BATS_TEST_TMPDIR/tmp"
    mkdir -p "$TMPDIR"
    make_real_scan "a.pdf"
    run_intake --once
    [[ -n "$(tn_image)" ]]
    [[ "$(notification_count)" -eq 1 ]]
    [[ -z "$(find "$TMPDIR" -type f)" ]]
}

@test "NON-REGRESSION: NOTIFY_SUCCESS=false: no notification and no thumbnail is made" {
    use_terminal_notifier
    write_env "NOTIFY_SUCCESS=false"
    export TMPDIR="$BATS_TEST_TMPDIR/tmp"
    mkdir -p "$TMPDIR"
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    printf '#!/usr/bin/env bash\ntouch "%s/sips-called"\nexec /usr/bin/sips "$@"\n' "$BATS_TEST_TMPDIR" >"$BATS_TEST_TMPDIR/bin/sips"
    chmod +x "$BATS_TEST_TMPDIR/bin/sips"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
    make_real_scan "a.pdf"
    run_intake --once
    assert_in done "a.pdf"
    [[ "$(tn_calls)" -eq 0 ]]
    [[ ! -e "$BATS_TEST_TMPDIR/sips-called" ]]
}

@test "the scan itself is never handed to terminal-notifier (only a PNG copy)" {
    use_terminal_notifier
    make_real_scan "a.pdf"
    run_intake --once
    local p
    p="$(tn_arg -contentImage)"
    [[ "$p" == *.png ]]
    [[ "$p" != "$SCANS"/* ]]
}
