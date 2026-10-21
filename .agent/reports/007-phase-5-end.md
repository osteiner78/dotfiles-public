# Phase 5 end: live end-to-end test

Date: 2026-10-21. Real paperless server (3.3.1, `https://paperless.osteiner.xyz`), ScanSnap Home
4.1.0 with an iX100, and launchd. The user ran every token, sudo and ScanSnap step; the agent never
read the token.

## Results

| # | Check | Result | Evidence |
|---|---|---|---|
| 0 | Phase 0 audit still clean | pass, with one miss (see below) | no NFS/SMB/AFP mounts; `/etc` hits only in `/etc/auto_nfs.bak-20261021`; launchd: only `xyz.osteiner.scan-intake` and the ScanSnap driver; no crontab |
| 1 | `--selftest` passes; `.env` at 644 refused | pass | 10/10 checks ok, exit 0. At mode 644: exit 1, `config_error reason=".env is mode 644; fix with: chmod 600 …"`, "Config error" notification seen by the user |
| 2 | 1-page scan → done/, OCR, Inbox, notifications, created date | pass | doc 6895, `secs=30`; Inbox tag, 1145 chars of OCR text; created 2026-10-07 from content (not today); Mac "Uploaded" and phone ntfy received |
| 3 | Same file again → duplicates/, shape of `duplicate_documents` | pass | `WARN duplicate … existing=6895`. v9 task JSON: `"status":"FAILURE"`, `"result":"Not consuming: It is a duplicate of document #6895"`, `"duplicate_documents":[{"id":6895,"title":"…","deleted_at":null}]`, which matches the plan's "Contracts" section |
| 4 | `2026-01-15 - Test.pdf` → created 2026-01-15 | **fail, then fixed on the Mac side** | doc 6896 got created 2024-07-03 (content date). Root cause on the server (see below). After `[phase-5.2]`: `2026-01-16 - Test created.pdf` → doc 6897 created 2026-01-16 |
| 5 | ~50 MB scan, no 413 | pass | 52 MB (2 A4 pages at 300 dpi, uncompressed) → doc 6898, uploaded in ~15 s, `secs=50` |
| 6 | Offline: stays in outbox, uploads later | pass | Wi-Fi off: `WARN network_error … curl=6`, file stayed in outbox; online + `launchctl kickstart`: doc 6908, `secs=38` |
| 7 | Wrong token → Config error, file stays | pass | `ERROR config_error reason="paperless rejected the API token (HTTP 401) …"`, exit 1, file stayed in outbox, notification seen; after restoring the token: doc 6906 |
| 8 | 7 files at once → one summary notification | pass | 7 `uploaded` + 7 `success` lines (docs 6899–6905); one Mac notification "7 scans uploaded". The phone got 7 ntfy messages (server post-consume script; out of scope, the user doesn't mind) |
| 9 | Agent loaded after reboot | pass | after the reboot: `runs = 1`, `last exit code = 0`, `run_start` at 10:23:30 |
| 10 | Test documents deleted in paperless | asked the user | see "Cleanup" |

## Findings

1. **Server: filename dates never worked.** `PAPERLESS_FILENAME_DATE_ORDER: 'Y-M-D'` is passed
   unchanged to dateparser's `DATE_ORDER`, which accepts only `DMY/DYM/MDY/MYD/YDM/YMD`
   (v3.3.1 `documents/plugins/date_parsing/base.py::_parse_string`; dateparser `conf.py`). Every
   filename date raises, is caught, and paperless falls back to the content. Fix: `'YMD'`. A
   prompt for the server agent was handed to the user; not verified on the container (no SSH
   access from the Mac).
2. **`scan.pdf` currently protects against nothing.** Because of (1), no filename date is read
   today. Even after the server fix, ScanSnap's names (`01011996_…`, `20261021091350`) have no
   separators, which the date regex requires, so they would not be parsed either; only a ScanSnap
   title that itself contains a date like `03.07.2024` could be.
3. **API v10 breaks the script.** v10 changes `/api/tasks/` to a paginated `results` list, lowercase
   `status`, and `result_data.duplicate_of`. With `API_VERSION=10` every file would time out into
   pending/. `SCANNER-INTAKE.md` says "version=9 (or 10)". The selftest only checks `/api/tags/`,
   so it would not notice.
4. **ScanSnap Home 3.6.1 → 4.1.0 (auto-update at 01:15) could not save profiles**
   (`SshResident … writeHomeSettingsToSettingFile: save profile failure`, errorCode 3). Restarting
   the Mac and recreating the missing save folder did not help. Fixed by the user: the old settings
   file was moved aside (backup: `~/Desktop/ScanSnapHomeSetting-backup-20261021.plist`, plus
   `….plist.old` in `~/Library/Preferences`), the scanner was reconnected and the profiles rebuilt.
5. **Missed by phase 0:** the old ScanSnap "Quick Menu" profile saved to
   `/Volumes/paperless-ngx-consume` (the old NFS mount). Phase 0 checked mounts and config files,
   not ScanSnap profiles. Gone with the rebuilt settings.
6. The first ScanSnap profile saved to `~/Scans` instead of `~/Scans/outbox`; the step 2 file was
   moved into outbox by hand, and the user fixed the profile (step 6's scan landed in outbox by
   itself).

## Code change

`[phase-5.2]` e2a51ce: dated names (`YYYY-MM-DD - …`) also send `created=YYYY-MM-DD`, so they no
longer depend on the server's filename parsing. Two tests were added to `tests/upload.bats` first;
"dated name also sends its date as the created field" failed before the fix (assertion, not
setup), and "neutral upload sends no created field" guards the other branch. This is a discovery
gap (the plan assumed the server sets the date from the filename), not a weakened test.

Verification after the fix:

```
$ shellcheck scan-intake install.sh uninstall.sh   # no output
$ bats tests/
1..130
(130 x ok, no failures)
```

## ScanSnap Home profile (as used)

Scan to Folder template; documents only; colour auto; simplex; image quality Best; rotation auto;
PDF (Single), one PDF per session, **Searchable PDF off**; file name automatic; blank page removal
on; compression Medium; continuous scan; merge both sides **off**; save to `~/Scans/outbox`;
Send to: none.

## Cleanup

Test documents to delete in paperless (then empty the trash): **6896, 6897, 6898, 6899–6905,
6906**. Real documents scanned during the test, kept unless the user says otherwise: 6895 (KVG
letter), 6908 (TAP Air Portugal letter). Local test files remain in `~/Scans/done/` and
`~/Scans/duplicates/` (deleted with the user's OK only).

## Follow-ups (not done)

- Server: `PAPERLESS_FILENAME_DATE_ORDER: 'YMD'`; fix `SCANNER-INTAKE.md` (YMD, version=9 only).
- Script: refuse or warn when `API_VERSION` ≠ 9, or have the selftest check the shape of the
  `/api/tasks/` response.
- On HTTP 401/403 the log says `failed file=… http=401` although the file correctly stays in
  outbox; "failed" suggests it moved to failed/.
- Phase 6 candidate **B (titles)**: strip ScanSnap's `ddMMyyyy_` prefix and send the rest as
  `title` (and possibly as the filename, given finding 2). Cheaper than AI suggestions (#5), which
  stays the follow-on. ScanSnap's titles carry its OCR typos ("ZusteHung").
- `.env.example`: a comment that `API_VERSION` must stay 9.
- Phase 0 audit checklist: include scanner-software profiles.

## Deviations

- Step 3's shape was checked via the browser's session (fetch with `Accept: application/json;
  version=9`) instead of `--verbose`, which doesn't log task JSON.
- Steps 4, 5, 8 used generated PDFs (`cupsfilter`, plus a stdlib Python script for the 52 MB file),
  with the user's approval.
- Step 6's retry was started with `launchctl kickstart` instead of waiting for the 900 s interval.

## Addendum: server fix applied (2026-10-21)

The server agent confirmed `Y-M-D` in the container, set `PAPERLESS_FILENAME_DATE_ORDER: 'YMD'`,
recreated the webserver and updated `SCANNER-INTAKE.md` (YMD; version=9 only). Its test
(`2026-01-14 - Filename date test.pdf`, content 03.07.2024, via the consume folder) got created
2026-01-14. "Error while parsing date string" log lines went from 2 to 0. The commit lives in the
server host's dotfiles clone and is not yet pushed.

Effect on the Mac side: none needed. `created=` stays as an explicit, server-independent date. The
neutral `scan.pdf` name now matters: filename dates are parsed, and a ScanSnap title containing a
separated date (e.g. `03.07.2024`) would now be read as YMD. Option B must keep dates out of
any filename it sends.

Cleanup status: test documents still in paperless are **6896, 6897, 6899–6905, 6907** (6907 is the
server agent's test). 6898 and 6906 are deleted; the trash is empty. Local test copies were deleted
from `~/Scans/done/` and `~/Scans/duplicates/`; the real scans (6895, 6908) are kept.

## Confidence

likely-good. Every plan step passed against the real server after the 5.2 fix. The server-side
date fix was applied and verified on the server afterwards (see Addendum).
