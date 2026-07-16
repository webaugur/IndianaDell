# IndianaDell

Dell Precision T5810 (B1GMB42) workstation project — hardware inventory, rebuild scripts, themes, recovery utilities, and Ventoy live persistence.

**SDR / ham / HackRF** live in **[DragonSDR](https://github.com/webaugur/DragonSDR)** (`~/Documents/DragonSDR`). This repo installs that suite when needed via `bin/install-dragonsdr`.

## Layout

| Path | Purpose |
|------|---------|
| `bin/` | Machine launchers (`dellmerge`, `gpu-stress`, `rebuild-machine`, …) |
| `scripts/` | Supporting scripts (rebuild, GPU, storage, docs, GitHub push) |
| `amd-radeon/` | AMDGPU install/verify scripts |
| `Themes/` | Boot/login/desktop theme mirrors and installers |
| `FactoryDocs/` | Dell vendor CABs/PDFs (local archive; large binaries) |
| `docs/` | Software manual chapters, feature notes, hardware figures |
| `mount-rpool-recovery.sh` | ZFS `rpool` recovery mount (chroot default, `--overlay` optional) |

**SDR suite (separate repo):** `~/Documents/DragonSDR` — apt packages, GNU Radio, ham apps, HackRF/Mayhem, URH.

## Documentation

| Document | Source | PDF |
|----------|--------|-----|
| **Software Manual** | `docs/software-manual/` (15 chapters) | `B1GMB42-software-manual.pdf` |
| **Hardware inventory** | `B1GMB42-slot-port-inventory.md` | `B1GMB42-slot-port-inventory.pdf` |
| **ZFS recovery** | `docs/B1GMB42-zfs-recovery.md` | `B1GMB42-zfs-recovery.pdf` |
| **PERC H710 IT flash** | `docs/B1GMB42-perc-it-flash.md` | — |
| **Software inventory stub** | `B1GMB42-software-inventory.md` | `B1GMB42-software-inventory.pdf` |
| **Quick reference** | `docs/features-available.md` | — |
| **FactoryDocs index** | `FactoryDocs/README.md` | — |

**Build all PDFs:**

```bash
bin/build-all-docs
# or software manual only:
bin/build-software-manual
```

Requires `pandoc` and `texlive-xetex` (installed by `bin/rebuild-machine` Phase 2).

## PATH (terminal defaults)

IndianaDell tools override system binaries. Configured in `~/.config/indianadell/path.sh`, sourced from `~/.bashrc`.

```bash
echo "$INDIANADELL_ROOT"   # ~/Documents/IndianaDell
which dellmerge gpu-stress push-repo
```

## GitHub sync

Repository: https://github.com/webaugur/IndianaDell (private). Default remote is **SSH** (`git@github.com:webaugur/IndianaDell.git`).

```bash
bin/pull-repo                    # IndianaDell + git-lfs
bin/pull-repo --dragonsdr        # + pull DragonSDR and hackrf/repos
bin/pull-repo --verify           # + rebuild-machine --verify-only
bin/pull-repo --build-docs       # + rebuild all manual PDFs
bin/push-repo                    # push main (SSH; no gh required)
bin/install-dragonsdr            # install full SDR suite from DragonSDR
```

HTTPS override: `INDIANADELL_REMOTE=https://github.com/webaugur/IndianaDell.git` (needs `gh auth login`).

Large FactoryDocs installers use **Git LFS** (`git lfs install` after clone).

## ZFS recovery (rpool + bpool)

**Manual:** `docs/B1GMB42-zfs-recovery.md` + `B1GMB42-zfs-recovery.pdf`  
**DOSBOOT copy:** `IndianaDell/recovery/` on partition `sdc3` — `bin/deploy-dosboot-recovery`

```bash
sudo apt-get install -y zfsutils-linux
sudo ./mount-rpool-recovery.sh mount
sudo ./scripts/recovery/mount-bpool-recovery.sh mount
sudo ./mount-rpool-recovery.sh chroot
```

Manual `zpool` commands (no scripts): see recovery manual Section 3.

### Required: force import in `/etc/default/zfs`

On this machine, **boot will fail or hang on pool import** after a recovery export or unclean shutdown unless force-import is enabled:

```bash
# /etc/default/zfs  (installed system, not just live media)
ZPOOL_IMPORT_OPTS="-f"
```

Verify: `grep ZPOOL_IMPORT_OPTS /etc/default/zfs` should show `"-f"`.  
One-shot alternative at the GRUB/kernel cmdline: `zfsforce=1`.  
Recovery scripts always pass `-f` on manual import; the installed OS still needs the default above for normal boots.

## Ventoy live persistence — Uncle Wiggly 🥕🐰

Ubuntu 26.04 on **Uncle Wiggly** (internal Ventoy, partition label `Wiggly`, `sdc1`) with 24 GB `persistence/ubuntu-26.04.dat` overlay. Drop ISOs into the **rabbit hole** — they fall into the boot black hole. See **Software Manual Ch. 15**.

```bash
bin/setup-wiggly-ventoy                    # verify ISO + ventoy.json + .dat (Tower5810)
scripts/ventoy/install-ventoy-session.sh   # install ~/bin helpers + autostart + PATH
~/bin/seed-ventoy-persistence.sh           # snapshot session into casper image
```

Autologin `ubuntu`, network-checked seed, Grok fullscreen autostart, and IndianaDell PATH.

**Related tools:** `bin/efi-timing-suite` (BIOS A/B baselines → `B1GMB42.timing`), `bin/setup-perc-ventoy` (PERC H710 FreeDOS/IT flash on Uncle Wiggly).

**Release:** `v1.0.6` — dual swap (4 GiB HDD + 33 GiB ZFS special zvol), Nautilus 50 tools, amdgpu DPM performance.
