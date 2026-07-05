# Desktop themes (Yaru)

GTK applications, icons, GNOME Shell session, and event sounds after login.

## Active settings (this machine)

| Layer | Value | Set by |
|-------|-------|--------|
| Color scheme | `prefer-dark` | `bin/apply-dark-mode` |
| GTK theme | `Yaru-dark` | `bin/apply-dark-mode` |
| Icons | `Yaru-dark` | `bin/apply-dark-mode` |
| Shell | `Yaru-dark` | `yaru-theme-gnome-shell` + gsettings |

## Subfolders

| Path | Purpose |
|------|---------|
| `mirror/` | Full `/usr/share` mirrors per apt package |

## Modify desktop look

```bash
bin/apply-dark-mode          # system-wide dark (GTK + shell + icons)
gsettings set org.gnome.desktop.interface gtk-theme 'Yaru-blue-dark'   # accent variant
```

**GTK apps:** edit `mirror/yaru-theme-gtk/` → install to `/usr/share/themes/`  
**Icons:** edit `mirror/yaru-theme-icon/` (large tree) → `/usr/share/icons/`  
**Shell:** see `login/mirror/yaru-theme-gnome-shell/README.md`  
**Sounds:** `mirror/yaru-theme-sound/` → `/usr/share/sounds/Yaru/`

Refresh mirrors: `bin/themes-extract` (~2 min; icon mirror is large).