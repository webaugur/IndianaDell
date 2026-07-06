---
header-includes:
  - \usepackage{graphicx}
  - \usepackage{grffile}
  - \usepackage{calc}
  - \setlength{\parskip}{0.4em}
  - \newlength{\figtextwd}
  - \newlength{\figimgwd}
  - \setlength{\figtextwd}{0.40\textwidth}
  - \setlength{\figimgwd}{0.58\textwidth}
---

# B1GMB42 Motherboard Slot & Port Inventory

**Machine:** Dell Precision Tower 5810  
**Serial:** B1GMB42 (same chassis; DMI serial blank until SMBIOS repopulated)  
**Hostname:** Tower5810  
**Motherboard:** Dell 0K240Y (BIOS **A34**)  
**Source:** live scan 2026-07-03 (fresh reinstall, **no encryption**)  
**CPU:** Intel Xeon E5-1660 v3 @ 3.00 GHz (1 socket, 16 threads)  
**Regulatory:** D01T / D01T006 (Dell Precision Tower 5810)

**Dell sources used for this section:** Owner's Manual (`precision-t5810-om-pub-en-us.pdf`), Quick Setup Guide, Serial PCIe Setup Guide, Dual-Host Card WP. Diagrams extracted to `docs/images/`.

---

## Reference diagrams (Dell Owner's Manual)

Labels and quick-reference tables are **left**; Dell figures are **right** (PDF layout only via LaTeX). Source: `precision-t5810-om-pub-en-us.pdf`.

