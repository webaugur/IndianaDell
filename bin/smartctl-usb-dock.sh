#!/usr/bin/env bash
#
# smartctl-usb-dock.sh
# Wrapper that tries common working device types for JMicron 152d:2352 docks.
#
# Usage:
#   smartctl-usb-dock.sh -a /dev/sdd
#   smartctl-usb-dock.sh -t long /dev/sdd
#
# It will try, in order:
#   -d sat
#   -d scsi
#   -d usb
#   (plain, no -d flag)
# and stop at the first one that returns valid SMART data.

set -euo pipefail

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 [smartctl options] /dev/sdX"
    echo "Example: $0 -a /dev/sdd"
    echo "         $0 -t long /dev/sdd"
    exit 1
fi

DEV="${!#}"          # last argument is the device
ARGS=("${@:1:$#-1}") # everything before the device

try_types=(sat scsi usb "")

for type in "${try_types[@]}"; do
    if [[ -n "$type" ]]; then
        echo ">>> Trying -d $type ..."
        if sudo smartctl -d "$type" "${ARGS[@]}" "$DEV" 2>&1; then
            echo
            echo "Success with -d $type"
            exit 0
        fi
    else
        echo ">>> Trying without -d flag ..."
        if sudo smartctl "${ARGS[@]}" "$DEV" 2>&1; then
            echo
            echo "Success with no -d flag"
            exit 0
        fi
    fi
    echo
done

echo "All attempts failed. SMART passthrough may not be supported by this dock firmware."
exit 1
