# Login apt mirrors

`/usr/share` files from packages that define the GDM / greeter experience.

| Subfolder | Package | Theming role |
|-----------|---------|--------------|
| `gdm3/` | `gdm3` | Greeter binaries, schemas, `gdm.schemas`, dbus config |
| `gnome-shell/` | `gnome-shell` | Shell JS, default theme stubs, extensions dir |
| `yaru-theme-gnome-shell/` | `yaru-theme-gnome-shell` | Yaru + Yaru-dark gresources, CSS, SVG |

See each subfolder’s README for key paths.

## Modify

Mirrors are reference copies. To change login appearance:

1. Prefer `bin/apply-dark-mode` for color scheme
2. For branding: replace assets in `yaru-theme-gnome-shell` mirror, then install to `/usr/share/gnome-shell/theme/Yaru-dark/` (backup first)
3. Re-run `bin/themes-extract` after `apt upgrade` to refresh mirrors

```bash
sudo apt install --reinstall gdm3 gnome-shell yaru-theme-gnome-shell
```