# Chapter 1 — Introduction

## What this workspace installs

IndianaDell is a **software restoration toolkit** for Tower5810 after a fresh Ubuntu 26.04 install. It does not partition disks, configure ZFS, flash BIOS, or install Windows. It restores the development, SDR, ham radio, HackRF/Mayhem, documentation, and workstation utility stack documented in the chapters that follow.

The workspace lives at `~/Documents/IndianaDell`. Copy or clone it before running `bin/rebuild-machine`.

## Install layering

Software arrives in three layers. Understanding the order prevents skipped steps after a reinstall.

```
Fresh Ubuntu 26.04
        |
        v
+---------------------------+
| Automated (rebuild-machine)|
| apt core + SDR/ham         |
| rustup stable              |
| HackRF host build          |
| Mayhem download + SD tree  |
| URH venv                   |
| HackRF udev rules          |
| Flatpak Telegram           |
+---------------------------+
        |
        v
+---------------------------+
| Manual post-rebuild        |
| apply-amdgpu (GPU configs) |
| apply-dark-mode            |
| apply-max-performance      |
| themes-extract / install   |
| amd-install (optional)     |
| HackRF hardware flash      |
+---------------------------+
        |
        v
+---------------------------+
| Workspace-only until used  |
| FactoryDocs (Dell CABs)    |
| Themes mirrors (~193 MB)   |
| Report files (*.report)    |
+---------------------------+
        |
        v
   Host ready for use
```

**Automated** steps run via `bin/rebuild-machine` (see Chapter 2). **Manual** steps are intentional: GPU session files, GNOME gsettings, Plymouth overlay, and hardware flashing need user context or sudo at the right time. **Workspace-only** content stays in the repo until you invoke the matching `bin/` launcher.

## Workspace vs host paths

| Location | Role |
|----------|------|
| `~/Documents/IndianaDell/` | Source of truth for scripts, themes, HackRF assets |
| `/usr/` | Apt-installed binaries, Plymouth themes, udev rules (after apply) |
| `~/.cargo/` | Rust toolchain (rustup) |
| `hackrf/venv-urh/` | Universal Radio Hacker Python venv |
| `hackrf/build/` | HackRF host tools built from source |
| `hackrf/local/` | Optional CMAKE_INSTALL_PREFIX for built libhackrf |
| `Themes/*/mirror/` | Frozen copies of apt-owned theme files |
| `FactoryDocs/` | Dell vendor packages (not auto-installed to host) |

## Reading guide

| If you need… | Read |
|--------------|------|
| Full restore after reinstall | Ch. 2 + Ch. 3 |
| Python, Rust, pandoc | Ch. 4 |
| Boot/login/desktop look | Ch. 5 + Ch. 7 |
| FirePro GPUs, ROCm | Ch. 6 |
| GNU Radio, gqrx, SoapySDR | Ch. 8 |
| fldigi, WSJT-X, CHIRP | Ch. 9 |
| HackRF, Mayhem, URH | Ch. 10 |
| Telegram | Ch. 11 |
| iotest, dellmerge | Ch. 12 |
| Dell driver CABs | Ch. 13 |
| Known gaps | Ch. 14 |
| Ventoy live persistence, Grok autostart | Ch. 15 |
| ZFS `rpool` / `bpool` recovery | Ch. 2 + `docs/B1GMB42-zfs-recovery.md` (+ Ch. 15 live boot) |
| `/etc/default/zfs` force import | Ch. 2 / ZFS recovery manual — `ZPOOL_IMPORT_OPTS="-f"` |
| All `bin/` commands | Appendix A |
| All apt package names | Appendix B |

## PATH and launchers

IndianaDell `bin/` and `scripts/` directories are prepended to `PATH` via `~/.config/indianadell/path.sh` (sourced from `~/.bashrc`). Project tools override same-named system binaries.

## Related documents

- **Hardware:** `B1GMB42-slot-port-inventory.md` + PDF — GPUs, PERC, bays, ports
- **ZFS recovery:** `docs/B1GMB42-zfs-recovery.md` + PDF — live-media rpool/bpool chroot
- **PERC IT flash:** `docs/B1GMB42-perc-it-flash.md` — H710 FreeDOS/Wiggly path
- **Themes deep-dive:** `Themes/README.md` and per-folder READMEs
- **HackRF inventory:** `hackrf/MANIFEST.txt`
- **Apt snapshots:** `apt-full-manifest.txt`, `apt-hamradio-dev-manifest.txt`
- **Rebuild log:** `scripts/rebuild/last-run.log`