#!/usr/bin/env bash
# Upgrade tests for the paperless-ngx v2.18 -> v2.20.15 -> v3.3.1 migration.
# See MIGRATION-v3.md for when to run each stage.
#
# Usage: ./upgrade-tests.sh <stage> [args]
#   preflight                 read-only checks before touching anything
#   backup                    pg_dump the database into $BACKUP_DIR
#   baseline                  record object/file counts to compare against later
#   verify <version> [--sanity]
#                             post-upgrade checks; --sanity also runs the (slow) sanity checker
#   consume [--keep]          end-to-end: scan PDF (OCR), born-digital PDF (no archive on v3),
#                             password PDF (pre-script), DOCX (Tika), duplicate rejection;
#                             deletes the test documents unless --keep
#   search                    full-text search finds known documents (run after index rebuild)
#   ai                        AI backend reachability, LLM index status, suggestions, chat
#   patches [image]           local patches/*.py: upstream file unchanged in the image (default:
#                             the one in docker-compose.yaml), active, own tests pass
#
# Env: PAPERLESS_TOKEN  API token (profile menu -> "My Profile" -> API Auth Token);
#                       needed for API checks, cleanup, search and ai stages.
#      PUBLIC_URL       default https://paperless.osteiner.xyz
#      CONSUME_DIR      default /mnt/nfs/paperless_ngx_consume
#      STATE_DIR        default ~/paperless-ngx/upgrade-state
#      BACKUP_DIR       default ~/paperless-backups

set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PUBLIC_URL="${PUBLIC_URL:-https://paperless.osteiner.xyz}"
LOCAL_URL="http://localhost:8000"
CONSUME_DIR="${CONSUME_DIR:-/mnt/nfs/paperless_ngx_consume}"
STATE_DIR="${STATE_DIR:-$HOME/paperless-ngx/upgrade-state}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/paperless-backups}"
TOKEN="${PAPERLESS_TOKEN:-}"
# API v9 is the only version accepted by both 2.18.x (1-9) and 3.x (9-10).
ACCEPT="Accept: application/json; version=9"

PASS=0 FAIL=0 WARN=0 SKIP=0
c_g=$'\e[32m' c_r=$'\e[31m' c_y=$'\e[33m' c_b=$'\e[34m' c_0=$'\e[0m'
pass() { echo "  ${c_g}PASS${c_0} $*"; PASS=$((PASS + 1)); }
fail() { echo "  ${c_r}FAIL${c_0} $*"; FAIL=$((FAIL + 1)); }
warn() { echo "  ${c_y}WARN${c_0} $*"; WARN=$((WARN + 1)); }
skip() { echo "  ${c_b}SKIP${c_0} $*"; SKIP=$((SKIP + 1)); }
section() { echo; echo "== $*"; }
summary() {
  echo
  echo "Result: ${PASS} passed, ${FAIL} failed, ${WARN} warnings, ${SKIP} skipped"
  [ "$FAIL" -eq 0 ]
}

dc() { docker compose --project-directory "$DIR" -f "$DIR/docker-compose.yaml" "$@"; }
psql_q() { dc exec -T db psql -U paperless -d paperless -tA -c "$1" 2>/dev/null; }
web() { dc exec -T webserver "$@"; }
web_user() { dc exec -T -u paperless webserver "$@"; }
image_version() {
  docker inspect "$(dc ps -q webserver)" \
    --format '{{index .Config.Labels "org.opencontainers.image.version"}}' 2>/dev/null
}
major() { echo "${1%%.*}"; }
need_token() {
  if [ -z "$TOKEN" ]; then skip "$1 (set PAPERLESS_TOKEN)"; return 1; fi
}
api() { # api <method> <path> [curl args...]
  local m="$1" p="$2"; shift 2
  curl -sS -X "$m" -H "Authorization: Token $TOKEN" -H "$ACCEPT" "$@" "$LOCAL_URL$p"
}
json() { python3 -I -c "import json,sys; d=json.load(sys.stdin); $1"; }

