# Chapter 15 — Ventoy Live Session & Persistence

Portable Ubuntu 26.04 on the **Wiggly** Ventoy stick, with a writable overlay so login state, apps, Grok, and IndianaDell survive reboots.

## What gets persisted

| Item | Location (live boot) | Seeded to casper image |
|------|----------------------|-------------------------|
| User home | `/home/ubuntu` | `cow/upper/home/ubuntu/` |
| Installed packages | dpkg overlay | `cow/upper/var/lib/dpkg/` |
| GDM autologin | `/etc/gdm3/custom.conf` | `cow/upper/etc/gdm3/` |
| Grok auth + sessions | `~/.grok/` | same (never in git) |
| GitHub CLI auth | `~/.config/gh/` | same |
| SSH keys | `~/.ssh/` | same |
| **Runtime source** | `/home/user/` when ZFS rpool is available | pulled at login via `resolve-secrets.sh` |
| IndianaDell workspace | `~/Documents/IndianaDell` | same (git clone or rsync) |
| PATH overrides | `~/.config/indianadell/path.sh` | same |

**Persistence image:** `/persistence/ubuntu-26.04.dat` (24 GB ext4, label `casper-rw`) on the internal Ventoy exFAT volume (**Wiggly**, `sdc1`).

**Ventoy config:** `ventoy/ventoy.json` maps `ubuntu-26.04-desktop-amd64.iso` → that `.dat` file with `autosel: 1`. Canonical copy in `scripts/ventoy/ventoy.json`.

## How it is installed

**One-time setup from Tower5810** (Wiggly mounted at `/mnt/wiggly`):

```bash
sudo mount -o uid=$(id -u),gid=$(id -g) /dev/disk/by-label/Wiggly /mnt/wiggly
bin/setup-wiggly-ventoy    # verify ISO, ventoy.json, .dat filesystem
```

Extend an undersized image: `sudo scripts/ventoy/ExtendPersistentImg.sh /mnt/wiggly/persistence/ubuntu-26.04.dat <MB>` then `resize2fs` on the loop device if needed.

**Seed session state** from a running session with Wiggly mounted (e.g. `/mnt/wiggly`):

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
`resolve-secrets.sh` materializes secrets from `/home/user` when rpool exists, else uses Ventoy `$HOME`.  
Runs `~/bin/seed-ventoy-persistence.sh` **before** Grok (logs to `~/.cache/seed-ventoy.log`).  
Seed verifies **internet + DNS** first; if down, offers NetworkManager bring-up or skip.
Default session: `~/Documents/IndianaDell` (session ID in script env vars).

## ZFS recovery (rpool + bpool)

**Manual:** `B1GMB42-zfs-recovery.pdf` (repo root and `DOSBOOT/IndianaDell/recovery/`).

Boot Ventoy Ubuntu live — **do not** use the broken installed system as root.

```bash
sudo apt-get install -y zfsutils-linux
cd ~/Documents/IndianaDell          # or /media/.../DOSBOOT1/IndianaDell/recovery
sudo ./mount-rpool-recovery.sh mount
sudo ./scripts/recovery/mount-bpool-recovery.sh mount
sudo ./mount-rpool-recovery.sh chroot
# repair inside chroot; then exit and umount both scripts
```

**No IndianaDell?** Same manual, Section 3 — raw `zpool import` commands.

Deploy kit to DOSBOOT: `bin/deploy-dosboot-recovery` (from Tower5810).

## GitHub repository

Full workspace (including FactoryDocs): https://github.com/webaugur/IndianaDell (private)

```bash
bin/pull-repo --verify           # IndianaDell + hackrf/repos + LFS + stack verify
bin/push-repo                    # push main (SSH default)
```

HTTPS push (optional): `INDIANADELL_REMOTE=https://github.com/webaugur/IndianaDell.git` after `gh auth login`.

Large FactoryDocs installers (>100 MB) use **Git LFS**. `bin/pull-repo` runs `git lfs pull`.

## How to verify

Boot Ventoy → Ubuntu 26.04 (persistence auto-selected). Then:

```bash
findmnt / | grep -q cow && echo "persistence overlay active"
grep AutomaticLogin=ubuntu /etc/gdm3/custom.conf
echo "$INDIANADELL_ROOT"    # should be ~/Documents/IndianaDell
which dellmerge pull-repo push-repo grok
bin/pull-repo --verify
google-chrome --version
```

## How to customize

| Goal | Action |
|------|--------|
| Re-seed after changes | `~/bin/seed-ventoy-persistence.sh` |
| Change Grok session | Edit `GROK_SESSION_ID` in `grok-indianadell-launch.sh` |
| Disable autostart | Remove `~/.config/autostart/grok-indianadell.desktop`, re-seed |
| Enlarge persistence | `scripts/ventoy/ExtendPersistentImg.sh` (+ `resize2fs` if needed) |
| Verify/fix Ventoy layout | `bin/setup-wiggly-ventoy` from Tower5810 |

## What rebuild does / does not do

| Does | Does not |
|------|----------|
| Install Chrome, gh, git-lfs when run on live session | Configure Ventoy `ventoy.json` |
| Document seed script in this chapter | Auto-run seed on reboot |
| | Manage Ventoy ISO partition layout |