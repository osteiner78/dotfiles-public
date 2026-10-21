#!/usr/bin/env bats
# Phase 8.2 — `scan-intake status [--json]`: local state for UIs. Never touches
# the network, never notifies, never writes the log.

load helpers
bats_require_minimum_version 1.5.0

UUID="b1ad602d-0000-4000-8000-000000000001"

status_json() { run "$SCRIPT" status --json; }
j() { jq -r "$1" <<<"$output"; }

put() { # subdir name [content]
    mkdir -p "$SCANS/$1"
    printf '%s\n' "${3:-%PDF-1.4}" >"$SCANS/$1/$2"
}

prepare_tree() {
    put outbox a.pdf
    put outbox b.jpg
    put outbox notes.txt
    put pending slow.pdf
    put pending slow.pdf.task "$UUID"
    put failed x.pdf
    put failed x.pdf.error $'line one\nline two'
    put duplicates d.pdf
    put done 1.pdf
    put done 2.pdf
    put done 3.pdf
}

write_log() {
    mkdir -p "${LOG%/*}"
    cat >"$LOG" <<'EOF'
2026-10-20T08:00:00+0200 INFO  run_start outbox=1 pending=0
2026-10-20T08:00:05+0200 INFO  uploaded file="old.pdf" task=b1ad602d-0000-4000-8000-000000000001 via=public
2026-10-20T08:00:40+0200 INFO  success file="old.pdf" doc=6000 secs=35
2026-10-21T09:14:03+0200 INFO  run_start outbox=1 pending=0
2026-10-21T09:14:41+0200 INFO  success file="Portail clients.pdf" doc=6342 secs=36
2026-10-21T09:14:41+0200 WARN  duplicate file="z.pdf" existing=5120
2026-10-21T09:29:03+0200 INFO  run_start outbox=0 pending=0
EOF
}

@test "status --json prints valid JSON and exits 0" {
    status_json
    assert_status 0
    jq -e . <<<"$output" >/dev/null
}

@test "counts per folder (only scan files; no .task, .error or .txt)" {
    prepare_tree
    status_json
    [[ "$(j '.counts.outbox')" == 2 ]]
    [[ "$(j '.counts.pending')" == 1 ]]
    [[ "$(j '.counts.failed')" == 1 ]]
    [[ "$(j '.counts.duplicates')" == 1 ]]
    [[ "$(j '.counts.done')" == 3 ]]
}

@test "failed entries carry the first line of the .error file" {
    prepare_tree
    status_json
    [[ "$(j '.failed | length')" == 1 ]]
    [[ "$(j '.failed[0].file')" == "x.pdf" ]]
    [[ "$(j '.failed[0].error')" == "line one" ]]
}

@test "a file name with double quotes survives in the JSON" {
    put failed 'Rechnung "Mai".pdf'
    put failed 'Rechnung "Mai".pdf.error' 'HTTP 500'
    status_json
    jq -e . <<<"$output" >/dev/null
    [[ "$(j '.failed[0].file')" == 'Rechnung "Mai".pdf' ]]
}

@test "pending entries carry the task id and the age of the .task file" {
    put pending slow.pdf
    put pending slow.pdf.task "$UUID"
    backdate "$SCANS/pending/slow.pdf.task" -2H
    status_json
    [[ "$(j '.pending[0].file')" == "slow.pdf" ]]
    [[ "$(j '.pending[0].task')" == "$UUID" ]]
    local age
    age="$(j '.pending[0].age_secs')"
    ((age >= 7100 && age <= 7300))
}

@test "last_run and last_success come from the log (latest lines win)" {
    write_log
    status_json
    [[ "$(j '.last_run')" == "2026-10-21T09:29:03+0200" ]]
    [[ "$(j '.last_success.file')" == "Portail clients.pdf" ]]
    [[ "$(j '.last_success.doc')" == 6342 ]]
    [[ "$(j '.last_success.doc | type')" == number ]]
    [[ "$(j '.last_success.at')" == "2026-10-21T09:14:41+0200" ]]
}

@test "without a log, last_run and last_success are null" {
    status_json
    [[ "$(j '.last_run')" == null ]]
    [[ "$(j '.last_success')" == null ]]
}

