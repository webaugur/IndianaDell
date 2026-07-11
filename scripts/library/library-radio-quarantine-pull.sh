#!/usr/bin/env bash
# Pull Google Drive "abuse"-blocked files into local quarantine using
# rclone --drive-acknowledge-abuse. Updates missing.tsv via library-radio-missing.
#
# Usage:
#   bin/library-radio-quarantine-pull
#   bin/library-radio-quarantine-pull --from-log /tmp/sync-library-radio.log
#
set -euo pipefail

DEST="${LIBRARY_RADIO_DEST:-$HOME/Documents/LibraryRadio}"
REMOTE="${RCLONE_GDRIVE_REMOTE:-gdrive}"
CONFIG="${LIBRARY_RADIO_FOLDERS:-$DEST/folders.tsv}"
QUAR="${DEST}/quarantine"
ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
MISSING_TOOL="$ROOT/scripts/library/library-radio-missing.sh"

LOG=${1:-}
[[ "${1:-}" == "--from-log" ]] && LOG=${2:-/tmp/sync-library-radio.log}
LOG=${LOG:-/tmp/sync-library-radio.log}

log() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

command -v rclone >/dev/null || die "rclone required"
[[ -f "$CONFIG" ]] || die "missing $CONFIG (run discover-library-radio-folders)"
[[ -f "$LOG" ]] || die "log not found: $LOG"

declare -A FID
while IFS=$'\t' read -r n i; do
  [[ -z "$n" || "$n" =~ ^# ]] && continue
  FID["$n"]=$i
done < <(awk -F'\t' 'NF>=2 && $1!~/^#/{print $1"\t"$2}' "$CONFIG")

mapfile -t ABUSE < <(grep cannotDownloadAbusiveFile "$LOG" | sed -n 's/^.*ERROR : \([^:]*\): Failed.*$/\1/p' | sort -u)
[[ ${#ABUSE[@]} -gt 0 ]] || { log "no abuse paths in $LOG"; exit 0; }

mkdir -p "$QUAR"
MAN="$QUAR/MANIFEST.tsv"
{
  echo "# quarantine pull $(date -Iseconds)"
  echo -e "status\tsize\tfolder\trel_path"
} >"$MAN"

guess_folder() {
  local rel=$1
  case "$rel" in
    mirrors/*) echo Scanner ;;
    keys-*) echo Software ;;
    ham.kiev.ua/*|krasnodar.*|www.*|members.*|web.archive.org/*|gbppr.*|freeradio.*)
      echo mirrors ;;
    *) echo mirrors ;;
  esac
}

ok=0 fail=0
for rel in "${ABUSE[@]}"; do
  folder=$(guess_folder "$rel")
  id=${FID[$folder]:-}
  dest="$QUAR/$folder/$rel"
  mkdir -p "$(dirname "$dest")"

  if [[ -f "$dest" ]]; then
    sz=$(stat -c%s "$dest")
    printf 'ok\t%s\t%s\t%s\n' "$sz" "$folder" "$rel" >>"$MAN"
    log "already: $folder/$rel"
    ok=$((ok + 1))
    bash "$MISSING_TOOL" set-status "$folder" "$rel" quarantined "already on disk" 2>/dev/null || true
    continue
  fi

  try_pull() {
    local f=$1 i=$2
    rclone copyto "gdrive:$rel" "$dest" \
      --drive-root-folder-id "$i" \
      --drive-acknowledge-abuse \
      --retries 3 --retries-sleep 5s \
      2>>"$QUAR/rclone-abuse.log"
  }

  pulled=0
  if [[ -n "$id" ]] && try_pull "$folder" "$id"; then
    pulled=1
  else
    for f in mirrors Scanner Software; do
      [[ "$f" == "$folder" ]] && continue
      i=${FID[$f]:-}
      [[ -n "$i" ]] || continue
      if try_pull "$f" "$i"; then
        folder=$f
        dest="$QUAR/$folder/$rel"
        pulled=1
        break
      fi
    done
  fi

  if [[ "$pulled" -eq 1 && -f "$dest" ]]; then
    sz=$(stat -c%s "$dest")
    printf 'ok\t%s\t%s\t%s\n' "$sz" "$folder" "$rel" >>"$MAN"
    log "quarantined: $folder/$rel ($sz bytes)"
    bash "$MISSING_TOOL" set-status "$folder" "$rel" quarantined "rclone --drive-acknowledge-abuse" 2>/dev/null || true
    # hash
    sha=$(sha256sum "$dest" | awk '{print $1}')
    bash "$MISSING_TOOL" set-status "$folder" "$rel" quarantined "sha256=$sha" 2>/dev/null || true
    ok=$((ok + 1))
  else
    printf 'FAIL\t0\t%s\t%s\n' "$folder" "$rel" >>"$MAN"
    log "MISSING (could not pull): $rel"
    bash "$MISSING_TOOL" set-status "$folder" "$rel" missing "pull failed; place in holding/inbox if you find a copy" 2>/dev/null || true
    fail=$((fail + 1))
  fi
  sleep 1
done

chmod 600 "$MAN" 2>/dev/null || true
log "done: ok=$ok fail=$fail -> $QUAR"
log "ledger: $DEST/missing.tsv"
[[ "$fail" -eq 0 ]]
