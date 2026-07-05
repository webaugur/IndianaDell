# Login settings snapshots

Point-in-time exports of GNOME appearance keys relevant to the greeter and session. Written by `bin/themes-extract`.

| File | Contents |
|------|----------|
| `user-gsettings-dark.txt` | `color-scheme`, `gtk-theme`, `icon-theme`, `org.gnome.shell.ubuntu` |
| `dconf-interface.txt` | `dconf dump` of `/org/gnome/desktop/interface/` |

## Use

- **Diff** after changing `bin/apply-dark-mode` to see what moved
- **Reapply manually:** `dconf load /org/gnome/desktop/interface/ < dconf-interface.txt`
- **Not auto-restored** on rebuild — run `bin/apply-dark-mode` on a fresh install

GDM has its own dconf profile (`/var/lib/gdm3/`); greeter dark mode is set by `apply-dark-mode.sh` when `APPLY_GDM=1` (default).