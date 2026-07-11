#!/usr/bin/env bash
# Mirror selected Google Drive folders into ~/Documents/LibraryRadio.
#
# Only folders listed in the allowlist config are touched (never whole Drive).
# Default: rclone copy (add/update). Use --prune for rclone sync (delete local orphans).
#
# Requires: rclone with a Google Drive remote (default name: gdrive).
#   rclone config   # create remote type=drive, scope=drive or drive.readonly
#
# Config (private, local only — never git):
#   ~/Documents/LibraryRadio/folders.tsv
#   format: local_name <TAB> folder_id
# Generate with: bin/discover-library-radio-folders
# Names allowlist in repo: library-radio-folder-names.txt (no IDs)
#
# Usage:
#   bin/discover-library-radio-folders   # recreate folders.tsv + ham-radio-id-map.tsv
#   bin/sync-library-radio
#   bin/sync-library-radio --dry-run
#   bin/sync-library-radio --prune
#   bin/sync-library-radio --folder Radio
#   bin/sync-library-radio --list
#
set -euo pipefail

DEST="${LIBRARY_RADIO_DEST:-$HOME/Documents/LibraryRadio}"
REMOTE="${RCLONE_GDRIVE_REMOTE:-gdrive}"
CONFIG="${LIBRARY_RADIO_FOLDERS:-$DEST/folders.tsv}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DRY_RUN=0
PRUNE=0
LIST_ONLY=0
ONLY_FOLDER=""
VERBOSE=0

log()  { printf '%s\n' "$*"; }
vlog() { [[ "$VERBOSE" -eq 1 ]] && printf '%s\n' "$*" || true; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: sync-library-radio.sh [options]

Mirror allowlisted Google Drive folders → ~/Documents/LibraryRadio/<name>/

Options:
  --dry-run         Pass -n to rclone (no changes)
  --prune           Use rclone sync (delete local files gone from Drive)
  --folder NAME     Sync only this local_name from the allowlist
  --list            Print allowlist and exit
  --dest DIR        Local root (default: ~/Documents/LibraryRadio)
  --remote NAME     rclone remote (default: gdrive)
  --config PATH     folders.tsv path
  -v, --verbose     Extra logging
  -h, --help        This help

Environment:
  LIBRARY_RADIO_DEST, LIBRARY_RADIO_FOLDERS, RCLONE_GDRIVE_REMOTE
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --prune) PRUNE=1; shift ;;
    --folder)
      [[ $# -ge 2 ]] || die "--folder requires a name"
      ONLY_FOLDER=$2
      shift 2
      ;;
    --list) LIST_ONLY=1; shift ;;
    --dest)
      [[ $# -ge 2 ]] || die "--dest requires a path"
      DEST=$2
      shift 2
      ;;
    --remote)
      [[ $# -ge 2 ]] || die "--remote requires a name"
      REMOTE=$2
      shift 2
      ;;
    --config)
      [[ $# -ge 2 ]] || die "--config requires a path"
      CONFIG=$2
      shift 2
      ;;
    -v|--verbose) VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
done

command -v rclone >/dev/null 2>&1 || die "rclone not found — install: sudo apt-get install -y rclone"

if [[ ! -f "$CONFIG" ]]; then
  die "no allowlist at $CONFIG
Generate private maps (not in git):
  bin/discover-library-radio-folders
That writes folders.tsv and ham-radio-id-map.tsv under $DEST"
fi

# stdout lines: name|id|resource_key
load_rows() {
  local line name id rkey
  while IFS= read -r line || [[ -n "$line" ]]; do
    line=${line//$'\r'/}
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    name=$(printf '%s\n' "$line" | awk -F'\t' '{print $1}')
    id=$(printf '%s\n' "$line" | awk -F'\t' '{print $2}')
    rkey=$(printf '%s\n' "$line" | awk -F'\t' '{print $3}')
    [[ -n "$name" && -n "$id" ]] || continue
    if [[ -n "$ONLY_FOLDER" && "$name" != "$ONLY_FOLDER" ]]; then
      continue
    fi
    printf '%s|%s|%s\n' "$name" "$id" "$rkey"
  done <"$CONFIG"
}

mapfile -t ROWS < <(load_rows)
[[ ${#ROWS[@]} -gt 0 ]] || die "no folders to sync (check allowlist / --folder)"

if [[ "$LIST_ONLY" -eq 1 ]]; then
  log "config: $CONFIG"
  log "dest:   $DEST"
  log "remote: ${REMOTE}:"
  log "Drive parent: Library / Ham_Radio"
  printf '%s\t%s\t%s\n' "local_name" "folder_id" "resource_key"
  for row in "${ROWS[@]}"; do
    IFS='|' read -r name id rkey <<<"$row"
    printf '%s\t%s\t%s\n' "$name" "$id" "${rkey:-}"
  done
  exit 0
fi

if ! rclone listremotes 2>/dev/null | grep -qx "${REMOTE}:"; then
  die "rclone remote '${REMOTE}:' not configured.

Run once:
  rclone config
  # n) New remote  name=${REMOTE}  type=drive
  # scope: 1 (Full) or 2 (Read-only)
  # complete browser OAuth, then re-run this script."
fi

mkdir -p "$DEST"

RCLONE_BASE=(rclone)
[[ "$DRY_RUN" -eq 1 ]] && RCLONE_BASE+=(--dry-run)
if [[ "$VERBOSE" -eq 1 ]]; then
  RCLONE_BASE+=(-v)
else
  RCLONE_BASE+=(--stats=30s --stats-one-line)
fi

RCLONE_FLAGS=(
  --create-empty-src-dirs
  --drive-export-formats "docx,xlsx,pptx,pdf,svg"
  --fast-list
  --transfers 4
  --checkers 8
)

CMD=copy
[[ "$PRUNE" -eq 1 ]] && CMD=sync

log "sync-library-radio: dest=$DEST remote=${REMOTE}: mode=$CMD dry_run=$DRY_RUN"
log "allowlist: $CONFIG (${#ROWS[@]} folder(s))"

errors=0
for row in "${ROWS[@]}"; do
  IFS='|' read -r name id rkey <<<"$row"
  target="${DEST}/${name}"
  mkdir -p "$target"

  # --drive-root-folder-id limits the remote root to this folder only
  log "--- $name  id=$id → $target"
  [[ -n "${rkey:-}" ]] && vlog "    resource_key=$rkey (usually unused for owned folders)"

  if ! "${RCLONE_BASE[@]}" "$CMD" "${REMOTE}:" "$target" \
      --drive-root-folder-id "$id" \
      "${RCLONE_FLAGS[@]}"; then
    printf 'warning: rclone failed for %s\n' "$name" >&2
    errors=$((errors + 1))
  fi
done

if [[ "$errors" -gt 0 ]]; then
  die "finished with $errors folder error(s)"
fi
log "done."
exit 0
