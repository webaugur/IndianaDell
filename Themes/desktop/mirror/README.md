# Desktop apt mirrors

| Subfolder | Package | Theming role |
|-----------|---------|--------------|
| `yaru-theme-gtk/` | `yaru-theme-gtk` | GTK2/3/4 themes, gtksourceview styles |
| `yaru-theme-icon/` | `yaru-theme-icon` | Yaru + Yaru-dark icon theme (~19k files) |
| `yaru-theme-gnome-shell/` | `yaru-theme-gnome-shell` | Shell CSS/gresource (same as login mirror) |
| `yaru-theme-sound/` | `yaru-theme-sound` | Login/logout/event sounds |

Nested icon size dirs (`16x16/`, `48x48/`, …) are not documented individually — edit at theme root level.

## Modify workflow

1. Change files in mirror (or system path directly)
2. Test: `gtk-launch` or re-login
3. Persist: copy to `/usr/share/themes/Yaru-dark/` or `/usr/share/icons/Yaru-dark/`
4. Re-extract after package upgrades

```bash
sudo apt install --reinstall yaru-theme-gtk yaru-theme-icon yaru-theme-gnome-shell yaru-theme-sound
bin/apply-dark-mode
```