# Scan intake: images in notifications

Follows plan 002 (phase 10, done). Conventions: `common-macos/scan-intake/CLAUDE.md`.
Phase number continues: **phase 11**. Report: next free number in `.agent/reports/` (013 is
reserved for the plan 003 experiment results, so probably 014).

**Test status (2026-10-22):** written. 293 tests: **17 fail** for the right reason (all in
`notify-image.bats`, "no -contentImage on call …"), 276 pass (268 existing + 8 new
NON-REGRESSION guards). Test infrastructure added:
- `tests/stubs-tn/terminal-notifier`: on `-contentImage PATH`, copies the file to
  `$STUB_LOG/tn-image-N` (N = call number), or warns on stderr and still exits 0 if it's missing,
  like the real tool.
- `helpers.bash`: `tn_image [CALL]`, plus `make_real_scan NAME`, which copies
  `tests/data/page.pdf` into outbox.
- `tests/data/page.pdf`: a one-page PDF with made-up text ("Lorem ipsum test page"), 11 KB.

## Intent

macOS takes a notification's icon from the sending app, and terminal-notifier can no longer
override it (`-appIcon`/`-sender` are "No longer supported" in 3.1.0). What a notification *can*
carry is an attached image (`-contentImage`). This phase attaches page 1 of the scan to Uploaded
and Duplicate, so you see which paper it was, and a system stop/caution icon to problem
notifications, so they stand out. The key decision: render with **`sips`, not `qlmanage`**.
`qlmanage -t` never exits on a missing, empty or corrupt file (verified; there's no `timeout`
on macOS), while `sips` takes ~0.1 s, never hung, and simply writes no file when it can't render.
**Out of scope:** a custom app bundle with its own icon (option A, see the end), images in the
osascript fallback (not possible), and paperless's own thumbnails via the API.

## Facts checked live (2026-10-22, macOS 27.0.1, terminal-notifier 3.1.0)