# ---------------------------------------------------------------- preflight
stage_preflight() {
  section "Host"
  local free_gb
  free_gb=$(df -BG --output=avail / | tail -1 | tr -dc 0-9)
  if [ "$free_gb" -ge 12 ]; then pass "root fs has ${free_gb}G free"
  else fail "root fs has only ${free_gb}G free (need ~12G: images + pg_dump headroom). See MIGRATION-v3.md phase 0"; fi
  grep -q -m1 sse4_2 /proc/cpuinfo && pass "CPU has SSE4.2 (v3 NumPy baseline)" || fail "CPU lacks SSE4.2"
  mountpoint -q "$CONSUME_DIR" && pass "consume NFS share mounted at $CONSUME_DIR" || fail "$CONSUME_DIR not mounted"
  local mem_mb
  mem_mb=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo)
  if [ "$mem_mb" -ge 5500 ]; then pass "container RAM ${mem_mb}M"
  else warn "container RAM ${mem_mb}M; fine for the upgrade, raise to 6G before enabling local AI embeddings"; fi

  section "Running instance"
  local v
  v=$(image_version)
  [ -n "$v" ] && pass "running paperless-ngx $v" || fail "webserver container not found"
  local enc
  enc=$(psql_q "select count(*) from documents_document where storage_type <> 'unencrypted'")
  [ "$enc" = "0" ] && pass "no encrypted documents (v3 removed encryption)" || fail "$enc encrypted documents: run decrypt_documents first"
  local mx
  mx=$(psql_q "select coalesce(max(maximum_age),0) from paperless_mail_mailrule")
  [ "${mx:-0}" -le 32767 ] && pass "mail rule maximum_age <= 32767" || warn "mail rule maximum_age $mx will be clamped to 32767"
  web sh -c '[ -n "${PAPERLESS_SECRET_KEY:-}" ]' && pass "PAPERLESS_SECRET_KEY is set (required in v3)" \
    || fail "PAPERLESS_SECRET_KEY not set"

  section "Target images exist"
  local img
  for img in ghcr.io/paperless-ngx/paperless-ngx:2.20.15 ghcr.io/paperless-ngx/paperless-ngx:3.3.1 \
    docker.io/apache/tika:3.3.1.0 docker.io/gotenberg/gotenberg:8.37; do
    docker manifest inspect "$img" >/dev/null 2>&1 && pass "$img" || fail "$img not found in registry"
  done

  section "Compose files"
  dc config -q && pass "docker-compose.yaml is valid" || fail "docker-compose.yaml invalid"
  if [ -f "$DIR/docker-compose.v3.yaml" ]; then
    docker compose --project-directory "$DIR" -f "$DIR/docker-compose.v3.yaml" config -q \
      && pass "docker-compose.v3.yaml is valid" || fail "docker-compose.v3.yaml invalid"
  fi

  section "Backups"
  local dump
  dump=$(ls -t "$BACKUP_DIR"/paperless-*.sql.gz 2>/dev/null | head -1)
  if [ -n "$dump" ] && [ -n "$(find "$dump" -mmin -1440)" ]; then pass "recent DB dump: $dump"
  else warn "no DB dump from the last 24h in $BACKUP_DIR (run: $0 backup)"; fi
  warn "Proxmox snapshot/backup of this CT cannot be checked from inside; confirm it manually"

  # The image named in docker-compose.yaml: run this after changing the tag, before `up -d`.
  stage_patches
}

# ------------------------------------------------------------------- backup
stage_backup() {
  section "Database dump"
  mkdir -p "$BACKUP_DIR"
  local f
  f="$BACKUP_DIR/paperless-$(image_version)-$(date +%Y%m%d-%H%M%S).sql.gz"
  if dc exec -T db pg_dump -U paperless -d paperless 2>/dev/null | gzip > "$f" && gzip -t "$f"; then
    local tables
    tables=$(zcat "$f" | grep -c '^CREATE TABLE')
    [ "$tables" -gt 20 ] && pass "dumped $tables tables to $f ($(du -h "$f" | cut -f1))" \
      || fail "dump looks incomplete ($tables tables): $f"
  else
    fail "pg_dump failed"
  fi
}

# ----------------------------------------------------------------- baseline
collect_counts() {
  local root_filter=""
  if [ "$(psql_q "select count(*) from information_schema.columns
      where table_name='documents_document' and column_name='root_document_id'")" = "1" ]; then
    root_filter="and root_document_id is null"  # v3 stores file versions as extra rows
  fi
  local -A q=(
    [documents]="select count(*) from documents_document where deleted_at is null $root_filter"
    [documents_trashed]="select count(*) from documents_document where deleted_at is not null $root_filter"
    [documents_with_archive]="select count(*) from documents_document where deleted_at is null and archive_filename is not null $root_filter"
    [tags]="select count(*) from documents_tag"
    [correspondents]="select count(*) from documents_correspondent"
    [document_types]="select count(*) from documents_documenttype"
    [storage_paths]="select count(*) from documents_storagepath"
    [custom_fields]="select count(*) from documents_customfield"
    [custom_field_instances]="select count(*) from documents_customfieldinstance"
    [notes]="select count(*) from documents_note"
    [saved_views]="select count(*) from documents_savedview"
    [workflows]="select count(*) from documents_workflow"
    [mail_accounts]="select count(*) from paperless_mail_mailaccount"
    [mail_rules]="select count(*) from paperless_mail_mailrule"
    [users]="select count(*) from auth_user"
    [groups]="select count(*) from auth_group"
    [share_links]="select count(*) from documents_sharelink"
  )
  local k
  for k in "${!q[@]}"; do echo "$k=$(psql_q "${q[$k]}")"; done
  echo "files_originals=$(find "$HOME/paperless-ngx/media/documents/originals" -type f | wc -l)"
  echo "files_archive=$(find "$HOME/paperless-ngx/media/documents/archive" -type f | wc -l)"
}

