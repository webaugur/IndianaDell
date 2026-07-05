# Boot apt mirrors

Exact `/usr/share` files from installed `.deb` packages. Built by `Themes/scripts/copy-apt-package.sh` during `bin/themes-extract`.

| Subfolder | Package | What it themes |
|-----------|---------|----------------|
| `plymouth/` | `plymouth` | Core Plymouth themes dir, pixmaps, modules |
| `plymouth-theme-spinner/` | `plymouth-theme-spinner` | Spinner animation PNGs + `spinner.plymouth` |
| `plymouth-theme-ubuntu-text/` | `plymouth-theme-ubuntu-text` | Text-mode fallback theme |

## Modify

Do **not** edit mirrors in place — they are overwritten on extract.

Workflow:

1. Diff mirror vs `../stock/` or system `/usr/share/plymouth/`
2. Copy changed assets to `../overlay/`
3. `sudo bin/themes-install-boot`

## Restore package files on system

```bash
sudo apt install --reinstall plymouth plymouth-theme-spinner
sudo bin/themes-restore-boot
```