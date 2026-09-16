# WCH USB hub + CS202 audio dock

**Captured:** 2026-09-04 on **Tower5810** (`B1GMB42`)  
**Role:** Shared lab USB dock (audio + extra ports; intended for one or more IndianaDell machines)  
**Hardware manual:** `B1GMB42-slot-port-inventory.md` / PDF — section **Lab USB dock (WCH + CS202 + Genesys)**  
**Do not confuse with:** the JMicron USB-SATA duplicator in `docs/usb-dock-stability.md` (`152d:2352`)

This is the dock plugged in today. Linux did **not** print a brand string. Identification is from USB IDs, topology, and ALSA/PipeWire names.

---

## What it is (as seen by Linux)

A cheap **USB 2.0** dock built from two cascaded **QinHeng / WCH 4-port hubs**, a **USB Audio Class 1** headset codec, and a **Genesys Logic microSD reader** that only enumerates when a card is inserted.

| Piece | USB ID | Strings | Speed | Driver |
|-------|--------|---------|-------|--------|
| Upstream hub | `1a86:8095` | Product `USB Hub` (no manufacturer/serial) | HS 480 Mbps | `hub` |
| Downstream hub | `1a86:8095` | same, `bcdDevice` **13.10** | HS 480 Mbps | `hub` |
| 3.5 mm audio | `001f:0b21` | Mfr `Generic`, product **`CS202`**, serial **`20210726905926`** | FS 12 Mbps | `snd-usb-audio` + `usbhid` |
| microSD reader | `05e3:0751` | Mfr/product `USB Storage`; `usb.ids`: **Genesys Logic microSD Card Reader**; `bcdDevice` **14.04** | HS 480 Mbps | `usb-storage` (BOT SCSI) |

`usb.ids` names `001f:0b21` **Walmart AB13X Headset Adapter**. PipeWire shows the same name. ALSA card id is **`CS202`**.

`1a86:8095` is **not** in the local `usb.ids`. WCH’s related 4-port USB 2 hub is `1a86:8091` (CH334). Treat `8095` as the same family (4-port USB 2 hub, Single TT), not as a USB 3 / dual-host CH9339 dock — those would enumerate SuperSpeed devices.

Both hubs advertise **self-powered** (`bmAttributes 0xe0`) and **4 downstream ports** (`maxchild=4`). The audio function is **bus-powered**, 100 mA.

---

## Topology on this capture

The dock was **not** on a native USB 3 port. It was hanging off the existing **NEC 7-port USB 2 hub** that already carries the Dell keyboard, wireless mouse, and C-Media dongle.

```text
xhci 0000:00:14.0
  Bus 001 (USB 2.0 HS)  Port 14
    NEC 7-port hub  0409:0050          ← existing lab hub
      Port 2  C-Media USB Audio        0d8c:0012
      Port 3  WCH hub                  1a86:8095     ← this dock
                Port 4  WCH hub        1a86:8095
                          Port 1  Genesys microSD  05e3:0751  (only with card in)
                          Port 2  CS202 / AB13X    001f:0b21
      Port 4  Dell Keyboard SK-8115    413c:2003
      Port 6  2.4G Wireless Mouse      3938:1191
  Bus 002 (USB 3.0 SS)  6 ports        ← empty in this capture
```

Sysfs path for the codec (this plug):

`usb-0000:00:14.0-14.3.4.2`  
`/sys/bus/usb/devices/1-14.3.4.2`

Kernel also logged: `usb 1-14.3.4.2: not running at top speed; connect to a high speed hub` — the codec is full-speed on a high-speed hub, which is normal for this class of 3.5 mm dongle.

---

## Audio (works without extra drivers)

| Item | Value |
|------|--------|
| ALSA card | `CS202` (was `hw:5` on this boot) |
| USB Audio | Class **1.0**, `snd-usb-audio` |
| Playback | S16_LE stereo, **8 kHz and 48 kHz**, headphones terminal |
| Capture | S16_LE stereo advertised; mixer is **mono Mic**; **48 kHz only** |
| Mixer | `PCM Playback Volume/Switch`, `Mic Capture Volume/Switch` |
| PipeWire | `alsa_card.usb-Generic_CS202_20210726905926-00` |
| Description | **AB13X Headset Adapter** Analog Stereo |
| HID | Consumer Control: next/prev, play/pause, mute, stop, volume ±, plus telephony mute (`hidraw`) |

Kernel warnings on attach (codec reports bogus volume resolution):

```text
Warning! Unlikely big volume range (=11520), cval->res is probably wrong.
[2] FU [PCM Playback Volume] ch = 2, val = -11520/0/1
Warning! Unlikely big volume range (=8191), cval->res is probably wrong.
[5] FU [Mic Capture Volume] ch = 1, val = 0/8191/1
```

