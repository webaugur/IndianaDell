#!/usr/bin/env bash
# GNOME user settings: force dark mode everywhere (GTK, shell, icons, WM).
# Run as the desktop user. Optionally sets GDM login greeter dark with sudo.
set -euo pipefail

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

if [[ "$(id -u)" -eq 0 ]]; then
  echo "Run as your normal user, not root." >&2
  exit 1
fi

command -v gsettings >/dev/null || { echo "gsettings not found" >&2; exit 1; }

GTK_THEME="${GTK_THEME:-Yaru-dark}"
ICON_THEME="${ICON_THEME:-Yaru-dark}"
WM_THEME="${WM_THEME:-Yaru-dark}"

log "Interface: prefer-dark + $GTK_THEME"
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME"
gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME"

log "GNOME Shell (Ubuntu): prefer-dark"
gsettings set org.gnome.shell.ubuntu color-scheme 'prefer-dark'

log "Window manager theme: $WM_THEME"
gsettings set org.gnome.desktop.wm.preferences theme "$WM_THEME"

log "Night light: off (no warm tint / schedule)"
gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled false
gsettings set org.gnome.settings-daemon.plugins.color night-light-schedule-automatic false

# Flatpak/GTK4 apps read color-scheme via portal when prefer-dark is set.
if command -v gsettings >/dev/null && gsettings list-schemas | grep -q org.gnome.settings-daemon.plugins.xsettings; then
  gsettings set org.gnome.settings-daemon.plugins.xsettings overrides \
    "{'Gtk/ColorScheme': <'prefer-dark'>, 'Net/ThemeName': <'${GTK_THEME}'>}" 2>/dev/null || true
fi

apply_gdm_dark() {
  if ! command -v dbus-run-session >/dev/null; then
    return 0
  fi
  log "GDM login screen: prefer-dark (requires sudo)"
  sudo dbus-run-session -- gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null \
    && sudo dbus-run-session -- gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME" 2>/dev/null \
    && sudo dbus-run-session -- gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME" 2>/dev/null \
    && log "GDM greeter updated" \
    || log "WARN: could not set GDM greeter (non-fatal)"
}

if [[ "${APPLY_GDM:-1}" == 1 ]]; then
  apply_gdm_dark
fi

log "Done."
gsettings get org.gnome.desktop.interface color-scheme
gsettings get org.gnome.desktop.interface gtk-theme
gsettings get org.gnome.desktop.interface icon-theme
gsettings get org.gnome.shell.ubuntu color-scheme 2>/dev/null || true
gsettings get org.gnome.desktop.wm.preferences theme 2>/dev/null || true