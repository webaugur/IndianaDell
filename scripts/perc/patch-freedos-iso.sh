#!/usr/bin/env bash
# Patch Fohdeesha FreeDOS ISO: inject IndianaDell docs + QBASDOWN + VIEW/DOCS menus.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CACHE="${PERC_CACHE:-$ROOT/.cache/perc-crossflash}"
EXTRACT="$CACHE/extract"
STAGE="$CACHE/dos-docs"
WORKDIR="$CACHE/freedos-patched"
SRC_ISO="$EXTRACT/PERC Mini Crossflashing/deesh-FreeDOS-v2.5.iso"
OUT_ISO="$CACHE/fohdeesha-freedos-patched.iso"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { log "ERROR: $*"; exit 1; }

cleanup_loop() {
    local mnt="$1" img="$2"
    mountpoint -q "$mnt" && sudo umount "$mnt"
    local loop
    loop="$(losetup -j "$img" 2>/dev/null | cut -d: -f1 | head -1 || true)"
    [[ -n "$loop" ]] && sudo losetup -d "$loop" 2>/dev/null || true
}

patch_good_img() {
    local src_img="$1" dst_img="$2"
    local mnt="$WORKDIR/goodmnt"

    if [[ "$(readlink -f "$src_img")" != "$(readlink -f "$dst_img")" ]]; then
        cp -f "$src_img" "$dst_img"
    fi
    mkdir -p "$mnt"
    cleanup_loop "$mnt" "$dst_img"

    local loop
    loop="$(sudo losetup -fP --show "$dst_img")"
    sudo mount -o rw "$loop"p1 "$mnt"

    log "Injecting IndianaDell docs into good.img"
    sudo cp -f "$STAGE/DOCS.BAT" "$STAGE/VIEW.BAT" "$STAGE/MDVIEW.BAT" "$STAGE/FLASHME.BAT" "$STAGE/QBASDOWN.EXE" "$mnt/"
    sudo cp -f "$STAGE/BIOS.TXT" "$STAGE/B1GMB42.TXT" "$STAGE/SASADDR.TXT" "$STAGE/PHASE2.TXT" "$mnt/"
    [[ -f "$STAGE/DELLH710.ROM" ]] && sudo cp -f "$STAGE/DELLH710.ROM" "$mnt/"
    sudo mkdir -p "$mnt/INDIANELL"
    sudo cp -f "$STAGE/INDIANELL/"* "$mnt/INDIANELL/"

    bash "$ROOT/scripts/perc/slim-b1gmb42-goodimg.sh" "$mnt"

    if ! sudo grep -qi 'FLASHME' "$mnt/AUTOEXEC.BAT" 2>/dev/null; then
        {
            echo ""
            echo "ECHO."
            echo "ECHO B1GMB42 Wiggly Ventoy - FLASHME for PERC wizard, DOCS for manuals"
            echo "ECHO Full-size H710 only: INFO then BIGB0CRS or BIGD1CRS"
        } | sed 's/$/\r/' | sudo tee -a "$mnt/AUTOEXEC.BAT" >/dev/null
    fi

    sync
    cleanup_loop "$mnt" "$dst_img"
}

repack_iso() {
    local src="$1" dst="$2" good="$3"
    command -v xorriso >/dev/null || die "xorriso required to repack FreeDOS ISO (apt install xorriso)"

    sudo rm -rf "$WORKDIR/isoroot"
    mkdir -p "$WORKDIR/isoroot"
    xorriso -osirrox on -indev "$src" -extract / "$WORKDIR/isoroot" 2>/dev/null
    sudo cp -f "$good" "$WORKDIR/isoroot/isolinux/good.img"
    sudo chown -R "$(id -u):$(id -g)" "$WORKDIR/isoroot" 2>/dev/null || true

    xorriso -as mkisofs \
        -o "$dst" \
        -r -J -joliet-long \
        -b isolinux/isolinux.bin \
        -c isolinux/boot.cat \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -eltorito-alt-boot \
        -e isolinux/memdisk \
        -no-emul-boot \
        -isohybrid-gpt-basdat \
        "$WORKDIR/isoroot" 2>/dev/null || \
    xorriso -as mkisofs \
        -o "$dst" \
        -r -J \
        -b isolinux/isolinux.bin \
        -c isolinux/boot.cat \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -eltorito-alt-boot \
        -e isolinux/memdisk \
        -no-emul-boot \
        "$WORKDIR/isoroot"

    log "Repacked ISO -> $dst ($(du -b "$dst" | awk '{printf "%.1fMB", $1/1048576}'))"
}

main() {
    [[ -f "$SRC_ISO" ]] || die "Missing $SRC_ISO — run download-fohdeesha.sh"
    bash "$ROOT/scripts/perc/prepare-dos-docs.sh"

    mkdir -p "$WORKDIR"
    local good="$WORKDIR/good.img"
    if ! xorriso -osirrox on -indev "$SRC_ISO" -extract /isolinux/good.img "$good" 2>/dev/null; then
        local mnt_iso="$WORKDIR/isomnt"
        mkdir -p "$mnt_iso"
        sudo mount -o loop,ro "$SRC_ISO" "$mnt_iso"
        cp -f "$mnt_iso/isolinux/good.img" "$good"
        sudo umount "$mnt_iso"
    fi
    [[ -f "$good" ]] || die "Cannot extract good.img from $SRC_ISO"

    patch_good_img "$good" "$good"
    repack_iso "$SRC_ISO" "$OUT_ISO" "$good"
    printf '%s\n' "$OUT_ISO"
}

main "$@"