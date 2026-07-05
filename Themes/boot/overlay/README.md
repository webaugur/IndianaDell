# Boot overlay (your replacements)

Drop PNG images here, then install:

```bash
sudo bin/themes-install-boot
```

| File | Replaces | Keeps Dell BGRT? |
|------|----------|------------------|
| `watermark.png` | Bottom Ubuntu text logo | Yes |
| `background.png` | Full boot background | No — use with `--oem` |

## Examples

```bash
# Custom bottom badge only:
cp ~/art/tower5810-badge.png watermark.png
sudo bin/themes-install-boot

# Full custom center splash (no Dell firmware logo):
cp ~/art/splash-1920.png background.png
sudo bin/themes-install-boot --oem background.png
```

## Image tips

- **Watermark:** ~187×72 or similar wide aspect; transparent PNG works best.
- **Background:** match display resolution if possible; black letterboxing is OK on mismatch.
- Plymouth uses `background.png` only when `UseFirmwareBackground=false`.

Installed copies land in `/usr/share/plymouth/themes/indianadell/`. Overlay is kept as your source of truth for re-runs.