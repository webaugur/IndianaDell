# Boot themes (Plymouth)

Controls the animated splash between firmware handoff and GDM login.

**Active system theme:** `bgrt` → `/usr/share/plymouth/themes/bgrt/bgrt.plymouth`  
Uses UEFI **BGRT** for the center OEM logo and `spinner/` assets for animation + watermark.

## Subfolders

| Path | Purpose |
|------|---------|
| `extracted/` | Logos pulled from live system (Dell BMP/PNG, Ubuntu watermarks) |
| `stock/` | Frozen copy of stock `bgrt` + `spinner` theme dirs |
| `overlay/` | **Your** replacement PNGs before install |
| `indianadell/` | Custom `.plymouth` definition installed to `/usr/share/plymouth/themes/indianadell/` |
| `mirror/` | Files owned by boot-related apt packages under `/usr/share` |

## Modify boot splash

```bash
# Bottom Ubuntu logo only:
cp my-logo.png overlay/watermark.png
sudo bin/themes-install-boot

# Replace center (disable Dell BGRT, use your PNG):
cp my-splash.png overlay/background.png
sudo bin/themes-install-boot --oem overlay/background.png

# Hide bottom watermark:
sudo bin/themes-install-boot --no-watermark

# Back to factory:
sudo bin/themes-restore-boot
```

Every install runs `update-initramfs -u` — **reboot** to preview.

## Apt packages

Listed in `apt-packages.txt`. Re-mirror after upgrades: `bin/themes-extract`.