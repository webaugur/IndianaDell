# Thumper hardware inventory

**Host:** `thumper.local` / `Thumper` · `user@10.0.0.30`  
**Captured:** 2026-07-23 (clean **Ubuntu 26.04 LTS** ZFS install)  
**Chassis:** Dell Precision **T5610** (service tag **8SNZK02**)  
**Board:** Dell **0WN7Y6** A02 · BIOS **A16** (2018-02-05) · UEFI  
**Related:** `docs/thumper-storage.md` (ZFS/GPT reconstruction), `docs/thumper-gpu.md` (NVIDIA policy)

---

## System summary

| Item | Value |
|------|--------|
| OS | Ubuntu **26.04** LTS (`resolute`), kernel **7.0.0-28-generic** |
| Install style | Ubuntu ZFS root (`rpool` + `bpool`) |
| Boot environment | `rpool/ROOT/ubuntu_0hwdet`, `bpool/BOOT/ubuntu_0hwdet` |
| Hostname | `Thumper` (mDNS/DNS: `thumper.local`) |
| User | `user` (uid 1000), passwordless sudo verified |
| Firmware | UEFI (efivarfs present) |
| Primary boot | Ubuntu on Hynix ESP (`Boot0001* Ubuntu`); BootCurrent often UEFI Hynix |

---

## CPU

| | |
|--|--|
| Model | **2×** Intel **Xeon E5-2603 v2** @ 1.80 GHz (Ivy Bridge-EP, family 6 model 62) |
| Topology | 2 sockets × 4 cores × 1 thread = **8 CPUs** |
| Caches | L1d/i 256 KiB×8 · L2 2 MiB×8 · L3 **20 MiB×2** |
| NUMA | **2** nodes (CPUs 0–3 / 4–7) |
| Virt | **VT-x** |
| Freq | 1200–1800 MHz |

---

## Memory

| | |
|--|--|
| Total | **32 GiB** (OS reports ~30 GiB usable) |
| ECC | **Multi-bit ECC** |
| Configured speed | **1333 MT/s** (mixed DIMMs) |

| Locator | Size | Type | Rated | Vendor | Part |
|---------|------|------|-------|--------|------|
| DIMM1_CPU1 | 4 GB | DDR3 | 1866 | Micron | 9JSF51272PZ-1G9E2 |
| DIMM2_CPU1 | 4 GB | DDR3 | 1866 | Micron | 9JSF51272PZ-1G9E2 |
| DIMM3_CPU1 | 4 GB | DDR3 | 1866 | Micron | 9JSF51272PZ-1G9E2 |
| DIMM4_CPU1 | 4 GB | DDR3 | 1866 | Micron | 9JSF51272PZ-1G9E2 |
| DIMM1_CPU2 | 4 GB | DDR3 | 1333 | Hynix | HMT351R7BFR8A-H9 |
| DIMM2_CPU2 | 4 GB | DDR3 | 1333 | Hynix | HMT351R7BFR8A-H9 |
| DIMM3_CPU2 | 4 GB | DDR3 | 1333 | Hynix | HMT351R7BFR8A-H9 |
| DIMM4_CPU2 | 4 GB | DDR3 | 1333 | Hynix | HMT351R7BFR8A-H9 |

**Swap (OS):** **8 GiB** on `/dev/sdb3` (not the earlier 24 GiB Qubes prep — reinstall used Ubuntu defaults).

---

## GPUs / display (post-swap)

| PCI | Device | Driver | Role |
|-----|--------|--------|------|
| **01:00.0** | AMD/ATI **Cedar** Radeon HD 6350 (Dell) `[1002:68f9]` | **`radeon`** | Display (Wayland session) |
| **02:00.0** | NVIDIA **TITAN Xp** GP102 `[10de:1b02]` 12 GiB | **`nvidia`** | Compute / CUDA |
| **02:00.1** | NVIDIA GP102 HDMI audio | snd_hda | |

```text
nvidia-smi: driver 580.173.02, power limit 250 W, UUID GPU-41d7b760-4778-638c-082e-d5610e6387c7
/dev/dri: card1 + card2, renderD128 + renderD129
```

**Notes**

- Dual-GPU: light AMD for desktop, TITAN Xp for CUDA (prefer `CUDA_VISIBLE_DEVICES=0` on the NVIDIA index).
- Only **one** TITAN Xp present (no second NVIDIA card in this capture).
- Older dual-TITAN thermal policy still in `docs/thumper-gpu.md` if a second card returns.

---

## Storage

Prefer **by-id** names. Letters: `sda` = old data ZFS · `sdb` = OS SSD · `sdc` = new/large bulk HDD.

### Disk table

| by-id (ata-…) | Size | Media | Role (2026-07-23) |
|---------------|------|-------|-------------------|
| `SK_hynix_SH920_2.5_7MM_256GB_EI49N15181060A75D` | 238.5 GiB SSD | SATA | **OS:** EFI + bpool + swap + rpool |
| `WDC_WD2003FYYS-02W0B0_WD-WMAY03713513` | 1.82 TiB HDD | SATA | **`user-data-pool`** ZFS (legacy lab data; not auto-imported at boot in this install) |
| `WDC_WD2002FAEX-007BA0_WD-WMAY03219154` | 1.82 TiB HDD | SATA | **ext4 `TVLAND1`** (~4 TB class pair with FYYS) |
| USB multi-reader | 0 B slots | USB | CF / SM / SD / MS (empty) |
| `HL-DT-ST_DVD+_-RW_GTA0N_KW3DCP23636` | optical | SATA | DVD±RW |

