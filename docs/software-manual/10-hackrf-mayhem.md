# Chapter 10 — HackRF and PortaPack Mayhem

## Ownership

The HackRF / PortaPack Mayhem workspace moved out of IndianaDell into **DragonSDR**:

| Item | Path |
|------|------|
| Workspace | `~/Documents/DragonSDR/hackrf/` |
| Manifest | `~/Documents/DragonSDR/hackrf/MANIFEST.txt` |
| Suite install | `~/Documents/DragonSDR/bin/install-suite` |
| IndianaDell wrappers | `bin/hackrf-*`, `bin/urh`, `bin/install-dragonsdr` |

## What gets installed

**Recommended firmware:** [PortaPack Mayhem v2.4.0](https://github.com/portapack-mayhem/mayhem-firmware/releases/tag/v2.4.0)

### Apt packages

`hackrf`, `hackrf-firmware`, `libhackrf-dev`, `hackrf-doc`, `inspectrum`, `hacktv`, `dfu-util`, `openocd`, ARM GCC toolchain, plus GNU Radio/SoapySDR deps (Chapter 8).

### Built from source (`DragonSDR/hackrf/build/`)

| Tool | Notes |
|------|-------|
| `hackrf_sweep` | Spectrum sweep |
| `hackrf_info`, `hackrf_transfer`, … | Host utilities |
| `libhackrf.so` | Under `hackrf/build/libhackrf/src/` |

Install prefix: `hackrf/local/` (CMAKE_INSTALL_PREFIX).

### Release assets (`hackrf/releases/`)

| File | Purpose |
|------|---------|
| `FIRMWARE_mayhem_v2.4.0.zip` | USB flash bundle |
| `COPY_TO_SDCARD_hackrf_mayhem_v2.4.0-no-world-map.zip` | PortaPack microSD |
| `OCI_hackrf_mayhem_v2.4.0.ppfw.tar` | Web flasher image |

**Extracted SD tree:** `hackrf/sd-card/mayhem-v2.4.0/`

### Source repos (`hackrf/repos/`)

`hackrf`, `mayhem-firmware` (+ submodules), `portapack-hackrf`, `urh`, `hacktv`

### Python venv

`hackrf/venv-urh/` — Universal Radio Hacker. Launch: `bin/urh` (wrapper → DragonSDR).

### udev

`hackrf/scripts/99-hackrf.rules` → `/etc/udev/rules.d/`

## How it is installed

```bash
bin/install-dragonsdr                 # full suite
SKIP_HACKRF_BUILD=1 bin/install-dragonsdr
bin/install-dragonsdr --hackrf-only   # workspace only (apt already done)
```

**Manual (hardware present):**

```bash
source bin/hackrf-env                 # PATH → DragonSDR/hackrf/build
bin/hackrf-flash-mayhem
bin/hackrf-prepare-sdcard
bin/hackrf-build-mayhem               # compile Mayhem from source
bin/hackrf-download-mayhem
bin/urh
```

## How to verify

```bash
bin/install-dragonsdr --verify-only
source bin/hackrf-env
hackrf_info
ls ~/Documents/DragonSDR/hackrf/sd-card/mayhem-v2.4.0/APPS | wc -l
bin/urh --version
```
