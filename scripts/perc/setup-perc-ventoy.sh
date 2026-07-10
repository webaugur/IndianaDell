#!/usr/bin/env bash
# Download Fohdeesha PERC bundle and deploy to internal Wiggly Ventoy (not USB).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

log "PERC Ventoy setup — target: internal Wiggly (Seagate sdc1), not USB Ventoy"
bash "$ROOT/scripts/perc/download-fohdeesha.sh"
bash "$ROOT/scripts/perc/patch-freedos-iso.sh"
bash "$ROOT/scripts/perc/deploy-to-wiggly.sh" "$@"