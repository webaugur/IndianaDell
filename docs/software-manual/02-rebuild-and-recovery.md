# Chapter 2 — Rebuild and Recovery

## What gets installed

`bin/rebuild-machine` restores the **workstation** software stack (core apt, rustup, Flatpak Telegram). The **SDR / ham / HackRF** stack is installed from **DragonSDR** when `~/Documents/DragonSDR` is present (`bin/install-dragonsdr`).

## How it is installed

```bash
cd ~/Documents/IndianaDell
chmod +x bin/* scripts/rebuild/*.sh
bin/rebuild-machine                 # full restore (includes DragonSDR suite if present)
bin/rebuild-machine --verify-only   # check only, no installs
bin/install-dragonsdr               # SDR suite alone
```

**Environment overrides:**

| Variable | Effect |
|----------|--------|
| `SKIP_TELEGRAM=1` | Skip Flatpak Telegram install |
| `SKIP_DRAGONSDR=1` | Skip SDR suite install/verify |
| `SKIP_HACKRF_BUILD=1` | Forwarded to DragonSDR suite (skip cmake host build) |
| `SKIP_HAM=1` | Forwarded to DragonSDR (skip desktop ham apps) |
| `DRAGONSDR_ROOT=…` | Override suite path (default `~/Documents/DragonSDR`) |

**Phases** (from `scripts/rebuild/rebuild-machine.sh`):

| Phase | Action |
|-------|--------|
| 1 | `apt-get update` |
| 2 | Install `APT_CORE` — build, Python, docs, GPU utils, flatpak, gh |
| 3 | Flatpak remote + `org.telegram.desktop` (unless skipped) |
| 4 | rustup stable if `rustc` missing |
| 5 | DragonSDR `install-suite` (apt SDR/ham + HackRF/Mayhem/URH) unless skipped |
| 6 | chmod `bin/` and scripts |
| 7 | Regenerate apt manifests; run `verify_stack` |

**Log file:** `scripts/rebuild/last-run.log`

## How to verify

```bash
bin/rebuild-machine --verify-only
bin/install-dragonsdr --verify-only
```

`verify_stack` checks:

- Every package in `APT_CORE` via `dpkg-query`
- Commands: `rustc`, `cargo`, `pandoc`, `xelatex`, `vkcube`
- Launchers: `dellmerge`, `gpu-stress`, `iotest`, `apply-amdgpu`, `rebuild-machine`
- DragonSDR suite (unless `SKIP_DRAGONSDR=1` or suite missing)
- Flatpak Telegram (unless `SKIP_TELEGRAM=1`)

Exit code 0 means all checks passed.

## How to customize

- **Add workstation apt packages:** Edit `scripts/rebuild/package-lists.sh`, update Appendix B, re-run rebuild.
- **Add SDR/ham packages:** Edit `~/Documents/DragonSDR/tools/package-lists.sh`, re-run `bin/install-dragonsdr`.
- **Pin Mayhem version:** Edit `DragonSDR/hackrf/scripts/download-mayhem.sh`.
- **Skip heavy steps:** Use `SKIP_*` env vars for CI or partial recovery.

## What rebuild does / does not do

| Rebuild **does** | Rebuild **does not** |
|------------------|----------------------|
| apt install `APT_CORE` | Partition disks or ZFS |
| rustup; DragonSDR suite when present | `sudo bin/apply-amdgpu` |
| Flatpak Telegram | GNOME prefs / themes by default |
| Regenerate apt manifests | Flash HackRF / PortaPack firmware |
| chmod workspace scripts | `bin/amd-install` (ROCm) |
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
```
