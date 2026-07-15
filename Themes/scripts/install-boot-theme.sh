#!/usr/bin/env bash
# Install or update IndianaDell Plymouth boot theme.
#
# Boot splash layers (top to bottom):
#   1. UEFI BGRT image — Dell/factory logo from /sys/firmware/acpi/bgrt/image (BIOS)
#   2. Spinner animation — from plymouth-theme-spinner (or animated Dell frames)
#   3. watermark.png — Ubuntu text logo at bottom (replaceable)
#
# Usage:
#   sudo ./install-boot-theme.sh                    # keep Dell BGRT + stock ubuntu watermark
#   sudo ./install-boot-theme.sh --watermark FILE   # custom bottom logo
#   sudo ./install-boot-theme.sh --oem FILE         # replace BGRT with custom center/background PNG
#   sudo ./install-boot-theme.sh --animated-dell    # animate Dell BGRT as center spinner (no firmware logo)
#   sudo ./install-boot-theme.sh --no-watermark     # hide ubuntu watermark
#   sudo ./install-boot-theme.sh --restore-stock    # revert to ubuntu bgrt theme
#   ./install-boot-theme.sh --stage-only [--animated-dell]   # build theme tree under boot/staging/ (no root)
#   Preview first (safe): bin/themes-preview-boot
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEME_NAME=indianadell
INSTALL_DIR="/usr/share/plymouth/themes/${THEME_NAME}"
STAGE_DIR="${ROOT}/boot/staging/${THEME_NAME}"
SPINNER_SRC="${ROOT}/boot/stock/spinner"
OVERLAY="${ROOT}/boot/overlay"
DELL_ANIM_DIR="${ROOT}/boot/generated/dell-animation"
GEN_SCRIPT="${ROOT}/scripts/generate-dell-animation.py"

WATERMARK=""
OEM_BG=""
NO_WATERMARK=0
RESTORE_STOCK=0
USE_FIRMWARE=1
ANIMATED_DELL=0
STAGE_ONLY=0

usage() {
  sed -n '2,16p' "$0"
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --watermark) WATERMARK="$2"; shift 2 ;;
    --oem) OEM_BG="$2"; USE_FIRMWARE=0; shift 2 ;;
    --animated-dell) ANIMATED_DELL=1; USE_FIRMWARE=0; shift ;;
    --no-watermark) NO_WATERMARK=1; shift ;;
    --restore-stock) RESTORE_STOCK=1; shift ;;
    --stage-only) STAGE_ONLY=1; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

if [[ "$STAGE_ONLY" -eq 1 && "$RESTORE_STOCK" -eq 1 ]]; then
  echo "ERROR: --stage-only and --restore-stock cannot be combined" >&2
  exit 1
fi

if [[ "$STAGE_ONLY" -eq 0 ]]; then
  [[ "$(id -u)" -eq 0 ]] || { echo "Run with sudo (or use --stage-only for a root-free preview tree)" >&2; exit 1; }
fi

if [[ "$RESTORE_STOCK" -eq 1 ]]; then
  echo "Restoring stock BGRT Plymouth theme"
  update-alternatives --set default.plymouth /usr/share/plymouth/themes/bgrt/bgrt.plymouth
  update-initramfs -u
  echo "Done. Reboot to see stock Dell + Ubuntu boot splash."
  exit 0
fi

[[ -d "$SPINNER_SRC" ]] || { echo "Missing $SPINNER_SRC — run Themes/scripts/extract-all.sh first" >&2; exit 1; }

if [[ "$STAGE_ONLY" -eq 1 ]]; then
  TARGET_DIR="$STAGE_DIR"
  echo "Staging Plymouth theme (no install) → $TARGET_DIR"
else
  TARGET_DIR="$INSTALL_DIR"
  echo "Installing Plymouth theme to $TARGET_DIR"
fi

mkdir -p "$TARGET_DIR" "$OVERLAY"

rsync -a --delete "$SPINNER_SRC/" "$TARGET_DIR/"
# rsync --delete may remove our .plymouth if not in spinner; always re-copy
cp -f "${ROOT}/boot/indianadell/indianadell.plymouth" "$TARGET_DIR/"

# Stock spinner ships watermark.png as a relative symlink that dangles after rsync.
# Drop it before any real file is written (also covers --no-watermark).
rm -f "$TARGET_DIR/watermark.png"

# Point ImageDir at the staged/installed tree (preview + two-step both use this)
if grep -q '^ImageDir=' "$TARGET_DIR/indianadell.plymouth"; then
  sed -i "s|^ImageDir=.*|ImageDir=${TARGET_DIR}|" "$TARGET_DIR/indianadell.plymouth"
else
  # Insert after ModuleName line if missing
  sed -i "/^ModuleName=/a ImageDir=${TARGET_DIR}" "$TARGET_DIR/indianadell.plymouth"
fi

# Patch firmware background flag in all plymouth mode sections
if [[ "$USE_FIRMWARE" -eq 1 ]]; then
  sed -i 's/^UseFirmwareBackground=.*/UseFirmwareBackground=true/g' "$TARGET_DIR/indianadell.plymouth"
  sed -i 's/^DialogClearsFirmwareBackground=.*/DialogClearsFirmwareBackground=false/' "$TARGET_DIR/indianadell.plymouth"
  rm -f "$TARGET_DIR/background.png"
else
  sed -i 's/^UseFirmwareBackground=.*/UseFirmwareBackground=false/g' "$TARGET_DIR/indianadell.plymouth"
  sed -i 's/^DialogClearsFirmwareBackground=.*/DialogClearsFirmwareBackground=true/' "$TARGET_DIR/indianadell.plymouth"
