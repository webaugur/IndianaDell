# Stock Plymouth snapshots

Frozen copies of Ubuntu’s shipped boot themes, taken at extract time.

| Subfolder | Apt package | Notes |
|-----------|-------------|-------|
| `bgrt/` | `plymouth` + `plymouth-theme-spinner` | **Default on this machine** — uses BGRT + spinner `ImageDir` |
| `spinner/` | `plymouth-theme-spinner` | Animation frames, `watermark.png` symlink, `bgrt-fallback.png` |
| `spinner-watermark.png` | `plymouth` pixmaps | Copy of ubuntu-logo-text-dark for diffing |

## Purpose

- Diff against `../overlay/` or `../indianadell/` after edits
- Restore individual files if a custom install goes wrong (full restore: `bin/themes-restore-boot`)
- Reference for `.plymouth` keys (`WatermarkVerticalAlignment=0.96`, etc.)

Refresh: `bin/themes-extract` (overwrites `bgrt/` and `spinner/`).