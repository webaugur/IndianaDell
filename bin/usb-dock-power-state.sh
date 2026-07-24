#!/usr/bin/env bash
#
# usb-dock-power-state.sh
# Show power management and driver state for the JMicron USB-SATA dock (152d:2352)
#
# Run this before and after applying the udev rule to verify the settings took effect.

set -euo pipefail

echo "=== JMicron USB-SATA Dock Power & Driver State ==="
echo

# Find all USB devices matching the VID:PID
mapfile -t USB_DEVS < <(lsusb -d 152d:2352 2>/dev/null | awk '{print $2":"$4}' | sed 's/:$//')

if [[ ${#USB_DEVS[@]} -eq 0 ]]; then
    echo "No JMicron 152d:2352 dock found."
    exit 0
fi

for dev in "${USB_DEVS[@]}"; do
    bus="${dev%%:*}"
    devnum="${dev##*:}"
    sysfs="/sys/bus/usb/devices/usb${bus}/${bus}-${devnum}"

    if [[ -d "$sysfs" ]]; then
        echo "USB device: $dev"
        echo "  power/control     : $(cat "$sysfs/power/control" 2>/dev/null || echo 'n/a')"
        echo "  power/autosuspend : $(cat "$sysfs/power/autosuspend" 2>/dev/null || echo 'n/a')"
        echo "  speed             : $(cat "$sysfs/speed" 2>/dev/null || echo 'n/a')"
        echo
    fi
done

# Find any sdX devices that came from this bridge
echo "=== Block devices from this dock ==="
for sd in /sys/block/sd*; do
    [[ -d "$sd" ]] || continue
    vendor="$(cat "$sd/device/vendor" 2>/dev/null | tr -d ' ' || true)"
    product="$(cat "$sd/device/model" 2>/dev/null | tr -d ' ' || true)"

    if [[ "$vendor" == "152d" || "$product" == *"JMicron"* || "$product" == *"2352"* ]]; then
        name="$(basename "$sd")"
        echo "/dev/$name"
        echo "  power/control     : $(cat "$sd/device/power/control" 2>/dev/null || echo 'n/a')"
        echo "  queue/max_sectors_kb : $(cat "$sd/queue/max_sectors_kb" 2>/dev/null || echo 'n/a')"
        driver="$(readlink -f "$sd/device/driver" 2>/dev/null | xargs basename 2>/dev/null || echo 'unknown')"
        echo "  driver            : $driver"
        echo
    fi
done

echo "=== Driver modules loaded ==="
lsmod | grep -E 'uas|usb_storage' || echo "neither uas nor usb_storage loaded"
