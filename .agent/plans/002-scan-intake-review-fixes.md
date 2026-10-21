# Scan intake: fixes from code review 011

Follows plan 001 (phases 7–9, done). Source: `~/dotfiles/.agent/reports/011-code-review-scan-intake.md`
(numbers like "R1" refer to its findings). Conventions: `common-macos/scan-intake/CLAUDE.md`.
Phase number continues: **phase 10**. Next free report number: 012.

**Test status (2026-10-22):** written; 268 tests, 12 fail for the right reason (10 new + the 2
tests 10.5 changes on purpose), 256 pass (incl. 5 new NON-REGRESSION guards). Test infrastructure
added: the curl fake refuses an unquoted `-F` value starting with `<`/`@` (exit 26, like real
curl); `vanishing_stat` helper (test-local `stat` failing for `*vanish*` paths); lock tests'
`hold_lock` holder is named `scan-intake-holder` and `foreign_lock` uses a plain `sleep`.
`status.bats`/`health.bats` declare `bats_require_minimum_version 1.5.0` (for
`run --separate-stderr`). 10.6 has no new tests beyond two doc checks in `install.bats`
(`.env.example` without `SCAN_ROOT`, README lists `upload_error`); its refactors are covered by
existing tests.

## Decisions (2026-10-22)

| Topic | Decision |
|---|---|
| Fix | R1, R2 (by removing the `SCAN_ROOT` setting), R3, R4, R5, R6, R8, plus the lock pid-reuse problem (review's missing test 6, raised to a bug) |
| Don't fix | R7 (log rotation vs launchd's open fd: document only), R9 (plugin quoting: fails safe, `retry` rejects unknown names) |
| `SCAN_ROOT` | **No longer a `.env` key.** It's always `$HOME/Scans`. `install.sh` and the plist hard-code that path anyway, so the override only half-worked, and R2 exists because nothing used it. Tests still isolate through `$HOME`. The internal variable stays |
| Title quoting | Extend the existing rule (quote on a leading `<` or `@`). `--form-string` would be more thorough, but it changes the argument shape every title test pins |
| New log event | `WARN upload_error file="…" reason="…"` for "no final answer, file stays in outbox" |
| Lock liveness | The lock counts as held only if its pid is alive **and** that process's command line contains `scan-intake` |
| History rewrite | No (real document names in `6be4de4` stay; force-push to main is off the table) |
| Out of scope | Showing outbox files that keep failing in `status`/the plugin (review's "no state outside the log"). Future idea, see the end |

---

## Phase 10 — Review fixes

### [phase-10.1] A title starting with `<` or `@` makes curl read a file (R1)

`scan-intake:266-268`: also quote when `$title == [\<@]*`. Real curl treats `-F title=<x` as
"contents of file x" and `@x` as an upload; quoted, it sends the literal text (verified with
curl 8.7.1 in the review).

Tests (`titles.bats`):
- `<Kopie> Brief.pdf` → the argument is exactly `title="<Kopie> Brief"`, and the file ends up
  in done/.
- `@home.pdf` → `title="@home"`.
- `a <b> c.pdf` (`<` not leading) → unquoted `title=a <b> c`, so the rule stays narrow.
- NON-REGRESSION: the existing `title=Scan …` and `title="Brief; Mai"` pins are unchanged.

Teach the curl stub the real behaviour, the same way `terminal-notifier` was taught in 9.5: an
**unquoted** `-F` value starting with `<` or `@` (other than `document=@`) → exit 26. Without
this, the stub would accept the bug. Make sure every existing test still passes with it.

### [phase-10.2] Upload errors that leave the file in outbox (R3)

`scan-intake:374-377` (`*)` branch: no HTTP answer) and `382-384` (no task id): log
`WARN upload_error file="…" reason="…"` instead of `ERROR failed`. Behaviour otherwise
unchanged: the file stays in outbox and there's no notification. Update the Contracts log
table in `SCAN-INTAKE-MAC-PLAN.md` and the README's event list.

Tests (`errors.bats`):
- curl exits 35 (TLS error, no HTTP code) → the file stays in outbox, no notification,
  `WARN +upload_error file="a.pdf" reason="curl exit 35`, and no `failed file="a.pdf"` line.
- `post_document` returns 200 with a non-string body (`{}`) → stays in outbox,
  `upload_error … reason="no task id in response"`.
- NON-REGRESSION: 413 and 500 still log `ERROR failed` and move to failed/.

### [phase-10.3] `status` and `health` crash when a file vanishes mid-listing (R4)

`scan-intake:576-579` (`pending_entries`) and `~509` (`health_cmd`): guard each `stat -f %m`
the way `process_file:352` does (`2>/dev/null || echo "$now"`). Better still: skip the entry if
the file is gone by then. Pick one and say which in the report.

Tests: the race can't be timed in a test, so fake it. Write a test-local `stat` wrapper (in
`$BATS_TEST_TMPDIR/bin`, put first on `PATH`) that fails for paths containing `vanish` and calls
`/usr/bin/stat` otherwise.
- `status.bats`: `pending/vanish.pdf` + `vanish.pdf.task` with the wrapper → exit 0, valid JSON.
- `health.bats`: `outbox/vanish.pdf` with the wrapper → health doesn't crash (exit 0 or 1, never
  a bash error on stderr).

