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

## Any IndianaDell machine: `bin/apply-tuning`

The same scripts now work on every similar-era Dell (Safar, Tower5810, the others), not only Tower5810. They detect the hardware and choose sizes from it. There is one entry point:

```bash
bin/apply-tuning report            # no root: detected hardware, live status, and the plan. Paste this.
bin/apply-tuning status            # no root: each step ok / DIFFERS / skip
bin/apply-tuning apply --dry-run   # no root: exact actions, changes nothing
sudo bin/apply-tuning apply        # root steps
bin/apply-tuning apply             # user steps (chrome-cap, max-performance), no sudo
sudo bin/apply-tuning revert       # undo the IO steps
# --only zram,sysctl   --skip fast-boot   --config FILE
```

Steps: `arc zram sysctl diskswap bfq initramfs ionice fast-boot fast-login gpu-manager` (root) and `chrome-cap max-performance` (user). Running a root step without sudo prints the exact `sudo` command instead. Every step is idempotent: a file is rewritten only when its content differs.

| What is detected | How it is used |
|---|---|
| RAM (`MemTotal`) | zram = **75 % of RAM, rounded to GiB, clamped 2G..32G** (16 GB → 12G, 8 GB → 6G, 32 GB → 24G). ZFS ARC = **25 % of RAM, clamped 1..16 GiB**. Chrome MemoryMax = 37.5 % of RAM (min 2G), MemoryHigh = max − 1G. |
| ZFS module loaded | ARC cap and the initramfs rebuild only when ZFS is present; otherwise skipped. Swap zvols are noted, never destroyed. |
| Root fs, initramfs tool | `update-initramfs -u` or `dracut -f`, only when the ARC file changed. |
| Disks (`lsblk` ROTA/TRAN) | BFQ for rotational SATA/SAS disks only. SSD, NVMe and eMMC keep their default. USB disks are left alone (flash sticks report rotational=1). |
| Disk-backed swap | `swapoff` only if its used pages fit in MemAvailable − 1.5 GB. Active fstab lines whose type field is `swap` are commented `#disabled-by-io-tuning#`, after a timestamped backup in `/root/io-tuning-backup/`. |
| Other zram managers | zram-generator, zram-config or zramswap: our zram step is skipped (no double zram) unless `ZRAM_TAKEOVER=1`. |
| GRUB, NetworkManager, kdump | fast-boot skips what is missing. The cmdline is built from the machine's own `GRUB_CMDLINE_LINUX_DEFAULT` with `crashkernel=` removed and `quiet splash` kept, so options such as Tower5810's `usbcore.quirks=` survive. |
| Display manager, session | fast-login (GDM auto-login) is **opt-in** (`ENABLE_FAST_LOGIN=1`) and GDM-only. max-performance needs GNOME. |
| GPUs (`lspci -n` class 03xx), `gpu-manager.service`, `/etc/prime-discrete` | gpu-manager step: `systemctl mask gpu-manager.service` (saves about 10 s of boot) only when the unit exists, there is **exactly one** display-class GPU (VGA 0300, 3D 0302 or display 0380, so no hybrid/Optimus/PRIME) and `/etc/prime-discrete` is absent. `GPU_MANAGER_MASK=auto` (default), `1` = mask whenever the unit exists, `0` = never. Safar (one NVS 3100M) masks it; Tower5810 (three FirePro cards) skips it. |
| Laptop (DMI chassis or battery) | max-performance is skipped unless `FORCE_DESKTOP_POWER=1`. |

**Configuration** (later wins): computed defaults < `etc/indianadell/hosts/<hostname>.conf` in the repo < `/etc/indianadell/tuning.conf` < `--config FILE` < environment variables. The keys are listed in `etc/indianadell/tuning.conf.example`. `etc/indianadell/hosts/Tower5810.conf` pins Tower5810 to what was tuned there: 13G zram, 4 GiB ARC, Chrome 5G/6G, and auto-login for `user`. A new machine needs no file. To pin it, copy the example to `/etc/indianadell/tuning.conf`, or add `hosts/<name>.conf` to the repo.

### New machine (e.g. Safar)

```bash
cd ~/Documents/IndianaDell && git pull
bin/apply-tuning report > /tmp/tuning-$(hostname).txt; cat /tmp/tuning-$(hostname).txt   # review / paste
sudo bin/apply-tuning apply            # root steps
bin/apply-tuning apply                 # Chrome cap + GNOME max performance (as yourself)
bin/apply-tuning status                # everything ok; reboot, then systemd-analyze
```

