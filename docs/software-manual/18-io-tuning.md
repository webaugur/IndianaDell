# Chapter 18 — Disk IO tuning (UI responsiveness)

**Symptom:** the GNOME desktop freezes whenever the disks are saturated (builds, `dsd-fme` decoders, swap-out, ZFS txg flushes).

**Cause (Tower5810, measured 2026-10-27):**

| Finding | Detail |
|---------|--------|
| Root pool on a spinning disk | `rpool` data vdev is the 1.4 TB Hitachi HDS723015BLA642 (`sdb4`, rotational). |
| SSD is not free space | The TEAM T253X6256G (`sda`, 238 GB) is a **ZFS `special` vdev** (metadata + blocks ≤ 32K). It cannot be carved into a non-ZFS swap partition without removing it from the pool. |
| Swap on a ZFS zvol | `rpool/swap` (`/dev/zd0`, 33 GB, `sync=always`, `volblocksize=8K`). Every swap-out is a synchronous HDD write. A second 4 GB swap partition sat on the same HDD (`sdb3`). |
| Unbounded ARC | `zfs_arc_max=0` → ARC allowed up to all 16 GB RAM, competing with apps and pushing them into that swap. |
| Pressure stall info | `/proc/pressure/io` full avg300 ≈ 10 % while CPU pressure was ≈ 2 %: the stalls were disk, not CPU. |
| IO scheduler | `mq-deadline` on all disks; no per-process fairness, so one writer (`cargo`, ~40 MB/s) starves the desktop. |

## What `apply-io-tuning` changes

```bash
sudo bin/apply-io-tuning
# options (environment): ARC_MAX_GIB=4  ZRAM_SIZE=8G  BG_PROCS="cargo rustc dsd-fme commander"
```

1. **ZFS ARC cap** — 4 GiB live (`/sys/module/zfs/parameters/zfs_arc_max`) and persistent in `/etc/modprobe.d/zfs-arc.conf`.
2. **zram swap** — `zram-swap.service`: 8 GiB, zstd, priority 100. Swap lives in compressed RAM, zero disk IO.
3. **sysctl** — `/etc/sysctl.d/60-zram.conf`: `vm.swappiness=100`, `vm.page-cluster=0` (the right values when swap is zram; high swappiness is cheap there).
4. **Disk swap off** — each non-zram entry in `/proc/swaps` is `swapoff`'d only if its used pages fit in `MemAvailable` minus 1.5 GB; matching `/etc/fstab` lines are commented with `#disabled-by-io-tuning#`. Original fstab is saved at `/root/io-tuning-backup/fstab.orig`.
5. **BFQ scheduler** — `modprobe bfq`, loaded at boot, plus `/etc/udev/rules.d/60-hdd-bfq.rules` for every rotational `sd*` disk. BFQ gives interactive/latency-sensitive IO priority over bulk writers.
6. **initramfs** — `update-initramfs -u` so the ARC cap applies from boot (ZFS root).
7. **Idle IO class** for running `cargo`, `rustc`, `dsd-fme`, `commander`.

The `rpool/swap` zvol is **left in place**. Once you are happy, reclaim the space with `sudo zfs destroy rpool/swap`.

## Running heavy jobs without freezing the desktop

```bash
bin/run-in-background cargo build --release     # ionice -c3 + nice -n 19
```

`ionice -c3` (idle class) is honoured by BFQ; it is **not** enforced under `mq-deadline`, which is why step 5 matters.

## Verify

```bash
swapon --show                     # only /dev/zramN
cat /sys/block/sdb/queue/scheduler  # [bfq]
grep -E '^(size|c_max) ' /proc/spl/kstat/zfs/arcstats
cat /proc/pressure/io             # watch 'full' under load
```

## Undo

```bash
sudo bin/revert-io-tuning
```

Removes the zram unit, ARC cap, sysctl, BFQ rule, restores fstab, and returns the disks to `mq-deadline`.

## Notes and limits

- `sudo` is **not available** to the Grok Bot assistant on Tower5810 (its shell runs with `no_new_privs`). Run these scripts yourself from a terminal.
- Device names (`sdb`, `sdc`) are not hard-coded: BFQ is applied to every rotational `sd*` disk.
- The real fix for the root cause is more free SSD: moving `rpool`'s data vdev to SSD, or adding a mirror/L2ARC/SLOG on a non-special SSD, would help more than any tuning. Not done here.
- Swapping out a large zvol swap needs free RAM; if step 4 reports "not enough free RAM", close apps and re-run or reboot.
