# Scanner intake: handoff for the notebook agent

Goal: scans saved on the notebook should reach paperless-ngx automatically, with no manual
drag and drop. This file describes the server side as of 2026-10-20. Server config lives
next to this file (`docker-compose.yaml`); `MIGRATION-v3.md` has the full history.
No secrets are in this file; ask the user for the API token.

## 1. The server

| | |
|---|---|
| Software | paperless-ngx **3.3.1** (Docker), Postgres 16, Redis 7, Tika 3.3.1.0, Gotenberg 8.37 |
| Host | Proxmox LXC CT 206 `paperless-ngx`, Ubuntu 24.04, **192.168.1.206** |
| Web UI / API (LAN) | `http://192.168.1.206:8000` |
| Web UI / API (anywhere) | `https://paperless.osteiner.xyz` (reverse proxy elsewhere; API answers 401 without auth) |
| User | `osteiner` (superuser). Documents uploaded with this token are owned by `osteiner`. |
| Archive | ~6,340 documents, mostly pt/de/fr/en, some es |

## 2. Two ways to get files in

### A. REST API upload (recommended)

Works on the LAN and remotely, returns a task ID you can check, and can set metadata.

```bash
curl -s -H "Authorization: Token $PAPERLESS_TOKEN" -H "Accept: application/json; version=9" \
  -F "document=@2026-10-20 - Scan.pdf" \
  https://paperless.osteiner.xyz/api/documents/post_document/
# -> "b1ad602d-..."   (task UUID, as a JSON string)
```

Optional form fields (v3.3.1): `title`, `created` (ISO date/datetime), `correspondent` (id),
`document_type` (id), `storage_path` (id), `tags` (id; repeat the field for several),
`archive_serial_number` (int), `custom_fields` (JSON). IDs come from
`GET /api/correspondents/?page_size=1000`, `/api/document_types/`, `/api/tags/`. Don't create
new tags or correspondents without asking the user; the server's auto-matching assigns them anyway.

Check the result:

```bash
curl -s -H "Authorization: Token $PAPERLESS_TOKEN" -H "Accept: application/json; version=9" \
  "https://paperless.osteiner.xyz/api/tasks/?task_id=<uuid>"
```

Fields: `status` (`PENDING`/`STARTED`/`SUCCESS`/`FAILURE`), `result` (message, e.g. the
duplicate reason), `related_document` (new document id on success), `duplicate_documents`.
Consumption takes ~10–60 s per document (OCR); poll every few seconds with a timeout of a few minutes.

- **API version:** send `Accept: application/json; version=9` (or 10). Versions below 9 were
  removed in v3.
- **Token:** the user's existing token (web UI → profile → My Profile → API Auth Token). Store it
  in the macOS Keychain, not in a script. A single token per user; regenerating it logs out the
  mobile app.
- **Upload size limit:** not known for the public URL (set by the reverse proxy). Test once with
  the largest scan you expect (e.g. 50 MB); the LAN URL has no proxy in front.

### B. Consume folder on the NAS (LAN only)

| | |
|---|---|
| NAS | OpenMediaVault, **192.168.1.150** (web UI on port 80) |
| Export | NFSv3 `192.168.1.150:/export/paperless_ngx_consume`, allowed for `192.168.1.0/24`, `sec=sys` |
| Other protocols | **None for this share today**: SMB (445) and FTP (21) are closed on the NAS. An SMB share of the same folder could be added in OMV if needed. |
| Permissions | directory mode `2777` (setgid), owner `nobody:nogroup`, plus an ACL: any UID can write |
| On the server | mounted at `/mnt/nfs/paperless_ngx_consume`, bind-mounted into the container as `/usr/src/paperless/consume` |

macOS mount (manual test):

```bash
sudo mkdir -p /Volumes/paperless-consume
sudo mount -t nfs -o resvport,vers=3 192.168.1.150:/export/paperless_ngx_consume /Volumes/paperless-consume
```

`resvport` is usually required by Linux NFS servers. For a permanent mount use `/etc/auto_master` +
an automount map, or a launchd job that mounts before copying.

**How the consumer watches the folder:**