```{=latex}
\newcommand{\figrow}[3]{%
  \noindent
  \begin{minipage}[t]{\figtextwd}
  \raggedright
  #2
  \end{minipage}%
  \hspace{0.02\textwidth}%
  \begin{minipage}[t]{\figimgwd}
  \vspace{0pt}%
  \includegraphics[width=\linewidth,height=#1,keepaspectratio]{#3}%
  \end{minipage}%
  \par\vspace{0.65em}%
}

\figrow{5.8cm}{
\textbf{Figure 1 --- Front \& Rear I/O}\\[0.35em]
\small\textit{Every external user-facing port.}\\[0.25em]
\begin{tabular}{@{}cl@{}}
\multicolumn{2}{@{}l}{\textbf{Front (1--11)}}\\[0.15em]
1 & Mic-in\\
4 & USB 3.0\\
5--6 & USB 2.0 $\times$2\\
6--9 & Slim ODD bays (opt.)\\
10 & Headphone\\
11 & Line-in / mic\\
\multicolumn{2}{@{}l}{\textbf{Rear (12--26)}}\\[0.15em]
12 & Serial DB-9\\
13 & USB 2.0 $\times$2\\
14--20 & PS/2, USB3, audio, RJ-45\\
23 & \textbf{GPU + PERC brackets}\\
25 & AC inlet (IEC C14)\\
\end{tabular}\\[0.3em]
\textbf{B1GMB42:} 12 mini-DP on 3 FirePro; Intel I217-LM RJ-45.
}{docs/images/figure-01-front-back.jpg}

\figrow{6.2cm}{
\textbf{Figure 2 --- Inside (top view)}\\[0.35em]
\small\textit{Drive cages, cooling, first GPU.}\\[0.25em]
\begin{tabular}{@{}cl@{}}
1 & CPU heatsink + fan $\rightarrow$ CPU\_FAN\\
2 & Memory shrouds (8 DIMM)\\
4 & 5.25'' + slim ODD bays\\
5 & \textbf{HDD cages} HDD0--3\\
6 & PSU cable shroud\\
7 & Graphics cards Slot1/2/4\\
8 & Intrusion switch\\
\end{tabular}\\[0.3em]
\textbf{B1GMB42:} Hitachi \texttt{rpool}; TEAM special; Seagate Windows.
}{docs/images/figure-02-inside-top.jpg}

\figrow{5.6cm}{
\textbf{Figure 3 --- Inside (PSU side)}\\[0.35em]
\small\textit{Power module, retention cage, speaker.}\\[0.25em]
\begin{tabular}{@{}cl@{}}
1 & PCIe retention latch\\
2 & Speaker $\rightarrow$ SPK header\\
3 & \textbf{PSU} 425/685\,W\\
4 & Motherboard 0K240Y\\
\end{tabular}\\[0.3em]
\textbf{Cables via shroud:}\\
24-pin ATX (29), 10-pin CPU (30),\\
SATA power to each drive.\\
\textbf{PERC H710} in Slot5.
}{docs/images/figure-03-inside-psu.jpg}

\noindent
\begin{minipage}[t]{\figtextwd}
\raggedright
\textbf{Figure 4 --- System board labels (1--30)}\\[0.3em]
\scriptsize
\begin{tabular}{@{}r@{\hspace{0.4em}}p{0.42\linewidth}@{}}
1 & PCI slot (Slot6)\\
2 & PCIe x16 / x4 wired (Slot5)\\
3 & PCIe 3.0 x16 (Slot4)\\
4 & PCIe 2.0 x1 (Slot3)\\
5 & PCIe 3.0 x16 (Slot2)\\
6 & PCIe 3.0 x16 / x8 (Slot1)\\
7 & DIMM slots (channel A)\\
8 & Intrusion-switch connector\\
9 & CPU heatsink fan (5-pin)\\
10 & Processor socket LGA2011-3\\
11 & DIMM slots (channel B)\\
12 & Front-panel audio (HD)\\
13 & Internal USB 2.0 header\\
14 & Coin-cell battery CR2032\\
15 & Optional HDD fan (5-pin)\\
\end{tabular}
\hspace{0.15em}
\begin{tabular}{@{}r@{\hspace{0.4em}}p{0.42\linewidth}@{}}
16 & System fan (4-pin)\\
17 & HDD temperature sensor\\
18 & System fan (4-pin)\\
19 & PWR\_REMOTE (host card)\\
20 & Thunderbolt sideband\\
21 & System fan (4-pin)\\
22 & Password jumper\\
23 & Front panel + USB 2.0\\
24 & Internal speaker\\
25 & USB 3.0 front-panel\\
26 & Internal USB flexbay\\
27 & SATA HDD0--3 + ODD0--1\\
28 & RTC\_RST jumper\\
29 & 24-pin system power\\
30 & CPU power (10-pin EPS)\\
\end{tabular}
\end{minipage}%
\hspace{0.02\textwidth}%
\begin{minipage}[t]{\figimgwd}
\vspace{0pt}%
\includegraphics[width=\linewidth,height=8.2cm,keepaspectratio]{docs/images/figure-04-system-board-detail.jpg}\\[0.45em]
\small\raggedright
\textbf{B1GMB42 summary (Fig 4)}\\[0.25em]
\begin{tabular}{@{}lp{0.72\linewidth}@{}}
\textbf{Slots} & 1 W5000, 2 W5100, 4 W5000, 5 PERC H710, 3 empty\\
\textbf{SATA 27} & Hitachi \texttt{rpool}, Seagate Windows, TEAM special\\
\textbf{Power} & 29 ATX + 30 CPU EPS from PSU shroud\\
\textbf{Front} & 12 audio, 23 panel/LED/USB2, 25 USB3\\
\textbf{Fans} & 9 CPU + 16/18/21 chassis\\
\textbf{PCIe bus} & 01:00 / 02:00 / 03:00 GPUs; 07:00 PERC\\
\end{tabular}
\end{minipage}
\par\vspace{0.65em}
```

### Quick slot map (B1GMB42 as-built)

```
Chassis front
    |
    v
+---+---------------------------+
|CPU| DIMM1 DIMM2 DIMM3  (empty x5)
|fan| [==== memory shrouds ====]
+---+---------------------------+
| ODD / 5.25" bay (top)         |
| HDD cage 0 | HDD cage 1       |  <- Hitachi, Seagate, TEAM
+------------+------------------+
| Slot1 W5000 | Slot2 W5100     |  PCIe retention cage
| Slot4 W5000 | Slot5 PERC H710 |
+-------------+-----------------+
| PSU (bottom rear)             |
+-------------------------------+
Rear I/O + GPU brackets + AC inlet
```

