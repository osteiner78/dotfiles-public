# Paperless-ngx migration: 2.18.4 → 3.3.1 (+ AI features)

Written 2026-10-14 against the running instance in the `paperless-ngx` LXC. Every
finding below was checked on the live system or in the v3.3.1 source/docs, not
taken from release-note summaries.

**Path:** 2.18.4 → **2.20.15** → **3.3.1** → enable AI.
v3 can only be installed over 2.20.15 (official migration guide). Each hop is
gated by `upgrade-tests.sh`; don't start the next phase until the gate passes.

Files in this directory:

| File | Purpose |
| --- | --- |
| `MIGRATION-v3.md` | this plan |
| `upgrade-tests.sh` | test stages: `preflight`, `backup`, `baseline`, `verify`, `consume`, `search`, `ai` |
| `docker-compose.v3.yaml` | target compose file for phase 3 (validated with `docker compose config`) |

---

## 1. Current state

| Item | Value |
| --- | --- |
| Paperless-ngx | 2.18.4 (image tag `:latest`, pulled ~13 months ago) |
| Stack | Postgres 16, Redis 7, Tika 3.2.3 (`:latest`), Gotenberg 8.7 |
| Data | 6,320 documents, 6.7 GB media, 122 correspondents, 22 tags, 7 saved views, 2 workflows, 8 mail rules, 4 users |
| Encryption | none (all `unencrypted`), so the v3 encryption removal doesn't affect you |
| Host | CT 206 on Proxmox, i7-8559U, 4 vCPU, **3 GB RAM**, no GPU, root fs **50 GB** (resized from 35 GB on 2026-10-14), 22 GB free |
| Consume dir | NFS `192.168.1.150:/export/paperless_ngx_consume` (polling mode) |
| Public URL | `https://paperless.osteiner.xyz` through a reverse proxy elsewhere (resolves to a public IP) |

## 2. Findings

### 2a. Must change for v3 (handled in `docker-compose.v3.yaml`)

| v3 change | Your config | Action |
| --- | --- | --- |
| `PAPERLESS_DBENGINE` required for Postgres | not set (engine inferred from `DBHOST`) | add `PAPERLESS_DBENGINE: postgresql`. Without it v3 falls back to **SQLite** and starts with an empty database. |
| `CONSUMER_POLLING` renamed | `PAPERLESS_CONSUMER_POLLING: 10` | `PAPERLESS_CONSUMER_POLLING_INTERVAL: 10`. Keep polling, because inotify doesn't work on NFS. |
| `CONSUMER_POLLING_DELAY` removed | `5` | `PAPERLESS_CONSUMER_STABILITY_DELAY: 5` |
| Archive generation decoupled from OCR; new default `auto` skips archives for born-digital PDFs | v2 default (always archive): 6,011 of 6,256 PDFs have a PDF/A copy, 3.2 GB next to 3.4 GB of originals | **Decided: `auto`.** New born-digital PDFs are stored once. Scans, images and Office files still get an archive. **Existing archives are kept.** No v3 migration or command deletes them (checked all 28 migrations and `document_archiver` in v3.3.1). Admin-UI OCR settings are empty, so there's nothing to migrate there. |
| Duplicates are now imported by default | v2 rejected 290 byte-identical files (268 during the Nov 2024 bulk import) | **Decided: keep rejecting.** `PAPERLESS_CONSUMER_DELETE_DUPLICATES: 'true'` refuses the file and deletes it from the consume share. |
| Pre/post-consume scripts lose positional args | both scripts already use env vars (`DOCUMENT_WORKING_PATH`, `DOCUMENT_*`) | none. Verified in v3.3.1 docs that `DOCUMENT_WORKING_PATH` still exists; the `consume` test proves it end-to-end. |
| API versions < 9 removed | — | Third-party clients (mobile apps, scripts) must speak API v9+. Update apps before phase 3. |
| `PAPERLESS_SECRET_KEY` required | set in `.env` | none. Keep the same value so sessions/tokens survive. |
| Reverse proxy / allauth rate-limit IP detection changed | `PAPERLESS_TRUSTED_PROXIES` unset | only if login via the public URL returns 403: set it to the IP the proxy connects from |
| Search: Whoosh → Tantivy, index auto-rebuilt | 0 saved views use full-text rules; 2 notes | none. Note that a plain search term no longer matches note text (`notes.note:term`). |
| Task history dropped, `MailRule.maximum_age` clamped to 32767 | max age 365 | none |
| NumPy needs SSE4.2 | CPU has it | none |
| Removed: barcode scanner setting, DB SSL/pool vars, `OCR_SKIP_ARCHIVE_FILE`, `OCR_MODE=skip*` | none of them set | none |

