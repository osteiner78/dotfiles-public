# Phase 1 end: config loading, logging, selftest

## Built
- 1.1 Script skeleton: defaults, flag parsing (`--once` default, `--selftest`, `--dry-run`, `--verbose`; unknown flag exits 2), folder creation.
- 1.2 `.env` loader: key whitelist via `printf -v`, never sourced; mode check rejects any group/other bit; missing file, empty token or loose mode gives notify + `config_error` log + exit 1.
- 1.3 Log writer (`<ts> <LEVEL:5> <event> k=v`, DEBUG only with `--verbose`) and `run_start` with outbox/pending counts.
- 1.4 `--selftest`: curl/jq on PATH, `.env` valid and not in a git tree, five folders writable, `GET /api/tags/?page_size=1` returns 200; prints per-check summary, exit 0/1.

Commit: c590b66 (all four tasks in one commit; they share one file, so no per-task test state existed to commit separately). It also adds the previously untracked phase 1-4 test suite and stubs, unmodified.

## Verification
`shellcheck scan-intake`: clean (no output).

```
1..27
ok 1 missing .env: exits 1
ok 2 missing .env: notifies Config error
ok 3 empty token: exits 1 with Config error notification
ok 4 .env with mode 644: refuses to run
ok 5 .env with mode 644: notification says how to fix it (chmod 600)
ok 6 .env with mode 644: nothing is uploaded and the scan stays in outbox
ok 7 .env is parsed, not sourced: command substitution is not executed
ok 8 .env is parsed, not sourced: a bare command line is not executed
ok 9 .env keys outside the whitelist are ignored (PATH cannot be overridden)
ok 10 .env comments and blank lines are accepted
ok 11 .env SCAN_ROOT overrides the default ~/Scans
ok 12 first run creates outbox, pending, done, duplicates and failed
ok 13 no flag behaves like --once
ok 14 each run appends a run_start line with outbox and pending counts
ok 15 log lines use only the levels DEBUG, INFO, WARN and ERROR
ok 16 two runs append, they do not truncate
ok 17 config error is logged as ERROR
ok 18 selftest: valid config and reachable server pass with exit 0
ok 19 selftest: queries GET /api/tags/?page_size=1
ok 20 selftest: sends the API version in the Accept header
ok 21 selftest: API_VERSION from .env is used in the Accept header
ok 22 selftest: token rejected (401) fails with exit 1
ok 23 selftest: .env with mode 644 fails
ok 24 selftest: .env inside a git working tree fails and says so
ok 25 selftest: a non-writable scan folder fails
ok 26 selftest: never uploads anything
ok 27 selftest: prints a summary
```

## Deviations
- Report numbered 003, not 002: 002 is already the phase 0 audit.
- The plan says to read `dotfiles-secrets/.../SCANNER-INTAKE.md`; it actually lives in `dotfiles/docker/paperless-ngx/`.
- `# shellcheck disable=SC2034` at file top: config keys and `DRY_RUN` are only consumed from phase 2/3. Remove it once they are used so real unused variables get flagged again.
- `notify()` (with AppleScript escaping and Basso for errors) is in phase 1 because config errors need it; phase 2.4 adds queueing/summary on top.
- Phase 0 audit not run through approval/cleanup in this session; not a phase 1 dependency.

## Tests
No tests added or changed.

## Follow-ups
- Tests run under macOS bash 3.2 (`/usr/bin/env bash` with the tests' PATH): avoid bash 4+ features (associative arrays, `${x,,}`, empty-array expansion under `set -u`).
- `run_start` counts: outbox = files passing the extension/dotfile filter; pending = `*.task` files.
- No CLAUDE.md in `~/dotfiles`; nothing to update.

Confidence: likely-good
