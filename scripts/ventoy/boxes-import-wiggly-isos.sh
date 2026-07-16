#!/usr/bin/env bash
# Create a GNOME Boxes (libvirt qemu:///session) VM for each ISO on Uncle Wiggly 🥕🐰.
# Skips .Trash-* paths. Existing domains with the same name are left alone unless
# FORCE=1. Does not start VMs (Boxes can boot them on demand).
set -euo pipefail

WIGGLY_MOUNT="${WIGGLY_MOUNT:-/mnt/wiggly}"
WIGGLY_DEV="${WIGGLY_DEV:-/dev/disk/by-label/Wiggly}"
CONN="${LIBVIRT_URI:-qemu:///session}"
IMG_DIR="${BOXES_IMG_DIR:-$HOME/.local/share/gnome-boxes/images}"
FORCE="${FORCE:-0}"
START="${START:-0}"          # 1 = start after create
DRY_RUN="${DRY_RUN:-0}"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { log "ERROR: $*"; exit 1; }

mount_wiggly() {
    if mountpoint -q "$WIGGLY_MOUNT"; then
        return 0
    fi
    [[ -e "$WIGGLY_DEV" ]] || die "Uncle Wiggly not found (label Wiggly): $WIGGLY_DEV"
    sudo mkdir -p "$WIGGLY_MOUNT"
    sudo mount -o "uid=$(id -u),gid=$(id -g)" "$WIGGLY_DEV" "$WIGGLY_MOUNT"
    log "Mounted Uncle Wiggly 🥕🐰 at $WIGGLY_MOUNT"
}

# libvirt domain name: [a-zA-Z0-9_.-]+, start with letter/digit
sanitize_name() {
    local base="$1"
    base="${base%.*}"
    base="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')"
    [[ -n "$base" ]] || base="iso"
    # collapse long names
    if ((${#base} > 48)); then
        base="${base:0:48}"
        base="${base%-}"
    fi
    # must start with alnum
    [[ "$base" =~ ^[a-z0-9] ]] || base="vm-$base"
    printf '%s\n' "$base"
}

# Human title for Boxes
pretty_title() {
    local path="$1" base
    base="$(basename "$path")"
    base="${base%.*}"
    base="${base//_/ }"
    printf '%s\n' "$base"
}

# Memory MB / vCPUs / disk GB by rough content
profile_for_iso() {
    local path="$1" lower
    lower="$(basename "$path" | tr '[:upper:]' '[:lower:]')"
    # defaults
    local mem=4096 vcpus=2 disk=40

    case "$lower" in
        *freedos*|*fd14*|*firmware*|*netinst*)
            mem=1024; vcpus=1; disk=8
            ;;
        *bartpe*|*hbcd*|*pe_x64*|*pe-kit*|*pe_kit*)
            mem=2048; vcpus=2; disk=16
            ;;
        *windows_nt*|*win_ent_7*|*win*7*)
            mem=2048; vcpus=2; disk=40
            ;;
        *windows10*|*windows11*|*win11*)
            mem=6144; vcpus=4; disk=60
            ;;
        *qubes*)
            mem=8192; vcpus=4; disk=80
            ;;
        *dragonos*)
            mem=6144; vcpus=4; disk=60
            ;;
        *ubuntu*|*debian*|*dragon*)
            mem=4096; vcpus=4; disk=40
            ;;
        *fohdeesha-linux*)
            mem=2048; vcpus=2; disk=16
            ;;
        *fohdeesha-freedos*)
            mem=1024; vcpus=1; disk=8
            ;;
    esac
    printf '%s %s %s\n' "$mem" "$vcpus" "$disk"
}

os_variant_for_iso() {
    local path="$1" lower
    lower="$(basename "$path" | tr '[:upper:]' '[:lower:]')"
    case "$lower" in
        *ubuntu*26*|*ubuntu-26*) echo ubuntu24.04 ;;
        *ubuntu*22*) echo ubuntu22.04 ;;
        *ubuntu*) echo ubuntu24.04 ;;
        *debian*) echo debian12 ;;
        *windows11*|*win11*) echo win11 ;;
        *windows10*|*win10*) echo win10 ;;
        *win_ent_7*|*windows*7*|sw_dvd5_sa_win_ent_7*) echo win7 ;;
        *windows_nt_5.10*|*windows_nt_5_10*|*nt_5.10*|*bartpe*) echo winxp ;;
        *windows_nt_5*|*nt_5.00*) echo win2k ;;
        *windows_nt_4*|*nt_4*) echo winnt4.0 ;;
        *freedos*|*fd14*|*fohdeesha-freedos*) echo freedos1.3 ;;
        *qubes*) echo linux2022 ;;
        *dragonos*) echo ubuntu24.04 ;;
        *debian*13*) echo debian13 ;;
        *firmware*|*netinst*|*hbcd*) echo generic ;;
        *) echo generic ;;
    esac
}

unique_name() {
    local base="$1" name="$1" n=2
    while virsh -c "$CONN" dominfo "$name" &>/dev/null; do
        name="${base}-${n}"
        n=$((n + 1))
        (( n < 100 )) || die "too many name collisions for $base"
    done
    printf '%s\n' "$name"
}

ensure_kvm() {
    if [[ -e /dev/kvm ]] && [[ ! -r /dev/kvm || ! -w /dev/kvm ]]; then
        sudo setfacl -m "u:$(id -un):rw" /dev/kvm 2>/dev/null || true
    fi
}