stage_baseline() {
  section "Baseline"
  mkdir -p "$STATE_DIR"
  local v f
  v=$(image_version)
  f="$STATE_DIR/baseline-$v.env"
  collect_counts | sort > "$f"
  ln -sf "$(basename "$f")" "$STATE_DIR/baseline-latest.env"
  sed 's/^/    /' "$f"
  pass "baseline for $v written to $f"
}

# ------------------------------------------------------------------- verify
stage_verify() {
  local expected="${1:-}" sanity="${2:-}"
  [ -z "$expected" ] && { echo "usage: $0 verify <expected-version> [--sanity]"; exit 2; }

  section "Containers"
  local v cid health started
  v=$(image_version)
  [ "$v" = "$expected" ] && pass "webserver runs $v" || fail "webserver runs '$v', expected $expected"
  cid=$(dc ps -q webserver)
  health=$(docker inspect "$cid" --format '{{.State.Health.Status}}' 2>/dev/null)
  [ "$health" = "healthy" ] && pass "webserver healthy" || fail "webserver health: ${health:-unknown}"
  local s
  for s in db broker tika gotenberg; do
    [ "$(docker inspect "$(dc ps -q $s)" --format '{{.State.Running}}' 2>/dev/null)" = "true" ] \
      && pass "$s running" || fail "$s not running"
  done

  section "Migrations"
  local pending
  pending=$(web python3 manage.py showmigrations --plan 2>/dev/null | grep -c '^\[ \]')
  [ "$pending" = "0" ] && pass "all migrations applied" || fail "$pending migrations not applied"

  section "Configuration ($expected)"
  local envs
  envs=$(web env)
  if [ "$(major "$expected")" -ge 3 ]; then
    local var
    for var in PAPERLESS_SECRET_KEY PAPERLESS_DBENGINE; do
      grep -q "^$var=." <<<"$envs" && pass "$var set" || fail "$var missing (required in v3)"
    done
    for var in PAPERLESS_CONSUMER_POLLING PAPERLESS_CONSUMER_POLLING_DELAY PAPERLESS_CONSUMER_POLLING_RETRY_COUNT \
      PAPERLESS_CONSUMER_INOTIFY_DELAY PAPERLESS_CONSUMER_BARCODE_SCANNER PAPERLESS_OCR_SKIP_ARCHIVE_FILE \
      PAPERLESS_DBSSLMODE PAPERLESS_DB_POOLSIZE PAPERLESS_DB_TIMEOUT; do
      grep -q "^$var=" <<<"$envs" && fail "$var is removed in v3, delete it" || pass "$var not set"
    done
    grep -q -E '^PAPERLESS_OCR_MODE=skip' <<<"$envs" && fail "PAPERLESS_OCR_MODE=skip* removed in v3" \
      || pass "no removed OCR_MODE value"
    grep -q '^PAPERLESS_CONSUMER_POLLING_INTERVAL=[1-9]' <<<"$envs" \
      && pass "polling enabled (needed for NFS consume dir)" || fail "PAPERLESS_CONSUMER_POLLING_INTERVAL not set; NFS changes won't be detected"
  fi

  section "Logs since container start"
  started=$(docker inspect "$cid" --format '{{.State.StartedAt}}')
  local logs errors deprec
  logs=$(dc logs --no-color --since "$started" webserver 2>&1)
  errors=$(grep -E '\[(ERROR|CRITICAL)\]|Traceback' <<<"$logs" | grep -v -i 'xfa/promoted-desc')
  deprec=$(grep -i -E 'deprecat|removed setting|no longer supported' <<<"$logs" \
    | grep -v -E 'tzlocal|CPendingDeprecationWarning|django/utils/deprecation\.py')  # harmless library noise / traceback frames
  [ -z "$errors" ] && pass "no errors logged" || { fail "errors logged:"; tail -15 <<<"$errors" | sed 's/^/      /'; }
  [ -z "$deprec" ] && pass "no deprecation warnings" || { warn "deprecation warnings:"; sed 's/^/      /' <<<"$deprec" | tail -10; }

  section "Data integrity vs baseline"
  local base="$STATE_DIR/baseline-latest.env"
  if [ ! -f "$base" ]; then
    skip "no baseline (run: $0 baseline before upgrading)"
  else
    echo "    baseline: $(readlink "$base")"
    local now k old new
    now=$(collect_counts | sort)
    while IFS='=' read -r k old; do
      new=$(grep "^$k=" <<<"$now" | cut -d= -f2)
      if [ "$new" = "$old" ]; then pass "$k = $new"
      elif [[ "$k" == documents* || "$k" == files_* ]] && [ "${new:-0}" -gt "$old" ]; then
        warn "$k grew $old -> $new (documents consumed since baseline?)"
      else fail "$k changed $old -> ${new:-<missing>}"; fi
    done < "$base"
  fi

  section "HTTP"
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' "$LOCAL_URL/accounts/login/")
  [ "$code" = "200" ] && pass "local login page 200" || fail "local login page $code"
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$PUBLIC_URL/accounts/login/")
  [ "$code" = "200" ] && pass "public login page 200 via reverse proxy" || fail "public login page $code"
  echo "    manual: log in via $PUBLIC_URL in a browser; a 403 on login means PAPERLESS_TRUSTED_PROXIES is needed"

  section "API /api/status/"
  if need_token "system status"; then
    local st
    st=$(api GET /api/status/)
    if [ -z "$st" ] || ! json 'pass' <<<"$st" 2>/dev/null; then
      fail "status endpoint did not return JSON (bad token?)"
    else
      local k val err
      while IFS=$'\t' read -r k val err; do
        case "$val" in
          OK|DISABLED) pass "$k=$val" ;;
          WARNING) warn "$k=$val $err" ;;
          *) fail "$k=$val $err" ;;
        esac
      done < <(json '
for section in ("database", "tasks"):
    s = d.get(section, {})
    for k, v in s.items():
        if k == "migration_status" and isinstance(v, dict):
            un = v.get("unapplied_migrations") or []
            print(section + "." + k + "\t" + ("OK" if not un else "UNAPPLIED") + "\t" + ",".join(un))
        elif k.endswith("status"):
            err = s.get(k[:-6] + "error") or s.get("error") or ""
            print(section + "." + k + "\t" + str(v) + "\t" + str(err))
' <<<"$st")
      echo "    (index/classifier WARNING/ERROR right after a v3 upgrade is expected until the rebuild finishes)"
    fi
  fi

  if [ "$sanity" = "--sanity" ]; then
    section "Sanity checker (reads every file; takes several minutes)"
    local out rc
    out=$(web document_sanity_checker 2>&1); rc=$?
    local serr
    serr=$(grep -c -E 'ERROR|\[E' <<<"$out")
    if [ "$rc" -eq 0 ] && [ "$serr" -eq 0 ]; then pass "sanity checker clean"
    else fail "sanity checker exit=$rc, $serr error lines:"; grep -E 'ERROR|\[E' <<<"$out" | head -20 | sed 's/^/      /'; fi
    grep -i -c 'warn' <<<"$out" | { read -r n; [ "$n" -gt 0 ] && echo "    ($n warning lines; review with: docker compose exec webserver document_sanity_checker)"; }
  fi

  stage_patches
}

