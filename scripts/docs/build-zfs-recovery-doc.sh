#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$ROOT/docs/B1GMB42-zfs-recovery.md"
OUT="$ROOT/B1GMB42-zfs-recovery.pdf"

command -v pandoc >/dev/null || { echo "pandoc not found" >&2; exit 1; }
command -v xelatex >/dev/null || { echo "xelatex not found" >&2; exit 1; }

pandoc "$SRC" -o "$OUT" \
    --pdf-engine=xelatex \
    -V mainfont="Noto Sans" \
    -V monofont="DejaVu Sans Mono" \
    2>&1 | grep -v 'Missing character' || true

printf 'Built %s\n' "$OUT"