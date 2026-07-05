# Chapter 5 — Themes (Boot, Login, Desktop)

## What gets installed

The **Themes/** module (~194 MB with mirrors) documents and customizes three visual stages:

| Stage | What you see | Apt packages | Workspace folder |
|-------|--------------|--------------|------------------|
| **Boot** | Dell BGRT center + spinner + Ubuntu watermark | `plymouth`, `plymouth-theme-spinner`, … | `Themes/boot/` |
| **Login** | GDM on GNOME Shell | `gdm3`, `gnome-shell`, `yaru-theme-gnome-shell` | `Themes/login/` |
| **Desktop** | Yaru GTK, icons, shell | `yaru-theme-gtk`, `yaru-theme-icon`, … | `Themes/desktop/` |

**Active Plymouth theme:** `bgrt` at `/usr/share/plymouth/themes/bgrt/bgrt.plymouth`

**Extracted boot logos:**

- `Themes/boot/extracted/bgrt-firmware-oem.png` — Dell from UEFI BGRT (`/sys/firmware/acpi/bgrt/image`)
- `Themes/boot/extracted/ubuntu-watermark-dark.png` — bottom Ubuntu text

**Custom Plymouth install target:** `indianadell` theme under `/usr/share/plymouth/themes/indianadell/`

Each subfolder has its own `README.md` and `apt-packages.txt`. See `Themes/MANIFEST.txt` for a one-page map.

## How it is installed

Themes are **not** applied by `bin/rebuild-machine`. Use launchers:

```bash
bin/themes-extract              # snapshot apt-owned files + extract logos (~193 MB mirrors)
sudo bin/themes-install-boot    # install custom Plymouth from boot/overlay/
sudo bin/themes-restore-boot    # revert to stock bgrt
bin/apply-dark-mode             # login + desktop dark (Chapter 7)
```

**Boot overlay workflow:**

```bash
cp my-logo.png Themes/boot/overlay/watermark.png    # bottom Ubuntu text only
sudo bin/themes-install-boot

cp my-splash.png Themes/boot/overlay/background.png
sudo bin/themes-install-boot --oem                  # replace center (disable BGRT)

sudo bin/themes-install-boot --no-watermark         # hide bottom logo
```

Every Plymouth install runs `update-initramfs -u` — **reboot required** to preview.

## How to verify

```bash
plymouth-set-default-theme -l
plymouth-set-default-theme                    # shows active theme
ls Themes/boot/extracted/
gsettings get org.gnome.desktop.interface gtk-theme   # after apply-dark-mode
```

## How to customize

Deep documentation lives in module READMEs — this chapter summarizes:

- **Boot:** `Themes/boot/README.md` — overlay/, stock/, indianadell/ plymouth definition
- **Login:** `Themes/login/README.md` — GDM greeter assets mirrored from apt
- **Desktop:** `Themes/desktop/README.md` — GTK/icon/shell Yaru variants

**Center Dell logo** comes from BIOS BGRT firmware, not an Ubuntu file. Change it in BIOS setup or use `--oem` with your PNG.

## What rebuild does / does not do

| Does | Does not |
|------|----------|
| Install `plymouth`, `gdm3`, Yaru via apt (Phase 2–3) | Run `themes-extract` or `themes-install-boot` |
| | Set dark mode or GDM greeter prefs |
| | Copy overlay PNGs into initramfs |

Run Chapter 3 checklist items 2 and 3 after rebuild.