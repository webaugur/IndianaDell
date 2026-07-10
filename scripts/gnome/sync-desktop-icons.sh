#!/usr/bin/env bash
# Set Nautilus custom-icon metadata from .desktop Icon= fields.
#
# Companion to scripts/gnome/fix-nautilus-desktop-launch.sh (double-click launch).
# Nautilus 50+ shows the generic application-x-desktop MIME icon in the file view
# and ignores Icon=. It still honors GIO metadata:
#   metadata::custom-icon       file:///absolute/path.png
#   metadata::custom-icon-name  theme-icon-name
#
# Run as the desktop user (not root). Portable once this script is present.
#
# Usage:
#   bin/sync-desktop-icons                 # scan default dirs
#   bin/sync-desktop-icons --file PATH     # one file (inotify-friendly)
#   bin/sync-desktop-icons --watch         # inotify loop (needs inotify-tools)
#   bin/sync-desktop-icons --dir DIR -v
#
# Env:
#   SYNC_DESKTOP_ICON_DIRS  colon-separated dirs (overrides defaults if set)

set -euo pipefail

VERBOSE=0
DRY_RUN=0
WATCH=0
CLEAR_MISSING=0
SINGLE_FILE=""
EXTRA_DIRS=()

log()  { printf '%s\n' "$*"; }
vlog() { [[ "$VERBOSE" -eq 1 ]] && printf '%s\n' "$*" || true; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: sync-desktop-icons.sh [options]

Scan .desktop files, read Icon=, and set GIO metadata so Nautilus shows
the correct icon (metadata::custom-icon or metadata::custom-icon-name).

Options:
  --file PATH     Process one .desktop file (for inotify handlers)
  --dir DIR       Add a scan directory (repeatable)
  --watch         Watch scan dirs with inotifywait (needs inotify-tools)
  --clear-missing Unset custom-icon* when Icon= is missing
  --verbose, -v   Log each change / skip
  --dry-run       Print actions without calling gio set
  -h, --help      Show this help

Default scan directories (if --dir not given and SYNC_DESKTOP_ICON_DIRS unset):
  $HOME/.local/share/applications
  $HOME/Applications

Environment:
  SYNC_DESKTOP_ICON_DIRS   colon-separated list of directories

Examples:
  sync-desktop-icons.sh -v
  sync-desktop-icons.sh --file ~/Applications/SDRPlusPlus.desktop
  inotifywait -m -e close_write,moved_to,create --include '\.desktop$' \
    "$HOME/Applications" | while read -r dir _ file; do
      sync-desktop-icons.sh --file "$dir$file"
    done
EOF
}

# --- parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)
      [[ $# -ge 2 ]] || die "--file requires a path"
      SINGLE_FILE=$2
      shift 2
      ;;
    --dir)
      [[ $# -ge 2 ]] || die "--dir requires a path"
      EXTRA_DIRS+=("$2")
      shift 2
      ;;
    --watch) WATCH=1; shift ;;
    --clear-missing) CLEAR_MISSING=1; shift ;;
    --verbose|-v) VERBOSE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
done

command -v gio >/dev/null 2>&1 || die "gio not found (install libglib2.0-bin)"

# --- scan dirs ---
default_dirs() {
  if [[ -n "${SYNC_DESKTOP_ICON_DIRS:-}" ]]; then
    local IFS=':'
    # shellcheck disable=SC2206
    local parts=($SYNC_DESKTOP_ICON_DIRS)
    printf '%s\n' "${parts[@]}"
  else
    printf '%s\n' \
      "${HOME}/.local/share/applications" \
      "${HOME}/Applications"
  fi
}

