# Appendix A — bin/ Launchers

All launchers live in `~/Documents/IndianaDell/bin/`. **PATH** is set automatically via `~/.config/indianadell/path.sh` (IndianaDell tools override system binaries).

| Launcher | Runs | Chapter |
|----------|------|---------|
| `rebuild-machine` | `scripts/rebuild/rebuild-machine.sh` | 2 |
| `build-software-manual` | `scripts/docs/build-software-manual.sh` | 1 |
| `build-all-docs` | `scripts/docs/build-all-docs.sh` | 1, 3 |
| `pull-repo` | `scripts/github/pull-all.sh` — IndianaDell + nested repos + LFS | 15 |
| `push-repo` | `bin/push-repo` → GitHub `webaugur/IndianaDell` (SSH default) | 15 |
| `setup-wiggly-ventoy` | `scripts/ventoy/setup-wiggly-ventoy.sh` — Uncle Wiggly 🥕🐰 ISO + ventoy.json + .dat | 15 |
| `setup-perc-ventoy` | `scripts/perc/setup-perc-ventoy.sh` — H710 FreeDOS/IT kit on Uncle Wiggly | hardware / PERC doc |
| `boot-uncle-wiggly-vm` | `scripts/ventoy/boot-uncle-wiggly-vm.sh` — QEMU live+persistence test | 15 |
| `boxes-import-wiggly-isos` | `scripts/ventoy/boxes-import-wiggly-isos.sh` — Boxes VM per ISO on Wiggly | 15 |
| `themes-preview-boot` | `Themes/scripts/plymouth-preview.py` — safe Plymouth window | 5 |
| `apply-fast-login` | `scripts/gnome/apply-fast-login.sh` — GRUB 0s + GDM autologin + face | 5, 7 |
| `apply-fast-boot` | `scripts/gnome/apply-fast-boot.sh` — strip crashkernel, defer daemons | 5, 7 / `docs/fast-boot.md` |
| `build-zfs-recovery-doc` | `scripts/docs/build-zfs-recovery-doc.sh` | 2, 15 |
| `build-trifold-slick` | `docs/sales/B1GMB42-trifold.html` → sales PDFs | — |
| `deploy-dosboot-recovery` | `scripts/recovery/deploy-to-dosboot.sh` | 2, 15 |
| `efi-timing-suite` | `scripts/efi/efi-timing-suite.sh` | 6, 12 |
| `dellmerge` | `scripts/dell/dellmerge.sh` | 12 |
| `gpu-stress` | `scripts/gpu/gpu-stress.sh` | 6, 12 |
| `iotest` | `scripts/storage/iotest.sh` | 12 |
| `apply-amdgpu` | `etc/apply.sh` | 6 |
| `amd-install` | `amd-radeon/install-all.sh` | 6 |
| `amd-preflight` | `amd-radeon/00-preflight.sh` | 6 |
| `amd-verify` | `amd-radeon/04-verify.sh` | 6 |
| `amd-uninstall` | `amd-radeon/uninstall.sh` | 6 |
| `apply-dark-mode` | `scripts/gnome/apply-dark-mode.sh` | 5, 7 |
| `apply-max-performance` | `scripts/gnome/apply-max-performance.sh` | 7 |
| `fix-nautilus-desktop-launch` | `scripts/gnome/fix-nautilus-desktop-launch.sh` | 3, 7 |
| `sync-desktop-icons` | `scripts/gnome/sync-desktop-icons.sh` | 3, 7 |
| `themes-extract` | `Themes/scripts/extract-all.sh` | 5 |
| `themes-install-boot` | `Themes/scripts/install-boot-theme.sh` | 5 |
| `themes-restore-boot` | `Themes/scripts/install-boot-theme.sh --restore-stock` | 5 |
| `hackrf-env` | sources `hackrf/scripts/env.sh` | 10 |
| `urh` | `hackrf/scripts/launch-urh.sh` | 10 |
| `hackrf-setup-udev` | `hackrf/scripts/setup-udev.sh` | 10 |
| `hackrf-download-mayhem` | `hackrf/scripts/download-mayhem.sh` | 10 |
| `hackrf-prepare-sdcard` | `hackrf/scripts/prepare-sdcard.sh` | 10 |
| `hackrf-flash-mayhem` | `hackrf/scripts/flash-mayhem.sh` | 10 |
| `hackrf-build-mayhem` | `hackrf/scripts/build-mayhem.sh` | 10 |

**Ventoy session (`scripts/ventoy/` → `~/bin` via `install-ventoy-session.sh`):**

| Script | Purpose |
|--------|---------|
| `seed-ventoy-persistence.sh` | Snapshot session into Ventoy casper image |
| `seed-network-check.sh` | Internet/DNS check before seed |
| `grok-indianadell-launch.sh` | Seed then Grok fullscreen autostart |
| `install-ventoy-session.sh` | Install helpers, autostart, PATH |
| `mount-rpool-recovery.sh` | ZFS rpool chroot recovery (workspace root) |
| `mount-bpool-recovery.sh` | ZFS bpool mount at `/recovery/boot` (`scripts/recovery/`) |

**Note:** `hackrf-env` must be **sourced**, not executed: `source bin/hackrf-env`

**Sudo required:** `apply-amdgpu`, `themes-install-boot`, `themes-restore-boot`, `iotest`, `hackrf-setup-udev` (udev install), `amd-install`, `efi-timing-suite`, `mount-rpool-recovery.sh`, `mount-bpool-recovery.sh`