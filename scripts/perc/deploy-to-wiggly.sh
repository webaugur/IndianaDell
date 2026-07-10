#!/usr/bin/env bash
# Deploy PERC IT-mode ISOs to internal Wiggly Ventoy (Seagate sdc1) — never USB Ventoy.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib/wiggly-ventoy.sh
source "$ROOT/scripts/perc/lib/wiggly-ventoy.sh"

CACHE="${PERC_CACHE:-$ROOT/.cache/perc-crossflash}"
EXTRACT="$CACHE/extract"
VENTOY_SRC="$ROOT/scripts/ventoy/ventoy.json"

PERC_DIR="perc"
FREEDOS_NAME="fohdeesha-freedos.iso"
LINUX_NAME="fohdeesha-linux.iso"

log() { wiggly_log "$*" >&2; }
die() { wiggly_die "$*"; }

pick_isos() {
    local freedos="" linux=""
    local patched="$CACHE/fohdeesha-freedos-patched.iso"

    if [[ -f "$patched" ]]; then
        freedos="$patched"
        log "Using patched FreeDOS ISO with IndianaDell docs"
    fi

    local iso base lower
    while IFS= read -r iso; do
        base="$(basename "$iso")"
        lower="${base,,}"
        if [[ -z "$freedos" && "$lower" == *freedos* ]]; then
            freedos="$iso"
        elif [[ "$lower" == *linux* ]]; then
            linux="$iso"
        fi
    done < <(find "$EXTRACT" -iname '*.iso' | sort)

    [[ -n "$freedos" && -n "$linux" ]] || die "Missing FreeDOS/Linux ISO — run download-fohdeesha.sh and patch-freedos-iso.sh"
    printf '%s\n%s\n' "$freedos" "$linux"
}

merge_ventoy_json() {
    local dest="$1"
    [[ -f "$VENTOY_SRC" ]] || die "Missing $VENTOY_SRC"
    mkdir -p "$(dirname "$dest")"
    cp -f "$VENTOY_SRC" "$dest"
    sync
    log "Installed ventoy.json -> $dest"
}

write_readme() {
    local dest="$1"
    cat >"$dest" <<'EOF'
B1GMB42 PERC H710 IT-mode flash (internal Ventoy on Wiggly)
===========================================================

This folder is on the INTERNAL Seagate Ventoy partition (label Wiggly, sdc1).
Do NOT copy these ISOs to the USB Ventoy stick (sdd).

Boot: BIOS -> internal disk / Ventoy -> pick an ISO below.

  fohdeesha-freedos.iso   Phase 1 — memdisk (auto). DOCS / VIEW PERC-FLASH
  fohdeesha-linux.iso     Phase 2 — setsas + finish IT flash

Full procedure: ~/Documents/IndianaDell/docs/B1GMB42-perc-it-flash.md

Redeploy from Ubuntu:
  cd ~/Documents/IndianaDell && bin/setup-perc-ventoy
EOF
}

main() {
    [[ -d "$EXTRACT" ]] || die "No extract dir $EXTRACT — run scripts/perc/download-fohdeesha.sh"

    wiggly_mount
    wiggly_assert_ventoy_tree "$WIGGLY_MOUNT"

    mapfile -t isos < <(pick_isos)
    local freedos="${isos[0]}" linux="${isos[1]}"
    local perc_root="$WIGGLY_MOUNT/$PERC_DIR"

    mkdir -p "$perc_root"
    log "Copying FreeDOS -> $perc_root/$FREEDOS_NAME"
    cp -f "$freedos" "$perc_root/$FREEDOS_NAME"
    log "Copying Linux  -> $perc_root/$LINUX_NAME"
    cp -f "$linux" "$perc_root/$LINUX_NAME"
    write_readme "$perc_root/README-B1GMB42.txt"
    merge_ventoy_json "$WIGGLY_MOUNT/ventoy/ventoy.json"
    sync

    log "Deployed PERC kit to internal Wiggly ($WIGGLY_MOUNT/$PERC_DIR)"
    ls -lh "$perc_root"
    cat <<EOF

Internal Ventoy (Wiggly) ready for PERC IT flash.
  Device:  $WIGGLY_DEV
  Mount:   $WIGGLY_MOUNT
  ISOs:    $perc_root/$FREEDOS_NAME
           $perc_root/$LINUX_NAME

Reboot -> Ventoy on INTERNAL disk (not USB) -> fohdeesha-freedos.iso first.
See docs/B1GMB42-perc-it-flash.md
EOF
}

main "$@"