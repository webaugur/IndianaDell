#!/usr/bin/env bash
# Undo apply-io-tuning.sh.  Usage: sudo bin/revert-io-tuning
[[ $EUID -eq 0 ]] || { echo "Run with sudo." >&2; exit 1; }
systemctl disable --now zram-swap.service 2>/dev/null
rm -f /etc/systemd/system/zram-swap.service /etc/modprobe.d/zfs-arc.conf /etc/sysctl.d/60-zram.conf \
      /etc/modules-load.d/bfq.conf /etc/udev/rules.d/60-hdd-bfq.rules
sed -i 's/^#disabled-by-io-tuning# //' /etc/fstab
[[ -w /sys/module/zfs/parameters/zfs_arc_max ]] && echo 0 > /sys/module/zfs/parameters/zfs_arc_max
for d in /sys/block/sd?; do
  [[ "$(cat "$d/queue/rotational")" == 1 ]] && echo mq-deadline > "$d/queue/scheduler"
done
sysctl -w vm.swappiness=60 vm.page-cluster=3
udevadm control --reload; systemctl daemon-reload
swapon -a; update-initramfs -u; swapon --show
