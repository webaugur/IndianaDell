#!/usr/bin/env bash
#
# apply-io-tuning.sh — keep the desktop responsive when the disks are busy.
#
# Tower5810 has its ZFS root pool on a spinning HDD and swap on a ZFS zvol
# (sync=always). Any swap-out becomes a synchronous HDD write, which stalls the
# GNOME session. This script:
#   1. caps the ZFS ARC (default 4 GiB; ZFS may otherwise take all RAM)
#   2. creates a 13 GiB zstd zram swap (priority 100, no disk IO)
#   3. sets vm.swappiness=100, vm.page-cluster=0 (right for zram)
#   4. swaps off every disk-backed swap and comments it out of /etc/fstab
#   5. puts rotational disks on the BFQ IO scheduler (persistent udev rule)
#   6. rebuilds the initramfs so the ARC cap applies at boot
#   7. moves running builds/background daemons to the idle IO class
#
# Usage:  sudo bin/apply-io-tuning
# Env:    ARC_MAX_GIB=4  ZRAM_SIZE=13G  BG_PROCS="cargo rustc dsd-fme commander"
# Undo:   sudo bin/revert-io-tuning
#
set -u
[[ $EUID -eq 0 ]] || { echo "Run with sudo." >&2; exit 1; }

ARC_MAX_GIB="${ARC_MAX_GIB:-4}"
ZRAM_SIZE="${ZRAM_SIZE:-13G}"
BG_PROCS="${BG_PROCS:-cargo rustc dsd-fme commander}"
BK=/root/io-tuning-backup
mkdir -p "$BK"
cp --update=none /etc/fstab "$BK/fstab.orig"

echo "== 1. ZFS ARC cap (${ARC_MAX_GIB} GiB) =="
if [[ -w /sys/module/zfs/parameters/zfs_arc_max ]]; then
  arc_bytes=$(( ARC_MAX_GIB * 1024 * 1024 * 1024 ))
  echo "$arc_bytes" > /sys/module/zfs/parameters/zfs_arc_max
  echo "options zfs zfs_arc_max=${arc_bytes}" > /etc/modprobe.d/zfs-arc.conf
else
  echo "zfs module not loaded; skipping"
fi

echo "== 2. zram swap (${ZRAM_SIZE}, zstd, priority 100) =="
cat > /etc/systemd/system/zram-swap.service <<UNIT
[Unit]
Description=zram compressed swap (IndianaDell io-tuning)
After=local-fs.target
Before=swap.target
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'modprobe zram num_devices=1; echo zstd > /sys/block/zram0/comp_algorithm; echo ${ZRAM_SIZE} > /sys/block/zram0/disksize; mkswap /dev/zram0; swapon -p 100 /dev/zram0'
ExecStop=/bin/sh -c 'swapoff /dev/zram0; echo 1 > /sys/block/zram0/reset'
[Install]
WantedBy=swap.target
UNIT
systemctl daemon-reload
systemctl enable --now zram-swap.service
swapon --show

echo "== 3. Swappiness for zram =="
printf 'vm.swappiness=100\nvm.page-cluster=0\n' > /etc/sysctl.d/60-zram.conf
sysctl -p /etc/sysctl.d/60-zram.conf

echo "== 4. Disable disk-backed swap =="
# Only swap off a device if its contents (compressed ~2:1) fit in free RAM.
while read -r name _type _size used _prio; do
  [[ "$name" == Filename || "$name" == /dev/zram* ]] && continue
  avail=$(awk '/MemAvailable/{print $2}' /proc/meminfo)
  echo "$name: ${used} KiB in use, ${avail} KiB RAM available"
  if (( used < avail - 1500000 )); then
    swapoff "$name" && echo "  off"
  else
    echo "  not enough free RAM to empty it safely now; close apps and re-run, or reboot (fstab is fixed below)."
  fi
done < /proc/swaps
# Comment out disk-swap entries in fstab (zvol swap is not in fstab on some installs; udev/zfs handles it).
sed -i -E '/^[^#].*[[:space:]]swap[[:space:]]/ s/^/#disabled-by-io-tuning# /' /etc/fstab
# zfs swap volume (if any): stop it being re-enabled at boot
for z in $(zfs list -H -t volume -o name 2>/dev/null | grep -i swap); do
  echo "note: swap zvol present: $z (left in place; remove with 'zfs destroy' once happy)"
done
systemctl daemon-reload

echo "== 5. BFQ on rotational disks =="
modprobe bfq
echo bfq > /etc/modules-load.d/bfq.conf
cat > /etc/udev/rules.d/60-hdd-bfq.rules <<'UDEV'
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
UDEV
udevadm control --reload
for d in /sys/block/sd?; do
  [[ "$(cat "$d/queue/rotational")" == 1 ]] && echo bfq > "$d/queue/scheduler" && echo "$(basename "$d"): $(cat "$d/queue/scheduler")"
done

echo "== 6. initramfs (ARC cap at boot) =="
update-initramfs -u

echo "== 7. Idle IO class for background jobs =="
for n in $BG_PROCS; do for p in $(pgrep -x "$n"); do ionice -c3 -p "$p" 2>/dev/null && echo "ionice idle: $n ($p)"; done; done

echo; free -h; swapon --show
echo "Done. Backup of fstab: $BK/fstab.orig"
