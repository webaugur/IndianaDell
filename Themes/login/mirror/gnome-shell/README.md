# Mirror: gnome-shell

**Package:** `gnome-shell`  
**Role:** GNOME Shell core — login dialog, panel, overview (including on GDM greeter).

Notable paths:

- `usr/share/gnome-shell/gnome-shell-theme.gresource` — default shell resources
- `usr/share/gnome-shell/extensions/` — bundled extensions (Ubuntu Dock, etc.)
- `usr/share/gnome-shell/GShell-Schemas.gschema.xml`

Login screen uses the same shell codebase as the user session; Yaru overrides live in `yaru-theme-gnome-shell/`.