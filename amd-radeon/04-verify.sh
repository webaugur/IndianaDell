#!/bin/bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lib/common.sh"

log "=== AMD GPU verify ==="
lspci -nnk | grep -A3 -iE 'vga|3d'
echo "--- /dev/dri ---"
ls -la /dev/dri/ 2>/dev/null || true
echo "--- kernel module ---"
lsmod | grep -E '^amdgpu' || true
command -v rocminfo >/dev/null && rocminfo | head -30 || log "rocminfo not installed"
command -v clinfo >/dev/null && clinfo -l 2>/dev/null | head -20 || log "clinfo not available"
command -v glxinfo >/dev/null && glxinfo -B 2>/dev/null | head -15 || log "glxinfo not available"