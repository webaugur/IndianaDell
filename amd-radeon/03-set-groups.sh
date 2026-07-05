#!/bin/bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lib/common.sh"

user="${1:-$USER}"
for g in render video; do
  if getent group "$g" >/dev/null; then
    sudo usermod -aG "$g" "$user"
    log "Added $user to $g"
  fi
done