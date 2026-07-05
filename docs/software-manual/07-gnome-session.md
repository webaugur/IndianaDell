# Chapter 7 — GNOME Session

## What gets installed

GNOME desktop preferences applied via gsettings (user session) and optionally GDM (login greeter). No apt packages beyond what Ubuntu desktop already provides (`gdm3`, `gnome-shell`, Yaru themes).

**Scripts:**

- `scripts/gnome/apply-dark-mode.sh` via `bin/apply-dark-mode`
- `scripts/gnome/apply-max-performance.sh` via `bin/apply-max-performance`

## How it is installed

Run as the **logged-in desktop user**, not root:

```bash
bin/apply-dark-mode
bin/apply-max-performance
```

### apply-dark-mode

Sets:

| Schema | Key | Value |
|--------|-----|-------|
| `org.gnome.desktop.interface` | `color-scheme` | `prefer-dark` |
| `org.gnome.desktop.interface` | `gtk-theme` | `Yaru-dark` (override: `GTK_THEME=`) |
| `org.gnome.desktop.interface` | `icon-theme` | `Yaru-dark` |
| `org.gnome.shell.ubuntu` | `color-scheme` | `prefer-dark` |
| `org.gnome.desktop.wm.preferences` | `theme` | `Yaru-dark` |
| `org.gnome.settings-daemon.plugins.color` | night-light | disabled |

With `APPLY_GDM=1` (default), also sets GDM greeter dark via `sudo dbus-run-session gsettings …`.

### apply-max-performance

Sets:

- Power plugin: no suspend on AC/battery, no idle dim, lid close does nothing
- Session idle delay: 0
- Screensaver: no blanking or lock on idle
- Night light: off
- `powerprofilesctl set performance` when available

## How to verify

```bash
gsettings get org.gnome.desktop.interface color-scheme
gsettings get org.gnome.desktop.interface gtk-theme
gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type
powerprofilesctl get
```

Log out and back in to confirm GDM greeter if dark mode was applied.

## How to customize

- Override themes: `GTK_THEME=Yaru-viridian bin/apply-dark-mode`
- Skip GDM: `APPLY_GDM=0 bin/apply-dark-mode`
- Revert individual keys with `gsettings reset …` or GNOME Settings app
- Login/desktop asset mirrors: `Themes/login/`, `Themes/desktop/`

## What rebuild does / does not do

| Does | Does not |
|------|----------|
| Install gdm3, gnome-shell, Yaru via apt | Change any gsettings |
| | Set performance power profile |

Run both launchers after every fresh install (Chapter 3).