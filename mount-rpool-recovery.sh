#!/usr/bin/env bash
# Mount Ubuntu ZFS rpool under /recovery for chroot recovery (default).
#
# Default (chroot): import rpool with altroot /recovery — full installed system tree.
# Optional (--overlay): bind-mount running rpool paths when altroot is not possible.
#
# Typical use from Ventoy live (rpool not imported):
#   sudo ./mount-rpool-recovery.sh mount
#   sudo ./mount-rpool-recovery.sh chroot
#
# Overlay fallback while booted from rpool:
#   sudo ./mount-rpool-recovery.sh mount --overlay

set -euo pipefail

POOL="${POOL_NAME:-rpool}"
RECOVERY="${RECOVERY_ROOT:-/recovery}"
STATE_FILE="/run/rpool-recovery.state"

IMPORT_DIRS=(
    /dev/disk/by-id
    /dev/disk/by-partlabel
    /dev/disk/by-label
)

MOUNT_MODE="chroot"

log() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

require_root() {
    [[ "${EUID:-$(id -u)}" -eq 0 ]] || die "run as root (sudo $0 ...)"
}

pool_imported() {
    zpool list -H -o name 2>/dev/null | grep -qx "$POOL"
}

pool_altroot() {
    zpool get -H -o value altroot "$POOL" 2>/dev/null || echo "-"
}

running_from_rpool() {
    findmnt -rn -o SOURCE / 2>/dev/null | grep -q "^${POOL}/"
}

recovery_active() {
    [[ -f "$STATE_FILE" ]] || return 1
    grep -q '^mode=' "$STATE_FILE"
}

write_state() {
    local mode="$1"
    {
        printf 'mode=%s\n' "$mode"
        printf 'pool=%s\n' "$POOL"
        printf 'recovery=%s\n' "$RECOVERY"
    } >"$STATE_FILE"
}

record_bind() {
    printf 'bind=%s|%s\n' "$1" "$2" >>"$STATE_FILE"
}

get_boot_env() {
    local name mountpoint
    while read -r name mountpoint; do
        [[ "$name" == "${POOL}/ROOT" ]] && continue
        [[ "$name" == *@* ]] && continue
        if [[ "$mountpoint" == "/" ]]; then
            printf '%s\n' "$name"
            return 0
        fi
    done < <(zfs list -H -o name,mountpoint -r "${POOL}/ROOT" 2>/dev/null)

    zfs list -H -o name -d 1 -r "${POOL}/ROOT" 2>/dev/null \
        | grep -v "^${POOL}/ROOT$" | head -1
}

import_pool() {
    local dir
    mkdir -p "$RECOVERY"

    for dir in "${IMPORT_DIRS[@]}"; do
        [[ -d "$dir" ]] || continue
        if zpool import -N -f -R "$RECOVERY" -d "$dir" "$POOL" 2>/dev/null; then
            write_state "chroot"
            return 0
        fi
    done

    die "could not import ${POOL}; check disks and run: zpool import"
}

mount_datasets_under_recovery() {
    local ds

    while read -r ds; do
        [[ -n "$ds" ]] || continue
        zfs mount -R "$RECOVERY" "$ds"
    done < <(zfs list -H -o name,canmount -r "$POOL" 2>/dev/null | awk '$2 == "on" { print $1 }')

    zfs mount -a -R "$RECOVERY"
}

relocate_imported_pool() {
    local altroot mountpoint

    altroot="$(pool_altroot)"
    if [[ "$altroot" == "$RECOVERY" ]]; then
        write_state "chroot"
        log "${POOL} already uses altroot ${RECOVERY}"
        mount_datasets_under_recovery
        return 0
    fi

    mkdir -p "$RECOVERY"

    while read -r mountpoint; do
        [[ -n "$mountpoint" && "$mountpoint" != "none" && "$mountpoint" != "/" ]] || continue
        if mountpoint -q "$mountpoint" 2>/dev/null; then
            umount "$mountpoint" || die "could not umount ${mountpoint}; close users of rpool first"
        fi
    done < <(zfs list -H -o mountpoint -r "$POOL" -t filesystem 2>/dev/null | sort -ru)

    zpool set altroot="$RECOVERY" "$POOL"
    write_state "chroot"
    mount_datasets_under_recovery
}

