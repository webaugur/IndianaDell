#!/bin/bash
set -euo pipefail
log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
log "Removing amdgpu-install packages (manual confirm)"
sudo amdgpu-install --uninstall || true
sudo apt-get purge -y 'rocm*' 'hip-*' amdgpu-dkms 2>/dev/null || true
sudo apt-get autoremove -y
log "Done — reboot"