@test "valid .env: config_ok true, config_error null, paperless_url from .env" {
    status_json
    [[ "$(j '.config_ok')" == true ]]
    [[ "$(j '.config_error')" == null ]]
    [[ "$(j '.paperless_url')" == "https://$PUBLIC_HOST" ]]
}

@test "paths point at the folders and the log" {
    status_json
    [[ "$(j '.paths.root')" == "$SCANS" ]]
    [[ "$(j '.paths.outbox')" == "$SCANS/outbox" ]]
    [[ "$(j '.paths.pending')" == "$SCANS/pending" ]]
    [[ "$(j '.paths.done')" == "$SCANS/done" ]]
    [[ "$(j '.paths.duplicates')" == "$SCANS/duplicates" ]]
    [[ "$(j '.paths.failed')" == "$SCANS/failed" ]]
    [[ "$(j '.paths.log')" == "$LOG" ]]
}

# Phase 10.5 changed this contract: SCAN_ROOT is no longer a .env key.
@test "SCAN_ROOT in .env is ignored" {
    write_env "SCAN_ROOT=$BATS_TEST_TMPDIR/alt"
    mkdir -p "$BATS_TEST_TMPDIR/alt/outbox"
    printf '%%PDF-1.4\n' >"$BATS_TEST_TMPDIR/alt/outbox/a.pdf"
    put outbox b.pdf
    status_json
    [[ "$(j '.paths.root')" == "$SCANS" ]]
    [[ "$(j '.counts.outbox')" == 1 ]]
}

@test "invalid .env (mode 644): config_ok false with the reason, exit 0, no notification" {
    chmod 644 "$ENV_FILE"
    status_json
    assert_status 0
    [[ "$(j '.config_ok')" == false ]]
    [[ "$(j '.config_error')" == *"chmod 600"* ]]
    [[ "$(j '.paths.root')" == "$SCANS" ]]
    [[ "$(notification_count)" -eq 0 ]]
}

@test "missing .env: config_ok false, exit 0" {
    rm "$ENV_FILE"
    status_json
    assert_status 0
    [[ "$(j '.config_ok')" == false ]]
}

@test "agent_loaded follows launchctl print of the main agent" {
    status_json
    [[ "$(j '.agent_loaded')" == true ]]
    grep -q "print gui/$(id -u)/xyz.osteiner.scan-intake" "$STUB_LOG/launchctl.log"
    touch "$FIXTURES/launchctl.fail"
    status_json
    [[ "$(j '.agent_loaded')" == false ]]
}

@test "status makes no network calls" {
    prepare_tree
    status_json
    assert_status 0
    [[ ! -s "$STUB_LOG/curl.log" ]]
}

@test "status does not write to the log" {
    write_log
    local before
    before="$(cat "$LOG")"
    status_json
    assert_status 0
    [[ "$(cat "$LOG")" == "$before" ]]
}

@test "status does not move or upload anything" {
    prepare_tree
    status_json
    assert_status 0
    assert_in outbox a.pdf
    assert_in failed x.pdf
    assert_in pending slow.pdf
}

@test "status without --json prints a human summary naming failed files" {
    prepare_tree
    run "$SCRIPT" status
    assert_status 0
    [[ "$output" == *outbox* ]]
    [[ "$output" == *failed* ]]
    [[ "$output" == *x.pdf* ]]
    ! jq -e . <<<"$output" >/dev/null 2>&1
}

@test "NON-REGRESSION: no argument still means --once" {
    make_scan "a.pdf"
    run "$SCRIPT"
    assert_status 0
    assert_in done "a.pdf"
}

# ── phase 10.3 ──────────────────────────────────────────────────────────────

@test "a .task file that vanishes mid-listing doesn't crash status --json" {
    put pending vanish.pdf
    put pending vanish.pdf.task "$UUID"
    put pending slow.pdf
    put pending slow.pdf.task "$UUID"
    vanishing_stat
    run --separate-stderr "$SCRIPT" status --json
    assert_status 0
    jq -e . <<<"$output" >/dev/null
    [[ "$stderr" != *"syntax error"* ]]
    [[ "$(j '.pending[] | select(.file == "slow.pdf") | .task')" == "$UUID" ]]
}