| Figure file | Path |
|-------------|------|
| Fig 1 | `docs/images/figure-01-front-back.jpg` |
| Fig 2 | `docs/images/figure-02-inside-top.jpg` |
| Fig 3 | `docs/images/figure-03-inside-psu.jpg` |
| Fig 4 | `docs/images/figure-04-system-board-detail.jpg` |

---

## Reinstall notes (post-TPM/disk incident)

Previous install used **ZFS native encryption + encrypted swap (TPM)**. Disk changes with TPM locked the system. This install is **identical hardware** with:

| Item | Old install | This install |
|------|-------------|--------------|
| ZFS `rpool` encryption | on (TPM) | **off** |
| Swap | `dm-crypt` on sdb3 | **plain** sdb3 |
| Hostname | PT5810 | **Tower5810** |
| ZFS root dataset | `ubuntu_mefuj7` | **`ubuntu_cortt9`** |
| TEAM SSD | special vdev on `rpool` | **attached** — `special_small_blocks=32K` |
| USB 2×2TB WD enclosure | present (flaky) | **removed** — Ventoy stick only |
| Apport | enabled | **purged** |

---

## As-Built PCIe Slots (Dell silkscreen)

| Dell slot | Bus address | Electrical | Status | Attached |
|-----------|-------------|------------|--------|----------|
| **Slot1** | `01:00.0` | PCIe 3 x16 | In use | AMD FirePro **W5000** + HDMI audio (`amdgpu`) |
| **Slot2** | `02:00.0` | PCIe 3 x16 | In use | AMD FirePro **W5100** + HDMI audio (`amdgpu`) |
| **Slot3** | — | PCIe 2 | Empty | — |
| **Slot4** | `03:00.0` | PCIe 3 x16 | In use | AMD FirePro **W5000** + HDMI audio (`amdgpu`) |
| **Slot5** | `07:00.0` | PCIe 2 x4 | In use | Dell **PERC H710** — **FW FAULT `0x40000`** |
| **Slot6** | — | Legacy PCI | Riser | Open |

### GPU device mapping

| PCI | Card | DRI device | Render node |
|-----|------|------------|-------------|
| 01:00.0 | FirePro W5000 | `/dev/dri/card1` | `renderD128` |
| 02:00.0 | FirePro W5100 | `/dev/dri/card2` | `renderD129` |
| 03:00.0 | FirePro W5000 | `/dev/dri/card3` | `renderD130` |

All three load **`amdgpu`**. W5100 logs `Cannot find any crtc or sizes` when headless (no monitor cable).

### Dell silkscreen PCIe map (factory spec)

| Dell slot | Electrical (manual) | Max power (manual) | Typical use |
|-----------|---------------------|--------------------|-------------|
| **Slot1** | PCIe 3.0 x16 (wired x8) | 75 W slot | Primary GPU / boot display |
| **Slot2** | PCIe 3.0 x16 | 75 W slot | Second GPU or accelerator |
| **Slot3** | PCIe 2.0 x1 | 25 W | NIC, USB3 card, TPM, serial |
| **Slot4** | PCIe 3.0 x16 | 75 W slot | Third GPU or high-bandwidth card |
| **Slot5** | PCIe 2.0 x4 | 25 W | **PERC / RAID** (H710 in B1GMB42) |
| **Slot6** | PCI 2.3 (32-bit) | — | Legacy PCI via riser (Slot4 area) |

Manual allows up to **two** full-height full-length PCIe x16 cards at 225 W each; B1GMB42 exceeds that count with three 75 W FirePro cards — confirm PSU label (**425 W** or **685 W**).

Serial PCIe add-in card (if installed): valid slots **1, 3, 4, 5** per Dell Serial PCIe Setup Guide.

---

## Every external cable / port (outside the chassis)

### Front panel (left to right, Fig 1)

| # | Connector | Type | Connect |
|---|-----------|------|---------|
| 1 | Microphone | 3.5 mm TRS | Headset mic |
| 2 | Power button | — | — (chassis switch) |
| 3 | HDD activity LED | — | — (status only) |
| 4 | USB | **USB 3.0** | Keyboard, stick, hub |
| 5–6 | USB | **USB 2.0** ×2 | Mouse, audio, etc. |
| 6–9 | Optical drive | Slim SATA ODD ×2 (optional) | Install media |
| 10 | Headphone | 3.5 mm TRS | Headphones |
| 11 | Line-in / mic | 3.5 mm TRRS | Analog audio in |

