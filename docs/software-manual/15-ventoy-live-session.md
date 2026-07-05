# Chapter 15 — Ventoy Live Session & Persistence

Portable Ubuntu 26.04 on the **Wiggly** Ventoy stick, with a writable overlay so login state, apps, Grok, and IndianaDell survive reboots.

## What gets persisted

| Item | Location (live boot) | Seeded to casper image |
|------|----------------------|-------------------------|
| User home | `/home/ubuntu` | `cow/upper/home/ubuntu/` |
| Installed packages | dpkg overlay | `cow/upper/var/lib/dpkg/` |
| GDM autologin | `/etc/gdm3/custom.conf` | `cow/upper/etc/gdm3/` |
| Grok auth + sessions | `~/.grok/` | same |
| GitHub CLI auth | `~/.config/gh/` | same |
| SSH keys | `~/.ssh/` | same |
| IndianaDell workspace | `~/Documents/IndianaDell` | same (git clone or rsync) |
| PATH overrides | `~/.config/indianadell/path.sh` | same |

**Persistence image:** `/persistence/ubuntu-26.04.dat` (14 GB ext4, label `casper-rw`) on the Ventoy exFAT volume (**Wiggly**).

**Ventoy config:** `ventoy/ventoy.json` maps `ubuntu-26.04-desktop-amd64.iso` → that `.dat` file with `autosel: 1`.

## How it is installed

From a running session with the stick mounted (e.g. `/mnt/wiggly`):

```bash
# One-time or after changes — seeds current ubuntu session into the .dat image
~/bin/seed-ventoy-persistence.sh
# or, if the image is already mounted:
PERSIST_MOUNT=/mnt/persist-check ~/bin/seed-ventoy-persistence.sh
```

The seed script copies home, dpkg/apt state, GDM autologin, SSH keys (including `/home/user/.ssh/id_rsa` when present), and the IndianaDell tree.

## Login experience (configured)

1. **GDM autologin** — user `ubuntu` (`/etc/gdm3/custom.conf`)
2. **PATH** — IndianaDell `bin/` and `scripts/` override system (`~/.config/indianadell/path.sh`)
3. **Grok autostart** — Ptyxis fullscreen, resumes IndianaDell session (`~/.config/autostart/grok-indianadell.desktop`)

Launcher: `~/bin/grok-indianadell-launch.sh`  
Default session: `~/Documents/IndianaDell` (session ID in script env vars).

## ZFS recovery (installed rpool)

When booted from Ventoy **without** importing `rpool`, use the workspace recovery script:

```bash
cd ~/Documents/IndianaDell
sudo ./mount-rpool-recovery.sh mount      # chroot layout under /recovery
sudo ./mount-rpool-recovery.sh chroot
sudo ./mount-rpool-recovery.sh umount
```

Use `mount --overlay` only when already booted from `rpool` and a full chroot tree is impossible.

## GitHub repository

Full workspace (including FactoryDocs): https://github.com/webaugur/IndianaDell (private)

```bash
gh auth login          # once per session
bin/push-repo          # full git push (HTTPS via gh)
```

Large FactoryDocs installers (>100 MB) use **Git LFS**. Run `git lfs install` after clone.

## How to verify

Boot Ventoy → Ubuntu 26.04 (persistence auto-selected). Then:

```bash
findmnt / | grep -q cow && echo "persistence overlay active"
grep AutomaticLogin=ubuntu /etc/gdm3/custom.conf
echo "$INDIANADELL_ROOT"    # should be ~/Documents/IndianaDell
which dellmerge push-repo grok
gh auth status
google-chrome --version
```

## How to customize

| Goal | Action |
|------|--------|
| Re-seed after changes | `~/bin/seed-ventoy-persistence.sh` |
| Change Grok session | Edit `GROK_SESSION_ID` in `grok-indianadell-launch.sh` |
| Disable autostart | Remove `~/.config/autostart/grok-indianadell.desktop`, re-seed |
| Enlarge persistence | Recreate `.dat` (Ventoy plugin or `dd` + `mkfs.ext4`) |

## What rebuild does / does not do

| Does | Does not |
|------|----------|
| Install Chrome, gh, git-lfs when run on live session | Configure Ventoy `ventoy.json` |
| Document seed script in this chapter | Auto-run seed on reboot |
| | Manage Ventoy ISO partition layout |