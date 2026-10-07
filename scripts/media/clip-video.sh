#!/usr/bin/env bash
# Trim a video and write MP4 (H.264 + AAC) or WebM (VP9 + Opus).
#
# The output suffix picks the container (.mp4 or .webm). Input can be MP4,
# WebM, or anything else ffmpeg decodes. Default dest is <stem>-clip.mp4, so
# a WebM input becomes an H.264 MP4 clip (same encode as webm-to-mp4, plus
# the trim). Re-encode is frame-accurate. --copy stream-copies only when the
# codecs already match the output (MP4: H.264 + AAC; WebM: VP8/VP9 + Opus or
# Vorbis). --copy snaps to the previous keyframe.
#
# --video-start / --video-end set the clip window. --start / -ss and
# --end / -to are aliases.
#
# --audio FILE replaces the clip's audio with the audio stream from FILE
# (audio or video). The window is --audio-start for the clip length. When
# --audio-start is omitted, it matches --video-start so a parallel recording
# stays aligned. Pass --audio-start 0 when FILE should be read from its beginning.
#
# Usage:
#   bin/clip-video --video-start 20 --video-end 50 atlantis.mp4
#   bin/clip-video --start 20 --end 50 atlantis.mp4
#   bin/clip-video -ss 00:00:20 -to 00:00:50 -o clip.mp4 input.webm
#   bin/clip-video --video-start 20 --video-end 50 --crf 20 --force in.mp4
#   bin/clip-video --video-start 20 --video-end 50 --copy --dry-run in.mp4
#   bin/clip-video --video-start 20 --video-end 50 --audio source-audio.mp4 source-video.mp4
#   bin/clip-video --video-start 20 --video-end 50 --audio bed.wav --audio-start 0 in.mp4
#   bin/clip-video --video-start 0 --video-end 30 -o clip.mp4 in.webm
#   bin/clip-video --video-start 20 --video-end 50 -o clip.webm in.mp4
#
# Env: FFMPEG_CRF (default 23), FFMPEG_PRESET (default veryfast)
set -euo pipefail

CRF="${FFMPEG_CRF:-23}"
PRESET="${FFMPEG_PRESET:-veryfast}"
START_RAW=""
END_RAW=""
OUT=""
FORCE=0
COPY=0
DRY_RUN=0
SRC=""
AUDIO=""
AUDIO_START_RAW=""

