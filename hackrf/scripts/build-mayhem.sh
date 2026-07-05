#!/usr/bin/env bash
# Build PortaPack Mayhem firmware from source (repos/mayhem-firmware).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${ROOT}/repos/mayhem-firmware"
BUILD="${SRC}/build"
OUT="${ROOT}/firmware/mayhem-built"

for cmd in cmake make arm-none-eabi-gcc; do
  command -v "$cmd" >/dev/null || { echo "Missing $cmd" >&2; exit 1; }
done
[[ -d "$SRC" ]] || { echo "Clone mayhem-firmware first" >&2; exit 1; }

if [[ ! -f "$SRC/hackrf/firmware/CMakeLists.txt" ]]; then
  echo "Initializing git submodules..."
  git -C "$SRC" submodule update --init --recursive
fi

mkdir -p "$BUILD" "$OUT"
cd "$BUILD"
cmake ..
make -j"$(nproc)" firmware
cp -v "${SRC}"/firmware/*.bin "$OUT/" 2>/dev/null || cp -v build/firmware/*.bin "$OUT/" 2>/dev/null || true
echo "Built firmware in $OUT"
ls -la "$OUT"