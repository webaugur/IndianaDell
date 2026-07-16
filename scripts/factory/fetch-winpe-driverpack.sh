#!/usr/bin/env bash
# Fetch WinPE drivers from the public OSDeploy-style WinPEDriverPack on GitHub.
#
# The pre-crash Dell CAB (WinPE10.0-Drivers-A25-F0XPX.CAB) is retired from
# downloads.dell.com. This repo is a practical replacement: expanded INF packs
# for WinPE/WinRE (Dell + common Intel/USB), ready to inject into a boot image.
#
# Source (user-suggested mirror):
#   https://github.com/adamaayala/WinPEDriverPack
# Upstream name in README: OSDeploy/WinPEDriverPack (may redirect/mirror).
#
# Usage:
#   bin/fetch-winpe-driverpack              # Dell + Intel-Ethernet + Intel-RAID + USB (amd64)
#   bin/fetch-winpe-driverpack --all-amd64  # entire amd64 tree (~1 GB)
#   bin/fetch-winpe-driverpack --update     # git pull / hard reset to origin/main
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEST="${WINPE_DRIVERPACK_DIR:-$ROOT/FactoryDocs/System-T5810/WinPE/WinPEDriverPack}"
REPO_URL="${WINPE_DRIVERPACK_URL:-https://github.com/adamaayala/WinPEDriverPack.git}"
MODE=sparse   # sparse | all-amd64 | update

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { log "ERROR: $*"; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all-amd64) MODE=all-amd64; shift ;;
    --update) MODE=update; shift ;;
    --dest) DEST="$2"; shift 2 ;;
    --url) REPO_URL="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,18p' "$0"
      exit 0
      ;;
    *) die "unknown option: $1" ;;
  esac
done

command -v git >/dev/null || die "git required"

SPARSE_PATHS=(
  amd64/Dell
  amd64/Intel-Ethernet
  amd64/Intel-RAID
  amd64/USB
  README.md
  LICENSE
)

clone_sparse() {
  local paths=("$@")
  log "Sparse-clone $REPO_URL → $DEST"
  log "Paths: ${paths[*]}"
  rm -rf "$DEST"
  mkdir -p "$(dirname "$DEST")"
  # Partial clone keeps network/disk gentler than a full 1 GB tree
  git clone --filter=blob:none --sparse --depth 1 "$REPO_URL" "$DEST"
  (
    cd "$DEST"
    git sparse-checkout set --cone
    # cone mode wants top-level dirs; set non-cone for nested paths
    git sparse-checkout init --no-cone
    printf '%s\n' "${paths[@]}" > .git/info/sparse-checkout
    git sparse-checkout reapply
    git checkout
  )
}

clone_all_amd64() {
  log "Sparse-clone full amd64 tree → $DEST"
  rm -rf "$DEST"
  mkdir -p "$(dirname "$DEST")"
  git clone --filter=blob:none --sparse --depth 1 "$REPO_URL" "$DEST"
  (
    cd "$DEST"
    git sparse-checkout init --cone
    git sparse-checkout set amd64 README.md LICENSE
  )
}

update_repo() {
  [[ -d "$DEST/.git" ]] || die "not a git clone: $DEST (run without --update first)"
  log "Updating $DEST"
  (
    cd "$DEST"
    git fetch origin
    git reset --hard origin/main
    git clean -f -d
  )
}

write_readme() {
  cat >"$DEST/INDIANADELL-README.txt" <<EOF
IndianaDell — WinPE DriverPack (Dell-focused)

Source: $REPO_URL
Fetched: $(date -Iseconds)
Host use: Precision T5810 (B1GMB42) WinPE / recovery media

This is NOT the retired Dell CAB:
  System-T5810/WinPE/WinPE10.0-Drivers-A25-F0XPX.CAB  (no longer on downloads.dell.com)

It is an expanded INF driver tree suitable for DISM / OSDCloud / custom WinPE:

  amd64/Dell/            — Dell WinPE drivers (~100 MB)
  amd64/Intel-Ethernet/  — NIC
  amd64/Intel-RAID/      — RST / AHCI class
  amd64/USB/             — USB host controllers

Refresh:
  bin/fetch-winpe-driverpack --update

Full amd64 set (all OEMs, ~1 GB):
  bin/fetch-winpe-driverpack --all-amd64
EOF
}

case "$MODE" in
  sparse) clone_sparse "${SPARSE_PATHS[@]}" ;;
  all-amd64) clone_all_amd64 ;;
  update) update_repo ;;
esac

write_readme

# Gentle summary — do not flood disks with find -exec du on every file if huge
log "Contents:"
if [[ -d "$DEST/amd64" ]]; then
  du -sh "$DEST/amd64"/* 2>/dev/null | sed 's/^/  /' || true
fi
log "Done → $DEST"
log "Note: do not commit this tree to IndianaDell git (large binary pack)."