Also checked: `PAPERLESS_OCR_USER_ARGS` (`invalidate_digital_signatures`,
`continue_on_soft_render_error`) still exist in OCRmyPDF 17.12, which v3.3.1 pins.
Every other setting you use still exists in the v3.3.1 configuration reference. 2.19
and 2.20 have no breaking changes. 2.20 moves the image to Debian Trixie, which the
`consume` test covers through your Python pre-consume script.

### 2b. Config errors and inconsistencies

1. **Plaintext passwords in logs (fix now).** `scripts/removepassword.py` prints every
   password it tries (`password is working:<pw>`, `password isn't working:<pw>`). Paperless
   logs script output, so `data/log/paperless.log*` contains ~870 such lines. Every admin
   can read them in the web UI log viewer. See phase 0.2.
2. **`PAPERLESS_IGNORE_DATES` defined twice with different values.** `.env` has 2 dates and the
   compose file has 4. The compose value wins, so the `.env` line is dead and misleading.
3. **`.env` uses `KEY: value`** instead of `KEY=value`. Compose tolerates it, but normalise it.
4. **Unpinned images.** `paperless-ngx:latest` and `tika:latest` would jump major versions on
   the next `pull` (a `:latest` pull today goes straight to v3 and skips 2.20.15). The phase 3
   compose pins everything.
5. **Gotenberg 8.7 is ~2 years old.** v3's reference compose uses 8.37, with an anchored
   allow-list regex (`^file:///tmp/.*`).
6. **Postgres collation mismatch.** Every connection warns `collation version 2.36 vs 2.41`.
   Fix in phase 4.
7. **Leftovers.** The `paperless-ai` (clusterzx) container has been stopped for 13 months and
   holds a **7 GB** image, which v3's built-in AI replaces. There's also a commented-out
   compose block, an unused `paperless-ai_data` volume, an empty `data/db.sqlite3`, the
   unused local `~/paperless-ngx/consume/` (holds only `.DS_Store` files) and a stale
   comment about the scripts mount.
8. **7 orphan files.** 6,327 originals on disk vs 6,320 documents (archive: 6,081 vs 6,074).
   The phase 3 sanity check lists them. Decide case by case, and don't bulk delete.
9. **Uncommitted changes** to `docker-compose.yaml` (timezone and OCR language).
10. Postgres password is the stock `paperless`. The DB port isn't published, so this is
    low risk, but it is in git.
11. Gmail IMAP errors on 2026-10-01 (DNS) and 2026-10-08 (auth) have not recurred in the
    last 48 h. They show up in `verify`'s log check only if they recur.

### 2c. Capacity

- **Disk:** resized to 50 GB with 22 GB free, about 30 GB after phase 0.1. That covers new
  images (~5 GB), a local `document_exporter` copy (6.7 GB) and the embedding model + index (~1 GB).
- **RAM:** 3 GB with ~1.2 GB available is enough for the upgrade. It's **not** enough for
  local embeddings (torch + model in the worker), so raise it to 6 GB before phase 5.

---

## 3. Phases

Every phase below assumes:

```bash
cd ~/dotfiles/docker/paperless-ngx
export PAPERLESS_TOKEN=...   # web UI → profile → My Profile → API Auth Token
```

### Phase 0: Preparation (no downtime)