fi

# Watermark (bottom Ubuntu logo)
if [[ "$NO_WATERMARK" -eq 1 ]]; then
  echo "Watermark removed"
elif [[ -n "$WATERMARK" ]]; then
  cp -f "$WATERMARK" "$TARGET_DIR/watermark.png"
  if [[ "$STAGE_ONLY" -eq 0 ]]; then
    cp -f "$WATERMARK" "$OVERLAY/watermark.png"
  fi
  echo "Watermark: $WATERMARK"
else
  if [[ -f "$OVERLAY/watermark.png" ]]; then
    cp -f "$OVERLAY/watermark.png" "$TARGET_DIR/watermark.png"
    echo "Watermark: overlay/watermark.png"
  else
    cp -f "${ROOT}/boot/extracted/ubuntu-watermark-dark.png" "$TARGET_DIR/watermark.png"
    echo "Watermark: stock ubuntu-watermark-dark.png"
  fi
fi

# Custom OEM / background (replaces Dell BGRT when --oem used)
if [[ -n "$OEM_BG" ]]; then
  cp -f "$OEM_BG" "$TARGET_DIR/background.png"
  if [[ "$STAGE_ONLY" -eq 0 ]]; then
    cp -f "$OEM_BG" "$OVERLAY/background.png"
  fi
  echo "OEM background: $OEM_BG (firmware logo disabled)"
elif [[ -f "$OVERLAY/background.png" && "$USE_FIRMWARE" -eq 0 && "$ANIMATED_DELL" -eq 0 ]]; then
  cp -f "$OVERLAY/background.png" "$TARGET_DIR/background.png"
  echo "OEM background: overlay/background.png"
fi

# Animated Dell logo as Plymouth throbber/animation (center spinner)
if [[ "$ANIMATED_DELL" -eq 1 ]]; then
  if [[ ! -f "$DELL_ANIM_DIR/animation-0001.png" ]]; then
    echo "Generating Dell animation frames..."
    if [[ "$(id -u)" -eq 0 && -n "${SUDO_USER:-}" ]]; then
      sudo -u "$SUDO_USER" python3 "$GEN_SCRIPT"
    else
      python3 "$GEN_SCRIPT"
    fi
  fi
  [[ -f "$DELL_ANIM_DIR/animation-0001.png" ]] || {
    echo "ERROR: missing frames in $DELL_ANIM_DIR — run: python3 Themes/scripts/generate-dell-animation.py" >&2
    exit 1
  }
  echo "Installing animated Dell frames from $DELL_ANIM_DIR"
  cp -f "$DELL_ANIM_DIR"/animation-*.png "$TARGET_DIR/"
  cp -f "$DELL_ANIM_DIR"/throbber-*.png "$TARGET_DIR/"
  if [[ -f "$DELL_ANIM_DIR/bgrt-fallback.png" ]]; then
    cp -f "$DELL_ANIM_DIR/bgrt-fallback.png" "$TARGET_DIR/bgrt-fallback.png"
  fi
  # Solid black background; logo animation is the centerpiece
  if [[ -f "$DELL_ANIM_DIR/background.png" ]]; then
    cp -f "$DELL_ANIM_DIR/background.png" "$TARGET_DIR/background.png"
  else
    python3 -c "from PIL import Image; Image.new('RGB',(1920,1080),(0,0,0)).save('$TARGET_DIR/background.png')"
  fi
  # Center the tall scene (logo + wizard + text); stock spinner sits lower at .7
  sed -i 's/^VerticalAlignment=.*/VerticalAlignment=.5/' "$TARGET_DIR/indianadell.plymouth"
  sed -i 's/^HorizontalAlignment=.*/HorizontalAlignment=.5/' "$TARGET_DIR/indianadell.plymouth"
  # Keep password dialog a bit lower so it does not cover the logo
  sed -i 's/^DialogVerticalAlignment=.*/DialogVerticalAlignment=.72/' "$TARGET_DIR/indianadell.plymouth"
  # Scene already has bottom wizard + ᏃᏫᏍ — drop Ubuntu watermark unless user forced one
  if [[ "$NO_WATERMARK" -eq 0 && -z "$WATERMARK" && ! -f "$OVERLAY/watermark.png" ]]; then
    rm -f "$TARGET_DIR/watermark.png"
    echo "Watermark omitted (wizard + magic text are part of the animation)"
  fi
  echo "Animated Dell + wizard scene ready (firmware logo disabled)"
fi

if [[ "$STAGE_ONLY" -eq 1 ]]; then
  echo "Staged at: $TARGET_DIR"
  echo "Preview: bin/themes-preview-boot --theme $TARGET_DIR"
  echo "(No system changes — no update-initramfs, no default.plymouth switch.)"
  exit 0
fi

update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth \
  "$TARGET_DIR/indianadell.plymouth" 120
update-alternatives --set default.plymouth "$TARGET_DIR/indianadell.plymouth"

update-initramfs -u
echo "Boot theme installed. Reboot to apply."
if [[ "$ANIMATED_DELL" -eq 1 ]]; then
  echo "Safe preview first: bin/themes-preview-boot --animated-dell"
  echo "Preview GIF: $DELL_ANIM_DIR/preview.gif"
  echo "Regenerate frames: python3 $GEN_SCRIPT"
else
  echo "Drop custom assets in $OVERLAY/ then re-run this script."
  echo "Safe preview: bin/themes-preview-boot"
fi
