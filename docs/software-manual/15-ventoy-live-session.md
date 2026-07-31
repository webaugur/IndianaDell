# Chapter 15 — Ventoy Live Session & Persistence

This chapter covers **two** Ventoy volumes used on the lab:

| Volume | Friendly name | Role | Typical size |
|--------|---------------|------|----------------|
| Internal Seagate ST500DM002 | **Uncle Wiggly** 🥕🐰 | Full rabbit hole: many ISOs, 24 GB Ubuntu persistence, DOSBOOT / Windows / ISO-STASH | ~466 GB disk |
| PNY USB 2.0 (~30 GB) | **Rebuild stick** | Lean Ubuntu 26.04 live + **3 GB** persistence for recovery / thumper rebuild | ~30 GB USB |

Both use Ventoy: drop ISOs onto the data partition; they appear in the boot menu. Writable **casper-rw** persistence keeps login state across live boots.

**EFI note (Tower5810):** Uncle Wiggly’s SATA port may be **disabled in Setup** for fast POST (`docs/fast-boot.md`). If `/dev/disk/by-label/Wiggly` is missing but the Seagate is cabled, re-enable that SATA port in **F2 Setup**, then reboot.

---

## Overlay layout (both volumes)

Ubuntu live + Ventoy persistence uses an ext4 file labeled **`casper-rw`**:

```text
persistence/ubuntu-26.04.dat   # ext4, LABEL=casper-rw
  upper/                       # modern overlay upper (preferred)
    home/<liveuser>/
    etc/
    usr/local/sbin/
    …
  work/                        # created by live system as needed
```

Older seeds may have used `cow/upper/`; current IndianaDell seeds use **`upper/`**. Seed scripts prefer `upper/` and remove a stale `cow/` tree when seeding.

**Ventoy config** (on the same data partition as the ISO):

```json
{
    "persistence": [
        {
            "image": "/ubuntu-26.04-desktop-amd64.iso",
            "backend": "/persistence/ubuntu-26.04.dat",
            "autosel": 1
        }
    ]
}
```

Canonical repo copy for Uncle Wiggly: `scripts/ventoy/ventoy.json`. Paths are **absolute from the Ventoy data partition root**. Persistence backend and ISO must live on the **same** Ventoy data partition.

### Subdirectories and non-ISO files

Ventoy **recursively scans** the data partition for bootable images (`.iso`, etc.). Subfolders are fine and already used on Wiggly:

| Path example | Notes |
|--------------|--------|
| `/perc/*.iso` | PERC FreeDOS/Linux kit; FreeDOS can use `auto_memdisk` in `ventoy.json` |
| `/Windows NT ISOs/*.iso` | Period OS media |
| `/QubesOS/Qubes-….iso` + `.asc` + signing key | Signatures sit next to the ISO; Ventoy ignores non-bootable files |

Optional: empty `.ventoyignore` in a folder hides that tree from the boot menu.

Create a persistence image (example 3 GiB):

```bash
# From extracted Ventoy release, or scripts/ventoy/ if present
sudo ./CreatePersistentImg.sh -s 3072 -t ext4 -l casper-rw -o persistence/ubuntu-26.04.dat
# Extend later:
sudo scripts/ventoy/ExtendPersistentImg.sh /path/to/ubuntu-26.04.dat <extra-MB>
# then resize2fs on the loop device if needed
```

---

## Uncle Wiggly 🥕🐰 (internal Ventoy)

**Names:** friendly **Uncle Wiggly**; partition label **`Wiggly`** (historically `sdc1`, mount `/mnt/wiggly`). Same Seagate also holds **DOSBOOT**, Windows, **ISO-STASH** — see hardware inventory.

### What gets persisted (full seed)