collect_dirs() {
  local d
  if [[ ${#EXTRA_DIRS[@]} -gt 0 ]]; then
    printf '%s\n' "${EXTRA_DIRS[@]}"
  else
    default_dirs
  fi | while read -r d; do
    [[ -n "$d" ]] || continue
    # expand leading ~
    [[ "$d" == ~* ]] && d="${d/#\~/$HOME}"
    [[ -d "$d" ]] && printf '%s\n' "$d"
  done
}

# First Icon= under [Desktop Entry] only (not Icon[lang]=, not other groups)
read_icon_field() {
  local file=$1
  local in_entry=0
  local line key val

  while IFS= read -r line || [[ -n "$line" ]]; do
    # strip CR
    line=${line//$'\r'/}
    # section headers
    if [[ "$line" =~ ^\[(.*)\]$ ]]; then
      if [[ "${BASH_REMATCH[1]}" == "Desktop Entry" ]]; then
        in_entry=1
      else
        # left Desktop Entry group
        [[ $in_entry -eq 1 ]] && break
        in_entry=0
      fi
      continue
    fi
    [[ $in_entry -eq 1 ]] || continue
    [[ "$line" =~ ^# ]] && continue
    [[ -z "$line" ]] && continue
    if [[ "$line" == Icon=* ]]; then
      val=${line#Icon=}
      # trim whitespace
      val="${val#"${val%%[![:space:]]*}"}"
      val="${val%"${val##*[![:space:]]}"}"
      printf '%s' "$val"
      return 0
    fi
  done < "$file"
  return 1
}

get_meta() {
  # stdout: value of attribute or empty
  local file=$1 attr=$2
  # gio info lines look like: "  metadata::custom-icon: file:///..."
  gio info -a "$attr" "$file" 2>/dev/null \
    | sed -n "s/^[[:space:]]*${attr}:[[:space:]]*//p" \
    | head -1
}

unset_meta() {
  local file=$1 attr=$2
  local cur
  cur=$(get_meta "$file" "$attr")
  [[ -n "$cur" ]] || return 0
  if [[ "$DRY_RUN" -eq 1 ]]; then
    vlog "dry-run: unset $attr on $file (was: $cur)"
    return 0
  fi
  gio set -t unset "$file" "$attr" 2>/dev/null || true
  vlog "unset $attr on $file"
}

set_meta() {
  local file=$1 attr=$2 value=$3
  local cur
  cur=$(get_meta "$file" "$attr")
  if [[ "$cur" == "$value" ]]; then
    vlog "ok (unchanged): $attr on $file"
    return 0
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "dry-run: set $attr=$value on $file"
    return 0
  fi
  gio set "$file" "$attr" "$value"
  vlog "set $attr=$value on $file"
}

# Process one desktop path. Never exits non-zero for content issues.
process_file() {
  local path=$1
  local real icon icon_path uri cur_icon cur_name

  if [[ ! -e "$path" ]]; then
    vlog "skip (missing): $path"
    return 0
  fi
  if [[ ! -f "$path" && ! -L "$path" ]]; then
    vlog "skip (not a file): $path"
    return 0
  fi
  case "$path" in
    *.desktop) ;;
    *) vlog "skip (not .desktop): $path"; return 0 ;;
  esac

  # Prefer real path for metadata (inode); still works if only symlink exists
  real=$(readlink -f "$path" 2>/dev/null || true)
  [[ -n "$real" && -e "$real" ]] || real=$path

  icon=""
  if ! icon=$(read_icon_field "$real"); then
    if [[ "$CLEAR_MISSING" -eq 1 ]]; then
      unset_meta "$real" metadata::custom-icon
      unset_meta "$real" metadata::custom-icon-name
    else
      vlog "skip (no Icon=): $real"
    fi
    return 0
  fi
  [[ -n "$icon" ]] || {
    vlog "skip (empty Icon=): $real"
    return 0
  }

  # Strip file:// prefix if present
  if [[ "$icon" == file://* ]]; then
    icon=${icon#file://}
    # URL-decode is out of scope; plain paths only
  fi

  if [[ "$icon" == /* ]]; then
    # absolute path
    if [[ ! -e "$icon" ]]; then
      warn "icon file missing for $real: $icon"
      return 0
    fi
    icon_path=$(readlink -f "$icon" 2>/dev/null || echo "$icon")
    uri="file://${icon_path}"
    set_meta "$real" metadata::custom-icon "$uri"
    unset_meta "$real" metadata::custom-icon-name
  elif [[ "$icon" == */* ]]; then
    # relative path from desktop file directory
    icon_path=$(readlink -f "$(dirname "$real")/$icon" 2>/dev/null || true)
    if [[ -z "$icon_path" || ! -e "$icon_path" ]]; then
      warn "relative icon missing for $real: $icon"
      return 0
    fi
    uri="file://${icon_path}"
    set_meta "$real" metadata::custom-icon "$uri"
    unset_meta "$real" metadata::custom-icon-name
  else
    # theme icon name
    set_meta "$real" metadata::custom-icon-name "$icon"
    unset_meta "$real" metadata::custom-icon
  fi
}

# Deduped full scan
scan_all() {
  local dir f real
  declare -A seen=()

  while read -r dir; do
    [[ -d "$dir" ]] || continue
    vlog "scanning: $dir"
    # top-level only (matches Applications + flat XDG apps layout)
    shopt -s nullglob
    for f in "$dir"/*.desktop; do
      real=$(readlink -f "$f" 2>/dev/null || echo "$f")
      if [[ -n "${seen[$real]+x}" ]]; then
        vlog "skip (already processed): $f -> $real"
        continue
      fi
      seen[$real]=1
      process_file "$f" || warn "failed processing $f"
    done
    shopt -u nullglob
  done < <(collect_dirs)
}

watch_loop() {
  command -v inotifywait >/dev/null 2>&1 \
    || die "inotifywait not found (install inotify-tools) for --watch"

  local dirs=()
  local d
  while read -r d; do
    dirs+=("$d")
  done < <(collect_dirs)
  [[ ${#dirs[@]} -gt 0 ]] || die "no scan directories exist to watch"

  log "watching: ${dirs[*]}"
  # Initial sync
  scan_all

  # close_write,moved_to,create,attrib — cover save, rename, new, chmod/metadata
  # --include may be unavailable on very old inotifywait; filter in shell too
  local dir event file path
  inotifywait -m -e close_write,moved_to,create,attrib \
    --format '%w|%e|%f' \
    "${dirs[@]}" 2>/dev/null \
  | while IFS='|' read -r dir event file; do
      [[ -n "$file" ]] || continue
      [[ "$file" == *.desktop ]] || continue
      path="${dir}${file}"
      vlog "event $event: $path"
      process_file "$path" || warn "failed processing $path"
    done
}

# --- main ---
if [[ -n "$SINGLE_FILE" ]]; then
  process_file "$SINGLE_FILE"
  exit 0
fi

if [[ "$WATCH" -eq 1 ]]; then
  watch_loop
  exit 0
fi

scan_all
exit 0