Use ALSA/PipeWire volume, not the raw USB feature-unit steps. This is a **headset / 3.5 mm TRRS** codec, not a studio interface.

Select it:

```bash
cat /proc/asound/cards          # look for CS202
wpctl status                    # "AB13X Headset Adapter"
pactl list short cards | grep -i CS202
```

---

## Card reader (enumerates only with media)

Empty slots do **not** show a USB device. With a card inserted (2026-09-04 16:41:26):

| Item | Value |
|------|--------|
| USB | `05e3:0751` Genesys Logic microSD Card Reader |
| Strings | Manufacturer/product `USB Storage` (no serial) |
| Class | Mass Storage, SCSI, Bulk-Only (`08:06:50`) |
| Driver | `usb-storage` (not `uas`); `usb-storage`/`uas` modules loaded on first insert this boot |
| Power | Bus-powered, 98 mA |
| SCSI | `Generic STORAGE DEVICE` rev `1404` |
| by-id | `/dev/disk/by-id/usb-Generic_STORAGE_DEVICE-0:0` |
| Sysfs | `/sys/bus/usb/devices/1-14.3.4.1` |

GNOME auto-mounted the partition. **`sdd` is not a stable name** — use `by-id` or the filesystem UUID.

### Media in the slot this capture

PortaPack / HackRF Mayhem card (not part of the dock hardware):

| Item | Value |
|------|--------|
| Size | 7.90 GB (15431680 × 512-byte sectors; ~7.4 GiB) |
| Partition | DOS, type `0x0c` FAT32 LBA, UUID `3aef0ad2` |
| Filesystem | FAT32 label **`HackRF`**, UUID **`300C-16B0`** |
| Mount | `/run/media/user/HackRF` (udisks) |
| Contents | Mayhem dirs: `APPS`, `FIRMWARE`, `SAMPLES`, `SUBGHZ`, … |

Kernel on mount:

```text
FAT-fs (sdd1): Volume was not properly unmounted. Some data may be corrupt. Please run fsck.
```

About 4 seconds later the reader dropped (`device offline error, dev sdd, sector 2049` WRITE) and re-enumerated. That write was likely FAT dirty-flag / automount metadata on the USB 2 daisy-chain. Card came back and stayed mounted; still **run `fsck.vfat` before trusting it in a PortaPack**, and prefer a native USB 3 host port for writes.

Only **one** mass-storage function appeared. If the dock has both SD and microSD, they likely share this Genesys chip (typical for `05e3:0751`).

```bash
lsusb -d 05e3:0751
lsblk -o NAME,TRAN,SIZE,MODEL,LABEL,UUID,MOUNTPOINT /dev/disk/by-id/usb-Generic_STORAGE_DEVICE-0:0
```

---

## Stability on this plug

Kernel log on 2026-09-04 (first seen **13:47:31**): the WCH tree **disconnected and re-enumerated four times** (13:47, 14:29, 15:14, 16:31) before staying as devices 20/21/22.

That is consistent with **power or contact trouble on a USB 2 daisy-chain**, not with a driver bug. Hubs are on `power/control=auto`. Prefer:

- Direct host port (USB 3 if the dock has a SuperSpeed plug).
- The dock’s own PSU if it has a barrel / USB-C PD inlet (hubs claim self-powered).
- Do not hang this dock off the NEC 7-port hub that already feeds keyboard/mouse/C-Media.

---

## Lab use

| Host | Notes |
|------|--------|
| **Tower5810** | Captured here. Move off the NEC hub onto a native xHCI port. |
| **Thumper** (T5610) | Same class of USB 2/3 rear I/O. Do not run `bin/apply-amdgpu` there; otherwise this dock is just another USB gadget. |
| Other IndianaDell machines | Identify by `1a86:8095` + `001f:0b21` / serial `20210726905926` + reader `05e3:0751` when a card is in. |

This is **not** the JMicron 2-bay SATA duplicator. Do not apply `usbcore.quirks=152d:2352:g` or `bin/99-usb-dock.rules` to these IDs unless you deliberately write a new rule.

Optional later: a udev rule matching `001f:0b21` / `1a86:8095` to pin `power/control=on` if autosuspend starts dropping the codec.

---

## Re-identify commands

```bash
lsusb -d 1a86:8095
lsusb -d 001f:0b21
lsusb -d 05e3:0751
lsusb -t
cat /proc/asound/cards
# codec serial
cat /sys/bus/usb/devices/*/serial 2>/dev/null | grep 20210726905926
```

*Documented 2026-09-04 from a live Tower5810 scan. Retail name unknown; IDs and serial are the stable handle.*
