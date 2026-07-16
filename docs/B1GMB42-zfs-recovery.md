---
title: "B1GMB42 ZFS Recovery"
header-includes:
  - \setlength{\parskip}{0.4em}
---

# B1GMB42 ZFS Recovery — rpool and bpool from live media

**Machine:** Dell Precision T5810 (Tower5810)  
**Installed pools:** `rpool` (root + `/home`) on Hitachi `sdb4` + TEAM `sda` special vdev; `bpool` (`/boot`) on Hitachi `sdb2`  
**Boot environment:** `rpool/ROOT/ubuntu_cortt9`, `bpool/BOOT/ubuntu_cortt9`  
**Encryption:** off (no ZFS passphrase on these pools)

Use this when the installed Ubuntu system will not boot. Boot **Ventoy Ubuntu 26.04** from **Uncle Wiggly** 🥕🐰 (`sdc1`, label `Wiggly`) instead — do not import `rpool` until you are ready to repair.

### Required host setting: force import

On the **installed** system, `/etc/default/zfs` must include:

```bash
ZPOOL_IMPORT_OPTS="-f"
```

Without this, boot can fail or hang after a recovery `zpool export`, hostid mismatch, or unclean shutdown — initramfs import will not force-import the pools. Recovery scripts already pass `-f` on the command line; the installed OS does **not** unless this default is set.

```bash
# verify on Tower5810 (or inside chroot after mount)
grep '^ZPOOL_IMPORT_OPTS' /etc/default/zfs
# expect: ZPOOL_IMPORT_OPTS="-f"
```

One-shot alternative: add `zfsforce=1` on the GRUB/kernel command line for a single boot.

---

## 1. Choose your path

| Situation | What to use |
|-----------|-------------|
| Ventoy live, IndianaDell or DOSBOOT scripts available | **Section 2** (recommended) |
| Ventoy live, no scripts — only a shell | **Section 3** (manual `zpool`) |
| Installed system still boots but you need a read-only view | `mount-rpool-recovery.sh mount --overlay` |

**DOSBOOT copy:** `IndianaDell/recovery/` on partition **DOSBOOT** (`sdc3`, vfat).  
**Repo copy:** `~/Documents/IndianaDell/mount-rpool-recovery.sh` and `scripts/recovery/`.

---

## 2. With IndianaDell / DOSBOOT scripts

### Prerequisites (live session)

```bash
sudo apt-get update
sudo apt-get install -y zfsutils-linux
```

### Mount rpool for chroot (default)

```bash
cd /path/to/recovery/scripts    # DOSBOOT/IndianaDell/recovery or IndianaDell repo root
sudo bash mount-rpool-recovery.sh mount      # use bash on DOSBOOT (vfat)
sudo bash mount-bpool-recovery.sh mount      # puts /boot at /recovery/boot
sudo bash mount-rpool-recovery.sh status
```

You should see `/recovery/bin`, `/recovery/home`, `/recovery/etc`, and `/recovery/boot` (kernel + initrd).

### Enter chroot and repair

```bash
sudo ./mount-rpool-recovery.sh chroot
# inside chroot:
mount | grep boot
zpool status
apt-get update
apt-get install -y --reinstall zfs-initramfs grub-efi-amd64-signed shim-signed
update-initramfs -c -k all
update-grub
exit
```

### Tear down

```bash
sudo ./mount-bpool-recovery.sh umount
sudo ./mount-rpool-recovery.sh umount
```

### Overlay fallback (running system already on rpool)

Only when a full live-media chroot is impossible:

```bash
sudo ./mount-rpool-recovery.sh mount --overlay
ls /recovery/home/user
sudo ./mount-rpool-recovery.sh umount
```

---

## 3. Without scripts (manual commands)

Run as **root** from Ventoy Ubuntu live. Replace dataset names if yours differ (`zpool import` / `zfs list` to discover).

### 3a. Import and mount rpool

```bash
sudo mkdir -p /recovery
sudo zpool import -N -f -R /recovery -d /dev/disk/by-id rpool
sudo zfs mount -a -R /recovery
sudo zfs list -r rpool | head -20
```

Boot environment should appear under `/recovery` (e.g. `/recovery/home/user`).

### 3b. Import and mount bpool at /recovery/boot

