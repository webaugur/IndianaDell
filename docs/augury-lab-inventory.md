# Augury Lab inventory (Web Archive 2004 snapshot)

Source (crawled ~2 levels):  
https://web.archive.org/web/20040727114255/http://www.webaugur.com/dave/comp/augury/

Parent context: https://web.archive.org/web/20040720081913/http://www.webaugur.com/dave/comp/

**Host:** Tower5810 / IndianaDell. Period ISOs can live in **Uncle Wiggly** 🥕🐰 (`/mnt/wiggly`); import with `bin/boxes-import-wiggly-isos` (x86) or custom QEMU for non-x86.

Goal: replicate each **named machine** in GNOME Boxes / QEMU with period OS and software as far as emulation allows. This is a proof of concept for a larger multi-arch lab.

## Named machines (Augury fleet)

| Name | Role | Hardware (as documented) | Arch | Period OS / desktop | Emulation path | Boxes? |
|------|------|--------------------------|------|---------------------|----------------|--------|
| **Calculon** | SQL server | AMD Athlon T-bird 1.2 GHz, 512 MB DDR, GA-7DXR, Promise ATA RAID, Linksys LNE100TX, ATI Radeon, SB PCI 128 | **x86_64** (run as i686/x86_64) | Linux **2.4.8 SMP**, **Slackware**, MySQL on RAID, no floppy | QEMU/KVM + Boxes | **Yes** (POC #1) |
| **Daneel** | Workstation | AMD T-bird 1 GHz, 640 MB PC133, A7V133 / VIA KT133A, GeForce2 MX, SB Live!, Wacom, SCSI Adaptec 2930U2 | **x86** | Linux **2.4**, **Red Hat**, XFree86, **GNOME** | QEMU/KVM + Boxes | **Yes** (POC #2) |
| **Marconi** | Server / ham & weather | Intel **Pentium 133 MHz**, 32 MB, Cirrus, Linksys LNE100TX; Peet Ultimeter 2000; PacComm-style TNC + VHF | **i386** | Linux **2.4.5**, **Slackware**, headless-ish | QEMU/KVM (i686), serial for “weather/TNC” stubs | **Yes** (POC #3) |
| **Trance** | Notebook | **Toshiba Portegé**, Pentium **90 MHz**, 40 MB, 10″ LCD, Glidepoint; PCMCIA Ether + modem | **i386** | Linux **2.4.3**, **Mandrake**, XFree86, **Ximian GNOME 1.4** | QEMU/KVM i686 (laptop as desktop VM) | **Yes** (POC #4) |
| **Galaxia** | Server/WS | **Apple PowerMac 6400/180**, PPC **603e @ 180 MHz**, 56 MB, Valkyrie FB + ATI Rage Pro, dual Adaptec SCSI | **PowerPC (32)** | Linux **2.2.14**, **Yellow Dog**, XFree86, Ximian GNOME | **QEMU `ppc`** (not Boxes-native) | Via QEMU/CLI or virt-manager |
| **Basilisk** | PA-RISC workstation | **HP Apollo 9000/730** “King Cobra”, **PA-7000 @ 66 MHz**, ASP chipset, EISA/GSC/SGC, CRX 1280×1024, 2×2.1 GB SCSI | **PA-RISC (hppa)** | **PA-RISC Linux** (Debian Sid era) / HP-UX media in photos | **QEMU hppa** (limited) or Hercules-class rarity | Research / later |
| **Frobnitz** | Library server | **DEC VAXServer 3100** model **KA41-B**, internal+external SCSI; page also shows Alpha/OpenVMS branding | **VAX** (primary text); Alpha/OpenVMS may be aspirational/mixed | **Ultrix** (stated); OpenVMS logo present | **SIMH VAX** (not Boxes); optional Alpha QEMU later | External launcher |
| **HPLaser** | Print server | **Lantronix EPS1**, EPS firmware **3.6.4**, 2 MB flash, BOOTP; HP LaserJet 4MP | **Embedded** (not a general CPU for us) | Lantronix firmware | Soft device / CUPS queue / container stub | Stub service, not a full VM |

### Topology notes (from site)

- Network names like `*.webaugur.com` / `*.augur.homeip.net` (home lab).
- **Calculon** NFS-mounts **Daneel:/home** (~60 GB era).
- **Daneel** holds Augury Library under `/home/public` (large RAID).
- **HPLaser** boots via DHCP/BOOTP from a host (Calculon/Daneel era).

## Architectures summary

| Arch | Machines | Host support today |
|------|----------|--------------------|
| **x86 / i386** | Calculon, Daneel, Marconi, Trance | Boxes + KVM (already) |
| **PowerPC 32** | Galaxia | Install `qemu-system-ppc`; TCG |
| **PA-RISC / hppa** | Basilisk | `qemu-system-misc` hppa if available; fragile |
| **VAX** | Frobnitz | **SIMH** (best fidelity) |
| **Embedded** | HPLaser | Service emulation, not guest OS |

## Historical machines (from `/dave/comp/` essay, not full Augury cards)

Mentioned as personal history — optional later “museum” VMs:

| Era | Machine | Arch | Period software |
|-----|---------|------|-----------------|
| 1980s | Commodore **64C** | 6510 | BASIC, **GEOS**, C64 Wedge |
| School | **Apple II** | 6502 | BASIC |
| School | **Macintosh** / PowerMac | 68k / PPC | Mac OS classic |
| School | **8088** lab PCs | i8086 | DOS games / ECHO OFF |
| ~1995–96 | Built **PC** (486+) | x86 | DOS, Win 3.1 (8 days), **Win95**, NT, 98, 2000 |
| Illumination | **DarkStar** 486 | i486 | **Red Hat Linux 5.0** |

## Period software targets (POC)

| Machine | Distro ISO target (period) | Desktop / services |
|---------|----------------------------|--------------------|
| Calculon | Slackware 8.x–9.x (~2001–03) | MySQL, NFS client, no X required |
| Daneel | Red Hat 7.3 / 8.0 / 9 | GNOME 1.4–2.x, XFree86, desktop apps |
| Marconi | Slackware 8.x | serial stubs for weather/TNC |
| Trance | Mandrake 8.x | Ximian GNOME 1.4 feel |
| Galaxia | Yellow Dog Linux 2.x | GNOME on PPC |
| Basilisk | Debian hppa or HP-UX 10.20 media if legal | PA Linux if QEMU works |
| Frobnitz | Ultrix 4.x on SIMH VAX 3100 | library server role |
| HPLaser | n/a | `lpd`/CUPS queue named `hplaser` |

## Proof-of-concept implementation plan

### Phase A — Boxes-native (x86 only) — start here

1. Create VMs named **exactly**: `augury-calculon`, `augury-daneel`, `augury-marconi`, `augury-trance`.
2. Hardware profile (period-ish, runnable):
   - Calculon: 512–1024 MB, 2 vCPU, IDE, e1000/rtl8139, 20 GB disk  
   - Daneel: 640–1024 MB, 2 vCPU, IDE, 40 GB disk, Spice display  
   - Marconi: 64–128 MB, 1 vCPU, Cirrus, serial console  
   - Trance: 64–128 MB, 1 vCPU, Cirrus  
3. Install period ISOs (legal copies on Uncle Wiggly or ISO-STASH).
4. Minimal software: same family of distro + role packages (mysql / gnome / serial tools).

### Phase B — Multi-arch QEMU (not Boxes UI)

5. Install `qemu-system-ppc` → **Galaxia**.  
6. Evaluate `qemu-system-hppa` / Debian ports → **Basilisk**.  
7. Package **SIMH** launcher → **Frobnitz** VAX + Ultrix tape/disk images if available.  
8. **HPLaser**: systemd unit or docker with BOOTP + raw parallel-to-file “print”.

### Phase C — Lab fabric

9. User-mode or libvirt network `augury` (192.168.era.x).  
10. NFS export from Daneel-like volume; Calculon mounts `/home`.  
11. Hostnames in `/etc/hosts` matching archive names.

## Honest limits

- **GNOME Boxes** is effectively **x86 only** for a polished experience.  
- **PA-RISC / VAX** need specialized emulators; fidelity will lag.  
- **Exact** Slackware/RH/Mandrake/Yellow Dog ISOs need to be obtained legally (not assumed on Wiggly).  
- Peripheral theater (Ultimeter, TNC, radio, Wacom, PhotoSmart) = stubs or host pass-through later.  
- Logo on Frobnitz (Alpha/OpenVMS) conflicts with body text (VAX + Ultrix) — POC follows **body text** unless you confirm Alpha.

## Next action

1. Collect legal period ISOs onto Uncle Wiggly (or an ISO stash).  
2. Phase A: `bin/boxes-import-wiggly-isos` for modern ISOs; create named **augury-*** VMs for Calculon/Daneel/Marconi/Trance by hand with period media.  
3. Phase B: `qemu-system-ppc` / SIMH for Galaxia / Frobnitz when media is available.

```bash
# List / import whatever ISOs are already in the rabbit hole
bin/boxes-import-wiggly-isos          # DRY_RUN=1 to preview
DRY_RUN=1 bin/boxes-import-wiggly-isos
```

---

*Captured from Wayback Jul 2004 listing + machine pages (Calculon, Daneel, Marconi, Trance, Galaxia, Basilisk, Frobnitz, HPLaser) and parent Computer Perspectives essay.*
