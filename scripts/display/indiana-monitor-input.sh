#!/usr/bin/env bash
# Ask the attached display to select this PC's input (DDC/CI VCP 0x60).
# FirePros are mini-DP: no HDMI-CEC. If I2C 0x37 is silent, the set cannot switch.
set -euo pipefail

TAG=indiana-monitor-input
DDCUTIL=${DDCUTIL:-ddcutil}

log() { printf '%s\n' "$*" >&2; }

need_ddcutil() {
  command -v "$DDCUTIL" >/dev/null 2>&1 || {
    log "ERROR: ddcutil is not installed (apt package ddcutil)"
    exit 1
  }
}

# ddcutil needs the i2c device. Prefer the i2c group; sudo only if needed.
ddc() {
  if [[ -r /dev/i2c-7 || -r /dev/i2c-0 ]]; then
    "$DDCUTIL" "$@"
    return
  fi
  if [[ "$(id -u)" -eq 0 ]]; then
    "$DDCUTIL" "$@"
    return
  fi
  if command -v sudo >/dev/null 2>&1; then
    sudo "$DDCUTIL" "$@"
    return
  fi
  log "ERROR: cannot read /dev/i2c-* (add this user to group i2c, then log out)"
  exit 1
}

# MCCS input source (VCP 60) names we accept on the command line.
input_code() {
  local n
  n=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  case "$n" in
    0x[0-9a-f][0-9a-f]|[0-9a-f][0-9a-f]) printf '%s' "${n#0x}" ;;
    vga|vga1) echo 01 ;;
    dvi|dvi1) echo 03 ;;
    dp|dp1|displayport|displayport1|pc) echo 0f ;;
    dp2|displayport2) echo 10 ;;
    hdmi|hdmi1) echo 11 ;;
    hdmi2) echo 12 ;;
    *)
      log "ERROR: unknown input '$1' (try detect, list, or 0x0f / dp / hdmi1)"
      exit 2
      ;;
  esac
}

cmd_detect() {
  need_ddcutil
  echo "=== DRM connected outputs ==="
  local s
  for s in /sys/class/drm/card*-*-*/status; do
    [[ -f "$s" ]] || continue
    [[ "$(cat "$s")" == connected ]] || continue
    printf '  %s\n' "$(basename "$(dirname "$s")")"
  done
  echo
  echo "=== CEC ==="
  if compgen -G '/dev/cec*' >/dev/null; then
    ls -l /dev/cec*
  else
    echo "  no /dev/cec (HDMI-CEC not exposed on this GPU path)"
  fi
  echo
  echo "=== ddcutil detect ==="
  # Exit 0 even when ddcutil finds no DDC/CI — we still printed the facts.
  if ! ddc detect; then
    log "ddcutil detect failed (see above)"
  fi
}

has_ddc() {
  ddc detect 2>/dev/null | grep -q '^Display '
}

cmd_list() {
  need_ddcutil
  if ! has_ddc; then
    log "ERROR: no DDC/CI display. This Samsung on card2-DP-4 does not answer I2C 0x37."
    log "If the set has an OSD option named DDC/CI, enable it and re-run detect."
    exit 3
  fi
  ddc capabilities
  echo
  ddc getvcp 60 || true
}

cmd_set() {
  need_ddcutil
  local code
  code=$(input_code "${1:?set requires an input name or hex code}")
  if ! has_ddc; then
    log "ERROR: cannot set input — monitor does not implement DDC/CI (I2C 0x37 silent)."
    exit 3
  fi
  ddc setvcp 60 "0x${code}"
  ddc getvcp 60 || true
}

cmd_grab() {
  # "This PC" on Tower5810 is the W5100 DisplayPort. MCCS DisplayPort-1 is 0x0F.
  # If DDC ever comes up, that is the code to request. Do not invent CEC here.
  cmd_set dp
}

usage() {
  cat <<'EOF'
indiana-monitor-input detect
indiana-monitor-input grab
indiana-monitor-input list
indiana-monitor-input set <code|name>

Names: dp / pc (0x0f DisplayPort-1), hdmi1 (0x11), hdmi2, vga, dvi
DDC/CI only. No /dev/cec on this GPU. Exit 3 if the monitor does not answer I2C 0x37.
EOF
  exit 2
}

cmd=${1:-}
shift || true
case "$cmd" in
  detect) cmd_detect ;;
  list) cmd_list ;;
  grab) cmd_grab ;;
  set) cmd_set "${1:-}" ;;
  -h|--help|"") usage ;;
  *) log "Unknown command: $cmd"; usage ;;
esac