### Rear panel (left to right, Fig 1)

| # | Connector | Type | Connect |
|---|-----------|------|---------|
| 12 | Serial | 9-pin DB-9 | Serial device (COM1 default) |
| 13 | USB | **USB 2.0** ×2 | Legacy peripherals |
| 14 | PS/2 | Keyboard | PS/2 keyboard |
| 15 | USB | **USB 3.0** ×2 | Fast peripherals |
| 16 | Line-out | 3.5 mm TRS | Powered speakers / amp |
| 17 | Security cable | Kensington slot | Physical lock |
| 18 | Padlock ring | — | Padlock hasp |
| 19 | Network | **RJ-45** (Intel I217-LM) | Ethernet cable |
| 20 | PS/2 | Mouse | PS/2 mouse |
| 21 | USB | **USB 3.0** | Fast peripheral |
| 22 | USB | **USB 2.0** | Peripheral |
| 23 | Expansion slots | PCIe/PCI bracket | **GPU DP/HDMI**, PERC SAS, serial |
| 24 | Mechanical slot | Vent / blank | No active ports |
| 25 | AC power | **IEC C14** inlet | Detachable AC cord to wall |
| 26 | PSU latch | — | Release PSU module |

### Rear GPU display ports (B1GMB42 as-built)

Each FirePro exposes **4× mini-DisplayPort** on the bracket. Plug the monitor into **whichever GPU** should drive the desktop (unpinned policy). Unused GPUs may stay headless.

| Card | Bracket location | Video out |
|------|------------------|-----------|
| W5000 Slot1 | Upper slot region | 4× mini-DP |
| W5100 Slot2 | Mid region | 4× mini-DP |
| W5000 Slot4 | Lower region | 4× mini-DP |

---

## Every internal cable / header / slot (inside the chassis)

### Chassis regions (Fig 2–3)

| Region | What connects here |
|--------|-------------------|
| CPU heatsink + fan | 5-pin **CPU_FAN** header on motherboard |
| Memory shrouds | DIMM1–8 under shrouds (B1GMB42: DIMM1/2/3 populated) |
| 5.25" bay | Full-height ODD or 3.5" adapter / card reader |
| Slim ODD bays | Up to 2 slim SATA optical drives |
| Primary HDD cages | **HDD0–HDD3** SATA + power (3.5" or 2.5" caddies) |
| PSU cable shroud | Routed **SATA power**, **24-pin**, **CPU 10-pin**, drive harness |
| PCIe retention cage | Full-height cards (GPUs, PERC) |
| Internal speaker | 4-pin speaker header |
| PSU module | Bottom/rear; slide-latch removal |

### Motherboard labeled connectors (Fig 4 — all 30)

Full numbered list is left of the Fig 4 photo in the PDF; summary sits under the photo. Expanded reference:

| # | Dell label | Header / slot | Cable / device |
|---|------------|---------------|----------------|
| 1 | PCI slot | **Slot6** legacy PCI | PCI riser card |
| 2 | PCIe x16 (x4 wired) | **Slot5** | **PERC H710** (B1GMB42) |
| 3 | PCIe 3.0 x16 | **Slot4** | **FirePro W5000 #2** |
| 4 | PCIe 2.0 x1 | **Slot3** | Empty — NIC, USB3, serial |
| 5 | PCIe 3.0 x16 | **Slot2** | **FirePro W5100** |
| 6 | PCIe 3.0 x16 (x8 wired) | **Slot1** | **FirePro W5000 #1** |
| 7 | DIMM slots | Channel A | DDR4 RDIMM (DIMM1, DIMM5, …) |
| 8 | Intrusion switch | 2-pin | Chassis intrusion cable |
| 9 | CPU heatsink fan | 5-pin | CPU fan tach/power |
| 10 | Processor socket | LGA2011-3 | Xeon E5-1660 v3 |
| 11 | DIMM slots | Channel B | DDR4 RDIMM (DIMM2, DIMM3, …) |
| 12 | Front-panel audio | 2×5 HD Audio | Front mic/headphone jack cable |
| 13 | Internal USB 2.0 | 2×5 header | Type-A internal port or cable |
| 14 | Coin-cell battery | CR2032 | BIOS clock / CMOS |
| 15 | Optional HDD fan | 5-pin | Bay cooling fan |
| 16 | System fan | 4-pin | Chassis fan #1 |
| 17 | HDD temp sensor | 2-pin | Thermal probe on drive cage |
| 18 | System fan | 4-pin | Chassis fan #2 |
| 19 | PWR_REMOTE | 2-wire | Teradici / dual-host card (optional) |
| 20 | Thunderbolt sideband | 5-pin | Dell Thunderbolt PCIe card (optional) |
| 21 | System fan | 4-pin | Chassis fan #3 |
| 22 | Password jumper | 2-pin | BIOS setup password enable |
| 23 | Front panel + USB2 | 2×14 | Power LED, HDD LED, power switch, USB2 front |
| 24 | Internal speaker | 4-pin | Chassis beeper |
| 25 | USB 3.0 front panel | 20-pin | Front USB3 port cable |
| 26 | Internal USB flexbay | 2×5 | Flex bay / media reader USB |
| 27 | **SATA** | 7-pin ×6 | **HDD0–3 + ODD0–1** (see table below) |
| 28 | RTC_RST jumper | 2-pin | Clear CMOS (with battery out) |
| 29 | 24-pin ATX | Main power | From PSU — **always required** |
| 30 | CPU power | 10-pin EPS | From PSU — **always required** |

### SATA port map (motherboard silkscreen → device)

| SATA label | Controller | Typical bay | B1GMB42 as-built |
|------------|------------|-------------|------------------|
| SATA3-HDD0 | Intel AHCI | Primary internal bay 0 | Likely **Hitachi** (`sdb`, ZFS) |
| SATA3-HDD1 | Intel AHCI | Primary internal bay 1 | Likely **Seagate** (`sdc`, Windows) |
| SATA2-HDD2 | Intel AHCI | Primary internal bay 2 | Empty or DVD |
| SATA2-HDD3 | Intel AHCI | Primary internal bay 3 | Empty |
| SATA2-ODD0 | Intel AHCI | Slim ODD bay 0 | **PLDS DVD** if installed (`sr0`) |
| SATA2-ODD1 | Intel AHCI | Slim ODD bay 1 | Empty |

**TEAM SSD** (`sda`) is on a separate port (often flex bay or HDD1) and serves as **ZFS special vdev** — confirm with `lsblk` / cable trace after opening cover.

### Internal drive power (from PSU)

Each 3.5"/2.5" device needs:

- **SATA data** → motherboard port 27 (one of HDD0–3 / ODD0–1)
- **SATA power** → PSU flat connector (15-pin SATA power)

Optical drives use the same SATA data + power pair. Do not mix data cables across ODD vs HDD ports if BIOS boot order matters.

### Fan headers summary

| Header | Purpose |
|--------|---------|
| CPU_FAN (9) | Stock CPU heatsink fan — **required** |
| SYS_FAN (16, 18, 21) | Chassis exhaust/intake fans |
| HDD_FAN (15) | Optional drive-bay fan |
| Memory shroud fans | Some configs — BIOS alerts if missing |

### Front-panel signal cable (item 23)

Single harness carries: power switch, power LED, HDD activity LED, and front USB2 ports. A disconnected harness causes **"Front I/O Cable failure"** at boot.

### Optional / factory expansion wiring

| Option | Internal connection |
|--------|---------------------|
| Dell Thunderbolt PCIe card | Slot3 or Slot5 + **TB sideband (20)** |
| Dual/Quad host PCIe card | Any x16/x8 slot + **PWR_REMOTE (19)** 2-wire to system board |
| Serial PCIe card | Slots **1, 3, 4, or 5** + rear DB-9 bracket |
| Media card reader | 5.25" bay + **flexbay USB (26)** + SATA power |
| PERC H710 | **Slot5** + SAS cables to backplane (if cabled) |

---

## Storage — SATA / SAS / USB

### Internal SATA disks

