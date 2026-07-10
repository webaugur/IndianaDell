#!/usr/bin/env bash
# Set Nautilus custom-icon metadata from .desktop Icon= fields.
# Optionally rename Chrome-style gibberish .desktop basenames to Name=.
#
# Companion to scripts/gnome/fix-nautilus-desktop-launch.sh (double-click launch).
# Nautilus 50+ shows the generic application-x-desktop MIME icon in the file view
# and ignores Icon=. It still honors GIO metadata:
#   metadata::custom-icon       file:///absolute/path.png
#   metadata::custom-icon-name  theme-icon-name
#
# Chrome PWAs drop files like chrome-lodlkdfmihgonocnmddehnfgiljnadcf-Default.desktop
# with a short Name= (e.g. "X", "YouTube"). With --rename (default on), writable
# files matching that pattern are renamed to "${Name}.desktop" when safe.
#
# Run as the desktop user (not root). Portable once this script is present.
#
# Usage:
#   bin/sync-desktop-icons                 # scan default dirs
#   bin/sync-desktop-icons --file PATH     # one file (inotify-friendly)
#   bin/sync-desktop-icons --watch         # inotify loop (needs inotify-tools)
#   bin/sync-desktop-icons --dir DIR -v
#   bin/sync-desktop-icons --no-rename     # icons only, keep chrome-* names
#
# Env:
#   SYNC_DESKTOP_ICON_DIRS  colon-separated dirs (overrides defaults if set)

set -euo pipefail

VERBOSE=0
DRY_RUN=0
WATCH=0
CLEAR_MISSING=0
RENAME=1
SINGLE_FILE=""
EXTRA_DIRS=()

# All human messages go to stderr so functions can print results on stdout
# (e.g. maybe_rename_desktop returns the path under command substitution).
log()  { printf '%s\n' "$*" >&2; }
vlog() { [[ "$VERBOSE" -eq 1 ]] && printf '%s\n' "$*" >&2 || true; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: sync-desktop-icons.sh [options]

Scan .desktop files, read Icon=, and set GIO metadata so Nautilus shows
the correct icon (metadata::custom-icon or metadata::custom-icon-name).

Also renames writable Chrome PWA launchers with opaque basenames
(chrome-<id>-Default.desktop) to "${Name}.desktop" from the Desktop Entry.

Options:
  --file PATH     Process one .desktop file (for inotify handlers)
  --dir DIR       Add a scan directory (repeatable)
  --watch         Watch scan dirs with inotifywait (needs inotify-tools)
  --clear-missing Unset custom-icon* when Icon= is missing
  --rename        Rename gibberish chrome-*.desktop → Name=.desktop (default)
  --no-rename     Do not rename files; only set icon metadata
  --verbose, -v   Log each change / skip
  --dry-run       Print actions without gio set / rename
  -h, --help      Show this help

Default scan directories (if --dir not given and SYNC_DESKTOP_ICON_DIRS unset):
  $HOME/.local/share/applications
  $HOME/Applications
  $HOME/Desktop

Environment:
  SYNC_DESKTOP_ICON_DIRS   colon-separated list of directories

Examples:
  sync-desktop-icons.sh -v
  sync-desktop-icons.sh --dir ~/Desktop -v
  sync-desktop-icons.sh --file ~/Desktop/chrome-….desktop
  sync-desktop-icons.sh --no-rename -v
  inotifywait -m -e close_write,moved_to,create --include '\.desktop$' \
    "$HOME/Desktop" | while read -r dir _ file; do
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
    --rename) RENAME=1; shift ;;
    --no-rename) RENAME=0; shift ;;
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
      "${HOME}/Applications" \
      "${HOME}/Desktop"
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

