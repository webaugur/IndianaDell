#!/usr/bin/env bash
# Talk to the Uno IR blaster over USB serial (115200).
# Waits for READY / OK / ERR on the fd — does not sleep-and-hope.
set -euo pipefail

PORT="${IR_PORT:-}"
CMD=""

usage() {
  cat <<'EOF'
indiana-ir-send detect
indiana-ir-send hdmi1|hdmi2|hdmi3|hdmi4|source
indiana-ir-send poweron|poweroff|mute|unmute|volup|voldown|home
indiana-ir-send up|down|left|right|ok|dot
indiana-ir-send 0-9
indiana-ir-send send E0E043BC
indiana-ir-send --port /dev/ttyACM0 hdmi2
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --port) PORT=${2:?}; shift 2 ;;
    -h|--help) usage ;;
    detect|hdmi1|hdmi2|hdmi3|hdmi4|source|send|help|poweron|poweroff|mute|unmute|volup|voldown|home|up|down|left|right|ok|dot|[0-9])
      CMD=$1
      shift
      break
      ;;
    *) usage ;;
  esac
done

list_ttys() {
  local d
  shopt -s nullglob
  for d in /dev/ttyACM* /dev/ttyUSB*; do
    [[ -e "$d" ]] || continue
    printf '%s' "$d"
    if command -v udevadm >/dev/null; then
      local vend prod
      vend=$(udevadm info -q property -n "$d" 2>/dev/null | awk -F= '/ID_VENDOR_ID=/{print $2}')
      prod=$(udevadm info -q property -n "$d" 2>/dev/null | awk -F= '/ID_MODEL_ID=/{print $2}')
      [[ -n "$vend" ]] && printf '  usb:%s:%s' "$vend" "$prod"
    fi
    printf '\n'
  done
}

# Read lines until one matches OK*|ERR*|READY or deadline (protocol timeout).
read_reply() {
  local fd=$1 deadline=$2
  local line now
  while true; do
    now=$(date +%s)
    if (( now >= deadline )); then
      echo "ERR timeout waiting for Arduino" >&2
      return 1
    fi
    if IFS= read -r -t 1 line <&"$fd"; then
      line=${line%$'\r'}
      printf '%s\n' "$line"
      case "$line" in
        OK*|ERR*|READY) return 0 ;;
      esac
    fi
  done
}

open_and_wait_ready() {
  local port=$1
  if [[ ! -e "$port" ]]; then
    echo "ERR no such port: $port" >&2
    return 1
  fi
  if [[ ! -r "$port" || ! -w "$port" ]]; then
    echo "ERR cannot open $port (add user to dialout, then log out)" >&2
    return 1
  fi
  # Opening the port resets the Uno (DTR). stty then wait for READY.
  stty -F "$port" 115200 cs8 -cstopb -parenb raw -echo
  exec 3<>"$port"
  local deadline=$(( $(date +%s) + 8 ))
  local line
  line=$(read_reply 3 "$deadline") || { exec 3>&-; return 1; }
  if [[ "$line" != READY ]]; then
    # Some firmwares already up; still usable.
    :
  fi
}

cmd_line() {
  case "$1" in
    hdmi1) echo HDMI1 ;;
    hdmi2) echo HDMI2 ;;
    hdmi3) echo HDMI3 ;;
    hdmi4) echo HDMI4 ;;
    source) echo SOURCE ;;
    poweron) echo POWERON ;;
    poweroff) echo POWEROFF ;;
    mute) echo MUTE ;;
    unmute) echo UNMUTE ;;
    volup) echo VOLUP ;;
    voldown) echo VOLDOWN ;;
    home) echo HOME ;;
    up) echo UP ;;
    down) echo DOWN ;;
    left) echo LEFT ;;
    right) echo RIGHT ;;
    ok) echo OK ;;
    dot) echo DOT ;;
    [0-9]) echo "$1" ;;
    help) echo HELP ;;
    send)
      local hex=${2:-}
      [[ -n "$hex" ]] || { echo "ERR send needs hex" >&2; return 2; }
      echo "SEND ${hex}"
      ;;
    *) echo "ERR bad cmd" >&2; return 2 ;;
  esac
}

pick_port() {
  if [[ -n "$PORT" ]]; then
    printf '%s\n' "$PORT"
    return 0
  fi
  local d
  shopt -s nullglob
  for d in /dev/ttyACM* /dev/ttyUSB*; do
    [[ -e "$d" ]] || continue
    printf '%s\n' "$d"
    return 0
  done
  echo "ERR no ttyACM/ttyUSB — plug in the Uno" >&2
  return 1
}

if [[ -z "${CMD:-}" ]]; then
  usage
fi

if [[ "$CMD" == detect ]]; then
  echo "=== serial ports ==="
  list_ttys
  if ! groups | grep -qw dialout; then
    echo "WARN: this user is not in group dialout"
  fi
  exit 0
fi

PORT=$(pick_port)
open_and_wait_ready "$PORT"
line=$(cmd_line "$CMD" "${1:-}")
printf '%s\n' "$line" >&3
deadline=$(( $(date +%s) + 5 ))
# drain READY then the OK from our command
reply=$(read_reply 3 "$deadline") || { exec 3>&-; exit 1; }
if [[ "$reply" == READY ]]; then
  reply=$(read_reply 3 "$deadline") || { exec 3>&-; exit 1; }
fi
exec 3>&-
printf '%s\n' "$reply"
case "$reply" in
  OK*) exit 0 ;;
  *) exit 1 ;;
esac
