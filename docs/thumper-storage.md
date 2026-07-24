# Thumper storage layout & reconstruction

**Host:** `thumper.local` (Dell Precision **T5610**, `user@10.0.0.30`)  
**Full hardware inventory (2026-07-23 clean install):** **`docs/thumper-inventory.md`**  
**This file:** ZFS/GPT geometry for reconstruction (includes **historical** 2026-07-19 incident + Qubes prep, and notes where the clean install differs).

Related: `docs/thumper-gpu.md` (NVIDIA), `docs/B1GMB42-zfs-recovery.md` (Tower5810 — different layout).

### Current OS layout (2026-07-23) — short form

Ubuntu **26.04 ZFS** on Hynix only:

| Part | Size | Role |
|------|------|------|
| sdb1 | 1 GiB | EFI → `/boot/efi` |
| sdb2 | 2 GiB | **bpool** |
| sdb3 | **8 GiB** | swap (not 24 GiB) |
| sdb4 | 227 GiB | **rpool** BE `ubuntu_0hwdet` |

Extra disks: WD2003FYYS = `user-data-pool` (import `-f` when needed); WD2002FAEX = ext4 **TVLAND1**.  
**rpool GUID (new):** `12865178900285581935` · **bpool GUID:** `6524546316270643389`  
Sections below still document the **pre-reinstall** damaged layout for archaeology.

---

## 1. Disk inventory (hardware IDs)

Prefer **by-id** names; kernel `sdX` letters move when USB is present.

| Role | Model | Serial / ID | Size | Current OS name (2026-07-19 live) |
|------|--------|-------------|------|-----------------------------------|
| **Root ZFS (`rpool`)** | SK hynix **SH920** 2.5″ 7 mm 256 GB | `EI49N15181060A75D` | 256 060 514 304 B (238.47 GiB, **500 118 192** × 512 B sectors) | `sdb` |
| **Data ZFS (`user-data-pool`)** | WDC **WD2003FYYS-02W0B0** | `WD-WMAY03713513` / WWN `0x50014ee0ad9a796b` | 2 000 398 934 016 B (1.82 TiB) | `sda` |
| **Live recovery USB** | PNY USB 2.0 FD | `AEA12H15YE08001755` | ~30 GiB | `sdc` |

```bash
ls -l /dev/disk/by-id/ata-SK_hynix_SH920* /dev/disk/by-id/ata-WDC_WD2003FYYS*
# Canonical:
#   ata-SK_hynix_SH920_2.5_7MM_256GB_EI49N15181060A75D
#   ata-WDC_WD2003FYYS-02W0B0_WD-WMAY03713513
#   ata-WDC_WD2003FYYS-02W0B0_WD-WMAY03713513-part1
```

**Not present at capture:** separate TEAM SSD (hot-removed earlier — do not assume it was part of these pools; `rpool` label shows **one** disk vdev only).

---

## 2. Pool summary

| Pool | GUID | Vdev | Health (capture) | Mount (intended) |
|------|------|------|------------------|------------------|
| **`rpool`** | `11348733854413672722` | single partition on Hynix SSD | **UNAVAIL** — GPT wiped; labels 0–1 destroyed; 2–3 bad cksum | root BE (Ubuntu ZFS install) |
| **`user-data-pool`** | `4307344409994064876` | single partition on WD 2 TB | **DEGRADED** (old scrub: 408+ errors; permanent errors on some files) | historically `/home/user/Data`; recovery used `/mnt/user-data` |

**Hostid** recorded on `rpool` labels: `1532761246` (hostname `thumper`).  
**Encryption:** neither pool reported encryption active on datasets seen.

Import always needs **`-f`** after live/recovery boots (foreign hostid).

---

## 3. `user-data-pool` (WD 2 TB) — complete geometry

### 3.1 Partition table (GPT)

| Part | Start | End | Sectors | Size | Type / notes |
|------|-------|-----|---------|------|----------------|
| **sda1** | 2048 | 3907012607 | 3907010560 | ~1.82 TiB | ZFS pool member — **`user-data-pool`** |
| **sda9** | 3907012608 | 3907028991 | 16384 | 8 MiB | Solaris reserved (ZFS whole-disk style spacer) |

