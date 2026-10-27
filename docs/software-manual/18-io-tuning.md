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

## Capping Chrome's memory

Chrome was one of the largest RAM users on 16 GB. Spoofing the RAM size is not practical, so Chrome runs inside a kernel memory budget instead:

```bash
bin/apply-chrome-cap                 # no sudo; defaults MemoryHigh=5G MemoryMax=6G
bin/apply-chrome-cap --high 4G --max 5G
bin/apply-chrome-cap --revert
```

- `~/.config/systemd/user/chrome.slice` holds the budget (also `CPUWeight=80`, `IOWeight=50`). All Chrome windows and PWAs share it.
- Past `MemoryHigh` the kernel reclaims Chrome's pages into zram swap (Chrome slows, the desktop does not). At `MemoryMax` only Chrome is OOM-killed.
- `~/bin/chrome-capped` (from `scripts/gnome/chrome-capped.sh`) starts Chrome with `systemd-run --user --scope --slice=chrome.slice` plus `--renderer-process-limit=8` and `--js-flags=--max-old-space-size=3072`. Extra flags: `CHROME_CAPPED_FLAGS`.
- The installer points the system launchers (copied to `~/.local/share/applications`) and the Chrome-made PWA launchers at the wrapper. Originals are in `~/Backups/chrome-cap`. Chrome rewrites its PWA launchers on update, so re-run `bin/apply-chrome-cap` afterward.
- Terminal: the installer writes a marker-delimited block (`# >>> indianadell chrome-cap >>>`) to `~/.bash_aliases` that aliases `google-chrome`, `google-chrome-stable` and `chrome` to the wrapper. Re-running replaces the block; `--revert` removes it. Open a new terminal (or `source ~/.bash_aliases`) to pick it up.
- Also useful, in Chrome: Settings → Performance → Memory Saver.

### Automatic re-check after updates

`bin/apply-chrome-cap` also installs three user units (no sudo): `chrome-cap-check.timer` (3 minutes after login, then hourly; it catches the nightly `apt-daily-upgrade`, which runs around 06:00), `chrome-cap-check.path` (fires when Chrome rewrites a launcher in `~/.local/share/applications`), and `chrome-cap-check.service`, which runs `scripts/gnome/check-chrome-cap.sh`. The script does nothing when every Chrome launcher still starts the wrapper. If an update reset one, or the wrapper or slice file is gone, it re-runs `bin/apply-chrome-cap` with your existing limits and sends a desktop notification.

```bash
systemctl --user list-timers chrome-cap-check.timer    # next run
journalctl --user -u chrome-cap-check -n 20            # history: "intact" or "re-applied"
systemctl --user start chrome-cap-check.service        # run the check now
```

`bin/apply-chrome-cap --revert` removes the units as well. The check re-applies launchers only; a Chrome window already running keeps its old cgroup until you restart it.

## Repeat from scratch (one block)

Everything in this chapter is scripted and idempotent. On a fresh or rebuilt Tower5810, from `~/Documents/IndianaDell`:

```bash
# 1. Root-level IO tuning: zram swap, ZFS ARC cap, BFQ, idle IO for background jobs
sudo bin/apply-io-tuning
sudo swapoff /dev/zd0 2>/dev/null || true      # finish emptying the old ZFS swap volume if step 4 skipped it
# 2. User-level, no sudo: capped Chrome + launchers + terminal aliases
bin/apply-chrome-cap                           # --high 5G --max 6G are the defaults
source ~/.bash_aliases
# 3. Make the new commands available in $PATH
bin/install-to-bin
# 4. Verify
swapon --show                                  # only /dev/zramN
cat /sys/block/sdb/queue/scheduler             # [bfq]
systemctl --user show chrome.slice -p MemoryHigh -p MemoryMax
type chrome                                    # aliased to ~/bin/chrome-capped
```

Undo: `sudo bin/revert-io-tuning` and `bin/apply-chrome-cap --revert`.
