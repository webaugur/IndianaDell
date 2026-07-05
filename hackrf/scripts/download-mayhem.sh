#!/usr/bin/env bash
set -euo pipefail
MAYHEM_VER="${MAYHEM_VER:-v2.4.0}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="${ROOT}/releases"
URL="https://github.com/portapack-mayhem/mayhem-firmware/releases/download/${MAYHEM_VER}"

mkdir -p "$BASE"
files=(
  "FIRMWARE_mayhem_${MAYHEM_VER}.zip"
  "COPY_TO_SDCARD_hackrf_mayhem_${MAYHEM_VER}-no-world-map.zip"
  "OCI_hackrf_mayhem_${MAYHEM_VER}.ppfw.tar"
)
for f in "${files[@]}"; do
  dest="$BASE/$f"
  if [[ -f "$dest" ]]; then
    echo "skip $f"
  else
    curl -fL --retry 3 -o "$dest" "$URL/$f"
  fi
done
ls -lh "$BASE"