# Phase 9 report — SwiftBar plugin, clickable notifications, health check

## Built
- 9.1 `swiftbar/.config/swiftbar/scan-intake.1m.sh`: renders `scan-intake status --json`; PATH is appended, not prepended, so stubs win in tests.
- 9.2 `notify()` takes a click URL and uses `terminal-notifier` when on PATH (own `-group` per notification, osascript fallback if it exits non-zero); `queue_notify` carries the URL through summaries.
- 9.3 `scan-intake health` plus `scan-intake-health.plist.in`; `install.sh` bootstraps health before main, `uninstall.sh` removes both.
- 9.4 README: log events, SwiftBar plugin, terminal-notifier, health check.

## Verification
`shellcheck scan-intake install.sh uninstall.sh ../swiftbar/.config/swiftbar/scan-intake.1m.sh` -> no output, exit 0.
`bats tests/` -> 250 tests, 250 ok, 0 not ok (before: 54 failing).
Tail of the run:
```
ok 248 upload uses --fail-with-body, --connect-timeout 10 and --max-time 600
ok 249 --verbose adds DEBUG lines
ok 250 without --verbose there are no DEBUG lines
```

## Commit
904fbed [phase-9.1-9.4]

## Deviations
- One commit for 9.1-9.4 (as in phases 7/8).
- Duplicate with unknown existing id: no click target (plan silent).
- Health: each selftest FAIL line counts as one problem; clicks open failed/ if it has files, else the log.
- No project CLAUDE.md exists, so none was updated.

## Tests added / gaps
None added, none weakened.

## Follow-ups
- Live check with the user is still open: rerun install.sh, plugin visibility, forced failure + Retry, clicking a notification, `scan-intake health` with a file in failed/.
- Real terminal-notifier may parse a message with a leading `-` as a flag; the test only pins argv, untested live.
- File URLs are not percent-encoded (fine while SCAN_ROOT/LOG have no spaces).
- Pi-hole password leak in pihole.30s.sh (plan, open items) is still open.

## Confidence
likely-good (stubbed tests green; live behaviour of SwiftBar/terminal-notifier unverified)

## Addendum: live check findings, fixed in [phase-9.5] (2026-10-22)

1. **terminal-notifier had no permission.** Every call exited 3 ("Notifications are not
   allowed for this application"), from this shell and from the user's Ghostty alike. The app
   is ad-hoc signed; on macOS 27 the permission prompt only appears when it is launched through
   LaunchServices (`open -W -n …/terminal-notifier.app --args …`). After that, `-diagnose` says
   `authorized`, banners. The osascript fallback covered every notification until then. README
   now documents the one-time step.
2. **Messages starting with `-` `"` `(` `[` `{` are refused** (exit 2, "Could not read the
   -message value"); `'` and ordinary characters are fine. A leading backslash escapes it, and
   the user confirmed the backslash is not shown. `notify()` now adds it for those characters.

Tests: the fake `terminal-notifier` now refuses the same characters. The phase 9 test "message
arrives verbatim: quotes, a leading dash, …" expected the unescaped leading dash the real tool
rejects; the orchestrator replaced it with three tests: inner quotes and backslashes unchanged;
the five leading characters get a backslash (no osascript fallback); `'` is not escaped. The new
escape test failed before the fix (fallback to osascript), and the suite is green after it:
252 tests, shellcheck clean.