### [phase-10.4] Lock: pid reuse after a crash, and atomic takeover (R5 + missing test 6)

`acquire_lock`:
- Held = `kill -0 "$pid"` **and** `ps -p "$pid" -o command=` contains `scan-intake`. Otherwise
  it's stale.
- Stale takeover by rename: `mv "$lock" "$lock.stale.$$" 2>/dev/null && rm -rf "$lock.stale.$$"`,
  then `mkdir`. If `mkdir` fails, another run won: log `skipped`, return 1 (as today).

Tests (`lock.bats`):
- A lock whose pid belongs to a live process that isn't scan-intake (`sleep 30`) → stale:
  `WARN stale_lock`, file uploaded.
- **Change the existing helper `hold_lock`** to start a holder whose command line contains
  `scan-intake` (`bash -c 'exec -a scan-intake-holder sleep 30'`; checked with `ps -o command=`).
  Otherwise the existing "live run" tests would see a stale lock. The tests themselves stay the same.
- Atomic takeover: no test (it needs two runs racing inside a few lines). Say so in the report.

### [phase-10.5] Remove `SCAN_ROOT` from `.env` (R2)

- Drop `SCAN_ROOT` from the `load_env` whitelist; it's always `$HOME/Scans`. A `SCAN_ROOT=` line
  in `.env` is now ignored like any unknown key.
- `.env.example`: remove the `SCAN_ROOT` comment lines.
- This fixes R2 for `health`. The `$(selftest)` subshell trap remains (nothing observable
  depends on it any more), so document it in CLAUDE.md (10.6) instead of adding an untestable
  `load_config_quietly` call.

Tests, **changed on purpose** (contract change; note both in the report):
- `config.bats:74` ".env SCAN_ROOT overrides the default ~/Scans" → ".env SCAN_ROOT is ignored":
  with `SCAN_ROOT=$HOME/OtherScans`, a scan in `~/Scans/outbox` is uploaded and `OtherScans/` is
  not created.
- `status.bats:122` "SCAN_ROOT from .env is honoured" → "SCAN_ROOT in .env is ignored":
  `paths.root == $HOME/Scans`.

New tests:
- `health.bats`: `SCAN_ROOT=$HOME/Other` in `.env` and a file in `~/Scans/failed/` → exit 1,
  problems=1 (health looks where everything else does).
- `retry.bats`: `.env` with mode 644 → `retry x.pdf` still moves `~/Scans/failed/x.pdf` (pins
  today's fallback, which is now simply the only root).

### [phase-10.6] Cleanups and docs (R6, R8, R7)

- R6: delete `count_outbox`; `run_once` uses `count_scans outbox`. Covered by the existing
  `run_start outbox=N` tests.
- R8: plugin `base64` → `base64 | tr -d '\n'` (GNU wraps at 76; costs nothing). Covered by
  `bar_is_red`.
- `CLAUDE.md` gotchas, add:
  - `curl -F name=<x` / `name=@x` read the file `x`: quote any user-derived `-F` value.
  - `selftest` runs as `$(selftest)` in `health`: its `load_env` doesn't reach the caller.
  - The lock counts as held only for a live process whose command line contains `scan-intake`
    (pids are reused after a reboot, and the lock survives it).
  - `rotate_log` moves the file launchd holds open for stdout/stderr, so stray output lands in
    `.log.1` until the agent restarts.
  - Remove the `SCAN_ROOT` override wherever CLAUDE.md or README mention it.

### Verification
```bash
cd ~/dotfiles/common-macos/scan-intake
shellcheck scan-intake install.sh uninstall.sh ../swiftbar/.config/swiftbar/scan-intake.1m.sh
bats tests/
```

Live check (short): drop `<test> probe.pdf` (a real small PDF) in outbox → it gets uploaded with
title `<test> probe`. Then delete that document in paperless. Plugin still red/normal as
expected after `./install.sh`.

## Future ideas (not in this plan)

- Outbox files that keep failing (`upload_error`, network down for hours) are only visible as
  the outbox count and in Monday's health check. An `outbox_stuck` list in `status --json`
  (files older than 1 h, as health already computes) would let the plugin show them.
