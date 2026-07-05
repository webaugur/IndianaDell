# Mirror: yaru-theme-icon

**Package:** `yaru-theme-icon`  
**Role:** Freedesktop icon theme — folders, apps, devices, status icons.

Structure: `usr/share/icons/Yaru-dark/{16x16,22x22,…,scalable}/categories/` etc.

`Yaru-dark` inherits many icons from base `Yaru` — both are mirrored.

## Modify

- Replace individual PNG/SVG under size directories
- Or add `index.theme` variants
- Run `gtk-update-icon-cache` after system install:

```bash
sudo gtk-update-icon-cache -f /usr/share/icons/Yaru-dark
```

**Size:** ~19k files — mirror is for backup/diff, not hand-editing every icon. Prefer symbolics in `scalable/status/` for small changes.

Refresh: `bin/themes-extract` (slowest step).