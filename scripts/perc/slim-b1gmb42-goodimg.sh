#!/usr/bin/env bash
# Remove non-H710-full-size files from mounted good.img (B1GMB42 slim).
# Keep BIGB0*/BIGD1* crossflash + revert + core flash tools only.
set -euo pipefail

MNT="${1:?mounted good.img path}"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

keep_pattern() {
    local f="$1"
    case "$f" in
        BIGB0*|BIGD1*|BIG710.ROM|BIGPB0MD.SBR|BIGPD1MD.SBR) return 0 ;;
        INFO.BAT|MEGACLI.EXE|MEGAREC.EXE|SAS2FLSH.EXE|SAS3FLSH.EXE) return 0 ;;
        DUMPALL.BAT|REBOOT.BAT|SBRDUMP.BAT|MPTBIOS.TXT) return 0 ;;
        GREP.EXE|FIND.COM|FDAPM.COM|DOS4GW.EXE|CWSDPMI.EXE|SYS.COM) return 0 ;;
        MPT3X64.ROM|MPTSAS3.ROM) return 0 ;;
        COMMAND.COM|CONFIG.SYS|KERNEL.SYS|AUTOEXEC.BAT|UMBPCI.SYS) return 0 ;;
        DOCS.BAT|VIEW.BAT|MDVIEW.BAT|FLASHME.BAT|QBASDOWN.EXE) return 0 ;;
        BIOS.TXT|B1GMB42.TXT|SASADDR.TXT|PHASE2.TXT|README.TXT) return 0 ;;
        FDOS) return 0 ;;
        INDIANELL) return 0 ;;
        DELLH710.ROM) return 0 ;;
    esac
    return 1
}

slim_goodimg() {
    local f upper removed=0
    for f in "$MNT"/*; do
        [[ -e "$f" ]] || continue
        [[ -d "$f" ]] && continue
        upper="$(basename "$f" | tr '[:lower:]' '[:upper:]')"
        if keep_pattern "$upper"; then
            continue
        fi
        sudo rm -f "$f"
        removed=$((removed + 1))
    done
    log "Slim B1GMB42: removed $removed non-H710-full-size files from $(basename "$MNT")"
}

slim_goodimg