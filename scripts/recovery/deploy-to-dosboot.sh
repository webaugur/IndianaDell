#!/usr/bin/env bash
# Copy ZFS recovery scripts and docs to the DOSBOOT partition (sdc3).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RECOVERY_SRC="$ROOT/scripts/recovery"
DEST_REL="IndianaDell/recovery"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { log "ERROR: $*"; exit 1; }

find_dosboot_mount() {
    local candidate
    if [[ -n "${DOSBOOT_MOUNT:-}" && -d "${DOSBOOT_MOUNT}" ]]; then
        printf '%s\n' "$DOSBOOT_MOUNT"
        return 0
    fi
    for candidate in /run/media/*/DOSBOOT1 /run/media/*/DOSBOOT /mnt/dosboot; do
        [[ -d "$candidate" ]] || continue
        printf '%s\n' "$candidate"
        return 0
    done
    return 1
}

DOSBOOT="$(find_dosboot_mount)" || die "DOSBOOT not mounted. Mount sdc3 or set DOSBOOT_MOUNT=."

DEST="${DOSBOOT}/${DEST_REL}"
mkdir -p "$DEST"

log "Deploying to ${DEST}"

cp -f "$ROOT/mount-rpool-recovery.sh" "$DEST/"
cp -f "$RECOVERY_SRC/mount-bpool-recovery.sh" "$DEST/"
chmod +x "$DEST/mount-rpool-recovery.sh" "$DEST/mount-bpool-recovery.sh"

cp -f "$ROOT/docs/B1GMB42-zfs-recovery.md" "$DEST/"
if [[ -f "$ROOT/B1GMB42-zfs-recovery.pdf" ]]; then
    cp -f "$ROOT/B1GMB42-zfs-recovery.pdf" "$DEST/"
else
    log "WARN: PDF missing — run bin/build-zfs-recovery-doc first"
fi

cat >"$DEST/README.txt" <<EOF
B1GMB42 ZFS recovery kit (Tower5810)
====================================

Read: B1GMB42-zfs-recovery.md or .pdf

Quick start (from Ventoy Ubuntu live):
  sudo apt-get install -y zfsutils-linux
  cd $(basename "$DEST")
  sudo bash mount-rpool-recovery.sh mount
  sudo bash mount-bpool-recovery.sh mount
  sudo bash mount-rpool-recovery.sh chroot

Full IndianaDell workspace: ~/Documents/IndianaDell or Wiggly Ventoy persistence.
EOF

sync
log "Done."
ls -la "$DEST"