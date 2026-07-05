# Chapter 11 — Flatpak Applications

## What gets installed

| App | Flatpak ID | Version (this host) |
|-----|------------|---------------------|
| Telegram | `org.telegram.desktop` | 6.9.3 |

**Runtime dependency:** `flatpak` package from `APT_CORE`.

## How it is installed

Rebuild Phase 4:

```bash
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub org.telegram.desktop
```

Skip with `SKIP_TELEGRAM=1 bin/rebuild-machine`.

## How to verify

```bash
flatpak list --app | grep telegram
flatpak run org.telegram.desktop --version 2>/dev/null || true
bin/rebuild-machine --verify-only
```

## How to customize

```bash
flatpak update org.telegram.desktop
flatpak override --user org.telegram.desktop …   # permissions, env
```

`bin/apply-dark-mode` sets `prefer-dark` color scheme; Flatpak GTK4 apps pick this up via portal when supported.

## What rebuild does / does not do

| Does | Does not |
|------|----------|
| Install `flatpak` via apt | Install SDRangel, SigDigger (not on Flathub) |
| Add flathub remote + Telegram | Pin Telegram to a specific commit |
| Treat Telegram miss as non-fatal on install (warns in log) | Install other Flatpak apps by default |