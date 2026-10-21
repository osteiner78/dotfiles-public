# Phase 8 end report: run lock and machine-readable subcommands

Status: implemented; the full suite is green.

## What was built
- 8.1 `acquire_lock` / `cleanup`: `mkdir $SCAN_ROOT/.lock` with `$$` in `.lock/pid`. A live owner (`kill -0`) logs `INFO skipped` and exits 0. A dead or missing pid logs `WARN stale_lock` and the lock is taken over. The lock is released by the EXIT trap, so it also goes away after a 401 stop. `--dry-run`, `--selftest`, `status` and `retry` never take it.
- 8.2 `status [--json]`: local only, built with `jq -n`. An invalid `.env` gives `config_ok=false` with the reason and exit 0 (`API_VERSION` != 9 counts as a config error too). Without `--json` it prints a short summary.
- 8.3 `retry <file|all>`: moves `failed/<file>` to outbox through `file_into` (timestamp prefix on a collision), deletes the `.error`, logs `INFO requeued`, prints `requeued <file>`. Exit 2 with a message on stderr for unknown names, `.error` names, names with `/`, and a missing argument. Never uploads.

## Verification
`shellcheck scan-intake`: no output (clean).

`bats tests/`: `1..195`, 195 `ok`, 0 `not ok`.

## Commits
`[phase-8.1-8.3]`, hash in `git log`.

## Deviations
- `retry` with an unreadable `.env` falls back to the default `SCAN_ROOT` (the plan's suggestion).
- Added the `skipped`, `stale_lock` and `requeued` events to the Log lines table in `SCAN-INTAKE-MAC-PLAN.md`, and the two subcommands to the README usage block. Phase 9.4 still owns the fuller README section.
- No CLAUDE.md exists in the repo, so none was updated.

## Test gaps / new tests
None added.

## Follow-ups
- A second run that starts between `mkdir .lock` and the pid write (microseconds) sees no pid and takes the lock over as stale. Closing it would need a different lock primitive.
- `kill -0` fails for a pid owned by another user; irrelevant here (same user), but it would read as stale.

## Confidence
likely-good
