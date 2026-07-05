# Chapter 10 — HackRF and PortaPack Mayhem

## What gets installed

**Recommended firmware:** [PortaPack Mayhem v2.4.0](https://github.com/portapack-mayhem/mayhem-firmware/releases/tag/v2.4.0)

### Apt packages

`hackrf`, `hackrf-firmware`, `libhackrf-dev`, `hackrf-doc`, `inspectrum`, `hacktv`, `dfu-util`, `openocd`, ARM GCC toolchain, plus GNU Radio/SoapySDR deps (Chapter 8).

### Built from source (`hackrf/build/`)

| Tool | Notes |
|------|-------|
| `hackrf_sweep` | Spectrum sweep — not in older apt splits |
| `hackrf_info`, `hackrf_transfer`, … | Newer libhackrf (0.10.0) than apt alone |
| `libhackrf.so` | Under `hackrf/build/libhackrf/src/` |

Install prefix: `hackrf/local/` (CMAKE_INSTALL_PREFIX).

### Release assets (`hackrf/releases/`)

| File | Size | Purpose |
|------|------|---------|
| `FIRMWARE_mayhem_v2.4.0.zip` | 8 MB | USB flash bundle |
| `COPY_TO_SDCARD_hackrf_mayhem_v2.4.0-no-world-map.zip` | 201 MB | PortaPack microSD |
| `OCI_hackrf_mayhem_v2.4.0.ppfw.tar` | 2.5 MB | Web flasher image |

**Extracted SD tree:** `hackrf/sd-card/mayhem-v2.4.0/` (276 MB, 84 apps in `APPS/`)

### Source repos (`hackrf/repos/`)

`hackrf`, `mayhem-firmware` (+ submodules), `portapack-hackrf`, `urh`, `hacktv`

### Python venv

`hackrf/venv-urh/` — Universal Radio Hacker **2.10.0** (PyQt6). Launch: `bin/urh`

### udev

`hackrf/scripts/99-hackrf.rules` installed to `/etc/udev/rules.d/` — plugdev access.

## How it is installed

**Automated (rebuild Phases 6–10):**

1. Clone repos (shallow, skip if `.git` exists)
2. Init Mayhem submodules if needed
3. `cmake` + build HackRF host (skip: `SKIP_HACKRF_BUILD=1`)
4. `hackrf/scripts/download-mayhem.sh`
5. `hackrf/scripts/prepare-sdcard.sh`
6. URH venv if missing
7. `hackrf/scripts/setup-udev.sh`

**Manual (hardware present):**

```bash
source bin/hackrf-env
bin/hackrf-flash-mayhem         # extract flash bundle
bin/hackrf-prepare-sdcard       # re-extract SD payload
bin/hackrf-build-mayhem         # compile Mayhem from source (advanced)
bin/hackrf-download-mayhem      # re-fetch releases
```

**PATH:** `source bin/hackrf-env` adds `hackrf/build/hackrf-tools/src` and `hackrf/local/bin`.

## How to verify

```bash
bin/rebuild-machine --verify-only
source bin/hackrf-env
hackrf_info                     # needs USB device
hackrf/build/hackrf-tools/src/hackrf_sweep --help | head -1
bin/urh --version
ls hackrf/sd-card/mayhem-v2.4.0/APPS | wc -l
```

## How to customize

- **Upgrade Mayhem:** Edit `hackrf/scripts/download-mayhem.sh` version URLs; re-run download + prepare
- **SD apps:** Copy subsets from `sd-card/mayhem-v2.4.0/APPS/` to microSD
- **Full inventory:** `hackrf/MANIFEST.txt`

### Mayhem v2.4.0 highlights

On-device: Morse RX/TX, RTTY, FPV detect, ADSB, ACARS, BLE, TPMS, KeeLoq, EPIRB, SAME, MDC-1200, P25, KISS TNC, Looking Glass, SubGHz, Flipper TX, waterfall designer, time sink.

SD apps include: `fpv_detect`, `kiss_tnc`, `keeloqtx`, `siggen`, `fmradio`, `sstvrx`, `wardrivemap`, `waterfall_designer`, and more.

## What rebuild does / does not do

| Does | Does not |
|------|----------|
| Clone repos, build tools, download Mayhem | DFU-flash firmware to hardware |
| Create URH venv, install udev | Format or write microSD in a reader |
| Verify zip, SD tree, hackrf_sweep | Test with HackRF USB attached |