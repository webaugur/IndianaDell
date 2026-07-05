# Mirror: yaru-theme-sound

**Package:** `yaru-theme-sound`  
**Role:** Ubuntu Yaru sound theme — login, logout, notifications.

| Path | Purpose |
|------|---------|
| `usr/share/sounds/Yaru/` | OGG event sounds |
| `usr/share/sounds/Yaru/stereo/` | Stereo variants |

## Modify

Replace `.ogg` files in mirror, copy to `/usr/share/sounds/Yaru/`, then:

```bash
gsettings set org.gnome.desktop.sound theme-name 'Yaru'
```

Custom name: create `MySounds/index.theme` referencing your directory.