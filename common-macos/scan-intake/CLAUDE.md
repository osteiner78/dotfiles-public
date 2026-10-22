# scan-intake

Bash script that uploads ScanSnap scans from `~/Scans/outbox` to paperless-ngx via the REST API,
run by a LaunchAgent. macOS only. User docs: `README.md`. History and design decisions:
`~/dotfiles/docker/paperless-ngx/SCAN-INTAKE-MAC-PLAN.md` (phases 0–6),
`~/dotfiles/.agent/plans/001-scan-intake-followups.md` (phases 7–9) and
`~/dotfiles/.agent/plans/002-scan-intake-review-fixes.md` (phase 10); reports in
`~/dotfiles/.agent/reports/`.

## Layout

- `scan-intake`: the whole tool, one file. Flags `--once` (default), `--selftest`, `--dry-run`,
  `--verbose`; subcommands `status [--json]`, `retry <file|all>`, `health`.
- `install.sh` / `uninstall.sh`: not stowed. They render `scan-intake.plist.in` and
  `scan-intake-health.plist.in` with absolute paths and load them with launchctl.
- The SwiftBar plugin lives in the swiftbar stow package:
  `../swiftbar/.config/swiftbar/scan-intake.1m.sh`. It only renders `status --json`.
- `tests/data/`: real fixture files (made-up content), e.g. `page.pdf` for tests that need a
  renderable scan.
- `tests/`: bats. `bats tests/` (~1 min) plus
  `shellcheck scan-intake install.sh uninstall.sh ../swiftbar/.config/swiftbar/scan-intake.1m.sh`.

## Conventions

- The script is the single source of truth; UIs call its subcommands, never reimplement logic.
- Every path derives from `$HOME`, every external command goes through `PATH` (tests rely on it).
- Log lines: `<ts> <LEVEL> <event> key=value...`; the event table is in the old plan's "Contracts".
- New behaviour gets a failing test first; never weaken an existing test to make it pass.
- Commits: `[phase-X.Y] ...`.

## Gotchas

- BSD tools only (`stat -f`, `date -v`, `sed -i ''`, `base64 -D`). `/usr/bin/env bash` is bash 3.2
  under launchd.
- launchd starts the script without `LANG`: byte vs character counts differ (see `scan_title`).
- Test fakes: `tests/stubs/` (curl, osascript, launchctl) is always on `PATH`;
  `tests/stubs-tn/terminal-notifier` only after `use_terminal_notifier`, so the osascript tests
  keep working. Fakes mirror real behaviour verified live; update them when reality differs.
- `.env` is parsed against a whitelist, never sourced. The token never goes in argv or the log.
- `API_VERSION` must be 9, checked outside `load_env` so `--selftest` still runs its other checks.
- terminal-notifier refuses messages starting with `- " ( [ {` (escape with a leading `\`), and
  needs a one-time permission grant via `open …/terminal-notifier.app` (README).
- `qlmanage -t` never exits on a missing, empty or corrupt file; render thumbnails with `sips`
  (it writes no output on failure, so check the output file, not the exit code).
- terminal-notifier can't change the notification icon (`-appIcon`/`-sender` are gone); only
  `-contentImage` attaches a picture. It reads the file and leaves it in place.
- `curl -F name=<x` / `name=@x` read the file `x`: quote any user-derived `-F` value.
- `selftest` runs as `$(selftest)` in `health`: its `load_env` doesn't reach the caller.
- The lock counts as held only for a live process whose command line contains `scan-intake`
  (pids are reused after a reboot, and the lock survives it).
- `rotate_log` moves the file launchd holds open for stdout/stderr, so stray output lands in
  `.log.1` until the agent restarts.
- `SCAN_ROOT` is always `~/Scans` (not a `.env` key); tests isolate through `$HOME`.
- SwiftBar 2.1.1 ignores `sfcolor` on the menu-bar icon; use `sfconfig` with Palette rendering.
- The repo (`dotfiles-public`) is public: test fixtures must use made-up document names.
