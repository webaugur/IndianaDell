#!/usr/bin/env bash
#
# fix-desktop-integration.sh
# Verify and repair Wayland clipboard + Qt/GNOME theming on IndianaDell systems.
#
# This matches the requirements documented in:
#   docs/usb-dock-stability.md  (Clipboard fix section)
#   scripts/rebuild/package-lists.sh
#
# Usage:
#   bin/fix-desktop-integration.sh            # report only
#   bin/fix-desktop-integration.sh --fix      # install/repair everything
#   bin/fix-desktop-integration.sh --verify-only
#
set -euo pipefail

FIX=0
VERIFY_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --fix) FIX=1 ;;
    --verify-only) VERIFY_ONLY=1 ;;
    -h|--help)
      sed -n '4,12p' "$0"
      exit 0
      ;;
    *) echo "Unknown argument: $arg"; exit 1 ;;
  esac
done

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
need_fix=0

check_bashrc_var() {
  local var="$1" value="$2" comment="$3"
  if grep -q "^export $var=$value" "$HOME/.bashrc" 2>/dev/null; then
    log "OK   $var=$value"
  else
    log "MISS $var=$value  ($comment)"
    need_fix=1
    if [[ $FIX -eq 1 ]]; then
      echo -e "\n# $comment\nexport $var=$value" >> "$HOME/.bashrc"
      log "FIXED $var"
    fi
  fi
}

check_pkg() {
  local pkg="$1"
  if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q 'install ok installed'; then
    log "OK   apt: $pkg"
  else
    log "MISS apt: $pkg"
    need_fix=1
    if [[ $FIX -eq 1 ]]; then
      sudo apt install -y "$pkg"
      log "FIXED $pkg"
    fi
  fi
}

check_copyq_autostart() {
  local desktop="$HOME/.config/autostart/com.github.hluk.copyq.desktop"
  if [[ -f "$desktop" ]]; then
    log "OK   CopyQ autostart"
  else
    log "MISS CopyQ autostart entry"
    need_fix=1
    if [[ $FIX -eq 1 ]]; then
      mkdir -p "$HOME/.config/autostart"
      cat > "$desktop" << 'DESKTOP'
[Desktop Entry]
Type=Application
Name=CopyQ
GenericName=Clipboard Manager
Icon=copyq
Exec=copyq
Terminal=false
Categories=Utility;Qt;
StartupNotify=false
X-GNOME-Autostart-enabled=true
DESKTOP
      log "FIXED CopyQ autostart"
    fi
  fi
}

echo "=== IndianaDell Desktop Integration Check ==="

check_bashrc_var "ARBOARD_BACKEND" "wayland" "Wayland clipboard for Rust TUIs (Grok, etc.)"
check_bashrc_var "QT_QPA_PLATFORMTHEME" "gtk3" "Qt apps use GTK/Adwaita styling on GNOME"

check_pkg "wl-clipboard"
check_pkg "copyq"
check_pkg "adwaita-qt"
check_pkg "adwaita-qt6"
check_pkg "qt6-gtk-platformtheme"
check_pkg "qt5-gtk-platformtheme"

check_copyq_autostart

echo
if [[ $need_fix -eq 0 ]]; then
  echo "All desktop integration items are present."
else
  if [[ $FIX -eq 0 && $VERIFY_ONLY -eq 0 ]]; then
    echo "Run with --fix to install/repair the missing items."
  fi
fi

if [[ $VERIFY_ONLY -eq 1 ]]; then
  exit $need_fix
fi
