# Phase 7 end report: pipeline fixes

Status: implemented and committed; phase 7 and earlier test files all green.

## What was built
- 7.1 `process_outbox` in `scan-intake`: up to 3 listing passes per run, each file attempted at most once per run (tracked by name), 401/403 stops the run in any pass, `--dry-run` unchanged.
- 7.2 `scan_title`: drops the extension and `ddMMyyyy_` prefix, collapses whitespace, trims `-_.,;:`, falls back to `Scan YYYY-MM-DD HH.MM` for empty/digit-only names, cuts at 80 characters on a word boundary. Runs in a subshell with `LC_ALL=en_US.UTF-8`. The `-F title=` value is quoted (via `form_quote`) only when it contains `\ " ; ,`, because `upload.bats:29` pins the unquoted fallback form.
- 7.3 401/403 now logs `ERROR rejected`; `API_VERSION` != 9 is a config error via `check_api_version` (called from `run_once` right after `load_env`, and as its own check inside `--selftest`); `.env.example` comment added; "Log lines" table in `SCAN-INTAKE-MAC-PLAN.md` updated (README lists no events).

## Verification
`shellcheck scan-intake`: no output (clean).

`bats` on rescan, titles, errors, config, install, selftest, upload, notify, network, outbox, pending, results, housekeeping, logging: `1..155`, 155 `ok`, 0 `not ok`.

The phase 8 tests (lock, retry, status) are out of scope and still fail.

## Commits
One commit for 7.1-7.3 (the three changes touch the same file): `[phase-7.1-7.3]`, hash in `git log`.

## Deviations / flagged
- First attempt put the `API_VERSION` check inside `load_env`, against the plan. That made `selftest.bats:21` (API_VERSION=10 sent in the Accept header) impossible to pass. Fixed per review: `check_api_version()` is separate; `selftest` reports it as a failed check but still runs the remaining checks. Both tests pass unchanged.
- Title quoted in the `-F` field only when it contains `\ " ; ,`, because `upload.bats:29` pins the unquoted fallback form.

## Test gaps / new tests
None added.

## Follow-ups
- Edge case: a file with the same name dropped again after it was processed in the same run is skipped until the next run.
- No project CLAUDE.md exists in the repo; none created.

Confidence: certain