| Item | Live path | In casper image |
|------|-----------|-----------------|
| User home | `/home/ubuntu` (Wiggly full seed convention) | `upper/home/ubuntu/` |
| Installed packages | dpkg overlay | `upper/var/lib/dpkg/` |
| GDM autologin | `/etc/gdm3/custom.conf` | `upper/etc/gdm3/` |
| Grok auth + sessions | `~/.grok/` | same (**never in git**) |
| GitHub CLI auth | `~/.config/gh/` | same |
| SSH keys | `~/.ssh/` | same |
| Chrome (tier C) | `~/.config/google-chrome/` curated | bookmarks, prefs, logins, Web Data, Extensions — **no caches** |
| Runtime secret source | `/home/user/` when ZFS rpool is available | pulled via `resolve-secrets.sh` |
| IndianaDell workspace | `~/Documents/IndianaDell` | full tree (git clone or rsync) |
| PATH overrides | `~/.config/indianadell/path.sh` | same |

**Persistence image:** `/persistence/ubuntu-26.04.dat` (**24 GB** ext4, label `casper-rw`) on label **`Wiggly`**.

### One-time setup (Tower5810)

```bash
sudo mount -o uid=$(id -u),gid=$(id -g) /dev/disk/by-label/Wiggly /mnt/wiggly
bin/setup-wiggly-ventoy    # verify ISO, ventoy.json, .dat filesystem
```

### Seed session state

```bash
~/bin/seed-ventoy-persistence.sh
# or:
PERSIST_MOUNT=/mnt/persist-check ~/bin/seed-ventoy-persistence.sh
SEED_CHROME=c ~/bin/seed-ventoy-persistence.sh   # default chrome tier
SEED_CHROME=off ~/bin/seed-ventoy-persistence.sh
```

| Mode | When | Network? |
|------|------|----------|
| Live casper overlay | Already booted from Ventoy persistence | **No** — local rsync only |
| External `.dat` seed | Seeding from Tower5810 / mounted volume | Only if IndianaDell must be **git cloned** |

**Network check:** waits up to `SEED_NETWORK_WAIT_SECS` (default **120s**). Skip: `SEED_SKIP_NETWORK_CHECK=1`.

### Chrome profile seed (`SEED_CHROME`)

Default **`c`**. Prefer `/home/user/.config/google-chrome` when rpool home exists; never copies Cache / Code Cache / GPU* / Service Worker.

| Tier | What is copied |
|------|----------------|
| `off` / `0` | Nothing |
| `a` | Bookmarks + Preferences |
| `b` | a + Local State + Secure Preferences |
| **`c`** | b + Login Data + Web Data + Extensions + Local Extension Settings |
| `d` | Reserved (same as `c` for now) |

### Login experience (Wiggly full seed)

1. **GDM autologin** — live user **`ubuntu`** (Wiggly seed convention; see rebuild stick for **`user`**)
2. **PATH** — IndianaDell `bin/` and `scripts/` via `~/.config/indianadell/path.sh`
3. **Grok autostart** — often disabled (`X-GNOME-Autostart-enabled=false`)
4. **Installer** — no autostart; Desktop Install icon when needed

`resolve-secrets.sh` materializes secrets from `/home/user` when rpool exists, else Ventoy `$HOME`.

---

## PNY rebuild stick (lean USB)

**Device:** ~30 GB PNY USB (model often `USB 2.0 FD`). **Not** production storage — install/recovery only.

### Why repartition / reinstall Ventoy

The old layout was ~6 GB Ventoy + 32 MB VTOYEFI + ~24 GB DOSBOOT. Ubuntu 26.04 desktop ISO is **~6.1 GB**, so the small Ventoy slice could not hold ISO + persistence. Rebuild (2026-07) used Ventoy **1.1.16** force-install so almost the whole stick is one data partition:

| Partition | Size | Label | Role |
|-----------|------|-------|------|
| `…1` | ~29.9 G | `Ventoy` | ISO + persistence + `ventoy.json` |
| `…2` | 32 M | `VTOYEFI` | Ventoy EFI |

```bash
# SAFETY: confirm USB transport + ~30 GB before -I
lsblk -o NAME,SIZE,MODEL,TRAN,LABEL
# From extracted ventoy-*-linux:
sudo bash ./Ventoy2Disk.sh -I -L Ventoy /dev/sdX   # double-confirm y/y
```

