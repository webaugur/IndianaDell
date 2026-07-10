# B1GMB42 — PERC H710 IT-mode flash via internal Ventoy (Wiggly)

Flash the **PERC H710** (Slot5) to **LSI IT firmware** so each drive is presented individually for **ZFS** (`mpt2sas`), not MegaRAID.

**Ventoy host:** internal **Wiggly** partition on the Seagate (`sdc1`, label `Wiggly`, SATA).  
**Not** the USB Ventoy stick (`sdd`, `USB 2.0 FD`).

## Deploy kit (from Ubuntu on Tower5810)

```bash
cd ~/Documents/IndianaDell
bin/setup-perc-ventoy
```

This downloads the [Fohdeesha PERC crossflash v2.6](https://fohdeesha.com/docs/perc.html) bundle (if needed), **patches the FreeDOS ISO** with all IndianaDell `.md` manuals (plain `.TXT` + **QBASDOWN** markdown→HTML), copies ISOs to **Wiggly** only, and updates `ventoy/ventoy.json` (`auto_memdisk` for FreeDOS).

## What you need to do (checklist)

1. **On Ubuntu:** `bin/setup-perc-ventoy` (already done if ISOs are on Wiggly).
2. **BIOS F2:** Boot Mode → **BIOS** for flash; disable VT/SR-IOV; enable Legacy Option ROMs.
3. **Reboot** from **internal Seagate** Ventoy (Wiggly) — not the USB stick.
4. **Phase 1:** `perc/fohdeesha-freedos.iso` → type **`DOCS`** for manuals → **`info`** → **`BIGB0CRS`** or **`BIGD1CRS`** → `reboot`.
5. **Phase 2:** `perc/fohdeesha-linux.iso` → `sudo su` → **`B0-H710`** or **`D1-H710`** → **`setsas <address>`** → `reboot`.
6. **Ubuntu:** confirm `mpt2sas`, no PERC fault in `dmesg`.

Confirm target before reboot:

```bash
lsblk -o NAME,TRAN,LABEL,MOUNTPOINT | grep -E 'Wiggly|Ventoy|NAME'
# Wiggly  -> sdc1, tran=sata
# Ventoy  -> sdd1, tran=usb  (ignore for PERC flash)
ls -lh /mnt/wiggly/perc/
```

## Pre-flight

| Check | B1GMB42 |
|-------|---------|
| Only one LSI/MegaRAID card | PERC in Slot5 only |
| Drives on PERC | None (no SAS cables) |
| PERC battery (BBU) | Remove and store if present |
| ZFS `rpool` | On motherboard SATA — unaffected |

## BIOS (F2) — flash window

Per Fohdeesha, **before** FreeDOS flash:

- **Boot Mode** → **BIOS** (not UEFI) for the flash steps; return to UEFI after
- Disable **Virtualization Technology**
- Disable **SR-IOV** / **I/OAT DMA** if shown
- **Enable Legacy Option ROMs** + **OROM Keyboard Access = Enable** (for later LSI Ctrl+C utility)

## Boot selection

1. Reboot; enter BIOS boot menu or set **internal Seagate** first (not USB).
2. Ventoy menu should come from **Wiggly** (internal), not the PNY USB stick.
3. Pick **`perc/fohdeesha-freedos.iso`** — Ventoy loads it in **memdisk** (red “Memdisk” hint).

## Phase 1 — FreeDOS

At the `C:\>` prompt, IndianaDell manuals are on **C:** (patched image):

| Command | Purpose |
|---------|---------|
| **`FLASHME`** | Step-by-step wizard (INFO → SASADDR → BIGB0CRS/D1CRS) |
| **`DOCS`** | Quick help + PERC flash reminder |
| **`TYPE BIOS.TXT`** | T5810 BIOS settings for flash window |
| **`TYPE B1GMB42.TXT`** | Machine card (Slot5, Wiggly, no SAS drives) |
| **`TYPE PHASE2.TXT`** | Linux ISO / `setsas` steps |
| **`VIEW PERC-FLASH`** | Open PERC guide as plain text in FreeDOS **EDIT** |
| **`VIEW HARDWARE`** | Hardware / slot inventory |
| **`MDVIEW PERC-FLASH`** | Render markdown to HTML via **QBASDOWN**, open in EDIT |
| **`TYPE INDIANELL\INDEX.TXT`** | List all bundled manuals |

All repo `*.md` files are under `C:\INDIANELL\` as **`.TXT`** (readable) and **`.MD`** (for QBASDOWN).

Then run:

```
info
```

Note:

- **SAS address** (needed in phase 2)
- Card type: **H710 Adapter** (full-size in Slot5, not Mini)
- Revision: **B0** or **D1**

Full-size H710 crossflash (only after `info` matches):

| Revision | Command |
|----------|---------|
| B0 | `BIGB0CRS` |
| D1 | `BIGD1CRS` |

Then:

```
reboot
```

Revert to Dell firmware if wrong script: `BIGB0RVT` / `BIGD1RVT`.

## Phase 2 — Linux ISO

Boot Ventoy on **Wiggly** again → **`perc/fohdeesha-linux.iso`** (normal mode, not memdisk).

```bash
sudo su
# B0 full-size:
B0-H710
# or D1 full-size:
D1-H710

setsas <SAS_ADDRESS_FROM_info>
# Optional UEFI boot ROM after IT flash:
flashboot /root/Bootloaders/x64sas2.rom
reboot
```

## Phase 3 — verify in Ubuntu

```bash
sudo dmesg | grep -iE 'mpt|megaraid'
lsmod | grep mpt
lsblk -o NAME,SIZE,MODEL,TRAN
```

IT mode: **`mpt2sas`** loaded, no `FW in FAULT` from `megaraid_sas`. Individual disks appear when SAS/SATA drives are cabled later.

## Troubleshooting

| Issue | Action |
|-------|--------|
| Ventoy menu shows USB only | BIOS: boot internal disk; unplug USB or move it below Seagate |
| `setup-perc-ventoy` refuses deploy | Script blocks USB Ventoy; only **Wiggly** (sata + label) is allowed |
| FreeDOS won’t boot | Confirm `auto_memdisk` in `/mnt/wiggly/ventoy/ventoy.json` |
| Still faulted before flash | Try phase 1 anyway; may clear ghost RAID; else Ctrl+R PERC BIOS clear |

## References

- Fohdeesha guide: https://fohdeesha.com/docs/perc.html  
- Hardware layout: `B1GMB42-slot-port-inventory.md`  
- Ventoy memdisk: https://www.ventoy.net/en/doc_memdisk.html