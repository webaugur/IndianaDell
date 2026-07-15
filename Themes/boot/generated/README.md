# Generated boot assets

Machine-built files — safe to delete and regenerate.

| Path | Generator | Purpose |
|------|-----------|---------|
| `dell-animation/` | `Themes/scripts/generate-dell-animation.py` | 60-frame boot scene for Plymouth |

### Scene contents (`dell-animation/`)

1. **Dell BGRT logo** (top) — ring-orbit highlight + soft pulse  
2. **Little wizard** (bottom left of group) — waves a star wand  
3. **ᏃᏫᏍ** (bottom right of group) — fixed in place, twinkles/sparkles  

```bash
# Rebuild frames from extracted BGRT logo (+ Noto Sans Cherokee for the text)
python3 Themes/scripts/generate-dell-animation.py

# Install as active boot theme
sudo bin/themes-install-boot --animated-dell
```

Preview without rebooting: open `dell-animation/preview.gif`.