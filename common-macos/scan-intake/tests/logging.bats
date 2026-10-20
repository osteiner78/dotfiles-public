#!/usr/bin/env bats
# Phase 1 — log file location and line format.

load helpers

# ISO timestamp; BSD `date` has no %:z, so the offset may be +0200 or +02:00.
TS='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{2}:?[0-9]{2}'

@test "each run appends a run_start line with outbox and pending counts" {
    make_scan "a.pdf"
    run_intake --once
    assert_log "$TS INFO +run_start outbox=1 pending=0"
}

@test "log lines use only the levels DEBUG, INFO, WARN and ERROR" {
    run_intake --once
    [[ -s "$LOG" ]]
    ! grep -Ev "$TS (DEBUG|INFO|WARN|ERROR) +[a-z_]+" "$LOG"
}

@test "two runs append, they do not truncate" {
    run_intake --once
    run_intake --once
    [[ "$(grep -c run_start "$LOG")" -eq 2 ]]
}

@test "config error is logged as ERROR" {
    chmod 644 "$ENV_FILE"
    run_intake --once
    assert_log "$TS ERROR +config_error"
}
