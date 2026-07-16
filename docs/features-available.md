# Features Available — Tower5810 (B1GMB42)

Snapshot of what is installed and ready on this system as of 2026-07-09.

Workspace root: `~/Documents/IndianaDell` (also on GitHub: `webaugur/IndianaDell`)

**PATH:** IndianaDell `bin/` and `scripts/` override system — `~/.config/indianadell/path.sh`

---

## Development

| Area | What you can do |
|------|-----------------|
| **Python 3.14** | `pip`, `venv`, numpy/scipy/matplotlib, GNU Radio Python API, SoapySDR bindings, Hamlib (`import Hamlib`) |
| **Rust 1.96** | `rustc` / `cargo` via `~/.cargo/env` — build SDR/ham projects (no starter crate workspace yet) |
| **Build** | `cmake`, `gcc`, ARM cross-compiler (`arm-none-eabi-gcc`) for Mayhem firmware, `clang`/`llvm` for bindgen-style Rust |
| **Docs/PDF** | `pandoc`, `xelatex` — `bin/build-all-docs` rebuilds all PDFs |
| **GitHub sync** | `bin/pull-repo`, `bin/push-repo` (SSH); `gh` 2.46 authenticated as **webaugur** |
| **Git LFS** | Large FactoryDocs installers in repo |
| **Chrome** | `google-chrome-stable` |
| **Grok** | `~/.grok/bin/grok` — autostart on Ventoy persistence boot |

Package manifests: `apt-hamradio-dev-manifest.txt` (178 SDR/ham), `apt-full-manifest.txt` (full dpkg list).  
**Software manual:** `docs/software-manual/` (15 chapters) — `bin/build-all-docs` → `B1GMB42-software-manual.pdf` + hardware/inventory PDFs.  
Rebuild: `bin/rebuild-machine`. Legacy stub: `B1GMB42-software-inventory.md`.

---

## GNU Radio, ham radio, HackRF (DragonSDR suite)

**Owned by** `~/Documents/DragonSDR` — install/reinstall with:

```bash
bin/install-dragonsdr
# or
~/Documents/DragonSDR/bin/install-suite
```

Includes GNU Radio + SoapySDR, desktop ham apps (fldigi, WSJT-X, CHIRP, …), HackRF host tools, PortaPack Mayhem assets, and URH.

Workspace / manifest: `~/Documents/DragonSDR/hackrf/` · `hackrf/MANIFEST.txt`  
Docs: software manual ch. 8–10; DragonSDR `README.md`

```bash
source bin/hackrf-env           # PATH → DragonSDR/hackrf/build
bin/urh
bin/hackrf-prepare-sdcard
bin/install-dragonsdr --verify-only
```

### SDR hardware support (when devices are plugged in)

| Device | Tools |
|--------|--------|
| **HackRF One / Pro** | Mayhem flash, gqrx, URH, GNU Radio, `hackrf_sweep` |
| **RTL-SDR** | `rtl_test`, gqrx, GNU Radio |
| **Airspy / bladeRF / Lime / UHD** | SoapySDR + GNU Radio blocks, host utils installed |

USB udev rules: `~/Documents/DragonSDR/hackrf/scripts/99-hackrf.rules` (installed to `/etc/udev/rules.d/`).

---

## This machine (B1GMB42 / IndianaDell)

| Feature | Status |
|---------|--------|
| **3× AMD FirePro** (W5000/W5100) | `bin/gpu-stress`, Vulkan (`vkcube`), OpenCL (`clinfo`) |
| **EFI timing baseline** | `sudo bin/efi-timing-suite` → `B1GMB42.timing` (before/after BIOS changes) |
| **AMD driver install** | `bin/amd-install`, `bin/amd-verify` → `amd-radeon/` |
| **Storage tests** | `bin/iotest` → `scripts/storage/` |
| **Dell docs** | `FactoryDocs/` (19/101 packages), `B1GMB42-slot-port-inventory.md` + PDF |
| **Telegram** | Flatpak `org.telegram.desktop` 6.9.3 |
| **Dell inventory** | `bin/dellmerge` → `scripts/dell/` |
| **Themes** | `Themes/` — boot/login/desktop READMEs; `bin/themes-*`, `bin/apply-dark-mode` |

---

## Themes module

