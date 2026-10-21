# Code review: scan-intake (phases 7–9 end state)

- **Target:** `common-macos/scan-intake/` (`scan-intake`, `install.sh`, `uninstall.sh`, both plist templates, `tests/`) and `common-macos/swiftbar/.config/swiftbar/scan-intake.1m.sh`
- **Date:** 2026-10-22
- **Context read:** `.agent/plans/001-scan-intake-followups.md`, `common-macos/scan-intake/CLAUDE.md`
- **Verdict:** significant issues. Two confirmed bugs (one reproduced with real curl, one with the test stubs), no test tampering.

The scope was the whole tool, not one diff, so I read the script, installers and plugin in full. For tests I only looked at the diffs of commits that changed tests after their fail-first commits.

---

## 🔴 Critical

### 1. A title starting with `<` or `@` makes curl read a local file

`scan-intake:266-269`
```bash
title=$(scan_title "$name")
if [[ $title == *[\\\"\;,]* ]]; then title="\"$(form_quote "$title")\""; fi
form=(-F "$doc;filename=scan.$(lower_ext "$name")" -F "title=$title")
```
With `-F`, curl treats `name=<file` as "send this file's contents" and `name=@file` as a file upload. `trim_title_punct` strips `-_.,;:` but not `<` or `@`, and the quoting rule doesn't cover them. I checked this with real curl 8.7.1:

- `-F 'title=<nofile'` → exit 26. `-F 'title=@nofile'` → exit 26.
- `-F 'title=<probe'` with a `probe` file in the cwd → the file's contents (`SECRET`) were in the POST body.
- `-F 'title="<nofile"'` (quoted) → no file read.

What happens in practice:
- `<Kopie> Brief.pdf` or `@home.pdf` in outbox: curl exits 26, `process_file` goes to the `*)` branch, logs `failed` but **leaves the file in outbox**, and sends no notification. It is tried again on every trigger, forever. Only the weekly health check notices (outbox file older than 1 h).
- During a manual run from `~`, a title that matches a file in the cwd (`<.zshrc` from `<.zshrc.pdf`) sends that file's contents to paperless as the title.

Likelihood: low (ScanSnap OCR titles rarely start with `<`/`@`, but files dropped in by hand can). Confidence: **certain**.

Fix: quote these titles too. This keeps the existing `title=` pins in `titles.bats`/`upload.bats` unchanged.
```diff
-        if [[ $title == *[\\\"\;,]* ]]; then title="\"$(form_quote "$title")\""; fi
+        # Also quote a leading < or @, which curl -F would read as a file.
+        if [[ $title == *[\\\"\;,]* || $title == [\<@]* ]]; then title="\"$(form_quote "$title")\""; fi
```
(`--form-string "title=$title"` is the more thorough option, but it changes the argument shape every title test pins.)

---

## 🟡 Important

### 2. `health` ignores `SCAN_ROOT` from `.env`

`scan-intake:497-510`
```bash
out=$(selftest) || true
...
n_failed=$(count_scans failed)
...
for f in "$SCAN_ROOT"/outbox/*; do
```
`selftest` runs `load_env`, but inside `$(...)`, which is a subshell. So `SCAN_ROOT` (and `PAPERLESS_URL`) go back to their defaults in `health_cmd`. With `SCAN_ROOT` overridden (`.env.example:13` documents this as supported), health counts `~/Scans/failed` instead of the real folder, and its click URL points there too.

I reproduced it with the test stubs: `.env` with `SCAN_ROOT=$HOME/Other`, a file in `Other/failed/x.pdf`. `scan-intake health` → exit 0, `INFO health ok`, no notification.

Confidence: **certain**. Fix (same pattern as `status`):
```diff
     out=$(selftest) || true
+    load_config_quietly
     while IFS= read -r line; do
```

### 3. `ERROR failed` is logged for files that stay in outbox

