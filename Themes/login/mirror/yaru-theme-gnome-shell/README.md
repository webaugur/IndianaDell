# Mirror: yaru-theme-gnome-shell (login)

**Package:** `yaru-theme-gnome-shell`  
**Role:** Yaru / Yaru-dark GNOME Shell theme — **primary visual for login greeter**.

Key files (under `usr/share/gnome-shell/theme/`):

| Path | Purpose |
|------|---------|
| `Yaru/gnome-shell.css` | Light shell stylesheet |
| `Yaru-dark/gnome-shell.css` | **Dark** shell stylesheet (login + session) |
| `Yaru-dark/gnome-shell-theme.gresource` | Compiled icons, assets |
| `*.svg` | Calendar, dash, workspace placeholders |

## Modify

1. Edit CSS/SVG here as reference
2. Copy changed files to system:  
   `sudo cp … /usr/share/gnome-shell/theme/Yaru-dark/`
3. Restart GDM: `sudo systemctl restart gdm`

Or use `bin/apply-dark-mode` to select `prefer-dark` without hand-editing CSS.

After `apt upgrade` to `yaru-theme-gnome-shell`, refresh mirror: `bin/themes-extract`.