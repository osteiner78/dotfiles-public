# scan-intake

Uploads scans saved by ScanSnap Home to paperless-ngx. A LaunchAgent runs the `scan-intake`
script whenever `~/Scans/outbox` changes, every 15 minutes (retries), and at login. macOS only.

## Install

```bash
cd ~/dotfiles/common-macos/scan-intake
./install.sh
```

The first run copies `.env.example` to `~/.config/scan-intake/.env` (mode 600) and stops.
Paste the token into `PAPERLESS_TOKEN` (paperless web UI -> My Profile -> API Auth Token),
then run `./install.sh` again. It creates the folders, symlinks the script to
`~/.local/bin/scan-intake`, renders and loads the LaunchAgent, and runs `--selftest`.

The token lives only in `~/.config/scan-intake/.env`, outside the repo. The script refuses to
run if that file is readable by others (`chmod 600 ~/.config/scan-intake/.env`).

Uninstall with `./uninstall.sh`. It leaves `~/Scans` and `.env` in place.

## Folders

```
~/Scans/
  outbox/       ScanSnap Home saves here
  pending/      uploaded, paperless has not finished; <file> + <file>.task
  done/         confirmed in paperless; deleted after 180 days
  duplicates/   rejected by paperless as duplicate
  failed/       other failures; <file> + <file>.error holds the reason
```

Log: `~/Library/Logs/scan-intake.log` (one line per event, rotated at 5 MB, 3 kept).

## Usage

```bash
scan-intake --selftest    # check config, server, folders; uploads nothing
scan-intake --dry-run     # print what would be uploaded
scan-intake --verbose     # add DEBUG lines to the log
scan-intake status [--json]   # local state (counts, failed files, last success); no network
scan-intake retry <file|all>  # move failed/ files back to outbox; the agent uploads them
scan-intake health            # selftest + failed/ + stuck outbox + agent loaded; notifies only on problems
```

## Log events

One line per event in the log: `run_start`, `uploaded`, `success`, `duplicate`, `pending`,
`failed`, `rejected` (401/403, the file stays in outbox and the run stops), `network_error`,
`upload_error` (no final answer, e.g. a TLS error: the file stays in outbox),
`requeued` (by `retry`), `skipped` (another run holds `~/Scans/.lock`), `stale_lock` (a dead
run's lock was taken over), `health` (`health ok` or `health problems=N`), `config_error`, `deleted`.

## SwiftBar plugin

`common-macos/swiftbar/.config/swiftbar/scan-intake.1m.sh` (stowed with the swiftbar package)
shows a menu-bar icon with the outbox + pending count, red when something needs attention
(failed files, config error, agent not loaded). The dropdown has the last upload (links to the
document), a Retry action per failed file, Retry all, Run now (`launchctl kickstart`), Run
selftest, and shortcuts to the Scans folder, `failed/`, the log and paperless. It reads
`scan-intake status --json`, so it needs `./install.sh` to have created `~/.local/bin/scan-intake`.

## Clickable notifications

```bash
brew install terminal-notifier
```

With `terminal-notifier` on `PATH`, notifications open something on click: the document
(Uploaded, Duplicate), `failed/` (errors), the log (config error, most health problems) or
paperless (summary without errors). Without it, or when it fails, plain `osascript`
notifications are used.

Once after installing, grant it notification permission. Run from a shell it can't ask
("Notifications are not allowed for this application"); launched through LaunchServices it can:

```bash
open -W -n "$(brew --prefix terminal-notifier)"/terminal-notifier.app --args -title "Scan intake" -message test
terminal-notifier -diagnose     # should say: authorization authorized
```

## Health check

A second LaunchAgent, `xyz.osteiner.scan-intake.health`, runs `scan-intake health` every Monday
at 09:00 (a run missed while asleep fires on wake). It stays silent when everything is fine
(`INFO health ok`). Otherwise it sends one "Health check" notification listing the problems
and logs `WARN health problems=N`. Run it by hand any time: `scan-intake health`.

## ScanSnap Home profile

- Save to: `~/Scans/outbox`
- Format: PDF; one scan session = one file
- Image quality: 300 dpi (Superfine), colour mode auto
- Blank page removal on, auto rotation and deskew on
- Searchable PDF / OCR: off (the server OCRs in deu+eng+fra+por)
- File name: default (the script neutralises it so the scan date doesn't become the document date)
- Post-scan viewer or app: none

To keep a date on purpose, rename the file `YYYY-MM-DD - Title.pdf` before it lands in outbox.

## Troubleshooting

```bash
launchctl print gui/$(id -u)/xyz.osteiner.scan-intake    # is the agent loaded?
tail -f ~/Library/Logs/scan-intake.log
scan-intake --selftest
```

- "Config error" notification: token missing or rejected, or `.env` permissions too loose.
- File stays in outbox: paperless unreachable; it retries every 15 minutes.
- File in `failed/`: read the `.error` file next to it.
- Don't put the scan folder in Desktop, Documents, Downloads or iCloud: launchd jobs can't
  read those without a TCC grant and fail silently.