| OS dev | Size | Model | Role |
|--------|------|-------|------|
| **sda** | 238 GB | TEAM T253X6256G | **`rpool` special vdev** (~509 MB/s seq read) |
| **sdb** | 1.4 TB | Hitachi HDS723015BLA642 | `rpool` + `bpool`, EFI, **plain swap** (~145 MB/s) |
| **sdc** | 466 GB | Seagate ST500DM002 | Ventoy + DOSBOOT + Windows + **live persistence** (see below) |

#### sdc partition map (Seagate)

| Part | Size | FS | Label | Role |
|------|------|-----|-------|------|
| sdc1 | 75 GB | exfat | Wiggly | Ventoy ISO host |
| sdc2 | 32 MB | vfat | VTOYEFI | Ventoy EFI |
| sdc3 | 94 GB | vfat | DOSBOOT | DOS/retro + `IndianaDell/recovery/` ZFS kit |
| sdc4 | 100 MB | vfat | — | Windows EFI |
| sdc5 | 16 MB | — | — | Microsoft reserved |
| sdc6 | 264 GB | ntfs | Windows10 | Windows data (shrunk from 318 GB) |
| **sdc8** | **33 GB** | **ext4** | **writable** | **Ubuntu Ventoy live persistence** |
| sdc7 | 522 MB | ntfs | — | Dell recovery |

### ZFS pools (current)

| Pool | Device | Health | Notes |
|------|--------|--------|-------|
| `rpool` | Hitachi `sdb4` | ONLINE | Root + `/home`, **encryption off**, `compression=lz4` |
| `rpool` special | TEAM `sda` | ONLINE | Metadata + blocks <=32K; `special_small_blocks=32K` |
| `bpool` | Hitachi `sdb2` | ONLINE | `/boot` |

### SAS / RAID (Slot5)

| Item | Detail |
|------|--------|
| Card | PERC H710 @ `07:00.0` |
| Driver | `megaraid_sas` |
| Status | **FAULT** — `FW in FAULT state, Fault code:0x40000` |
| Disks exposed | **None** |

### USB-attached storage

| OS dev | Size | Model | Notes |
|--------|------|-------|-------|
| sdd | 30 GB | PNY USB (Ventoy) | Install/recovery stick — not production storage |

---

## USB (motherboard)

### Controllers

| Controller | Type | Typical ports |
|------------|------|---------------|
| `00:14.0` xHCI | USB 3.0 | Rear USB3 |
| `00:1d.0` EHCI | USB 2.0 | Rear/front USB2 |
| `00:1a.0` EHCI | USB 2.0 | Internal headers / front |

### Attached devices (current)

| Device | Notes |
|--------|-------|
| Realtek RTS5182 | Front-panel card reader (empty slots) |
| CSR Bluetooth | Onboard BT dongle |
| C-Media USB audio | USB sound |
| Dell keyboard / wireless mouse | Input |

**Removed since pre-crash inventory:** JMicron USB 2×2TB WD enclosures (were `sdg`/`sdh`, caused I/O errors — powered off).

---

## Network

| Port | Chip | Bus | Status |
|------|------|-----|--------|
| Onboard RJ-45 | Intel I217-LM | `00:19.0` | Present |
| PCIe NIC | — | — | None installed |
| USB Wi-Fi | — | — | Not attached now (D-Link DWA-121 was on old scan) |

---

## Audio

| Source | Device | Status |
|--------|--------|--------|
| Motherboard | Intel C610 HD Audio `00:1b.0` | Onboard analog jacks |
| GPU ×3 | AMD HDMI audio on each FirePro | On display outputs |
| USB | C-Media USB audio | Attached |

---

## Memory (DIMM slots)

| Slot | Status | Module |
|------|--------|--------|
| DIMM1 | Occupied | 4 GB Hynix DDR4-2133 |
| DIMM2 | Occupied | 4 GB Hynix DDR4-2133 |
| DIMM3 | Occupied | 4 GB Hynix DDR4-2133 |
| DIMM5 | Empty | — |
| DIMM6 | Empty | — |
| DIMM7 | Empty | — |

**Total:** ~15 GiB usable. Board has additional slots — target 32 GB+.

