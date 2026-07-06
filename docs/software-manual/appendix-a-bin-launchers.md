# Appendix A — bin/ Launchers

All launchers live in `~/Documents/IndianaDell/bin/`. **PATH** is set automatically via `~/.config/indianadell/path.sh` (IndianaDell tools override system binaries).

| Launcher | Runs | Chapter |
|----------|------|---------|
| `rebuild-machine` | `scripts/rebuild/rebuild-machine.sh` | 2 |
| `build-software-manual` | `scripts/docs/build-software-manual.sh` | 1 |
| `build-all-docs` | `scripts/docs/build-all-docs.sh` | 1, 3 |
| `pull-repo` | `scripts/github/pull-all.sh` — IndianaDell + nested repos + LFS | 15 |
| `push-repo` | `bin/push-repo` → GitHub `webaugur/IndianaDell` (SSH default) | 15 |
| `setup-wiggly-ventoy` | `scripts/ventoy/setup-wiggly-ventoy.sh` — ISO + ventoy.json + .dat | 15 |
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

**Note:** `hackrf-env` must be **sourced**, not executed: `source bin/hackrf-env`

**Sudo required:** `apply-amdgpu`, `themes-install-boot`, `themes-restore-boot`, `iotest`, `hackrf-setup-udev` (udev install), `amd-install`, `mount-rpool-recovery.sh`