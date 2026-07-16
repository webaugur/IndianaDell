#!/usr/bin/env bash
# Verify/fix Ventoy persistence on Uncle Wiggly 🥕🐰 (internal Ventoy, sdc1).
# Partition label stays "Wiggly". Drop ISOs into the rabbit hole to boot them.
# Creates persistence/ubuntu-26.04.dat and ventoy/ventoy.json if missing.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VENTOY="$ROOT/scripts/ventoy"

WIGGLY_DEV="${WIGGLY_DEV:-/dev/disk/by-label/Wiggly}"
WIGGLY_MOUNT="${WIGGLY_MOUNT:-/mnt/wiggly}"
ISO_NAME="${VENTOY_ISO:-ubuntu-26.04-desktop-amd64.iso}"
DAT_REL="persistence/ubuntu-26.04.dat"
# Production Uncle Wiggly image is 24 GB; override with VENTOY_DAT_SIZE_MB if needed.
DAT_SIZE_MB="${VENTOY_DAT_SIZE_MB:-24576}"
DAT_LABEL="${VENTOY_DAT_LABEL:-casper-rw}"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { log "ERROR: $*"; exit 1; }

require_root_bits() {
  command -v mkfs.ext4 >/dev/null || die "mkfs.ext4 not found"
  command -v losetup >/dev/null || die "losetup not found"
}

mount_wiggly() {
  if mountpoint -q "$WIGGLY_MOUNT"; then
    log "Uncle Wiggly 🥕🐰 already mounted at $WIGGLY_MOUNT"
    return 0
  fi
  [[ -e "$WIGGLY_DEV" ]] || die "Uncle Wiggly 🥕🐰 not found (label Wiggly): $WIGGLY_DEV"
  sudo mkdir -p "$WIGGLY_MOUNT"
  sudo mount -o "uid=$(id -u),gid=$(id -g)" "$WIGGLY_DEV" "$WIGGLY_MOUNT"
  log "Mounted Uncle Wiggly 🥕🐰 ($WIGGLY_DEV) at $WIGGLY_MOUNT"
}

create_dat_if_missing() {
  local dat_path="$WIGGLY_MOUNT/$DAT_REL"
  sudo mkdir -p "$(dirname "$dat_path")"
  if [[ -f "$dat_path" ]]; then
    log "Persistence image exists: $dat_path ($(du -h "$dat_path" | awk '{print $1}'))"
    return 0
  fi
  log "Creating ${DAT_SIZE_MB}MB persistence image at $dat_path"
  if [[ -x "$VENTOY/CreatePersistentImg.sh" ]]; then
    sudo bash "$VENTOY/CreatePersistentImg.sh" -s "$DAT_SIZE_MB" -l "$DAT_LABEL" -o "$dat_path"
  else
    dd if=/dev/zero of="$dat_path" bs=1M count="$DAT_SIZE_MB" status=progress
    sync
    local loop
    loop="$(sudo losetup --show -f "$dat_path")"
    sudo mkfs.ext4 -F -L "$DAT_LABEL" "$loop"
    sudo losetup -d "$loop"
  fi
  sync
  log "Created $dat_path"
}

install_ventoy_json() {
  local dest_dir="$WIGGLY_MOUNT/ventoy"
  local dest="$dest_dir/ventoy.json"
  [[ -f "$VENTOY/ventoy.json" ]] || die "Missing $VENTOY/ventoy.json"
  mkdir -p "$dest_dir"
  if [[ -f "$dest" ]] && cmp -s "$VENTOY/ventoy.json" "$dest"; then
    log "ventoy.json already current"
    return 0
  fi
  cp "$VENTOY/ventoy.json" "$dest"
  sync
  log "Installed ventoy.json -> $dest"
}

verify_iso() {
  local iso="$WIGGLY_MOUNT/$ISO_NAME"
  [[ -f "$iso" ]] || die "ISO missing in Uncle Wiggly’s rabbit hole: $iso (drop ubuntu-26.04-desktop-amd64.iso into $WIGGLY_MOUNT)"
  log "ISO OK (in the hole): $iso ($(du -h "$iso" | awk '{print $1}'))"
}

verify_dat_filesystem() {
  local dat_path="$WIGGLY_MOUNT/$DAT_REL"
  local loop mount_check="/mnt/persist-verify"
  loop="$(sudo losetup --show -f "$dat_path")"
  sudo e2fsck -fy "$loop" >/dev/null
  sudo mkdir -p "$mount_check"
  sudo mount "$loop" "$mount_check"
  local label
  label="$(sudo blkid -o value -s LABEL "$loop")"
  [[ "$label" == "$DAT_LABEL" ]] || die "dat label is '$label', expected '$DAT_LABEL'"
  sudo umount "$mount_check"
  sudo losetup -d "$loop"
  log "Persistence image OK (ext4, label=$DAT_LABEL)"
}

print_summary() {
  cat <<EOF

Uncle Wiggly 🥕🐰 — Ventoy rabbit hole ready:
  Mount:  $WIGGLY_MOUNT   (partition label: Wiggly)
  ISO:    $WIGGLY_MOUNT/$ISO_NAME
  Dat:    $WIGGLY_MOUNT/$DAT_REL
  Config: $WIGGLY_MOUNT/ventoy/ventoy.json (autosel=1)

Drop more ISOs into $WIGGLY_MOUNT — they fall into the boot black hole.
Boot Ventoy from BIOS -> Ubuntu 26.04 should use casper-rw overlay automatically.
Seed session from Tower5810:  SEED_SKIP_NETWORK_CHECK=1 ~/bin/seed-ventoy-persistence.sh
EOF
}

require_root_bits
mount_wiggly
verify_iso
create_dat_if_missing
install_ventoy_json
verify_dat_filesystem
print_summary