### SATA controllers

| Controller | Ports |
|------------|-------|
| `00:1f.2` 6-port SATA (AHCI) | SATA 0–5 |
| `00:11.4` sSATA (AHCI) | sSATA 0–3 |

DVD/ODD and exact bay silkscreen mapping not captured in software inventory.

---

## Headless GPU use

GPUs do **not** need a monitor to run Vulkan/OpenGL compute or offscreen render. Only the **desktop session** GPU needs a cable (or dummy plug).

| Use case | Headless OK? |
|----------|------------|
| `vkcube` / Vulkan stress (`bin/gpu-stress`) | Yes |
| OpenCL / offscreen GL on W5000/W5100 | Usually yes |
| ROCm / HIP ML | No — W5000/W5100 not in ROCm matrix |
| GNOME Wayland desktop | One GPU needs display or dummy plug |

```bash
lspci | grep -i vga
ls -l /dev/dri/
DRI_PRIME=1 glxinfo | grep 'OpenGL renderer'   # pick non-primary GPU
```

---

## Video Manual (unpinned multi-GPU)

**Policy:** No forced primary GPU. Plug the monitor into whichever card should drive the desktop.

### Shared limits

| Limit | Value |
|-------|-------|
| AMD rated ports per GPU | **4** mini-DP |
| Physical ports installed | **12** (4 per card) |
| Wayland desktop GPUs | **1** (session binds to one GPU) |
| X11 multi-GPU displays | **~12** with `xrandr` providers |

### Config files (`etc/`)

| File | Purpose |
|------|---------|
| `etc/modprobe.d/amdgpu-multigpu.conf` | `runpm=0` — stable multi-GPU |
| `etc/udev/rules.d/99-amdgpu-multigpu.rules` | GPU tags (no `setpci` pin) |
| `etc/X11/xorg.conf.d/20-amdgpu-multi-gpu.conf` | X11 multi-GPU, no BusID |
| `etc/gdm3/custom.conf` | `WaylandEnable=true` |
| `etc/environment.d/99-amdgpu-wayland.conf` | Mesa radeonsi |
| `bin/apply-amdgpu` | Installer — run `sudo bin/apply-amdgpu` |

### Wayland session

- GDM gear menu: **Ubuntu** (Wayland) or **Ubuntu on Xorg**
- Verify: `echo $XDG_SESSION_TYPE` should print `wayland`
- Headless GPUs: use **HDMI/DP dummy plugs** if an app needs a CRTC

### X11 session

- Multi-GPU: `xrandr --listproviders` then per-provider `xrandr`
- Dual-boot Windows: set primary display in Windows separately

### W5000 vs W5100 as display GPU

No meaningful desktop difference. W5000 slightly stronger for 3D on the display GPU.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Boot failure after disk swap | **TPM + ZFS encryption** on old install | This reinstall avoids that — keep encryption off unless TPM is configured first |
| UI freezes, high load | ZFS on HDD, low RAM | Add TEAM special vdev; add RAM; avoid swap thrash |
| `Cannot find any crtc` | Headless GPU | Expected; dummy plug if needed |
| PERC no disks | FW fault `0x40000` | PERC BIOS / battery / replace or IT-mode flash |
| Wrong display GPU | Cable on different card | Move cable (unpinned policy) |
| `show_signal_msg: N callbacks suppressed` | Kernel rate-limiting duplicate logs | Not N separate errors — read the one line above |

### Triple-GPU / PSU

- **Installed:** 2× W5000 + 1× W5100 (75 W each, slot-powered)
- **Estimated peak:** ~440 W — confirm PSU label (**425 W** tight, **685 W** comfortable)
- Stress test: `bin/gpu-stress 60 vkcube`

---

## Summary — Occupied vs Free

