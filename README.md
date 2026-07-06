# IndianaDell

Dell Precision T5810 (B1GMB42) workstation project — hardware inventory, rebuild scripts, themes, HackRF tooling, recovery utilities, and Ventoy live persistence.

## Layout

| Path | Purpose |
|------|---------|
| `bin/` | Machine launchers (`dellmerge`, `gpu-stress`, `rebuild-machine`, …) |
| `scripts/` | Supporting scripts (rebuild, GPU, storage, docs, GitHub push) |
| `amd-radeon/` | AMDGPU install/verify scripts |
| `hackrf/` | HackRF / Mayhem tooling (repos excluded from git; re-download with scripts) |
| `Themes/` | Boot/login/desktop theme mirrors and installers |
| `FactoryDocs/` | Dell vendor CABs/PDFs (local archive; large binaries) |
| `docs/` | Software manual chapters, feature notes, hardware figures |
| `mount-rpool-recovery.sh` | ZFS `rpool` recovery mount (chroot default, `--overlay` optional) |

## Documentation

| Document | Source | PDF |
|----------|--------|-----|
| **Software Manual** | `docs/software-manual/` (15 chapters) | `B1GMB42-software-manual.pdf` |
| **Hardware inventory** | `B1GMB42-slot-port-inventory.md` | `B1GMB42-slot-port-inventory.pdf` |
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
bin/pull-repo                    # IndianaDell + hackrf/repos + git-lfs
bin/pull-repo --verify           # + rebuild-machine --verify-only
bin/pull-repo --build-docs       # + rebuild all manual PDFs
bin/push-repo                    # push main (SSH; no gh required)
```

HTTPS override: `INDIANADELL_REMOTE=https://github.com/webaugur/IndianaDell.git` (needs `gh auth login`).

Large FactoryDocs installers use **Git LFS** (`git lfs install` after clone).

## ZFS recovery (installed rpool)

```bash
sudo ./mount-rpool-recovery.sh mount      # chroot layout under /recovery
sudo ./mount-rpool-recovery.sh chroot     # enter chroot
sudo ./mount-rpool-recovery.sh umount
```

## Ventoy live persistence

Ubuntu 26.04 on the Wiggly Ventoy stick with 14 GB `ubuntu-26.04.dat` overlay. See **Software Manual Ch. 15**.

```bash
scripts/ventoy/install-ventoy-session.sh   # install ~/bin helpers + autostart + PATH
~/bin/seed-ventoy-persistence.sh             # snapshot session into casper image
```

Autologin `ubuntu`, network-checked seed, Grok fullscreen autostart, and IndianaDell PATH.

**Release:** `v1.0.4` — runtime secret resolution (`/home/user` when rpool exists), Ventoy persistence seed, Grok autostart.