| Stage | Folder | Customize |
|-------|--------|-----------|
| Boot (Plymouth) | `Themes/boot/` | `overlay/watermark.png` or `--oem` background → `sudo bin/themes-install-boot` |
| Login (GDM) | `Themes/login/` | `bin/apply-dark-mode` |
| Desktop (Yaru) | `Themes/desktop/` | `bin/apply-dark-mode` |

`bin/themes-extract` refreshes apt mirrors and extracts Dell/Ubuntu boot logos. Every `Themes/*/` folder has a README.md.

---

## Project launchers (`bin/`)

| Command | Runs |
|---------|------|
| `bin/dellmerge` | Dell workstation inventory report |
| `bin/gpu-stress` | 3-GPU Vulkan/EGL stress test |
| `bin/iotest` | Block-device IO benchmark |
| `bin/apply-amdgpu` | Install multi-GPU `etc/` configs (sudo) |
| `bin/amd-install` | Full AMD ROCm driver install |
| `bin/amd-preflight` / `bin/amd-verify` / `bin/amd-uninstall` | AMD driver steps |
| `bin/install-dragonsdr` | Install full DragonSDR suite |
| `bin/hackrf-env` | Source HackRF PATH → DragonSDR (use with `source`) |
| `bin/urh` | Universal Radio Hacker (wrapper → DragonSDR) |
| `bin/hackrf-*` | Mayhem flash, SD prep, udev, build (wrappers) |
| `bin/themes-extract` | Theme mirrors + boot logo extract |
| `bin/themes-install-boot` / `bin/themes-restore-boot` | Custom / stock Plymouth |
| `bin/themes-preview-boot` | Safe windowed Plymouth preview (no install) |
| `bin/apply-dark-mode` | GNOME + GDM dark |
| `bin/apply-max-performance` | No power saving / dimming |
| `bin/apply-fast-login` | GRUB menu 0s, GDM autologin, greeter face |
| `bin/apply-fast-boot` | Strip crashkernel, mask NM-wait-online, defer lab daemons |
| `bin/fix-nautilus-desktop-launch` | Nautilus 50+: launch `.desktop` on double-click |
| `bin/sync-desktop-icons` | Nautilus 50+: custom-icon from `Icon=`; rename chrome-*.desktop → `Name=` |
| `bin/pull-repo` | Fetch IndianaDell + LFS (`--dragonsdr`, `--verify`, `--build-docs`) |
| `bin/push-repo` | Push main to GitHub (SSH default) |
| `bin/setup-wiggly-ventoy` | Verify Uncle Wiggly 🥕🐰 ISO + ventoy.json + persistence .dat |
| `bin/setup-perc-ventoy` | FreeDOS / PERC H710 IT flash kit on Uncle Wiggly |
| `bin/boot-uncle-wiggly-vm` | QEMU: Ubuntu live + casper-rw persistence smoke test |
| `bin/boxes-import-wiggly-isos` | Create GNOME Boxes VMs for each ISO on Uncle Wiggly |
| `bin/deploy-dosboot-recovery` | Copy ZFS recovery kit to DOSBOOT (`sdc3`) |
| `bin/efi-timing-suite` | BIOS A/B timing baselines → `B1GMB42.timing` |
| `bin/build-all-docs` | Rebuild software, hardware, inventory, ZFS PDFs |

PATH is automatic via `~/.config/indianadell/path.sh` (see `README.md`).

## Quick start commands

```bash
cd ~/Documents/IndianaDell
source bin/hackrf-env
. ~/.cargo/env

# Machine / Dell
sudo bin/apply-amdgpu
bin/gpu-stress 60 vkcube
sudo bin/iotest
bin/dellmerge > b1gmb42.report

# Ham / SDR (some work without hardware)
fldigi &
wsjtx &
chirpw &
bin/urh
inspectrum <iq-file>

# GNU Radio
grcc myflowgraph.grc
gqrx

# HackRF (needs hardware)
hackrf_info
hackrf_sweep -f 100:6000 -w 1000000 -1
bin/hackrf-flash-mayhem
bin/hackrf-prepare-sdcard
```

---

## Library Radio (Google Drive mirror)

Selective copy of **Library / Ham_Radio** children into `~/Documents/LibraryRadio/`.  
Folder **IDs stay machine-local** (not in git). Repo only lists **names**.

