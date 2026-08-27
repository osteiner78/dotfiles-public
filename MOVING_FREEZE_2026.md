# Moving Freeze — August 2026

Temporary changes made on 2026-08-07 while moving house, without access to the external HDDs
connected to the OMV NAS (`192.168.1.150`). Expected to be reverted in ~2–3 months when settled.

---

## What Was Changed

### 1. `snoopy` — Docker pre-start NFS check disabled

**File:** `/etc/systemd/system/docker.service.d/override.conf`

The `ExecStartPre` line that verified NFS mounts before starting Docker was commented out.
Without this, Docker starts even if NFS shares are unavailable.

**To revert:**
```bash
# Edit /etc/systemd/system/docker.service.d/override.conf and uncomment:
# ExecStartPre=/bin/bash -c 'ls /mnt/nfs/videos /mnt/nfs/torrents /mnt/nfs/audiobooks /mnt/nfs/books > /dev/null'
sudo systemctl daemon-reload
sudo systemctl restart docker
```

---

### 2. `snoopy` — HDD-backed NFS volumes removed from Docker Compose

**File:** `~/dotfiles/docker/arr_stack/docker-compose.yaml`

The following volume mounts were commented out for `qbittorrent`, `radarr`, and `sonarr`:
- `/mnt/nfs/torrents:/data/torrents`
- `/mnt/nfs/videos:/data/videos`

**To revert:** Uncomment those lines and run:
```bash
cd ~/dotfiles/docker/arr_stack
docker compose up -d
```

---

### 3. `snoopy` — Stopped and disabled containers

The following containers were stopped (they depend on HDD-backed NFS shares or stopped services):

| Container | Compose file |
|-----------|-------------|
| sonarr | `arr_stack/docker-compose.yaml` |
| radarr | `arr_stack/docker-compose.yaml` |
| qbittorrent | `arr_stack/docker-compose.yaml` |
| prowlarr | `arr_stack/docker-compose.yaml` |
| tautulli | `arr_stack/docker-compose.yaml` |

**To revert:**
```bash
cd ~/dotfiles/docker/arr_stack
docker compose up -d
```

---

### 4. `snoopy` — Plex Media Server stopped and disabled

Plex was stopped and disabled to avoid errors scanning unavailable media paths.

**To revert:**
```bash
sudo systemctl enable plexmediaserver
sudo systemctl start plexmediaserver
```

---

### 5. OMV (`192.168.1.150`) — HDD-backed bind mounts disabled in fstab

**File:** `/etc/fstab` on the OMV NAS (backup at `/etc/fstab.bak`)

The 4 bind mounts backed by the `Pool_8TB_4GB` MergerFS pool (external HDDs) were commented out.
Without them, the NFS server could not start (they were hard dependencies).

Commented-out entries:
```
/srv/mergerfs/Pool_8TB_4GB/photos/          /export/photos          none  bind,nofail  0 0
/srv/mergerfs/Pool_8TB_4GB/torrents/        /export/torrents        none  bind,nofail  0 0
/srv/mergerfs/Pool_8TB_4GB/data/media/      /export/videos          none  bind,nofail  0 0
/srv/mergerfs/Pool_8TB_4GB/data/nextcloud_data/  /export/nextcloud_data  none  bind,nofail  0 0
```

**To revert (on the OMV):**
```bash
# Restore from backup or uncomment the 4 Pool_8TB_4GB lines in /etc/fstab
cp /etc/fstab.bak /etc/fstab
systemctl daemon-reload
systemctl start export-photos.mount export-torrents.mount export-videos.mount export-nextcloud_data.mount
systemctl restart nfs-server
```

Then also mount the shares on `snoopy`:
```bash
sudo mount /mnt/nfs/videos
sudo mount /mnt/nfs/torrents
sudo mount /mnt/nfs/photos
```

---

### 6. `snoopy` — `borgmatic.timer` stopped and disabled

**Discovered:** 2026-08-26 (log-analyst audit). Not an intentional day-1 freeze change,
but an untracked side effect of the move: the borgmatic backup target is a Raspberry
Pi at `192.168.1.100:49237`, which went unreachable starting 2026-08-06 (one day
before the freeze began) — presumably packed up / relocated along with everything else.

Symptom before this fix: `borgmatic.service` retried every 3h via its timer and failed
every single time with `ssh: connect to host 192.168.1.100 port 49237: No route to
host`, for 20 days straight with zero successful backups. The Uptime Kuma
failure-heartbeat was also 404ing on its push URL, so this was failing silently.

**To revert (once the Pi is back on the network):**
```bash
sudo systemctl enable --now borgmatic.timer
```
Then verify the next scheduled run succeeds:
```bash
journalctl -u borgmatic.service -n 50 --no-pager
```

---

## Services Left Running

These continue to work normally on SSD-backed NFS shares:

| Service | Share used |
|---------|-----------|
| kavita | `/mnt/nfs/comics`, `/mnt/nfs/comics2` |
| audiobookshelf | `/mnt/nfs/audiobooks` |
| calibre-web-luisa | `/mnt/nfs/books` |
| calibre-web-technical | `/mnt/nfs/books` |

---

---

## Proxmox VM Resource Reduction

On 2026-08-07, the VM's resources were reduced in Proxmox to reflect the lighter workload.

| Resource | Before | After |
|----------|--------|-------|
| vCPUs | 6 | 2 |
| RAM | 10 GB | 3 GB |
| Disk | 99 GB | 99 GB (unchanged) |

**To revert** (in Proxmox, with the VM shut down):
1. Select the VM → Hardware
2. Set Processors back to **6**
3. Set Memory back to **10240 MiB**
4. Start the VM

---

## Full Revert Checklist

When back with the HDDs:

- [ ] Plug in external HDDs to OMV, verify they appear as `/dev/disk/by-uuid/083fc007-...` and `d9e4318a-...`
- [ ] On OMV: restore `/etc/fstab` from backup and reload mounts (step 5 above)
- [ ] On `snoopy`: restore the `ExecStartPre` check in the Docker override (step 1 above)
- [ ] On `snoopy`: uncomment NFS volumes in `arr_stack/docker-compose.yaml` and bring stack up (steps 2–3 above)
- [ ] On `snoopy`: enable and start `plexmediaserver` (step 4 above)
- [ ] On `snoopy`: enable and start `borgmatic.timer` once the backup Pi (`192.168.1.100`) is back online (step 6 above)
