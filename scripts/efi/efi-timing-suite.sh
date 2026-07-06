#!/usr/bin/env bash
# EFI / BIOS timing baseline for Tower5810 — run before and after BIOS changes.
# Writes a dated report suitable for A/B comparison.
#
# Usage:
#   sudo bin/efi-timing-suite
#   sudo bin/efi-timing-suite -o ~/B1GMB42.timing
#   SKIP_LOAD=1 sudo bin/efi-timing-suite    # skip stress-ng load phase
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT=""
SKIP_LOAD="${SKIP_LOAD:-0}"
LOAD_SEC="${LOAD_SEC:-20}"
TURBOSTAT_ITER="${TURBOSTAT_ITER:-10}"

log() { printf '%s\n' "$*"; }
section() { printf '\n=== %s ===\n' "$*"; }

usage() {
  cat <<EOF
Usage: sudo $0 [-o FILE]

Options:
  -o FILE          Output report (default: ${ROOT}/B1GMB42.timing)
  SKIP_LOAD=1      Skip CPU load phase (stress-ng)
  LOAD_SEC=N       Load duration seconds (default: 20)
  TURBOSTAT_ITER=N turbostat samples per phase (default: 10)

Install optional tools for fuller report:
  apt install stress-ng mbw fio linux-tools-$(uname -r)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) OUT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "$OUT" ]] || OUT="${ROOT}/B1GMB42.timing"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "sudo required (turbostat, dmidecode, hdparm, block tests)." >&2
  exit 1
fi

exec > >(tee "$OUT")
exec 2>&1

log "=== EFI / timing baseline — B1GMB42 ==="
log "User: $(whoami) | Date: $(date) | Host: $(hostname)"
log "Output: $OUT"
log "IndianaDell: $ROOT"
log "=================================================="

section "1. Boot / timers / power (EFI-relevant)"
log "EFI firmware:"
[[ -d /sys/firmware/efi ]] && log "  mode: UEFI" || log "  mode: legacy/unknown"
log "Clocksource: $(cat /sys/devices/system/clocksource/clocksource0/current_clocksource 2>/dev/null)"
dmesg 2>/dev/null | grep -iE 'clocksource: Switched|tsc: Refined' | tail -3 || true
log "CPU governor (cpu0): $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo n/a)"
command -v powerprofilesctl >/dev/null && log "powerprofilesctl: $(powerprofilesctl get 2>/dev/null)" || true
lscpu | grep -E 'Model name|CPU max MHz|CPU min MHz|Socket|Thread|Core|CPU\(s\)|NUMA'

section "2. Memory topology (DIMM placement vs EFI)"
free -h
dmidecode -t memory 2>/dev/null | awk '
  /^[[:space:]]*(Size|Locator|Speed|Configured Memory Speed|Type|Rank):/ { print }
' | head -40
if command -v mbw >/dev/null; then
  log "mbw 256 MiB x 5 (higher = better bandwidth):"
  mbw -n 5 256 2>/dev/null | tail -6 || log "  mbw failed"
else
  log "mbw: not installed (apt install mbw)"
fi

section "3. turbostat idle (C-states, package power)"
if command -v turbostat >/dev/null; then
  turbostat --num_iterations "$TURBOSTAT_ITER" 2>/dev/null || log "turbostat idle failed"
else
  log "turbostat: not installed"
fi

section "4. CPU under load (turbo reach)"
if [[ "$SKIP_LOAD" == 1 ]]; then
  log "SKIP_LOAD=1 — load phase skipped"
elif command -v stress-ng >/dev/null; then
  log "Starting stress-ng --cpu $(nproc) for ${LOAD_SEC}s ..."
  stress-ng --cpu "$(nproc)" --timeout "${LOAD_SEC}s" --metrics-brief &
  stress_pid=$!
  sleep 2
  if command -v turbostat >/dev/null; then
    turbostat --num_iterations "$TURBOSTAT_ITER" 2>/dev/null || true
  fi
  wait "$stress_pid" 2>/dev/null || true
else
  log "stress-ng: not installed — run: apt install stress-ng"
  log "Fallback: perf stat under brief shell load"
  perf stat -e cycles,task-clock,cache-misses,context-switches -a sleep 5 2>&1 | tail -12 || true
fi

section "5. perf system snapshot (5s idle)"
if command -v perf >/dev/null; then
  perf stat -e cycles,instructions,cache-misses,cache-references,context-switches,cpu-migrations -a sleep 5 2>&1 | tail -14
else
  log "perf: not available"
fi

section "6. PCIe GPU links (lane width / speed)"
for addr in 01:00.0 02:00.0 03:00.0; do
  log "--- GPU $addr ---"
  lspci -nn -s "$addr" 2>/dev/null | head -1 || log "  not present"
  lspci -vv -s "$addr" 2>/dev/null | grep -E 'Physical Slot|LnkCap:|LnkSta:' || true
done
log "Note: Slot1 is x16 wired x8 on T5810 — x8 LnkSta is expected."

section "7. Storage throughput (SATA / ZFS)"
lsblk -d -o NAME,SIZE,MODEL,ROTA,TRAN | grep -vE 'loop|sr0' || true
for dev in sda sdb sdc; do
  [[ -b "/dev/$dev" ]] || continue
  log "--- hdparm -Tt /dev/$dev ---"
  hdparm -Tt "/dev/$dev" 2>/dev/null | tail -2 || log "  skipped"
done
if command -v zpool >/dev/null; then
  log "zpool iostat rpool (5 samples):"
  zpool iostat -v rpool 1 5 2>/dev/null || true
fi
if command -v fio >/dev/null && [[ -d /tmp ]]; then
  log "fio 4K random read latency (30s, /tmp):"
  fio --name=efi-timing --filename=/tmp/efi-timing-fio --size=512M --rw=randread \
    --bs=4k --iodepth=1 --numjobs=1 --runtime=30 --time_based=1 \
    --lat_percentiles=1 --output-format=normal 2>/dev/null \
    | grep -E 'lat |IOPS|bw=|slat|clat' | head -20 || log "  fio failed"
  rm -f /tmp/efi-timing-fio
else
  log "fio: not installed (apt install fio) — use bin/iotest for block seq tests"
fi

section "8. GPU quick sample"
if [[ -x "${ROOT}/bin/gpu-stress" ]]; then
  log "gpu-stress 5s vkcube (per-GPU busy/temp):"
  "${ROOT}/bin/gpu-stress" 5 vkcube 2>/dev/null | tail -15 || log "  gpu-stress failed"
else
  log "bin/gpu-stress not found"
fi

section "9. EFI A/B interpretation guide"
cat <<'GUIDE'
Compare two reports (before/after one BIOS change at a time):

  turbostat load:  Bzy_MHz near 3500 = turbo OK; low Avg_MHz under load = check Turbo / Performance mode
  turbostat idle:  high C6% = deep sleep; disable C-states in BIOS for lower wake latency (more power)
  mbw / fio:       memory or disk latency regression after a BIOS change
  LnkSta:          GPU should stay 8GT/s; Slot1 x8 is normal on this chassis
  hdparm:          HDD ~140 MB/s seq is mechanical limit — EFI will not fix

High-impact hardware (not EFI): 3x4 GB RAM fill -> upgrade DIMMs; PERC H710 fault; Hitachi HDD speed.

Dell T5810 settings worth A/B testing:
  Performance profile | Turbo Boost on | C-states reduced | PCIe ASPM off | Above 4G decoding on
GUIDE

log ""
log "=== Done: $OUT ==="