usage() {
  awk 'NR>=2 && /^set -euo pipefail$/ { exit } NR>=2 { print }' "$0"
  exit 2
}

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { log "ERROR: $*"; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --video-start|--start|-ss)
      [[ $# -ge 2 ]] || die "$1 needs a timestamp"
      [[ -z "$START_RAW" ]] || die "video start given twice"
      START_RAW="$2"; shift 2 ;;
    --video-end|--end|-to)
      [[ $# -ge 2 ]] || die "$1 needs a timestamp"
      [[ -z "$END_RAW" ]] || die "video end given twice"
      END_RAW="$2"; shift 2 ;;
    -o|--output)
      [[ $# -ge 2 ]] || die "$1 needs a path"
      OUT="$2"; shift 2 ;;
    --audio)
      [[ $# -ge 2 ]] || die "$1 needs a file"
      [[ -z "$AUDIO" ]] || die "--audio given twice"
      AUDIO="$2"; shift 2 ;;
    --audio-start)
      [[ $# -ge 2 ]] || die "$1 needs a timestamp"
      [[ -z "$AUDIO_START_RAW" ]] || die "--audio-start given twice"
      AUDIO_START_RAW="$2"; shift 2 ;;
    --crf)
      [[ $# -ge 2 ]] || die "$1 needs a value"
      CRF="$2"; shift 2 ;;
    --preset)
      [[ $# -ge 2 ]] || die "$1 needs a value"
      PRESET="$2"; shift 2 ;;
    --force|-y) FORCE=1; shift ;;
    --copy) COPY=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage ;;
    --) shift; break ;;
    -*) die "unknown option: $1" ;;
    *)
      [[ -z "$SRC" ]] || die "extra argument: $1"
      SRC="$1"; shift ;;
  esac
done
[[ $# -eq 0 ]] || die "extra argument: $1"

command -v ffmpeg >/dev/null || die "ffmpeg not found (apt install ffmpeg)"
command -v ffprobe >/dev/null || die "ffprobe not found (apt install ffmpeg)"
command -v python3 >/dev/null || die "python3 not found"

[[ -n "$START_RAW" ]] || die "need --video-start (--start, -ss)"
[[ -n "$END_RAW" ]] || die "need --video-end (--end, -to)"
[[ -n "$SRC" ]] || die "need an input file"
[[ -f "$SRC" ]] || die "not a file: $SRC"
if [[ -n "$AUDIO_START_RAW" && -z "$AUDIO" ]]; then
  die "--audio-start needs --audio"
fi

# Seconds from 12.5, 20, 1:30, 00:00:20, 00:00:20.5
parse_ts() {
  python3 -c '
import re, sys
s = sys.argv[1].strip()
if re.fullmatch(r"[0-9]+(\.[0-9]+)?", s):
    print(float(s)); raise SystemExit(0)
parts = s.split(":")
if not (2 <= len(parts) <= 3):
    raise SystemExit("bad timestamp: " + s)
try:
    nums = [float(p) for p in parts]
except ValueError:
    raise SystemExit("bad timestamp: " + s)
if any(n < 0 for n in nums):
    raise SystemExit("bad timestamp: " + s)
if len(nums) == 2:
    m, sec = nums
    if m != int(m) or sec >= 60:
        raise SystemExit("bad timestamp: " + s)
    print(m * 60 + sec)
else:
    h, m, sec = nums
    if h != int(h) or m != int(m) or m >= 60 or sec >= 60:
        raise SystemExit("bad timestamp: " + s)
    print(h * 3600 + m * 60 + sec)
' "$1"
}

START="$(parse_ts "$START_RAW")" || die "bad --video-start timestamp: $START_RAW"
END="$(parse_ts "$END_RAW")" || die "bad --video-end timestamp: $END_RAW"

python3 -c "import sys; s=float('$START'); e=float('$END'); sys.exit(0 if 0 <= s < e else 1)" \
  || die "need 0 <= start < end (got start=$START end=$END)"

DURATION="$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$SRC" 2>/dev/null || true)"
[[ -n "$DURATION" && "$DURATION" != "N/A" ]] || die "cannot read duration: $SRC"

python3 -c "
s=float('$START'); e=float('$END'); d=float('$DURATION')
raise SystemExit(0 if s < d and e <= d + 0.05 else 1)
" || die "range $START–$END s is outside file duration ${DURATION}s"

CLIP_DUR="$(python3 -c "print('{:.6f}'.format(float('$END') - float('$START')))")"

has_audio() {
  ffprobe -v error -select_streams a -show_entries stream=index \
    -of csv=p=0 "$1" 2>/dev/null | grep -q .
}

# First audio stream duration, else container duration. Empty if unknown.
audio_duration() {
  local d
  d="$(ffprobe -v error -select_streams a:0 -show_entries stream=duration \
    -of default=nw=1:nk=1 "$1" 2>/dev/null | head -n 1 || true)"
  if [[ -z "$d" || "$d" == "N/A" ]]; then
    d="$(ffprobe -v error -show_entries format=duration \
      -of default=nw=1:nk=1 "$1" 2>/dev/null || true)"
  fi
  printf '%s\n' "$d"
}

audio_codec() {
  ffprobe -v error -select_streams a:0 -show_entries stream=codec_name \
    -of csv=p=0 "$1" 2>/dev/null | head -n 1 || true
}

video_codec() {
  ffprobe -v error -select_streams v:0 -show_entries stream=codec_name \
    -of csv=p=0 "$1" 2>/dev/null | head -n 1 || true
}

AUDIO_ABS=""
AUDIO_START=""
if [[ -n "$AUDIO" ]]; then
  [[ -f "$AUDIO" ]] || die "not a file: $AUDIO"
  AUDIO_ABS="$(realpath "$AUDIO")"
  has_audio "$AUDIO_ABS" || die "no audio stream: $AUDIO_ABS"
  if [[ -n "$AUDIO_START_RAW" ]]; then
    AUDIO_START="$(parse_ts "$AUDIO_START_RAW")" || die "bad --audio-start timestamp: $AUDIO_START_RAW"
  else
    AUDIO_START="$START"
  fi
  python3 -c "import sys; s=float('$AUDIO_START'); sys.exit(0 if s >= 0 else 1)" \
    || die "need audio start >= 0 (got $AUDIO_START)"
  ADUR="$(audio_duration "$AUDIO_ABS")"
  [[ -n "$ADUR" && "$ADUR" != "N/A" ]] || die "cannot read audio duration: $AUDIO_ABS"
  python3 -c "
s=float('$AUDIO_START'); d=float('$CLIP_DUR'); a=float('$ADUR')
raise SystemExit(0 if s < a and s + d <= a + 0.05 else 1)
" || die "audio range ${AUDIO_START}s + ${CLIP_DUR}s is outside audio duration ${ADUR}s (pass --audio-start when the replacement file uses a different timeline)"
fi

SRC_ABS="$(realpath "$SRC")"
if [[ -n "$OUT" ]]; then
  DEST="$OUT"
else
  dir="$(dirname "$SRC_ABS")"
  base="$(basename "$SRC_ABS")"
  stem="${base%.*}"
  DEST="${dir}/${stem}-clip.mp4"
fi
# resolve dest parent; do not require dest to exist
DEST_DIR="$(dirname "$DEST")"
mkdir -p "$DEST_DIR"
DEST_ABS="$(realpath -m "$DEST")"

[[ "$DEST_ABS" != "$SRC_ABS" ]] || die "output would overwrite the source; pass -o another path"
if [[ -n "$AUDIO_ABS" ]]; then
  [[ "$DEST_ABS" != "$AUDIO_ABS" ]] || die "output would overwrite the audio file; pass -o another path"
fi

DEST_EXT="${DEST_ABS##*.}"
DEST_EXT="${DEST_EXT,,}"
case "$DEST_EXT" in
  mp4) CONTAINER="mp4" ;;
  webm) CONTAINER="webm" ;;
  *) die "output suffix must be .mp4 or .webm: $DEST_ABS" ;;
esac

if [[ -e "$DEST_ABS" && "$FORCE" -ne 1 ]]; then
  die "exists (use --force): $DEST_ABS"
fi

# x264 --preset names, mapped to libvpx-vp9 -cpu-used (0 slowest … 5 fastest).
vpx_cpu_used() {
  case "$PRESET" in
    ultrafast|superfast) printf '5\n' ;;
    veryfast|faster) printf '4\n' ;;
    fast) printf '3\n' ;;
    medium) printf '2\n' ;;
    slow) printf '1\n' ;;
    slower|veryslow|placebo) printf '0\n' ;;
    [0-5]) printf '%s\n' "$PRESET" ;;
    *) return 1 ;;
  esac
}

