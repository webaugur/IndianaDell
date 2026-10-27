#!/usr/bin/env bash
# resize-zram-swap — change the size of the zram swap device (default 13G) without a reboot.
# Usage:  sudo bin/resize-zram-swap [SIZE]      e.g. 13G, 16G
# Updates /etc/systemd/system/zram-swap.service (so it survives reboot), then, only if the
# pages now in zram fit in free RAM, swaps off, resets and re-creates the device at the new size.
# Cost: zram only uses RAM for what is stored (~3.5:1 compression), so a bigger device is cheap.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run with sudo" >&2; exit 1; }
SIZE="${1:-13G}"
UNIT=/etc/systemd/system/zram-swap.service
[[ -f $UNIT ]] || { echo "$UNIT not found; run sudo bin/apply-io-tuning first" >&2; exit 1; }
want=$(numfmt --from=iec "$SIZE")
cur=$(cat /sys/block/zram0/disksize 2>/dev/null || echo 0)
sed -i -E "s#echo [0-9]+[KMGT]? > /sys/block/zram0/disksize#echo ${SIZE} > /sys/block/zram0/disksize#" "$UNIT"
systemctl daemon-reload
echo "unit now sets disksize=${SIZE}"
if [[ $cur -eq $want ]]; then echo "already ${SIZE}; nothing to do"; exit 0; fi
used_kb=$(awk '$1=="/dev/zram0"{print $4}' /proc/swaps); used_kb=${used_kb:-0}
avail_kb=$(awk '/MemAvailable/{print $2}' /proc/meminfo)
if (( used_kb + 1500000 > avail_kb )); then
  echo "Not enough free RAM to swap off now (zram holds $((used_kb/1024)) MiB, available $((avail_kb/1024)) MiB)." >&2
  echo "The new size is saved; it takes effect at next boot, or re-run this after closing some apps." >&2
  exit 2
fi
echo "swapping off zram ($((used_kb/1024)) MiB) ... this can take a minute"
systemctl restart zram-swap.service
swapon --show