- **PARTUUID sda1:** `e74ca4e9-bd1c-eb43-96af-852e63684481`  
- **PARTLABEL sda1:** `zfs-fdbbc8d2a7cdd36d`  
- **PARTTYPE:** ZFS (`6a898cc3-1dd2-11b2-99a6-080020736631`)  
- **blkid:** `LABEL="user-data-pool" UUID="4307344409994064876" TYPE="zfs_member"`

Disk GPT identifier (capture): `1D7E1594-CDBF-4243-98B5-B576548634DC`.

### 3.2 Pool / dataset

| Property | Value |
|----------|--------|
| Topology | 1× disk (partition) |
| `size` | 1.81 T |
| `ashift` (pool get) | 0 / default (legacy pool; physical 512 B) |
| Root dataset | `user-data-pool` only (no child datasets listed) |
| `mountpoint` | `/home/user/Data` (local); recovery temporarily `/mnt/user-data` |
| `compression` | on (lz4 feature active) |
| `xattr` | sa |
| Creation | Sun Dec 25 04:58 2022 |

```bash
sudo zpool import -f -d /dev/disk/by-id user-data-pool
# or by name if path is already correct:
sudo zpool import -f user-data-pool
sudo zfs set mountpoint=/mnt/user-data user-data-pool   # recovery
# restore for normal boots on installed OS:
# sudo zfs set mountpoint=/home/user/Data user-data-pool
```

**Known permanent errors (scrub 2026-06-29):** at least  
`/home/user/Data/Downloads/octopi-1.0.0-1.9.0-20230523082504.img`  
(and 400+ other checksum issues historically). Pool mounts; treat as **degraded archive**, not pristine.

### 3.3 Reconstruct GPT (if wiped)

```bash
DISK=/dev/disk/by-id/ata-WDC_WD2003FYYS-02W0B0_WD-WMAY03713513
sudo sgdisk --zap-all "$DISK"   # only if table is gone and you accept risk
sudo sgdisk \
  -n 1:2048:3907012607 -t 1:BF01 -c 1:'zfs-fdbbc8d2a7cdd36d' \
  -n 9:3907012608:3907028991 -t 9:BF07 \
  "$DISK"
# Then import with -f. Do NOT mkfs or zpool create if labels still exist.
```

If ZFS labels still present, prefer **recovery of existing GPT** (`gdisk` → `r` recovery / backup) over zap.

---

## 4. `rpool` (Hynix 256 GB SSD) — geometry for reconstruction

### 4.1 Observed state (2026-07-19)

| Item | Value |
|------|--------|
| Kernel view | **Whole disk** `sdb` reports `TYPE=zfs_member` / `LABEL=rpool` — **no GPT** (`gdisk`: MBR/GPT not present) |
| Sector 0 | **Zeroed** (labels 0–1 fail: “failed to unpack label”) |
| End labels | Labels **2** and **3** present, **Bad label cksum**, still parseable |
| Import | `UNAVAIL` / `invalid label` / `insufficient replicas` |

**Do not** `zpool create` or wipe the disk until label recovery is exhausted.

### 4.2 ZFS label facts (from `zdb -l` on damaged labels)

| Field | Value |
|-------|--------|
| `name` | `rpool` |
| `pool_guid` | `11348733854413672722` |
| `vdev guid` (top / leaf) | `2363609906384940571` |
| `txg` (last seen) | `55928361` |
| `version` | 5000 |
| `hostid` | `1532761246` |
| `hostname` | `thumper` |
| `vdev_children` | **1** (single device; no mirror/special) |
| `type` | `disk` |
| `whole_disk` | **0** → was a **partition**, not whole-disk vdev |
| `path` (original) | `/dev/disk/by-partuuid/bdc14abd-d3b2-0541-9480-f4c16dbb729c` |
| `ashift` | **12** (4 KiB) |
| `asize` | **251 222 818 816** bytes (**490 669 568** sectors) |
| `metaslab_shift` | 31 |
| `create_txg` | 4 |
| features_for_read | `com.delphix:hole_birth`, `com.delphix:embedded_data` |

### 4.3 Inferred historical GPT (Ubuntu ZFS root style)

Disk size − `asize` ≈ **4 613.6 MiB** free before rpool. That matches a classic Ubuntu ZFS **root** layout with head partitions:

| Component | Size (MiB) | Notes |
|-----------|------------|--------|
| Alignment / BIOS boot | ~1 | often 1 MiB GRUB BIOS boot (EF02) on some installs |
| **ESP (EFI System)** | **512** | FAT32, `/boot/efi` |
| **`bpool`** | **2048** | ZFS boot pool (`bpool`), kernels/initrds |
| **swap** | **2048** | optional but fits the ~4.6 GiB delta exactly with 512+2048+2048 |
| **`rpool`** | rest of disk | ~234 GiB usable (`asize` matches within ~5 MiB) |

