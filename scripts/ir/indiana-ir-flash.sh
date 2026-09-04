#!/usr/bin/env bash
# Compile and upload tools/ir-blaster with arduino-cli (no IDE).
set -euo pipefail

HERE=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
ROOT="$(cd "$HERE/../.." && pwd)"
SKETCH="$ROOT/tools/ir-blaster"
FQBN=arduino:avr:uno
PORT=""
COMPILE_ONLY=0

usage() {
  cat <<'EOF'
indiana-ir-flash
indiana-ir-flash --port /dev/ttyACM0
indiana-ir-flash --compile-only
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --port) PORT=${2:?}; shift 2 ;;
    --compile-only) COMPILE_ONLY=1; shift ;;
    -h|--help) usage ;;
    *) usage ;;
  esac
done

if ! command -v arduino-cli >/dev/null 2>&1; then
  echo "ERR: arduino-cli not on PATH. Install: sudo apt install arduino-cli" >&2
  exit 1
fi

if [[ ! -f "$SKETCH/ir-blaster.ino" ]]; then
  echo "ERR: sketch missing: $SKETCH/ir-blaster.ino" >&2
  exit 1
fi

if ! arduino-cli core list 2>/dev/null | grep -q '^arduino:avr'; then
  echo "installing Arduino AVR core into ~/.arduino15"
  arduino-cli core update-index
  arduino-cli core install arduino:avr
fi

echo "compile $SKETCH ($FQBN)"
arduino-cli compile --fqbn "$FQBN" "$SKETCH"

if [[ $COMPILE_ONLY -eq 1 ]]; then
  echo "compile-only: skip upload"
  exit 0
fi

if [[ -z "$PORT" ]]; then
  shopt -s nullglob
  for d in /dev/ttyACM* /dev/ttyUSB*; do
    [[ -e "$d" ]] || continue
    PORT=$d
    break
  done
fi

if [[ -z "$PORT" ]]; then
  echo "ERR: no Uno serial port. Plug USB or pass --port. Compile succeeded." >&2
  exit 1
fi

echo "upload $PORT"
arduino-cli upload --fqbn "$FQBN" --port "$PORT" "$SKETCH"

# Prove firmware is up: wait for READY (DTR reset), then HELP.
if [[ -x "$ROOT/bin/indiana-ir-send" ]]; then
  "$ROOT/bin/indiana-ir-send" --port "$PORT" help
else
  echo "WARN: indiana-ir-send not found; skip serial check"
fi
