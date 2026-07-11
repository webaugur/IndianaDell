#!/usr/bin/env bash
# Mirror selected Google Drive folders into ~/Documents/LibraryRadio.
#
# Only folders listed in the allowlist config are touched (never whole Drive).
# Default: rclone copy (add/update). Use --prune for rclone sync (delete local orphans).
#
# Requires: rclone with a Google Drive remote (default name: gdrive).
#   rclone config   # create remote type=drive, scope=drive or drive.readonly
#
# Config (private, local only -- never git):
#   ~/Documents/LibraryRadio/folders.tsv
#   format: local_name <TAB> folder_id
# Generate with: bin/discover-library-radio-folders
# Names allowlist in repo: library-radio-folder-names.txt (no IDs)
#
# Usage:
#   bin/discover-library-radio-folders
#   bin/sync-library-radio
#   bin/sync-library-radio --dry-run
#   bin/sync-library-radio --prune
#   bin/sync-library-radio --folder Radio
#   bin/sync-library-radio --repair-abuse   # pull Google-blocked files into quarantine/
#   bin/sync-library-radio --list
#
set -euo pipefail

DEST="${LIBRARY_RADIO_DEST:-$HOME/Documents/LibraryRadio}"
REMOTE="${RCLONE_GDRIVE_REMOTE:-gdrive}"
CONFIG="${LIBRARY_RADIO_FOLDERS:-$DEST/folders.tsv}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUARANTINE_DIR="${DEST}/quarantine"
HOLDING_DIR="${DEST}/holding"
ERROR_LOG="${DEST}/sync-errors.log"

DRY_RUN=0
PRUNE=0
LIST_ONLY=0
REPAIR_ABUSE=0
ONLY_FOLDER=""
VERBOSE=0
# Tolerate partial failures (abuse 403s) without aborting the whole run
IGNORE_ERRORS=1