# Old Windows / DOS lack virtio inbox drivers. Use IDE + pcnet/rtl8139 + cirrus.
is_legacy_guest() {
    local path="$1" lower
    lower="$(basename "$path" | tr '[:upper:]' '[:lower:]')"
    case "$lower" in
        *windows_nt*|*win_ent_7*|*win*7*|*freedos*|*fd14*|*bartpe*|*hbcd*) return 0 ;;
        *fohdeesha-freedos*) return 0 ;;
    esac
    # path under Windows NT ISOs
    case "$path" in
        *"/Windows NT ISOs/"*|*"/windows nt isos/"*) return 0 ;;
    esac
    return 1
}

legacy_nic_for_iso() {
    local path="$1" lower
    lower="$(basename "$path" | tr '[:upper:]' '[:lower:]')"
    case "$lower" in
        *windows_nt_4*|*windows_nt_5.00*|*nt_4*|*nt_5.00*|*freedos*|*fd14*)
            echo pcnet  # AMD PCnet — best inbox for Win2000 / NT4 / DOS
            ;;
        *)
            echo rtl8139  # Realtek — XP / Win7 often have drivers
            ;;
    esac
}

create_vm() {
    local iso="$1"
    local base name title mem vcpus disk img osv
    local disk_bus net_model video extra_args

    base="$(sanitize_name "$(basename "$iso")")"
    # Prefix perc/ for clarity
    if [[ "$iso" == *"/perc/"* ]]; then
        base="perc-${base#perc-}"
        base="$(sanitize_name "$base")"
    fi
    if [[ "$iso" == *"/Windows NT ISOs/"* ]] || [[ "$iso" == *"/windows nt isos/"* ]]; then
        base="nt-$(sanitize_name "$(basename "$iso")")"
        base="$(sanitize_name "$base")"
    fi

    title="$(pretty_title "$iso")"
    if [[ "$iso" == *"/perc/"* ]]; then
        title="PERC $title"
    fi

    read -r mem vcpus disk <<<"$(profile_for_iso "$iso")"
    osv="$(os_variant_for_iso "$iso")"

    if is_legacy_guest "$iso"; then
        disk_bus=ide
        net_model="$(legacy_nic_for_iso "$iso")"
        video=cirrus
        extra_args=()
    else
        disk_bus=virtio
        net_model=virtio
        video=virtio
        extra_args=(--channel spicevmc)
    fi

    if virsh -c "$CONN" dominfo "$base" &>/dev/null; then
        if [[ "$FORCE" == 1 ]]; then
            log "FORCE: redefine $base"
            virsh -c "$CONN" destroy "$base" 2>/dev/null || true
            virsh -c "$CONN" managedsave-remove "$base" 2>/dev/null || true
            virsh -c "$CONN" undefine "$base" --managed-save --snapshots-metadata --nvram 2>/dev/null \
                || virsh -c "$CONN" undefine "$base" --managed-save --snapshots-metadata 2>/dev/null \
                || virsh -c "$CONN" undefine "$base" 2>/dev/null || true
            rm -f "$IMG_DIR/$base"
        else
            log "skip (exists): $base  ←  $(basename "$iso")"
            return 0
        fi
        name="$base"
    else
        name="$(unique_name "$base")"
    fi

    img="$IMG_DIR/$name"
    log "create: $name"
    log "  title=$title mem=${mem}M vcpus=$vcpus disk=${disk}G bus=$disk_bus nic=$net_model video=$video"
    log "  iso=$iso"

    if [[ "$DRY_RUN" == 1 ]]; then
        return 0
    fi

    mkdir -p "$IMG_DIR"
    qemu-img create -f qcow2 "$img" "${disk}G" >/dev/null

    virt-install \
        --connect "$CONN" \
        --name "$name" \
        --metadata "title=${title}" \
        --memory "$mem" \
        --vcpus "$vcpus" \
        --disk "path=${img},format=qcow2,bus=${disk_bus}" \
        --cdrom "$iso" \
        --os-variant "$osv" \
        --graphics spice,listen=none \
        --video "$video" \
        "${extra_args[@]}" \
        --network "user,model=${net_model}" \
        --boot cdrom,hd \
        --noautoconsole \
        --check path_in_use=off \
        >/dev/null

    # virt-install starts by default for cdrom boot; shut off unless START=1.
    if [[ "$START" != 1 ]]; then
        virsh -c "$CONN" destroy "$name" 2>/dev/null || true
    fi
    log "ok: $name"
}

list_isos() {
    find "$WIGGLY_MOUNT" -type f \( -iname '*.iso' -o -iname '*.ISO' \) \
        ! -path '*/.Trash-*/*' ! -path '*/lost+found/*' | sort
}

main() {
    command -v virt-install >/dev/null || die "virt-install missing (apt install virtinst)"
    command -v qemu-img >/dev/null || die "qemu-img missing"
    command -v virsh >/dev/null || die "virsh missing"
    mount_wiggly
    ensure_kvm
    mkdir -p "$IMG_DIR"

    local iso count=0
    while IFS= read -r iso; do
        [[ -f "$iso" ]] || continue
        create_vm "$iso"
        count=$((count + 1))
    done < <(list_isos)

    log "Processed $count ISO(s) from Uncle Wiggly 🥕🐰"
    log "Domains:"
    virsh -c "$CONN" list --all
}

main "$@"
