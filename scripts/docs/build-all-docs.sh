#!/usr/bin/env bash
# Build all IndianaDell documentation PDFs and merged markdown.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PDF_ARGS=(
    --pdf-engine=xelatex
    -V mainfont="Noto Sans"
    -V monofont="DejaVu Sans Mono"
)

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

command -v pandoc >/dev/null || { echo "pandoc not found — install via apt" >&2; exit 1; }
command -v xelatex >/dev/null || { echo "xelatex not found — install texlive-xetex" >&2; exit 1; }

log "Building software manual (PDF + merged MD)"
"$ROOT/scripts/docs/build-software-manual.sh"

cd "$ROOT"

log "Building B1GMB42-slot-port-inventory.pdf"
pandoc B1GMB42-slot-port-inventory.md -o B1GMB42-slot-port-inventory.pdf \
    "${PDF_ARGS[@]}" 2>&1 | grep -v 'Missing character' || true

log "Building B1GMB42-software-inventory.pdf"
pandoc B1GMB42-software-inventory.md -o B1GMB42-software-inventory.pdf \
    "${PDF_ARGS[@]}" 2>&1 | grep -v 'Missing character' || true

log "Building B1GMB42-zfs-recovery.pdf"
"$ROOT/scripts/docs/build-zfs-recovery-doc.sh"

log "Done. PDF outputs:"
ls -lh B1GMB42-software-manual.pdf B1GMB42-slot-port-inventory.pdf \
    B1GMB42-software-inventory.pdf B1GMB42-zfs-recovery.pdf