**Status: complete (2026-10-15).** All gates passed on 2.18.4. Deviations from the steps below:

- **0.2:** `removepassword.py` also got an `except pikepdf.PdfError: return`. It called
  `pikepdf.open` on every file, so any non-PDF (docx, images) failed in pre-consume. This bug
  predates the plan. Old logs were deliberately **not** purged.
- **0.3:** `.env` keeps the secret key in single quotes (it contains `$`). The compose
  `IGNORE_DATES` (4 dates) is the effective value.
- **0.4:** `pct snapshot` is unsupported (bind mount `mp1`), but `vzdump --mode snapshot` works
  and is the rollback: `nfs-backups-proxmox:dump/vzdump-lxc-206-2026_10_15-02_39_54.tar.zst`
  (8.84 GB; excludes the NFS consume bind mount). DB dump: `~/paperless-backups/paperless-2.18.4-20261015-000305.sql.gz`.
- **0.5:** `preflight` 14 pass, `verify 2.18.4` 37 pass, `consume` 12 pass, `search` 5/5. The
  duplicate WARN is expected on v2. `verify` was fixed to handle the dict-valued `migration_status`.

**0.1 Remove leftovers**

```bash
docker rm paperless-ai && docker image rm clusterzx/paperless-ai:latest
docker image prune            # dangling old paperless/tika/redis/postgres layers
df -h /                       # expect ~30 GB free
```

**0.2 Stop logging passwords.** In `~/paperless-ngx/scripts/removepassword.py`, change
the two prints:

```python
print("password is working:" + password)   ->  print("PDF unlocked")
print("password isn't working:" + password) ->  (delete the line)
```

Then decide whether to purge the old logs. The passwords are in
`~/paperless-ngx/data/log/paperless.log*`. Deleting the rotated files (`.1`–`.14`) and
truncating `paperless.log` removes them. If any of these passwords protect anything
beyond PDFs, treat them as exposed.

**0.3 Tidy config.** Remove `PAPERLESS_IGNORE_DATES` from `.env` and rewrite the
remaining line as `PAPERLESS_SECRET_KEY=...`. Commit the pending compose changes.

**0.4 Backups**

- On the Proxmox host: `pct list`, then `vzdump <CTID> --mode snapshot --storage <backup-storage>`
  (the disk name suggests CTID 206). **This is the primary rollback.**
- `./upgrade-tests.sh backup` writes a Postgres dump to `~/paperless-backups/` (36 MB today).
- Optional: `docker compose exec -T webserver document_exporter ../export` (~6.7 GB, now fits
  locally). Copy it to the NAS and delete it locally afterwards.

**0.5 Test gate: prove the tests on the known-good v2**

```bash
./upgrade-tests.sh preflight      # expect 0 FAIL (disk now OK)
./upgrade-tests.sh baseline
./upgrade-tests.sh verify 2.18.4
./upgrade-tests.sh consume        # scan/OCR, locked PDF, DOCX, duplicate; then deletes them
./upgrade-tests.sh search
```

Running `consume` and `search` on v2 first means any later failure is caused by the
upgrade, not the test. You'll get 3 ntfy notifications from the `consume` run.

### Phase 1: 2.18.4 → 2.20.15 (~10 min downtime)

**Status: complete (2026-10-15).** `verify 2.20.15` 37 pass before test consumption, all 19
counts match the 2.18.4 baseline; `consume` 12 pass, `search` 5/5; public login OK. Notes:

- The first consume after the upgrade crashed once: the newer scikit-learn made the old
  `classification_model.pickle` stale and two parallel tasks both deleted it. One-time; the
  model retrained on the next task. Its ERROR line makes `verify` report "errors logged"
  until the log rotates.
- `upgrade-tests.sh`: the OCR marker match now ignores whitespace (newer Tesseract reads
  `UPG01 10415921`).

Don't scan or upload during phases 1–3.

```bash
sed -i 's#paperless-ngx:latest#paperless-ngx:2.20.15#' docker-compose.yaml
./upgrade-tests.sh backup && ./upgrade-tests.sh baseline
docker compose pull webserver && docker compose up -d
docker compose logs -f webserver        # wait for migrations + "healthy"
```

