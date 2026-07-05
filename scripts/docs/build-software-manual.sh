#!/usr/bin/env bash
# Build B1GMB42-software-manual.pdf from docs/software-manual/ chapters.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANUAL_DIR="${ROOT}/docs/software-manual"
OUT_PDF="${ROOT}/B1GMB42-software-manual.pdf"
OUT_MD="${ROOT}/B1GMB42-software-manual.md"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

command -v pandoc >/dev/null || { echo "pandoc not found — install via apt (rebuild Phase 2)" >&2; exit 1; }
command -v xelatex >/dev/null || { echo "xelatex not found — install texlive-xetex" >&2; exit 1; }

mapfile -t CHAPTERS < <(find "$MANUAL_DIR" -maxdepth 1 -type f \( -name '0*.md' -o -name '1*.md' -o -name 'appendix-*.md' \) | sort)

if [[ ${#CHAPTERS[@]} -eq 0 ]]; then
  echo "No chapter files in $MANUAL_DIR" >&2
  exit 1
fi

log "Merging ${#CHAPTERS[@]} chapters to $OUT_MD"
pandoc "${CHAPTERS[@]}" -o "$OUT_MD" \
  --from markdown \
  --to markdown \
  --wrap=none

log "Building PDF: $OUT_PDF"
pandoc "${CHAPTERS[@]}" -o "$OUT_PDF" \
  --pdf-engine=xelatex \
  -V mainfont="Noto Sans" \
  -V monofont="DejaVu Sans Mono" \
  2>&1 | grep -v 'Missing character' || true

log "Done."
log "  PDF: $OUT_PDF"
log "  MD:  $OUT_MD ($(wc -l < "$OUT_MD") lines)"