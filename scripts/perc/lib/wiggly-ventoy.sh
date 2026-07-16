# Shared helpers: mount and verify Uncle Wiggly 🥕🐰 (internal Ventoy) only.
# Uncle Wiggly = Seagate sdc1 (partition label Wiggly, TRAN=sata). Not the USB Ventoy stick.
# shellcheck shell=bash

wiggly_log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
wiggly_die() { wiggly_log "ERROR: $*"; exit 1; }

WIGGLY_DEV="${WIGGLY_DEV:-/dev/disk/by-label/Wiggly}"
WIGGLY_MOUNT="${WIGGLY_MOUNT:-/mnt/wiggly}"
WIGGLY_LABEL_EXPECT="${WIGGLY_LABEL_EXPECT:-Wiggly}"

# Refuse USB/removable Ventoy unless ALLOW_USB_VENTOY=1 (safety: default internal disk only).
wiggly_assert_internal() {
    local dev="$1"
    local pk parent tran label removable

    [[ -e "$dev" ]] || wiggly_die "Uncle Wiggly 🥕🐰 not found (label Wiggly): $dev"

    pk="$(lsblk -no PKNAME "$dev" 2>/dev/null | head -1)"
    [[ -n "$pk" ]] || wiggly_die "Cannot resolve parent disk for $dev"

    parent="/dev/$pk"
    tran="$(lsblk -no TRAN "$parent" 2>/dev/null | head -1)"
    label="$(lsblk -no LABEL "$dev" 2>/dev/null | head -1)"
    removable="$(lsblk -no RM "$parent" 2>/dev/null | head -1)"

    if [[ "$label" != "$WIGGLY_LABEL_EXPECT" ]]; then
        wiggly_die "Partition label is '$label', expected '$WIGGLY_LABEL_EXPECT' — refusing to use this Ventoy volume"
    fi

    if [[ "${ALLOW_USB_VENTOY:-0}" != "1" ]]; then
        if [[ "$tran" == "usb" || "$removable" == "1" ]]; then
            wiggly_die "Refusing USB/removable Ventoy ($parent tran=$tran rm=$removable). Use Uncle Wiggly 🥕🐰 on Seagate (sata). Set ALLOW_USB_VENTOY=1 to override."
        fi
        if [[ "$tran" != "sata" ]]; then
            wiggly_die "Refusing non-SATA Ventoy parent $parent (tran=$tran). Expected Uncle Wiggly on Seagate (sata)."
        fi
    fi

    wiggly_log "Uncle Wiggly 🥕🐰 OK: $dev on $parent (label=$label tran=$tran)"
}

wiggly_resolve_dev() {
    readlink -f "$1" 2>/dev/null || realpath "$1" 2>/dev/null || printf '%s\n' "$1"
}

wiggly_mount() {
    wiggly_assert_internal "$WIGGLY_DEV"
    local expect actual mounted_dev

    expect="$(wiggly_resolve_dev "$WIGGLY_DEV")"

    if mountpoint -q "$WIGGLY_MOUNT"; then
        mounted_dev="$(findmnt -n -o SOURCE "$WIGGLY_MOUNT")"
        actual="$(wiggly_resolve_dev "$mounted_dev")"
        if [[ "$actual" != "$expect" ]]; then
            wiggly_die "$WIGGLY_MOUNT is mounted from $mounted_dev, not Uncle Wiggly ($WIGGLY_DEV -> $expect)"
        fi
        wiggly_log "Uncle Wiggly 🥕🐰 already mounted at $WIGGLY_MOUNT ($mounted_dev)"
        return 0
    fi

    sudo mkdir -p "$WIGGLY_MOUNT"
    sudo mount -o "uid=$(id -u),gid=$(id -g)" "$WIGGLY_DEV" "$WIGGLY_MOUNT"
    wiggly_log "Mounted Uncle Wiggly 🥕🐰 ($WIGGLY_DEV) at $WIGGLY_MOUNT"
}

wiggly_assert_ventoy_tree() {
    local root="$1"
    # Ventoy payload often lives on VTOYEFI (sdc2); data partition only needs ventoy/ + ISOs.
    [[ -d "$root/ventoy" ]] || wiggly_die "No ventoy/ on $root — is Ventoy installed on Uncle Wiggly?"
    if [[ ! -f "$root/ventoy/ventoy.json" ]] && ! ls "$root"/*.iso 2>/dev/null | head -1 | grep -q .; then
        wiggly_die "Uncle Wiggly does not look like a Ventoy data partition (no ventoy.json and no ISOs)"
    fi
}
