#!/usr/bin/env bash
# Local analysis of quarantine/ files (no execution of payloads).
# Writes: quarantine/scan-report.tsv and updates missing.tsv statuses.
#
# Usage: bin/library-radio-scan-quarantine
#
set -euo pipefail

DEST="${LIBRARY_RADIO_DEST:-$HOME/Documents/LibraryRadio}"
QUAR="${DEST}/quarantine"
REPORT="${QUAR}/scan-report.tsv"
ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
MISSING_TOOL="$ROOT/scripts/library/library-radio-missing.sh"

log() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[[ -d "$QUAR" ]] || die "no quarantine dir: $QUAR"
mkdir -p "$QUAR"

# Optional ClamAV
HAVE_CLAM=0
if command -v clamscan >/dev/null 2>&1; then
  HAVE_CLAM=1
else
  log "note: clamscan not installed (optional: sudo apt-get install -y clamav clamav-freshclam && sudo freshclam)"
fi

{
  echo -e "path\tfolder\trel\tsize\tsha256\tfile_type\tclam\tgoogle_why_guess\tnotes"
} >"$REPORT"

while IFS= read -r -d '' f; do
  rel_full=${f#"$QUAR/"}
  folder=${rel_full%%/*}
  rest=${rel_full#*/}
  [[ "$folder" == "$rest" ]] && continue
  case "$rest" in
    MANIFEST*|*.tsv|*.log|SCAN*|scan-report*) continue ;;
  esac

  sz=$(stat -c%s "$f")
  sha=$(sha256sum "$f" | awk '{print $1}')
  ftype=$(file -b "$f" | tr '\t' ' ')

  clam="skipped"
  if [[ "$HAVE_CLAM" -eq 1 ]]; then
    if out=$(clamscan --no-summary --infected "$f" 2>/dev/null); then
      clam="OK"
    else
      clam="HIT:${out//$'\n'/ }"
    fi
  fi

  # Heuristic: why Google might have flagged
  guess="unknown_fp"
  notes=""
  case "$ftype" in
    *PE32*|*PE32+*|*MS-DOS*)
      guess="likely_fp_old_pe_or_installer"
      notes="old Windows PE/EXE; Drive often flags unknown packers/installers"
      ;;
    *Zip*|*ZIP*)
      guess="likely_fp_zip_archive"
      notes="zip container; reputation may follow inner PE or filename"
      # list zip names (no extract)
      if command -v unzip >/dev/null; then
        inner=$(unzip -l "$f" 2>/dev/null | tail -n +4 | head -20 | tr '\t' ' ' | tr '\n' ';')
        notes="${notes}; zip_listing=${inner:0:200}"
      fi
      ;;
    *HTML*|*ASCII*|*UTF-8*|*UTF-16*|*text*)
      guess="likely_fp_text_or_html"
      notes="text/html/utf16; not a classic PE virus host unless polyglot"
      ;;
    *)
      guess="needs_review"
      notes="see file_type"
      ;;
  esac

  # Name-based signals Google may use
  base=$(basename "$f")
  case "$base" in
    keys-*|*keygen*|*crack*|*warez*)
      guess="likely_fp_name_heuristic"
      notes="${notes}; filename pattern attracts heuristics"
      ;;
  esac

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$rel_full" "$folder" "$rest" "$sz" "$sha" "$ftype" "$clam" "$guess" "$notes" >>"$REPORT"

  status=scanned_clean
  [[ "$clam" == HIT* ]] && status=scanned_dirty
  bash "$MISSING_TOOL" set-status "$folder" "$rest" "$status" "$guess; $notes" 2>/dev/null || true
  # re-set sha via set-status notes only - also sync hash into ledger
  python3 - "$DEST/missing.tsv" "$folder" "$rest" "$sha" <<'PY' 2>/dev/null || true
import sys
from pathlib import Path
path, folder, rel, sha = sys.argv[1:5]
p=Path(path)
if not p.exists():
    raise SystemExit
lines=p.read_text().splitlines()
out=[]
for line in lines:
    if line.startswith("#") or line.startswith("ts_first") or not line.strip():
        out.append(line); continue
    parts=line.split("\t")
    while len(parts)<8: parts.append("")
    if parts[3]==folder and parts[4]==rel:
        parts[5]=sha
    out.append("\t".join(parts))
p.write_text("\n".join(out)+"\n")
PY

  log "scanned: $folder/$rest -> $clam ($guess)"
done < <(find "$QUAR" -type f -print0)

chmod 600 "$REPORT" 2>/dev/null || true
log "wrote $REPORT"
log "ledger updated: $DEST/missing.tsv"
bash "$MISSING_TOOL" report || true
