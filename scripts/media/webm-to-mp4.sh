#!/usr/bin/env bash
# Convert GNOME Screencast (and other) .webm files to .mp4 (H.264).
#
# GNOME's screencast app typically writes VP8 in WebM, often without audio.
# Players and upload sites are happier with H.264 MP4.
#
# Usage:
#   bin/webm-to-mp4                         # all *.webm in ~/Screencasts
#   bin/webm-to-mp4 ~/Screencasts           # directory
#   bin/webm-to-mp4 clip.webm other.webm    # explicit files
#   bin/webm-to-mp4 -o ~/Videos clip.webm   # output directory
#   bin/webm-to-mp4 --crf 20 --delete       # quality + remove source after success
#
# Env: FFMPEG_CRF (default 23), FFMPEG_PRESET (default veryfast)
set -euo pipefail

CRF="${FFMPEG_CRF:-23}"
PRESET="${FFMPEG_PRESET:-veryfast}"
OUT_DIR=""
DELETE_SRC=0
DRY_RUN=0
DEFAULT_DIR="${SCREENCASTS_DIR:-$HOME/Screencasts}"

usage() {
  sed -n '2,16p' "$0"
  exit 2
}

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { log "ERROR: $*"; exit 1; }

ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output-dir) OUT_DIR="$2"; shift 2 ;;
    --crf) CRF="$2"; shift 2 ;;
    --preset) PRESET="$2"; shift 2 ;;
    --delete) DELETE_SRC=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage ;;
    --) shift; ARGS+=("$@"); break ;;
    -*) die "unknown option: $1" ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

command -v ffmpeg >/dev/null || die "ffmpeg not found (apt install ffmpeg)"
command -v ffprobe >/dev/null || die "ffprobe not found (apt install ffmpeg)"

collect_inputs() {
  local a path
  if [[ ${#ARGS[@]} -eq 0 ]]; then
    [[ -d "$DEFAULT_DIR" ]] || die "no arguments and default dir missing: $DEFAULT_DIR"
    ARGS=("$DEFAULT_DIR")
  fi
  for a in "${ARGS[@]}"; do
    path="$(realpath -m "$a")"
    if [[ -d "$path" ]]; then
      # shellcheck disable=SC2164
      while IFS= read -r -d '' f; do
        printf '%s\0' "$f"
      done < <(find "$path" -maxdepth 1 -type f \( -iname '*.webm' \) -print0 | sort -z)
    elif [[ -f "$path" ]]; then
      [[ "$path" =~ \.[Ww][Ee][Bb][Mm]$ ]] || die "not a .webm file: $path"
      printf '%s\0' "$path"
    else
      die "not found: $a"
    fi
  done
}

has_audio() {
  ffprobe -v error -select_streams a -show_entries stream=index \
    -of csv=p=0 "$1" 2>/dev/null | grep -q .
}

convert_one() {
  local src="$1" dest dir base
  dir="$(dirname "$src")"
  base="$(basename "$src")"
  base="${base%.*}"
  if [[ -n "$OUT_DIR" ]]; then
    mkdir -p "$OUT_DIR"
    dest="$OUT_DIR/${base}.mp4"
  else
    dest="${dir}/${base}.mp4"
  fi

  if [[ -f "$dest" ]]; then
    log "skip (exists): $dest"
    return 0
  fi

  log "convert: $src"
  log "     ->  $dest  (crf=$CRF preset=$PRESET)"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    return 0
  fi

  # GNOME screencasts: VP8 (+ optional Opus). Re-encode for widest MP4 support.
  # -movflags +faststart: streamable / scrub-friendly
  # -pix_fmt yuv420p: old players / browsers
  local -a cmd=(
    ffmpeg -hide_banner -loglevel warning -stats
    -i "$src"
    -map 0:v:0
    -c:v libx264 -preset "$PRESET" -crf "$CRF" -pix_fmt yuv420p
  )
  if has_audio "$src"; then
    cmd+=(-map 0:a:0? -c:a aac -b:a 160k)
  else
    cmd+=(-an)
  fi
  cmd+=(-movflags +faststart -y "$dest")

  "${cmd[@]}"
  # sync size after ffmpeg closes the file
  local sz
  sz="$(du -h "$dest" 2>/dev/null | awk '{print $1}')"
  log "ok: $dest (${sz:-?})"

  if [[ "$DELETE_SRC" -eq 1 ]]; then
    rm -f "$src"
    log "deleted source: $src"
  fi
}

main() {
  local count=0 src
  while IFS= read -r -d '' src; do
    convert_one "$src"
    count=$((count + 1))
  done < <(collect_inputs)

  [[ "$count" -gt 0 ]] || die "no .webm files found"
  log "done ($count file(s))"
}

main
