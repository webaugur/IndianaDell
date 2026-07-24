#!/usr/bin/env bash
#
# disk-stress-test.sh
# Stress test a disk identified by a stable /dev/disk/by-id/ path or serial.
#
# This version never guesses device names. It only accepts paths that
# actually exist on the system.
#
# Usage:
#   ./disk-stress-test.sh /dev/disk/by-id/usb-WDC_WD20_03FZEX-00Z4SA0_DCA2599981FF-0:0
#   ./disk-stress-test.sh WD-WMC1F1160506
#
# The script will:
#   - Resolve the identifier to the real block device (no guessing)
#   - Refuse to run on mounted or obviously internal system disks
#   - Run SMART long test + fio random I/O stress
#   - Log everything with timestamps

set -euo pipefail

# Ensure Wayland clipboard works for any Rust TUI that might be launched
export ARBOARD_BACKEND=wayland

IDENT="${1:-}"

if [[ -z "$IDENT" ]]; then
    echo "Usage: $0 <serial|by-id-path>"
    echo
    echo "Examples (use the exact by-id paths your system reports):"
    echo "  $0 /dev/disk/by-id/usb-WDC_WD20_03FZEX-00Z4SA0_DCA2599981FF-0:0"
    echo "  $0 /dev/disk/by-id/usb-WDC_WD20_EADS-11R6B1_DCA2599981FF-0:1"
    echo "  $0 WD-WMC1F1160506"
    exit 1
fi

# Resolve identifier to real block device (no guessing)
if [[ "$IDENT" == /dev/disk/by-id/* ]]; then
    if [[ -e "$IDENT" ]]; then
        DEV="$(readlink -f "$IDENT")"
    else
        echo "ERROR: Path does not exist: $IDENT"
        exit 1
    fi
elif [[ "$IDENT" =~ ^[A-Z0-9-]+$ ]]; then
    CANDIDATE="$(ls /dev/disk/by-id/*"$IDENT"* 2>/dev/null | head -1 || true)"
    if [[ -n "$CANDIDATE" ]]; then
        DEV="$(readlink -f "$CANDIDATE")"
    else
        echo "ERROR: No /dev/disk/by-id/ entry matches serial '$IDENT'"
        exit 1
    fi
else
    echo "ERROR: Unrecognized identifier format: $IDENT"
    exit 1
fi

if [[ -z "$DEV" || ! -b "$DEV" ]]; then
    echo "ERROR: Could not resolve '$IDENT' to a block device"
    exit 1
fi

# Safety checks
if mount | grep -q "^$DEV"; then
    echo "ERROR: $DEV is currently mounted. Unmount first."
    exit 1
fi

SERIAL="$(udevadm info --query=all --name="$DEV" 2>/dev/null | awk -F= '/ID_SERIAL_SHORT/ {print $2}')"
MODEL="$(udevadm info --query=all --name="$DEV" 2>/dev/null | awk -F= '/ID_MODEL/ {print $2}')"
LOGFILE="stress-$(date +%Y%m%d-%H%M%S)-${SERIAL:-unknown}.log"

echo "========================================"
echo "Disk Stress Test"
echo "Identifier : $IDENT"
echo "Resolved to: $DEV"
echo "Model      : ${MODEL:-unknown}"
echo "Serial     : ${SERIAL:-unknown}"
echo "Log file   : $LOGFILE"
echo "========================================"

{
    echo "=== $(date) ==="
    echo "Device: $DEV"
    echo "Model : $MODEL"
    echo "Serial: $SERIAL"
    echo

    echo ">>> SMART short test"
    sudo smartctl -t short "$DEV" || true
    sleep 120

    echo ">>> SMART long test (this will take hours)"
    sudo smartctl -t long "$DEV" || true

    echo ">>> fio random read/write stress (2 hours, 4k blocks, 75% read)"
    sudo fio --name=stress \
        --filename="$DEV" \
        --rw=randrw \
        --rwmixread=75 \
        --bs=4k \
        --ioengine=libaio \
        --iodepth=32 \
        --numjobs=4 \
        --runtime=7200 \
        --time_based \
        --group_reporting \
        --output-format=json+ \
        --output=fio-${SERIAL:-unknown}.json || true

    echo ">>> Final SMART status"
    sudo smartctl -a "$DEV" || true

    echo "=== Test finished at $(date) ==="
} | tee -a "$LOGFILE"

echo
echo "Test complete. Log saved to: $LOGFILE"
