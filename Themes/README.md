# Themes module

Snapshots and customization toolkit for **boot** (Plymouth), **login** (GDM/GNOME Shell greeter), and **desktop** (Yaru) on Tower5810.

## Layout

| Folder | Stage | Apt packages (see `apt-packages.txt` in each) |
|--------|-------|---------------------------------------------|
| `boot/` | Plymouth splash | `plymouth`, `plymouth-theme-spinner`, … |
| `login/` | GDM login screen | `gdm3`, `gnome-shell`, `yaru-theme-gnome-shell` |
| `desktop/` | GTK / icons / shell | `yaru-theme-gtk`, `yaru-theme-icon`, … |
| `scripts/` | Extract, install, restore | — |

## Commands (`~/Documents/IndianaDell/bin/`)

```bash
bin/themes-extract          # refresh extracted logos + apt mirrors
sudo bin/themes-install-boot   # install custom Plymouth theme
sudo bin/themes-restore-boot   # revert to stock BGRT theme
bin/apply-dark-mode         # GNOME dark (login + desktop session)
bin/apply-max-performance   # no suspend / dimming
```

## Boot splash at a glance

1. **Center** — Dell logo from UEFI BGRT (BIOS firmware, not an Ubuntu file)
2. **Spinner** — dots animation (`plymouth-theme-spinner`)
3. **Bottom** — Ubuntu text watermark (`ubuntu-logo-text-dark.png`)

Replace (2)/(3) via `boot/overlay/` and `bin/themes-install-boot`. Replace (1) with `--oem` or change logo in BIOS setup.

See `MANIFEST.txt` for a one-page reference.