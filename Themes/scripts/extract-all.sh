#!/usr/bin/env bash
# Snapshot boot/login/desktop themes from installed apt packages + extract boot logos.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

log "Extract UEFI BGRT OEM logo (Dell) and Ubuntu Plymouth watermark"
mkdir -p "$ROOT/boot/extracted" "$ROOT/boot/stock"
if [[ -r /sys/firmware/acpi/bgrt/image ]]; then
  cat /sys/firmware/acpi/bgrt/image > "$ROOT/boot/extracted/bgrt-firmware-oem.bmp"
  if command -v ffmpeg >/dev/null; then
    ffmpeg -y -loglevel error -i "$ROOT/boot/extracted/bgrt-firmware-oem.bmp" \
      -update 1 -frames:v 1 "$ROOT/boot/extracted/bgrt-firmware-oem.png"
  fi
else
  log "WARN: /sys/firmware/acpi/bgrt/image not readable — using bgrt-fallback.png"
  cp "$ROOT/boot/stock/spinner/bgrt-fallback.png" "$ROOT/boot/extracted/bgrt-firmware-oem.png" 2>/dev/null || true
fi
cp -f /usr/share/pixmaps/ubuntu-logo-text-dark.png "$ROOT/boot/extracted/ubuntu-watermark-dark.png"
cp -f /usr/share/pixmaps/ubuntu-logo-text.png "$ROOT/boot/extracted/ubuntu-watermark-light.png"

log "Refresh stock Plymouth mirrors"
rm -rf "$ROOT/boot/stock/bgrt" "$ROOT/boot/stock/spinner"
cp -a /usr/share/plymouth/themes/bgrt "$ROOT/boot/stock/"
cp -a /usr/share/plymouth/themes/spinner "$ROOT/boot/stock/"
cp -f /usr/share/pixmaps/ubuntu-logo-text-dark.png "$ROOT/boot/stock/spinner-watermark.png"

write_pkg_list() {
  local dest="$1"; shift
  mkdir -p "$(dirname "$dest")"
  printf '%s\n' "$@" >"$dest"
}

write_pkg_list "$ROOT/boot/apt-packages.txt" \
  plymouth libplymouth5 plymouth-label plymouth-theme-spinner plymouth-theme-ubuntu-text

write_pkg_list "$ROOT/login/apt-packages.txt" \
  gdm3 libgdm1 gnome-shell gnome-shell-common yaru-theme-gnome-shell

write_pkg_list "$ROOT/desktop/apt-packages.txt" \
  yaru-theme-gtk yaru-theme-icon yaru-theme-gnome-shell yaru-theme-sound gnome-shell ubuntu-desktop-minimal

log "Mirror apt package theme files (may take a minute)"
for pkg in plymouth plymouth-theme-spinner plymouth-theme-ubuntu-text; do
  "$SCRIPT_DIR/copy-apt-package.sh" "$pkg" "$ROOT/boot/mirror/${pkg}"
done

for pkg in gdm3 gnome-shell yaru-theme-gnome-shell; do
  "$SCRIPT_DIR/copy-apt-package.sh" "$pkg" "$ROOT/login/mirror/${pkg}"
done

for pkg in yaru-theme-gtk yaru-theme-icon yaru-theme-gnome-shell yaru-theme-sound; do
  "$SCRIPT_DIR/copy-apt-package.sh" "$pkg" "$ROOT/desktop/mirror/${pkg}"
done

log "Save login (GDM) greeter gsettings snapshot"
mkdir -p "$ROOT/login/extracted"
{
  echo "# User session dark-mode snapshot ($(date -Iseconds))"
  gsettings list-recursively org.gnome.desktop.interface 2>/dev/null | grep -E 'color-scheme|gtk-theme|icon-theme' || true
  gsettings list-recursively org.gnome.shell.ubuntu 2>/dev/null || true
} >"$ROOT/login/extracted/user-gsettings-dark.txt"

if command -v dconf >/dev/null; then
  dconf dump /org/gnome/desktop/interface/ >"$ROOT/login/extracted/dconf-interface.txt" 2>/dev/null || true
fi

log "Done. Boot logos in $ROOT/boot/extracted/"
ls -lh "$ROOT/boot/extracted/"