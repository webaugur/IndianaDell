# Chapter 7 — GNOME Session

## What gets installed

GNOME desktop preferences applied via gsettings (user session) and optionally GDM (login greeter). No apt packages beyond what Ubuntu desktop already provides (`gdm3`, `gnome-shell`, Yaru themes).

**Scripts:**

- `scripts/gnome/apply-dark-mode.sh` via `bin/apply-dark-mode`
- `scripts/gnome/apply-max-performance.sh` via `bin/apply-max-performance`
- `scripts/gnome/fix-nautilus-desktop-launch.sh` via `bin/fix-nautilus-desktop-launch`
- `scripts/gnome/sync-desktop-icons.sh` via `bin/sync-desktop-icons`

## How it is installed

Run as the **logged-in desktop user**, not root:

```bash
bin/apply-dark-mode
bin/apply-max-performance
bin/fix-nautilus-desktop-launch   # Nautilus 50+ .desktop double-click launch
bin/sync-desktop-icons             # Nautilus 50+ show Icon= as file icon
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

## Nautilus 50 — generic `.desktop` icons

**Change:** even after launch works, Nautilus 50+ still shows the generic `application-x-desktop` MIME icon in the file view. It **ignores** the FreeDesktop `Icon=` field on the `.desktop` file for the list/icon view. Icons in the GNOME Shell app grid (from XDG application menus) are a different path and usually look correct; this problem is about **Files** showing launcher files as plain documents.

**Fix:** set GIO metadata that Nautilus still honors:

| Attribute | When used | Example |
|-----------|-----------|---------|
| `metadata::custom-icon` | `Icon=` is an absolute or relative file path | `file:///home/user/Applications/sdrpp.png` |
| `metadata::custom-icon-name` | `Icon=` is a theme icon name | `utilities-terminal` |

The script reads the first `Icon=` under `[Desktop Entry]` only (not `Icon[lang]=`, not other groups), then:

1. Absolute path (`/…`) → `metadata::custom-icon` with a `file://` URI; clear `custom-icon-name`
2. Relative path (`foo/bar.png`) → resolve relative to the `.desktop` file’s directory; same as absolute
3. Theme name (no `/`) → `metadata::custom-icon-name`; clear `custom-icon`
4. Missing icon file → warning and skip (does not fail the whole run)

### Usage

```bash
bin/sync-desktop-icons                 # scan default directories
bin/sync-desktop-icons -v              # log each set / skip / rename
bin/sync-desktop-icons --dry-run       # print actions, no gio set / rename
bin/sync-desktop-icons --file PATH     # one .desktop (inotify-friendly)
bin/sync-desktop-icons --dir DIR       # add/replace scan dir (repeatable)
bin/sync-desktop-icons --watch         # inotify loop (needs inotify-tools)
bin/sync-desktop-icons --clear-missing # unset custom-icon* if Icon= absent
bin/sync-desktop-icons --no-rename     # keep chrome-*-Default.desktop names
```

**Default scan directories** (when `--dir` is not used and `SYNC_DESKTOP_ICON_DIRS` is unset):

- `$HOME/.local/share/applications`
- `$HOME/Applications`
- `$HOME/Desktop`

Only **top-level** `*.desktop` files in each directory are processed (flat XDG apps layout and a personal `Applications` / Desktop folder). Nested trees are not walked.

### Rename Chrome gibberish basenames

Chrome/Chromium PWAs create launchers like `chrome-lodlkdfmihgonocnmddehnfgiljnadcf-Default.desktop` while `Name=` is a short human label (`X`, `YouTube`). **By default** (`--rename`), if the file **and** its directory are **writable**, matching basenames are renamed to `${Name}.desktop` before icon metadata is applied.

| Rule | Behavior |
|------|----------|
| Pattern | `chrome-<id>-Default.desktop`, `chrome-<id>.desktop` (id ≥ 16 alnum); same for `chromium-` |
| Source of new name | First `Name=` under `[Desktop Entry]` only (not action groups, not `Name[lang]=`) |
| Not writable | Skip rename, warn, still try icon metadata |
| Target already exists | Skip rename, warn (no overwrite) |
| Disable | `--no-rename` |

Example: `~/Desktop/chrome-lodlk…-Default.desktop` (`Name=X`) → `~/Desktop/X.desktop`.

**Environment:**

| Variable | Effect |
|----------|--------|
| `SYNC_DESKTOP_ICON_DIRS` | Colon-separated directory list (overrides defaults when set) |

**Dependencies:** `gio` (`libglib2.0-bin`, already on Ubuntu desktop). `--watch` also needs `inotifywait` (`inotify-tools`).

**Portable / PATH install:** `bin/sync-desktop-icons` resolves its own path with `readlink -f`, so a symlink from `~/.local/bin/sync-desktop-icons` into the repo still finds `scripts/gnome/`. The script itself needs only `gio`; copy `scripts/gnome/sync-desktop-icons.sh` alone if you want it off-tree.

**Companion:** run **after** `bin/fix-nautilus-desktop-launch` so double-click starts the app **and** the file view shows the right icon. Neither script replaces the other.

**CLI verify:**

```bash
bin/sync-desktop-icons -v
# pick a launcher you care about:
gio info -a metadata::custom-icon -a metadata::custom-icon-name \
  "$HOME/Applications/SomeApp.desktop"
# open Files on that folder — icon should match Icon=
```

**Watch mode example** (re-apply when a launcher is saved or dropped into a scan dir):

```bash
bin/sync-desktop-icons --watch -v
# or a single-file handler:
inotifywait -m -e close_write,moved_to,create --include '\.desktop$' \
  "$HOME/Applications" | while read -r dir _ file; do
    bin/sync-desktop-icons --file "$dir$file"
  done
```

## How to verify

```bash
gsettings get org.gnome.desktop.interface color-scheme
gsettings get org.gnome.desktop.interface gtk-theme
gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type
powerprofilesctl get
bin/fix-nautilus-desktop-launch --status
bin/sync-desktop-icons -v
```

Log out and back in to confirm GDM greeter if dark mode was applied. Refresh or reopen the Files window after `sync-desktop-icons` if icons do not update immediately.

## How to customize

- Override themes: `GTK_THEME=Yaru-viridian bin/apply-dark-mode`
- Skip GDM: `APPLY_GDM=0 bin/apply-dark-mode`
- Revert individual keys with `gsettings reset …` or GNOME Settings app
- Login/desktop asset mirrors: `Themes/login/`, `Themes/desktop/`
- Remove .desktop launch fix: `bin/fix-nautilus-desktop-launch --uninstall`
- Extra icon scan dirs: `SYNC_DESKTOP_ICON_DIRS="$HOME/Apps:$HOME/Desktop" bin/sync-desktop-icons`
- Clear stale custom icons when `Icon=` is gone: `bin/sync-desktop-icons --clear-missing`
- Unset metadata on one file:  
  `gio set -t unset PATH metadata::custom-icon`  
  `gio set -t unset PATH metadata::custom-icon-name`

## What rebuild does / does not do

| Does | Does not |
|------|----------|
| Install gdm3, gnome-shell, Yaru via apt | Change any gsettings |
| | Set performance power profile |
| | Install the Nautilus 50 .desktop MIME handler |
| | Run `sync-desktop-icons` or set custom-icon metadata |

Run dark mode, max performance, `fix-nautilus-desktop-launch`, and `sync-desktop-icons` after every fresh install (Chapter 3).
