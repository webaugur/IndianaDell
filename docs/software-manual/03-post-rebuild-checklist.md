# Chapter 3 — Post-Rebuild Checklist

`bin/rebuild-machine` intentionally stops before steps that need a logged-in desktop, a reboot, or hardware attached. Run this checklist once per fresh install.

## 1. GPU session configuration

Tower5810 has three AMD FirePro cards (W5000/W5100). Multi-GPU Wayland/X11 configs live in `etc/`.

```bash
cd ~/Documents/IndianaDell
sudo bin/apply-amdgpu
sudo reboot
```

**Verify after reboot:** `echo $WAYLAND_DISPLAY`, `glxinfo -B`, `vkcube` on each display if needed.

See Chapter 6 for ROCm (`bin/amd-install`) — optional and not supported for ML on these GPUs.

## 2. GNOME session preferences

Run as the **desktop user** (not root):

```bash
bin/apply-dark-mode          # Yaru-dark GTK, shell, icons, GDM greeter
bin/apply-max-performance    # no suspend, dimming, or night light
```

**Verify:**

```bash
gsettings get org.gnome.desktop.interface color-scheme
powerprofilesctl get
```

See Chapter 7 for every gsettings key touched.

## 3. Boot splash (optional)

Default Ubuntu **bgrt** Plymouth theme shows Dell BGRT center + Ubuntu watermark. To customize:

```bash
bin/themes-extract                    # refresh mirrors + extract logos
# edit Themes/boot/overlay/watermark.png or background.png
sudo bin/themes-install-boot          # or --oem / --no-watermark
sudo reboot
```

Restore factory: `sudo bin/themes-restore-boot`

See Chapter 5.

## 4. HackRF hardware (when device is available)

```bash
source bin/hackrf-env
hackrf_info                           # should list board
bin/hackrf-flash-mayhem               # extract USB flash bundle
# follow bundle README for DFU flash
bin/hackrf-prepare-sdcard             # ensure SD tree is extracted
# copy hackrf/sd-card/mayhem-v2.4.0/* to FAT32 microSD root
```

**Verify:** `hackrf_info`, on-device Mayhem version, SD apps visible on PortaPack.

See Chapter 10.

## 5. Documentation PDFs

```bash
bin/build-software-manual             # this manual
pandoc B1GMB42-slot-port-inventory.md -o B1GMB42-slot-port-inventory.pdf \
  --pdf-engine=xelatex -V mainfont="Noto Sans" -V monofont="DejaVu Sans Mono"
```

## 6. Machine inventory baseline

```bash
bin/dellmerge > b1gmb42.report
sudo bin/iotest                       # optional storage survey
bin/gpu-stress 60 vkcube              # optional GPU smoke test
```

## 7. FactoryDocs recovery (optional)

Only 19 of 101 pre-crash Dell packages are on disk. Re-download per `FactoryDocs/README.md` and `MANIFEST-pre-crash.txt`. These are **workspace archives**, not installed by rebuild.

See Chapter 13.

## Quick verification block

```bash
cd ~/Documents/IndianaDell
bin/rebuild-machine --verify-only
source bin/hackrf-env
. ~/.cargo/env && rustc --version
gnuradio-config-info --version
bin/urh --version
```

## Summary table

| Step | Command | Reboot? |
|------|---------|---------|
| GPU configs | `sudo bin/apply-amdgpu` | Yes |
| Dark mode | `bin/apply-dark-mode` | No |
| Max performance | `bin/apply-max-performance` | No |
| Custom boot | `sudo bin/themes-install-boot` | Yes |
| HackRF flash | `bin/hackrf-flash-mayhem` + DFU | Maybe |
| ROCm (optional) | `bin/amd-install` | Yes |
| Manual PDF | `bin/build-software-manual` | No |