`scan-intake:374-377` and `382-384`
```bash
*)
    log ERROR failed "file=\"$name\" reason=\"curl exit $rc, http=${HTTP_CODE:-none}\""
...
    log ERROR failed "file=\"$name\" reason=\"no task id in response\""
```
Phase 7.3 renamed the 401 line to `rejected` because `failed` should mean "moved to failed/". These two branches still say `failed` while the file stays in outbox, with no notification and no `failed/` entry, so `status` and the plugin never show it. Together with #1 this is how a file gets stuck quietly. Confidence: **certain** (inconsistency), **likely** (that it misleads when reading the log).

Fix: use a separate event, e.g. `WARN upload_error file="…" reason="…"`, and add it to the Contracts table and the README. This changes the log contract, so it is a decision for the next plan rather than a drive-by fix.

### 4. `status --json` can crash when a file moves mid-listing

`scan-intake:576-579` (and `509` in health)
```bash
[[ -f $t ]] || continue
jq -nc ... --arg task "$(head -n 1 "$t")" \
    --argjson age "$((now - $(stat -f %m "$t")))" ...
```
SwiftBar calls `status` every minute while a run may be deleting `.task` files (`recheck_pending`). If `$t` disappears between the `-f` test and `stat`, the expansion becomes `now - `, an arithmetic syntax error, and the script exits. The plugin then shows "status failed" in red for that minute. `process_file:352` already guards against this (`|| date +%s`); these two places don't. Confidence: **likely** (narrow window, but the plugin hits it repeatedly over time).
```diff
-        --argjson age "$((now - $(stat -f %m "$t")))" '{file: $file, task: $task, age_secs: $age}'
+        --argjson age "$((now - $(stat -f %m "$t" 2>/dev/null || echo "$now")))" '{file: $file, task: $task, age_secs: $age}'
```
Do the same in `health_cmd` (`stat -f %m "$f" 2>/dev/null || echo "$now"`).

---

## 🟢 Suggestions

### 5. Stale-lock takeover isn't atomic

`scan-intake:531-536`
```bash
log WARN stale_lock "pid=${pid:-none}"
rm -rf "$lock"
if ! mkdir "$lock" 2>/dev/null; then
```
If two runs find the same stale lock, A does `rm` + `mkdir`, then B's `rm -rf` deletes A's new lock and B's `mkdir` succeeds too. Both run. It needs a crash followed by a manual run starting at the same moment as a launchd run, so confidence is **speculative**. Renaming is atomic, so only one run wins:
```diff
-        rm -rf "$lock"
+        mv "$lock" "$lock.stale.$$" 2>/dev/null && rm -rf "$lock.stale.$$"
```

### 6. `count_outbox` duplicates `count_scans outbox`

`scan-intake:175-181` is the same as `count_scans outbox` (`556-562`). Replace the one call in `run_once` and delete the function. Confidence: certain.

### 7. Log rotation vs. launchd's open stdout/stderr

`rotate_log` does `mv "$LOG" "$LOG.1"`. launchd keeps its `StandardOutPath`/`StandardErrorPath` fd open, so stray stdout/stderr (e.g. `--selftest` output via install, bash errors) keeps going into `.1` until the agent restarts, while `log()` writes to the new file. It's harmless, but it's confusing when you're looking for a crash message. Confidence: likely. No change needed. It's worth a line in the CLAUDE.md gotchas.

### 8. Plugin: `base64` is BSD-only here

`scan-intake.1m.sh:16`: BSD `base64` doesn't wrap lines, GNU `base64` wraps at 76 characters. The encoded `sfconfig` is ~116 characters, so GNU output would break the parameter. The plugin is macOS-only, so this is just a note (per the BSD/GNU rule); `base64 | tr -d '\n'` would make it portable for free.

### 9. Plugin parameter quoting is minimal

