# Chapter 2 — Rebuild and Recovery

## What gets installed

`bin/rebuild-machine` restores the **workstation** software stack (core apt, **KiCad 10**, **samsungtv** LAN remote, rustup, Flatpak Telegram). The **SDR / ham / HackRF** stack is installed from **DragonSDR** when `~/Documents/DragonSDR` is present (`bin/install-dragonsdr`).

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
| `SKIP_KICAD=1` | Skip KiCad 10 PPA + `APT_KICAD` + tscircuit npm (ngspice, gerbv, 3D libs) |
| `SKIP_SAMSUNGTV=1` | Skip `samsungtv` CLI (`pipx install samsungtvws[cli]`) |
| `DRAGONSDR_ROOT=…` | Override suite path (default `~/Documents/DragonSDR`) |

**Phases** (from `scripts/rebuild/rebuild-machine.sh`):

| Phase | Action |
|-------|--------|
| 1 | `apt-get update` |
| 2 | Install `APT_CORE` — build, Python, docs, GPU utils, flatpak, gh |
| 2b | KiCad 10 PPA + `APT_KICAD` + tscircuit npm (unless `SKIP_KICAD=1`) |
| 2c | `samsungtv` via pipx `samsungtvws[cli]` (unless `SKIP_SAMSUNGTV=1`) |
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
- Every package in `APT_KICAD` plus `kicad` / `kicad-cli` / `ngspice` / `node` / `npm`, `import pcbnew` 10.*, and tscircuit + `@tscircuit/capacity-autorouter` (unless `SKIP_KICAD=1`)
- `samsungtv` pipx package `samsungtvws[cli]` (unless `SKIP_SAMSUNGTV=1`)
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
| apt install `APT_CORE` + `APT_KICAD` (KiCad 10 PPA) | Partition disks or ZFS |
| tscircuit + `@tscircuit/capacity-autorouter` under `~/.local` | `sudo bin/apply-amdgpu` |
| `samsungtv` (`pipx install samsungtvws[cli]`) unless `SKIP_SAMSUNGTV=1` | Pair the TV (on-screen Allow) |
| rustup; DragonSDR suite when present | GNOME prefs / themes by default |
| Flatpak Telegram | Flash HackRF / PortaPack firmware |
| Regenerate apt manifests | `bin/amd-install` (ROCm) |
| chmod workspace scripts | Install FactoryDocs CABs to Windows |

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