**Best-fit reconstruction (sector 512 B):**

```text
Disk sectors:           500118192
Usable end (GPT):       500118158   # last usable typical
Head (approx):          9447424 sectors  (~4.5 GiB)  → EFI + bpool + swap + gaps
rpool asize sectors:    490669568
```

**Candidate partition map to recreate (verify with `zdb -l` on the rpool partition after create):**

| # | Role | Type code | Start (sector) | Size / end | Notes |
|---|------|-----------|----------------|------------|--------|
| 1 | BIOS boot | EF02 | 2048 | 2048 sectors (1 MiB) | omit on pure UEFI-only if original lacked it |
| 2 | ESP | EF00 | 4096 | 512 MiB | FAT32, boot/efi |
| 3 | bpool | BF01 | after ESP | 2 GiB | ZFS `bpool` |
| 4 | swap | 8200 | after bpool | 2 GiB | optional |
| 5 | **rpool** | BF01 | after swap | to last usable | **must** expose PARTUUID if possible |

**Original rpool PARTUUID (critical):**

```text
bdc14abd-d3b2-0541-9480-f4c16dbb729c
```

ZFS open path used this. After rebuilding GPT, either:

1. Set that PARTUUID with `sgdisk -u` / `gdisk` expert, **or**
2. `zpool import -d /dev/disk/by-id` and let ZFS find by guid, **or**
3. `zpool import -d /dev` with the correct partition node, then `zpool set` / export-import once healthy.

### 4.4 Procedure sketch: restore GPT + import `rpool`

```bash
HYNIX=/dev/disk/by-id/ata-SK_hynix_SH920_2.5_7MM_256GB_EI49N15181060A75D

# 1) Confirm labels still at end of disk
sudo zdb -l "$HYNIX" | head -80

# 2) Rebuild GPT (adjust starts if zdb on candidate partition fails)
# Example aligned layout (512B sectors) — VERIFY before writing:
#   p1 EF02  2048-4095
#   p2 EF00  4096-1054719     # 512 MiB ESP
#   p3 BF01  1054720-5249023  # 2 GiB bpool
#   p4 8200  5249024-9443327  # 2 GiB swap
#   p5 BF01  9443328-500118158 # rpool
#
# Use gdisk/sgdisk interactively and compare rpool partition size ≈ asize + labels (~1–4 MiB).

# 3) Point PARTUUID of rpool partition if required
# sudo sgdisk -u 5:bdc14abd-d3b2-0541-9480-f4c16dbb729c "$HYNIX"
# partprobe; udevadm settle

# 4) Dry-run / repair import
sudo zpool import -f -F -n -d /dev/disk/by-id rpool
sudo zpool import -f -F -d /dev/disk/by-id rpool
# last resorts (data risk): -X / -FX  — only after backup of user-data-pool

# 5) Mount for chroot (typical Ubuntu BE names — discover after import)
sudo zpool import -f -R /recovery rpool
sudo zfs list -r rpool
# Then mount bpool if recovered, EFI, and:
#   mount --bind /dev /recovery/dev; ... chroot; grub-install; update-grub; update-initramfs
```

### 4.5 If only end labels remain

Labels 0–1 at **start of the rpool vdev** are required for normal import. They lived at the **start of the rpool partition**, not necessarily LBA 0 of the disk. After GPT rebuild:

```bash
# Probe candidate start offsets (bytes) for a readable label 0:
for mb in 0 1 512 1024 2048 2560 3072 4096 4608 5120; do
  off=$((mb*1024*1024))
  sudo losetup -P -o "$off" --sizelimit 251222818816 /dev/loop20 "$HYNIX" 2>/dev/null || continue
  echo "=== offset ${mb}MiB ==="
  sudo zdb -l /dev/loop20 2>&1 | head -8
  sudo losetup -d /dev/loop20
done
```

When `zdb -l` shows **LABEL 0** without “failed to unpack”, recreate the partition with that **exact start** and matching size.

### 4.6 Bootloader repair (after `rpool` + ESP + `bpool` mount)

Typical Ubuntu ZFS EFI path (names may differ — list BE first):

