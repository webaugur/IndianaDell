#!/bin/bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lib/common.sh"

log "Installing amdgpu + ROCm (use=all)"
sudo amdgpu-install -y --usecase=graphics,rocm || {
  log "Retry without rocm usecase (graphics only)"
  sudo amdgpu-install -y --usecase=graphics
}
log "Driver install finished — reboot recommended"