# Scan intake follow-ups: implementation plan

Follows `~/dotfiles/docker/paperless-ngx/SCAN-INTAKE-MAC-PLAN.md` (phases 0–5 done, phase 6 =
feature selection, 2026-10-21). Read that plan's "Decisions" and "Contracts" first: they still
apply unless this plan overrides them. Phase numbers continue from it (7, 8, 9).

| What | Path |
|---|---|
| Code | `~/dotfiles/common-macos/scan-intake/` |
| SwiftBar plugin | `~/dotfiles/common-macos/swiftbar/.config/swiftbar/` (already symlinked to `~/.config/swiftbar`, SwiftBar's plugin folder) |
| Tests | `common-macos/scan-intake/tests/*.bats` |
| Phase reports | `~/dotfiles/.agent/reports/NNN-phase-N-end.md` (next free number: 008) |

**Status (2026-10-22): done.** Phases 7–9 are implemented and live-checked (reports 008–010),
including two fixes found live: `[phase-9.5]` (terminal-notifier message escaping) and
`[phase-9.6]` (menu-bar icon colour). 253 tests green. What's left is in "Open items" below and
the future ideas in "Selected scope".

Test infrastructure added for these phases:
- `tests/stubs/curl`: if `$FIXTURES/on_post_document` exists, a `post_document` call runs it once
  with bash **after** its response is decided (the file is removed first, so a hook can re-arm).
  Helpers: `on_upload SCRIPT`, `drop_during_upload NAME`.
- `tests/stubs/launchctl`: exits 1 when `$FIXTURES/launchctl.fail` exists.
- `tests/stubs-tn/terminal-notifier` (phase 9): logs argv to `terminal-notifier.log`, exits with
  `$FIXTURES/terminal-notifier.exit` if present. Only on `PATH` after `use_terminal_notifier`.
  Helpers: `tn_calls`, `tn_arg FLAG [CALL]`, `write_success_log`.

## Selected scope

| Phase | Item | Source |
|---|---|---|
| 7 | Rescan outbox before exiting | phase 6 #13 |
| 7 | Titles from the ScanSnap file name | phase 6 #11 |
| 7 | Phase 5 cleanups (401 log wording, `API_VERSION` guard, `.env.example` comment) | report 007 follow-ups |
| 8 | Run lock, `status [--json]`, `retry <file\|all>` | phase 6 prerequisite |
| 9 | SwiftBar plugin, clickable notifications, weekly health check | phase 6 #1, #3, #10 |

Not doing (future ideas): Raycast (#2), title/date prompt (#4), AI suggestions (#5), native app
(#6), dashboard (#7), Quick Action (#8, dropping a file into `~/Scans/outbox` in Finder does the
same), iPhone Shortcut (#9). German summaries (#12) are being done server-side.

## Decisions (made 2026-10-21)

| Topic | Decision |
|---|---|
| Title fallback | `Scan YYYY-MM-DD HH.MM` (the current title) when nothing usable is left of the name |
| Title length | max 80 characters (characters, not bytes) |
| `API_VERSION` ≠ 9 | config error (same path as an empty token): with 10, every upload times out into pending/ (report 007) |
| `open-failed` subcommand | dropped. `status --json` returns the folder paths, and the plugin and notifications call `open` on them directly |
| `retry` | only moves files back to outbox; it never uploads. The `WatchPaths` agent (or the rescan loop of a run in progress) picks them up. One upload path, no second code path to test |
| "Run now" | `launchctl kickstart gui/<uid>/xyz.osteiner.scan-intake`, not a direct call: launchd won't start a second instance |
| Notifier | `terminal-notifier` when it is on `PATH`, otherwise `osascript` as today. No new `.env` key |
| Health check schedule | weekly, Monday 09:00, via `StartCalendarInterval` (a run missed while asleep fires on wake) |

---

## Phase 7 — Pipeline fixes

**Intent.** Fix the two problems seen in daily use before building anything on top of them:
missed scans and meaningless titles. Out of scope: any new subcommand or UI.

### [phase-7.1] Rescan outbox before exiting

Problem: a scan saved during a run is missed until the 900 s interval, because the run listed
outbox once at its start and launchd doesn't re-fire `WatchPaths` for changes made while the job
runs.

Behaviour:
- After the outbox loop, list outbox again. Process only eligible files **not already attempted
  in this run** (track names). Repeat while a pass finds new files, at most **3 passes** in total.
- Files that stayed in outbox for a reason (network error, unstable) are not retried in the same
  run. Without this rule, a network outage would upload-attempt each file 3 times per run.
- A 401/403 still stops the run immediately, in any pass.
- `--dry-run` is unchanged (one listing).
- `run_start` counts stay as they are (first listing).

Tests (`tests/rescan.bats`, NEW-BEHAVIOR / FAILURE-MODE):
- A file added to outbox while the first upload is in flight is uploaded in the same run
  (`drop_during_upload`); still one `run_start` line.
- With a network error (curl 7), both the original and the dropped file are attempted exactly
  once.
- The loop stops after 3 passes even if every pass adds a new file (the hook re-arms itself).
- 401 in pass 2 stops the run and exits 1.

### [phase-7.2] Titles from the ScanSnap file name

Applies only to the **neutral** branch (names not matching `^[0-9]{4}-[0-9]{2}-[0-9]{2} - .+`).
The filename stays `scan.<ext>`: since the server's YMD fix, a separated date in the filename
would set the created date, and ScanSnap titles contain dates (`Date 30.09.2026`).

Title derivation (`scan_title <name>`), in order:
1. Drop the extension.
2. Drop a leading `^[0-9]{8}_` (ScanSnap's `ddMMyyyy_` prefix).
3. Collapse runs of whitespace into one space; trim leading/trailing spaces and `-_.,;:`.
4. If the result is empty or only digits (e.g. `20261021091350`), use the fallback
   `Scan $(date '+%Y-%m-%d %H.%M')`.
5. If it is longer than 80 characters: cut at the last space at or before 80; if there is none,
   cut at 80. Then trim trailing spaces and punctuation as in step 3.

**Gotcha:** launchd starts the script without `LANG`, so bash's `${#s}` counts bytes, and cutting
by bytes can split `ü`/`é` into invalid UTF-8. Set a UTF-8 locale for this function
(`LC_ALL=en_US.UTF-8`) or otherwise count characters; a test covers it.

The title goes in `-F "title=…"`. When it contains `;`, `,`, `"` or a backslash, send it quoted
(`title="<form_quote'd title>"`); otherwise unquoted. The fallback must stay unquoted:
`upload.bats` pins `title=Scan YYYY-MM-DD HH.MM`.

Tests (`tests/titles.bats`, NEW-BEHAVIOR / FAILURE-MODE), names taken from real scans:
- `01011996_Allgemeine Mitteilung (ABC) - Zustellung einer Kopie der aktuellen Vereinbarung zum Beispielvertrag.pdf`
  → title starts with `Allgemeine Mitteilung`, is ≤ 80 characters, ends on a word.
- `20102026_- Why was my request delayed? …` → leading `- ` trimmed.
- `20102026_Portail clients Exemple vos données d'accès.pdf` → title is exactly
  `Portail clients Exemple vos données d'accès` (the apostrophe and `é` survive).
- `20261021091350.pdf` → fallback `Scan YYYY-MM-DD HH.MM`.
- `12345678_.pdf` → fallback.
- A long name with a multi-byte character near position 80, under `env -u LANG -u LC_ALL` →
  the title is valid UTF-8 (`iconv -f UTF-8 -t UTF-8` succeeds) and ≤ 80 characters.
- `30092026_Musterfirma AG … Date 30.09.2026 …pdf` → still `filename=scan.pdf`.
- `Brief; Mai.pdf` → the argument is exactly `title="Brief; Mai"`.
- `20102026_Rechnung "Mai".pdf` → title `Rechnung "Mai"` after unquoting.
- `20102026_Foo   Bar .pdf` → `Foo Bar`.
- `Rechnung.pdf` (non-ScanSnap name) → title `Rechnung`.

Step 5 precisely: take the first 81 characters; if that contains a space, cut at the last one;
otherwise cut at 80. The expected values in `titles.bats` were computed with this rule.

NON-REGRESSION: the existing `upload.bats` cases already pin the fallback title for
`20261021091350.pdf` and the dated-name branch (own filename, `created=`, no title).

### [phase-7.3] Phase 5 cleanups

- 401/403 log line: `ERROR rejected file="…" http=401` instead of `failed`, because the file
  stays in outbox. Update the "Log lines" table in `SCAN-INTAKE-MAC-PLAN.md` ("Contracts") and the
  README if it lists events.
- `API_VERSION` other than `9` → for runs, a config error with reason
  `API_VERSION must be 9 (is N); the task API changed in version 10`. In `--selftest` it is its
  own `FAIL` line, and the other checks still run **with that version**: the existing test
  "selftest: API_VERSION from .env is used in the Accept header" sets 10 and expects
  `version=10` on the tags request. So don't put the check inside `load_env`.
- `.env.example`: comment above `API_VERSION=9` saying it must stay 9.

Tests (add to `tests/errors.bats` and `tests/config.bats`):
- 401 → log has `rejected file=… http=401` and no `failed` line for that file.
- `API_VERSION=10` → exit 1, `config_error` log line, "Config error" notification, no upload.
- `API_VERSION=10` → `--selftest` exits 1 and its output contains `API_VERSION must be 9`.
- `API_VERSION=9` set explicitly still works (NON-REGRESSION).
- `.env.example` has a comment line mentioning `API_VERSION` and 9 (in `install.bats`).

### Verification
```bash
cd ~/dotfiles/common-macos/scan-intake
shellcheck scan-intake
bats tests/
```

Live check (with the user): one real ScanSnap scan → paperless title is the cleaned name; a
second scan saved while the first one is still polling → uploaded in the same run (log shows
both under one `run_start`).

---

## Phase 8 — Run lock and machine-readable subcommands

**Intent.** Give UIs a stable interface so they never reimplement logic, and make concurrent
invocations safe. Out of scope: the UIs themselves (phase 9).

### [phase-8.1] Run lock

A manual `scan-intake` in a terminal can overlap with a launchd run and upload the same file
twice. Add a lock around the `--once` path:
- `mkdir "$SCAN_ROOT/.lock"` (atomic) and write `$$` into `.lock/pid`; remove it on exit (trap).
- If the lock exists and its pid is alive (`kill -0`): log `INFO skipped reason="another run in progress"`
  and exit 0. The running run's rescan loop (7.1) will pick up any new file.
- If the pid is dead or missing: take the lock over and log `WARN stale_lock`.
- `--selftest`, `--dry-run`, `status` and `retry` don't take the lock.

Tests (`tests/lock.bats`): lock held by a live pid (`sleep 30 &`) → no upload, exit 0, `skipped`
logged, the holder's pid file untouched; stale lock (dead pid) and lock dir without `pid` → taken
over, file uploaded, `stale_lock` logged; during the upload `.lock/pid` holds a number (checked
via the upload hook) and the lock is gone after a normal run and after a 401 stop; `--selftest`
and `--dry-run` run while a lock is held.

### [phase-8.2] `status [--json]`

Subcommands are positional (`scan-intake status --json`); the existing flags keep working and
`--once` stays the default. `status` is **local only**: no network, because SwiftBar calls it
every minute.

JSON shape (built with `jq -n`, so names with quotes are escaped correctly):

```json
{
  "config_ok": true,
  "config_error": null,
  "agent_loaded": true,
  "paperless_url": "https://paperless.osteiner.xyz",
  "paths": {"root": "...", "outbox": "...", "pending": "...", "done": "...",
            "duplicates": "...", "failed": "...", "log": "..."},
  "counts": {"outbox": 0, "pending": 0, "failed": 1, "duplicates": 0, "done": 12},
  "failed": [{"file": "x.pdf", "error": "first line of x.pdf.error"}],
  "pending": [{"file": "y.pdf", "task": "uuid", "age_secs": 120}],
  "last_run": "2026-10-21T09:14:03+0200",
  "last_success": {"file": "a.pdf", "doc": 6342, "at": "2026-10-21T09:14:41+0200"}
}
```

- If `.env` is invalid: `config_ok=false`, `config_error=<reason>`, default `SCAN_ROOT`, no
  notification, exit 0 (status reports problems; it doesn't raise them).
- `agent_loaded`: exit code of `launchctl print gui/<uid>/xyz.osteiner.scan-intake`.
- `last_run` / `last_success`: from the current log only (`run_start` / `success` lines);
  `null` when absent.
- Without `--json`: a short human summary (counts, last success, failed files).

Tests (`tests/status.bats`): valid JSON (`jq -e .`); counts match a prepared tree; failed entry
carries the first line of `.error`; file name with `"` survives; pending age from `.task` mtime;
`last_success` parsed from a prepared log (`doc` is a JSON number; file name with a space);
nulls without a log; paths and `SCAN_ROOT` override; invalid or missing `.env` →
`config_ok=false`, exit 0, no notification; **no curl calls**; no log writes; nothing moved;
`agent_loaded` follows the launchctl stub; plain `status` is non-JSON and names failed files;
no argument still means `--once`.

### [phase-8.3] `retry <file|all>`

- Moves `failed/<file>` back to outbox and deletes `failed/<file>.error`. `all` = every file in
  failed/ (not the `.error` files).
- Logs `INFO requeued file="…"`; prints `requeued <file>`.
- Unknown file, a `.error` name, a path with `/`, or a file only in duplicates/ → message on
  stderr naming the argument, exit 2. No argument → usage on stderr containing
  `retry <file|all>`, exit 2. Empty failed/ with `all` → `nothing to retry`, exit 0.
- If the name already exists in outbox, use `file_into`'s timestamp-prefix rule.
- Never uploads, never touches duplicates/.

Tests (`tests/retry.bats`): single file moved and `.error` gone, others untouched; `all`;
`nothing to retry`; the exit-2 cases above; no curl calls; name with spaces and quotes; collision
in outbox (existing file kept, retried one as `<n>-x.pdf`).

Not covered (decide when implementing; not tested): `retry` with an invalid `.env`. Suggested:
fall back to the default `SCAN_ROOT`, like `status`.

### Verification
```bash
cd ~/dotfiles/common-macos/scan-intake
shellcheck scan-intake
bats tests/
```

---

## Phase 9 — SwiftBar plugin, clickable notifications, health check

**Intent.** Make the pipeline visible and actionable without opening a terminal. Everything calls
the phase 8 subcommands.

### [phase-9.1] SwiftBar plugin

File: `common-macos/swiftbar/.config/swiftbar/scan-intake.1m.sh` (executable, xbar metadata
header like `tailscale.10s.sh`). It calls `$HOME/.local/bin/scan-intake status --json` and `jq`.

- **PATH**: append system dirs after the inherited `PATH`
  (`PATH="$PATH:/usr/bin:/bin:/opt/homebrew/bin"`), unlike the tailscale plugin, which prepends
  them. Prepending would bypass the test stubs.
- Menu-bar line: an SF Symbol (`sfimage=doc.viewfinder`), plus `outbox+pending` count when > 0.
  Red (`sfcolor=red`) when failed > 0, `config_ok=false` or `agent_loaded=false`.
- Dropdown:
  - Config error or agent not loaded, as a first line, when present.
  - Last upload: `<file> → #<doc>` (relative time), linking to
    `<paperless_url>/documents/<doc>/details`.
  - Outbox N, Pending N, Failed N. Failed has a submenu: one entry per file (with its error),
    each with a "Retry" action (`bash=… param1=retry param2=<file> terminal=false refresh=true`).
  - Retry all failed, Run now (`launchctl kickstart`), Run selftest (`terminal=true`).
  - Open: Scans folder, failed/, log, paperless.
- If `scan-intake` isn't installed: one line "scan-intake not installed".

Tests (`tests/swiftbar.bats`; `$HOME/.local/bin/scan-intake` symlinked to the repo script in the
temp `$HOME`). Output contract they pin:
- Line 1 is the menu-bar line; the dropdown is everything after the first `---`.
- Config error text is the **first** dropdown line; "not loaded" appears when the agent isn't.
- Failed files appear on `--` (submenu) lines with their error text.
- Retry: `bash=<$HOME/.local/bin/scan-intake> param1=retry param2=<file> terminal=false refresh=true`;
  names with spaces are quoted as `param2="Rechnung Mai.pdf"`. Retry all: `param2=all`.
- Run now: `bash=<…launchctl> param1=kickstart param2=gui/<uid>/xyz.osteiner.scan-intake`.
- Run selftest: `param1=--selftest terminal=true`.
- Last upload line contains `#<doc>`, the file name and
  `href=<paperless_url>/documents/<doc>/details`; no such link without a log.
- The dropdown contains the Scans path, the failed/ path, the log path and `href=<paperless_url>`.
- Without the symlink: a "not installed" line, exit 0. No curl calls; nothing moved.
- An agent-not-loaded test only passes if the plugin keeps the stub `launchctl` first on `PATH`,
  which is how the append-not-prepend `PATH` rule is enforced.

### [phase-9.2] Clickable notifications

`notify()` gains an optional click target. With `terminal-notifier` on `PATH`:
`terminal-notifier -title "Scan intake" -subtitle <sub> -message <body> [-sound Basso] [-open <url>] -group scan-intake-<n>`.
If `terminal-notifier` exits non-zero, fall back to `osascript` for that notification.

| Event | Click opens |
|---|---|
| Uploaded | `<PAPERLESS_URL>/documents/<id>/details` |
| Duplicate | the existing document's details page |
| Error / 413 / no result | `file://<SCAN_ROOT>/failed/` |
| Config error | `file://<LOG>` (shows the reason in Console) |
| Summary | failed/ if any errors, otherwise `<PAPERLESS_URL>` |
| Waiting | nothing |

Arguments go through argv, so the AppleScript escaping doesn't apply; the body must still arrive
verbatim (quotes, backslashes, a leading `-`).

Tests (`tests/notify-click.bats`): a `terminal-notifier` stub in a **separate** dir
(`tests/stubs-tn/`), added to `PATH` only by these tests via a helper. Otherwise every existing
`notify.bats` test would switch notifier and break; they stay as the osascript-fallback coverage.
Cases: Uploaded → `-title "Scan intake" -subtitle Uploaded -message "a.pdf → document #6342"
-open …/documents/6342/details`, no osascript call, no `-sound`; Duplicate → existing id; Error and
413 → `-sound Basso`, `-open file://<SCAN_ROOT>/failed` (trailing `/` optional); Config error →
`-open file://<LOG>`; Summary → `<PAPERLESS_URL>` (failed/ if errors); Waiting → no `-open`; two
notifications in one run get two different `-group` values; a body like `-x "q".pdf → …`
arrives verbatim (no AppleScript escaping); stub exits 1 → osascript fallback for that
notification.

Manual: the first terminal-notifier notification needs permission in System Settings →
Notifications. Document it in the README.

### [phase-9.3] Weekly health check

`scan-intake health`: runs the selftest checks quietly, plus:
- failed/ is not empty;
- an outbox file older than 1 h (stuck or offline);
- the main agent isn't loaded (`launchctl print`).

All OK → log `INFO health ok`, no notification, exit 0. Otherwise one notification
(subtitle "Health check", Basso, body lists the problems, click opens failed/ or the log), log
`WARN health problems=N`, exit 1. Don't check "last run time" from the log: after a weekend
asleep it would always be old.

Second LaunchAgent `xyz.osteiner.scan-intake.health` from `scan-intake-health.plist.in`:
`ProgramArguments [<script>, health]`, `StartCalendarInterval {Weekday 1, Hour 9, Minute 0}`,
same log and `PATH` as the main agent, no `RunAtLoad`.

`install.sh`: render and bootstrap the health agent **before** the main agent. The existing test
"install twice: second run boots out the old agent before bootstrapping" checks that the last
bootout/bootstrap pair belongs to the main label. `uninstall.sh` boots out and removes both.

Tests (`tests/health.bats`, plus additions to `install.bats`): all OK → exit 0, no notification,
`INFO health ok`, no selftest `ok` lines on stdout; failed/ file → exit 1, exactly one
notification (subtitle "Health check", Basso, mentions "failed"), `WARN health problems=1`; outbox
file older than 1 h (mentions "outbox"), a fresh one is fine; health never uploads; agent not
loaded (mentions "not loaded"); selftest failure (mentions "401"); invalid `.env` → still **one**
notification, the Health check one, containing the reason; two problems → one notification,
`problems=2`; with terminal-notifier, failed/ problems open failed/, others open the log.
`install.bats`: template exists; health plist lints; `ProgramArguments` = main script + `health`;
`StartCalendarInterval` Weekday 1 / Hour 9 / Minute 0 as a dict; `RunAtLoad` absent or false;
same log and `PATH`; health bootstrapped before main; on reinstall health is booted out before
its bootstrap; uninstall boots out and removes it.

### [phase-9.4] README

Tests (`install.bats`): README mentions SwiftBar, `terminal-notifier`, `scan-intake health`, and
the events `rejected`, `requeued`, `skipped`, `stale_lock`, `health`.

Plugin (what it shows, that it lives in the swiftbar package), clickable notifications
(`brew install terminal-notifier`, notification permission), health check (schedule, how to run
it by hand), new subcommands and log events (`rejected`, `requeued`, `skipped`, `stale_lock`,
`health`).

### Verification
```bash
cd ~/dotfiles/common-macos/scan-intake
shellcheck scan-intake install.sh uninstall.sh ../swiftbar/.config/swiftbar/scan-intake.1m.sh
bats tests/
```

Live check (with the user): rerun `install.sh`; plugin visible and counts right; a forced failure
(e.g. a `.txt` renamed to `.pdf`) shows red, Retry moves it back; clicking an Uploaded
notification opens the document; `scan-intake health` by hand with a file in failed/ notifies.

## Open items outside this plan

- Phase 5 test documents still in paperless: 6896, 6897, 6899–6905, 6907 (delete + empty trash).
- The server fix commit in the server host's dotfiles clone is not pushed yet.
- duplicates/ is never cleaned up (done/ has 180-day retention). Not in scope unless you want it.
- **Pi-hole password committed in the repo** (found 2026-10-22):
  `common-macos/swiftbar/.config/swiftbar/pihole.30s.sh` has the real password as the
  `PIHOLE_PASSWORD` default. It is pushed to `origin` (`dotfiles-public`, a **public** GitHub
  repo, commit c59993e), so treat it as leaked. Fix: change the password on the Pi-hole (the old one stays in git
  history), have the plugin read it from a mode-600 file kept in `~/dotfiles-secrets` (or the
  environment) instead of a default, and leave history alone unless you decide to rewrite it.
  Unrelated to scan-intake; its own small task.