mount_chroot_tree() {
    if ! pool_imported; then
        log "importing ${POOL} with altroot ${RECOVERY} (chroot layout) ..."
        import_pool
        mount_datasets_under_recovery
        return 0
    fi

    if running_from_rpool; then
        die "${POOL} is the running root filesystem; chroot layout is not available." \
            "Boot Ventoy live without importing ${POOL}, or use: $0 mount --overlay"
    fi

    log "${POOL} is imported; relocating datasets under ${RECOVERY} (chroot layout) ..."
    relocate_imported_pool
}

bind_running_system() {
    local name mountpoint target d covered

    mkdir -p "$RECOVERY"
    write_state "overlay"

    while read -r name mountpoint; do
        [[ "$mountpoint" == "none" || "$mountpoint" == "/" ]] && continue
        [[ "$mountpoint" == "${RECOVERY}"* ]] && continue
        [[ -d "$mountpoint" ]] || continue

        target="${RECOVERY}${mountpoint}"
        mkdir -p "$target"
        if mount --bind "$mountpoint" "$target" 2>/dev/null; then
            record_bind "$mountpoint" "$target"
            log "bind ${mountpoint} -> ${target}  (${name})"
        else
            log "skip ${mountpoint} (${name}): bind not available"
        fi
    done < <(zfs list -H -o name,mountpoint -r "$POOL" -t filesystem 2>/dev/null)

    for d in boot etc opt; do
        [[ -e "/$d" ]] || continue
        covered=false
        if findmnt -n -T "/$d" -o SOURCE 2>/dev/null | grep -q "^${POOL}/"; then
            covered=true
        fi
        $covered && continue

        target="${RECOVERY}/system/${d}"
        mkdir -p "$target"
        mount --bind "/$d" "$target"
        record_bind "/$d" "$target"
        log "bind /$d -> ${target}"
    done

    be="$(get_boot_env || true)"
    log ""
    log "Overlay recovery mounts active under ${RECOVERY} (not a full chroot tree)."
    [[ -n "$be" ]] && log "Boot environment dataset: ${be}"
}

mount_overlay_tree() {
    pool_imported || die "overlay mode requires ${POOL} to already be imported"
    log "mounting overlay recovery view under ${RECOVERY} ..."
    bind_running_system
}

prepare_chroot_filesystems() {
    local d
    for d in dev proc sys run; do
        mkdir -p "${RECOVERY}/${d}"
        if ! mountpoint -q "${RECOVERY}/${d}" 2>/dev/null; then
            mount --bind "/${d}" "${RECOVERY}/${d}"
        fi
    done
    mkdir -p "${RECOVERY}/dev/pts"
    if ! mountpoint -q "${RECOVERY}/dev/pts" 2>/dev/null; then
        mount --bind /dev/pts "${RECOVERY}/dev/pts"
    fi
}

print_chroot_hint() {
    local be
    be="$(get_boot_env 2>/dev/null || true)"
    log ""
    log "Chroot recovery tree ready at ${RECOVERY}"
    [[ -n "$be" ]] && log "Boot environment: ${be}"
    log ""
    log "Enter with:"
    log "  sudo $0 chroot"
    log ""
    log "Or manually:"
    log "  for d in dev proc sys run; do mount --bind /\$d ${RECOVERY}/\$d; done"
    log "  mount --bind /dev/pts ${RECOVERY}/dev/pts"
    log "  chroot ${RECOVERY} /bin/bash"
}

cmd_mount() {
    require_root

    if recovery_active; then
        log "recovery mounts already active (${STATE_FILE})"
        cmd_status
        return 0
    fi

    case "$MOUNT_MODE" in
        chroot)
            mount_chroot_tree
            log "mounted ${POOL} for chroot recovery at ${RECOVERY}"
            print_chroot_hint
            ;;
        overlay)
            mount_overlay_tree
            log "mounted ${POOL} overlay view at ${RECOVERY}"
            log "Note: this is not a complete chroot rootfs; use chroot mode from live media when possible."
            ;;
        *)
            die "internal error: unknown mount mode '${MOUNT_MODE}'"
            ;;
    esac

    cmd_status
}

cmd_chroot() {
    require_root

    if ! recovery_active; then
        MOUNT_MODE="chroot"
        cmd_mount
    fi

    local mode
    mode="$(awk -F= '$1 == "mode" { print $2 }' "$STATE_FILE")"
    [[ "$mode" == "chroot" ]] || die "active recovery mode is '${mode}'; chroot requires chroot layout (not --overlay)"

    [[ -x "${RECOVERY}/bin/bash" ]] \
        || die "${RECOVERY}/bin/bash not found; is the boot environment mounted?"

    prepare_chroot_filesystems
    log "entering chroot ${RECOVERY} ..."
    exec chroot "${RECOVERY}" /bin/bash
}

