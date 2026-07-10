#!/usr/bin/env bash
# Stage IndianaDell markdown + plain-text copies for injection into FreeDOS good.img.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STAGE="${PERC_DOS_DOCS:-$ROOT/.cache/perc-crossflash/dos-docs}"
QBASDOWN_CACHE="$ROOT/.cache/perc-crossflash/qbasdown.exe"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { log "ERROR: $*"; exit 1; }

dos_basename() {
    local rel="$1"
    local base="${rel%.md}"
    base="${base//\//-}"
    base="${base//_/-}"
    printf '%s' "$base" | tr '[:lower:]' '[:upper:]'
}

fetch_qbasdown() {
    [[ -f "$QBASDOWN_CACHE" ]] && return 0
    local zip="$ROOT/.cache/perc-crossflash/qbasdown_dos.zip"
    mkdir -p "$(dirname "$QBASDOWN_CACHE")"
    if [[ ! -f "$zip" ]]; then
        log "Downloading QBASDOWN (DOS markdown -> HTML)"
        curl -fL --retry 3 -o "$zip" \
            "https://raw.githubusercontent.com/clasqm/QBASDOWN/master/binaries/0.8.1/qbasdown_dos_0.8.1.zip"
    fi
    unzip -p "$zip" qbasdown.exe >"$QBASDOWN_CACHE"
    chmod +x "$QBASDOWN_CACHE"
}

prepare_one() {
    local src="$1"
    local rel="${src#$ROOT/}"
    local name
    name="$(dos_basename "$rel")"
    local md_out="$STAGE/${name}.MD"
    local txt_out="$STAGE/${name}.TXT"

    cp -f "$src" "$md_out"
    if command -v unix2dos >/dev/null; then
        unix2dos -q "$md_out" 2>/dev/null || unix2dos "$md_out"
    else
        sed -i 's/$/\r/' "$md_out"
    fi

    if command -v pandoc >/dev/null; then
        pandoc -f markdown -t plain --wrap=none -o "$txt_out" "$src"
        if command -v unix2dos >/dev/null; then
            unix2dos -q "$txt_out" 2>/dev/null || unix2dos "$txt_out"
        else
            sed -i 's/$/\r/' "$txt_out"
        fi
    else
        cp -f "$md_out" "$txt_out"
    fi
    printf '%s\t%s\n' "$rel" "$name" >>"$STAGE/INDEX.tsv"
}

