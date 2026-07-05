#!/usr/bin/env bash
# B1GMB42: stress all 3 amdgpu GPUs (headless-safe via vkcube per gpu_number).
set -euo pipefail

DURATION="${1:-60}"
MODE="${2:-vkcube}"

declare -A GPUS=(
  [0]="W5000 card1 (01:00.0)"
  [1]="W5100 card2 (02:00.0)"
  [2]="W5000 card3 (03:00.0)"
)

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

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
read_gpu_stats

pids=()
for idx in 0 1 2; do
  frames=$((DURATION * 60))
  log "Launching ${MODE} on GPU ${idx} (${GPUS[$idx]})"
  case "$MODE" in
    vkcube)
      timeout "${DURATION}" vkcube --gpu_number "${idx}" --c "${frames}" --wsi wayland \
        >/tmp/gpu-stress-${idx}.log 2>&1 &
      ;;
    egltri)
      rd="renderD$((128 + idx))"
      timeout "${DURATION}" env EGL_DRM_DEVICE_FILE="/dev/dri/${rd}" egltri_x11 \
        >/tmp/gpu-stress-${idx}.log 2>&1 &
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
    log "GPU ${i} error — see /tmp/gpu-stress-${i}.log"
    fail=1
  fi
done
read_gpu_stats
exit "$fail"