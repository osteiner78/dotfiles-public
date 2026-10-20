# Upgrading paperless-ngx (routine procedure)

For regular updates after the v3 migration (see `MIGRATION-v3.md` for that history).
Run everything in `~/dotfiles/docker/paperless-ngx` on CT 206, inside tmux.
The tests that call the API need `PAPERLESS_TOKEN=<token>` in front of the command.

## Before

1. Read the release notes for every version between the current one and the target
   (https://github.com/paperless-ngx/paperless-ngx/releases), especially "Breaking changes".
   Don't skip a major version.
2. Proxmox host: `vzdump 206 --mode snapshot --compress zstd --storage nfs-backups-proxmox`.
3. `./upgrade-tests.sh backup` (database dump to `~/paperless-backups/`), then
   `./upgrade-tests.sh baseline` (counts to compare against).
4. Don't scan or upload until the upgrade is verified.

## Upgrade

```bash
sed -i 's#paperless-ngx:3.3.1#paperless-ngx:<new>#' docker-compose.yaml   # image tags are pinned
docker compose pull
./upgrade-tests.sh patches        # BEFORE up -d: is the local matching.py patch still valid?
docker compose up -d
docker compose logs -f webserver  # wait for migrations and "healthy"
```

If `patches` FAILs because upstream `matching.py` changed: either remove the two `patches`
mounts from `docker-compose.yaml` (runs unpatched), or diff the new upstream file against
`patches/matching.py.orig`, re-apply the blocks marked `LOCAL PATCH`, and update the hash in
the patch header and `matching.py.orig` (copy the new upstream file there).

## After

```bash
PAPERLESS_TOKEN=... ./upgrade-tests.sh verify <new>   # includes the patch guard
PAPERLESS_TOKEN=... ./upgrade-tests.sh consume        # sends ~4 ntfy notifications
docker compose exec -T webserver python3 manage.py document_index reindex   # consume deletes docs
PAPERLESS_TOKEN=... ./upgrade-tests.sh search
PAPERLESS_TOKEN=... ./upgrade-tests.sh ai
```

Then log in via https://paperless.osteiner.xyz and check the mobile app.
Commit the compose change. Delete the vzdump after ~2 weeks of normal use.

## Rollback

Restore the vzdump on the Proxmox host (reliable). Alternative: old tag in
`docker-compose.yaml` + restore the DB dump into a fresh `pgdata` volume + `up -d` +
`document_index reindex`; only valid if the new version's migrations didn't touch files.

## Other images

Tika, Gotenberg, Redis and Postgres are pinned too. Update them separately from paperless,
one at a time, and run `verify` + `consume` afterwards. A Postgres **major** upgrade
(16 → 18) needs a dump/restore and is a project of its own.

## Notes

- After deleting documents in bulk, run `document_index reindex` (Tantivy "more like this"
  panics on stale statistics, which empties AI-suggestion candidates).
- Documents consumed during an LLM index rebuild are dropped from it; run
  `document_llmindex update` afterwards (the nightly 02:10 update also catches them).
- Commands that write files (`document_index`, `document_llmindex`, `document_create_classifier`)
  must run as `--user paperless`, or the files end up owned by root.
