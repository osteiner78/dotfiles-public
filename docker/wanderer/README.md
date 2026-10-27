# wanderer

Self-hosted trail database ([wanderer.to](https://wanderer.to)) on **snoopy**, public at
**https://wanderer.osteiner.xyz** (Caddy on garfield → `192.168.1.101:3003`).

## Files
| Where | What |
|---|---|
| `docker-compose.yaml` | search (Meilisearch), db (PocketBase), web (SvelteKit) |
| `~/dotfiles-secrets/docker/wanderer/.env` | `ORIGIN`, `MEILI_MASTER_KEY`, `POCKETBASE_ENCRYPTION_KEY`, `POCKETBASE_PROXY_SECRET`, `PUBLIC_DISABLE_SIGNUP` |
| `/opt/wanderer/` on snoopy | data: `data.ms` (search index), `pb_data` (database), `plugins`, `uploads` |

## First install (snoopy)
The secrets repo needs an SSH remote on snoopy (HTTPS has no credentials there):
`git -C ~/dotfiles-secrets remote set-url origin git@github.com:osteiner78/dotfiles-secrets.git`
```bash
cd ~/dotfiles && git pull && cd ~/dotfiles-secrets && git pull
sudo mkdir -p /opt/wanderer/{data.ms,pb_data,plugins,uploads}
sudo chown -R "$USER": /opt/wanderer
ln -sf ~/dotfiles-secrets/docker/wanderer/.env ~/dotfiles/docker/wanderer/.env   # compose reads .env here (git-ignored)
cd ~/dotfiles/docker/wanderer && docker compose up -d
docker compose ps        # all three "healthy" after ~1 min
```
Then on garfield: `cd ~/dotfiles && git pull && sudo caddy validate --config /etc/caddy/Caddyfile && sudo systemctl reload caddy`
(the Caddyfile is stowed from `machines/garfield/caddy`). DNS: `wanderer.osteiner.xyz` must point to garfield, like the other subdomains.

## Account
1. Open https://wanderer.osteiner.xyz → Sign up (your account).
2. Close sign-ups: set `PUBLIC_DISABLE_SIGNUP=true` in the secrets `.env`, then `docker compose up -d`.
3. PocketBase admin (rarely needed): `ssh -L 8090:127.0.0.1:8090 snoopy` → http://localhost:8090/_/

## Bulk GPX import
1. In wanderer: Settings → create an **API token**.
2. On snoopy: `mkdir /opt/wanderer/uploads/<api-token>` (folder name = the token).
3. Copy files in (`.gpx`, `.fit`, `.kml`) via a staging dir, so the watcher never sees a half-written file
   (copying straight into the token folder made it reject files with 400 "Empty file" / "Invalid file"):
   ```bash
   ssh snoopy 'mkdir -p /opt/wanderer/staging'
   scp ~/Downloads/Tracks/*.gpx snoopy:/opt/wanderer/staging/
   ssh snoopy 'mv /opt/wanderer/staging/*.gpx /opt/wanderer/uploads/<api-token>/'
   ```
4. The watcher imports them while the container runs and deletes each imported file.
   Files left behind failed to import; check `docker logs wanderer-web`.
   The watcher only reacts to new files and never retries: move a leftover file out of the token folder and back in.
5. Afterwards remove the token folder and `/opt/wanderer/staging`, and delete the API token in wanderer.

Pitfalls:
- Wanderer merges all `<trk>` in one GPX into a single trail. Split multi-track files first, or you get duplicated
  routes and jumps between tracks. Check track dates before merging: order the pieces chronologically.
- A ~6 MB Strava GPX failed with 500 "Failed to create record"; the same file without the per-point `<extensions>`
  (heart rate, cadence; 2.3 MB) imported fine.

## Update
Read https://wanderer.to/changelog first (v0.21 added `POCKETBASE_PROXY_SECRET`), then
`docker compose pull && docker compose up -d`. Keep `getmeili/meilisearch` at the version the upstream compose uses.

## Backup
`/opt/wanderer/pb_data` holds trails and users (the search index can be rebuilt). snoopy's borgmatic backs up `/`, so it is included — as long as `borgmatic.timer` runs (it was stopped for the 2026 move, see `MOVING_FREEZE_2026.md`).