Hiren’s / old Ubuntu 22 / DOSBOOT content on that stick was wiped by reinstall. BartPE and current media live on **Uncle Wiggly** (or ISO-STASH).

### Layout on the stick

```text
/ubuntu-26.04-desktop-amd64.iso          # ~6.1 G (copied from Wiggly)
/persistence/ubuntu-26.04.dat            # 3 G casper-rw
/ventoy/ventoy.json                      # persistence map, autosel=1
```

**Capacity rule of thumb:** 6.1 G ISO + 3 G `.dat` ≈ 9 G used; leave free space for future ISOs. A **24 GB** Wiggly-class overlay does **not** fit on this stick.

### Lean seed policy (rebuild stick)

**Include** (as live user home — see identity below):

| Item | Source (Tower5810) | Notes |
|------|--------------------|--------|
| SSH keys | `/home/user/.ssh/` | `id_rsa`, config, authorized_keys; mode 700/600 |
| GitHub CLI | `/home/user/.config/gh/` | `hosts.yml` token |
| Grok | `/home/user/.grok/` | auth + sessions; **prune `downloads/`** to save space |
| GnuPG | `/home/user/.gnupg/` | optional |
| gitconfig | `/home/user/.gitconfig` | |
| Cursor auth | `~/.config/cursor/auth.json` | if present |
| Shell dots | `.bashrc`, `.profile`, … | |
| IndianaDell config | `~/.config/indianadell`, autostart, dconf | |
| `~/bin` | host `~/bin` helpers | |
| Keyrings | `~/.local/share/keyrings` | |
| **Project PDFs only** | `Documents/IndianaDell/B1GMB42-*.pdf` | manuals / trifolds / ZFS recovery — **not** full Documents tree |

**Exclude:** full `Documents/`, `.cache`, Chrome bulk, cargo/rustup/wine/googleearth, full `.local` (except keyrings).

Seed path in the image: `upper/home/user/…` (after username change below).

Mount / edit / unmount pattern:

```bash
DAT=/run/media/$USER/Ventoy/persistence/ubuntu-26.04.dat   # or by-label Ventoy
MOUNT=/mnt/persist-usb
sudo mkdir -p "$MOUNT"
LOOP=$(sudo losetup --show -f "$DAT")
sudo mount "$LOOP" "$MOUNT"
# edit $MOUNT/upper/ ...
sync
sudo umount "$MOUNT"
sudo losetup -d "$LOOP"
```

### Live user identity: `user` (not `ubuntu`)

Casper creates the live account from **`/etc/casper.conf`**. **`FLAVOUR` must be non-empty** or casper ignores `USERNAME` / `HOST` and substitutes the flavour string.

Seeded on the rebuild stick:

```bash
# /etc/casper.conf  (in upper/)
export USERNAME="user"
export USERFULLNAME="User"
export HOST="thumper"
export BUILD_SYSTEM="Ubuntu"
export FLAVOUR="Ubuntu"    # required for USERNAME/HOST to stick
```

Also:

| File | Purpose |
|------|---------|
| `upper/etc/gdm3/custom.conf` | `AutomaticLoginEnable=true`, `AutomaticLogin=user` |
| `upper/etc/sudoers.d/casper` | `user ALL=(ALL) NOPASSWD: ALL` |
| `upper/home/user/` | Seeded secrets + lean home (uid/gid **1000**) |

Casper’s `15autologin` / `25adduser` / `44pk_allow_ubuntu` all use `$USERNAME`, so PolicyKit and autologin follow `casper.conf` when FLAVOUR is set.

### Boot unit: groups + rename safety net

**Script:** `upper/usr/local/sbin/indianadell-live-user.sh`  
**Unit:** `indianadell-live-user.service` (WantedBy `multi-user.target` and `graphical.target`)  
**Log:** `/var/log/indianadell-live-user.log`

Behavior:

