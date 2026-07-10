#!/usr/bin/env bash
# Pin all amdgpu cards to max DPM clocks (desktop workstation).
# Installed to /usr/local/sbin by etc/apply.sh; also invoked from udev.
#
# Sysfs:
#   power_dpm_force_performance_level = high   (modern clock force)
#   power_dpm_state                   = performance  (legacy DPM policy)
set -euo pipefail

log() { printf 'amdgpu-dpm: %s\n' "$*"; }

set_one() {
  local dev=$1
  local vendor level_file state_file

  vendor=$(cat "${dev}/vendor" 2>/dev/null || true)
  [[ "$vendor" == "0x1002" ]] || return 0

  level_file="${dev}/power_dpm_force_performance_level"
  state_file="${dev}/power_dpm_state"

  if [[ -w "$level_file" ]]; then
    printf 'high\n' >"$level_file" || log "WARN: could not set high on $level_file"
  fi
  if [[ -w "$state_file" ]]; then
    printf 'performance\n' >"$state_file" || log "WARN: could not set performance on $state_file"
  fi
}

shopt -s nullglob
for card in /sys/class/drm/card[0-9]*; do
  # Skip connectors (card1-DP-1) — only top-level cardN
  [[ "$(basename "$card")" == card[0-9] ]] || [[ "$(basename "$card")" == card[0-9][0-9] ]] || continue
  [[ -d "${card}/device" ]] || continue
  set_one "${card}/device"
done

# Optional summary when run interactively (udev has no TTY)
if [[ -t 1 ]]; then
  for card in /sys/class/drm/card[0-9]*; do
    base=$(basename "$card")
    [[ "$base" == card[0-9] || "$base" == card[0-9][0-9] ]] || continue
    dev="${card}/device"
    [[ -f "${dev}/power_dpm_force_performance_level" ]] || continue
    printf '  %s: level=%s state=%s\n' \
      "$base" \
      "$(cat "${dev}/power_dpm_force_performance_level" 2>/dev/null || echo '?')" \
      "$(cat "${dev}/power_dpm_state" 2>/dev/null || echo '?')"
  done
fi
