# Phase 2 end: upload, poll, file the result, notify

## Built
- 2.1 Outbox scan: extension filter (case-insensitive), dotfile/`._*`/directory skip, stability check (`stat` size+mtime across `STABLE_SECS`).
- 2.2 Upload: curl call shape per the plan (headers via `-H @-`, `--fail-with-body`, timeouts, `-F`); dated `YYYY-MM-DD - x` names keep their name, all others upload as `scan.<ext>` plus `title=Scan YYYY-MM-DD HH.MM`; `uploaded` log line.
- 2.3 Polling by wall clock (`$SECONDS`, so `POLL_INTERVAL=0` can't loop forever) and filing: SUCCESS to done/, duplicate (via `duplicate_documents` or `/duplicate/i` in result, id falls back to `#NNNN`) to duplicates/, other FAILURE to failed/ with `.error`, timeout to pending/ with `.task`.
- 2.4 Notifications queued per event and flushed at end of run: individually up to 5, otherwise one "Summary" notification ("7 scans uploaded", "12 scans uploaded, 1 error"). Immediate `notify()` from phase 1 unchanged for config errors.

Commit: see `git log` entry `[phase-2.1-2.4]` (single commit, one file).

## Verification
`shellcheck scan-intake`: clean.

`bats` on config, logging, selftest, outbox, upload, results, notify: 1..69, all `ok` (no `not ok`). Baseline before: phase 2 files 36 of 42 failing, the 6 passing ones being tests that hold vacuously without an implementation (empty outbox, directory skip, token not in log, no DEBUG lines, exit 0 on failure).

## Deviations
- `file_into` never overwrites: on a name clash in the destination it prefixes `<epoch>-`. Not in the plan; added because failed/ and duplicates/ hold the only local copy.
- Upload failure (curl error or HTTP error, plus a response without a task id) is logged as ERROR `failed ... http=<code> curl=<rc>` and the file stays in outbox. This is a placeholder: 401/403, 413, other HTTP errors and network errors with LAN fallback are phase 3 and will replace it. Until then a persistently rejected file is retried every trigger.
- The SC2034 shellcheck disable remains, with a narrower comment: `DRY_RUN`, `LAN_FALLBACK_URL`, `DONE_RETENTION_DAYS` are unused until phase 3.
- Summary notification counts duplicates too ("N duplicates skipped"); plan only gave the uploaded/error examples.
- Plan says SCANNER-INTAKE.md is in `dotfiles-secrets/`; it is in `dotfiles/docker/paperless-ngx/` (also noted in the phase 1 report).

## Tests
No tests added or changed.

## Follow-ups
- File names containing `"`, `;` or `,` are passed unescaped inside curl `-F` (`document=@path;filename=name`). Only a deliberately dated name keeps its own name in `filename=`, and the path always contains the name, so real curl may mis-parse such names; the stub can't show this. Worth checking in phase 5.
- Log lines embed the file name raw inside `file="..."`; a name with `"` makes that line ambiguous to parse.
- Pending-task re-check, 24 h expiry and retention are phase 3.

Confidence: likely-good
