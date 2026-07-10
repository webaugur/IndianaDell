#!/usr/bin/env bash
# Restore double-click launch of .desktop files under Nautilus 50+ / GNOME Files.
#
# Background (Nautilus 50, Ubuntu 26.04 / GNOME 50):
#   Nautilus removed “Allow Launching”. It no longer executes FreeDesktop
#   .desktop entries itself (security change). Double-click falls through to
#   “open with default app” for MIME type application/x-desktop — often a
#   text editor (gedit, gnome-text-editor), so the file is edited, not run.
#
# Fix:
#   Install a tiny MIME handler so the open path becomes:
#     Files → xdg-open → xdg-desktop-launch → gio launch → your app
#
# Portable: run as the desktop user on any Ubuntu/GNOME system. No root.
# Does not require the IndianaDell tree once this script is present.
#
# Usage:
#   fix-nautilus-desktop-launch           # install / reinstall
#   fix-nautilus-desktop-launch --status  # show current handler
#   fix-nautilus-desktop-launch --uninstall
#   fix-nautilus-desktop-launch --help
set -euo pipefail

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { echo "error: $*" >&2; exit 1; }

MIME_TYPE="application/x-desktop"
HANDLER_ID="xdg-desktop-launch.desktop"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
WRAPPER="$BIN_DIR/xdg-desktop-launch"
DESKTOP="$APP_DIR/$HANDLER_ID"

