# Chapter 2 — Rebuild and Recovery

## What gets installed

`bin/rebuild-machine` restores the full automated software stack in one run (~15–30 minutes, network dependent). It installs **90 apt packages** from `scripts/rebuild/package-lists.sh` (`APT_CORE` 37 + `APT_SDR_HAM` 53), plus rustup, HackRF repos/build, Mayhem v2.4.0 assets, URH venv, udev rules, and Flatpak Telegram.

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
| 2 | Install `APT_CORE` (37 packages) — build, Python, docs, GPU utils, flatpak |
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

## ZFS rpool recovery

When the Hitachi `rpool` install is not bootable, recover from Ventoy live (or any environment where `rpool` is not the running root):

```bash
cd ~/Documents/IndianaDell
sudo ./mount-rpool-recovery.sh mount      # altroot /recovery — full chroot tree
sudo ./mount-rpool-recovery.sh chroot     # enter with dev/proc/sys bound
sudo ./mount-rpool-recovery.sh umount
```

**Overlay fallback** (already booted from `rpool`):

```bash
sudo ./mount-rpool-recovery.sh mount --overlay
```

See also **Chapter 15** for Ventoy persistence and seeding a portable live session.