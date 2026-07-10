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

## GNU Radio & desktop SDR (3.10.12)

Full toolkit with companion blocks:

- **Sources:** `gr-osmosdr` (RTL-SDR, HackRF, Airspy, etc.), SoapySDR, LimeSDR, UHD
- **Specialized:** `gr-air-modes` (ADS-B), `gr-dab`, `gr-satellites`, `gr-fosphor` (GPU waterfall), `gr-hpsdr`, `gr-limesdr`
- **Apps:** `gqrx`, `quisk`, `grcc` (compile `.grc` flowgraphs)
- **Analysis:** `inspectrum` (IQ file viewer), **URH 2.10.0** (decode/replay/protocol reverse-engineering)

**SoapySDR drivers loaded:** HackRF, RTL-SDR (osmosdr), Airspy, bladeRF, Lime, MiriSDR, HydraSDR, PlutoSDR, Red Pitaya, remote, audio.

---

## Ham radio (desktop)

| App | Use |
|-----|-----|
| **fldigi** | Digital modes (PSK, RTTY, etc.) |
| **WSJT-X** | Weak-signal (FT8, JT65, …) |
| **chirpw / chirpc** | Program amateur radios |
| **direwolf** | Sound-card TNC / APRS |
| **gpredict** | Satellite tracking |
| **grig** | Hamlib rig control GUI |
| **xastir** | APRS map client |
| **Hamlib** | Rig control library (C/Python) |

---

## HackRF / PortaPack Mayhem (v2.4.0)

Firmware, flash tools, and **276 MB SD card payload** live under `~/Documents/IndianaDell/hackrf/`.

See also: `hackrf/MANIFEST.txt`

### Host tools

`hackrf_info`, `hackrf_transfer`, `hackrf_sweep`, `hackrf_spiflash`, `hacktv` (analog TV TX), `dfu-util`, `openocd`

Built from source: `hackrf/build/hackrf-tools/src/`

### Release assets

| Asset | Path |
|-------|------|
| USB flash bundle | `hackrf/releases/FIRMWARE_mayhem_v2.4.0.zip` |
| SD card data (no world map) | `hackrf/releases/COPY_TO_SDCARD_hackrf_mayhem_v2.4.0-no-world-map.zip` |
| Web flasher image | `hackrf/releases/OCI_hackrf_mayhem_v2.4.0.ppfw.tar` |
| Extracted SD payload | `hackrf/sd-card/mayhem-v2.4.0/` |

### Mayhem onboard firmware (v2.4.0 highlights)

Morse RX/TX, RTTY RX/TX, FPV detect, ADSB RX (map/trails), ACARS RX, BLE RX, TPMS RX/TX, KeeLoq TX, EPIRB TX, SAME TX, MDC-1200 TX, P25 TX, KISS TNC, Looking Glass, Mic TX, SubGHz decoder, Flipper TX (OOK + 2FSK), waterfall designer, time sink, and more.

### SD card external apps (84)

Located in `hackrf/sd-card/mayhem-v2.4.0/APPS/`, including:

`fpv_detect`, `kiss_tnc`, `keeloqtx`, `epirb_tx`, `epirb_rx`, `flippertx`, `siggen`, `fmradio`, `sstvrx`, `sstvtx`, `wefax_rx`, `wardrivemap`, `waterfall_designer`, `time_sink`, and others.

### SD data folders

`SAMPLES`, `WAV`, `OOKFILES`, `SUBGHZ`, `KEELOQKEYS`, `FREQMAN`, `WATERFALLS`, `REMOTES`, `GPS`, `OSM`, `ADSB`, `AIS`, `CVSFILES`, `HOPPER`, `LOOKINGGLASS`, `SPLASH`, `SSTV`, `WHIPCALC`, …

### Source repos

`hackrf/repos/hackrf`, `mayhem-firmware`, `portapack-hackrf`, `urh`, `hacktv`

### Helper scripts

