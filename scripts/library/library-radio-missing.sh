#!/usr/bin/env bash
# Durable missing-file ledger for LibraryRadio (local only).
#
# File: ~/Documents/LibraryRadio/missing.tsv
# Columns (tab-separated):
#   ts_first  ts_last  status  folder  rel_path  sha256  source  notes
#
# status values:
#   missing | quarantined | scanned_clean | scanned_dirty | promoted | replaced_holding | wontfix
#
# Usage:
#   bin/library-radio-missing seed-from-log [/tmp/sync-library-radio.log]
#   bin/library-radio-missing list
#   bin/library-radio-missing list missing
#   bin/library-radio-missing set-status <folder> <rel_path> <status> [notes]
#   bin/library-radio-missing sync-quarantine   # mark files present in quarantine/
#   bin/library-radio-missing report
#
set -euo pipefail

DEST="${LIBRARY_RADIO_DEST:-$HOME/Documents/LibraryRadio}"
LEDGER="${DEST}/missing.tsv"
QUAR="${DEST}/quarantine"
HOLD="${DEST}/holding"

log() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

ensure_ledger() {
  mkdir -p "$DEST"
  if [[ ! -f "$LEDGER" ]]; then
    cat >"$LEDGER" <<'EOF'
# LibraryRadio durable missing / recovery ledger (PRIVATE — do not commit)
# ts_first	ts_last	status	folder	rel_path	sha256	source	notes
EOF
    chmod 600 "$LEDGER" 2>/dev/null || true
  fi
}

now() { date -Iseconds; }

# Upsert by folder+rel_path
upsert() {
  local status=$1 folder=$2 rel=$3 source=${4:-} notes=${5:-} sha=${6:-}
  local ts
  ts=$(now)
  ensure_ledger
  python3 - "$LEDGER" "$ts" "$status" "$folder" "$rel" "$source" "$notes" "$sha" <<'PY'
import sys
from pathlib import Path
path, ts, status, folder, rel, source, notes, sha = sys.argv[1:9]
lines = Path(path).read_text(encoding="utf-8", errors="replace").splitlines()
header = []
rows = []
for line in lines:
    if not line.strip() or line.startswith("#") or line.startswith("ts_first"):
        header.append(line)
        continue
    parts = line.split("\t")
    while len(parts) < 8:
        parts.append("")
    rows.append(parts)

key = (folder, rel)
found = False
out_rows = []
for p in rows:
    if (p[3], p[4]) == key:
        p[1] = ts  # ts_last
        p[2] = status
        if source:
            p[6] = source
        if notes:
            p[7] = notes
        if sha:
            p[5] = sha
        found = True
    out_rows.append(p)
if not found:
    out_rows.append([ts, ts, status, folder, rel, sha, source, notes])

# keep comments/header
out = []
if not any(l.startswith("ts_first") for l in header):
    out.append("# LibraryRadio durable missing / recovery ledger (PRIVATE — do not commit)")
    out.append("ts_first\tts_last\tstatus\tfolder\trel_path\tsha256\tsource\tnotes")
else:
    out = header
# ensure column header present once
if not any(l.startswith("ts_first\t") for l in out):
    out.append("ts_first\tts_last\tstatus\tfolder\trel_path\tsha256\tsource\tnotes")

body = ["\t".join(p) for p in sorted(out_rows, key=lambda r: (r[3], r[4]))]
Path(path).write_text("\n".join(out + body) + "\n", encoding="utf-8")
PY
}

cmd=${1:-list}
shift || true

case "$cmd" in
  seed-from-log)
    logf=${1:-/tmp/sync-library-radio.log}
    [[ -f "$logf" ]] || die "log not found: $logf"
    ensure_ledger
    # Parse abuse errors; assign folder heuristically then refine
    while IFS= read -r rel; do
      [[ -z "$rel" ]] && continue
      folder=mirrors
      case "$rel" in
        mirrors/*) folder=Scanner ;;
        keys-*) folder=Software ;;
        ham.kiev.ua/*|krasnodar.*|www.*|members.*|web.archive.org/*|gbppr.*|freeradio.*)
          folder=mirrors ;;
      esac
      upsert missing "$folder" "$rel" "sync-log:cannotDownloadAbusiveFile" "Google Drive abuse 403"
    done < <(grep cannotDownloadAbusiveFile "$logf" | sed -n 's/^.*ERROR : \([^:]*\): Failed.*$/\1/p' | sort -u)
    # Quota note as meta row optional skip
    log "seeded from $logf -> $LEDGER"
    ;;
  set-status)
    [[ $# -ge 3 ]] || die "usage: set-status <folder> <rel_path> <status> [notes]"
    upsert "$3" "$1" "$2" "manual" "${4:-}"
    log "set $1 / $2 -> $3"
    ;;
  sync-quarantine)
    ensure_ledger
    # For each file under quarantine/<folder>/rel mark quarantined + hash
    while IFS= read -r -d '' f; do
      rel=${f#"$QUAR/"}
      folder=${rel%%/*}
      rest=${rel#*/}
      [[ "$folder" == "$rest" ]] && continue  # not under folder/
      case "$rest" in
        MANIFEST*|*.tsv|*.log|SCAN*) continue ;;
      esac
      sha=$(sha256sum "$f" | awk '{print $1}')
      upsert quarantined "$folder" "$rest" "quarantine-scan" "present in quarantine" "$sha"
    done < <(find "$QUAR" -type f -print0 2>/dev/null)
    log "synced quarantine presence into $LEDGER"
    ;;
  list)
    ensure_ledger
    filt=${1:-}
    if [[ -n "$filt" ]]; then
      awk -F'\t' -v s="$filt" 'NR==1 || /^#/{next} $3==s{print}' "$LEDGER"
    else
      grep -v '^#' "$LEDGER" | grep -v '^$'
    fi
    ;;
  report)
    ensure_ledger
    python3 - "$LEDGER" <<'PY'
import sys
from collections import Counter
from pathlib import Path
rows=[]
for line in Path(sys.argv[1]).read_text().splitlines():
    if not line.strip() or line.startswith("#") or line.startswith("ts_first"):
        continue
    p=line.split("\t")
    while len(p)<8: p.append("")
    rows.append(p)
c=Counter(r[2] for r in rows)
print("LibraryRadio missing ledger report")
print(f"  file: {sys.argv[1]}")
print(f"  rows: {len(rows)}")
for k,v in sorted(c.items()):
    print(f"  {k}: {v}")
print("\nStill missing / needs attention:")
for r in rows:
    if r[2] in ("missing","scanned_dirty"):
        print(f"  [{r[2]}] {r[3]}/{r[4]}  notes={r[7]}")
if not any(r[2] in ("missing","scanned_dirty") for r in rows):
    print("  (none)")
PY
    ;;
  -h|--help|help)
    sed -n '1,25p' "$0"
    ;;
  *)
    die "unknown command: $cmd (try: seed-from-log|list|report|set-status|sync-quarantine)"
    ;;
esac