```bash
# Discover boot environment
sudo zfs list -r rpool/ROOT
# Example:
# sudo mount -t zfs rpool/ROOT/<BE> /recovery
# sudo zpool import -f -N bpool   # if separate
# sudo mount -t zfs bpool/BOOT/<BE> /recovery/boot
# sudo mount /dev/disk/by-partuuid/<ESP> /recovery/boot/efi

for i in /dev /proc /sys /run; do sudo mount --rbind "$i" /recovery$i; done
sudo chroot /recovery /bin/bash -l
# inside:
apt-get update
apt-get install --reinstall -y grub-efi-amd64-signed shim-signed zfs-initramfs
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu --recheck
update-initramfs -c -k all
update-grub
# ensure /etc/default/zfs has:  ZPOOL_IMPORT_OPTS="-f"
exit
```

**EFI NVRAM (capture boot order was USB-first):** after repair, set disk boot to Hynix ESP, not only BBS “USB”.

```bash
sudo efibootmgr -v
# BootCurrent was often the PNY USB during recovery.
```

---

## 5. Live recovery USB (PNY Ventoy) — geometry

| Part | Size | Label | Contents |
|------|------|-------|----------|
| 1 | ~29.9 GiB | `Ventoy` | `ubuntu-26.04-desktop-amd64.iso`, `persistence/ubuntu-26.04.dat` (3 GiB casper-rw), `QubesOS/`, `IndianaDell-manuals/`, `ventoy/ventoy.json` |
| 2 | 32 MiB | `VTOYEFI` | Ventoy EFI |

**Wiggly backup of lean persistence:**  
`/mnt/wiggly/persistence/usb-ubuntu-persistance.dat` (on Tower Uncle Wiggly, next to 24 GiB `ubuntu-26.04.dat`).

Details: Software Manual Ch. 15.

---

## 6. Quick recovery checklist

```bash
# A. Data pool first (usually safe)
sudo zpool import -f user-data-pool
sudo zfs get mountpoint user-data-pool
sudo zfs mount user-data-pool

# B. Root SSD — reconstruct GPT using §4, then
sudo zpool import -f -F -d /dev/disk/by-id rpool   # escalate to -X only if needed

# C. Mount BE + bpool + ESP; chroot; grub-install + update-initramfs + update-grub

# D. Reboot without USB; confirm efibootmgr points at ubuntu on Hynix ESP
```

---

## 7. Commands to re-capture geometry (after any change)

```bash
ssh user@thumper.local 'bash -s' <<'EOF'
lsblk -b -o NAME,SIZE,TYPE,FSTYPE,LABEL,UUID,PARTUUID,PARTTYPE,PARTLABEL,MODEL,SERIAL
ls -l /dev/disk/by-id/
sudo zpool status -P
sudo zpool get all
sudo zfs list -o name,used,avail,refer,mountpoint,canmount
sudo zdb -l /dev/disk/by-id/ata-SK_hynix_SH920_2.5_7MM_256GB_EI49N15181060A75D
sudo zdb -l /dev/disk/by-id/ata-WDC_WD2003FYYS-02W0B0_WD-WMAY03713513-part1
sudo sgdisk -p /dev/disk/by-id/ata-SK_hynix_SH920_2.5_7MM_256GB_EI49N15181060A75D
sudo sgdisk -p /dev/disk/by-id/ata-WDC_WD2003FYYS-02W0B0_WD-WMAY03713513
sudo efibootmgr -v
EOF
```

Paste output back into this file when the layout is healthy again.

---

## 8. Contrast: Tower5810 (do not mix with Thumper)

| | **Thumper** | **Tower5810** |
|--|-------------|----------------|
| Chassis | T5610 | T5810 |
| Root pool | `rpool` on Hynix 256 G partition | `rpool` on Hitachi + **TEAM special** |
| Boot pool | expected `bpool` on same SSD (missing GPT) | `bpool` on Hitachi `sdb2` |
| Data | `user-data-pool` on WD 2 TB | home on `rpool` USERDATA |
| Recovery doc | **this file** | `docs/B1GMB42-zfs-recovery.md` |

---

*Incident note: 2026-07-19 — after TEAM SSD removal + power loss, Thumper would not find bootloaders; Hynix GPT gone; `rpool` unimportable until partition table + labels restored. `user-data-pool` importable with `-f`.*

---

## 9. Qubes OS prep (Hynix SSD) — applied 2026-07-19

