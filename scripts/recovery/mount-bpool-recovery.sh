#!/usr/bin/env bash
# Import bpool and mount the Ubuntu boot environment under a recovery root.
# Use after rpool is mounted at RECOVERY_ROOT (default /recovery).
#
# Typical (from live media, after mount-rpool-recovery.sh mount):
#   sudo ./mount-bpool-recovery.sh mount
#   sudo ./mount-bpool-recovery.sh umount
set -euo pipefail

POOL="${BPOOL_NAME:-bpool}"
RECOVERY="${RECOVERY_ROOT:-/recovery}"
BOOT_MOUNT="${RECOVERY}/boot"
STATE_FILE="/run/bpool-recovery.state"

IMPORT_DIRS=(
    /dev/disk/by-id
    /dev/disk/by-partlabel
    /dev/disk/by-label
)

log() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

require_root() {
    [[ "${EUID:-$(id -u)}" -eq 0 ]] || die "run as root (sudo $0 ...)"
}

pool_imported() {
    zpool list -H -o name 2>/dev/null | grep -qx "$POOL"
}

get_boot_dataset() {
    zfs list -H -o name,mountpoint -r "${POOL}/BOOT" 2>/dev/null \
        | awk '$2 == "/boot" { print $1; exit }'
    zfs list -H -o name -d 1 -r "${POOL}/BOOT" 2>/dev/null | grep -v "^${POOL}/BOOT$" | head -1
}

write_state() {
    printf 'pool=%s\nboot_mount=%s\n' "$POOL" "$BOOT_MOUNT" >"$STATE_FILE"
}

cmd_mount() {
    require_root
    local ds

    [[ -d "$RECOVERY" ]] || die "recovery root ${RECOVERY} missing — mount rpool first"

    if [[ -f "$STATE_FILE" ]]; then
        log "bpool recovery already active (${STATE_FILE})"
        cmd_status
        return 0
    fi

    if ! pool_imported; then
        local dir
        for dir in "${IMPORT_DIRS[@]}"; do
            [[ -d "$dir" ]] || continue
            if zpool import -N -f -d "$dir" "$POOL" 2>/dev/null; then
                log "imported ${POOL}"
                break
            fi
        done
        pool_imported || die "could not import ${POOL}"
    else
        log "${POOL} already imported"
    fi

    ds="$(get_boot_dataset || true)"
    [[ -n "$ds" ]] || die "no boot dataset under ${POOL}/BOOT"

    mkdir -p "$BOOT_MOUNT"
    zfs set mountpoint="$BOOT_MOUNT" "$ds"
    zfs mount "$ds"
    write_state

    log "mounted ${ds} at ${BOOT_MOUNT}"
    cmd_status
}

cmd_umount() {
    require_root
    local ds

    [[ -f "$STATE_FILE" ]] || { log "no active bpool recovery"; return 0; }

    ds="$(get_boot_dataset 2>/dev/null || true)"
    if [[ -n "$ds" ]] && mountpoint -q "$BOOT_MOUNT" 2>/dev/null; then
        zfs umount "$ds" || log "warning: could not umount ${ds}"
        zfs set mountpoint=/boot "$ds" 2>/dev/null || true
    fi

    if pool_imported; then
        zpool export "$POOL" && log "exported ${POOL}" || log "warning: could not export ${POOL}"
    fi

    rm -f "$STATE_FILE"
}

cmd_status() {
    log "pool:       ${POOL}"
    if pool_imported; then
        log "imported:   yes"
        zpool status "$POOL" | sed -n '1,8p'
    else
        log "imported:   no"
    fi
    if [[ -f "$STATE_FILE" ]]; then
        log "boot mount: ${BOOT_MOUNT}"
        ls -la "$BOOT_MOUNT" 2>/dev/null | head -10 || true
    fi
}

usage() {
    cat <<EOF
Usage: $0 <mount|umount|status>

Mount Ubuntu ZFS boot pool (${POOL}) at ${RECOVERY}/boot for chroot repair.
Run after mount-rpool-recovery.sh mount.

Environment:
  BPOOL_NAME      pool name (default: bpool)
  RECOVERY_ROOT   rpool recovery tree (default: /recovery)
EOF
}

case "${1:-}" in
    mount)  cmd_mount ;;
    umount|unmount) cmd_umount ;;
    status) cmd_status ;;
    -h|--help|help|"") usage ;;
    *) die "unknown command '${1}'" ;;
esac