#!/bin/bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lib/common.sh"

VER="${ROCM_VERSION:-7.2.1}"
log "Fetching amdgpu-install for ROCm $VER"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
# Ubuntu 26.04: use noble package if jammy/noble not auto-detected
. /etc/os-release
case "$VERSION_ID" in
  26.04|24.04) repo="noble" ;;
  22.04) repo="jammy" ;;
  *) repo="noble"; log "Unknown release — trying noble" ;;
esac
url="https://repo.radeon.com/amdgpu-install/${VER}/ubuntu/${repo}/amdgpu-install_${VER}_all.deb"
log "URL: $url"
curl -fLO "$url" || die "Download failed — check ROCm version / repo"
sudo dpkg -i amdgpu-install_*_all.deb || sudo apt-get install -f -y
log "amdgpu-install ready"