**~4 TB bulk storage** = two ~2 TB WD HDDs (FYYS + FAEX), not a single 4 TB spindle.

### Hynix OS SSD partition map (Ubuntu 26.04 ZFS)

| Part | Start | End | Size | Type | Content |
|------|-------|-----|------|------|---------|
| sdb1 | 2048 | 2203647 | **1.0 GiB** | EF00 | EFI vfat `A27D-449F` → `/boot/efi` |
| sdb2 | 2203648 | 6397951 | **2.0 GiB** | 8300 | **bpool** UUID `6524546316270643389` ashift **12** |
| sdb3 | 6397952 | 23175167 | **8.0 GiB** | 8200 | **swap** UUID `074b0f04-b9f8-4cc0-8685-86182b32e12d` |
| sdb4 | 23175168 | 500115455 | **227.4 GiB** | 8300 | **rpool** UUID `12865178900285581935` ashift **12** |

Disk GPT GUID: `2ABA5D4C-7CC1-439B-B709-40E1DD8A3D59`  
ESP PARTUUID (efibootmgr): `baa971d5-a883-4798-b340-6088863d8e38`

| Pool | GUID | Size | Health |
|------|------|------|--------|
| bpool | 6524546316270643389 | 1.88 G | ONLINE |
| rpool | 12865178900285581935 | 226 G | ONLINE (~7 G used fresh install) |

### WD2003FYYS (user-data-pool) — unchanged geometry

| Part | Start–End | Size | Type | Label |
|------|-----------|------|------|-------|
| sda1 | 2048–3907012607 | 1.8 TiB | BF01 | `user-data-pool` |
| sda9 | 3907012608–3907028991 | 8 MiB | BF07 | Solaris reserved |

- Pool GUID: **`4307344409994064876`**  
- PARTUUID sda1: `e74ca4e9-bd1c-eb43-96af-852e63684481`  
- Historically **DEGRADED** with permanent checksum errors (see prior scrub).  
- **Not imported** on this clean OS until explicitly:  
  `sudo zpool import -f user-data-pool`

### WD2002FAEX (was TVLAND1 → now in `user-data-pool`)

| Part | Size | Role (2026-07-23) |
|------|------|-------------------|
| sdc1 | 1.8 TiB | **ZFS data vdev** for `user-data-pool` (striped with FYYS) |

- ext4 **TVLAND1** removed; mount was `/media/user/TVLAND1`.  
- Pool also has **special** vdev: `rpool/user-data-special` (64 G zvol on Hynix) with `special_small_blocks=32K`.  
- Mount: **`/media/user/Data`**. See `thumper-storage.md` §9.4.

---

## Network

| Interface | State | MAC | Driver | Notes |
|-----------|-------|-----|--------|--------|
| **enp0s25** | UP | `f8:b1:56:cc:79:14` | e1000e | Intel **82579LM** onboard; **10.0.0.30/24** + IPv6 |
| **wlxb8a38607bb15** | DOWN | `b8:a3:86:07:bb:15` | rtl8192cu | D-Link **DWA-121** USB Wi‑Fi |

---

## Other I/O

| Item | Detail |
|------|--------|
| Chipset SATA | Intel C600/X79 6-port AHCI (`00:1f.2`) |
| USB 3 | Renesas uPD720201 (`05:00.0`) + onboard EHCI hubs |
| Audio | Intel HDA X79 + NVIDIA HDMI |
| Keyboard | Fujitsu USB HID |
| Card reader | Realtek RTS5182 |

---

## EFI boot entries (snapshot)

| Boot | Description |
|------|-------------|
| Boot0001* | **Ubuntu** → `\EFI\ubuntu\shimx64.efi` on Hynix ESP |
| Boot0000* | leftover **Qubes OS** entry (VenHw) — safe to delete when unused |
| Boot000A/B | Hynix BBS / UEFI |
| Boot000C | WD2002FAEX BBS |
| Boot000D | WD2003FYYS BBS |

```bash
# Optional cleanup
sudo efibootmgr -b 0000 -B   # remove stale Qubes entry if desired
```

---

## Re-capture commands

```bash
ssh user@thumper.local 'bash -s' <<'EOF'
sudo dmidecode -t system -t baseboard -t bios | head -40
lscpu | head -25
free -h
sudo dmidecode -t memory | grep -E "Size:|Locator:|Speed:|Part Number:" | head -40
lspci -nn | grep -iE "VGA|3D|Ethernet"
nvidia-smi -L 2>/dev/null
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT,MODEL,SERIAL,TRAN
ls -l /dev/disk/by-id/ata-*
sudo zpool status -P
zfs list
sudo sgdisk -p /dev/disk/by-id/ata-SK_hynix_SH920_2.5_7MM_256GB_EI49N15181060A75D
sudo sgdisk -p /dev/disk/by-id/ata-WDC_WD2003FYYS-02W0B0_WD-WMAY03713513
sudo sgdisk -p /dev/disk/by-id/ata-WDC_WD2002FAEX-007BA0_WD-WMAY03219154
ip -br a
sudo efibootmgr -v | head -25
EOF
```

---

## Change log

| Date | Change |
|------|--------|
| 2026-07-23 | Fresh Ubuntu 26.04 ZFS inventory; dual GPU AMD 6350 + TITAN Xp; +WD2002FAEX 2 TB `TVLAND1`; swap 8 G on OS SSD |
| 2026-07-19 | Prior recovery era: damaged rpool/GPT, Qubes prep 24 G swap (superseded by reinstall) — see `thumper-storage.md` |
