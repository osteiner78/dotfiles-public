# Phase 10 end: scan-intake review fixes

Plan: `.agent/plans/002-scan-intake-review-fixes.md`. Source review: `011-code-review-scan-intake.md`.

## What was built

- **10.1 (R1)**: `upload` now also quotes a title starting with `<` or `@`, so curl sends it as text
  and doesn't read a file. `a <b> c` stays unquoted. The curl fake (exit 26) was already in place.
- **10.2 (R3)**: "no HTTP answer" (e.g. curl 35) and "no task id in response" now log
  `WARN upload_error file="…" reason="…"` instead of `ERROR failed`. Nothing else changed. Added to the
  README event list and the Contracts table in `SCAN-INTAKE-MAC-PLAN.md`.
- **10.3 (R4)**: `health_cmd` and `pending_entries` **skip** an entry when its `stat` fails
  (`mtime=$(stat -f %m … 2>/dev/null) || continue`). I chose that over the `|| echo "$now"`
  fallback: a vanished file isn't stuck in outbox, and status shouldn't list a pending file that
  is gone.
- **10.4 (R5 + missing test 6)**: the lock counts as held only when `kill -0` succeeds **and**
  `ps -p "$pid" -o command=` contains `scan-intake`. A stale lock is renamed to `.lock.stale.$$`
  before `rm -rf`, then `mkdir`. If that `mkdir` fails, the run logs `skipped` and returns 1.
- **10.5 (R2)**: `SCAN_ROOT` is out of the `load_env` whitelist and `.env.example`. It's always
  `$HOME/Scans`.
