#!/usr/bin/env bats
# Phase 9.2 — clickable notifications via terminal-notifier when it is on PATH;
# osascript stays the fallback (notify.bats covers that path).

load helpers

six_scans() {
    local i
    for i in 1 2 3 4 5 6; do make_scan "s$i.pdf"; done
}

@test "Uploaded: sent via terminal-notifier, not osascript" {
    use_terminal_notifier
    make_scan "a.pdf"
    run_intake --once
    assert_status 0
    [[ "$(tn_calls)" -eq 1 ]]
    [[ "$(notification_count)" -eq 0 ]]
}

@test "Uploaded: title, subtitle and message" {
    use_terminal_notifier
    make_scan "a.pdf"
    run_intake --once
    [[ "$(tn_arg -title)" == "Scan intake" ]]
    [[ "$(tn_arg -subtitle)" == "Uploaded" ]]
    [[ "$(tn_arg -message)" == "a.pdf → document #6342" ]]
}

@test "Uploaded: click opens the document in paperless" {
    use_terminal_notifier
    make_scan "a.pdf"
    run_intake --once
    [[ "$(tn_arg -open)" == "https://$PUBLIC_HOST/documents/6342/details" ]]
}

@test "Uploaded: no sound" {
    use_terminal_notifier
    make_scan "a.pdf"
    run_intake --once
    [[ "$(tn_calls)" -eq 1 ]]
    ! tn_arg -sound >/dev/null
}

@test "Duplicate: click opens the existing document" {
    use_terminal_notifier
    stub_task FAILURE '"result": "It is a duplicate.", "duplicate_documents": [{"id": 5120, "title": "Old letter"}]'
    make_scan "a.pdf"
    run_intake --once
    [[ "$(tn_arg -subtitle)" == "Duplicate, skipped" ]]
    [[ "$(tn_arg -open)" == "https://$PUBLIC_HOST/documents/5120/details" ]]
}

@test "Error: Basso, and click opens failed/" {
    use_terminal_notifier
    stub_task FAILURE '"result": "Corrupt PDF"'
    make_scan "a.pdf"
    run_intake --once
    [[ "$(tn_arg -subtitle)" == "Error" ]]
    [[ "$(tn_arg -sound)" == "Basso" ]]
    [[ "$(tn_arg -open)" =~ ^file://$SCANS/failed/?$ ]]
}

@test "413: click opens failed/" {
    use_terminal_notifier
    stub_http "$PUBLIC_HOST" post_document 413 ''
    make_scan "big.pdf"
    run_intake --once
    [[ "$(tn_arg -message)" == *"too large for the reverse proxy"* ]]
    [[ "$(tn_arg -open)" =~ ^file://$SCANS/failed/?$ ]]
}

@test "Config error: Basso, and click opens the log" {
    use_terminal_notifier
    chmod 644 "$ENV_FILE"
    run_intake --once
    assert_status 1
    [[ "$(tn_arg -subtitle)" == "Config error" ]]
    [[ "$(tn_arg -sound)" == "Basso" ]]
    [[ "$(tn_arg -open)" == "file://$LOG" ]]
}

@test "Summary without errors: one notification, click opens paperless" {
    use_terminal_notifier
    six_scans
    run_intake --once
    [[ "$(tn_calls)" -eq 1 ]]
    [[ "$(tn_arg -subtitle)" == "Summary" ]]
    [[ "$(tn_arg -open)" =~ ^https://$PUBLIC_HOST/?$ ]]
}

@test "Summary with an error: click opens failed/" {
    use_terminal_notifier
    stub_task FAILURE '"result": "Corrupt PDF"'
    six_scans
    run_intake --once
    [[ "$(tn_calls)" -eq 1 ]]
    [[ "$(tn_arg -sound)" == "Basso" ]]
    [[ "$(tn_arg -open)" =~ ^file://$SCANS/failed/?$ ]]
}

@test "Waiting: no click target" {
    use_terminal_notifier
    stub_transport_error "$PUBLIC_HOST" post_document 7
    make_scan "old.pdf" -2H
    run_intake --once
    [[ "$(tn_arg -subtitle)" == "Waiting" ]]
    ! tn_arg -open >/dev/null
}

@test "every notification gets its own -group, so they don't replace each other" {
    use_terminal_notifier
    make_scan "a.pdf"
    make_scan "b.pdf"
    run_intake --once
    [[ "$(tn_calls)" -eq 2 ]]
    local g1 g2
    g1="$(tn_arg -group 1)"
    g2="$(tn_arg -group 2)"
    [[ -n "$g1" && -n "$g2" && "$g1" != "$g2" ]]
}

@test "no AppleScript escaping: inner quotes and backslashes arrive unchanged" {
    use_terminal_notifier
    make_scan 'Rechnung "Mai" a\b.pdf'
    run_intake --once
    [[ "$(tn_calls)" -eq 1 ]]
    [[ "$(notification_count)" -eq 0 ]]
    [[ "$(tn_arg -message)" == 'Rechnung "Mai" a\b.pdf → document #6342' ]]
}

# The real terminal-notifier refuses a message starting with - " ( [ {; a
# leading backslash escapes it and doesn't show (checked live, 2026-10-22).
@test "a message starting with - \" ( [ or { is sent with a leading backslash" {
    use_terminal_notifier
    local name
    for name in '-x.pdf' '"q".pdf' '(Kopie) Brief.pdf' '[Scan].pdf' '{x}.pdf'; do
        make_scan "$name"
    done
    run_intake --once
    [[ "$(tn_calls)" -eq 5 ]]
    [[ "$(notification_count)" -eq 0 ]]
    for name in '-x.pdf' '"q".pdf' '(Kopie) Brief.pdf' '[Scan].pdf' '{x}.pdf'; do
        grep -qF -- "-message"$'\x1f'"\\$name → document #6342" "$STUB_LOG/terminal-notifier.log" || {
            echo "no escaped message for $name"
            cat "$STUB_LOG/terminal-notifier.log"
            return 1
        }
    done
}

@test "a message starting with an ordinary character or ' is not escaped" {
    use_terminal_notifier
    make_scan "'x'.pdf"
    run_intake --once
    [[ "$(tn_arg -message)" == "'x'.pdf → document #6342" ]]
}

@test "terminal-notifier failing: that notification falls back to osascript" {
    use_terminal_notifier
    echo 1 >"$FIXTURES/terminal-notifier.exit"
    make_scan "a.pdf"
    run_intake --once
    assert_status 0
    [[ "$(tn_calls)" -eq 1 ]]
    assert_notified 'subtitle "Uploaded"'
}

@test "NON-REGRESSION: without terminal-notifier on PATH, osascript is used" {
    make_scan "a.pdf"
    run_intake --once
    assert_notified 'subtitle "Uploaded"'
    [[ ! -s "$STUB_LOG/terminal-notifier.log" ]]
}