```bash
# one-time: rclone config → remote name "gdrive" (type=drive)
bin/discover-library-radio-folders   # write private folders.tsv + ham-radio-id-map.tsv
bin/sync-library-radio --list
bin/sync-library-radio --dry-run
bin/sync-library-radio               # copy (add/update)
bin/sync-library-radio --prune       # also delete local orphans
```

| Repo (public) | Local only (private) |
|---------------|----------------------|
| `scripts/library/library-radio-folder-names.txt` | `~/Documents/LibraryRadio/folders.tsv` |
| `bin/discover-library-radio-folders` | `~/Documents/LibraryRadio/ham-radio-id-map.tsv` |
| `bin/sync-library-radio` | rclone token in `~/.config/rclone/` |

Default names: Antennas, mirrors, Projects, Radio, Scanner, Software, Sounds.

**Missing / quarantine ledger (local only):** `bin/library-radio-missing report`,
`bin/library-radio-quarantine-pull`, `bin/library-radio-scan-quarantine`.
Ledger: `~/Documents/LibraryRadio/missing.tsv`. Holding: `holding/inbox/`.

## Memory / swap

| Device | Size | Priority | Notes |
|--------|------|----------|--------|
| `/dev/sdb3` | 4 GiB | −1 (default) | Plain partition on Hitachi HDD (outer tracks) |
| `rpool/swap` → `/dev/zvol/rpool/swap` | 33 GiB | **10** (preferred) | ZFS zvol; blocks prefer **special** vdev (TEAM SSD) via `special_small_blocks=8K` |

- fstab ZFS line: `UUID=… none swap sw,pri=10,nofail 0 0` (`nofail` so a missing zvol never stalls boot)
- Zvol props: `compression=off`, `primarycache=metadata`, `sync=always`, `refreservation` ~34 G
- Verify: `swapon --show` (expect both); `zpool list -v rpool` (special ALLOC grows as pages are written)

## ZFS recovery (rpool + bpool)

| Item | Detail |
|------|--------|
| Manual | `docs/B1GMB42-zfs-recovery.md` + `B1GMB42-zfs-recovery.pdf` |
| DOSBOOT kit | `IndianaDell/recovery/` on `sdc3` — `bin/deploy-dosboot-recovery` |
| Scripts | `mount-rpool-recovery.sh`, `scripts/recovery/mount-bpool-recovery.sh` |
| Live boot | Ventoy Ubuntu 26.04 from Uncle Wiggly 🥕🐰 — then Section 2 or 3 of recovery manual |
| **Force import (required)** | `/etc/default/zfs` → `ZPOOL_IMPORT_OPTS="-f"` (else boot can hang after recovery export) |
| **Swap zvol** | `rpool/swap` — `swapoff` before `zpool export` in recovery |

---

## Ventoy live persistence (Uncle Wiggly 🥕🐰)

| Item | Detail |
|------|--------|
| Nickname | **Uncle Wiggly** — rabbit hole / boot black hole for ISOs |
| Partition label | `Wiggly` (`sdc1`, `/mnt/wiggly`) |
| ISO | `ubuntu-26.04-desktop-amd64.iso` |
| Overlay | `persistence/ubuntu-26.04.dat` (24 GB on Uncle Wiggly) |
| Setup | `bin/setup-wiggly-ventoy` from Tower5810 |
| Autologin | GDM user `ubuntu` |
| Autostart | Grok fullscreen → IndianaDell session (currently disabled) |
| Seed script | `~/bin/seed-ventoy-persistence.sh` |

See Software Manual **Chapter 15**. PERC IT flash + **reset/revert**: `docs/B1GMB42-perc-it-flash.md`.  
Historical Augury fleet plan: `docs/augury-lab-inventory.md`. Fast boot/BIOS notes: `docs/fast-boot.md`.
## Gaps / not set up yet

- **No HackRF hardware detected** — flash and SD card copy prepared, not tested on device
- **Rust SDR crates** — toolchain ready; no project scaffold (`rtlsdr`, `soapysdr`, etc. install per-project with `cargo add`)
- **SDRangel / SigDigger** — not installed (URH + gqrx + inspectrum cover most desktop work)
- **Pre-crash apt list** — no full pre-crash package manifest saved; only current `apt-hamradio-dev-manifest.txt` and `FactoryDocs/MANIFEST-pre-crash.txt` (Dell driver files, not apt)