# ------------------------------------------------------------------ consume
stage_consume() {
  local keep="${1:-}"
  local run="UPG$(date +%H%M%S)$((RANDOM % 9000 + 1000))"
  section "Generating test documents ($run)"
  # Generated inside the webserver container (it has Pillow + pikepdf), as the paperless
  # user so the NFS share accepts the files, then copied into the consume dir.
  if ! web_user python3 - "$run" <<'PY'
import sys, zipfile, shutil, pathlib
from PIL import Image, ImageDraw, ImageFont
import pikepdf
run = sys.argv[1]
tmp = pathlib.Path("/tmp/upgtest"); shutil.rmtree(tmp, ignore_errors=True); tmp.mkdir()
consume = pathlib.Path("/usr/src/paperless/consume")

def scan(path):
    img = Image.new("RGB", (1700, 2200), "white")
    d = ImageDraw.Draw(img)
    try:
        font = ImageFont.load_default(size=80)
    except TypeError:
        font = ImageFont.truetype("DejaVuSans.ttf", 80)
    for i, line in enumerate(["Paperless upgrade test", f"Reference {run}", "Invoice total 123.45"]):
        d.text((150, 300 + i * 200), line, fill="black", font=font)
    img.save(path, "PDF", resolution=200.0)

scan(tmp / f"upgtest-{run}-scan.pdf")

def digital(path):
    # Born-digital PDF: real text layer, no image. Written by hand (no PDF library needed).
    lines = ["Paperless upgrade digital test", f"Reference {run}"]
    stream = "BT /F1 24 Tf 72 720 Td 30 TL " + " ".join(f"({l}) Tj T*" for l in lines) + " ET"
    objs = ["<< /Type /Catalog /Pages 2 0 R >>",
            "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R "
            "/Resources << /Font << /F1 5 0 R >> >> >>",
            f"<< /Length {len(stream)} >>\nstream\n{stream}\nendstream",
            "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"]
    out, offsets = b"%PDF-1.4\n", []
    for i, o in enumerate(objs, 1):
        offsets.append(len(out)); out += f"{i} 0 obj\n{o}\nendobj\n".encode()
    xref = len(out)
    out += f"xref\n0 {len(objs) + 1}\n0000000000 65535 f \n".encode()
    out += "".join(f"{x:010d} 00000 n \n" for x in offsets).encode()
    out += f"trailer\n<< /Size {len(objs) + 1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n".encode()
    path.write_bytes(out)

digital(tmp / f"upgtest-{run}-digital.pdf")

pw = next((l.strip() for l in open("/usr/src/paperless/scripts/passwords.txt") if l.strip()), None)
if pw:
    with pikepdf.open(tmp / f"upgtest-{run}-scan.pdf") as pdf:
        pdf.save(tmp / f"upgtest-{run}-locked.pdf",
                 encryption=pikepdf.Encryption(owner=pw, user=pw, R=6))
else:
    print("no password in passwords.txt; skipping locked PDF", file=sys.stderr)

ct = ('<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>')
rels = ('<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>')
doc = ('<?xml version="1.0" encoding="UTF-8"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
       f'<w:body><w:p><w:r><w:t>Paperless upgrade office test {run}</w:t></w:r></w:p></w:body></w:document>')
with zipfile.ZipFile(tmp / f"upgtest-{run}-office.docx", "w") as z:
    z.writestr("[Content_Types].xml", ct); z.writestr("_rels/.rels", rels); z.writestr("word/document.xml", doc)

for f in sorted(tmp.iterdir()):
    shutil.copy(f, consume / f.name)
    print(f.name)
PY
  then
    fail "could not generate/copy test documents"; return
  fi
  local expect=(scan digital office)
  ls "$CONSUME_DIR"/upgtest-"$run"-locked.pdf >/dev/null 2>&1 && expect+=(locked)
  pass "dropped ${#expect[@]} files into $CONSUME_DIR"

  section "Waiting for consumption (up to 10 min)"
  local deadline=$((SECONDS + 600)) n=0
  while [ $SECONDS -lt $deadline ]; do
    n=$(psql_q "select count(*) from documents_document where original_filename like 'upgtest-$run-%'")
    [ "$n" -ge "${#expect[@]}" ] && break
    sleep 10
  done
  [ "$n" -ge "${#expect[@]}" ] && pass "all ${#expect[@]} documents consumed" \
    || fail "only $n/${#expect[@]} consumed; recent log lines:"
  [ "$n" -lt "${#expect[@]}" ] && dc logs --no-color --since 15m webserver 2>&1 | grep -i -E "$run|error" | tail -15 | sed 's/^/      /'

  section "Content checks"
  local kind row
  for kind in "${expect[@]}"; do
    local ext=pdf; [ "$kind" = office ] && ext=docx
    row=$(psql_q "select id, (regexp_replace(content, '\s', '', 'g') ilike '%$run%')::int, (archive_filename is not null)::int
                  from documents_document where original_filename = 'upgtest-$run-$kind.$ext'")
    if [ -z "$row" ]; then fail "$kind: not in database"; continue; fi
    IFS='|' read -r id has_text has_archive <<<"$row"
    case "$kind" in
      scan)   [ "$has_text" = 1 ] && pass "scan #$id: OCR found the reference" || fail "scan #$id: OCR text missing ($run)" ;;
      locked) [ "$has_text" = 1 ] && pass "locked #$id: pre-consume script decrypted it, OCR ok" \
                || fail "locked #$id: no text -> removepassword.py did not run/work (check DOCUMENT_WORKING_PATH)" ;;
      office) [ "$has_text" = 1 ] && pass "office #$id: Tika extracted text" || fail "office #$id: Tika text missing" ;;
      digital) [ "$has_text" = 1 ] && pass "digital #$id: embedded text extracted" || fail "digital #$id: text missing" ;;
    esac
    if [ "$kind" = digital ] && [ "$(major "$(image_version)")" -ge 3 ]; then
      # v3 with PAPERLESS_ARCHIVE_FILE_GENERATION=auto: born-digital PDFs get no archive copy
      [ "$has_archive" = 0 ] && pass "digital #$id: no archive copy (ARCHIVE_FILE_GENERATION=auto)" \
        || fail "digital #$id: archive created; is PAPERLESS_ARCHIVE_FILE_GENERATION=auto?"
    else
      [ "$has_archive" = 1 ] && pass "$kind #$id: archive PDF created" \
        || fail "$kind #$id: no archive PDF (check PAPERLESS_ARCHIVE_FILE_GENERATION / Gotenberg)"
    fi
  done
  ls "$CONSUME_DIR"/upgtest-"$run"-* >/dev/null 2>&1 && fail "test files left in consume dir" \
    || pass "consume dir cleaned up after consumption"
  echo "    manual: you should have received ${#expect[@]} ntfy notifications (post-consume script)"

  section "Duplicate rejection (PAPERLESS_CONSUMER_DELETE_DUPLICATES)"
  web_user sh -c "cp /tmp/upgtest/upgtest-$run-scan.pdf /usr/src/paperless/consume/upgtest-$run-dup.pdf"
  sleep 90
  local dup
  dup=$(psql_q "select count(*) from documents_document where original_filename = 'upgtest-$run-dup.pdf'")
  if [ "$dup" = "0" ]; then pass "duplicate was not imported"
  else warn "duplicate was imported (v3 default; set PAPERLESS_CONSUMER_DELETE_DUPLICATES=true to reject)"; fi
  rm -f "$CONSUME_DIR/upgtest-$run-dup.pdf" 2>/dev/null
  web_user rm -rf /tmp/upgtest

  section "Cleanup"
  local ids
  ids=$(psql_q "select id from documents_document where original_filename like 'upgtest-$run-%'" | tr '\n' ' ')
  if [ "$keep" = "--keep" ]; then
    skip "keeping test documents: $ids"
  elif need_token "deleting test documents $ids (delete them in the UI and empty the trash)"; then
    local id ok=1
    for id in $ids; do
      [ "$(api DELETE "/api/documents/$id/" -o /dev/null -w '%{http_code}')" = "204" ] || ok=0
    done
    local idjson
    idjson=$(echo "$ids" | python3 -I -c 'import sys,json; print(json.dumps([int(x) for x in sys.stdin.read().split()]))')
    api POST /api/trash/ -H 'Content-Type: application/json' \
      -d "{\"action\":\"empty\",\"documents\":$idjson}" -o /dev/null
    [ "$ok" = 1 ] && pass "deleted and purged test documents: $ids" || fail "could not delete some of: $ids"
  fi
}