log()  { printf '%s\n' "$*"; }
vlog() { [[ "$VERBOSE" -eq 1 ]] && printf '%s\n' "$*" || true; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: sync-library-radio.sh [options]

Mirror allowlisted Google Drive folders -> ~/Documents/LibraryRadio/<name>/

Options:
  --dry-run           Pass -n to rclone (no changes)
  --prune             Use rclone sync (delete local files gone from Drive)
  --folder NAME       Sync only this local_name from the allowlist
  --list              Print allowlist and exit
  --repair-abuse      Download Google "malware/spam" blocked files into quarantine/
                      (uses --drive-acknowledge-abuse; paths from sync-errors.log
                       and/or /tmp/sync-library-radio.log)
  --dest DIR          Local root (default: ~/Documents/LibraryRadio)
  --remote NAME       rclone remote (default: gdrive)
  --config PATH       folders.tsv path
  --strict            Fail the run if any folder has rclone errors
  -v, --verbose       Extra logging
  -h, --help          This help

Environment:
  LIBRARY_RADIO_DEST, LIBRARY_RADIO_FOLDERS, RCLONE_GDRIVE_REMOTE

Holding area (manual drops for later processing):
  ~/Documents/LibraryRadio/holding/README.txt
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --prune) PRUNE=1; shift ;;
    --repair-abuse) REPAIR_ABUSE=1; shift ;;
    --strict) IGNORE_ERRORS=0; shift ;;
    --folder)
      [[ $# -ge 2 ]] || die "--folder requires a name"
      ONLY_FOLDER=$2
      shift 2
      ;;
    --list) LIST_ONLY=1; shift ;;
    --dest)
      [[ $# -ge 2 ]] || die "--dest requires a path"
      DEST=$2
      CONFIG="${LIBRARY_RADIO_FOLDERS:-$DEST/folders.tsv}"
      QUARANTINE_DIR="${DEST}/quarantine"
      HOLDING_DIR="${DEST}/holding"
      ERROR_LOG="${DEST}/sync-errors.log"
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

command -v rclone >/dev/null 2>&1 || die "rclone not found - install: sudo apt-get install -y rclone"

if [[ ! -f "$CONFIG" ]]; then
  die "no allowlist at $CONFIG
Generate private maps (not in git):
  bin/discover-library-radio-folders
That writes folders.tsv and ham-radio-id-map.tsv under $DEST"
fi

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

ensure_holding_readme() {
  mkdir -p "$HOLDING_DIR"
  local readme="$HOLDING_DIR/README.txt"
  [[ -f "$readme" ]] && return 0
  cat >"$readme" <<'EOF'
Holding area for LibraryRadio manual drops
==========================================

Put files or folders here when Drive will not serve them (deleted remote
copy, abuse block you prefer to supply yourself, etc.).

Suggested layout:
  holding/inbox/          drop anything here
  holding/processed/      moved here after import (optional)

When ready, tell the agent to process holding/inbox into the right
LibraryRadio/<folder>/ tree, or run:

  # example: copy a file into mirrors tree
  # mkdir -p ~/Documents/LibraryRadio/mirrors/some/path
  # cp holding/inbox/foo.zip ~/Documents/LibraryRadio/mirrors/some/path/

This directory is machine-local; do not commit it.
EOF
}

# --- repair-abuse: pull blocked files into quarantine ---
repair_abuse() {
  local logs=()
  local f rel folder dest id ok=0 fail=0
  local -A folder_id=()

  for row in "${ROWS[@]}"; do
    IFS='|' read -r name id _ <<<"$row"
    folder_id["$name"]=$id
  done
  # Also load full allowlist for id lookup even if --folder limited rows
  while IFS= read -r line || [[ -n "$line" ]]; do
    line=${line//$'\r'/}
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    name=$(printf '%s\n' "$line" | awk -F'\t' '{print $1}')
    id=$(printf '%s\n' "$line" | awk -F'\t' '{print $2}')
    [[ -n "$name" && -n "$id" ]] && folder_id["$name"]=$id
  done <"$CONFIG"

  [[ -f /tmp/sync-library-radio.log ]] && logs+=(/tmp/sync-library-radio.log)
  [[ -f "$ERROR_LOG" ]] && logs+=("$ERROR_LOG")
  [[ ${#logs[@]} -gt 0 ]] || die "no error logs found (expected /tmp/sync-library-radio.log)"

  mapfile -t ABUSE < <(grep -h cannotDownloadAbusiveFile "${logs[@]}" 2>/dev/null \
    | sed -n 's/^.*ERROR : \([^:]*\): Failed.*$/\1/p' \
    | sort -u)
  [[ ${#ABUSE[@]} -gt 0 ]] || { log "no abuse-blocked paths found in logs"; return 0; }

  log "repair-abuse: ${#ABUSE[@]} path(s) -> $QUARANTINE_DIR"
  mkdir -p "$QUARANTINE_DIR"
  : >"${QUARANTINE_DIR}/MANIFEST.tsv"
  {
    echo "# quarantine manifest $(date -Iseconds)"
    echo "# status size path folder"
  } >>"${QUARANTINE_DIR}/MANIFEST.tsv"

  for rel in "${ABUSE[@]}"; do
    # Guess which top-level allowlist folder owns this relative path.
    # Paths are usually relative to that folder's Drive root.
    folder=""
    if [[ "$rel" == mirrors/* ]]; then
      # Nested under Scanner (or similar) as "mirrors/..."
      folder="Scanner"
    elif [[ "$rel" == keys-* || "$rel" != */* ]]; then
      # top-level file name -> Software common case
      folder="Software"
    else
      # Prefer mirrors for classic web-mirror trees
      case "$rel" in
        ham.kiev.ua/*|krasnodar.*|www.*|members.*|web.archive.org/*|gbppr.*|freeradio.*)
          folder="mirrors" ;;
        *)
          # default: mirrors if path looks nested, else Software
          folder="mirrors" ;;
      esac
    fi

    id="${folder_id[$folder]:-}"
    if [[ -z "$id" ]]; then
      log "warning: no folder id for $folder (skip $rel)"
      fail=$((fail + 1))
      continue
    fi

    dest="${QUARANTINE_DIR}/${folder}/${rel}"
    mkdir -p "$(dirname "$dest")"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log "dry-run: quarantine $folder :: $rel"
      continue
    fi
    if rclone copyto "gdrive:${rel}" "$dest" \
        --drive-root-folder-id "$id" \
        --drive-acknowledge-abuse \
        --retries 2 \
        --low-level-retries 5 2>>"${QUARANTINE_DIR}/rclone-abuse.log"; then
      if [[ -f "$dest" ]]; then
        sz=$(stat -c%s "$dest")
        printf 'ok\t%s\t%s\t%s\n' "$sz" "$folder" "$rel" >>"${QUARANTINE_DIR}/MANIFEST.tsv"
        log "quarantined: $folder/$rel ($sz bytes)"
        ok=$((ok + 1))
      else
        printf 'FAIL\t0\t%s\t%s\n' "$folder" "$rel" >>"${QUARANTINE_DIR}/MANIFEST.tsv"
        fail=$((fail + 1))
      fi
    else
      # Retry: path might already include a top segment wrong for Scanner nested mirrors
      if [[ "$folder" == "Scanner" ]]; then
        # path is mirrors/foo - id is Scanner; rel is correct relative to Scanner
        :
      fi
      # Try under mirrors explicitly if not already
      if [[ "$folder" != "mirrors" && -n "${folder_id[mirrors]:-}" ]]; then
        if rclone copyto "gdrive:${rel}" "$dest" \
            --drive-root-folder-id "${folder_id[mirrors]}" \
            --drive-acknowledge-abuse \
            --retries 1 2>>"${QUARANTINE_DIR}/rclone-abuse.log"; then
          if [[ -f "$dest" ]]; then
            sz=$(stat -c%s "$dest")
            printf 'ok\t%s\tmirrors\t%s\n' "$sz" "$rel" >>"${QUARANTINE_DIR}/MANIFEST.tsv"
            log "quarantined (via mirrors): $rel"
            ok=$((ok + 1))
            continue
          fi
        fi
      fi
      printf 'FAIL\t0\t%s\t%s\n' "$folder" "$rel" >>"${QUARANTINE_DIR}/MANIFEST.tsv"
      log "FAILED quarantine: $rel"
      fail=$((fail + 1))
    fi
    # gentle pace to avoid Drive query quota
    sleep 1
  done

  chmod 600 "${QUARANTINE_DIR}/MANIFEST.tsv" 2>/dev/null || true
  log "repair-abuse done: ok=$ok fail=$fail -> $QUARANTINE_DIR"
  return 0
}

ensure_holding_readme
mkdir -p "$DEST"

if [[ "$REPAIR_ABUSE" -eq 1 ]]; then
  repair_abuse
  exit 0
fi

RCLONE_BASE=(rclone)
[[ "$DRY_RUN" -eq 1 ]] && RCLONE_BASE+=(--dry-run)
if [[ "$VERBOSE" -eq 1 ]]; then
  RCLONE_BASE+=(-v)
else
  RCLONE_BASE+=(--stats=30s --stats-one-line)
fi

# Keep query rate modest to reduce Drive "Queries per minute" 403s
RCLONE_FLAGS=(
  --create-empty-src-dirs
  --drive-export-formats "docx,xlsx,pptx,pdf,svg"
  --fast-list
  --transfers 2
  --checkers 4
  --tpslimit 8
  --retries 5
  --low-level-retries 10
  --retries-sleep 10s
)

CMD=copy
[[ "$PRUNE" -eq 1 ]] && CMD=sync

log "sync-library-radio: dest=$DEST remote=${REMOTE}: mode=$CMD dry_run=$DRY_RUN"
log "allowlist: $CONFIG (${#ROWS[@]} folder(s))"
: >"$ERROR_LOG"

errors=0
for row in "${ROWS[@]}"; do
  IFS='|' read -r name id rkey <<<"$row"
  target="${DEST}/${name}"
  mkdir -p "$target"

  log "--- $name  id=$id -> $target"
  [[ -n "${rkey:-}" ]] && vlog "    resource_key=$rkey"

  set +e
  "${RCLONE_BASE[@]}" "$CMD" "${REMOTE}:" "$target" \
      --drive-root-folder-id "$id" \
      "${RCLONE_FLAGS[@]}" 2>>"$ERROR_LOG"
  rc=$?
  set -e

  if [[ "$rc" -ne 0 ]]; then
    printf 'warning: rclone exit %s for %s (see %s)\n' "$rc" "$name" "$ERROR_LOG" >&2
    errors=$((errors + 1))
  fi
  # cool-down between folders (quota)
  sleep 3
done

# Always attempt to park abuse-blocked files in quarantine after a run
if [[ "$DRY_RUN" -eq 0 ]]; then
  log "pulling any abuse-blocked files into quarantine..."
  repair_abuse || true
fi

if [[ "$errors" -gt 0 ]]; then
  if [[ "$IGNORE_ERRORS" -eq 1 ]]; then
    log "finished with $errors folder warning(s) (ignored; use --strict to fail)"
    log "error detail: $ERROR_LOG"
    log "quarantine: $QUARANTINE_DIR"
    log "holding (manual drops): $HOLDING_DIR"
    exit 0
  fi
  die "finished with $errors folder error(s); see $ERROR_LOG"
fi
log "done."
log "quarantine: $QUARANTINE_DIR"
log "holding (manual drops): $HOLDING_DIR"
exit 0
