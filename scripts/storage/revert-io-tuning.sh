#!/usr/bin/env bash
# Undo the IO steps of apply-tuning / apply-io-tuning.  Usage: sudo bin/revert-io-tuning [--dry-run]
# Works on any machine: only touches what exists (ZFS ARC only if zfs is loaded; all rotational disks).
DRY=0; [[ ${1:-} == --dry-run ]] && DRY=1
run() { if (( DRY )); then echo "would run: $*"; else echo "+ $*"; "$@"; fi; }
[[ $DRY -eq 1 || $EUID -eq 0 ]] || { echo "Run with sudo: sudo $0 (or --dry-run)" >&2; exit 1; }
run systemctl disable --now zram-swap.service 2>/dev/null
run rm -f /etc/systemd/system/zram-swap.service /etc/modprobe.d/zfs-arc.conf /etc/sysctl.d/60-zram.conf \
      /etc/modules-load.d/bfq.conf /etc/udev/rules.d/60-hdd-bfq.rules
run sed -i 's/^#disabled-by-io-tuning# //' /etc/fstab
[[ -w /sys/module/zfs/parameters/zfs_arc_max || ( $DRY -eq 1 && -d /sys/module/zfs ) ]] && { if (( DRY )); then echo "would reset zfs_arc_max to 0"; else echo 0 > /sys/module/zfs/parameters/zfs_arc_max; fi; }
for d in /sys/block/*; do
  [[ -f $d/queue/rotational && $(cat "$d/queue/rotational") == 1 ]] || continue
  grep -qw mq-deadline "$d/queue/scheduler" || continue
  if (( DRY )); then echo "would set $(basename "$d") -> mq-deadline"; else echo mq-deadline > "$d/queue/scheduler"; fi
done
run sysctl -w vm.swappiness=60 vm.page-cluster=3
run udevadm control --reload; run systemctl daemon-reload
run swapon -a
if command -v update-initramfs >/dev/null; then run update-initramfs -u; elif command -v dracut >/dev/null; then run dracut -f; fi
swapon --show
