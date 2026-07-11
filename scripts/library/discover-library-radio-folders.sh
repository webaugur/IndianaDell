#!/usr/bin/env bash
# Discover Google Drive folder IDs under Library/Ham_Radio and write local maps.
#
# Private data stays on the machine only (never intended for git):
#   ~/Documents/LibraryRadio/ham-radio-id-map.tsv  — all children (name ↔ id)
#   ~/Documents/LibraryRadio/folders.tsv           — allowlist subset for sync
#
# Repo ships names only: scripts/library/library-radio-folder-names.txt
#
# Requires: rclone remote (default gdrive) authorized.
#
# Usage:
#   bin/discover-library-radio-folders
#   bin/discover-library-radio-folders --path Library/Ham_Radio
#   bin/discover-library-radio-folders --dry-run
#
set -euo pipefail

DEST="${LIBRARY_RADIO_DEST:-$HOME/Documents/LibraryRadio}"
REMOTE="${RCLONE_GDRIVE_REMOTE:-gdrive}"
DRIVE_PATH="${LIBRARY_RADIO_DRIVE_PATH:-Library/Ham_Radio}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMES_FILE="${LIBRARY_RADIO_NAMES:-$SCRIPT_DIR/library-radio-folder-names.txt}"

DRY_RUN=0
VERBOSE=0

log()  { printf '%s\n' "$*"; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: discover-library-radio-folders.sh [options]

List Drive folders under Library/Ham_Radio and write local ID maps:

  ham-radio-id-map.tsv  full name↔id map (all children)
  folders.tsv           allowlist names only (input for sync-library-radio)

Options:
  --path PATH     Path from remote root (default: Library/Ham_Radio)
  --dest DIR      Output directory (default: ~/Documents/LibraryRadio)
  --remote NAME   rclone remote (default: gdrive)
  --names FILE    Allowlist of folder names (default: repo library-radio-folder-names.txt)
  --dry-run       Print maps; do not write files
  -v, --verbose
  -h, --help

Environment:
  LIBRARY_RADIO_DEST, LIBRARY_RADIO_DRIVE_PATH, LIBRARY_RADIO_NAMES,
  RCLONE_GDRIVE_REMOTE
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path) [[ $# -ge 2 ]] || die "--path requires a value"; DRIVE_PATH=$2; shift 2 ;;
    --dest) [[ $# -ge 2 ]] || die "--dest requires a value"; DEST=$2; shift 2 ;;
    --remote) [[ $# -ge 2 ]] || die "--remote requires a value"; REMOTE=$2; shift 2 ;;
    --names) [[ $# -ge 2 ]] || die "--names requires a value"; NAMES_FILE=$2; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -v|--verbose) VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

command -v rclone >/dev/null 2>&1 || die "rclone not found"
command -v python3 >/dev/null 2>&1 || die "python3 not found"
if ! rclone listremotes 2>/dev/null | grep -qx "${REMOTE}:"; then
  die "rclone remote '${REMOTE}:' not configured (run: rclone config)"
fi
[[ -f "$NAMES_FILE" ]] || die "names file not found: $NAMES_FILE"

SRC="${REMOTE}:${DRIVE_PATH}"
log "listing ${SRC} ..."
JSON=$(rclone lsjson "$SRC" --dirs-only) \
  || die "rclone lsjson failed for ${SRC}"

FULL_MAP=$(printf '%s' "$JSON" | python3 -c '
import json, sys
data = json.load(sys.stdin)
rows = []
for o in data:
    if not o.get("IsDir", True):
        continue
    name = (o.get("Name") or o.get("Path") or "").rstrip("/").split("/")[-1]
    fid = o.get("ID") or o.get("Id") or ""
    if not name or not fid:
        continue
    if name.startswith("."):
        continue
    rows.append((name, fid))
rows.sort(key=lambda x: x[0].lower())
for name, fid in rows:
    print(f"{name}\t{fid}")
')

[[ -n "$FULL_MAP" ]] || die "no child folders found under ${DRIVE_PATH}"

declare -A WANT=()
while IFS= read -r line || [[ -n "$line" ]]; do
  line=${line//$'\r'/}
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  WANT["$line"]=1
done <"$NAMES_FILE"

ALLOW_MAP=""
found=0
while IFS=$'\t' read -r name fid; do
  [[ -n "${WANT[$name]+x}" ]] || continue
  ALLOW_MAP+="${name}"$'\t'"${fid}"$'\n'
  unset "WANT[$name]"
  found=$((found + 1))
done <<<"$FULL_MAP"

missing=()
for n in "${!WANT[@]}"; do
  missing+=("$n")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  log "warning: allowlist names not under ${DRIVE_PATH}: ${missing[*]}"
fi
[[ "$found" -gt 0 ]] || die "none of the allowlist names matched Drive children"

ts=$(date -Iseconds)
header_full="# name <-> id  Drive path: ${DRIVE_PATH}
# generated ${ts} by discover-library-radio-folders
# PRIVATE — do not commit
name	id
"
header_allow="# sync allowlist (subset of ham-radio-id-map.tsv)
# generated ${ts} by discover-library-radio-folders
# PRIVATE — do not commit
# format: local_name<TAB>folder_id
"

if [[ "$DRY_RUN" -eq 1 ]]; then
  log "=== ham-radio-id-map.tsv (dry-run) ==="
  printf '%s' "$header_full"
  printf '%s\n' "$FULL_MAP"
  log "=== folders.tsv (dry-run) ==="
  printf '%s' "$header_allow"
  printf '%s' "$ALLOW_MAP"
  exit 0
fi

mkdir -p "$DEST"
FULL_OUT="${DEST}/ham-radio-id-map.tsv"
ALLOW_OUT="${DEST}/folders.tsv"
{
  printf '%s' "$header_full"
  printf '%s\n' "$FULL_MAP"
} >"$FULL_OUT"
{
  printf '%s' "$header_allow"
  printf '%s' "$ALLOW_MAP"
} >"$ALLOW_OUT"
chmod 600 "$FULL_OUT" "$ALLOW_OUT" 2>/dev/null || true

n_full=$(printf '%s\n' "$FULL_MAP" | grep -c . || true)
n_allow=$(printf '%s' "$ALLOW_MAP" | grep -c . || true)
log "wrote $FULL_OUT  ($n_full folders, name↔id)"
log "wrote $ALLOW_OUT  ($n_allow allowlisted for sync)"
log "lookups:"
log "  name→id:  awk -F'\\t' -v n=NAME '\$1==n{print \$2}' $FULL_OUT"
log "  id→name:  awk -F'\\t' -v i=ID '\$2==i{print \$1}' $FULL_OUT"
log "next: bin/sync-library-radio"
exit 0