# ------------------------------------------------------------------- search
stage_search() {
  section "Full-text search"
  need_token "search API" || return
  local samples hits=0 total=0 id title words res
  samples=$(psql_q "select id, title from documents_document
                    where deleted_at is null and length(title) > 12 order by random() limit 5")
  while IFS='|' read -r id title; do
    [ -z "$id" ] && continue
    total=$((total + 1))
    words=$(python3 -I -c 'import re,sys; w=sorted(set(re.findall(r"[^\W\d_]{4,}", sys.argv[1])), key=len, reverse=True)[:2]; print(" ".join(w))' "$title")
    [ -z "$words" ] && { total=$((total - 1)); continue; }
    res=$(api GET "/api/documents/?page_size=100&fields=id&query=$(python3 -I -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))' "$words")")
    if json "sys.exit(0 if $id in [r['id'] for r in d.get('results', [])] else 1)" <<<"$res" 2>/dev/null; then
      hits=$((hits + 1)); echo "    hit  #$id for '$words'"
    else echo "    miss #$id for '$words'"; fi
  done <<<"$samples"
  if [ "$total" -eq 0 ]; then skip "no sample documents"
  elif [ "$hits" -ge $((total - 1)) ]; then pass "search found $hits/$total sample documents"
  elif [ "$hits" -gt 0 ]; then warn "search found only $hits/$total (index still rebuilding?)"
  else fail "search found 0/$total (index empty/broken? try: docker compose exec webserver document_index reindex)"; fi
}

# ----------------------------------------------------------------------- ai
stage_ai() {
  section "AI configuration"
  if [ "$(major "$(image_version)")" -lt 3 ]; then skip "AI features need v3"; summary; exit; fi
  local envs
  envs=$(web env)
  grep -q -i '^PAPERLESS_AI_ENABLED=\(true\|1\|yes\)' <<<"$envs" && pass "PAPERLESS_AI_ENABLED" \
    || warn "PAPERLESS_AI_ENABLED not true in env (OK only if enabled in admin UI instead)"
  grep '^PAPERLESS_AI_LLM_\(BACKEND\|MODEL\|ENDPOINT\|EMBEDDING_BACKEND\|EMBEDDING_MODEL\|OUTPUT_LANGUAGE\)=' <<<"$envs" | sed 's/^/    /'

  section "Backend reachability (from inside the container)"
  # Runs in the container so API keys never appear on the host command line.
  local level msg
  while IFS=$'\t' read -r level msg; do
    case "$level" in
      PASS) pass "$msg" ;; FAIL) fail "$msg" ;; WARN) warn "$msg" ;; SKIP) skip "$msg" ;; *) echo "    $msg" ;;
    esac
  done < <(web python3 - <<'PY'
import os, json, urllib.request
def out(level, msg):
    print(f"{level}\t{msg}")
def check(label, backend, endpoint, key):
    if not backend:
        out("SKIP", f"{label}: no backend set"); return
    if backend == "huggingface":
        out("INFO", f"{label}: huggingface runs in-process (model downloads on first index build)"); return
    if not endpoint and backend == "openai-like":
        endpoint = "https://api.openai.com/v1"
    url = endpoint.rstrip("/") + ("/api/tags" if backend == "ollama" else "/models")
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {key}"} if key else {})
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            body = json.load(r)
            names = [m.get("id") or m.get("name") for m in body.get("models", body.get("data", []))]
            out("PASS", f"{label}: {url} reachable, {len(names)} models")
            return names
    except Exception as e:
        out("FAIL", f"{label}: {url}: {e}")
e = os.environ
names = check("LLM", e.get("PAPERLESS_AI_LLM_BACKEND"), e.get("PAPERLESS_AI_LLM_ENDPOINT"), e.get("PAPERLESS_AI_LLM_API_KEY"))
model = e.get("PAPERLESS_AI_LLM_MODEL")
if names and model:
    ok = any(n == model or n.split(":")[0] == model for n in names if n)
    out("PASS" if ok else "WARN", f"model '{model}' {'is' if ok else 'is not'} listed by the backend")
def openrouter_route(endpoint, key, model, extra):
    # One tiny completion with the same model and routing params paperless sends, then ask
    # OpenRouter which provider served it and what it cost.
    import time
    body = {"model": model, "max_tokens": 5, "messages": [{"role": "user", "content": "Reply with: ok"}]}
    body.update(extra.get("extra_body", {}))
    hdr = {"Authorization": f"Bearer {key}", "Content-Type": "application/json"}
    base = endpoint.rstrip("/")
    try:
        req = urllib.request.Request(base + "/chat/completions", data=json.dumps(body).encode(), headers=hdr)
        with urllib.request.urlopen(req, timeout=60) as r:
            gen_id = json.load(r)["id"]
    except Exception as ex:
        out("FAIL", f"test completion via OpenRouter: {ex}"); return
    for _ in range(10):
        time.sleep(2)
        try:
            req = urllib.request.Request(f"{base}/generation?id={gen_id}", headers=hdr)
            with urllib.request.urlopen(req, timeout=15) as r:
                g = json.load(r)["data"]
            break
        except Exception:
            g = None
    if not g:
        out("WARN", f"generation {gen_id}: stats not available yet; check openrouter.ai/activity"); return
    want = [p.lower() for p in extra.get("extra_body", {}).get("provider", {}).get("order", [])]
    prov = g.get("provider_name") or "?"
    level = "PASS" if not want or prov.lower().replace(" ", "") in want else "WARN"
    out(level, f"route: {g.get('model')} served by {prov} (wanted {want or 'any'}), "
               f"{g.get('tokens_prompt')}+{g.get('tokens_completion')} tokens, ${g.get('total_cost')}")
if names and model and "openrouter.ai" in (e.get("PAPERLESS_AI_LLM_ENDPOINT") or ""):
    try:
        extra = json.loads(e.get("PAPERLESS_AI_LLM_EXTRA_PARAMS") or "{}")
    except ValueError as ex:
        extra = {}; out("FAIL", f"PAPERLESS_AI_LLM_EXTRA_PARAMS is not valid JSON: {ex}")
    if any(k in extra for k in ("provider", "reasoning")):
        out("FAIL", "EXTRA_PARAMS has provider/reasoning at top level; the OpenAI SDK rejects them, wrap them in extra_body")
    openrouter_route(e["PAPERLESS_AI_LLM_ENDPOINT"], e.get("PAPERLESS_AI_LLM_API_KEY"), model, extra)
eb = e.get("PAPERLESS_AI_LLM_EMBEDDING_BACKEND")
check("embeddings", eb, e.get("PAPERLESS_AI_LLM_EMBEDDING_ENDPOINT") or e.get("PAPERLESS_AI_LLM_ENDPOINT"),
      e.get("PAPERLESS_AI_LLM_EMBEDDING_API_KEY") or e.get("PAPERLESS_AI_LLM_API_KEY"))
PY
  )

  need_token "AI API checks" || return
  section "LLM index"
  local st idx
  st=$(api GET /api/status/)
  idx=$(json 'print(d["tasks"].get("llmindex_status"), d["tasks"].get("llmindex_last_modified"), d["tasks"].get("llmindex_error") or "")' <<<"$st" 2>/dev/null)
  case "$idx" in
    OK*) pass "llmindex: $idx" ;;
    DISABLED*) warn "llmindex DISABLED (no embedding backend; chat/RAG unavailable)" ;;
    WARNING*) warn "llmindex: $idx (run: docker compose exec webserver document_llmindex rebuild)" ;;
    *) fail "llmindex: ${idx:-no status}" ;;
  esac

  section "AI suggestions"
  local id res code
  id=$(psql_q "select id from documents_document where deleted_at is null and length(content) > 500
               order by added desc limit 1")
  res=$(api GET "/api/documents/$id/ai_suggestions/" --max-time 300 -w '\n%{http_code}')
  code=$(tail -1 <<<"$res"); res=$(sed '$d' <<<"$res")
  if [ "$code" = "200" ]; then
    pass "ai_suggestions for #$id"
    json 'print("    " + json.dumps(d, ensure_ascii=False)[:400])' <<<"$res" 2>/dev/null
  else fail "ai_suggestions for #$id returned $code: $(head -c 300 <<<"$res")"; fi

  section "Document chat"
  # The route is /api/documents/chat/; /api/chat/ falls through to the SPA (302/403).
  # Chat needs the embedding index, and it reports failures as HTTP 200 with an apology.
  if [[ "$idx" == DISABLED* ]]; then
    skip "chat: needs an embedding backend (phase 5b)"
  else
    res=$(api POST /api/documents/chat/ -H 'Content-Type: application/json' --max-time 300 -w '\n%{http_code}' \
      -d "{\"q\":\"In one sentence, what is this document about?\",\"document_id\":$id}")
    code=$(tail -1 <<<"$res"); res=$(sed '$d' <<<"$res")
    if [ "$code" = "200" ] && [ -n "$res" ] && ! grep -q "something went wrong" <<<"$res"; then
      pass "chat answered: $(head -c 200 <<<"$res" | tr '\n' ' ')"
    else fail "chat returned $code: $(head -c 300 <<<"$res") (see docker compose logs webserver)"; fi
  fi

  section "Memory"
  local p u
  # docker stats divides by the RAM dockerd saw at startup, which goes stale after `pct set
  # --memory`; judge the whole CT instead (the containers have no limits of their own).
  u=$(docker stats --no-stream --format '{{.MemUsage}}' "$(dc ps -q webserver)" | cut -d/ -f1)
  read -r p < <(free -m | awk 'NR==2 {printf "%d %d/%d MiB\n", $3*100/$2, $3, $2}')
  [ "${p%% *}" -lt 85 ] && pass "CT memory ${p#* } used (${p%% *}%), webserver $u" \
    || fail "CT memory ${p#* } used (${p%% *}%), webserver $u; raise CT RAM"
}

