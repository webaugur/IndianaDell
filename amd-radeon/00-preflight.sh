#!/bin/bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "$DIR/lib/common.sh"

log "ROCm / amdgpu preflight for $(hostname)"

has_amd_gpu || die "No AMD GPU detected"
detect_amd_gpus

if detect_amd_gpus | grep -qiE 'bonaire|w5100|w5000|firepro|pitcairn'; then
  log "WARNING: FirePro W5000/W5100 use amdgpu for display but are NOT in the ROCm ML matrix."
  log "These scripts install amdgpu/ROCm stack; do not expect HIP/OpenCL ML on GCN1/2 FirePro."
fi

series="$(ubuntu_series)"
log "Ubuntu series: $series (26.x uses noble repo fallback in installer)"
command -v dpkg >/dev/null || die "dpkg missing"
command -v curl >/dev/null || log "curl recommended for amdgpu-install download"
log "Preflight OK"