usage() {
  sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

require_user() {
  if [[ "$(id -u)" -eq 0 ]]; then
    die "run as your normal desktop user, not root"
  fi
}

write_wrapper() {
  mkdir -p "$BIN_DIR"
  cat >"$WRAPPER" <<'WRAPPER_EOF'
#!/usr/bin/env bash
# Launch a FreeDesktop .desktop file (Nautilus 50+ no longer does this itself).
set -euo pipefail
if [[ $# -lt 1 ]]; then
  echo "usage: $0 path/to/app.desktop" >&2
  exit 2
fi
target=$1
if [[ ! -f "$target" ]]; then
  echo "not a file: $target" >&2
  exit 1
fi
# Prefer gio (handles Trusted / relative Exec); fall back to gtk-launch by basename
if command -v gio >/dev/null && gio launch "$target" 2>/dev/null; then
  exit 0
fi
base=$(basename "$target" .desktop)
if command -v gtk-launch >/dev/null; then
  exec gtk-launch "$base"
fi
# Last resort: parse Exec= (simple, no field codes)
exec_line=$(grep -E '^Exec=' "$target" | head -1 | cut -d= -f2-)
# strip common field codes
exec_line=${exec_line//%f/}
exec_line=${exec_line//%F/}
exec_line=${exec_line//%u/}
exec_line=${exec_line//%U/}
exec_line=${exec_line//%i/}
exec_line=${exec_line//%c/}
exec_line=${exec_line//%k/}
# shellcheck disable=SC2086
eval exec $exec_line
WRAPPER_EOF
  chmod 755 "$WRAPPER"
}

write_desktop() {
  mkdir -p "$APP_DIR"
  cat >"$DESKTOP" <<DESKTOP_EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Run Application Launcher
Comment=Launch FreeDesktop .desktop application entries (Nautilus 50+ workaround)
Exec=$WRAPPER %f
MimeType=$MIME_TYPE;
NoDisplay=true
Terminal=false
Categories=System;
DESKTOP_EOF
  chmod 755 "$DESKTOP"
}

register_mime() {
  if command -v xdg-mime >/dev/null; then
    xdg-mime default "$HANDLER_ID" "$MIME_TYPE"
  else
    # Fallback: edit mimeapps.list Default Applications section
    local mimeapps="${XDG_CONFIG_HOME:-$HOME/.config}/mimeapps.list"
    mkdir -p "$(dirname "$mimeapps")"
    if [[ ! -f "$mimeapps" ]]; then
      printf '[Default Applications]\n%s=%s\n' "$MIME_TYPE" "$HANDLER_ID" >"$mimeapps"
    else
      if grep -q "^${MIME_TYPE}=" "$mimeapps" 2>/dev/null; then
        # portable in-place replace without relying on GNU sed -i alone
        local tmp
        tmp=$(mktemp)
        sed "s|^${MIME_TYPE}=.*|${MIME_TYPE}=${HANDLER_ID}|" "$mimeapps" >"$tmp"
        mv "$tmp" "$mimeapps"
      else
        if grep -q '^\[Default Applications\]' "$mimeapps"; then
          local tmp
          tmp=$(mktemp)
          awk -v k="$MIME_TYPE" -v v="$HANDLER_ID" '
            BEGIN { done=0 }
            /^\[Default Applications\]/ { print; print k "=" v; done=1; next }
            { print }
            END { if (!done) { print ""; print "[Default Applications]"; print k "=" v } }
          ' "$mimeapps" >"$tmp"
          mv "$tmp" "$mimeapps"
        else
          printf '\n[Default Applications]\n%s=%s\n' "$MIME_TYPE" "$HANDLER_ID" >>"$mimeapps"
        fi
      fi
    fi
  fi

  # Ensure desktop database sees the new handler
  if command -v update-desktop-database >/dev/null; then
    update-desktop-database "$APP_DIR" 2>/dev/null || true
  fi
}

show_status() {
  local current="(none)"
  if command -v xdg-mime >/dev/null; then
    current=$(xdg-mime query default "$MIME_TYPE" 2>/dev/null || echo "(none)")
  fi
  echo "MIME type:     $MIME_TYPE"
  echo "Default app:   $current"
  echo "Wrapper:       $WRAPPER$([ -x "$WRAPPER" ] && echo '  [ok]' || echo '  [missing]')"
  echo "Desktop entry: $DESKTOP$([ -f "$DESKTOP" ] && echo '  [ok]' || echo '  [missing]')"
  if [[ "$current" == "$HANDLER_ID" ]] && [[ -x "$WRAPPER" ]] && [[ -f "$DESKTOP" ]]; then
    echo "Status:        installed (double-click .desktop should launch)"
    return 0
  fi
  echo "Status:        not fully installed"
  return 1
}

do_install() {
  require_user
  log "Installing Nautilus 50 .desktop launch fix for user $USER"
  write_wrapper
  log "Wrote $WRAPPER"
  write_desktop
  log "Wrote $DESKTOP"
  register_mime
  log "Registered $MIME_TYPE → $HANDLER_ID"

  # Ensure ~/.local/bin is on PATH for non-login shells (harmless if already present)
  if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    log "Note: $BIN_DIR is not on PATH in this shell (MIME handler uses absolute path; OK)"
  fi

  echo
  show_status || true
  echo
  log "Done. Double-click a .desktop file in Files to verify."
  log "CLI check:  xdg-open /path/to/App.desktop"
  log "Or:         $WRAPPER /path/to/App.desktop"
}

do_uninstall() {
  require_user
  log "Removing Nautilus 50 .desktop launch fix"

  rm -f "$WRAPPER" "$DESKTOP"

  # Clear MIME default only if we own it
  local current=""
  if command -v xdg-mime >/dev/null; then
    current=$(xdg-mime query default "$MIME_TYPE" 2>/dev/null || true)
  fi
  if [[ "$current" == "$HANDLER_ID" ]]; then
    local mimeapps="${XDG_CONFIG_HOME:-$HOME/.config}/mimeapps.list"
    if [[ -f "$mimeapps" ]]; then
      local tmp
      tmp=$(mktemp)
      # Remove our Default Applications line; leave Added Associations alone
      grep -v "^${MIME_TYPE}=${HANDLER_ID}\$" "$mimeapps" >"$tmp" || true
      mv "$tmp" "$mimeapps"
    fi
  fi

  if command -v update-desktop-database >/dev/null; then
    update-desktop-database "$APP_DIR" 2>/dev/null || true
  fi

  log "Removed. .desktop files may open in a text editor again."
  show_status || true
}

main() {
  case "${1:-}" in
    "" | --install | install) do_install ;;
    --status | status) show_status ;;
    --uninstall | uninstall | --remove | remove) do_uninstall ;;
    -h | --help | help) usage ;;
    *)
      echo "unknown option: $1" >&2
      usage
      ;;
  esac
}

main "$@"
