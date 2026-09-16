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

```bash
sudo bin/apply-sensor-watch          # thermal/fan watchdog (delayed systemd)
indiana-sensor-watch --once          # print current sensors
```

## 2. GNOME session preferences

Run as the **desktop user** (not root):

```bash
bin/apply-dark-mode                  # Yaru-dark GTK, shell, icons, GDM greeter
bin/apply-max-performance            # no suspend, dimming, or night light
bin/fix-nautilus-desktop-launch     # Nautilus 50+: double-click .desktop launches app
bin/sync-desktop-icons               # Nautilus 50+: show Icon= as file icon
```

**Verify:**

```bash
gsettings get org.gnome.desktop.interface color-scheme
powerprofilesctl get
bin/fix-nautilus-desktop-launch --status   # expect application/x-desktop → xdg-desktop-launch
bin/sync-desktop-icons -v                   # sets metadata::custom-icon* from Icon=
```

See Chapter 7 for every gsettings key touched, the Nautilus 50 “Allow Launching” note, and custom-icon metadata.

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
bin/install-dragonsdr --verify-only   # suite present?
source bin/hackrf-env                 # PATH → ~/Documents/DragonSDR/hackrf
hackrf_info                           # should list board
bin/hackrf-flash-mayhem               # extract USB flash bundle
# follow bundle README for DFU flash
bin/hackrf-prepare-sdcard             # ensure SD tree is extracted
# copy ~/Documents/DragonSDR/hackrf/sd-card/mayhem-v2.4.0/* to FAT32 microSD root
```

**Verify:** `hackrf_info`, on-device Mayhem version, SD apps visible on PortaPack.

See Chapter 10 and `~/Documents/DragonSDR/README.md`.

## 5. KiCad 10 and tscircuit (workstation default)

Installed by `bin/rebuild-machine` Phase 2b unless `SKIP_KICAD=1`. Opt out is rebuild-time only; this checklist just confirms the GUI/CLI stack.

**KiCad 10** (PPA `kicad/kicad-10.0-releases`): schematic/PCB editor, 3D models, `ngspice`, `gerbv`.

**tscircuit** ([github.com/tscircuit/tscircuit](https://github.com/tscircuit/tscircuit)): TypeScript/React circuits via `tsci`. Export to KiCad, then open the files in KiCad 10. Autorouter package is `@tscircuit/capacity-autorouter` ([tscircuit-autorouter](https://github.com/tscircuit/tscircuit-autorouter)), installed under `~/.local` with `tsci`.

```bash
kicad-cli version
python3 -c 'import pcbnew; print(pcbnew.Version())'
command -v ngspice gerbv gerbview tsci
tsci --help | head
```

## 5b. samsungtv (workstation default)

Installed by `bin/rebuild-machine` Phase 2c unless `SKIP_SAMSUNGTV=1`. LAN remote for the Tower5810 Samsung (UN32M4500, `10.0.0.31`). First run: Allow the client on the TV.

```bash
samsungtv device-info
samsungtv home
```

TypeScript → KiCad:

```bash
tsci init my-board
cd my-board
tsci export index.tsx -f kicad_sch    # also kicad_pcb, kicad_zip, kicad-library
```

Expect `10.0.*` from `kicad-cli` and `pcbnew`. `kicad-doc-id` may remain on 9.x; that is not a blocker.

## 6. Documentation PDFs

```bash
bin/build-all-docs                    # software manual + hardware + inventory PDFs
# or:
bin/build-software-manual             # this manual only
```

Outputs: `B1GMB42-software-manual.pdf`, `B1GMB42-slot-port-inventory.pdf`, `B1GMB42-software-inventory.pdf`.

## 7. Machine inventory baseline

```bash
bin/dellmerge > b1gmb42.report
sudo bin/iotest                       # optional storage survey
bin/gpu-stress 60 vkcube              # optional GPU smoke test
```

## 8. FactoryDocs recovery (optional)

Only 19 of 101 pre-crash Dell packages are on disk. Re-download per `FactoryDocs/README.md` and `MANIFEST-pre-crash.txt`. These are **workspace archives**, not installed by rebuild.

See Chapter 13.

## 9. ZFS force import (required on this host)

After any reinstall or recovery chroot, confirm the installed system will force-import pools at boot:

```bash
grep '^ZPOOL_IMPORT_OPTS' /etc/default/zfs
# must show: ZPOOL_IMPORT_OPTS="-f"
```

If missing, set it in `/etc/default/zfs`, then `sudo update-initramfs -c -k all`. Without this, boot can hang after a recovery export or unclean shutdown. See Chapter 2 and `docs/B1GMB42-zfs-recovery.md`.

## Quick verification block

```bash
cd ~/Documents/IndianaDell
bin/rebuild-machine --verify-only
kicad-cli version                             # expect 10.0.*
tsci --help >/dev/null && echo OK tscircuit   # TypeScript → KiCad
grep '^ZPOOL_IMPORT_OPTS' /etc/default/zfs    # expect "-f"
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
| Nautilus 50 .desktop launch | `bin/fix-nautilus-desktop-launch` | No |
| Nautilus 50 .desktop icons | `bin/sync-desktop-icons` | No |
| Custom boot | `sudo bin/themes-install-boot` | Yes |
| HackRF flash | `bin/hackrf-flash-mayhem` + DFU | Maybe |
| KiCad 10 + tscircuit | `kicad-cli version`; `tsci export … -f kicad_sch` | No |
| ROCm (optional) | `bin/amd-install` | Yes |
| All doc PDFs | `bin/build-all-docs` | No |
| ZFS force import | check `/etc/default/zfs` → `ZPOOL_IMPORT_OPTS="-f"` | If initramfs updated |
| Ventoy persistence seed | `~/bin/seed-ventoy-persistence.sh` | No |