# Scan intake on the Mac: implementation plan

Handoff for a coding agent (Claude Code, `/implement <this file>`). Read `SCANNER-INTAKE.md`
(same folder) first: it describes the paperless-ngx server, the API, and what the server does
with each file. This plan covers only the Mac side. Do not change anything on the server.

`SCANNER-INTAKE.md` suggests storing the token in the Keychain. This plan overrides that: the
token goes in a `.env` file (see "Decisions").

## Where things live

| What | Path |
|---|---|
| Code | `~/dotfiles/common-macos/scan-intake/` |
| Tests (written, failing) | `~/dotfiles/common-macos/scan-intake/tests/*.bats` |
| Test stubs | `tests/stubs/{curl,osascript,launchctl}`, shared setup in `tests/helpers.bash` |
| This plan | `~/dotfiles/docker/paperless-ngx/SCAN-INTAKE-MAC-PLAN.md` |
| Phase reports | `~/dotfiles/.agent/reports/NNN-phase-N-end.md` (next free number: 002) |
| Installed script | `~/.local/bin/scan-intake`, a symlink to the repo copy (same as `borders-ctl`) |

`common-macos/scan-intake/` is **not** a stow package. It has its own `install.sh`, because it
needs a rendered plist and a launchctl bootstrap, which stow can't do. Don't add it to the
repo-level `~/dotfiles/install.sh` (a non-regression test checks this).

Final layout:

```
common-macos/scan-intake/
  scan-intake               the script (bash, executable)
  scan-intake.plist.in      LaunchAgent template
  install.sh  uninstall.sh
  .env.example              token empty; .env itself is ignored by the repo .gitignore
  README.md                 install, ScanSnap Home profile, troubleshooting
  tests/
    helpers.bash  stubs/
    config.bats logging.bats selftest.bats            phase 1
    outbox.bats upload.bats results.bats notify.bats  phase 2
    errors.bats network.bats pending.bats housekeeping.bats  phase 3
    install.bats                                      phase 4
```

### Running the tests

Dev-only dependencies: `brew install bats-core shellcheck` (already installed on the MacBook).

```bash
cd ~/dotfiles/common-macos/scan-intake
bats tests/                    # everything
bats tests/config.bats         # one file
bats -f 'duplicate' tests/     # by name
```

Each test runs with a throwaway `$HOME` in `$BATS_TEST_TMPDIR`. `PATH` starts with
`tests/stubs/`, so `curl`, `osascript` and `launchctl` are fakes: no network, no real
notifications, and launchd is never touched. The curl stub answers from fixture files that
`helpers.bash` writes (`stub_upload_ok`, `stub_task`, `stub_http`, `stub_transport_error`). It
logs every call's argv to `curl.log` and its stdin to `curl.stdin`.

