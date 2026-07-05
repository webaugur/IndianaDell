# Mirror: gdm3

**Package:** `gdm3`  
**Role:** GNOME Display Manager — owns the login greeter process.

Notable mirrored paths:

- `usr/share/gdm/gdm.schemas` — GDM configuration schema
- `usr/share/dconf/profile/gdm` — dconf profile for greeter user
- `usr/share/glib-2.0/schemas/` — GSettings overrides

## Modify

GDM look is mostly driven by GNOME Shell + Yaru theme, not standalone GDM PNGs.

Config tweaks (auto-login, Wayland): `/etc/gdm3/custom.conf` (see `~/Documents/IndianaDell/etc/gdm3/custom.conf` in IndianaDell workspace).

Greeter dark mode: `bin/apply-dark-mode` (GDM gsettings).