```bash
sudo zpool import -N -f -d /dev/disk/by-id bpool
BOOT_DS=$(zfs list -H -o name,mountpoint -r bpool/BOOT | awk '$2=="/boot"{print $1; exit}')
sudo zfs set mountpoint=/recovery/boot "$BOOT_DS"
sudo zfs mount "$BOOT_DS"
ls /recovery/boot
```

### 3c. Chroot

```bash
for d in dev proc sys run; do sudo mount --bind /$d /recovery/$d; done
sudo mount --bind /dev/pts /recovery/dev/pts
sudo chroot /recovery /bin/bash
```

Inside chroot: run repairs (Section 4), then `exit`.

### 3d. Unmount and export

```bash
sudo zfs umount -a -R /recovery
sudo zpool set altroot=- rpool
sudo zpool export rpool
sudo zfs umount "$BOOT_DS"
sudo zpool export bpool
```

---

## 4. Common repairs (inside chroot)

| Problem | Commands |
|---------|----------|
| Broken initramfs / boot | `update-initramfs -c -k all` && `update-grub` |
| Boot hangs on ZFS import after recovery | Ensure `/etc/default/zfs` has `ZPOOL_IMPORT_OPTS="-f"`; rebuild initramfs if needed |
| Pool won't import (live) | `zpool import -f -d /dev/disk/by-id` (inspect candidates); check `dmesg` |
| Pool degraded | `zpool status -v`; replace faulted vdev per ZFS docs |
| PERC H710 fault | SAS bays unavailable — see hardware manual; pool on SATA only |
| Boot menu missing | `apt-get install --reinstall grub-efi-amd64-signed shim-signed` |
| ZFS mount fails | `zfs mount -a`; check `zfs list -o name,mountpoint,canmount` |

**Before leaving chroot**, confirm force import is set:

```bash
grep '^ZPOOL_IMPORT_OPTS' /etc/default/zfs
# must show: ZPOOL_IMPORT_OPTS="-f"
# if missing or empty:
#   printf 'ZPOOL_IMPORT_OPTS="-f"\n' | tee -a /etc/default/zfs   # or edit in place
# then: update-initramfs -c -k all
```

**Do not** re-enable ZFS encryption until TPM + recovery are documented (hardware manual).

---

## 5. Disk map (this machine)

| Device | Pool / role |
|--------|-------------|
| `sdb4` | `rpool` main vdev |
| `sda` | `rpool` special vdev (TEAM SSD) |
| `sdb2` | `bpool` |
| `sdb1` | EFI (`/boot/efi` when running) |
| `sdb3` | Plain **4 GiB** swap (HDD) |
| `rpool/swap` | **33 GiB** swap zvol (prefers special/SSD; fstab `pri=10,nofail`) |
| `sdc1` Uncle Wiggly 🥕🐰 (`Wiggly`) | Ventoy rabbit hole + Ubuntu live ISO + persistence |
| `sdc3` DOSBOOT | Recovery scripts + this manual |

**Before `zpool export rpool`:** disable the zvol swap so export is clean:

```bash
sudo swapoff /dev/zvol/rpool/swap 2>/dev/null || sudo swapoff -a
# HDD swap sdb3 can stay or also swapoff -a
```

---

## 6. Script reference

| Script | Purpose |
|--------|---------|
| `mount-rpool-recovery.sh` | Import `rpool` at `/recovery`, chroot, overlay, umount |
| `mount-bpool-recovery.sh` | Import `bpool`, mount boot FS at `/recovery/boot` |

Environment overrides: `POOL_NAME`, `BPOOL_NAME`, `RECOVERY_ROOT`.

---

## 7. Verify after repair

Reboot to installed disk (not Ventoy). Then:

```bash
grep '^ZPOOL_IMPORT_OPTS' /etc/default/zfs    # must be "-f"
zpool status rpool bpool
zfs list -r rpool | head -15
ls /boot/grub
```

If boot fails again, repeat from Section 2 or 3. If import stalls at boot, boot Ventoy, set `ZPOOL_IMPORT_OPTS="-f"` in the chroot (Section 4), update-initramfs, and retry.

---

*IndianaDell ZFS recovery. Tower5810 / B1GMB42. Last updated: 2026-07-10.*