Before implementation, 121 of the 123 tests fail (the script doesn't exist). The 2 that pass
are the NON-REGRESSION anchors in `install.bats`. While a phase is in progress, tests from
later phases are expected to fail, so run only the current and earlier phases' files (see each
phase's Verification block).

## Decisions (already made, don't revisit)

| Topic | Decision |
|---|---|
| Transport | REST API only: `https://paperless.osteiner.xyz/api/documents/post_document/`. No NFS, no LAN URL by default. |
| Language | One **bash** script. Dependencies: `curl`, `jq` (`/usr/bin/jq` ships with macOS 15+; it's present on macOS 27). No Python, no daemon. |
| Trigger | A user **LaunchAgent** with `WatchPaths` on the outbox, plus `StartInterval` 900 s for retries, plus `RunAtLoad`. |
| Token / config | A `.env` file at `~/.config/scan-intake/.env`, **outside the repo**, mode `600` (see "Config"). No Keychain. |
| Folder | `~/Scans/` (not Desktop, Documents, Downloads or iCloud: those are TCC-protected and launchd jobs fail silently there). |
| Created date | Never let the scan date become the document date (see "Filename handling"). |
| Notifications | macOS notifications (`osascript display notification`) for **every uploaded scan and every problem** (see "Notifications"). |
| Logging | Always on: `~/Library/Logs/scan-intake.log`, one line per event, size-rotated. |
| Code location | `~/dotfiles/common-macos/scan-intake/`, own installer, not stowed (decided 2026-10-20). |
| Tests | bats-core, stubbed `curl`/`osascript`/`launchctl`, temp `$HOME` (decided 2026-10-20). |
| Platform | macOS only. Use BSD tools: `stat -f %Lp`, `date -v`, `sed -i ''`. BSD `date` has no `%:z`, so the timezone offset may be `+0200`; the tests accept `+0200` and `+02:00`. |

## Contracts the tests pin down

The tests depend on these details. They were left open in the earlier version of this plan, so
they're listed here in one place.

**Test seams**
- Every path comes from `$HOME`: `.env`, the `SCAN_ROOT` default, the log, LaunchAgents and
  `~/.local/bin`. Never hard-code `/Users/...`.
- Call external commands by name through `PATH` (`curl`, `jq`, `osascript`, `launchctl`, `git`,
  `plutil`), never as `/usr/bin/curl`. The stubs only work through `PATH` lookup.
- New `.env` key **`STABLE_SECS`** (default 5): the stability window. The tests set it to 0.

**curl call shape** (the stub parses exactly this)
- The URL is a plain positional argument. The body is written with `-o <file>`. The status is
  read with `-w '%{http_code}'`.
- Headers (`Authorization: Token …` and `Accept: application/json; version=N`) go on stdin via
  `-H @-`. The token must never appear in argv.
- The upload uses `--fail-with-body --connect-timeout 10 --max-time 600` and
  `-F "document=@<path>;filename=<name>"`. A curl exit code of 6, 7 or 28 means a network error.
  Exit 22 with a status code means an HTTP error.

**Exit codes**: `0` normal (including per-file failures). `1` config error: `.env` missing,
empty token, permissions looser than 600, or HTTP 401/403. `--selftest` returns 0 for pass and
1 for fail.

**Log lines**: `<ISO-ts> <LEVEL padded to 5> <event> key=value...`, with keys in this order:

| Event | Level | Keys |
|---|---|---|
| `run_start` | INFO | `outbox=N pending=N` (logged **after** `.env` loads, so the counts use `SCAN_ROOT`) |
| `config_error` | ERROR | `reason="..."` |
| `uploaded` | INFO | `file="…" task=<uuid> via=public\|lan` |
| `success` | INFO | `file="…" doc=<id> secs=N` |
| `duplicate` | WARN | `file="…" existing=<id>` |
| `failed` | ERROR | `file="…" http=<code>` or `file="…" reason="…"` |
| `pending` | WARN | `file="…" task=<uuid>` |
| `network_error` | WARN | `file="…" curl=<exit code>` |
| `deleted` | INFO | `file="…"` (done/ retention) |

**API fields**: success doc id = `.[0].related_document`. Duplicate id =
`.[0].duplicate_documents[0].id`. That field's shape (`[{id, title, ...}]`) is assumed; confirm it
in phase 5. When `duplicate_documents` is empty, fall back to the `#NNNN` in `result`.

**Other**
- Notification AppleScript form: `display notification "<body>" with title "Scan intake"
  subtitle "<subtitle>"`, adding ` sound name "Basso"` for errors.
- More than 5 notifications in one run → **exactly one** summary notification ("7 scans
  uploaded", "12 scans uploaded, 1 error"). 5 or fewer → one per file.
- LAN fallback: after uploading via the LAN, poll that task on the LAN URL too.
- The "pending > 24 h" check uses the `.task` file's mtime.
- `--dry-run`: no POST, no moves, no deletions. It prints `would upload <file>` per file to
  stdout and exits 0.

## Folder layout

```
~/Scans/
  outbox/       ScanSnap Home saves here; the script watches it
  pending/      uploaded, task not finished at timeout; <file> + <file>.task (task UUID)
  done/         confirmed in paperless; files older than 180 days are deleted
  duplicates/   rejected by paperless as duplicate
  failed/       other failures; <file> + <file>.error (server message / HTTP code)
~/.config/scan-intake/.env          token + overrides (mode 600, never committed)
~/Library/Logs/scan-intake.log      rotated at 5 MB to scan-intake.log.1 (keep 3)
```

## Script specification: `scan-intake` (single file, ~150–250 lines)

### Config

Defaults live at the top of the script. Values in `~/.config/scan-intake/.env` override them.

```
PAPERLESS_TOKEN=            # required; the user fills this in, the agent never sees it
PAPERLESS_URL=https://paperless.osteiner.xyz
SCAN_ROOT=$HOME/Scans
API_VERSION=9
POLL_TIMEOUT=300
POLL_INTERVAL=5
STABLE_SECS=5
DONE_RETENTION_DAYS=180
NOTIFY_SUCCESS=true
LAN_FALLBACK_URL=           # empty = disabled; optional http://192.168.1.206:8000
```

`LAN_FALLBACK_URL` is used only when the public URL fails with a curl connect, resolve or
timeout error.

Loading the file:
- **Do not `source` it.** Parse `KEY=VALUE` lines against a whitelist of the keys above,
  ignoring comments (including indented ones) and blank lines, so the file can't execute code.
  Keys outside the whitelist (for example `PATH`) are ignored. Values are literal: `$(...)` and
  backticks are never expanded.
- Refuse to run (notify "Config error" + log `config_error` + exit 1) if the file is missing,
  the token is empty, or the file permissions are looser than `600`. The message should say how
  to fix it (for permissions: `chmod 600 ~/.config/scan-intake/.env`).

### Run sequence (each invocation)

1. `set -euo pipefail`. Load `.env`; if it's invalid, notify and exit 1.
2. Create the folders if missing, then log `run_start`.
3. **Re-check pending/**: for each `*.task`, query the task. On a final status, file it as in
   step 6 and remove the `.task`. If it's still running, leave it. If the `.task` is older than
   24 h, move the file to failed/ with `.error` = "no result from paperless" and notify. A `.task`
   whose file has vanished must not crash the run.
4. **Process outbox/**: for each regular file with extension pdf/jpg/jpeg/png/tif/tiff (skip
   dotfiles, `._*` and directories):
   - **Stability check**: size and mtime unchanged over `STABLE_SECS`. If not, skip (the next
     trigger will catch it).
   - **Upload** (see "Filename handling" and "curl call shape").
   - HTTP 401/403: notify "Config error" (token rejected), leave the file in outbox, **stop the
     run**, exit 1.
   - HTTP 413: move to failed/, `.error` = "too large for reverse proxy".
   - Network error (curl 6/7/28): try `LAN_FALLBACK_URL` if set. Otherwise leave the file in
     outbox, log `network_error`, and continue with the next file. If any file affected this way
     has waited more than 1 h (mtime), send one "Waiting" notification per run.
   - Other HTTP errors: failed/, with the response body in `.error`.
   - On success the response is a JSON string (task UUID): `jq -r .`.
5. **Poll** `GET /api/tasks/?task_id=<uuid>` (it returns an array; use `.[0]`) every
   `POLL_INTERVAL` until `status` is `SUCCESS` or `FAILURE`, or until `POLL_TIMEOUT`. On timeout,
   move the file to pending/ and write its `.task` file, then log `pending`.
6. **File the result**:
   - `SUCCESS`: move to done/, then notify success.
   - `FAILURE` with `duplicate_documents` non-empty or `result` matching `/duplicate/i`:
     move to duplicates/, then notify duplicate.
   - `FAILURE` otherwise: move to failed/ with a `.error` file containing `result`, then notify error.
7. Delete files in done/ older than `DONE_RETENTION_DAYS`, and log each deletion.
8. Rotate the log if it's larger than 5 MB (`.log` → `.log.1` → `.log.2` → `.log.3`; drop the oldest).
9. Send queued notifications (individually, or one summary if there are more than 5).

### Notifications

Use `osascript -e 'display notification "<body>" with title "Scan intake" subtitle "<subtitle>"'`.
Escape `\` and `"` in file names (`"` → `\"`). Add `sound name "Basso"` for errors only.

| Event | Subtitle | Body |
|---|---|---|
| Uploaded and confirmed (`NOTIFY_SUCCESS=true`) | Uploaded | original file name → document #id |
| Duplicate | Duplicate, skipped | file name + id of the existing document |
| Processing failure | Error | file name + first line of the server message |
| 413 too large | Error | file name: "too large for the reverse proxy" |
| Token rejected (401/403) / bad `.env` | Config error | what to fix |
| File waiting > 1 h (offline) | Waiting | "N scans queued, paperless unreachable" (once per run, not per file) |
| Pending task > 24 h | Error | file name: "no result from paperless" |

### Logging

Every run appends to `~/Library/Logs/scan-intake.log` (also visible in Console.app). Format and
event names: see "Contracts". Example:

```
2026-10-21T09:14:03+0200 INFO  run_start outbox=2 pending=0
2026-10-21T09:14:05+0200 INFO  uploaded file="20261021091350.pdf" task=b1ad602d-... via=public
2026-10-21T09:14:41+0200 INFO  success file="20261021091350.pdf" doc=6342 secs=36
2026-10-21T09:14:41+0200 WARN  duplicate file="old.pdf" existing=5120
2026-10-21T09:14:41+0200 ERROR failed file="x.pdf" http=413
```

Never log the token or full response headers. A `--verbose` flag adds DEBUG lines (HTTP codes,
poll attempts); without it there are no DEBUG lines. launchd's stdout and stderr go to the same
file, so unexpected crashes are captured as well. Never `set -x`.

### Filename handling (important)

The server sets the created date from a filename date (`FILENAME_DATE_ORDER=Y-M-D`), which
overrides the date found in the document. ScanSnap's default names contain the scan timestamp,
which would date every old letter "today". Rule:

- If the name matches `^[0-9]{4}-[0-9]{2}-[0-9]{2} - .+` (the user renamed it deliberately),
  upload it under its own name, with no `filename=scan…` and no title.
- Otherwise upload with a neutral filename and an explicit title, so paperless reads the date
  from the content: `-F "document=@$path;filename=scan.<ext>" -F "title=Scan $(date '+%Y-%m-%d %H.%M')"`.
  The title is not used for date parsing.
- Don't send tags, correspondent or type. Server auto-matching and the Inbox tag handle that.

### Behaviour constraints

- Idempotent and safe to run twice. launchd doesn't start a second instance of the same job,
  but don't rely on that alone: handle files disappearing mid-run.
- Never delete a file from outbox. Only move it, and only after a final server answer.
- Flags: `--once` (the default when no flag is given), `--selftest`, `--dry-run`, `--verbose`
  (combinable with the others).
- `--selftest` checks: `.env` is valid and mode 600; `.env` is not inside a git working tree
  (`git -C <dir> rev-parse`); `GET /api/tags/?page_size=1` returns 200; the five folders are
  writable; `jq` and `curl` are on `PATH`. It prints a summary, never uploads, and exits 0 or 1.

## LaunchAgent and installer

`~/Library/LaunchAgents/xyz.osteiner.scan-intake.plist`, rendered by `install.sh` from
`scan-intake.plist.in` with absolute paths (launchd does not expand `~`; the rendered file must
not contain `~`):

- `Label`: `xyz.osteiner.scan-intake`
- `ProgramArguments`: `[<absolute path to scan-intake>, --once]`
- `WatchPaths`: `[$HOME/Scans/outbox]`
- `StartInterval`: 900, `RunAtLoad`: true
- `StandardOutPath` / `StandardErrorPath`: the log file
- `EnvironmentVariables`: `PATH=/usr/bin:/bin:/usr/sbin:/opt/homebrew/bin`

`install.sh`:
1. If `~/.config/scan-intake/.env` doesn't exist: copy `.env.example` there, `chmod 600`, print
   a message asking the user to paste the token (web UI → My Profile → API Auth Token) and
   rerun, then exit non-zero **without** loading the agent. The agent must not read, write or
   echo the token.
2. Create the folders, symlink the script to `~/.local/bin/scan-intake`, and render the plist.
3. `launchctl bootout gui/$(id -u)/xyz.osteiner.scan-intake` (ignore errors, so reinstalling
   works), then `launchctl bootstrap gui/$(id -u) <plist>`.
4. Run `scan-intake --selftest`.

`uninstall.sh`: `launchctl bootout`, remove the plist and the `~/.local/bin` symlink, leave
`~/Scans` and `.env` alone.

---

# Phases

Every phase: run the phase's Verification block and paste its full output into the phase
report. Commit each task once its tests pass, as `[phase-X.Y] <what>`, with the why in the body.
Tests from earlier phases are the non-regression anchors for later phases. Never edit a test to
make it pass; stop and flag it instead.

## Phase 0 — Audit leftovers from earlier attempts (no code)

**Intent.** Mounting the NFS consume folder on this Mac was explored earlier. Anything left from
that attempt, or any other scan automation, could consume or move files in parallel with the new
script. This phase is **read-only until the user approves**. Out of scope: writing any of the
new code.

### [phase-0.1] Read-only audit

Check:
- Active mounts: `mount | grep -Ei 'nfs|smb|afp'` and `nfsstat -m`.
- Automount config: `/etc/auto_master`, any `/etc/auto_*` maps, `/etc/fstab`, `/etc/nfs.conf`.
  Look for `192.168.1.150`, `paperless`, `consume`.
- Leftover mount points: `/Volumes/paperless-consume` and other `/Volumes/*paperless*`, plus
  `/System/Volumes/Data/...` equivalents created via `/etc/synthetic.conf`.
- launchd jobs: `~/Library/LaunchAgents`, `/Library/LaunchAgents`, `/Library/LaunchDaemons`.
  Run `grep -ril 'paperless\|consume\|nfs\|scan'` over them, plus `launchctl list | grep -i scan`.
- Other automation: Folder Actions (`~/Library/Workflows/Applications/Folder Actions`, System
  Settings → Folder Actions), Automator/Shortcuts workflows, Hazel rules, cron (`crontab -l`),
  login items.
- Stale scripts and config in `~/bin`, `~/.local/bin`, `~/dotfiles`, `~/dotfiles-secrets` and
  shell rc files (`grep -ri '192.168.1.150\|paperless'`). Expected hits that are **not** leftovers:
  `~/dotfiles/docker/paperless-ngx/` and `~/dotfiles-secrets/docker/paperless-ngx/`.
- Saved credentials: Keychain entries mentioning `paperless` or `192.168.1.150` (list only; don't
  display secrets).
- Finder sidebar or Login Items entries pointing at the NFS share.

Output: `.agent/reports/002-phase-0-audit.md` with a table (item, location, active?, proposed
action). **Stop and wait for approval.**

### [phase-0.2] Cleanup (only after approval)

Back up before editing (e.g. `/etc/auto_master.bak-YYYYMMDD`). Unmount, remove the config lines,
then run `sudo automount -cv`. **The user runs every `sudo` step in their own Terminal; never
pipe a password through the chat.**

### Verification
Re-run every check from 0.1 and paste the output; it must be clean.

## Phase 1 — Config loading, logging, selftest

**Intent.** Build the script skeleton that everything else hangs on: flag parsing, the safe
`.env` parser, folder creation, the log writer, and `--selftest`. The key design decision is
**parsing `.env` against a whitelist instead of sourcing it**: the file sits in `$HOME` and
must not become a code-execution path. Out of scope: anything that touches outbox files beyond
counting them.

Tasks:
- [phase-1.1] Script skeleton: defaults, flag parsing (`--once` default, `--selftest`,
  `--dry-run`, `--verbose`), folder creation.
- [phase-1.2] `.env` loader: whitelist, literal values, mode check, missing or empty token →
  config error (notify + `config_error` log line + exit 1).
- [phase-1.3] Log writer (format and levels from "Contracts") and `run_start`.
- [phase-1.4] `--selftest`.

Tests (all NEW-BEHAVIOR / FAILURE-MODE, failing now):
- `tests/config.bats` — missing/empty-token/644 `.env`; no execution of `$(...)`, backticks or
  bare commands; `PATH` not overridable; comments; `SCAN_ROOT` override; folder creation; no
  flag = `--once`.
- `tests/logging.bats` — `run_start` format, levels, append-not-truncate, `config_error`.
- `tests/selftest.bats` — pass case; `/api/tags/?page_size=1`; `API_VERSION` header; 401; mode
  644; `.env` inside a git tree; non-writable folder; never uploads; prints a summary.

### Verification
```bash
cd ~/dotfiles/common-macos/scan-intake
shellcheck scan-intake
bats tests/config.bats tests/logging.bats tests/selftest.bats
```

## Phase 2 — Upload, poll, file the result, notify (happy path)

**Intent.** Make a scan dropped in outbox end up in paperless and in done/ (or duplicates/ or
failed/), with a notification. The key design decision is the **neutral filename** for
ScanSnap-named files, so paperless takes the date from the content and not from the scan
timestamp. Out of scope: HTTP errors other than task FAILURE, network failures, pending/
re-checks and retention (phase 3).

Tasks:
- [phase-2.1] Outbox scan: extension filter, skip dotfiles/`._*`/directories, stability check.
- [phase-2.2] Upload request: curl call shape, headers on stdin, filename/title rule, `uploaded` log.
- [phase-2.3] Task polling and filing: done/duplicates/failed + `.error`, timeout → pending/ + `.task`.
- [phase-2.4] Notifications: per event, AppleScript escaping, Basso for errors, summary when >5.

Tests (NEW-BEHAVIOR / FAILURE-MODE, failing now):
- `tests/outbox.bats` — accepted extensions; `.txt`, dotfiles, `._*`, directories skipped;
  growing file skipped; stable file uploaded; spaces and quotes in names.
- `tests/upload.bats` — endpoint; `filename=scan.pdf`/`scan.jpg`; title; dated names kept;
  no-separator date is neutral; no tags; token not in argv, token on stdin, token not in log;
  curl flags; `--verbose` DEBUG lines.
- `tests/results.bats` — SUCCESS → done/ + log lines; tasks query; duplicates via
  `duplicate_documents` and via `result` text; other FAILURE → failed/ + `.error`; exit 0;
  timeout → pending/ + `.task`; second run doesn't re-upload.
- `tests/notify.bats` — Uploaded/Duplicate/Error bodies; `NOTIFY_SUCCESS=false`; Basso only for
  errors; quote escaping; 5 → 5 notifications; 7 → 1 summary; 7 success log lines.

NON-REGRESSION: all phase 1 files.

### Verification
```bash
cd ~/dotfiles/common-macos/scan-intake
shellcheck scan-intake
bats tests/config.bats tests/logging.bats tests/selftest.bats \
     tests/outbox.bats tests/upload.bats tests/results.bats tests/notify.bats
```

## Phase 3 — Failure modes and housekeeping

**Intent.** Make the script behave correctly when things go wrong: a rejected token, an
oversized file, a server error, being offline, a task that never finishes. Also add
housekeeping (retention, log rotation) and `--dry-run`. The key design decision is
**separating network errors from HTTP errors**. A network error leaves the file in outbox for
the 900 s retry and is the only case that triggers the LAN fallback. An HTTP error is a final
answer. Out of scope: installer and launchd (phase 4).

Tasks:
- [phase-3.1] HTTP 401/403 (stop the run, exit 1), 413, other 4xx/5xx.
- [phase-3.2] Network errors, LAN fallback (upload and poll on the LAN), "Waiting" notification.
- [phase-3.3] pending/ re-check at the start of each run, 24 h expiry, vanished files.
- [phase-3.4] done/ retention, log rotation (keep 3), `--dry-run`.

Tests (NEW-BEHAVIOR / FAILURE-MODE, failing now):
- `tests/errors.bats`, `tests/network.bats`, `tests/pending.bats`, `tests/housekeeping.bats`.

NON-REGRESSION: all phase 1 and 2 files.

### Verification
```bash
cd ~/dotfiles/common-macos/scan-intake
shellcheck scan-intake
bats tests/config.bats tests/logging.bats tests/selftest.bats \
     tests/outbox.bats tests/upload.bats tests/results.bats tests/notify.bats \
     tests/errors.bats tests/network.bats tests/pending.bats tests/housekeeping.bats
```

## Phase 4 — LaunchAgent, installer, README

**Intent.** Make the script run by itself after every scan. The key design decision is
**rendering the plist at install time** with absolute paths: launchd doesn't expand `~`, and
the repo must not contain `/Users/oliversteiner`. Out of scope: running the installer for real
on this Mac (phase 5) and the ScanSnap Home settings themselves (the user does that).

Tasks:
- [phase-4.1] `.env.example` (empty token, every key with its default) and `scan-intake.plist.in`.
- [phase-4.2] `install.sh` and `uninstall.sh`, as specified in "LaunchAgent and installer".
- [phase-4.3] `README.md`: install/uninstall, where the token comes from, folder layout, log
  location, troubleshooting (`launchctl print gui/$(id -u)/xyz.osteiner.scan-intake`), and the
  ScanSnap Home profile:
  - Save to: `~/Scans/outbox`
  - Format: PDF; one scan session = one file
  - Image quality: 300 dpi (Superfine), colour mode auto
  - Blank page removal on, auto rotation and deskew on
  - **Searchable PDF / OCR: off** (the server OCRs in deu+eng+fra+por; scanner OCR would block that)
  - File name: default (the script neutralises it); post-scan viewer or app: none

Tests:
- `tests/install.bats` NEW-BEHAVIOR / FAILURE-MODE: `.env.example` token empty; first install
  without `.env` (copy, 600, message, no bootstrap); folders; `plutil -lint`; plist keys and
  absolute paths; symlink; bootstrap command; selftest run; reinstall boots out first; uninstall
  removes plist and symlink and keeps `~/Scans` and `.env`.
- `tests/install.bats` **NON-REGRESSION** (pass now, must keep passing): `.env` in the tool dir is
  git-ignored; the repo-level `install.sh` doesn't mention scan-intake.

### Verification
```bash
cd ~/dotfiles/common-macos/scan-intake
shellcheck scan-intake install.sh uninstall.sh
bats tests/
```

## Phase 5 — Live end-to-end test (with the user)

**Intent.** The bats suite proves the logic against stubs. This phase proves it against the
real paperless server, ScanSnap Home and launchd. The user runs `install.sh` and pastes the
token; the agent never sees it. Report each result. Out of scope: fixing server-side problems
(report them instead).

0. The phase 0 audit checks are still clean.
1. `scan-intake --selftest` passes. With `.env` set to `chmod 644`, the script refuses to run
   and notifies.
2. A 1-page scan via ScanSnap: done/ within about a minute; the document is in paperless with
   OCR text and the Inbox tag; Mac "Uploaded" notification and phone ntfy received; created
   date = the date in the content (not today); log line `success` with the doc id.
3. The same file copied into outbox again: duplicates/, "Duplicate" notification, nothing new in
   paperless. **Confirm the `duplicate_documents` shape** in the log/`--verbose` output matches
   the assumption in "Contracts"; if not, stop and report.
4. A file named `2026-01-15 - Test.pdf`: created date 2026-01-15.
5. The largest expected scan (~50 MB): no 413. If it fails, report it; don't work around it.
6. Wi-Fi off, scan, Wi-Fi on: the file stays in outbox and uploads on the next interval.
7. Wrong token in `.env`: "Config error" notification, file stays in outbox. Then restore the token.
8. Seven files dropped at once: one summary notification; the log contains all seven.
9. Reboot: the agent is loaded (`launchctl print gui/$(id -u)/xyz.osteiner.scan-intake`).
10. Ask the user to delete the test documents in paperless and empty the trash.

Commit: `[phase-5.1] live end-to-end report` (the report only; no code changes unless a bug
was found, in which case: a failing bats test first, then the fix, as its own `[phase-5.2]`).

## Phase 6 — Propose next features (no code)

Once all tests pass, **don't build anything more**. Present this list to the user with a rough
effort estimate for each (S/M/L) and a recommended order, and let them choose. Keep the script
the single source of truth: every UI below should call `scan-intake` subcommands rather than
reimplementing the logic. That means first adding machine-readable subcommands (`status --json`,
`retry <file|all>`, `open-failed`).

| # | Feature | What it gives | Effort |
|---|---|---|---|
| 1 | **SwiftBar plugin** (already installed; plugins live in `common-macos/swiftbar/`) | Menu-bar icon with outbox/pending/failed counts, last upload, actions: retry failed, open folders, open log, run selftest | S |
| 2 | **Raycast script commands** (already installed) | "Scan intake status", "Retry failed scans", "Open paperless Inbox" from the launcher | S |
| 3 | **Clickable notifications** via `terminal-notifier` (Homebrew) | Clicking "Uploaded" opens the document in paperless (`/documents/<id>/details`); clicking an error opens failed/ | S |
| 4 | **Title/date prompt before upload** (optional mode) | A small `osascript` dialog lets the user type a title or document date before upload; skipped after a timeout so the pipeline is never blocked | S–M |
| 5 | **AI suggestions in the notification** | After success, call `GET /api/documents/<id>/ai_suggestions/` and show the suggested title and correspondent; optionally apply on one click | M |
| 6 | **Native menu-bar app** (SwiftUI `MenuBarExtra`) | Same as #1 but self-contained: queue view, drag-and-drop a PDF onto the icon to upload, per-file status and retry. Wraps the bundled script (in `Contents/Resources`) instead of rewriting it; registers its own agent via `SMAppService`, replacing `install.sh`; settings window for token (Keychain) and folder. As a signed app with its own identity it can be granted `~/Documents` access. Local ad-hoc signing is enough for this Mac; other Macs need notarisation (paid developer account). Do #1 first. | L |
| 7 | **Small GUI / dashboard** | A window or local web page with the upload history parsed from the log (searchable, links to documents), weekly counts | M–L |
| 8 | **Drop-anywhere upload** | Finder Quick Action / Services menu "Send to paperless" for any PDF, using the same script | S |
| 9 | **iPhone path** | An iOS Shortcut that uploads a ScanSnap Connect scan (or any PDF) via the same API, for scans made away from the Mac | S–M |
| 10 | **Health check** | A weekly launchd job: selftest + "nothing stuck in failed/pending"; notifies only if something is wrong | S |
| 11 | **Better titles from ScanSnap** (found in phase 5) | Strip ScanSnap's `ddMMyyyy_` prefix and send the rest as `title`. Keep dates out of any filename sent: since the server fix, paperless parses separated dates in filenames (YMD). Titles carry ScanSnap OCR typos; #5 is the follow-on | S |
| 12 | **German documents: summary + translation as a Note** (server-side, not in this script) | A server job (workflow webhook or cron, not a post-consume script) finds new German documents, asks the existing hosted LLM for a short summary (sender, what, action, deadline, amount) plus a full translation, saves it as a Note and tags the document; optional backfill of the archive. Try document chat on demand first. Belongs in a separate server plan | M (server) |

## Out of scope for this plan

Server changes, NFS/SMB mounts, auto-tagging on the Mac, and everything in phase 6.

## Resolved questions

1. Repo and path: `~/dotfiles/common-macos/scan-intake/`, not stowed (2026-10-20).
2. `jq`: `/usr/bin/jq` is present (macOS 27.0.1); Homebrew isn't needed.
