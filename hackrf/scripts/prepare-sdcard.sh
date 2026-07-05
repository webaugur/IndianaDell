#!/usr/bin/env bash
# Extract Mayhem SD-card payload for PortaPack microSD.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SD_ZIP="${ROOT}/releases/COPY_TO_SDCARD_hackrf_mayhem_v2.4.0-no-world-map.zip"
OUT="${ROOT}/sd-card/mayhem-v2.4.0"

if [[ ! -f "$SD_ZIP" ]]; then
  echo "Missing $SD_ZIP" >&2
  exit 1
fi

mkdir -p "$OUT"
rm -rf "${OUT:?}/"*
unzip -o "$SD_ZIP" -d "$OUT"

echo "SD card files ready at: $OUT"
echo "Copy everything inside to the root of your PortaPack microSD (FAT32)."
du -sh "$OUT"
find "$OUT" -maxdepth 2 | head -30