1. If account **`ubuntu`** exists and **`user`** does not → `groupmod`/`usermod` rename + move home (old overlays / missed FLAVOUR).
2. Add **`user`** to every **special group that exists** on the live system (skip missing groups quietly).
3. Refresh sudoers + GDM autologin for `user`.
4. Set hostname **`thumper`** and `127.0.1.1 thumper.local thumper` in `/etc/hosts`.

**Group list** (lab / rebuild relevant — install packages later may create more groups; reboot re-runs attach):

| Category | Groups |
|----------|--------|
| Admin / desktop | `adm`, `cdrom`, `sudo`, `dip`, `plugdev`, `lpadmin`, `sambashare`, `users` |
| Serial / radio | `dialout`, `tty`, `uucp` |
| AV / GPU / input | `audio`, `video`, `render`, `input` |
| Print / scan | `lp`, `scanner` |
| Network | `netdev`, `bluetooth` |
| Containers / VMs | `docker`, `lxd`, `kvm`, `libvirt`, `libvirt-qemu` |
| Other | `disk`, `floppy`, `ssl-cert`, `wireshark`, `fuse` |

Matches the intent of Tower5810’s host user groups (`id user`) plus hardware-facing groups we may install on live.

### Fast-boot deferments (Tower5810 parity + live snap kill)

Same idea as `bin/apply-fast-boot` / `docs/fast-boot.md`, adapted for **casper overlay** (cannot run `systemctl disable` on the ISO lower layer — use **mask symlinks**).

| Mechanism | Path in overlay | Role |
|-----------|-----------------|------|
| Boot masks | `etc/systemd/system/<unit> → /dev/null` | Unit cannot start early (present as soon as root mounts) |
| Permanent mask list | `etc/indianadell-live-mask.list` | Never auto-start (snap seed, NM-wait-online, …) |
| Deferred list | `etc/indianadell-deferred.list` | Unmasked + `start --no-block` **after** `graphical.target` |
| Socket-lazy list | `etc/indianadell-socket-lazy.list` | `docker` / `cups` / `snapd` / `libvirt` sockets only |
| Early assert | `indianadell-live-fastboot.service` → `usr/local/sbin/indianadell-live-fastboot.sh` | Re-mask/stop thrashers; log `/var/log/indianadell-live-fastboot.log` |
| Post-desktop start | `indianadell-deferred.service` → `usr/local/sbin/indianadell-start-deferred` | After GDM; does **not** block desktop |

**Permanent masks (rebuild stick — the usual multi-minute hang):**

- `snapd.seeded.service` (main culprit on Ubuntu live)
- `snapd.autoimport.service`, `snapd.core-fixup.service`, `snapd.recovery-chooser-trigger.service`, …
- `NetworkManager-wait-online.service`

**Deferred (masked at boot, started later in background):** `snapd.service`, cloud-init*, cups*, bluetooth, avahi, ModemManager, docker/libvirt stack, apport/whoopsie, unattended-upgrades, etc. (full list on the stick).

`snapd.service` itself is only started after the desktop is up (and only if you unmask/start it); **seeded** stays masked so it never blocks login.

Verify on live:

```bash
systemctl is-enabled snapd.seeded.service   # expect: masked
systemctl is-active snapd.seeded.service    # inactive
systemd-analyze blame | head -20
sudo tail /var/log/indianadell-live-fastboot.log
```

### Plymouth theme (`indianadell`)

Tower’s custom theme is seeded into the overlay (~20 MB):

| Item | Overlay path |
|------|----------------|
| Theme tree | `usr/share/plymouth/themes/indianadell/` (from host `/usr/share/plymouth/themes/indianadell`) |
| Default alternative | `etc/alternatives/default.plymouth` → `…/indianadell.plymouth` |
| Default symlink | `usr/share/plymouth/themes/default.plymouth` → alternatives |
| Daemon config | `etc/plymouth/plymouthd.conf` → `Theme=indianadell` |

`indianadell-live-fastboot.sh` re-asserts the default theme once rootfs is up.

