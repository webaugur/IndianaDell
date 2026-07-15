# Theme scripts

| Script | Called by | Purpose |
|--------|-----------|---------|
| `extract-all.sh` | `bin/themes-extract` | BGRT + watermark extract; mirror all apt theme packages; save login dconf |
| `copy-apt-package.sh` | `extract-all.sh` | Copy one package’s `/usr/share` files into a mirror dir |
| `generate-dell-animation.py` | (manual / install) | Build 60-frame Dell BGRT + wizard + sparkling ᏃᏫᏍ for Plymouth |
| `plymouth-preview.py` | `bin/themes-preview-boot` | **Safe** windowed two-step simulator (no root, no initramfs) |
| `install-boot-theme.sh` | `bin/themes-install-boot` | Install `indianadell` Plymouth theme, patch watermark/OEM, `update-initramfs` |
| `install-boot-theme.sh --stage-only` | preview / manual | Build `boot/staging/indianadell/` only |
| `install-boot-theme.sh --animated-dell` | `bin/themes-install-boot --animated-dell` | Install animated Dell logo as center spinner |
| `install-boot-theme.sh --restore-stock` | `bin/themes-restore-boot` | Reset `default.plymouth` to stock `bgrt` |

Related (outside `Themes/`):

| Script | Purpose |
|--------|---------|
| `scripts/gnome/apply-dark-mode.sh` | GTK + shell + GDM dark |
| `scripts/gnome/apply-max-performance.sh` | No suspend/dim/night-light |

All scripts are idempotent — safe to re-run.