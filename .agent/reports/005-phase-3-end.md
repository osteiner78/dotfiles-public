# Phase 3 end: failure modes and housekeeping

## Built
- 3.1 HTTP errors: 401/403 log `failed http=`, stop the run, flush queued notifications, then `config_error` ("Config error", token message) and exit 1; 413 to failed/ with `.error` "too large for reverse proxy"; other 4xx/5xx to failed/ with the response body as `.error`; the run continues with the next file.
- 3.2 Network errors (curl 6/7/28): `network_error` log, file stays in outbox; `LAN_FALLBACK_URL` retried for network errors only (never for HTTP errors), with `via=lan` and the task polled on the LAN URL; one "Waiting" notification per run ("N scans queued, paperless unreachable") when affected files are older than 1 h.
- 3.3 `recheck_pending` at the start of each run: final status files via the shared `file_result`, `.task` older than 24 h and still running goes to failed/ ("no result from paperless") with an Error notification, orphan `.task` files are removed.
- 3.4 `done/` retention (`find -mtime +N`, `deleted` log line), log rotation at 5 MB keeping 3, `--dry-run` (prints `would upload <name>`; no stability wait, POST, pending re-check, move, deletion or rotation).

Commit: 263b8ca

## Verification
`shellcheck scan-intake`: clean (no output).

```
1..108
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
ok 28 pdf, jpg, jpeg, png, tif and tiff are uploaded
ok 29 other extensions (.txt) are left in outbox and not uploaded
ok 30 dotfiles are skipped
ok 31 AppleDouble ._ files are skipped
ok 32 a directory named like a pdf is skipped
ok 33 empty outbox: exits 0 without uploading
ok 34 a file still being written is skipped and stays in outbox
ok 35 a stable file is uploaded after the stability window
ok 36 file names with spaces and quotes are handled
ok 37 uploads to the public post_document endpoint
ok 38 ScanSnap-style name is uploaded with the neutral filename scan.pdf
ok 39 neutral filename keeps the real extension (jpg -> scan.jpg)
ok 40 neutral upload sets the title 'Scan YYYY-MM-DD HH.MM'
ok 41 deliberately dated name 'YYYY-MM-DD - Title.pdf' is uploaded under its own name
ok 42 dated name with ';' and ',' is sent as a quoted filename
ok 43 path with ';' is sent as a quoted document path
ok 44 double quote in a dated name is backslash-escaped inside the quoted filename
ok 45 date without ' - ' separator is not treated as deliberate (neutral filename)
ok 46 no tags, correspondent or document_type are sent
ok 47 token never appears in curl argv (visible in ps)
ok 48 token is sent as an Authorization header on stdin
ok 49 token never appears in the log
ok 50 upload uses --fail-with-body, --connect-timeout 10 and --max-time 600
ok 51 --verbose adds DEBUG lines
ok 52 without --verbose there are no DEBUG lines
ok 53 SUCCESS: file moves to done/
ok 54 SUCCESS: logs uploaded (task, via=public) and success (doc id)
ok 55 polls /api/tasks/?task_id=<uuid>
ok 56 FAILURE with duplicate_documents: file moves to duplicates/
ok 57 FAILURE with duplicate_documents: logs WARN duplicate with the existing id
ok 58 FAILURE whose result mentions 'Duplicate' (no duplicate_documents): duplicates/
ok 59 other FAILURE: file moves to failed/ with a .error file holding the result
ok 60 other FAILURE: run still exits 0
ok 61 task not finished within POLL_TIMEOUT: file and .task move to pending/
ok 62 task not finished within POLL_TIMEOUT: logged as pending
ok 63 running twice uploads each file only once
ok 64 success: 'Uploaded' notification titled 'Scan intake' with file name and document id
ok 65 success: no error sound
ok 66 NOTIFY_SUCCESS=false: no notification on success
ok 67 duplicate: 'Duplicate, skipped' notification with the existing id
ok 68 processing failure: 'Error' notification with the first line of the message and Basso sound
ok 69 double quotes in the file name are escaped for AppleScript
ok 70 five files: five individual notifications
ok 71 seven files: one summary notification instead of seven
ok 72 seven files: the log still has all seven success lines
ok 73 401: file stays in outbox
ok 74 401: 'Config error' notification about the token
ok 75 401: exits 1 (treated as a config error)
ok 76 401: stops the run after the first file
ok 77 403: file stays in outbox and the run stops
ok 78 413: file moves to failed/ with 'too large for reverse proxy' in .error
ok 79 413: Error notification 'too large for the reverse proxy' with Basso
ok 80 413: logged as ERROR failed with http=413
ok 81 500: file moves to failed/ and .error holds the response body
ok 82 500 on one file does not stop the others
ok 83 connect error, no fallback: file stays in outbox and run exits 0
ok 84 resolve (6) and timeout (28) errors also leave the file in outbox
ok 85 connect error: logged as network_error with the curl exit code
ok 86 connect error on a fresh file: no notification
ok 87 files waiting more than 1 h: one 'Waiting' notification per run with the count
ok 88 LAN fallback: used when the public URL has a connect error
ok 89 LAN fallback: the task is polled on the LAN host it was uploaded to
ok 90 LAN fallback: not used for HTTP errors (500 goes to failed/)
ok 91 LAN fallback empty (default): the LAN host is never contacted
ok 92 pending task now SUCCESS: file moves to done/ and the .task file is removed
ok 93 pending task now a duplicate FAILURE: file moves to duplicates/
ok 94 pending task still STARTED and fresh: file stays in pending/
ok 95 pending task still STARTED after 24 h: failed/ with 'no result from paperless'
ok 96 pending task still STARTED after 24 h: Error notification
ok 97 pending files are counted in run_start
ok 98 a .task whose file has disappeared does not crash the run
ok 99 done/ file older than 180 days is deleted
ok 100 done/ deletion is logged
ok 101 done/ file younger than 180 days is kept (while an older one is deleted)
ok 102 DONE_RETENTION_DAYS from .env overrides 180
ok 103 log larger than 5 MB is rotated to scan-intake.log.1
ok 104 log rotation keeps 3 old logs
ok 105 log smaller than 5 MB is not rotated
ok 106 --dry-run: nothing is uploaded and the scan stays in outbox
ok 107 --dry-run: old done/ files are not deleted
ok 108 --dry-run: says what it would upload
```

