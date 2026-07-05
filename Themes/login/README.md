# Login themes (GDM)

The login greeter runs **GDM3** on top of **GNOME Shell** with **Yaru** shell styling.

Unlike boot (Plymouth), there is no single image file — appearance comes from:

- `gdm3` — greeter session, schemas, defaults
- `gnome-shell` — shell UI, login dialog
- `yaru-theme-gnome-shell` — Yaru CSS, gresources, SVG assets

## Subfolders

| Path | Purpose |
|------|---------|
| `extracted/` | Saved gsettings/dconf snapshots (dark mode, etc.) |
| `mirror/` | Apt-owned `/usr/share` files for login packages |

## Modify login look

**Session / desktop user (after login):**

```bash
bin/apply-dark-mode      # prefer-dark + Yaru-dark GTK/icons/shell
bin/apply-max-performance
```

**GDM greeter (login screen before session):**

`apply-dark-mode.sh` optionally sets GDM via `sudo dbus-run-session gsettings` (requires re-run after changes).

**Deep customization:**

1. Edit files under `mirror/yaru-theme-gnome-shell/` (reference only)
2. Install modified theme to `/usr/share/gnome-shell/theme/` or use extension
3. Or override with `gnome-shell-theme.gresource` rebuild (advanced)

For most users, `bin/apply-dark-mode` + reboot is sufficient.

Refresh mirrors: `bin/themes-extract`.