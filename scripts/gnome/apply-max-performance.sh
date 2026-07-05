#!/usr/bin/env bash
# GNOME user settings: max performance, no suspend, no dimming, no night light.
# Run as the desktop user (not root). Re-run after fresh login or OS reinstall.
set -euo pipefail

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

if [[ "$(id -u)" -eq 0 ]]; then
  echo "Run as your normal user, not root." >&2
  exit 1
fi

if ! command -v gsettings >/dev/null; then
  echo "gsettings not found — is GNOME installed?" >&2
  exit 1
fi

log "Power: disable suspend, dimming, ambient brightness"
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0
gsettings set org.gnome.settings-daemon.plugins.power idle-dim false
gsettings set org.gnome.settings-daemon.plugins.power idle-brightness 100
gsettings set org.gnome.settings-daemon.plugins.power ambient-enabled false
gsettings set org.gnome.settings-daemon.plugins.power lid-close-ac-action 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power lid-close-battery-action 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power power-saver-profile-on-low-battery false

log "Session: never idle out"
gsettings set org.gnome.desktop.session idle-delay 0

log "Screensaver: no blanking or lock on idle"
gsettings set org.gnome.desktop.screensaver idle-activation-enabled false
gsettings set org.gnome.desktop.screensaver lock-enabled false
gsettings set org.gnome.desktop.screensaver ubuntu-lock-on-suspend false

log "Color: disable night light (no daytime color shifting)"
gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled false
gsettings set org.gnome.settings-daemon.plugins.color night-light-schedule-automatic false

if command -v powerprofilesctl >/dev/null; then
  log "CPU/platform profile: performance"
  powerprofilesctl set performance
else
  log "WARN: powerprofilesctl not found — skip performance profile"
fi

log "Done. Settings apply immediately for this user."
log "Verify: powerprofilesctl get"
gsettings list-recursively org.gnome.settings-daemon.plugins.power | grep -E 'sleep-inactive|idle-dim|idle-brightness|ambient|lid-close'
gsettings get org.gnome.settings-daemon.plugins.color night-light-enabled