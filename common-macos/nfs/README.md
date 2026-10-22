# nfs (macOS)

Mounts the NAS `books` share at `~/NetworkDrives/books` with autofs, so the
Calibre app can open the libraries that live on the NAS (OpenMediaVault, 192.168.1.150).

```bash
~/dotfiles/common-macos/nfs/install.sh           # install / repair (asks for sudo)
~/dotfiles/common-macos/nfs/install.sh --check   # report drift, change nothing
```

**Run `--check` after every major macOS upgrade.** Upgrades replace
`/etc/auto_master` with the stock file (macOS 27 did). The share then silently
stops mounting, and Calibre creates an empty local library at the old path.

## What it manages

| File | Content |
|---|---|
| `/etc/auto_master` | adds `~/NetworkDrives  auto_nfs  -nobrowse,nosuid` (appended, rest untouched) |
| `/etc/auto_nfs` | copy of [`auto_nfs`](auto_nfs) — only `books` |

Existing files are backed up as `*.bak-<timestamp>` before any change.

## Why these options

- `hard` + NFS locking (no `nolockd`): each Calibre library is a SQLite
  `metadata.db`. calibre-web on snoopy opens the same files, and its mount is
  `hard` with locking too (see `machines/snoopy/nfs`).
- NAS export `books` uses `all_squash,anonuid=1000,anongid=1000`. The Mac (uid 501)
  and the containers (PUID 1000) therefore write as the same owner.
- `nfc`: normalises accented file names (book titles).

## Comics (SMB, not NFS)

`comics` and `comics2` are only used to drop new files for Kavita, so they are
SMB shares on the NAS (user `smbshare`, uid 1000):

1. Finder → ⌘K → `smb://smbshare@192.168.1.150/comics` (repeat for `comics2`), tick "Remember password".
2. System Settings → General → Login Items → add both mounted volumes.
