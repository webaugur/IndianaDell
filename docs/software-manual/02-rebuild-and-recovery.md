# Chapter 2 — Rebuild and Recovery

## What gets installed

`bin/rebuild-machine` restores the full automated software stack in one run (~15–30 minutes, network dependent). It installs **91 apt packages** from `scripts/rebuild/package-lists.sh` (`APT_CORE` 38 + `APT_SDR_HAM` 53), plus rustup, HackRF repos/build, Mayhem v2.4.0 assets, URH venv, udev rules, and Flatpak Telegram.

## How it is installed

```bash
cd ~/Documents/IndianaDell
chmod +x bin/* scripts/rebuild/*.sh
bin/rebuild-machine                 # full restore
bin/rebuild-machine --verify-only   # check only, no installs
```

**Environment overrides:**

| Variable | Effect |
|----------|--------|
| `SKIP_TELEGRAM=1` | Skip Flatpak Telegram install |
| `SKIP_HACKRF_BUILD=1` | Skip cmake build of HackRF host tools |

**Phases** (from `scripts/rebuild/rebuild-machine.sh`):

| Phase | Action |
|-------|--------|
| 1 | `apt-get update` |
| 2 | Install `APT_CORE` (38 packages) — build, Python, docs, GPU utils, flatpak, gh |
| 3 | Install `APT_SDR_HAM` (53 packages) — GNU Radio, ham, SDR hardware, HackRF |
| 4 | Flatpak remote + `org.telegram.desktop` (unless skipped) |
| 5 | rustup stable if `rustc` missing |
| 6 | Clone HackRF/Mayhem/URH repos under `hackrf/repos/` |
| 7 | Build HackRF host tools to `hackrf/build/` (unless skipped) |
| 8 | Download Mayhem v2.4.0 + extract SD card tree |
| 9 | Create `hackrf/venv-urh/` with URH |
| 10 | Install HackRF udev rules; chmod `bin/` and scripts |
| 11 | Regenerate apt manifests; run `verify_stack` |

**Debconf preseed:** `xastir/install-setuid` is set to `false` before apt to avoid interactive hangs.

**Log file:** `scripts/rebuild/last-run.log`

## How to verify

```bash
bin/rebuild-machine --verify-only
```

`verify_stack` checks:

- Every package in `APT_CORE` and `APT_SDR_HAM` via `dpkg-query`
- Commands: `rustc`, `cargo`, `gnuradio-config-info`, `grcc`, `gqrx`, `fldigi`, `wsjtx`, `chirpw`, `hackrf_info`, `inspectrum`, `pandoc`, `xelatex`, `vkcube`
- `hackrf/venv-urh/bin/urh`
- Mayhem firmware zip and extracted SD tree
- Built `hackrf/build/hackrf-tools/src/hackrf_sweep`
- Launchers: `dellmerge`, `gpu-stress`, `iotest`, `apply-amdgpu`, `rebuild-machine`
- Flatpak Telegram (unless `SKIP_TELEGRAM=1`)

Exit code 0 means all checks passed.

## How to customize

- **Add apt packages:** Edit `scripts/rebuild/package-lists.sh`, update Appendix B, re-run rebuild.
- **Pin HackRF/Mayhem version:** Edit `hackrf/scripts/download-mayhem.sh` and MANIFEST; rebuild does not auto-upgrade pinned releases.
- **Skip heavy steps:** Use `SKIP_*` env vars for CI or partial recovery.

## What rebuild does / does not do

| Rebuild **does** | Rebuild **does not** |
|------------------|----------------------|
| apt install all listed packages | Partition disks or ZFS |
| rustup, HackRF build, Mayhem download | `sudo bin/apply-amdgpu` |
| URH venv, udev rules | `bin/apply-dark-mode` / `apply-max-performance` |
| Regenerate `apt-full-manifest.txt` | Plymouth theme install |
| chmod workspace scripts | Flash HackRF / PortaPack firmware |
| | `bin/amd-install` (ROCm) |
| | Install FactoryDocs CABs to Windows |

After a successful rebuild, continue with **Chapter 3 — Post-Rebuild Checklist**.

## ZFS rpool / bpool recovery

**Full guide:** `docs/B1GMB42-zfs-recovery.md` + `B1GMB42-zfs-recovery.pdf` (also on **DOSBOOT** `IndianaDell/recovery/`).

**Required on the installed system:** `/etc/default/zfs` must set force import so boot can recover after export or unclean shutdown:

```bash
# /etc/default/zfs
ZPOOL_IMPORT_OPTS="-f"
```

Verify anytime: `grep ZPOOL_IMPORT_OPTS /etc/default/zfs`. One-shot boot alternative: kernel cmdline `zfsforce=1`.

**Quick (with scripts, from Ventoy live):**

```bash
sudo apt-get install -y zfsutils-linux
cd ~/Documents/IndianaDell    # or DOSBOOT/IndianaDell/recovery
sudo ./mount-rpool-recovery.sh mount
sudo ./scripts/recovery/mount-bpool-recovery.sh mount
sudo ./mount-rpool-recovery.sh chroot
# inside chroot: confirm ZPOOL_IMPORT_OPTS="-f", repair, update-initramfs/grub
```

**Without scripts:** manual `zpool import -N -f -R /recovery rpool` — see ZFS recovery manual Section 3.

Build PDF: `bin/build-zfs-recovery-doc`. Deploy to DOSBOOT: `bin/deploy-dosboot-recovery`.

See also **Chapter 15** for Ventoy live boot.