require_copy_codecs() {
  local vsrc="$1" asrc="$2" audio_required="$3"
  local v a
  v="$(video_codec "$vsrc")"
  a="$(audio_codec "$asrc")"
  if [[ "$CONTAINER" == "mp4" ]]; then
    [[ "$v" == "h264" ]] || die "--copy needs H.264 video for MP4 (transcode instead)"
    if [[ "$audio_required" -eq 1 ]]; then
      [[ "$a" == "aac" ]] || die "--copy needs AAC audio in the replacement file for MP4 (transcode instead)"
    else
      [[ -z "$a" || "$a" == "aac" ]] || die "--copy needs AAC or no audio for MP4 (transcode instead)"
    fi
    return 0
  fi
  [[ "$v" == "vp8" || "$v" == "vp9" ]] || die "--copy needs VP8 or VP9 video for WebM (transcode instead)"
  if [[ "$audio_required" -eq 1 ]]; then
    [[ "$a" == "opus" || "$a" == "vorbis" ]] || die "--copy needs Opus or Vorbis audio in the replacement file for WebM (transcode instead)"
  else
    [[ -z "$a" || "$a" == "opus" || "$a" == "vorbis" ]] || die "--copy needs Opus, Vorbis, or no audio for WebM (transcode instead)"
  fi
}

append_video_encoder() {
  local -n _enc=$1
  local cpu
  if [[ "$CONTAINER" == "mp4" ]]; then
    _enc+=(-c:v libx264 -preset "$PRESET" -crf "$CRF" -pix_fmt yuv420p)
    return 0
  fi
  cpu="$(vpx_cpu_used)" || die "WebM --preset must be an x264 preset name or 0-5 (cpu-used), got: $PRESET"
  # -b:v 0 selects VP9 CRF mode. Without it libvpx targets a default bitrate.
  _enc+=(-c:v libvpx-vp9 -crf "$CRF" -b:v 0 -pix_fmt yuv420p -row-mt 1 -cpu-used "$cpu")
}