`q()` only quotes values containing a space or `"`. Names with `'` or `\` may be parsed differently by SwiftBar. This fails safely: `retry_one` rejects any name that isn't in `failed/` (and any `/`) with exit 2. Confidence: speculative.

---

## Test integrity

- **No orchestrator test was weakened, deleted or skipped.**
- `166244e` ([phase-9.5]) changed an orchestrator test: `message arrives verbatim … a leading dash` expected `-x "q".pdf → …` unescaped. Real terminal-notifier refuses such messages, so the contract changed (verified live and documented in the commit and CLAUDE.md). The replacement tests are stricter: all five leading characters, plus a negative case for `'`. This is a justified contract change, not a weakening.
- `c7b4cbd` swapped `*"sfcolor=red"*` string checks for `bar_is_red`, which decodes the `sfconfig` and checks `renderingMode` and `colors`. That's stronger. The added "status --json failing" test covers a real branch.
- `20cfc5a` swapped real document names for made-up ones in `titles.bats`. Expected titles were recomputed and the assertions are unchanged in kind.

## Scope adherence

Plan 001 has no "What NOT to touch" section. All changes in `6be4de4..20cfc5a` stay inside `common-macos/scan-intake/` and the swiftbar plugin, as declared. The uncommitted changes in `btop.conf`, `claude/CLAUDE.md` and `settings.json` aren't part of this work.

---

## Top 3 to fix first

1. #1: quote titles starting with `<`/`@` (one line, certain, stops silent stuck files).
2. #2: `load_config_quietly` in `health_cmd` (one line, reproduced).
3. #3: decide on a separate event for "upload error, file stays in outbox" so stuck files are visible outside the log.

## Architectural concerns

- **`SCAN_ROOT` is configurable in only one of three places.** The script honours it. `install.sh` creates `~/Scans/*` and the plist watches `@HOME@/Scans/outbox`, both hard-coded, and the SwiftBar plugin follows `status`. `.env.example` admits that overriding it means editing the plist by hand, which `install.sh` then overwrites. Either drop `SCAN_ROOT` from the `.env` whitelist (simplest; tests still set `HOME`), or have `install.sh` read it and render it into the plist. Bug #2 only exists because this path isn't used in practice.
- **Non-final upload outcomes have no state outside the log.** The `*)`, `no task id` and network branches leave the file in outbox, and only `network_error` feeds a notification (`Waiting`, after 1 h). Status and the plugin can't tell "queued" from "stuck". If the plugin should show this, it needs either a marker file (like `.task` for pending) or an `outbox_errors` list in `status --json`.
- **Privacy in the public repo:** the real document names that `20cfc5a` replaced (health insurer name, an application-rejection text, an invoice) are still in `origin/main` history (commit `6be4de4`). They aren't credentials, so this is your call: accept it, or rewrite history (which would need a force-push to main, and your rules forbid that without a deliberate decision).

## Missing tests (for `/add-tests` or the next plan)

1. `titles.bats`: `<Kopie> Brief.pdf` → the curl stub receives `title="<Kopie> Brief"` (quoted). Same for `@home.pdf` → `title="@home"`.
2. `health.bats`: `.env` with `SCAN_ROOT=$HOME/Other`, a file in `Other/failed/` → exit 1, `problems=1`, the notification mentions "failed", and the click URL is `file://$HOME/Other/failed/`. Fails today.
3. `health.bats`: same override with a 2 h old file in `Other/outbox/` → reported as "older than 1 h".
4. `errors.bats`: curl exits 26 (or 35) with no HTTP code → the file stays in outbox, no notification, log line with the curl code. Pins today's behaviour before #3 changes it.
5. `retry.bats`: `.env` with mode 644 and `SCAN_ROOT` overridden → decide and pin. Today `retry` silently uses `~/Scans` and says "not in failed/".
6. `lock.bats`: a lock dir whose pid file holds a live pid that isn't scan-intake (pid reuse after a crash) → today the run is skipped forever until that pid exits. Decide whether that's acceptable and pin it.

## CLAUDE.md updates

Add under Gotchas in `common-macos/scan-intake/CLAUDE.md`:
- `curl -F name=<x` / `name=@x` read the file `x`. Any user-derived `-F` value must be quoted (or sent with `--form-string`).
- `selftest` is called as `$(selftest)` from `health`, so its `load_env` doesn't reach the caller. Load the config again in the parent shell.
- `rotate_log` moves the file launchd holds open for stdout/stderr, so stray output lands in `.1`.