The older launchers still work and call the same code. `sudo bin/apply-io-tuning` runs the IO steps only, and `bin/apply-io-tuning --report` reports them. `sudo bin/resize-zram-swap` without a size uses the configured size. `bin/apply-fast-boot --dry-run` needs no sudo.

## What `apply-io-tuning` changes (Tower5810 history)

```bash
sudo bin/apply-io-tuning
# options (environment): ARC_MAX_GIB=4  ZRAM_SIZE=13G  BG_PROCS="cargo rustc dsd-fme commander"
```

1. **ZFS ARC cap** — 4 GiB live (`/sys/module/zfs/parameters/zfs_arc_max`) and persistent in `/etc/modprobe.d/zfs-arc.conf`.
2. **zram swap** — `zram-swap.service`: 13 GiB (was 8 GiB; resize live with `sudo bin/resize-zram-swap 13G`), zstd, priority 100. Swap lives in compressed RAM, zero disk IO.
3. **sysctl** — `/etc/sysctl.d/60-zram.conf`: `vm.swappiness=100`, `vm.page-cluster=0` (the right values when swap is zram; high swappiness is cheap there).
4. **Disk swap off** — each non-zram entry in `/proc/swaps` is `swapoff`'d only if its used pages fit in `MemAvailable` minus 1.5 GB; matching `/etc/fstab` lines are commented with `#disabled-by-io-tuning#`. Original fstab is saved at `/root/io-tuning-backup/fstab.orig`.
5. **BFQ scheduler** — `modprobe bfq`, loaded at boot, plus `/etc/udev/rules.d/60-hdd-bfq.rules` for every rotational `sd*` disk (USB disks are skipped by the live step). BFQ gives interactive/latency-sensitive IO priority over bulk writers.
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

Removes the zram unit, ARC cap, sysctl, BFQ rule, restores fstab, and returns the disks to `mq-deadline`. `sudo bin/apply-tuning revert` also runs `systemctl unmask gpu-manager.service` when it is masked (`--skip gpu-manager` keeps it masked). By hand: `sudo systemctl unmask gpu-manager.service`.

## Notes and limits

- `sudo` is **not available** to the Grok Bot assistant on Tower5810 (its shell runs with `no_new_privs`). Run these scripts yourself from a terminal.
- Device names (`sdb`, `sdc`) are not hard-coded: BFQ is applied to every rotational `sd*` disk.
- The real fix for the root cause is more free SSD: moving `rpool`'s data vdev to SSD, or adding a mirror/L2ARC/SLOG on a non-special SSD, would help more than any tuning. Not done here.
- Swapping out a large zvol swap needs free RAM; if step 4 reports "not enough free RAM", close apps and re-run or reboot.

### Resizing the zram swap

zram uses RAM only for pages actually stored (about 3.5:1 compression on this machine), so a larger device costs nothing until it fills. To change the size live and persistently:

```bash
sudo bin/resize-zram-swap 13G      # or 16G; edits zram-swap.service, then swapoff/reset/swapon
swapon --show                      # confirm the new size
zramctl --bytes                    # DATA = stored, TOTAL = RAM actually used
```

The script refuses to swap off if the stored pages would not fit in free RAM; it still saves the size for the next boot.

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

### What the cap covers (and doesn't)

Chrome moves its own main browser process (about 250-300 MB) into a separate per-app group that GNOME creates (`app-com.google.Chrome-<pid>.scope`), so that process is **not** inside `chrome.slice`. This is deliberate and left alone: the renderers, GPU, network and extension helper processes are the ones that balloon, and they all start inside the capped group and share its MemoryHigh/MemoryMax budget. Capping the main process too would risk the kernel killing the whole browser instead of only its helpers.

Check where each process lives:

```bash
for p in $(pgrep -f /opt/google/chrome/chrome); do echo "$(cut -d/ -f6- /proc/$p/cgroup)"; done | sort | uniq -c
systemctl --user show chrome.slice -p MemoryCurrent -p MemoryHigh -p MemoryMax
```

`MemoryCurrent` therefore reads lower than Chrome's own task manager (Shift+Esc) by roughly the main process's size.

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
