#!/usr/bin/env bash
# Boot Uncle Wiggly 🥕🐰 Ubuntu live + casper-rw persistence in a local VM.
#
# Uses QEMU/KVM (what GNOME Boxes uses under the hood). GNOME Boxes alone cannot
# attach the persistence .dat as a casper-rw volume with the live ISO.
#
# Opens a GTK display window. Kernel cmdline includes `persistent` so the overlay
# is used automatically (no GRUB edit needed).
set -euo pipefail

ISO="${UNCLE_WIGGLY_ISO:-}"
DAT="${UNCLE_WIGGLY_DAT:-}"
WIGGLY_MOUNT="${WIGGLY_MOUNT:-/mnt/wiggly}"
MEM_MB="${VM_MEM_MB:-4096}"
SMP="${VM_SMP:-4}"
NAME="${VM_NAME:-uncle-wiggly}"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { log "ERROR: $*"; exit 1; }

find_media() {
    local candidate
    if [[ -z "$ISO" ]]; then
        for candidate in \
            "$WIGGLY_MOUNT/ubuntu-26.04-desktop-amd64.iso" \
            /run/media/*/Wiggly/ubuntu-26.04-desktop-amd64.iso \
            /media/*/Wiggly/ubuntu-26.04-desktop-amd64.iso; do
            if [[ -f "$candidate" ]]; then
                ISO="$candidate"
                break
            fi
        done
    fi
    if [[ -z "$DAT" ]]; then
        for candidate in \
            "$WIGGLY_MOUNT/persistence/ubuntu-26.04.dat" \
            /run/media/*/Wiggly/persistence/ubuntu-26.04.dat \
            /media/*/Wiggly/persistence/ubuntu-26.04.dat; do
            if [[ -f "$candidate" ]]; then
                DAT="$candidate"
                break
            fi
        done
    fi
    [[ -f "${ISO:-}" ]] || die "Ubuntu ISO not found (mount Uncle Wiggly / label Wiggly)"
    [[ -f "${DAT:-}" ]] || die "persistence .dat not found"
}

ensure_kvm() {
    if [[ ! -e /dev/kvm ]]; then
        log "warning: /dev/kvm missing — software emulation (slow)"
        return 1
    fi
    if [[ ! -r /dev/kvm || ! -w /dev/kvm ]]; then
        if command -v sudo >/dev/null; then
            sudo setfacl -m "u:$(id -un):rw" /dev/kvm 2>/dev/null || true
        fi
    fi
    [[ -r /dev/kvm && -w /dev/kvm ]]
}

# Copy kernel/initrd out of ISO so QEMU can pass `persistent` on the cmdline.
extract_casper_boot() {
    local iso="$1" work="$2"
    local mnt="$work/iso"
    mkdir -p "$mnt" "$work/boot"
    if ! mountpoint -q "$mnt"; then
        sudo mount -o loop,ro "$iso" "$mnt"
    fi
    [[ -f "$mnt/casper/vmlinuz" ]] || die "no casper/vmlinuz in ISO"
    [[ -f "$mnt/casper/initrd" ]] || die "no casper/initrd in ISO"
    # Copy to user-writable paths for qemu -kernel
    cp -f "$mnt/casper/vmlinuz" "$work/boot/vmlinuz"
    cp -f "$mnt/casper/initrd" "$work/boot/initrd"
    sudo umount "$mnt" 2>/dev/null || true
}

main() {
    command -v qemu-system-x86_64 >/dev/null || die "qemu-system-x86_64 not installed (apt install qemu-system-x86)"
    find_media

    local work="${XDG_CACHE_HOME:-$HOME/.cache}/uncle-wiggly-vm"
    mkdir -p "$work"
    extract_casper_boot "$ISO" "$work"

    local kvm_args=()
    if ensure_kvm; then
        kvm_args=(-enable-kvm -cpu host)
        log "KVM acceleration ON"
    else
        kvm_args=(-cpu max)
        log "KVM off (slow)"
    fi

    log "Uncle Wiggly 🥕🐰 VM"
    log "  ISO:  $ISO"
    log "  DAT:  $DAT  (label casper-rw persistence)"
    log "  RAM:  ${MEM_MB}M  CPUs: $SMP"
    log "  Note: uses live session + persistence overlay (not a full install)"

    # Second raw disk = entire casper-rw filesystem (label already set).
    # boot=casper + persistent picks it up like Ventoy would.
    exec qemu-system-x86_64 \
        "${kvm_args[@]}" \
        -name "$NAME" \
        -m "$MEM_MB" \
        -smp "$SMP" \
        -machine q35,accel=kvm:tcg \
        -drive "file=${DAT},format=raw,if=virtio,cache=writeback" \
        -drive "file=${ISO},media=cdrom,readonly=on,if=ide" \
        -kernel "$work/boot/vmlinuz" \
        -initrd "$work/boot/initrd" \
        -append "boot=casper persistent username=ubuntu hostname=ubuntu quiet splash ---" \
        -device virtio-net-pci,netdev=n0 \
        -netdev user,id=n0 \
        -device qemu-xhci \
        -device usb-tablet \
        -display gtk,gl=on \
        -vga virtio \
        "$@"
}

main "$@"
