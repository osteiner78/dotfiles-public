# nfs (snoopy)

The NAS NFS mounts (OpenMediaVault, 192.168.1.150) used by the Docker services on
snoopy: calibre-web, Kavita, Audiobookshelf, the arr stack and others.

```bash
cd ~/dotfiles/machines/snoopy/nfs
./apply.sh --check     # show the diff against /etc/fstab, change nothing
sudo ./apply.sh        # write it (backs up /etc/fstab first)
```

`apply.sh` owns only the block between its `>>> managed …` / `<<< end managed …`
markers in `/etc/fstab`. It refuses to write if any other line, such as the root
filesystem or swap, would change. It also refuses if the result has no `/` entry,
or if `findmnt --verify` fails. `/etc/fstab` itself is not stowed: it holds the
machine's root disk UUID.

## Notes

- `books` is `hard` with locking, because Calibre's `metadata.db` is SQLite and
  is also opened from the Mac. Locking needs `rpc-statd`. It is a static unit
  that NFS starts on demand, so `systemctl start rpc-statd` works but
  `enable` does not.
- The other shares are still `soft,nolock`. Consider `hard` for those that get
  written to: torrents, audiobooks, comics.
- The Mac side lives in `common-macos/nfs`.
