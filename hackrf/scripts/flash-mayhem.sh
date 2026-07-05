#!/usr/bin/env bash
# Flash PortaPack Mayhem to HackRF One (USB). Requires HackRF in DFU or normal mode per release notes.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FW_ZIP="${ROOT}/releases/FIRMWARE_mayhem_v2.4.0.zip"
WORK="${ROOT}/firmware/mayhem-flash"

if ! command -v hackrf_spiflash >/dev/null; then
  echo "hackrf_spiflash not found; install package: hackrf" >&2
  exit 1
fi
if [[ ! -f "$FW_ZIP" ]]; then
  echo "Missing $FW_ZIP — run scripts/download-mayhem.sh first" >&2
  exit 1
fi

mkdir -p "$WORK"
rm -rf "${WORK:?}/"*
unzip -o "$FW_ZIP" -d "$WORK"

echo "Firmware extracted to $WORK"
echo "Contents:"
find "$WORK" -maxdepth 2 -type f | sort

if hackrf_info 2>/dev/null | grep -q 'Found HackRF'; then
  echo
  echo "HackRF detected. Follow Mayhem release instructions to flash."
  echo "Typical flow (see mayhem-firmware releases page):"
  echo "  1. Hold DFU, connect USB, or use hackrf_spiflash from release bundle"
  echo "  2. Copy SD card assets separately with scripts/prepare-sdcard.sh"
else
  echo
  echo "No HackRF attached. Plug in device, then re-run or flash manually from $WORK"
fi