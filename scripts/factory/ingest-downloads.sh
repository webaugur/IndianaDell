#!/usr/bin/env bash
# Ingest intact files from ~/Downloads into FactoryDocs (then sort/dedupe).
#
# - Skips incomplete browser leftovers (*.crdownload, *.part, …)
# - Keeps only PE/ZIP/GZ with valid magic headers
# - For name collisions (… (1).exe), keeps the largest intact copy
# - Copies into FactoryDocs/_incoming then runs _sort_factory_docs.py
# - Large installers stay gitignored; regenerates LOCAL inventory
#
# Usage:
#   bin/ingest-downloads
#   bin/ingest-downloads --from ~/Downloads --dry-run
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="${DOWNLOADS_DIR:-$HOME/Downloads}"
INCOMING="$ROOT/FactoryDocs/_incoming"
SORT_PY="$ROOT/FactoryDocs/_sort_factory_docs.py"
DRY=0

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from) SRC="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "Unknown: $1" >&2; exit 2 ;;
  esac
done

[[ -d "$SRC" ]] || { echo "Not a directory: $SRC" >&2; exit 1; }
[[ -f "$SORT_PY" ]] || { echo "Missing $SORT_PY" >&2; exit 1; }

python3 - "$SRC" "$INCOMING" "$DRY" <<'PY'
import re
import shutil
import struct
import sys
import zipfile
from pathlib import Path

src_dir = Path(sys.argv[1])
incoming = Path(sys.argv[2])
dry = sys.argv[3] == "1"

SKIP_SUFFIX = (
    ".crdownload", ".part", ".tmp", ".download", ".partial",
    ".aria2", ".!ut", ".opdownload",
)
SKIP_PREFIX = ("Unconfirmed", ".")


def clean_name(name: str) -> str:
    name = re.sub(r" \(\d+\)(?=\.[^.]+$)", "", name)
    name = re.sub(r"\.zip\.zip$", ".zip", name, flags=re.IGNORECASE)
    return name


def is_intact(path: Path) -> tuple[bool, str]:
    if path.stat().st_size < 1024:
        return False, "too-small"
    if any(path.name.endswith(s) for s in SKIP_SUFFIX):
        return False, "incomplete-suffix"
    if any(path.name.startswith(p) for p in SKIP_PREFIX):
        return False, "skip-name"
    with path.open("rb") as fh:
        head = fh.read(8)
    if head[:2] == b"MZ":
        return True, "PE"
    if head[:4] == b"PK\x03\x04":
        try:
            with zipfile.ZipFile(path) as zf:
                bad = zf.testzip()
                if bad is not None:
                    return False, f"zip-bad:{bad}"
        except zipfile.BadZipFile:
            return False, "zip-corrupt"
        return True, "ZIP"
    if head[:2] == b"\x1f\x8b":
        return True, "GZ"
    if head[:4] == b"%PDF":
        return True, "PDF"
    # Reject HTML error pages saved as .exe
    if head[:1] == b"<" or head[:15].lower().startswith(b"<!doctype"):
        return False, "html"
    return False, f"unknown-magic:{head[:4]!r}"


# Group by cleaned basename; keep largest intact
candidates: dict[str, Path] = {}
skipped = []
for p in sorted(src_dir.iterdir()):
    if not p.is_file():
        continue
    ok, reason = is_intact(p)
    if not ok:
        skipped.append((p.name, reason))
        continue
    key = clean_name(p.name).lower()
    prev = candidates.get(key)
    psz = p.stat().st_size
    # Prefer larger; on equal size prefer name without " (n)" suffix
    def better(new: Path, old: Path) -> bool:
        nsz, osz = new.stat().st_size, old.stat().st_size
        if nsz != osz:
            return nsz > osz
        new_dup = bool(re.search(r" \(\d+\)\.", new.name))
        old_dup = bool(re.search(r" \(\d+\)\.", old.name))
        return old_dup and not new_dup

    if prev is None or better(p, prev):
        if prev is not None:
            skipped.append((prev.name, f"not-preferred-vs:{p.name}"))
        candidates[key] = p
    else:
        skipped.append((p.name, f"not-preferred-vs:{prev.name}"))

print(f"Intact unique: {len(candidates)}")
print(f"Skipped: {len(skipped)}")
for name, why in skipped[:15]:
    print(f"  skip {name[:60]}  ({why})")
if len(skipped) > 15:
    print(f"  … +{len(skipped)-15} more skips")

if dry:
    for p in sorted(candidates.values(), key=lambda x: x.name.lower()):
        print(f"  would-copy {p.name}  ({p.stat().st_size//1024//1024} MiB)")
    raise SystemExit(0)

incoming.mkdir(parents=True, exist_ok=True)
copied = 0
for p in candidates.values():
    dest = incoming / clean_name(p.name)
    # Prefer larger if already in incoming
    if dest.exists() and dest.stat().st_size >= p.stat().st_size:
        print(f"  keep-existing {dest.name}")
        continue
    shutil.copy2(p, dest)
    print(f"  copy {p.name} -> _incoming/{dest.name}")
    copied += 1
print(f"Copied into _incoming: {copied}")
PY

if [[ "$DRY" -eq 1 ]]; then
  exit 0
fi

log "Sorting FactoryDocs…"
python3 "$SORT_PY"

# Refresh local inventory (tracked text) of what is on disk
INV="$ROOT/FactoryDocs/LOCAL-INVENTORY.txt"
{
  echo "# FactoryDocs local inventory (installers gitignored; this list is tracked)"
  echo "# Generated: $(date -Iseconds)"
  echo
  find "$ROOT/FactoryDocs" -type f \
    ! -path '*/WinPEDriverPack/*' \
    ! -path '*/_cache/*' \
    ! -path '*/_extracted/*' \
    ! -name '_sort_factory_docs.py' \
    ! -name '*.part' \
    | sed "s|^$ROOT/FactoryDocs/||" \
    | sort
} > "$INV"
log "Wrote $INV ($(wc -l < "$INV") lines)"
log "Done. Large EXEs remain gitignored; commit inventory/scripts only if desired."
