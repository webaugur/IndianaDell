# Chapter 7 — GNOME Session

## What gets installed

GNOME desktop preferences applied via gsettings (user session) and optionally GDM (login greeter). No apt packages beyond what Ubuntu desktop already provides (`gdm3`, `gnome-shell`, Yaru themes).

**Scripts:**

- `scripts/gnome/apply-dark-mode.sh` via `bin/apply-dark-mode`
- `scripts/gnome/apply-max-performance.sh` via `bin/apply-max-performance`
- `scripts/gnome/fix-nautilus-desktop-launch.sh` via `bin/fix-nautilus-desktop-launch`

## How it is installed

Run as the **logged-in desktop user**, not root:

```bash
bin/apply-dark-mode
bin/apply-max-performance
bin/fix-nautilus-desktop-launch   # Nautilus 50+ .desktop double-click launch
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

## Nautilus 50 — “Allow Launching” removed

**Change (GNOME Files / Nautilus 50, Ubuntu 26.04):** Nautilus no longer runs FreeDesktop `.desktop` files itself. The old “Allow Launching” / trusted-launcher path is gone (security). Double-click falls through to the default handler for MIME type `application/x-desktop`, which is often a text editor (`gedit` / `gnome-text-editor`). So double-clicking `SDRPlusPlus.desktop` (or any app launcher on disk) **edits** the file instead of **starting** the app.

**Fix:** register a small MIME handler that launches the entry via `gio launch`:

| Piece | Path |
|-------|------|
| Handler app | `~/.local/share/applications/xdg-desktop-launch.desktop` |
| Wrapper script | `~/.local/bin/xdg-desktop-launch` |
| MIME default | `application/x-desktop` → `xdg-desktop-launch.desktop` |

Double-click path after install: **Files → xdg-open → wrapper → `gio launch` → your app**.

```bash
bin/fix-nautilus-desktop-launch              # install / reinstall
bin/fix-nautilus-desktop-launch --status     # check MIME + files
bin/fix-nautilus-desktop-launch --uninstall  # remove handler
```

**Portable:** the script is self-contained. Copy `scripts/gnome/fix-nautilus-desktop-launch.sh` to any Ubuntu/GNOME box and run as the desktop user (no root, no IndianaDell tree required).

**CLI verify:**

```bash
xdg-mime query default application/x-desktop   # expect xdg-desktop-launch.desktop
xdg-open /path/to/App.desktop                  # should start the app
~/.local/bin/xdg-desktop-launch /path/to/App.desktop
```

## How to verify

```bash
gsettings get org.gnome.desktop.interface color-scheme
gsettings get org.gnome.desktop.interface gtk-theme
gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type
powerprofilesctl get
bin/fix-nautilus-desktop-launch --status
```

Log out and back in to confirm GDM greeter if dark mode was applied.

## How to customize

- Override themes: `GTK_THEME=Yaru-viridian bin/apply-dark-mode`
- Skip GDM: `APPLY_GDM=0 bin/apply-dark-mode`
- Revert individual keys with `gsettings reset …` or GNOME Settings app
- Login/desktop asset mirrors: `Themes/login/`, `Themes/desktop/`
- Remove .desktop launch fix: `bin/fix-nautilus-desktop-launch --uninstall`

## What rebuild does / does not do

| Does | Does not |
|------|----------|
| Install gdm3, gnome-shell, Yaru via apt | Change any gsettings |
| | Set performance power profile |
| | Install the Nautilus 50 .desktop MIME handler |

Run dark mode, max performance, and `fix-nautilus-desktop-launch` after every fresh install (Chapter 3).