**Destroyed:** unrecovered Ubuntu `rpool` on Hynix (ZFS labels wiped start+end).  
**Untouched:** WD `user-data-pool` (`sda`).

### 9.1 New GPT on Hynix (`ata-SK_hynix_SH920_2.5_7MM_256GB_EI49N15181060A75D`)

| # | Role | Size | Type | PARTLABEL | Format |
|---|------|------|------|-----------|--------|
| 1 | ESP | **1 GiB** | EF00 | EFI System | FAT32 `LABEL=EFI` |
| 2 | **swap** | **24.0 GiB** | 8200 | Linux swap | `mkswap` `LABEL=swap` |
| 3 | Qubes / LVM | **213.5 GiB** (rest) | 8E00 | Qubes LVM | **empty** (no PV yet) |

**Disk GUID (after prep):** `14BF8DF9-6AFF-4620-A7B1-72D5995DE8C7`  
**Sectors (512 B):** p1 `2048–2099199`; p2 `2099200–52430847`; p3 `52430848–500118158`

| Part | UUID (capture) |
|------|----------------|
| p1 EFI | FAT `393D-D5CA` / PARTUUID `1c0c86b4-896e-461c-b385-65efa4dcd1c7` |
| p2 swap | `b7372d89-25fe-4493-b6cc-2c6ea7e75e20` / PARTUUID `aa6fba50-cbc4-4484-95ce-b5f26ef25adf` |
| p3 LVM | PARTUUID `d47002b8-458b-4b13-9df5-a8dac00ecdb0` |

```bash
# Verify on live session
lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL /dev/disk/by-id/ata-SK_hynix_SH920*
swapon --show   # may show 24G /dev/sdb2 if enabled during prep
```

### 9.2 Qubes installer notes

- Prefer **custom partitioning**: use **p3** for Qubes (LVM thin pool / root); **keep p1 as ESP** if the installer allows reuse; **keep p2 as 24 GiB swap** (do not let “use whole disk” wipe p2).
- If the installer only offers “entire disk”, it **will destroy** this layout — re-run prep or create swap inside LVM instead.
- **Do not** install Qubes onto the WD 2 TB (`user-data-pool`).

### 9.4 user-data-pool expansion (2026-07-23) — TVLAND1 retired

| Step | Detail |
|------|--------|
| Removed | ext4 **TVLAND1** on FAEX; fstab entry deleted |
| Data vdevs | FYYS (existing, **DEGRADED** history) **+** FAEX `…-part1` (new, ONLINE) → ~**3.1 T free** / ~3.6 T class capacity |
| **Special** (small files + metadata) | `rpool/user-data-special` **64 GiB zvol** on Hynix SSD → `zpool add … special /dev/zvol/rpool/user-data-special` |
| `special_small_blocks` | **32K** on `user-data-pool` |
| Mount | `/media/user/Data` |
| Compression | `lz4` |

**Import order:** `rpool` (OS) must be up first so the special zvol exists, then `user-data-pool`.

```bash
# After reboot, if not auto-imported:
sudo zpool import -f user-data-pool
# special path should reattach via cache; if not:
# sudo zpool online user-data-pool zvol/rpool/user-data-special
```

**Caveats:** striped HDDs (not mirrored); nested special lives on OS pool (rpool free space); old permanent errors on FYYS remain until files deleted/restored.

### 9.3 Re-create this layout from scratch

```bash
HYNIX=/dev/disk/by-id/ata-SK_hynix_SH920_2.5_7MM_256GB_EI49N15181060A75D
sudo wipefs -a "$HYNIX"
sudo sgdisk --zap-all "$HYNIX"
sudo dd if=/dev/zero of="$HYNIX" bs=1M count=100 conv=fsync
sudo dd if=/dev/zero of="$HYNIX" bs=1M seek=$(($(cat /sys/block/$(basename $(readlink -f $HYNIX))/size)*512/1024/1024 - 100)) count=100 conv=fsync
sudo sgdisk --clear \
  -n 1:2048:+1G -t 1:EF00 -c 1:"EFI System" \
  -n 2:0:+24G   -t 2:8200 -c 2:"Linux swap" \
  -n 3:0:0      -t 3:8E00 -c 3:"Qubes LVM" \
  "$HYNIX"
sudo partprobe "$HYNIX"
sudo mkfs.vfat -F32 -n EFI "${HYNIX}-part1"
sudo mkswap -L swap "${HYNIX}-part2"
```
