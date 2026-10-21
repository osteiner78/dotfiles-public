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
```

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