# ------------------------------------------------------------------ patches
# Local source patches (patches/*.py with a "# TARGET:" header) are bind-mounted read-only
# over the image's files. Each records the sha256 of the upstream file it was based on, so
# an image whose file changed fails here instead of silently running a stale copy.
stage_patches() {
  local image="${1:-$(dc config --format json 2>/dev/null | json 'print(d["services"]["webserver"]["image"])')}"
  local running p target want have live mine t out
  running=$(docker inspect "$(dc ps -q webserver)" --format '{{.Config.Image}}' 2>/dev/null)
  section "Local patches (image $image)"
  for p in "$DIR"/patches/*.py; do
    target=$(sed -n 's/^# TARGET: //p' "$p")
    [ -z "$target" ] && continue
    want=$(sed -n 's/.*upstream sha256 \([0-9a-f]\{64\}\).*/\1/p' "$p" | head -1)
    have=$(docker run --rm --entrypoint sha256sum "$image" "$target" 2>/dev/null | cut -d' ' -f1)
    if [ -z "$have" ]; then fail "$(basename "$p"): $target not found in $image"
    elif [ "$have" = "$want" ]; then pass "$(basename "$p"): upstream $target unchanged"
    else fail "$(basename "$p"): upstream $target CHANGED in $image; rebase the patch on the new" \
      "file (diff against patches/$(basename "$p").orig) or remove its mount from docker-compose.yaml"
    fi
    [ "$image" = "$running" ] || continue
    live=$(web sha256sum "$target" 2>/dev/null | cut -d' ' -f1)
    mine=$(sha256sum "$p" | cut -d' ' -f1)
    [ "$live" = "$mine" ] && pass "$(basename "$p"): active in the running webserver" \
      || fail "$(basename "$p"): NOT active in the running webserver (mount missing?)"
    t="$DIR/patches/test_$(basename "$p" .py)_patch.py"
    if [ -f "$t" ]; then
      out=$(web_user python3 manage.py shell -c \
        "exec(open('/usr/src/paperless/patches/$(basename "$t")').read())" 2>&1)
      grep -q '^ALL PASS' <<<"$out" && pass "$(basename "$t"): $(grep -c '  PASS' <<<"$out") checks pass" \
        || { fail "$(basename "$t"):"; grep -E 'FAIL|Error' <<<"$out" | head -10 | sed 's/^/      /'; }
    fi
  done
}

case "${1:-}" in
  preflight) stage_preflight ;;
  backup) stage_backup ;;
  baseline) stage_baseline ;;
  verify) shift; stage_verify "$@" ;;
  consume) shift; stage_consume "$@" ;;
  search) stage_search ;;
  ai) stage_ai ;;
  patches) shift; stage_patches "$@" ;;
  *) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
summary