# Read KEY= under [Desktop Entry] only (not KEY[lang]=, not Desktop Action groups)
read_desktop_entry_field() {
  local file=$1
  local want=$2
  local in_entry=0
  local line val

  while IFS= read -r line || [[ -n "$line" ]]; do
    line=${line//$'\r'/}
    if [[ "$line" =~ ^\[(.*)\]$ ]]; then
      if [[ "${BASH_REMATCH[1]}" == "Desktop Entry" ]]; then
        in_entry=1
      else
        [[ $in_entry -eq 1 ]] && break
        in_entry=0
      fi
      continue
    fi
    [[ $in_entry -eq 1 ]] || continue
    [[ "$line" =~ ^# ]] && continue
    [[ -z "$line" ]] && continue
    # exact key only (not Name[en_US]=)
    if [[ "$line" == "${want}="* ]]; then
      val=${line#"${want}="}
      val="${val#"${val%%[![:space:]]*}"}"
      val="${val%"${val##*[![:space:]]}"}"
      printf '%s' "$val"
      return 0
    fi
  done < "$file"
  return 1
}

read_icon_field() {
  read_desktop_entry_field "$1" Icon
}

read_name_field() {
  read_desktop_entry_field "$1" Name
}

# Chrome / Chromium PWA launcher basenames are opaque app-id strings.
is_gibberish_desktop_basename() {
  local base=$1
  # chrome-<id>-Default.desktop or chrome-<id>.desktop (id is long alnum)
  [[ "$base" =~ ^chrome-[a-zA-Z0-9]{16,}(-Default)?\.desktop$ ]] && return 0
  # Chromium flatpak / other: chromium-*.desktop with long id
  [[ "$base" =~ ^chromium-[a-zA-Z0-9]{16,}(-Default)?\.desktop$ ]] && return 0
  return 1
}

# Turn Name= into a single path component safe for Linux filesystems.
sanitize_desktop_filename() {
  local name=$1
  # strip CR and path separators
  name=${name//$'\r'/}
  name=${name//\//-}
  name=${name//$'\0'/}
  # trim
  name="${name#"${name%%[![:space:]]*}"}"
  name="${name%"${name##*[![:space:]]}"}"
  # collapse internal whitespace runs to a single space
  name=$(printf '%s' "$name" | tr -s '[:space:]' ' ')
  # drop characters that are awkward in shell/Desktop contexts (keep spaces, dots, +)
  name=$(printf '%s' "$name" | tr -d '<>:"\\|?*')
  # no leading/trailing dots or spaces (hidden / empty-looking names)
  name="${name##.}"
  name="${name%%.}"
  name="${name#"${name%%[![:space:]]*}"}"
  name="${name%"${name##*[![:space:]]}"}"
  # reject empty or "." / ".."
  [[ -n "$name" && "$name" != "." && "$name" != ".." ]] || return 1
  # cap length (leave room for .desktop)
  if [[ ${#name} -gt 200 ]]; then
    name=${name:0:200}
    name="${name%"${name##*[![:space:]]}"}"
  fi
  printf '%s' "$name"
}

# If path is a writable gibberish chrome-*.desktop, rename to Name=.desktop.
# Prints the resulting path (possibly unchanged) on stdout.
maybe_rename_desktop() {
  local path=$1
  local base dir name safe dest

  base=$(basename "$path")
  if [[ "$RENAME" -ne 1 ]]; then
    printf '%s' "$path"
    return 0
  fi
  if ! is_gibberish_desktop_basename "$base"; then
    vlog "rename skip (not chrome/chromium id name): $path"
    printf '%s' "$path"
    return 0
  fi
  if [[ ! -f "$path" ]]; then
    printf '%s' "$path"
    return 0
  fi
  # Need write on the file (rename replaces the dirent) and its directory
  if [[ ! -w "$path" ]]; then
    warn "rename skip (file not writable): $path"
    printf '%s' "$path"
    return 0
  fi
  dir=$(dirname "$path")
  if [[ ! -w "$dir" ]]; then
    warn "rename skip (directory not writable): $dir"
    printf '%s' "$path"
    return 0
  fi

  if ! name=$(read_name_field "$path"); then
    warn "rename skip (no Name=): $path"
    printf '%s' "$path"
    return 0
  fi
  if ! safe=$(sanitize_desktop_filename "$name"); then
    warn "rename skip (Name= not usable as filename: '$name'): $path"
    printf '%s' "$path"
    return 0
  fi

  dest="${dir}/${safe}.desktop"
  if [[ "$path" == "$dest" ]]; then
    vlog "rename skip (already named): $path"
    printf '%s' "$path"
    return 0
  fi
  if [[ -e "$dest" ]]; then
    warn "rename skip (target exists): $path → $dest"
    printf '%s' "$path"
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "dry-run: rename $path → $dest"
    printf '%s' "$path"
    return 0
  fi

  if mv -n "$path" "$dest"; then
    log "renamed: $base → ${safe}.desktop"
    printf '%s' "$dest"
    return 0
  fi
  warn "rename failed: $path → $dest"
  printf '%s' "$path"
  return 0
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

  # Rename chrome-*-Default.desktop → Name=.desktop when writable (before icon meta)
  real=$(maybe_rename_desktop "$real")
  path=$real

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