- **Polling** every **10 s** (inotify doesn't work over NFS); a file is taken once it has been
  unchanged for **5 s**. Copying straight into the folder is fine.
- **Not recursive**: only files directly in the folder are consumed. Subfolders are ignored, and
  subfolder names are **not** turned into tags.
- Ignored automatically: `.DS_Store`, `._*`, `Thumbs.db`, `.stfolder/*`, `@eaDir/*` and similar.
  Other files with unsupported types are attempted and fail with an error in the log.
- **After success the file is deleted from the folder.** A rejected duplicate is deleted too
  (`PAPERLESS_CONSUMER_DELETE_DUPLICATES=true`). A file that fails for another reason stays there.
- There is no per-file status in this mode. Confirm through the API (search
  `GET /api/documents/?title__icontains=...` or the tasks list) or the ntfy notification.

**Either way, keep the notebook's own copy** until paperless confirms the document; the
consume folder is not an archive.

## 3. What the server does with each file

1. **Pre-consume script** `removepassword.py`: password-protected PDFs are unlocked with a list of
   known passwords (kept on the server). Unencrypted PDFs are left byte-identical.
2. **Duplicate check**: SHA-256 of the incoming file against all stored documents (including the
   trash). Exact duplicates are rejected. (PDFs imported before 2026-10-15 were re-saved by an
   older script, so a re-scan of an old paper won't match anyway; re-scans never match byte-wise.)
3. **Parsing / OCR**: OCRmyPDF with languages `deu+eng+fra+por`, `OCR_MODE=auto` (pages that
   already contain text are not OCRed again). Office files, `.eml`, etc. go through Tika/Gotenberg.
4. **Archive copy**: `ARCHIVE_FILE_GENERATION=auto`, so a PDF/A archive copy is made for scans,
   not for born-digital PDFs.
5. **Dates**: content dates are read as day-month-year (`DATE_ORDER=DMY`). A filename starting
   with `YYYY-MM-DD` sets the created date (`FILENAME_DATE_ORDER=Y-M-D`). Four personal dates
   (birthdays etc.) are ignored.
6. **Title** = filename without extension, unless `title` is sent via the API.
7. **Classification**: the tag **Inbox** is added to every new document. The auto-matching model
   (retrained hourly) assigns correspondent, document type and tags. Two workflows add custom
   fields (bills: "Paid?"; Reembolsos: reimbursement fields).
8. **Post-consume script**: a push notification to the user's phone (ntfy) with file name,
   correspondent and tags.
9. **Search + AI**: added to the full-text index and to the LLM index (embeddings via OpenRouter).
   AI suggestions are on demand: `GET /api/documents/<id>/ai_suggestions/` (title, tags,
   correspondent, type, dates; ~4 s, a fraction of a cent).

Stored filename: `{correspondent}/{YYYY}-{MM}-{DD} - {correspondent} - {title}`.

## 4. File formats and scanner settings

- Supported: PDF, PNG, JPEG, TIFF, GIF, WebP, plain text, and via Tika: DOCX/ODT/XLSX/PPTX, EML.
- **One document = one file.** Barcode splitting, ASN barcodes and double-sided collation are all
  **disabled** on the server (could be enabled; ask the user, then the server-side session changes
  `docker-compose.yaml`).
- Recommended scans: PDF, 300 dpi, greyscale/colour as needed. The scanner's own OCR is optional;
  the server OCRs image-only pages in four languages.
- Recommended filename: `YYYY-MM-DD - short description.pdf` (sets the date and a readable title).
  Avoid `/` and characters that are invalid on Linux filesystems.

## 5. Suggested design for the notebook

1. Watch the scanner's output folder (launchd `WatchPaths`, a Folder Action, or a small daemon).
2. Wait until the file is complete (size stable for a few seconds).
3. Upload via **API (A)**, prefer the LAN URL when on the home network, the public URL otherwise.
4. Poll the task: on `SUCCESS`, move the local file to a `done/` folder (or delete it after N days);
   on `FAILURE` with a duplicate message, move it to `duplicates/`; on other failures, keep it in
   `failed/` with the error message and notify the user.
5. Log every upload (file, task id, document id, result).

Fallback when the API isn't reachable: copy into the NFS consume folder (B) when on the LAN.

## 6. Test checklist

- [ ] Upload a small 1-page scan via the API on the LAN: task `SUCCESS`, document has OCR text,
      tag Inbox, a phone notification arrives.
- [ ] Same via the public URL from outside the LAN.
- [ ] Upload the same file again: task `FAILURE` with a duplicate message, nothing new in paperless.
- [ ] Largest expected scan: no 413 error from the reverse proxy.
- [ ] Filename `2026-01-15 - Test.pdf`: created date is 2026-01-15, title "2026-01-15 - Test".
- [ ] Afterwards delete the test documents in paperless (and empty the trash) so they don't
      block real files as duplicates.

## 7. Things not to change from the notebook

Server settings, scripts and the paperless database are managed from the paperless container
(dotfiles `docker/paperless-ngx/`). If intake needs a server change (SMB share, barcodes,
recursive consume folder, double-sided collation), describe it to the user instead.