**Gate:** `verify 2.20.15`, `consume` and `search` all pass. Also log in through the
public URL once.

**Rollback:** set the tag to `2.18.4`, restore the dump taken just before
(`gunzip -c <dump> | docker compose exec -T db psql -U paperless -d paperless` into a fresh
`pgdata`), then `up -d`. Restoring the Proxmox snapshot is simpler.

### Phase 2: Prepare v3 (no downtime)

1. Review `docker-compose.v3.yaml` against the current file. The full effective env diff:
   ```
   - PAPERLESS_CONSUMER_POLLING=10            + PAPERLESS_CONSUMER_POLLING_INTERVAL=10
   - PAPERLESS_CONSUMER_POLLING_DELAY=5       + PAPERLESS_CONSUMER_STABILITY_DELAY=5
                                              + PAPERLESS_DBENGINE=postgresql
                                              + PAPERLESS_ARCHIVE_FILE_GENERATION=auto
                                              + PAPERLESS_CONSUMER_DELETE_DUPLICATES=true
   ```
   Images: `paperless-ngx:3.3.1`, `tika:3.3.1.0`, `gotenberg:8.37`. Postgres stays on 16
   and Redis on 7. Checked 2026-10-15 against the effective `docker compose config`: this is
   the complete diff (plus the gotenberg allow-list anchored with `^`), and all three tags exist.
   Optional, to shorten phase 3 downtime: `docker compose -f docker-compose.v3.yaml pull`.
2. Update any API clients or mobile apps to versions that support API v9+.
   **Done 2026-10-15:** `vzdump-lxc-206-2026_10_15-09_03_20.tar` (17.5 GB, uncompressed),
   DB dump `paperless-2.20.15-20261015-071322.sql.gz`, `baseline-2.20.15.env`, v3 images pre-pulled.
3. Take a fresh Proxmox snapshot. Then run `./upgrade-tests.sh backup && ./upgrade-tests.sh baseline`
   so the baseline is taken from 2.20.15.

### Phase 3: 2.20.15 → 3.3.1 (30–60+ min downtime)

**Status: upgrade done (2026-10-15), gate partly run.** Total downtime was only a few
minutes: the SHA-256 checksum migration took ~50 s and the container was healthy by 09:22.
`docker-compose.v2.yaml.bak` holds the old compose file.

- `verify 3.3.1 --sanity`: 44 pass, 0 fail, 1 skip (`/api/status/`, no token). All 19 counts
  match the 2.20.15 baseline, there are no errors or deprecations in the log, and the local and
  public login pages return 200.
- Sanity checker: 19 orphan warnings, not the 7 the plan expects. They are the 7 known
  orphan originals + their 7 archive copies, plus **5 stale thumbnails** (`0003949`, `0005969`,
  `0006051`, `0006457`, `0006458`.webp, from Oct 2024 – Jun 2025, no matching document).
  The thumbnails predate the upgrade, so v3's checker just reports them. Safe to delete after a look.
- With the token: `verify 3.3.1` 49 pass / 0 fail (the classifier and sanity-check task
  warnings are expected after the v3 task-history drop); `consume` 12 pass / 0 fail;
  `search` 4/5 (passes).
  - `consume` born-digital PDF: no archive copy, as intended with `auto`.
  - `consume` duplicate WARN: the test's duplicate was imported because `removepassword.py`
    re-saves every PDF with pikepdf, so the stored checksum differs from the source file's.
    Real duplicates are rejected and removed from the share: a copy of an existing original
    was refused (`duplicate of ... #617`). Same behaviour as on v2.
  - `search` miss: the test truncated `Coordonnées` to `Coordonne`, and Tantivy doesn't match
    partial words. `AVENTURIERS` finds the document, so the index is fine.
