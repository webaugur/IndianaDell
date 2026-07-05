# Stock theme: spinner (assets)

Jimmac’s spinner animation used by both `spinner` and `bgrt` themes.

| Asset | Purpose |
|-------|---------|
| `animation-*.png` | Boot progress spinner frames |
| `throbber-*.png` / `throbber.svg` | Alternative spinner graphics |
| `watermark.png` | Symlink → `../../../pixmaps/ubuntu-logo-text-dark.png` |
| `bgrt-fallback.png` | 128×128 placeholder if UEFI BGRT unavailable |
| `lock.png`, `bullet.png` | Password / multi-display prompts |

Custom installs copy this entire directory to `/usr/share/plymouth/themes/indianadell/` then patch `watermark.png` and optional `background.png`.