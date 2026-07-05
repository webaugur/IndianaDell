#!/usr/bin/env bash
# Install or update IndianaDell Plymouth boot theme.
#
# Boot splash layers (top to bottom):
#   1. UEFI BGRT image — Dell/factory logo from /sys/firmware/acpi/bgrt/image (BIOS)
#   2. Spinner animation — from plymouth-theme-spinner
#   3. watermark.png — Ubuntu text logo at bottom (replaceable)
#
# Usage:
#   sudo ./install-boot-theme.sh                    # keep Dell BGRT + stock ubuntu watermark
#   sudo ./install-boot-theme.sh --watermark FILE   # custom bottom logo
#   sudo ./install-boot-theme.sh --oem FILE         # replace BGRT with custom center/background PNG
#   sudo ./install-boot-theme.sh --no-watermark     # hide ubuntu watermark
#   sudo ./install-boot-theme.sh --restore-stock    # revert to ubuntu bgrt theme
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEME_NAME=indianadell
INSTALL_DIR="/usr/share/plymouth/themes/${THEME_NAME}"
SPINNER_SRC="${ROOT}/boot/stock/spinner"
OVERLAY="${ROOT}/boot/overlay"

WATERMARK=""
OEM_BG=""
NO_WATERMARK=0
RESTORE_STOCK=0
USE_FIRMWARE=1

usage() {
  sed -n '2,12p' "$0"
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --watermark) WATERMARK="$2"; shift 2 ;;
    --oem) OEM_BG="$2"; USE_FIRMWARE=0; shift 2 ;;
    --no-watermark) NO_WATERMARK=1; shift ;;
    --restore-stock) RESTORE_STOCK=1; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

[[ "$(id -u)" -eq 0 ]] || { echo "Run with sudo" >&2; exit 1; }

if [[ "$RESTORE_STOCK" -eq 1 ]]; then
  echo "Restoring stock BGRT Plymouth theme"
  update-alternatives --set default.plymouth /usr/share/plymouth/themes/bgrt/bgrt.plymouth
  update-initramfs -u
  echo "Done. Reboot to see stock Dell + Ubuntu boot splash."
  exit 0
fi

[[ -d "$SPINNER_SRC" ]] || { echo "Missing $SPINNER_SRC — run Themes/scripts/extract-all.sh first" >&2; exit 1; }

mkdir -p "$INSTALL_DIR" "$OVERLAY"

echo "Installing Plymouth theme to $INSTALL_DIR"
rsync -a --delete "$SPINNER_SRC/" "$INSTALL_DIR/"
cp -f "${ROOT}/boot/indianadell/indianadell.plymouth" "$INSTALL_DIR/"

# Patch firmware background flag in all plymouth mode sections
if [[ "$USE_FIRMWARE" -eq 1 ]]; then
  sed -i 's/^UseFirmwareBackground=.*/UseFirmwareBackground=true/g' "$INSTALL_DIR/indianadell.plymouth"
  sed -i 's/^DialogClearsFirmwareBackground=.*/DialogClearsFirmwareBackground=false/' "$INSTALL_DIR/indianadell.plymouth"
  rm -f "$INSTALL_DIR/background.png"
else
  sed -i 's/^UseFirmwareBackground=.*/UseFirmwareBackground=false/g' "$INSTALL_DIR/indianadell.plymouth"
  sed -i 's/^DialogClearsFirmwareBackground=.*/DialogClearsFirmwareBackground=true/' "$INSTALL_DIR/indianadell.plymouth"
fi

# Watermark (bottom Ubuntu logo)
if [[ "$NO_WATERMARK" -eq 1 ]]; then
  rm -f "$INSTALL_DIR/watermark.png"
  echo "Watermark removed"
elif [[ -n "$WATERMARK" ]]; then
  cp -f "$WATERMARK" "$INSTALL_DIR/watermark.png"
  cp -f "$WATERMARK" "$OVERLAY/watermark.png"
  echo "Watermark: $WATERMARK"
else
  if [[ -f "$OVERLAY/watermark.png" ]]; then
    cp -f "$OVERLAY/watermark.png" "$INSTALL_DIR/watermark.png"
    echo "Watermark: overlay/watermark.png"
  else
    cp -f "${ROOT}/boot/extracted/ubuntu-watermark-dark.png" "$INSTALL_DIR/watermark.png"
    echo "Watermark: stock ubuntu-watermark-dark.png"
  fi
fi

# Custom OEM / background (replaces Dell BGRT when --oem used)
if [[ -n "$OEM_BG" ]]; then
  cp -f "$OEM_BG" "$INSTALL_DIR/background.png"
  cp -f "$OEM_BG" "$OVERLAY/background.png"
  echo "OEM background: $OEM_BG (firmware logo disabled)"
elif [[ -f "$OVERLAY/background.png" && "$USE_FIRMWARE" -eq 0 ]]; then
  cp -f "$OVERLAY/background.png" "$INSTALL_DIR/background.png"
  echo "OEM background: overlay/background.png"
fi

update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth \
  "$INSTALL_DIR/indianadell.plymouth" 120
update-alternatives --set default.plymouth "$INSTALL_DIR/indianadell.plymouth"

update-initramfs -u
echo "Boot theme installed. Reboot to apply."
echo "Drop custom assets in $OVERLAY/ then re-run this script."