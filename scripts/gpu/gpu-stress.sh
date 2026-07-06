#!/usr/bin/env bash
# B1GMB42: stress all 3 amdgpu GPUs (vkcube per gpu_number; uses display when available).
set -euo pipefail

DURATION="${1:-60}"
MODE="${2:-vkcube}"
LOG_DIR="${GPU_STRESS_LOG_DIR:-${TMPDIR:-/tmp}/gpu-stress-${EUID:-0}}"
mkdir -p "${LOG_DIR}"
VK_WSI="${GPU_STRESS_WSI:-}"

declare -A GPUS=(
  [0]="W5000 card1 (01:00.0)"
  [1]="W5100 card2 (02:00.0)"
  [2]="W5000 card3 (03:00.0)"
)

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

setup_display_env() {
  local gui_user uid runtime

  if [[ -n "${VK_WSI}" ]]; then
    log "Using GPU_STRESS_WSI=${VK_WSI}"
    return 0
  fi

  if [[ -n "${WAYLAND_DISPLAY:-}" && -n "${XDG_RUNTIME_DIR:-}" && -S "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}" ]]; then
    VK_WSI=wayland
    log "Display: wayland (${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY})"
    return 0
  fi

  gui_user="$(loginctl list-sessions --no-legend 2>/dev/null | awk '$3 != "-" && $2 ~ /^[0-9]+$/ {print $3; exit}')"
  if [[ -z "${gui_user}" ]]; then
    gui_user="$(who 2>/dev/null | awk '/\(:[0-9]+\)/ {print $1; exit}')"
  fi
  if [[ -n "${gui_user}" && "${gui_user}" != "root" ]]; then
    uid="$(id -u "${gui_user}")"
    runtime="/run/user/${uid}"
    if [[ -d "${runtime}" ]]; then
      export XDG_RUNTIME_DIR="${runtime}"
      export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
      export DISPLAY="${DISPLAY:-:0}"
      if [[ -S "${runtime}/${WAYLAND_DISPLAY}" ]]; then
        VK_WSI=wayland
        log "Display: wayland as ${gui_user} (${runtime}/${WAYLAND_DISPLAY})"
        return 0
      fi
    fi
  fi

  export DISPLAY="${DISPLAY:-:0}"
  if [[ -S /tmp/.X11-unix/X0 || -S /tmp/.X11-unix/X1 ]]; then
    VK_WSI=xcb
    log "Display: X11 (${DISPLAY}, wsi=xcb)"
    return 0
  fi

  log "No graphical session — set XDG_RUNTIME_DIR/WAYLAND_DISPLAY or DISPLAY"
  return 1
}

read_gpu_stats() {
  for card in card1 card2 card3; do
    busy=$(cat "/sys/class/drm/${card}/device/gpu_busy_percent" 2>/dev/null || echo na)
    temp=$(cat /sys/class/drm/${card}/device/hwmon/hwmon*/temp1_input 2>/dev/null | head -1 || echo na)
    [[ "$temp" =~ ^[0-9]+$ ]] && temp="$((temp / 1000))C"
    printf '  %s: busy=%s%% temp=%s\n' "$card" "$busy" "$temp"
  done
}

case "$MODE" in vkcube|egltri) ;; *)
  echo "Usage: $0 [seconds] [vkcube|egltri]" >&2; exit 2 ;; esac

log "Starting ${DURATION}s GPU stress (${MODE})"
if [[ "${MODE}" == vkcube ]]; then
  setup_display_env || exit 1
fi
read_gpu_stats

pids=()
for idx in 0 1 2; do
  frames=$((DURATION * 60))
  log_file="${LOG_DIR}/gpu-stress-${idx}.log"
  log "Launching ${MODE} on GPU ${idx} (${GPUS[$idx]})"
  case "$MODE" in
    vkcube)
      timeout "${DURATION}" vkcube --gpu_number "${idx}" --c "${frames}" --wsi "${VK_WSI}" \
        >"${log_file}" 2>&1 &
      ;;
    egltri)
      rd="renderD$((128 + idx))"
      timeout "${DURATION}" env EGL_DRM_DEVICE_FILE="/dev/dri/${rd}" egltri_x11 \
        >"${log_file}" 2>&1 &
      ;;
  esac
  pids+=($!)
done

for ((t=10; t<=DURATION; t+=10)); do
  sleep 10
  log "--- ${t}s ---"
  read_gpu_stats
done

fail=0
for i in "${!pids[@]}"; do
  if wait "${pids[$i]}"; then
    log "GPU ${i} OK"
  elif [[ $? -eq 124 ]]; then
    log "GPU ${i} finished (timeout)"
  else
    log "GPU ${i} error — see ${LOG_DIR}/gpu-stress-${i}.log"
    fail=1
  fi
done
read_gpu_stats
exit "$fail"