- **Duplicate fix (2026-10-15):** the old `removepassword.py` re-saved *every* PDF, so the
  stored checksum never matched the incoming file and re-downloaded PDFs were imported again
  (v3 checks the incoming file, `consumer.py:1046`, but stores the working copy's checksum,
  `consumer.py:891`). The script now returns early for unencrypted PDFs. Backup:
  `scripts/removepassword.py.bak-20261015`. Rerun `consume`: 13 pass, 0 warn, the duplicate is
  rejected. Documents imported before the fix still carry re-saved checksums, so a fresh copy
  of an *old* PDF is still imported.
- Classifier: v3 deleted the stale 2.20 model on load; retrained by hand with
  `document_create_classifier` (~2 min). Status shows WARNING until the first scheduled training task.
- Checked by Claude: public login OK (user), 7 saved views present (6 owned by `osteiner`,
  "Inbox" #2 by `admin`), mail rules run every 10 min with no errors, post-consume ntfy
  calls succeed in the log.
- Manual checklist complete (2026-10-15). Mobile app OK (user). Saved-view counts match the
  2.20.15 dump exactly (Current IDs 16, Inbox 43 ×2, Reembolsos 378, Empregada 164, Bills 1309,
  User Manuals 80). OCR: no UI overrides in Application configuration; effective settings equal
  the compose env. The 5 stale thumbnails belong to no document (not even in trash); remove
  them in phase 4.

```bash
cp docker-compose.yaml docker-compose.v2.yaml.bak
cp docker-compose.v3.yaml docker-compose.yaml
docker compose pull && docker compose up -d
docker compose logs -f webserver
```

**Expect a long first start.** Don't restart the container while migrations run.

- The checksum migration to SHA-256 re-reads all 6.7 GB of media.
- The Tantivy search index is rebuilt from scratch.
- Task history is dropped.

**Gate:**

```bash
./upgrade-tests.sh verify 3.3.1 --sanity   # --sanity lists the 7 orphan files; anything else is new
./upgrade-tests.sh consume
./upgrade-tests.sh search                  # rerun once the index rebuild has finished
```

Manual checks:

- [ ] Log in via `https://paperless.osteiner.xyz`. If you get a 403, set `PAPERLESS_TRUSTED_PROXIES`.
- [ ] Open each of the 7 saved views and confirm the counts look right.
- [ ] Mail: in Admin → Mail, run "process mail" (or wait 10 min) and check the log.
- [ ] Admin → Application configuration → OCR shows no surprises.
- [ ] You received the ntfy notifications from the `consume` run.
- [ ] Mobile app / API clients still work.

**Rollback:** restore the Proxmox snapshot from phase 2. This is the reliable path,
because v3 migrations rewrite checksums and the search index. The manual alternative:

1. Restore the 2.20.15 dump into a fresh `pgdata`.
2. Restore `docker-compose.v2.yaml.bak`.
3. Run `up -d`, then `docker compose exec webserver document_index reindex`.

### Phase 4: Housekeeping

**Status: complete (2026-10-15).** `REINDEX DATABASE` and `REFRESH COLLATION VERSION` ran
(2.36 → 2.41); new connections no longer warn. Also removed: the 5 stale thumbnails (no matching
document), `data/db.sqlite3`, the local `consume/` directory, dangling images and the `:latest` /
`tika:latest` / `gotenberg:8.7` tags (disk now 30 GB free). The `paperless-ngx:2.20.15` image is
kept as a local rollback until `docker-compose.v2.yaml.bak` is deleted.

```bash
docker compose exec db psql -U paperless -d paperless -c 'REINDEX DATABASE paperless;'
docker compose exec db psql -U paperless -d paperless -c 'ALTER DATABASE paperless REFRESH COLLATION VERSION;'
docker image prune
git add -A . && git commit   # compose, tests, plan
```

- Delete `docker-compose.v2.yaml.bak` and `docker-compose.v3.yaml` after ~2 weeks of stable running.
- Delete `data/db.sqlite3` and the unused local `consume/` directory.
- Optional later: Postgres 16 → 18 (dump/restore) and Redis → Valkey, as in v3's reference
  compose. Do these as separate changes.

---

## 4. Phase 5: AI features

v3 has built-in LLM features. They're off by default.

- **AI suggestions:** title, tags, correspondent, type, storage path and dates. Use the "Suggest"
  button, or have them fetched automatically for inbox documents.
- **LLM index (RAG):** a vector index of all documents, used to ground suggestions and to
  find similar documents.
- **Document chat:** asks questions of one document or the whole archive, with source links.

API endpoints (from the v3.3.1 source): `GET /api/documents/<id>/ai_suggestions/`,
`POST /api/documents/chat/` (`{"q": ..., "document_id": ...}`; streams text, and reports errors as HTTP 200 "Sorry, something went wrong"), and `llmindex_status` in `/api/status/`.

### 5.1 Decision: hosted LLM via OpenRouter, embeddings local

- **Generation (decided 2026-10-15):** `deepseek/deepseek-v4.1-flash` via OpenRouter, routed to
  **DeepInfra** (US, fp8, zero data retention) with fallback only to other ZDR endpoints, reasoning
  off. Pin the slug, not the `~latest` alias, so the model doesn't change under you.
  - Why not V4 Flash: DeepSeek retired it on 2026-09-10; the official API now serves V4.1 Flash
    under the old name, and OpenRouter's `deepseek-v4-flash` is the old weights on third-party
    hosts (often fp4 or Chinese clouds).
  - Why not DeepSeek's own API: data is stored in the PRC, inputs may be used for training
    (opt-out by email), no ZDR, and peak hours (03–06 and 08–12 Zurich, weekdays) cost double.
  - Fallback model if quality disappoints: `anthropic/claude-haiku-5.5` (same cost at this
    volume; change only `PAPERLESS_AI_LLM_MODEL` and drop the `provider.order`).
  - `EXTRA_PARAMS` **must** wrap `provider`/`reasoning` in `extra_body`: paperless passes it to
    the OpenAI SDK 2.48, which raises `TypeError` on unknown top-level keys (tested 2026-10-15).
- **Ruled out:**
  - A Claude subscription. Consumer OAuth tokens aren't allowed in third-party apps; only a paid
    Console API key is.
  - OpenCode Go. It's designed for coding-agent traffic and expects a custom user agent and an
    `x-opencode-session` header, which paperless can't send.
  - A local LLM. This CT has 3 GB RAM and no GPU.
- **Embeddings:** local `huggingface` with `intfloat/multilingual-e5-small` (the archive is
  pt/de/fr/en, and the default model is English-only). The full archive never leaves the network.

**What is sent, from the v3.3.1 source.** Nothing runs in the background, and results are cached
per document.

- **Suggest:** one request (about 4.5K tokens) with the instructions, the first 4,000 characters of
  the document, candidate tags/correspondents/types from the 15 most similar documents, and the
  first 1,000 characters of the 5 most similar documents. A second, small request translates the
  result into the user's UI language. Similar documents come from the embedding index, or from
  Tantivy full-text "more like this" when there is no index.
- **Chat:** the question is embedded locally, and the 5 best-matching chunks (~1,024 tokens each)
  plus the question are sent (about 6K tokens). The answer links up to 3 source documents.

**Cost.** DeepInfra via OpenRouter on 2026-10-15: $0.14/M input, $0.42/M output. Intake is about
21 documents a month (12-month average).

| Monthly use (assumed) | Input | Output | Cost |
| --- | --- | --- | --- |
| 50 suggestion runs (incl. translation, reasoning off) | 250K | 20K | $0.04 |
| 100 chat questions | 600K | 50K | $0.11 |
| **Total** | | | **≈ $0.15 / month** (10× usage ≈ $1.50) |

The real cost is the top-up: OpenRouter charges 5.5% (min $0.80) per purchase, and credit can
expire after a year, so buy $5 at a time. In OpenRouter's privacy settings, disable providers that
train on prompts; the `zdr: true` routing enforces zero retention per request anyway.

### 5.2 Phase 5a: AI suggestions (no RAM change)

**Status: enabled (2026-10-15).** `./upgrade-tests.sh ai`: 5 pass, 0 fail; served by DeepInfra,
~4–6 s per suggestion. Notes:

- The chat route is `/api/documents/chat/`, not `/api/chat/` (that falls through to the SPA and
  returns 302/403). The test now skips chat until 5b; without embeddings it fails with
  "Unsupported embedding backend: None".
- **Tantivy "more like this" panics after deletions** (`6320 >= 6322`, stale segment stats), so
  the model got **no** candidates from similar documents. `document_index reindex` (27 s) fixed it.
  Run it after deleting documents in bulk, e.g. after `upgrade-tests.sh consume`.
- Matching: the model returns existing IDs only for candidates from similar documents; paperless
  then name-matches the rest (exact, or ≥ 0.8 fuzzy, accents **not** stripped: "Itaú" ≠ "Itau").
- 5-document sample, reasoning off vs on: similar results (on matched one catch-all "Other
  correspondents" more), but on was 3–6× slower (12–31 s). Keep reasoning off.

1. Create an OpenRouter key, add a few dollars of credit, and set the privacy filter.
2. Add `PAPERLESS_AI_LLM_API_KEY=sk-or-...` to `.env`, which is git-ignored.
3. Uncomment the "5a" lines of the AI block in `docker-compose.yaml`:
   ```yaml
   PAPERLESS_AI_ENABLED: 'true'
   PAPERLESS_AI_LLM_BACKEND: openai-like
   PAPERLESS_AI_LLM_ENDPOINT: https://openrouter.ai/api/v1
   PAPERLESS_AI_LLM_MODEL: deepseek/deepseek-v4.1-flash
   PAPERLESS_AI_LLM_ALLOW_INTERNAL_ENDPOINTS: 'false'
   PAPERLESS_AI_LLM_EXTRA_PARAMS: '{"extra_body": {"provider": {"order": ["deepinfra"], "zdr": true}, "reasoning": {"enabled": false}}}'
   ```
   - Leave `PAPERLESS_AI_LLM_OUTPUT_LANGUAGE` unset so output follows each user's UI language.
   - Values in Admin → Application configuration **override** the env. Keep the AI fields there
     empty so the compose file stays the single source of truth.
4. Run `docker compose up -d && ./upgrade-tests.sh ai`. Expect a PASS for reachability and
   `ai_suggestions`, and WARN/DISABLED for the index and chat.
   - The test also sends one 5-token completion with the same routing and reads OpenRouter's
     generation stats: expect `served by DeepInfra` and a cost in fractions of a cent.
   - If `ai_suggestions` fails with a tool-call error, check openrouter.ai/activity for the
     provider's error; dropping `"order"` lets OpenRouter pick another ZDR host.
5. Settings → Documents:
   - Set suggestions to "both" (ML + AI).
   - Optionally turn off "Automatically request suggestions for inbox documents" to keep LLM calls
     explicit.

### 5.3 Phase 5b: chat + similar documents (local embeddings)

**Status: enabled (2026-10-16).** CT RAM 6 GB. `document_llmindex rebuild` (run with
`--user paperless`): 6,322 documents, 25k chunks, **3 h 30 min**, index 187 MB plus a 471 MB model
cache in `data/`. `./upgrade-tests.sh ai`: chat answers with source links. Notes:

- Peak CT memory 5.1 GB (build + 11 mail imports at once). With embeddings, the web process
  and each Celery worker load their own copy of the model (~1.3 GB each), so normal use is
  ~4.5 GB at peaks. Keep 6 GB.
- Documents consumed **during** a rebuild are dropped from the index when it finishes (10 were).
  Run `document_llmindex update` afterwards; the nightly 02:10 update also catches them.
- Retrieval quality (6-question sample, pt/en/fr/de/es): good for descriptive questions
  (Sunrise, insurance offer, expensas, condominium), but it misses acronyms ("IPTU" found
  nothing out of 146 matching documents). llama-index adds no `query:`/`passage:` prefix for
  e5 and paperless has no setting for it; a query-only prefix didn't change the hit count.
  Use normal search for keyword lookups and per-document chat for questions about one document.
- `upgrade-tests.sh` memory check now uses the CT's `free` total: `docker stats` kept
  reporting the old 3 GB as the limit after `pct set --memory`.

1. On the Proxmox host: `pct set 206 --memory 6144`. Then `./upgrade-tests.sh preflight` shows RAM PASS.
2. Uncomment the "5b" lines (`EMBEDDING_BACKEND: huggingface`,
   `EMBEDDING_MODEL: intfloat/multilingual-e5-small`) and run `docker compose up -d`.
3. Build the index in `tmux`: `docker compose exec webserver document_llmindex rebuild`.
   - The first run downloads the model into `data/`.
   - Embedding about 12M tokens on 4 CPU cores will take a while. Note the time.
   - After that, the daily cron (`10 2 * * *`) updates the index incrementally.
4. Run `./upgrade-tests.sh ai`. Everything should PASS, with worker memory under 85%.

### 5.4 AI test gate

```bash
./upgrade-tests.sh ai          # reachability, model listed, llmindex OK, ai_suggestions, chat, memory < 85%
```

Manual quality check:

- [ ] Ten recent, already-filed documents: compare the AI suggestions with what you actually
  assigned. Note hits and misses for each field.
- [ ] Five chat questions with known answers, e.g. "How much was the <X> invoice in <month>?"
  in pt, de and en. Check that the answers link to the correct source documents.
- [ ] "Similar documents" on 3 documents returns related items.
- [ ] Your provider dashboard shows the expected (small) usage.

**Rollback:** set `PAPERLESS_AI_ENABLED: 'false'` and run `up -d`. Nothing else changes. The
index stays in `data/` and can be deleted.

---

## 5. Test reference

| Stage | Checks | Run in phases |
| --- | --- | --- |
| `preflight` | disk ≥ 12 GB, SSE4.2, NFS mounted, RAM, no encrypted docs, mail-rule ages, secret key, target images exist, both compose files valid, recent DB dump | 0, 2, 5 |
| `backup` | `pg_dump` → `~/paperless-backups/*.sql.gz`, gzip integrity, table count | before 1 and 3 |
| `baseline` | 19 object counts (documents, tags, correspondents, custom fields, notes, views, workflows, mail, users, share links, files on disk) | before 1 and 3 |
| `verify <ver> [--sanity]` | image version, health, all 5 services, no unapplied migrations, v3 required/removed env vars, polling enabled, errors and deprecations in logs since start, counts == baseline, local + public login page, `/api/status/` components, optional sanity checker | 0, 1, 3 |
| `consume [--keep]` | generates a scanned PDF (OCR), a born-digital PDF, a password PDF using your `passwords.txt` (pre-consume script), and a DOCX (Tika/Gotenberg); drops them on the **NFS** share; checks the text of each file and its archive (born-digital: archive on v2, **none on v3** with `auto`), that the consume dir is emptied and that the duplicate is rejected; deletes the test docs via API | 0, 1, 3 |
| `search` | 5 random documents found by their own title words via the API | 0, 1, 3 |
| `ai` | backend + embedding endpoint reachable (keys stay inside the container), model listed, `llmindex_status`, `ai_suggestions` on a real document, chat answer, worker memory | 5 |

Already run against the live 2.18.4 on 2026-10-14:

- **`preflight`:** 12 pass. The one failure was disk (8 GB free); it now passes after the resize to 50 GB.
- **`baseline`, `backup`, `verify 2.18.4`:** 28 pass. The one failure was the old Gmail errors
  in the log window; the API checks were skipped (no token).
- **The `consume` document generator, run in the container:** OCR reads the reference string
  from the generated scan, the locked PDF really is locked, and your `removepassword.py`
  unlocks it.

Not run yet, because they write to the live archive or need your token: the
end-to-end `consume`, `search`, and the API parts of `verify`. Phase 0.5 runs them.