| Check | Result |
|---|---|
| `sips -s format png -Z 256 page.pdf --out x.png` | 0.08 s; 198×256; byte-identical output across runs and source paths |
| Same on a real ScanSnap PDF from `~/Scans/done` | 0.12 s, 181×256 |
| `sips` on junk / empty / missing file | exit 13 / 0 / 0, **no output file**, never hangs |
| `qlmanage -t` on junk / empty / missing file | **hangs** (killed after 5 s) |
| `sips` on `AlertStopIcon.icns`, `AlertCautionBadgeIcon.icns` (CoreTypes) | 256×256 PNG, deterministic |
| `terminal-notifier -contentImage x.png` | exit 0; the file is **left in place** (it's read, not moved) |
| `-contentImage` with a missing file | prints `[!] Could not attach '…': no such file.`, exit 0, notification sent |

| How the image shows (user, 2026-10-22) | **Not in the collapsed banner.** The banner has a disclosure arrow; the image appears only after expanding it. There is no API to expand a notification by default (`UNNotificationContent` has no such option; the alert style "Alerts" vs "Banners" only changes how long it stays) |

Still open (live check): whether `sips` behaves the same under launchd.

**Consequence:** the image is a detail you see on demand (expand, or in Notification Center),
not at a glance. The stop/caution icons therefore add little; the scan thumbnail is the part
worth having. Implement only if that's still worth it to you; otherwise drop this plan and the
tests (`git revert` of the commit that added them).

## Decisions

| Topic | Decision |
|---|---|
| Image per notification | Uploaded, Duplicate: page 1 of the scan (the file in `done/` or `duplicates/`). Error (per file, incl. 413), Config error, Health check, Summary with errors: **stop icon**. Waiting: **caution icon**. Summary without errors: none |
| Icon sources | `/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns` and `AlertCautionBadgeIcon.icns`. Not copied into the repo (Apple artwork; this repo is public) |
| Rendering | Always `sips -s format png -Z 256 <src> --out <tmp>.png`, for scans and icons alike. The tests compare against exactly this rendering |
| Temp files | One PNG per notification in `${TMPDIR:-/tmp}` (`mktemp`), deleted right after the terminal-notifier call, whether it succeeds or not. No cache: rendering an icon costs 0.1 s, and there are at most 6 notifications per run |
| Failure | No PNG (sips failed, unreadable file, missing icon) → send the notification **without** `-contentImage`. Never block or drop a notification because of its image |
| No watchdog | sips didn't hang on any bad input, so no timeout wrapper. If it ever hangs live, that's a new finding to fix with a test |
| osascript fallback | Unchanged. No image, no sips call when terminal-notifier is absent |

---

## Phase 11 — Images in notifications

### Tasks

- **11.1** Let `queue_notify` / `notify` take an optional 5th argument, the image source: a file
  path, `stop`, `caution`, or empty. Keep the existing 4 arguments and their order; every
  current caller keeps working unchanged.
- **11.2** In `notify()`'s terminal-notifier branch only: render the source to a temp PNG with
  `sips` (11.3). If a non-empty PNG exists, add `-contentImage <png>`. Delete the PNG after the
  call, before falling through to osascript on failure.
- **11.3** A small helper (e.g. `notify_image src out`) that maps `stop`/`caution` to the
  CoreTypes `.icns` paths and runs
  `sips -s format png -Z 256 "$src" --out "$out" >/dev/null 2>&1`. It returns failure when `$out`
  is missing or empty. sips exits 0 on an empty or missing input, so check the file, not the
  exit code.
- **11.4** `file_result`: pass `$DEST` (now in `done/` or `duplicates/`) for Uploaded and
  Duplicate, and `stop` for Error. `fail_file`: `stop`.
- **11.5** `flush_notifications` Summary with errors: `stop`; without errors: none. Config error
  (`notify "Config error" …`), `health_cmd`'s Health check: `stop`. Waiting: `caution`.
- **11.6** Only render when a notification is actually sent. `NOTIFY_SUCCESS=false` must not call
  sips (the NON-REGRESSION test checks this).
- **11.7** README "Clickable notifications": one paragraph on the images (scan page / stop /
  caution, and none with the osascript fallback). CLAUDE.md gotchas: see below.
- **11.8** Live check (see Verification).

### Files

- Modify: `common-macos/scan-intake/scan-intake` (`notify`, `queue_notify`, `flush_notifications`,
  `file_result`, `fail_file`, the Config error and Health check and Waiting call sites, plus a
  new helper), `common-macos/scan-intake/README.md`, `common-macos/scan-intake/CLAUDE.md`.
- Already written (orchestrator): `tests/notify-image.bats`, `tests/data/page.pdf`,
  `tests/stubs-tn/terminal-notifier`, `tests/helpers.bash` (`tn_image`, `make_real_scan`).

### What NOT to touch

- The osascript branch of `notify()` and its escaping.
- `-group`, `-open`, `-sound` and the message-escaping logic (pinned by `notify-click.bats`).
- `upload`, `scan_title`, the lock, `status`, `retry`, the SwiftBar plugin, `install.sh`, both plists.
- Any orchestrator test or stub. If one looks wrong, stop and flag it.

### Risks and open questions

- **The image shows only when the notification is expanded** (confirmed live). The live check
  confirms it works from the agent; if it doesn't show at all, revert the phase rather than keep
  dead code.
- **sips under launchd**: no `LANG` and no TTY. It worked from a shell. Check that the live run
  shows the image from the agent, not only from a manual `--once`.
- **Privacy**: the thumbnail shows page content in Notification Center, which can be visible on
  the lock screen. Acceptable for a personal Mac; mention it in the README. macOS's "Show
  previews: When unlocked" setting covers it.
- Multi-page PDFs: only page 1 (sips renders the first page). Intended.

### Success criteria

Must keep passing (NON-REGRESSION, already green):
- `notify-image.bats`: `NON-REGRESSION: real PDF, terminal-notifier: title, subtitle, message and click target unchanged`,
  `NON-REGRESSION: real PDF without terminal-notifier: one osascript notification, no image`,
  `NON-REGRESSION: real PDF ends up byte-identical in done/`,
  `NON-REGRESSION: unreadable PDF: the notification is still sent, without an image`,
  `NON-REGRESSION: sips fails: notifications still go out, without an image`,
  `NON-REGRESSION: no -contentImage flag at all when there is no image to show`,
  `NON-REGRESSION: Summary without errors: no image`,
  `NON-REGRESSION: NOTIFY_SUCCESS=false: no notification and no thumbnail is made`.
- The whole existing suite (`notify.bats`, `notify-click.bats`, `health.bats`, `network.bats`, …).

Must pass after this phase (NEW BEHAVIOUR, failing now):
- `Uploaded: the notification shows page 1 of the scan`
- `Uploaded: the image is a PNG at most 256 px on its longer side`
- `Duplicate: the notification shows page 1 of the scan`
- `Error from paperless: the stop icon, not the scan`
- `413 error: the stop icon`
- `Config error: the stop icon`
- `Health check with a problem: the stop icon`
- `Waiting (paperless unreachable for over 1 h): the caution icon`
- `Summary with errors (more than 5 results): the stop icon`
- `two uploads: each notification shows its own scan`

Must pass after this phase (FAILURE MODES, failing now):
- `file name with spaces, ';', quotes and umlauts: still gets its thumbnail`
- `file name starting with a dash: still gets its thumbnail`
- `JPEG scan: the notification shows the image`
- `very large page (3000x4000 px): the thumbnail is still at most 256 px`
- `no thumbnail files are left in TMPDIR after a run`
- `terminal-notifier fails: osascript fallback, and no thumbnail left in TMPDIR`
- `the scan itself is never handed to terminal-notifier (only a PNG copy)`

Edge-case checklist, as covered:
- Empty or unreadable input: the junk-PDF and sips-failing guards.
- Unicode, whitespace, `;`, quotes and a leading `-` in names: the two name tests.
- Large input: the 3000×4000 page.
- Zero notifications: `NOTIFY_SUCCESS=false`.
- Max count (>5, Summary): the two Summary tests.
- Not applicable: null, negative numbers, and off-by-one (the only boundary, the 5-notification
  summary, is already pinned in `notify-click.bats`).

### Verification

```bash
cd ~/dotfiles/common-macos/scan-intake
shellcheck scan-intake install.sh uninstall.sh ../swiftbar/.config/swiftbar/scan-intake.1m.sh tests/stubs-tn/terminal-notifier
bats tests/notify-image.bats
bats tests/
```

Live check (with the user; uses only non-personal test paper):
1. Scan one test sheet (or copy `tests/data/page.pdf` to `~/Scans/outbox/notify-test.pdf`) and
   let the **agent** pick it up (don't run `--once` by hand). The Uploaded banner should show the
   page. Then delete the document in paperless and empty the trash.
2. Run `scan-intake health` with a dummy file in `~/Scans/failed/`. The Health check banner should
   show the stop icon. Remove the dummy afterwards.
3. `ls "${TMPDIR:-/tmp}" | grep -c png`: no new leftovers.

## CLAUDE.md additions (proposed; apply in 11.7)

Under Gotchas:
- `qlmanage -t` never exits on a missing, empty or corrupt file; render thumbnails with `sips`
  (it writes no output on failure, so check the output file, not the exit code).
- terminal-notifier can't change the notification icon (`-appIcon`/`-sender` are gone); only
  `-contentImage` attaches a picture. It reads the file and leaves it in place.

Under Layout: `tests/data/`: real fixture files (made-up content), e.g. `page.pdf` for tests
that need a renderable scan.

## Handoff notes

- `notify()` and friends: `common-macos/scan-intake/scan-intake:51-110`; result handling and
  `$DEST`: `file_result` `:287-318`, `fail_file` `:324-330`; Config error `:152`; Health check
  `:513`; Waiting `:723`.
- Existing notification tests: `tests/notify.bats` (osascript), `tests/notify-click.bats`
  (terminal-notifier argv), `tests/health.bats`, `tests/network.bats` (Waiting).
- terminal-notifier's README (`$(brew --prefix terminal-notifier)/README.markdown`): sections
  `-contentImage PATH` and "Custom icons".

## Future idea (not in this plan): option A, its own app icon

A copy of `terminal-notifier.app` with its own bundle ID and `.icns` (built with `sips`,
`iconutil`, `plutil`, `codesign --sign -`) would replace the terminal-notifier icon and the
sender name. It needs a new permission grant and has to be rebuilt after upgrades. Do this as
part of the self-contained app idea (the app bundle would be the notification sender), not on
its own.
