#!/bin/bash
set -euo pipefail

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { log "ERROR: $*"; exit 1; }

has_amd_gpu() {
  lspci -nn | grep -qiE 'vga|3d.*\[1002:'
}

detect_amd_gpus() {
  lspci -nn | grep -iE 'vga|3d' | grep -i '\[1002:' || true
}

ubuntu_series() {
  . /etc/os-release
  echo "${VERSION_ID%%.*}"
}