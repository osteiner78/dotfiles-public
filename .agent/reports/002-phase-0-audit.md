# Phase 0.1 audit: leftovers from earlier scan-automation attempts

Date: 2026-10-21. Read-only; nothing was changed or removed.

## Findings

| # | Item | Location | Active? | Proposed action |
|---|---|---|---|---|
| 1 | Automount map with an active `paperless_ngx_consume` entry (line 6) pointing at `192.168.1.150:/export/paperless_ngx_consume`, plus 5 commented duplicates (lines 13, 18, 19) | `/etc/auto_nfs` (referenced by `/etc/auto_master`? see 2) | Config present; not mounted right now | Remove only the `paperless_ngx_consume` lines (6, 13, 18, 19). Leave audiobooks, books, comics, comics2 and torrents alone: they are unrelated shares. |
| 2 | `/etc/auto_master` has no `auto_nfs` line; only `auto_home`, `/Network/Servers` and `/-  -static` | `/etc/auto_master` | `auto_nfs` is not loaded from here | None. It also means the map in row 1 is currently inert. Row 1 is still worth cleaning so it doesn't revive if someone adds the line back. |
| 3 | Backup of an older map with `paperless_ngx_consume` | `/etc/auto_nfs.bak` | No | Leave (a backup, not read by automount). Optional: delete. |
| 4 | Fully commented `10.0.0.1:/var/nfs/paperless-consume` lines (3, 7) | `/etc/fstab` | No (comments) | Optional: remove the two lines. Harmless. |
| 5 | Mounts | `mount`, `nfsstat -m` | None active | None |
| 6 | Mount points | `/Volumes`, `/System/Volumes/Data` | None for paperless. `/etc/synthetic.conf` doesn't exist. `~/NetworkDrives/` has only `books`; `~/paperless-consume` doesn't exist. | None |
| 7 | launchd jobs | `~/Library/LaunchAgents`: espanso, borders-power-watcher, steamclean, goku, borders. `/Library/LaunchDaemons`: adobe. `launchctl list` has only Apple's XProtect scan jobs. | None related | None |
| 8 | `com.ricoh.pfu.SshAutoLaunch.plist` matched "scan" | `/Library/LaunchAgents` | Yes, but it's the ScanSnap (Ricoh PFU) driver | Not a leftover. Keep. |
| 9 | Folder Actions | `com.apple.FolderActionsDispatcher`: `folderActionsEnabled = 0`, with some stored action data. `~/Library/Workflows/.../Folder Actions` is empty. | Disabled | None |
| 10 | Hazel, cron, Automator workflows | No Hazel; no crontab; Services contain only 3 "Claude -" workflows | No | None |
| 11 | Login items | Raycast, SwiftBar | Yes | Unrelated. None. |
| 12 | Keychain | 2 entries with server `192.168.1.150` (attributes only; no secrets read) | Stored credentials, likely for the NAS (Finder SMB/NFS login) | Your call. Not harmful to the new script (it uses a `.env` token). Leave unless you want to drop old NAS credentials. |
| 13 | Shell rc files, `~/bin`, `~/.local/bin` | No hits for `192.168.1.150` or `paperless` | No | None |
| 14 | Other `paperless` hits in `~/dotfiles` and `~/dotfiles-secrets` | `docker/paperless-ngx/*` (expected); karabiner (`focus "Paperless-ngx"` hotkey); niri/hypr keybinds (webapp launch); `.gitconfig` (commented filter); caddy configs (reverse proxy); `common-macos/scan-intake/tests/*` (new tests) | Not automation that touches scans | None. Nothing here consumes or moves files. |
| 15 | Finder sidebar | `~/Library/Application Support/com.apple.sharedfilelist` is blocked by macOS privacy ("Operation not permitted") | Unknown | Check by hand: in Finder, look for a paperless or 192.168.1.150 entry in the sidebar. |

## Assessment

Nothing active can consume or move files in parallel with the new script. The only real
leftover is the inert `paperless_ngx_consume` entry in `/etc/auto_nfs` (row 1). Editing it
needs `sudo`.

## Proposed phase 0.2 (needs your approval)

1. You back up and edit (in your own Terminal):
   ```
   sudo cp /etc/auto_nfs /etc/auto_nfs.bak-20261021
   sudo sed -i '' '/paperless_ngx_consume/d' /etc/auto_nfs
   sudo automount -cv
   ```
   This deletes every line mentioning `paperless_ngx_consume` (active and commented). Alternatively
   delete only line 6 and keep the commented ones.
2. Optional: remove the two commented `paperless-consume` lines from `/etc/fstab`.
3. I then re-run the checks above and paste the output.

Open for you: the Finder sidebar check (row 15), and whether to also touch the optional items
(rows 3, 4, 12).

## Phase 0.2 cleanup and verification (2026-10-21)

Done by the user (sudo/Keychain steps): `/etc/auto_nfs` backed up to `/etc/auto_nfs.bak-20261021` and
all `paperless_ngx_consume` lines removed; `automount -cv` run; `paperless-consume` lines removed from
`/etc/fstab`; old `/etc/auto_nfs.bak` removed; the two `192.168.1.150` Keychain entries deleted.

Re-run of the 0.1 checks:
- Mounts (`mount | grep nfs|smb|afp`, `nfsstat -m`): none.
- `/etc/auto_master`: no `auto_nfs` line; `/etc/synthetic.conf` absent.
- `grep paperless|consume` over `/etc/auto_*`, `/etc/fstab`, `/etc/nfs.conf`: no hits except the
  intentional backup `/etc/auto_nfs.bak-20261021`.
- Remaining `192.168.1.150` hits are the unrelated audiobooks/books/comics/comics2/torrents shares.
- `/Volumes`: no paperless mount point.
- launchd (3 dirs + `launchctl list`), crontab: nothing related.
- Keychain entries for `192.168.1.150` or `paperless`: 0.
- `~/bin`, `~/.local/bin`, `~/.zshrc`, `~/.zprofile`, `~/.zshenv`: no hits.
- Finder sidebar: checked by the user, no entry.

Result: clean. Phase 0 complete. Nothing was committed (no repo files changed besides this report).