cmd_umount() {
    require_root

    if ! recovery_active; then
        log "no active recovery mounts (${STATE_FILE} missing)"
        return 0
    fi

    local mode d
    mode="$(awk -F= '$1 == "mode" { print $2 }' "$STATE_FILE")"

    for d in dev/pts dev proc sys run; do
        if mountpoint -q "${RECOVERY}/${d}" 2>/dev/null; then
            umount "${RECOVERY}/${d}" || log "warning: could not umount ${RECOVERY}/${d}"
        fi
    done

    case "$mode" in
        overlay)
            local line dst
            while IFS= read -r line; do
                [[ "$line" == bind=* ]] || continue
                line="${line#bind=}"
                dst="${line#*|}"
                if mountpoint -q "$dst" 2>/dev/null; then
                    umount "$dst" || log "warning: could not umount ${dst}"
                fi
            done < <(tac "$STATE_FILE")

            rmdir "${RECOVERY}/system" 2>/dev/null || true
            ;;
        chroot)
            zfs umount -a -R "$RECOVERY" 2>/dev/null || true
            zpool set altroot=- "$POOL" 2>/dev/null || true
            if zpool export "$POOL"; then
                log "exported ${POOL}"
            else
                die "could not export ${POOL}; datasets may still be busy"
            fi
            ;;
        altroot|bind)
            # legacy state files from earlier script versions
            zfs umount -a -R "$RECOVERY" 2>/dev/null || true
            zpool set altroot=- "$POOL" 2>/dev/null || true
            zpool export "$POOL" 2>/dev/null || true
            ;;
        *)
            die "unknown recovery mode '${mode}' in ${STATE_FILE}"
            ;;
    esac

    rm -f "$STATE_FILE"
    log "recovery mounts removed"
}

cmd_status() {
    local mode be

    log "pool:      ${POOL}"
    if pool_imported; then
        log "imported:  yes (altroot=$(pool_altroot))"
        zpool status "$POOL" | sed -n '1,12p'
    else
        log "imported:  no"
    fi

    if recovery_active; then
        mode="$(awk -F= '$1 == "mode" { print $2 }' "$STATE_FILE")"
        log "recovery:  active (mode=${mode}, root=${RECOVERY})"
    else
        log "recovery:  inactive"
    fi

    be="$(get_boot_env 2>/dev/null || true)"
    [[ -n "$be" ]] && log "boot env:  ${be}"

    if [[ -d "$RECOVERY" ]]; then
        log ""
        log "contents of ${RECOVERY}:"
        ls -la "$RECOVERY" 2>/dev/null || true
    fi

    log ""
    log "mounts under ${RECOVERY}:"
    findmnt -T "$RECOVERY" 2>/dev/null | head -25 || true
}

usage() {
    cat <<EOF
Usage: $0 <command> [options]

Commands:
  mount              Mount rpool for chroot recovery (default)
  mount --overlay    Bind-mount running rpool paths (fallback only)
  chroot             Mount if needed, then enter chroot at ${RECOVERY}
  umount             Tear down recovery mounts
  status             Show pool and recovery state

Default mount mode builds a full altroot tree at ${RECOVERY} suitable for:
  chroot ${RECOVERY} /bin/bash

Use --overlay only when already booted from rpool and a chroot tree is impossible.

Environment overrides:
  POOL_NAME      pool name (default: rpool)
  RECOVERY_ROOT  mount root (default: /recovery)

Examples:
  sudo $0 mount
  sudo $0 chroot
  ls ${RECOVERY}/home/ubuntu
  sudo $0 umount
EOF
}

parse_args() {
    local cmd="${1:-}"
    shift || true

    case "$cmd" in
        mount)
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --overlay|--bind) MOUNT_MODE="overlay"; shift ;;
                    *) die "unknown mount option '$1'" ;;
                esac
            done
            ;;
        umount|unmount|status|chroot|help|-h|--help)
            [[ $# -eq 0 ]] || die "command '${cmd}' does not take options"
            ;;
        "")
            usage
            exit 0
            ;;
        *)
            die "unknown command '${cmd}'; use mount, chroot, umount, or status"
            ;;
    esac

    case "$cmd" in
        mount)   cmd_mount ;;
        umount|unmount) cmd_umount ;;
        status)  cmd_status ;;
        chroot)  cmd_chroot ;;
        help|-h|--help) usage ;;
    esac
}

parse_args "$@"