Baseline before the change: 25 of 36 phase 3 tests failing, 11 passing as the user predicted. `tests/install.bats` (phase 4) is not part of this phase's verification; its 2 NON-REGRESSION anchors still pass, the other 14 fail as expected.

## Deviations
- Files moved into done/ get `touch`ed. Retention counts from the file mtime, and `mv` keeps the scan's own mtime, so an old PDF dropped into outbox would otherwise be uploaded and deleted by the same run's retention step. Not in the plan.
- A curl failure with no HTTP answer and not 6/7/28 (e.g. TLS error) is logged `failed reason="curl exit N, http=..."` and the file stays in outbox for retry. The plan only classifies 6/7/28 and HTTP errors.
- Pending re-check queries the public URL only; if it is unreachable the `.task` is left alone and not expired.
- `--dry-run` also skips the pending re-check and log rotation; the plan lists "no POST, no moves, no deletions". Dry-run still creates folders and appends `run_start` to the log.
- The "Waiting" notification is sent directly after the queued ones, so it is never folded into a >5 summary.
- On 401/403 the run skips retention and rotation and exits 1.
- Removed the file-level `shellcheck disable=SC2034`; every config key is now used.

## Tests
No tests added or changed.

## Follow-ups
- A 4xx/5xx HTML body from a proxy (not 413) ends up in `.error` and the notification as its first line, e.g. `<html>`. Check what the real proxy returns in phase 5.
- The old copy in `failed/` after the 24 h expiry has `.error` but the stale `.task` is removed.

Confidence: likely-good