```bash
source ~/Documents/IndianaDell/bin/hackrf-env
bin/hackrf-setup-udev       # USB permissions (plugdev)
bin/hackrf-download-mayhem  # Re-fetch release assets
bin/hackrf-prepare-sdcard   # Extract SD card files
bin/hackrf-flash-mayhem     # Extract firmware flash bundle
bin/hackrf-build-mayhem     # Compile Mayhem from source
bin/urh                     # Universal Radio Hacker GUI
```

**Status:** No HackRF detected yet (`hackrf_info` → “No HackRF boards found”). Flash/SD steps are prepared but untested.

---

## SDR hardware support (when devices are plugged in)

| Device | Tools |
|--------|--------|
| **HackRF One / Pro** | Mayhem flash, gqrx, URH, GNU Radio, `hackrf_sweep` |
| **RTL-SDR** | `rtl_test`, gqrx, GNU Radio |
| **Airspy / bladeRF / Lime / UHD** | SoapySDR + GNU Radio blocks, host utils installed |

USB udev rules: `hackrf/scripts/99-hackrf.rules` (installed to `/etc/udev/rules.d/`).

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
| `bin/hackrf-env` | Source HackRF PATH (use with `source`) |
| `bin/urh` | Universal Radio Hacker |
| `bin/hackrf-*` | Mayhem flash, SD prep, udev, build |
| `bin/themes-extract` | Theme mirrors + boot logo extract |
| `bin/themes-install-boot` / `bin/themes-restore-boot` | Custom / stock Plymouth |
| `bin/apply-dark-mode` | GNOME + GDM dark |
| `bin/apply-max-performance` | No power saving / dimming |
| `bin/pull-repo` | Fetch IndianaDell + hackrf/repos + LFS (`--verify`, `--build-docs`) |
| `bin/push-repo` | Push main to GitHub (SSH default) |
| `bin/setup-wiggly-ventoy` | Verify Wiggly ISO + ventoy.json + persistence .dat |
| `bin/setup-perc-ventoy` | FreeDOS / PERC H710 IT flash kit on Wiggly |
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

## ZFS recovery (rpool + bpool)

| Item | Detail |
|------|--------|
| Manual | `docs/B1GMB42-zfs-recovery.md` + `B1GMB42-zfs-recovery.pdf` |
| DOSBOOT kit | `IndianaDell/recovery/` on `sdc3` — `bin/deploy-dosboot-recovery` |
| Scripts | `mount-rpool-recovery.sh`, `scripts/recovery/mount-bpool-recovery.sh` |
| Live boot | Ventoy Ubuntu 26.04 from Wiggly — then Section 2 or 3 of recovery manual |
| **Force import (required)** | `/etc/default/zfs` → `ZPOOL_IMPORT_OPTS="-f"` (else boot can hang after recovery export) |

---

## Ventoy live persistence (Wiggly stick)

| Item | Detail |
|------|--------|
| ISO | `ubuntu-26.04-desktop-amd64.iso` |
| Overlay | `persistence/ubuntu-26.04.dat` (24 GB on Wiggly / `sdc1`) |
| Setup | `bin/setup-wiggly-ventoy` from Tower5810 |
| Autologin | GDM user `ubuntu` |
| Autostart | Grok fullscreen → IndianaDell session |
| Seed script | `~/bin/seed-ventoy-persistence.sh` |

See Software Manual **Chapter 15**.

## Gaps / not set up yet

- **No HackRF hardware detected** — flash and SD card copy prepared, not tested on device
- **Rust SDR crates** — toolchain ready; no project scaffold (`rtlsdr`, `soapysdr`, etc. install per-project with `cargo add`)
- **SDRangel / SigDigger** — not installed (URH + gqrx + inspectrum cover most desktop work)
- **Pre-crash apt list** — no full pre-crash package manifest saved; only current `apt-hamradio-dev-manifest.txt` and `FactoryDocs/MANIFEST-pre-crash.txt` (Dell driver files, not apt)