write_bats() {
    cat >"$STAGE/DOCS.BAT" <<'EOF'
@ECHO OFF
CLS
ECHO ============================================================
ECHO  IndianaDell documentation (Tower5810 / B1GMB42)
ECHO ============================================================
ECHO.
ECHO  Quick start:
ECHO    PERC-FLASH.TXT  - IT-mode flash procedure (read this first)
ECHO    HARDWARE.TXT    - slots, SATA, PERC layout
ECHO.
ECHO  View any file:
ECHO    VIEW PERC-FLASH
ECHO    VIEW HARDWARE
ECHO    (opens .TXT in FreeDOS EDIT; .MD available for QBASDOWN)
ECHO.
ECHO  Markdown to HTML:
ECHO    MDVIEW PERC-FLASH
ECHO.
ECHO  List all manuals:
ECHO    TYPE INDIANELL\INDEX.TXT
ECHO.
ECHO  PERC flash wizard:
ECHO    FLASHME  - step-by-step H710 IT flash
ECHO.
ECHO  PERC flash commands (after INFO):
ECHO    BIGB0CRS / BIGD1CRS  then reboot to Linux ISO on Wiggly
ECHO ============================================================
PAUSE
EOF

    cat >"$STAGE/VIEW.BAT" <<'EOF'
@ECHO OFF
IF "%1"=="" GOTO USAGE
IF EXIST INDIANELL\%1.TXT (
  FDOS\EDIT.EXE INDIANELL\%1.TXT
  GOTO END
)
IF EXIST INDIANELL\%1.MD (
  FDOS\EDIT.EXE INDIANELL\%1.MD
  GOTO END
)
ECHO Not found: INDIANELL\%1.TXT or .MD
:USAGE
ECHO Usage: VIEW PERC-FLASH
:END
EOF

    cat >"$STAGE/MDVIEW.BAT" <<'EOF'
@ECHO OFF
IF "%1"=="" GOTO USAGE
IF NOT EXIST INDIANELL\%1.MD (
  ECHO Not found: INDIANELL\%1.MD
  GOTO END
)
QBASDOWN.EXE INDIANELL\%1.MD --silent
IF EXIST INDIANELL\%1.HTM FDOS\EDIT.EXE INDIANELL\%1.HTM
:USAGE
ECHO Usage: MDVIEW PERC-FLASH
:END
EOF

    unix2dos -q "$STAGE"/*.BAT 2>/dev/null || sed -i 's/$/\r/' "$STAGE"/*.BAT 2>/dev/null || true
}

write_machine_files() {
    cat >"$STAGE/BIOS.TXT" <<'EOF'
B1GMB42 / T5810 — BIOS settings for PERC IT flash (F2)
======================================================

Before FreeDOS flash:
  Boot Mode .............. BIOS (not UEFI); return to UEFI after flash
  Virtualization ......... Disabled
  SR-IOV / I/OAT ......... Disabled if present
  Legacy Option ROMs ..... Enabled
  OROM Keyboard Access ... Enable

Boot target:
  Internal Seagate Ventoy (partition label Wiggly, sdc1, SATA)
  NOT the USB Ventoy stick (sdd)

After flash:
  Restore Virtualization if you use VMs
  Boot Mode back to UEFI if desired
  Phase 2: boot perc/fohdeesha-linux.iso on Wiggly (not memdisk)
EOF

    cat >"$STAGE/B1GMB42.TXT" <<'EOF'
B1GMB42 machine card (Tower5810)
================================
Service tag .............. B1GMB42
Host name ................ Tower5810
PERC ..................... H710 full-size, PCIe Slot5 (07:00.0)
SAS cables / drives ...... None (pulled from server; no backplane)
ZFS rpool ................ Motherboard SATA (Hitachi + TEAM) — not on PERC
Ventoy for this flash .... Wiggly (internal Seagate), NOT USB

FreeDOS commands (full-size H710 only):
  INFO ................. identify B0 vs D1 + SAS address
  BIGB0CRS / BIGD1CRS .. IT crossflash (phase 1)
  BIGB0RVT / BIGD1RVT .. revert to Dell firmware

Optional: DELLH710.ROM — stock Dell FW if placed in image root for recovery
EOF

    cat >"$STAGE/SASADDR.TXT" <<'EOF'
Paste output from INFO here (especially SAS Address):
=====================================================

Card type:
Revision (B0 or D1):
SAS Address:

EOF

    cat >"$STAGE/PHASE2.TXT" <<'EOF'
Phase 2 — after FreeDOS crossflash + reboot
===========================================
Boot Ventoy on INTERNAL Wiggly (not USB).
Select: perc/fohdeesha-linux.iso  (normal boot, NOT memdisk)

  sudo su
  B0-H710     (if INFO showed B0 full-size H710)
  D1-H710     (if INFO showed D1 full-size H710)
  setsas <SAS_ADDRESS_FROM_SASADDR.TXT>
  flashboot /root/Bootloaders/x64sas2.rom   (optional UEFI ROM)
  reboot

Verify in Ubuntu:
  dmesg | grep -i mpt
  lsmod | grep mpt2sas
EOF

    cat >"$STAGE/FLASHME.BAT" <<'EOF'
@ECHO OFF
CLS
ECHO ============================================================
ECHO  B1GMB42 PERC H710 IT flash wizard (full-size Slot5)
ECHO ============================================================
ECHO.
ECHO  0) TYPE BIOS.TXT and B1GMB42.TXT if you have not already
ECHO  1) Run INFO — note SAS Address and B0 vs D1
ECHO  2) EDIT SASADDR.TXT — paste INFO output
ECHO  3) Run BIGB0CRS (B0) or BIGD1CRS (D1) — NOT mini/blade scripts
ECHO  4) REBOOT to perc/fohdeesha-linux.iso on internal Wiggly
ECHO  5) See PHASE2.TXT / VIEW PERC-FLASH
ECHO.
ECHO  Revert: BIGB0RVT or BIGD1RVT
ECHO ============================================================
PAUSE
CLS
ECHO Running INFO now...
CALL INFO.BAT
ECHO.
ECHO Opening SASADDR.TXT — paste the SAS Address line, save, exit EDIT.
PAUSE
FDOS\EDIT.EXE SASADDR.TXT
ECHO.
ECHO If revision was B0, type: BIGB0CRS
ECHO If revision was D1, type: BIGD1CRS
ECHO Then REBOOT to Linux ISO on Wiggly. TYPE PHASE2.TXT for details.
PAUSE
EOF

    for f in BIOS.TXT B1GMB42.TXT SASADDR.TXT PHASE2.TXT; do
        if command -v unix2dos >/dev/null; then
            unix2dos -q "$STAGE/$f" 2>/dev/null || unix2dos "$STAGE/$f"
        else
            sed -i 's/$/\r/' "$STAGE/$f"
        fi
    done
    unix2dos -q "$STAGE/FLASHME.BAT" 2>/dev/null || sed -i 's/$/\r/' "$STAGE/FLASHME.BAT"
}

write_index() {
    {
        echo "IndianaDell manuals (basename -> repo path)"
        echo "VIEW <basename>  opens .TXT in EDIT"
        echo "MDVIEW <basename> renders .MD to .HTM via QBASDOWN"
        echo ""
        sort -t $'\t' -k2 "$STAGE/INDIANELL/INDEX.tsv" | while IFS=$'\t' read -r rel name; do
            printf '%-28s %s\n' "$name" "$rel"
        done
    } >"$STAGE/INDEX.txt"
    unix2dos -q "$STAGE/INDEX.txt" 2>/dev/null || sed -i 's/$/\r/' "$STAGE/INDEX.txt"
}

main() {
    command -v pandoc >/dev/null || die "pandoc required to build plain-text doc copies"
    rm -rf "$STAGE"
    mkdir -p "$STAGE/INDIANELL"
    : >"$STAGE/INDEX.tsv"

    fetch_qbasdown
    cp -f "$QBASDOWN_CACHE" "$STAGE/QBASDOWN.EXE"

    log "Collecting IndianaDell .md files"
    while IFS= read -r -d '' md; do
        prepare_one "$md"
        cp -f "$STAGE/$(dos_basename "${md#$ROOT/}").MD" "$STAGE/INDIANELL/"
        cp -f "$STAGE/$(dos_basename "${md#$ROOT/}").TXT" "$STAGE/INDIANELL/"
    done < <(find "$ROOT" -name '*.md' ! -path '*/.git/*' ! -path '*/Themes/*' -print0 | sort -z)

    mv "$STAGE/INDEX.tsv" "$STAGE/INDIANELL/INDEX.tsv"
    write_index
    cp -f "$STAGE/INDEX.txt" "$STAGE/INDIANELL/INDEX.TXT"

    # Short 8.3-friendly aliases for DOCS.BAT / VIEW.BAT
    alias_doc() {
        local src="$1" dst="$2"
        [[ "$src" != "$dst" ]] || return 0
        [[ -f "$STAGE/INDIANELL/${src}.TXT" ]] || return 0
        cp -f "$STAGE/INDIANELL/${src}.TXT" "$STAGE/INDIANELL/${dst}.TXT"
        cp -f "$STAGE/INDIANELL/${src}.MD"  "$STAGE/INDIANELL/${dst}.MD"
    }
    alias_doc DOCS-B1GMB42-PERC-IT-FLASH PERC-FLASH
    alias_doc B1GMB42-SLOT-PORT-INVENTORY HARDWARE
    alias_doc DOCS-B1GMB42-ZFS-RECOVERY ZFS-RECOVERY

    write_bats
    write_machine_files

    # Optional stock Dell H710 ROM for revert (drop in FactoryDocs/_incoming/ or scripts/perc/firmware/)
    local dell_rom=""
    for dell_rom in \
        "$ROOT/scripts/perc/firmware/DELLH710.ROM" \
        "$ROOT/FactoryDocs/_incoming/"*H710*.rom \
        "$ROOT/FactoryDocs/_incoming/"*h710*.ROM; do
        [[ -f "$dell_rom" ]] || continue
        cp -f "$dell_rom" "$STAGE/DELLH710.ROM"
        log "Bundled stock Dell ROM: $(basename "$dell_rom")"
        break
    done

    log "Staged $(find "$STAGE/INDIANELL" -name '*.TXT' | wc -l) docs under $STAGE"
}

main "$@"