# Mirror: yaru-theme-gtk

**Package:** `yaru-theme-gtk`  
**Role:** GTK2, GTK3, GTK4 widget themes + editor color schemes.

| Path under `usr/share/` | Purpose |
|-------------------------|---------|
| `themes/Yaru-dark/gtk-3.0/gtk.css` | Main GTK3 dark stylesheet |
| `themes/Yaru-dark/gtk-4.0/` | GTK4 libadwaita-compatible theme |
| `gtksourceview-*/styles/Yaru-dark.xml` | Text editor syntax colors |

## Modify

```bash
# Quick test (user override, no sudo):
mkdir -p ~/.themes/Yaru-dark/gtk-3.0
cp mirror/.../gtk.css ~/.themes/Yaru-dark/gtk-3.0/
gsettings set org.gnome.desktop.interface gtk-theme 'Yaru-dark'
```

System-wide: copy to `/usr/share/themes/Yaru-dark/` then re-login.