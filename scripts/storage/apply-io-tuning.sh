#!/usr/bin/env bash
#
# apply-io-tuning.sh — keep the desktop responsive when the disks are busy.
# Now a compatibility wrapper around the hardware-adaptive tool
# scripts/tuning/indianadell-tuning.sh (bin/apply-tuning), limited to the IO steps:
#   arc (ZFS only) zram sysctl diskswap bfq (rotational disks) initramfs ionice
#
# Usage:  sudo bin/apply-io-tuning [--dry-run] [--only a,b] [--skip a,b]
#         bin/apply-io-tuning --report        (no root)
# Env / /etc/indianadell/tuning.conf: ARC_MAX_GIB ZRAM_SIZE ZRAM_ALGO SWAPPINESS PAGE_CLUSTER BG_PROCS ...
# Defaults are computed from RAM; Tower5810 keeps 13G zram / 4 GiB ARC via etc/indianadell/hosts/Tower5810.conf.
# Undo:   sudo bin/revert-io-tuning
set -euo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
T="$ROOT/scripts/tuning/indianadell-tuning.sh"
IO_STEPS="arc,zram,sysctl,diskswap,bfq,initramfs,ionice"
args=(); only="$IO_STEPS"; cmd=apply
while [[ $# -gt 0 ]]; do case "$1" in
  --report) cmd=report; shift ;;
  --status) cmd=status; shift ;;
  --only) only="$2"; shift 2 ;;
  *) args+=("$1"); shift ;;
esac; done
if [[ $cmd == apply && $EUID -ne 0 && " ${args[*]-} " != *" --dry-run "* ]]; then
  echo "Run with sudo: sudo $ROOT/bin/apply-io-tuning ${args[*]-}   (or add --dry-run / --report)" >&2; exit 1
fi
exec "$T" "$cmd" --only "$only" ${args[@]+"${args[@]}"}
