# Phase 4 end: LaunchAgent, installer, README

## Built
- 4.1 `.env.example` (empty token, every whitelisted key with its default except `SCAN_ROOT`, which is a comment because `.env` values are literal and the default needs `$HOME`) and `scan-intake.plist.in` with `@SCRIPT@`, `@HOME@`, `@LOG@` placeholders.
- 4.2 `install.sh`: first run copies `.env.example` to `~/.config/scan-intake/.env` (600), asks for the token and exits 1 without loading anything; otherwise creates folders, symlinks the script, renders the plist with `sed`, boots out then bootstraps, runs `--selftest` through the symlink. `uninstall.sh`: bootout, remove plist and symlink, leave `~/Scans` and `.env`.
- 4.3 `README.md`: install/uninstall, token source, folders, log, ScanSnap Home profile, troubleshooting.

Commits: 483e46d (4.1), af5e3a3 (4.2), 7e93a22 (4.3)

## Verification
`shellcheck scan-intake install.sh uninstall.sh`: clean (no output).

```
1..126
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
ok 14 401: file stays in outbox
ok 15 401: 'Config error' notification about the token
ok 16 401: exits 1 (treated as a config error)
ok 17 401: stops the run after the first file
ok 18 403: file stays in outbox and the run stops
ok 19 413: file moves to failed/ with 'too large for reverse proxy' in .error
ok 20 413: Error notification 'too large for the reverse proxy' with Basso
ok 21 413: logged as ERROR failed with http=413
ok 22 500: file moves to failed/ and .error holds the response body
ok 23 500 on one file does not stop the others
ok 24 done/ file older than 180 days is deleted
ok 25 done/ deletion is logged
ok 26 done/ file younger than 180 days is kept (while an older one is deleted)
ok 27 DONE_RETENTION_DAYS from .env overrides 180
ok 28 log larger than 5 MB is rotated to scan-intake.log.1
ok 29 log rotation keeps 3 old logs
ok 30 log smaller than 5 MB is not rotated
ok 31 --dry-run: nothing is uploaded and the scan stays in outbox
ok 32 --dry-run: old done/ files are not deleted
ok 33 --dry-run: says what it would upload
ok 34 NON-REGRESSION: a .env inside the tool dir is git-ignored
ok 35 NON-REGRESSION: the repo's stow installer does not stow scan-intake
ok 36 .env.example ships with an empty token
ok 37 install without .env: copies .env.example to ~/.config/scan-intake/.env with mode 600
ok 38 install without .env: exits non-zero and tells the user to paste the token
ok 39 install without .env: does not load the LaunchAgent
ok 40 install: exits 0, creates the scan folders
ok 41 install: renders a valid plist
ok 42 install: plist has the label, --once, and absolute paths (no ~)
ok 43 install: plist watches ~/Scans/outbox, runs every 900 s and at load
ok 44 install: plist sends stdout and stderr to the log and sets PATH
ok 45 install: symlinks the script into ~/.local/bin
ok 46 install: bootstraps the agent into gui/<uid>
ok 47 install: runs the selftest
ok 48 install twice: second run boots out the old agent before bootstrapping
ok 49 uninstall: boots out the agent and removes the plist
ok 50 uninstall: removes the ~/.local/bin symlink
ok 51 uninstall: leaves ~/Scans and .env alone
ok 52 each run appends a run_start line with outbox and pending counts
ok 53 log lines use only the levels DEBUG, INFO, WARN and ERROR
ok 54 two runs append, they do not truncate
ok 55 config error is logged as ERROR
ok 56 connect error, no fallback: file stays in outbox and run exits 0
ok 57 resolve (6) and timeout (28) errors also leave the file in outbox
ok 58 connect error: logged as network_error with the curl exit code
ok 59 connect error on a fresh file: no notification
ok 60 files waiting more than 1 h: one 'Waiting' notification per run with the count
ok 61 LAN fallback: used when the public URL has a connect error
ok 62 LAN fallback: the task is polled on the LAN host it was uploaded to
ok 63 LAN fallback: not used for HTTP errors (500 goes to failed/)
ok 64 LAN fallback empty (default): the LAN host is never contacted
ok 65 success: 'Uploaded' notification titled 'Scan intake' with file name and document id
ok 66 success: no error sound
ok 67 NOTIFY_SUCCESS=false: no notification on success
ok 68 duplicate: 'Duplicate, skipped' notification with the existing id
ok 69 processing failure: 'Error' notification with the first line of the message and Basso sound
ok 70 double quotes in the file name are escaped for AppleScript
ok 71 five files: five individual notifications
ok 72 seven files: one summary notification instead of seven
ok 73 seven files: the log still has all seven success lines
ok 74 pdf, jpg, jpeg, png, tif and tiff are uploaded
ok 75 other extensions (.txt) are left in outbox and not uploaded
ok 76 dotfiles are skipped
ok 77 AppleDouble ._ files are skipped
ok 78 a directory named like a pdf is skipped
ok 79 empty outbox: exits 0 without uploading
ok 80 a file still being written is skipped and stays in outbox
ok 81 a stable file is uploaded after the stability window
ok 82 file names with spaces and quotes are handled
ok 83 pending task now SUCCESS: file moves to done/ and the .task file is removed
ok 84 pending task now a duplicate FAILURE: file moves to duplicates/
ok 85 pending task still STARTED and fresh: file stays in pending/
ok 86 pending task still STARTED after 24 h: failed/ with 'no result from paperless'
ok 87 pending task still STARTED after 24 h: Error notification
ok 88 pending files are counted in run_start
ok 89 a .task whose file has disappeared does not crash the run
ok 90 SUCCESS: file moves to done/
ok 91 SUCCESS: logs uploaded (task, via=public) and success (doc id)
ok 92 polls /api/tasks/?task_id=<uuid>
ok 93 FAILURE with duplicate_documents: file moves to duplicates/
ok 94 FAILURE with duplicate_documents: logs WARN duplicate with the existing id
ok 95 FAILURE whose result mentions 'Duplicate' (no duplicate_documents): duplicates/
ok 96 other FAILURE: file moves to failed/ with a .error file holding the result
ok 97 other FAILURE: run still exits 0
ok 98 task not finished within POLL_TIMEOUT: file and .task move to pending/
ok 99 task not finished within POLL_TIMEOUT: logged as pending
ok 100 running twice uploads each file only once
ok 101 selftest: valid config and reachable server pass with exit 0
ok 102 selftest: queries GET /api/tags/?page_size=1
ok 103 selftest: sends the API version in the Accept header
ok 104 selftest: API_VERSION from .env is used in the Accept header
ok 105 selftest: token rejected (401) fails with exit 1
ok 106 selftest: .env with mode 644 fails
ok 107 selftest: .env inside a git working tree fails and says so
ok 108 selftest: a non-writable scan folder fails
ok 109 selftest: never uploads anything
ok 110 selftest: prints a summary
ok 111 uploads to the public post_document endpoint
ok 112 ScanSnap-style name is uploaded with the neutral filename scan.pdf
ok 113 neutral filename keeps the real extension (jpg -> scan.jpg)
ok 114 neutral upload sets the title 'Scan YYYY-MM-DD HH.MM'
ok 115 deliberately dated name 'YYYY-MM-DD - Title.pdf' is uploaded under its own name
ok 116 dated name with ';' and ',' is sent as a quoted filename
ok 117 path with ';' is sent as a quoted document path
ok 118 double quote in a dated name is backslash-escaped inside the quoted filename
ok 119 date without ' - ' separator is not treated as deliberate (neutral filename)
ok 120 no tags, correspondent or document_type are sent
ok 121 token never appears in curl argv (visible in ps)
ok 122 token is sent as an Authorization header on stdin
ok 123 token never appears in the log
ok 124 upload uses --fail-with-body, --connect-timeout 10 and --max-time 600
ok 125 --verbose adds DEBUG lines
ok 126 without --verbose there are no DEBUG lines
```

## Deviations
- `ProgramArguments.0` points at the repo copy of `scan-intake`, not the `~/.local/bin` symlink (plan says "absolute path to scan-intake"; tests accept either).
- `install.sh` quotes `"done"` in its folder loop to silence shellcheck SC1010.
- `SCANNER-INTAKE.md` was read from `dotfiles/docker/paperless-ngx/`; there is no copy under `dotfiles-secrets/`.

## Test gaps / added tests
None flagged, none added.

## Follow-ups
- The plist hard-codes `~/Scans/outbox`; a `SCAN_ROOT` override in `.env` would need the plist edited too (noted in `.env.example`).
- `install.sh` does not check that `/usr/bin/jq` exists; `--selftest` does.
- No project-level CLAUDE.md exists in `dotfiles`, so none was updated.
- Unrelated uncommitted changes exist in `common/btop`, `common/claude` (not touched).
- Phase 5 (live test) needs the user to run `./install.sh` and paste the token.

## Confidence
likely-good: all 126 tests pass against stubs; real launchd bootstrap is untested until phase 5.
