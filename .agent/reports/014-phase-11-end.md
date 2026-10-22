# Phase 11 report: images in notifications (plan 004)

## What was built
- **11.1-11.6** `scan-intake`: `notify` and `queue_notify` take an optional 5th argument (image source: file path, `stop`, `caution` or empty); a new `N_IMG` array carries it through `flush_notifications`. New helper `notify_image src out` maps `stop`/`caution` to the CoreTypes `.icns`, renders with `sips -s format png -Z 256`, and succeeds only if the output file is non-empty. In the terminal-notifier branch `notify` renders into a temp dir and adds `-contentImage` when that worked. The temp dir is removed after the call, before the osascript fallback. No sips call happens when no notification is sent. Call sites: Uploaded and Duplicate pass `$DEST`; Error (both), Config error, Health check and Summary with errors pass `stop`; Waiting passes `caution`.
- **11.7** README paragraph (thumbnail/icons, expand-only, lock screen privacy, none with osascript); CLAUDE.md gotchas (`qlmanage` hangs, `-contentImage` only) and `tests/data/` layout line.

## Verification
- `shellcheck scan-intake install.sh uninstall.sh ../swiftbar/.config/swiftbar/scan-intake.1m.sh tests/stubs-tn/terminal-notifier`: no output, exit 0.
- `bats tests/notify-image.bats`: 25 of 25 ok (was 17 failing).
- `bats tests/`: `1..293`, 293 ok, 0 not ok.

## Commits
- c25fe78 `[phase-11.1] scan-intake: attach scan page or stop/caution icon to notifications`

## Deviations
- The PNG lives in `mktemp -d` + `image.png` rather than a `mktemp` file. Test "the scan itself is never handed to terminal-notifier" requires the path to end in `.png`, and BSD `mktemp` cannot put a suffix after the X's. Cleanup is `rm -rf` of the dir. The plan said "one PNG per notification in `${TMPDIR:-/tmp}`"; this still holds.

## Test gaps / new tests
None flagged, none added.

## Follow-ups (not done)
- 11.8 live check not run (needs the real agent and test paper, with the user): Uploaded banner shows the page when expanded; `scan-intake health` with a dummy file in `~/Scans/failed/` shows the stop icon; `ls "${TMPDIR:-/tmp}" | grep -c png` shows no new leftovers. Open question from the plan: sips under launchd.
- If the image never shows from the agent, the plan says to revert the phase.
- Unstaged/staged unrelated changes in the repo were left out of the commit.

## Confidence
likely-good (all tests green; live behaviour under launchd unverified)
