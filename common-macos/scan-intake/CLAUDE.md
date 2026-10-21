# scan-intake

Bash script that uploads ScanSnap scans from `~/Scans/outbox` to paperless-ngx via the REST API,
run by a LaunchAgent. macOS only. User docs: `README.md`. History and design decisions:
`~/dotfiles/docker/paperless-ngx/SCAN-INTAKE-MAC-PLAN.md` (phases 0–6) and
`~/dotfiles/.agent/plans/001-scan-intake-followups.md` (phases 7–9); reports in
`~/dotfiles/.agent/reports/`.

## Layout

- `scan-intake`: the whole tool, one file. Flags `--once` (default), `--selftest`, `--dry-run`,
  `--verbose`; subcommands `status [--json]`, `retry <file|all>`, `health`.
- `install.sh` / `uninstall.sh`: not stowed. They render `scan-intake.plist.in` and
  `scan-intake-health.plist.in` with absolute paths and load them with launchctl.
- The SwiftBar plugin lives in the swiftbar stow package:
  `../swiftbar/.config/swiftbar/scan-intake.1m.sh`. It only renders `status --json`.
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
- SwiftBar 2.1.1 ignores `sfcolor` on the menu-bar icon; use `sfconfig` with Palette rendering.
- The repo (`dotfiles-public`) is public: test fixtures must use made-up document names.