| Resource | Used | Free |
|----------|------|------|
| PCIe Slot1 (x8) | FirePro W5000 | — |
| PCIe Slot2 (x16) | FirePro W5100 | — |
| PCIe Slot3 (x1) | — | Open (NIC, USB3, serial) |
| PCIe Slot4 (x16) | FirePro W5000 | — |
| PCIe Slot5 (x4) | PERC H710 (faulted) | — |
| PCIe Slot6 (PCI) | Riser only | Legacy PCI card |
| SATA HDD0–3 | Hitachi + Seagate (+ TEAM) | 1–2 bays |
| SATA ODD0–1 | DVD (if installed) | 1 slim bay |
| DIMM (8 slots) | 3 × 4 GB | 5 slots |
| Front USB | All active | — |
| Rear USB | Most active | Some ports |
| Internal USB headers | Card reader, BT | 1–2 headers |
| Fan headers | CPU + system | 1–2 optional |
| ZFS special vdev | TEAM SSD | — |
| Encryption | off | — |

---

## IndianaDell workspace

```
IndianaDell/
├── B1GMB42-slot-port-inventory.md   # this file (hardware)
├── B1GMB42-software-manual.pdf      # software manual (bin/build-software-manual)
├── B1GMB42-zfs-recovery.pdf         # rpool/bpool live-CD recovery
├── docs/B1GMB42-zfs-recovery.md     # ZFS recovery (also DOSBOOT/IndianaDell/recovery/)
├── docs/software-manual/            # software manual chapters
├── B1GMB42-software-inventory.md    # stub → software manual
├── b1gmb42.report / B1GMB42.ioperf  # live inventory + disk benchmark
├── 8SNZK02.report / 8SNZK02.ioperf  # second machine (thumper / Titan Xp)
├── bin/                  # launchers → scripts/, Themes/, hackrf/, etc/
├── scripts/dell/, scripts/gpu/, scripts/storage/, scripts/gnome/, scripts/rebuild/
├── Themes/               # boot (Plymouth), login (GDM), desktop (Yaru) — README per folder
├── etc/                             # multi-GPU Wayland/X11 config
├── amd-radeon/                      # manual ROCm install toolkit
└── FactoryDocs/                     # Dell support packages (sorted)
    ├── _incoming/                   # drop new downloads here
    ├── _sort_factory_docs.py        # dedupe + sort script
    └── README.md                    # folder index
```

### FactoryDocs ingest

```bash
cp ~/Downloads/* ~/Documents/IndianaDell/FactoryDocs/_incoming/
python3 ~/Documents/IndianaDell/FactoryDocs/_sort_factory_docs.py
```

**Pre-crash:** 101 sorted Dell packages (~500 MB). **Now:** 19 on disk. See `FactoryDocs/MANIFEST-pre-crash.txt` for the full list of what to re-download (GPU, PERC, audio, TPM, Win7/10 CABs, SSD firmware, etc.).

### Themes (boot / login / desktop)

See `Themes/README.md`. Boot splash: Dell logo = UEFI BGRT; Ubuntu text = Plymouth watermark. Replace via `Themes/boot/overlay/` and `sudo bin/themes-install-boot`. Login/desktop dark: `bin/apply-dark-mode`.

---

## Action Items

1. **Apply video config** (if not done): `cd ~/Documents/IndianaDell && sudo bin/apply-amdgpu` then reboot.
2. **RAM:** Upgrade to 32 GB+ when possible (currently 3×4 GB).
3. **PERC H710:** Fix firmware fault or replace before using SAS bays.
4. **PSU:** Confirm wattage on PSU label.
5. **Do not re-enable ZFS encryption** until TPM + recovery strategy is documented.
6. **FactoryDocs:** Re-grab any drivers that failed mid-download (GPU, audio, encryption zips).

---

## Refresh commands

```bash
cd ~/Documents/IndianaDell
chmod +x bin/*
sudo bin/dellmerge > b1gmb42.report
pandoc B1GMB42-slot-port-inventory.md -o B1GMB42-slot-port-inventory.pdf \
  --pdf-engine=xelatex -V mainfont="Noto Sans" -V monofont="DejaVu Sans Mono"
zpool status && zpool list -v rpool
lsblk -o NAME,SIZE,MODEL,TRAN,FSTYPE,MOUNTPOINT
lspci -nn | grep -iE 'vga|raid'
sudo dmesg | grep -iE 'megaraid|amdgpu|fault'
```

---

*IndianaDell workstation toolkit. Last updated: 2026-07-05 (sdc8 live persistence).*