**Caveat:** The **very first** splash frames still come from the **ISO initrd** (stock spinner/BGRT). After casper mounts the persistence overlay, Plymouth uses `Theme=indianadell` for late boot / shutdown / any restart of plymouthd. Fully replacing early ISO splash would require rebuilding `casper/initrd` on the ISO (not done on this stick).

Install source on Tower: `sudo bin/themes-install-boot` (see Ch. 5). Stick seed copies the **installed** theme tree, not a separate rebuild of animation frames.

### Hostname `thumper` / `thumper.local` and OpenSSH on LAN

**Hostname:** `casper.conf` `HOST=thumper` plus `/etc/hostname` and `/etc/hosts` (`thumper.local`). Cloud-init can be steered with `upper/etc/cloud/cloud.cfg.d/99-thumper-hostname.cfg` if present.

**SSH unit (optional seed):** `thumper-lan-ssh.service` → `upper/usr/local/sbin/thumper-lan-ssh.sh`

- Waits for network if needed; installs **`openssh-server`** (apt, or debs under `/var/cache/thumper-debs/` if cached).
- Drop-in `/etc/ssh/sshd_config.d/99-thumper-lan.conf`: listen `0.0.0.0` / `::`, pubkey + password auth, no root login, no empty passwords.
- Enables/starts `ssh.service` (disables socket-only activation if needed).
- Allows UFW OpenSSH if UFW is active; starts `avahi-daemon` when available for mDNS **`thumper.local`**.
- Log: `/var/log/thumper-lan-ssh.log`

**Login:**

```bash
ssh user@thumper.local
# or LAN IP from the live session
```

Use the same SSH private key as Tower5810 (`id_rsa`); public key is in `~/.ssh/authorized_keys` on the stick. Live password is typically blank at the console (casper); SSH should use **keys** (empty passwords disabled for SSH).

MOTD hint (if seeded): `etc/update-motd.d/99-thumper-ssh`.

---

## Secrets policy (`resolve-secrets.sh`)

Canonical secret relative paths (never commit to git):

```text
.ssh
.grok
.config/gh
```

When ZFS rpool `/home/user` is present, it is the live secret **source**; Ventoy persistence is the portable **store** under the live home. Chrome seed is separate (`SEED_CHROME`).

---

## ZFS recovery (rpool + bpool)

**Manual:** `docs/B1GMB42-zfs-recovery.md` + `B1GMB42-zfs-recovery.pdf` (repo root and DOSBOOT recovery kit).

Boot Ventoy Ubuntu live — **do not** use a broken installed system as root.

```bash
sudo apt-get install -y zfsutils-linux
cd ~/Documents/IndianaDell          # or recovery kit path
sudo ./mount-rpool-recovery.sh mount
sudo ./scripts/recovery/mount-bpool-recovery.sh mount
sudo ./mount-rpool-recovery.sh chroot
# repair; then exit and umount both scripts
```

**Before rebooting installed OS:** `/etc/default/zfs` must set `ZPOOL_IMPORT_OPTS="-f"`. Kernel one-shot: `zfsforce=1`.

Deploy kit: `bin/deploy-dosboot-recovery` (from Tower5810). PDF on the rebuild stick: `~/Documents/IndianaDell/B1GMB42-zfs-recovery.pdf`.

---

## GitHub repository

https://github.com/webaugur/IndianaDell (private)

```bash
bin/pull-repo --verify
bin/pull-repo --dragonsdr
bin/push-repo
```

HTTPS optional: `INDIANADELL_REMOTE=…` after `gh auth login`. Large FactoryDocs use **Git LFS**.

On the rebuild stick, after network is up: `git clone git@github.com:webaugur/IndianaDell.git` using seeded SSH keys.

---

## How to verify

### Uncle Wiggly (full)

```bash
findmnt / | grep -qE 'cow|overlay' && echo "persistence overlay active"
grep AutomaticLogin= /etc/gdm3/custom.conf
echo "$INDIANADELL_ROOT"
which dellmerge pull-repo push-repo grok
bin/pull-repo --verify
```

