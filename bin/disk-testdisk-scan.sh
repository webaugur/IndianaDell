#!/usr/bin/env bash
#
# disk-testdisk-scan.sh
# Launch testdisk on a specific disk using a stable identifier.
#
# WARNING: The cheap JMicron USB-SATA dock (152d:2352) used with this disk
# is known to drop the SATA link under sustained load (testdisk, fio, etc.).
# Run ~/bin/usb-dock-power-state.sh first and consider the udev rule in
# ~/bin/99-usb-dock.rules before running long scans.
#
# This version NEVER pipes the interactive program, so keyboard input works.
#
# Usage:
#   ./disk-testdisk-scan.sh /dev/disk/by-id/usb-WDC_WD20_03FZEX-00Z4SA0_DCA2599981FF-0:0
#   ./disk-testdisk-scan.sh WD-WMC1F1160506
#
# The script will resolve the identifier, show you exactly which device it
# will use, and then run testdisk directly (no pipe).

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

# Resolve to a real block device
if [[ "$IDENT" == /dev/disk/by-id/* ]]; then
    if [[ -e "$IDENT" ]]; then
        DEV="$(readlink -f "$IDENT")"
    else
        echo "ERROR: Path does not exist: $IDENT"
        exit 1
    fi
elif [[ "$IDENT" =~ ^[A-Z0-9-]+$ ]]; then
    # Try to find a matching by-id entry containing this serial
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
    echo "ERROR: Could not resolve '$IDENT' to a valid block device"
    exit 1
fi

# Safety checks
if mount | grep -q "^$DEV"; then
    echo "ERROR: $DEV is currently mounted. Unmount it first."
    exit 1
fi

if ! command -v testdisk >/dev/null 2>&1; then
    echo "ERROR: testdisk is not installed."
    echo "Install it with: sudo apt install testdisk"
    exit 1
fi

SERIAL="$(udevadm info --query=all --name="$DEV" 2>/dev/null | awk -F= '/ID_SERIAL_SHORT/ {print $2}')"
MODEL="$(udevadm info --query=all --name="$DEV" 2>/dev/null | awk -F= '/ID_MODEL/ {print $2}')"

echo "========================================"
echo "Testdisk Partition Scan"
echo "Identifier given : $IDENT"
echo "Resolved device  : $DEV"
echo "Model            : ${MODEL:-unknown}"
echo "Serial           : ${SERIAL:-unknown}"
echo "========================================"
echo
echo "testdisk will now be launched directly on: $DEV"
echo
echo "Keyboard control will work normally because we are not piping the program."
echo
read -r -p "Press Enter to launch testdisk or Ctrl-C to abort... "

# Run testdisk directly (no pipe). It will create its own log file
# in the current directory when /log is used.
sudo testdisk /log /debug "$DEV"
