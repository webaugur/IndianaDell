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
| `generated/dell-animation/` | Animated Dell BGRT frames + `preview.gif` |
| `staging/indianadell/` | Local theme tree for preview (gitignored; built by `--stage-only`) |
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

# Animate the Dell BGRT logo (ring-orbit + wizard + sparkling ᏃᏫᏍ):
python3 Themes/scripts/generate-dell-animation.py   # optional; stage/install regenerates if missing
bin/themes-preview-boot --animated-dell             # SAFE windowed preview (no root, no reboot)
sudo bin/themes-install-boot --animated-dell        # only when happy — updates initramfs

# Hide bottom watermark:
sudo bin/themes-install-boot --no-watermark

# Back to factory:
sudo bin/themes-restore-boot
```

### Safe preview (recommended before install)

```bash
bin/themes-preview-boot                  # stage + window (defaults to animated Dell if frames exist)
bin/themes-preview-boot --animated-dell  # force Dell+wizard scene
bin/themes-preview-boot --width 1920 --height 1080
bin/themes-preview-boot --theme Themes/boot/staging/indianadell
```

| Key | Action |
|-----|--------|
| `Esc` / `q` | Quit |
| `Space` | Pause / resume |
| `F` | Fullscreen |
| `1` | Boot animation mode |
| `2` | Fake password dialog |
| `R` | Restage theme |

Staging tree (no system changes): `Themes/boot/staging/indianadell/` via  
`Themes/scripts/install-boot-theme.sh --stage-only [--animated-dell]`.

Install still runs `update-initramfs -u` — **reboot** only for the final real check.

### Animated Dell mode

`--animated-dell` builds a full boot scene from the extracted UEFI BGRT logo:

| Layer | Behavior |
|-------|----------|
| Firmware BGRT | Disabled (`UseFirmwareBackground=false`) |
| `animation-*.png` / `throbber-*.png` | 60-frame scene: Dell ring-orbit (top) + wizard waving wand (bottom) + fixed sparkling **ᏃᏫᏍ** |
| Background | Solid black |
| Alignment | Centered (`.5`) instead of stock lower spinner |
| Watermark | Omitted by default (scene has its own bottom art) |

Frames live in `generated/dell-animation/` (regenerate anytime from `extracted/bgrt-firmware-oem.png`).

```bash
python3 Themes/scripts/generate-dell-animation.py
# open generated/dell-animation/preview.gif
```

## Apt packages

Listed in `apt-packages.txt`. Re-mirror after upgrades: `bin/themes-extract`.