### PNY rebuild stick

```bash
# Identity
whoami                    # expect: user
id                        # expect sudo,adm,plugdev,dialout,… as available
hostname; hostname -f     # thumper / thumper.local
grep AutomaticLogin=user /etc/gdm3/custom.conf

# Persistence
findmnt / | grep -qE 'cow|overlay' && echo "overlay ok"
test -f ~/.ssh/id_rsa && test -f ~/.config/gh/hosts.yml && test -f ~/.grok/auth.json && echo "secrets ok"
ls ~/Documents/IndianaDell/*.pdf

# SSH on LAN (after thumper-lan-ssh has run)
ss -tlnp | grep ':22'
systemctl is-active ssh
# from another host:
#   ssh user@thumper.local

# Fast-boot / snapd not thrashing
systemctl is-enabled snapd.seeded.service   # masked
systemd-analyze blame | head -15

# Plymouth (rootfs theme)
grep Theme= /etc/plymouth/plymouthd.conf    # indianadell
readlink -f /etc/alternatives/default.plymouth

# Logs
sudo tail -50 /var/log/indianadell-live-user.log
sudo tail -50 /var/log/thumper-lan-ssh.log
sudo tail -50 /var/log/indianadell-live-fastboot.log
```

---

## How to customize

| Goal | Action |
|------|--------|
| Re-seed Wiggly full session | `~/bin/seed-ventoy-persistence.sh` |
| Change Grok session | Edit `GROK_SESSION_ID` in `grok-indianadell-launch.sh` |
| Enlarge persistence | `ExtendPersistentImg.sh` + `resize2fs` |
| Verify Wiggly layout | `bin/setup-wiggly-ventoy` |
| Edit rebuild stick overlay | loop-mount `ubuntu-26.04.dat`, edit `upper/`, unmount |
| Live user name | `upper/etc/casper.conf` (`USERNAME` + **`FLAVOUR`**) + GDM + home dir + `indianadell-live-user.sh` |
| Extra groups | Edit `SPECIAL_GROUPS` in `indianadell-live-user.sh` |
| SSH / hostname | `thumper-lan-ssh.sh` + sshd drop-in + hosts/hostname |
| Boot defer / mask lists | `etc/indianadell-deferred.list`, `etc/indianadell-live-mask.list` |
| Refresh Plymouth on stick | rsync host `/usr/share/plymouth/themes/indianadell/` into overlay; keep `plymouthd.conf` |
| Hide ISO folder from menu | `.ventoyignore` in that folder |
| Qubes + signatures | e.g. `Wiggly/QubesOS/*.iso` + `.asc` + key (subdirs OK) |

---

## Related tools

| Tool | Role |
|------|------|
| `bin/setup-wiggly-ventoy` | Verify Wiggly ISO + `ventoy.json` + `.dat` |
| `bin/boot-uncle-wiggly-vm` | QEMU live + persistence smoke test |
| `bin/boxes-import-wiggly-isos` | GNOME Boxes domain per ISO on Wiggly |
| `bin/setup-perc-ventoy` | PERC FreeDOS/IT kit on Wiggly (`perc/`) |
| `~/bin/seed-ventoy-persistence.sh` | Full seed into casper image |
| `scripts/ventoy/resolve-secrets.sh` | Secret path policy + Chrome tiers |
| `scripts/ventoy/ventoy.json` | Canonical Wiggly Ventoy plugin config |
| Ventoy release `CreatePersistentImg.sh` | Build empty `casper-rw` `.dat` |

---

## What rebuild does / does not do

| Does | Does not |
|------|----------|
| Install Chrome, gh, git-lfs when run on a full live session | Auto-configure Ventoy `ventoy.json` |
| Document seed / stick layout in this chapter | Auto-run seed every boot (except stick units: groups/SSH) |
| | Manage Seagate partition map (Wiggly/DOSBOOT/Windows) |
| | Fit a 24 GB Wiggly `.dat` on the 30 GB PNY stick |
