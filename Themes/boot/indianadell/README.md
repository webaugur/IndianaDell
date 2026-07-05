# IndianaDell Plymouth theme

Source template for the custom boot theme installed to:

`/usr/share/plymouth/themes/indianadell/`

## Files

| File | Role |
|------|------|
| `indianadell.plymouth` | Theme definition (copied + patched by `install-boot-theme.sh`) |

At install time the script also rsyncs `../stock/spinner/` assets into the system theme dir and applies overlay images.

## `install-boot-theme.sh` patches

| Mode | `UseFirmwareBackground` | `background.png` |
|------|----------------------|------------------|
| Default | `true` | removed |
| `--oem FILE` | `false` | your image (clears Dell BGRT) |

Watermark controlled by `overlay/watermark.png`, `--watermark`, or `--no-watermark`.

## Priority

Installed with `update-alternatives` priority **120** (stock `bgrt` is 110), so IndianaDell wins until `bin/themes-restore-boot`.