append_audio_encoder() {
  local -n _enc=$1
  if [[ "$CONTAINER" == "mp4" ]]; then
    _enc+=(-c:a aac -b:a 160k)
  else
    _enc+=(-c:a libopus -b:a 160k)
  fi
}

append_finish() {
  local -n _enc=$1
  local mode="$2"
  if [[ "$mode" == "copy" ]]; then
    _enc+=(-avoid_negative_ts make_zero)
  fi
  if [[ "$CONTAINER" == "mp4" ]]; then
    _enc+=(-movflags +faststart)
  fi
  _enc+=(-f "$CONTAINER" -y "$DEST_ABS")
}

build_cmd() {
  local -n _out=$1
  if [[ -n "$AUDIO_ABS" && "$COPY" -eq 1 ]]; then
    # -ss before -i: copy cannot trim with a filter. Keyframe snap is the
    # same limit --copy already has for a single input.
    require_copy_codecs "$SRC_ABS" "$AUDIO_ABS" 1
    log "WARN: --copy may start on the previous keyframe, not exactly ${START}s (audio ${AUDIO_START}s)"
    _out=(
      ffmpeg -hide_banner -loglevel warning -stats
      -ss "$START" -t "$CLIP_DUR" -i "$SRC_ABS"
      -ss "$AUDIO_START" -t "$CLIP_DUR" -i "$AUDIO_ABS"
      -map 0:v:0 -c:v copy
      -map 1:a:0 -c:a copy
    )
    append_finish _out copy
    return
  fi
  if [[ -n "$AUDIO_ABS" ]]; then
    # Separate trims: video in-point and audio in-point are independent.
    # Output -ss would apply one timestamp to both inputs.
    _out=(
      ffmpeg -hide_banner -loglevel warning -stats
      -i "$SRC_ABS"
      -i "$AUDIO_ABS"
      -filter_complex "[0:v]trim=start=${START}:duration=${CLIP_DUR},setpts=PTS-STARTPTS,pad=ceil(iw/2)*2:ceil(ih/2)*2[v];[1:a]atrim=start=${AUDIO_START}:duration=${CLIP_DUR},asetpts=PTS-STARTPTS[a]"
      -map "[v]" -map "[a]"
    )
    append_video_encoder _out
    append_audio_encoder _out
    append_finish _out encode
    return
  fi
  _out=(
    ffmpeg -hide_banner -loglevel warning -stats
    -i "$SRC_ABS"
    -ss "$START" -t "$CLIP_DUR"
  )
  if [[ "$COPY" -eq 1 ]]; then
    require_copy_codecs "$SRC_ABS" "$SRC_ABS" 0
    log "WARN: --copy may start on the previous keyframe, not exactly ${START}s"
    _out+=(-map 0:v:0 -c:v copy)
    if has_audio "$SRC_ABS"; then
      _out+=(-map 0:a:0? -c:a copy)
    else
      _out+=(-an)
    fi
    append_finish _out copy
  else
    _out+=(
      -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2"
      -map 0:v:0
    )
    append_video_encoder _out
    if has_audio "$SRC_ABS"; then
      _out+=(-map 0:a:0?)
      append_audio_encoder _out
    else
      _out+=(-an)
    fi
    append_finish _out encode
  fi
}

CMD=()
build_cmd CMD

log "clip: $SRC_ABS"
log "  range ${START}s → ${END}s  (duration ${CLIP_DUR}s)"
if [[ -n "$AUDIO_ABS" ]]; then
  log "  audio $AUDIO_ABS  from ${AUDIO_START}s for ${CLIP_DUR}s"
fi
log "  dest  $DEST_ABS  (container=$CONTAINER crf=$CRF preset=$PRESET copy=$COPY)"

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf 'dry-run:'
  printf ' %q' "${CMD[@]}"
  printf '\n'
  exit 0
fi

"${CMD[@]}" || die "ffmpeg failed"

[[ -f "$DEST_ABS" ]] || die "ffmpeg exited 0 but dest missing: $DEST_ABS"
sz="$(du -h "$DEST_ABS" | awk '{print $1}')"
out_dur="$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$DEST_ABS" 2>/dev/null || echo '?')"
log "ok: $DEST_ABS (${sz:-?}  duration=${out_dur}s)"