- **10.6 (R6, R8, R7)**: `count_outbox` deleted and `run_start` uses `count_scans outbox`. The plugin
  uses `base64 | tr -d '\n'`. CLAUDE.md gained the gotchas (curl `<`/`@`, `$(selftest)` subshell,
  lock liveness, `rotate_log` vs launchd's open fd, `SCAN_ROOT` fixed) and a pointer to plan 002.
  README and CLAUDE.md had no `SCAN_ROOT` override to remove.

## Verification

```
$ cd ~/dotfiles/common-macos/scan-intake
$ shellcheck scan-intake install.sh uninstall.sh ../swiftbar/.config/swiftbar/scan-intake.1m.sh
(no output, rc=0)
$ bats tests/
1..268
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
ok 11 .env SCAN_ROOT is ignored: ~/Scans is always used
ok 12 first run creates outbox, pending, done, duplicates and failed
ok 13 no flag behaves like --once
ok 14 API_VERSION=10: exits 1 with a config_error naming API_VERSION
ok 15 API_VERSION=10: Config error notification, nothing uploaded, scan stays in outbox
ok 16 NON-REGRESSION: API_VERSION=9 set explicitly is accepted
ok 17 401: file stays in outbox
ok 18 401: 'Config error' notification about the token
ok 19 401: exits 1 (treated as a config error)
ok 20 401: stops the run after the first file
ok 21 403: file stays in outbox and the run stops
ok 22 413: file moves to failed/ with 'too large for reverse proxy' in .error
ok 23 413: Error notification 'too large for the reverse proxy' with Basso
ok 24 413: logged as ERROR failed with http=413
ok 25 500: file moves to failed/ and .error holds the response body
ok 26 500 on one file does not stop the others
ok 27 401: logged as ERROR rejected with http=401, not as failed
ok 28 403: logged as ERROR rejected with http=403
ok 29 curl error without an HTTP answer (35): stays in outbox, WARN upload_error, no notification
ok 30 no task id in the response: stays in outbox, WARN upload_error
ok 31 NON-REGRESSION: 500 still logs ERROR failed and moves to failed/
ok 32 all OK: exit 0, no notification, logs INFO health ok
ok 33 all OK: the selftest's per-check lines are not printed
ok 34 a file in failed/: exit 1, one Health check notification with Basso
ok 35 a file in failed/: logs WARN health problems=1
ok 36 an outbox file older than 1 h is a problem
ok 37 a fresh outbox file is not a problem
ok 38 health never uploads or moves outbox files
ok 39 main agent not loaded is a problem
ok 40 a failing selftest check (token rejected) is a problem
ok 41 an invalid .env is reported in the one health notification
ok 42 two problems: still one notification, problems=2
ok 43 with terminal-notifier: a failed/ problem opens failed/ on click
ok 44 with terminal-notifier: other problems open the log on click
ok 45 an outbox file that vanishes mid-check doesn't crash health
ok 46 NON-REGRESSION: SCAN_ROOT in .env is ignored: a file in ~/Scans/failed is still found
ok 47 done/ file older than 180 days is deleted
ok 48 done/ deletion is logged
ok 49 done/ file younger than 180 days is kept (while an older one is deleted)
ok 50 DONE_RETENTION_DAYS from .env overrides 180
ok 51 log larger than 5 MB is rotated to scan-intake.log.1
ok 52 log rotation keeps 3 old logs
ok 53 log smaller than 5 MB is not rotated
ok 54 --dry-run: nothing is uploaded and the scan stays in outbox
ok 55 --dry-run: old done/ files are not deleted
ok 56 --dry-run: says what it would upload
ok 57 NON-REGRESSION: a .env inside the tool dir is git-ignored
ok 58 NON-REGRESSION: the repo's stow installer does not stow scan-intake
ok 59 .env.example ships with an empty token
ok 60 install without .env: copies .env.example to ~/.config/scan-intake/.env with mode 600
ok 61 install without .env: exits non-zero and tells the user to paste the token
ok 62 install without .env: does not load the LaunchAgent
ok 63 install with .env but an empty token: exits non-zero, asks for the token, does not load the agent
ok 64 install: exits 0, creates the scan folders
ok 65 install: renders a valid plist
ok 66 install: plist has the label, --once, and absolute paths (no ~)
ok 67 install: plist watches ~/Scans/outbox, runs every 900 s and at load
ok 68 install: plist sends stdout and stderr to the log and sets PATH
ok 69 install: symlinks the script into ~/.local/bin
ok 70 install: bootstraps the agent into gui/<uid>
ok 71 install: runs the selftest
ok 72 install twice: second run boots out the old agent before bootstrapping
ok 73 uninstall: boots out the agent and removes the plist
ok 74 uninstall: removes the ~/.local/bin symlink
ok 75 uninstall: leaves ~/Scans and .env alone
ok 76 .env.example warns that API_VERSION must stay 9
ok 77 the health plist template ships in the repo
ok 78 install: renders a valid health plist
ok 79 install: health plist runs '<script> health' with absolute paths (no ~)
ok 80 install: health plist fires Mondays at 09:00 and not at load
ok 81 install: health plist logs like the main agent and sets the same PATH
ok 82 install: bootstraps the health agent before the main agent
ok 83 install twice: the health agent is booted out before it is bootstrapped again
ok 84 uninstall: boots out the health agent and removes its plist
ok 85 README documents the SwiftBar plugin, terminal-notifier and the health check
ok 86 README lists the new log events
ok 87 .env.example no longer offers SCAN_ROOT
ok 88 README lists the upload_error event
ok 89 lock held by a live run: no upload, file stays, exit 0
ok 90 lock held by a live run: logs INFO skipped
ok 91 NON-REGRESSION: lock held by a live run: the other run's lock is left alone
ok 92 stale lock (owner gone): taken over, file uploaded, WARN stale_lock
ok 93 lock directory without a pid file counts as stale
ok 94 the lock is held during the upload and removed after a normal run
ok 95 the lock is removed after a run that stops on 401
ok 96 NON-REGRESSION: --selftest runs while a lock is held
ok 97 NON-REGRESSION: --dry-run runs while a lock is held
ok 98 lock pid alive but not scan-intake (reused after a crash): stale, taken over
ok 99 NON-REGRESSION: the test holder really looks like scan-intake to ps
ok 100 each run appends a run_start line with outbox and pending counts
ok 101 log lines use only the levels DEBUG, INFO, WARN and ERROR
ok 102 two runs append, they do not truncate
ok 103 with stderr appended to the log (as under launchd), 413 and offline errors add no raw curl lines
ok 104 config error is logged as ERROR
ok 105 connect error, no fallback: file stays in outbox and run exits 0
ok 106 resolve (6) and timeout (28) errors also leave the file in outbox
ok 107 connect error: logged as network_error with the curl exit code
ok 108 connect error on a fresh file: no notification
ok 109 files waiting more than 1 h: one 'Waiting' notification per run with the count
ok 110 LAN fallback: used when the public URL has a connect error
ok 111 LAN fallback: the task is polled on the LAN host it was uploaded to
ok 112 LAN fallback: not used for HTTP errors (500 goes to failed/)
ok 113 LAN fallback empty (default): the LAN host is never contacted
ok 114 Uploaded: sent via terminal-notifier, not osascript
ok 115 Uploaded: title, subtitle and message
ok 116 Uploaded: click opens the document in paperless
ok 117 Uploaded: no sound
ok 118 Duplicate: click opens the existing document
ok 119 Error: Basso, and click opens failed/
ok 120 413: click opens failed/
ok 121 Config error: Basso, and click opens the log
ok 122 Summary without errors: one notification, click opens paperless
ok 123 Summary with an error: click opens failed/
ok 124 Waiting: no click target
ok 125 every notification gets its own -group, so they don't replace each other
ok 126 no AppleScript escaping: inner quotes and backslashes arrive unchanged
ok 127 a message starting with - " ( [ or { is sent with a leading backslash
ok 128 a message starting with an ordinary character or ' is not escaped
ok 129 terminal-notifier failing: that notification falls back to osascript
ok 130 NON-REGRESSION: without terminal-notifier on PATH, osascript is used
ok 131 success: 'Uploaded' notification titled 'Scan intake' with file name and document id
ok 132 success: no error sound
ok 133 NOTIFY_SUCCESS=false: no notification on success
ok 134 duplicate: 'Duplicate, skipped' notification with the existing id
ok 135 processing failure: 'Error' notification with the first line of the message and Basso sound
ok 136 double quotes in the file name are escaped for AppleScript
ok 137 five files: five individual notifications
ok 138 seven files: one summary notification instead of seven
ok 139 seven files: the log still has all seven success lines
ok 140 pdf, jpg, jpeg, png, tif and tiff are uploaded
ok 141 other extensions (.txt) are left in outbox and not uploaded
ok 142 dotfiles are skipped
ok 143 AppleDouble ._ files are skipped
ok 144 a directory named like a pdf is skipped
ok 145 empty outbox: exits 0 without uploading
ok 146 a file still being written is skipped and stays in outbox
ok 147 a stable file is uploaded after the stability window
ok 148 file names with spaces and quotes are handled
ok 149 pending task now SUCCESS: file moves to done/ and the .task file is removed
ok 150 pending task now a duplicate FAILURE: file moves to duplicates/
ok 151 pending task still STARTED and fresh: file stays in pending/
ok 152 pending task still STARTED after 24 h: failed/ with 'no result from paperless'
ok 153 pending task still STARTED after 24 h: Error notification
ok 154 pending files are counted in run_start
ok 155 a .task whose file has disappeared does not crash the run
ok 156 a scan saved during an upload is uploaded in the same run
ok 157 NON-REGRESSION: the rescan stays inside one run: one run_start line
ok 158 a file left in outbox by a network error is attempted once per run
ok 159 the rescan stops after 3 passes even if every pass adds a file
ok 160 401 on a file found by the rescan stops the run and exits 1
ok 161 NON-REGRESSION: --dry-run lists outbox once and uploads nothing
ok 162 SUCCESS: file moves to done/
ok 163 SUCCESS: logs uploaded (task, via=public) and success (doc id)
ok 164 polls /api/tasks/?task_id=<uuid>
ok 165 FAILURE with duplicate_documents: file moves to duplicates/
ok 166 FAILURE with duplicate_documents: logs WARN duplicate with the existing id
ok 167 FAILURE whose result mentions 'Duplicate' (no duplicate_documents): duplicates/
ok 168 other FAILURE: file moves to failed/ with a .error file holding the result
ok 169 other FAILURE: run still exits 0
ok 170 task not finished within POLL_TIMEOUT: file and .task move to pending/
ok 171 task not finished within POLL_TIMEOUT: logged as pending
ok 172 running twice uploads each file only once
ok 173 retry <file>: moves it to outbox and deletes its .error
ok 174 retry <file>: prints 'requeued <file>' and logs INFO requeued
ok 175 retry <file>: leaves the other failed files alone
ok 176 retry all: moves every failed file and removes every .error
ok 177 retry all with nothing in failed/: 'nothing to retry', exit 0
ok 178 retry of an unknown file: exit 2, nothing moved
ok 179 retry without an argument: exit 2 with a usage line naming retry
ok 180 retry of a .error file: exit 2, nothing moved
ok 181 retry with a path outside failed/: exit 2, nothing moved
ok 182 retry never touches duplicates/
ok 183 retry makes no network calls
ok 184 retry handles spaces and double quotes in the name
ok 185 retry when the name already exists in outbox: both files kept
ok 186 NON-REGRESSION: retry works with an invalid .env (mode 644): uses ~/Scans
ok 187 retry ignores SCAN_ROOT in .env
ok 188 selftest: valid config and reachable server pass with exit 0
ok 189 selftest: queries GET /api/tags/?page_size=1
ok 190 selftest: sends the API version in the Accept header
ok 191 selftest: API_VERSION from .env is used in the Accept header
ok 192 selftest: token rejected (401) fails with exit 1
ok 193 selftest: .env with mode 644 fails
ok 194 selftest: .env inside a git working tree fails and says so
ok 195 selftest: a non-writable scan folder fails
ok 196 selftest: never uploads anything
ok 197 selftest: prints a summary
ok 198 selftest: API_VERSION=10 fails and names the problem
ok 199 status --json prints valid JSON and exits 0
ok 200 counts per folder (only scan files; no .task, .error or .txt)
ok 201 failed entries carry the first line of the .error file
ok 202 a file name with double quotes survives in the JSON
ok 203 pending entries carry the task id and the age of the .task file
ok 204 last_run and last_success come from the log (latest lines win)
ok 205 without a log, last_run and last_success are null
ok 206 valid .env: config_ok true, config_error null, paperless_url from .env
ok 207 paths point at the folders and the log
ok 208 SCAN_ROOT in .env is ignored
ok 209 invalid .env (mode 644): config_ok false with the reason, exit 0, no notification
ok 210 missing .env: config_ok false, exit 0
ok 211 agent_loaded follows launchctl print of the main agent
ok 212 status makes no network calls
ok 213 status does not write to the log
ok 214 status does not move or upload anything
ok 215 status without --json prints a human summary naming failed files
ok 216 NON-REGRESSION: no argument still means --once
ok 217 a .task file that vanishes mid-listing doesn't crash status --json
ok 218 plugin exists, is executable and has an xbar.title header
ok 219 empty state: exit 0, SF Symbol icon, no count, not red
ok 220 outbox + pending count is shown in the menu bar
ok 221 a failed file turns the icon red
ok 222 config error: red, and the reason is the first dropdown line
ok 223 agent not loaded: red, and the dropdown says so
ok 224 each failed file is listed in a submenu with its error
ok 225 each failed file has a Retry action calling scan-intake retry <file>
ok 226 Retry handles a file name with spaces (quoted param)
ok 227 Retry all failed calls scan-intake retry all
ok 228 Run now kickstarts the main agent through launchctl
ok 229 Run selftest opens in a terminal
ok 230 last upload links to the document in paperless
ok 231 no log: no last-upload link
ok 232 Open entries cover the Scans folder, failed/, the log and paperless
ok 233 scan-intake not installed: one 'not installed' line, exit 0
ok 234 rendering makes no network calls and moves nothing
ok 235 status --json failing: red icon and a 'status failed' line
ok 236 ScanSnap prefix is dropped and a long name is cut at a word, max 80 characters
ok 237 leading '- ' after the prefix is trimmed
ok 238 accents and apostrophes survive
ok 239 runs of whitespace collapse and trailing spaces are trimmed
ok 240 pure timestamp name falls back to 'Scan YYYY-MM-DD HH.MM'
ok 241 nothing left after the prefix falls back to 'Scan YYYY-MM-DD HH.MM'
ok 242 a name that is not from ScanSnap is used as the title
ok 243 a date in the title doesn't reach the filename: still filename=scan.pdf
ok 244 a title with ';' is sent quoted, so curl doesn't split it
ok 245 a title with a double quote arrives intact
ok 246 without LANG the 80-character cut doesn't split a multi-byte character
ok 247 NON-REGRESSION: a dated name still gets no title
ok 248 a title starting with '<' is sent quoted, so curl doesn't read a file
ok 249 a title starting with '@' is sent quoted, so curl doesn't upload a file
ok 250 NON-REGRESSION: a '<' that isn't leading doesn't force quoting
ok 251 uploads to the public post_document endpoint
ok 252 ScanSnap-style name is uploaded with the neutral filename scan.pdf
ok 253 neutral filename keeps the real extension (jpg -> scan.jpg)
ok 254 neutral upload sets the title 'Scan YYYY-MM-DD HH.MM'
ok 255 deliberately dated name 'YYYY-MM-DD - Title.pdf' is uploaded under its own name
ok 256 dated name with ';' and ',' is sent as a quoted filename
ok 257 path with ';' is sent as a quoted document path
ok 258 double quote in a dated name is backslash-escaped inside the quoted filename
ok 259 dated name also sends its date as the created field
ok 260 neutral upload sends no created field
ok 261 date without ' - ' separator is not treated as deliberate (neutral filename)
ok 262 no tags, correspondent or document_type are sent
ok 263 token never appears in curl argv (visible in ps)
ok 264 token is sent as an Authorization header on stdin
ok 265 token never appears in the log
ok 266 upload uses --fail-with-body, --connect-timeout 10 and --max-time 600
ok 267 --verbose adds DEBUG lines
ok 268 without --verbose there are no DEBUG lines
```
(rc=0. 268/268 ok. Before phase 10: 12 failing, all real assertion failures.)

Live check (`<test> probe.pdf` uploaded to paperless, plugin after `./install.sh`): **not done**.
It touches the real paperless instance, so it's left for you.

## Commits

- `b2e9fc9` [phase-10.1] quote a title starting with < or @
- `78a32e3` [phase-10.2] log WARN upload_error when a file stays in outbox
- `a69fb7e` [phase-10.3] skip files that vanish during status and health
- `f4ceb87` [phase-10.4] lock needs a live scan-intake process; take over by rename
- `ca59c50` [phase-10.5] SCAN_ROOT is no longer a .env key
- `67cdb03` [phase-10.6] drop count_outbox, unwrap plugin base64, document gotchas

## Deviations

- None in the code.
- The plan describes the 10.5 retry test as "`.env` with mode 644 → retry still moves". The test
  that's actually there (`retry.bats` "retry ignores SCAN_ROOT in .env") uses a mode-600 `.env`
  with `SCAN_ROOT=$HOME/Other`. That tests the contract change more directly. I left the test
  as written.

## Tests changed on purpose (contract change, 10.5)

- `config.bats` ".env SCAN_ROOT overrides the default ~/Scans" → ".env SCAN_ROOT is ignored: ~/Scans is always used".
- `status.bats` "SCAN_ROOT from .env is honoured" → "SCAN_ROOT in .env is ignored".

The orchestrator made both changes. I didn't edit any tests.

## Test gaps

- Atomic lock takeover (10.4) has no test. It needs two runs racing within a few lines, as the
  plan says.
- No new tests added.

## Follow-ups (not done)

- `SCAN-INTAKE-MAC-PLAN.md` still says for `run_start`: "logged after .env loads, so the counts
  use SCAN_ROOT". That's harmless history, but it's now meaningless.
- `recheck_pending` has the same unguarded `stat -f %m "$t"` as R4. It was outside 10.3's scope.
  A `.task` file vanishing there would need a concurrent run, which the lock prevents.
- Future idea from the plan: `outbox_stuck` in `status --json`.

## Confidence

likely-good. The suite and shellcheck are green. The live check is still open.
