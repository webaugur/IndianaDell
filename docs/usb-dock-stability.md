# USB-SATA Dock Stability (JMicron 152d:2352)

**Host:** Tower5810 (and any machine using the same cheap USB dock)  
**Dock chipset:** JMicron ATA/ATAPI Bridge (USB VID:PID `152d:2352`)  
**Interface:** USB 2.0 High Speed (480 Mbps) — **not USB 3**  
**Problem:** Dock frequently drops the SATA link during sustained or random I/O (testdisk, fio, long SMART tests, etc.).

> **Important:** Because this is a USB 2.0 HS dock, many USB 3–era stability tweaks have limited or no effect. The hardware itself is the primary bottleneck.

## Symptoms

- Disks (`sdd`, `sde`) disappear from `lsblk` or `dmesg` mid-operation.
- `testdisk` keyboard input stops responding (caused by piping the TUI through `tee`).
- SMART data unavailable unless the correct `-d` type is forced.
- Power management (autosuspend) on the USB device is the most actionable item.

## Root Causes (in order of likelihood for this USB 2.0 dock)

1. USB autosuspend / power management on the host (most effective fix applied).
2. Marginal power delivery through the USB cable or dock PSU.
3. Dock firmware bugs under sustained load (common on cheap JMicron USB 2.0 bridges).
4. Cable quality / length / EMI.
5. Host controller quirks (less relevant at USB 2.0 speeds).
6. `uas` vs `usb-storage` differences (largely irrelevant at 480 Mbps).

## Files Added to `bin/`

| Script / File | Purpose |
|---------------|---------|
| `usb-dock-power-state.sh` | Shows `power/control`, `power/autosuspend`, driver binding, and `max_sectors_kb` for the dock and its `sdX` devices. Works for both USB 2.0 and 3.x. |
| `smartctl-usb-dock.sh` | Tries `-d sat`, `-d scsi`, `-d usb`, and no `-d` flag until one returns valid SMART data. |
| `99-usb-dock.rules` | udev rule that disables autosuspend on the USB device and attempts to tune block devices behind this VID:PID. Review before installing. |
| `copyq.service` | User systemd service for CopyQ clipboard manager (required on GNOME Wayland because Mutter lacks the `data-control` protocol). |
| `disk-testdisk-scan.sh` | Updated with correct by-id examples and dock warning (no longer pipes the interactive program). |
| `disk-stress-test.sh` | Updated with correct by-id examples and dock warning. |

All scripts accept either the full `/dev/disk/by-id/...` path **or** just the serial number. They refuse to guess device names.

## Recommended udev Rule (copy after review)

```bash
sudo cp bin/99-usb-dock.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger
```

The rule does:

- `power/control = on` and `power/autosuspend = -1` on the USB device (verified working on this USB 2.0 dock).
- Attempts to match block devices via `ID_VENDOR_ID`/`ID_MODEL_ID` environment variables.
- (Commented) optional force of `usb-storage` driver instead of `uas`.

**Note:** On USB 2.0 docks the block-device portion of the rule may not fully match. The USB-device power settings are the most important part and **do** take effect.

## Quick Diagnostic Commands

```bash
# Check current power/driver state
~/bin/usb-dock-power-state.sh

# Test SMART (tries multiple device types)
~/bin/smartctl-usb-dock.sh -a /dev/sdd
~/bin/smartctl-usb-dock.sh -t long /dev/sdd

# Run the updated testdisk wrapper (keyboard now works)
./bin/disk-testdisk-scan.sh /dev/disk/by-id/usb-WDC_WD20_03FZEX-00Z4SA0_DCA2599981FF-0:0
```

## Decision Tree (adjusted for USB 2.0 reality)

1. Power-cycle dock + try different cable + different USB port → still disconnects?
2. Apply the udev rule (primarily for autosuspend disable) + reboot → still disconnects?
3. Add `usbcore.quirks=152d:2352:g` to GRUB (already done on Tower5810) → still disconnects?
4. Accept that this USB 2.0 dock is unsuitable for sustained random I/O or long testdisk runs. Move drives inside the machine or replace the enclosure with a USB 3.x or internal SATA solution.

## Notes on SMART Passthrough

Many JMicron bridges (USB 2.0 and 3.x) only expose SMART when `-d sat` or `-d scsi` is forced. Some firmware revisions simply do not implement it at all. The `smartctl-usb-dock.sh` wrapper automates trying the common working device types.

If the wrapper script fails on all attempts, the only reliable workaround is a real SATA connection or a better enclosure (ASM2358 / RTL9210 based with external PSU).

## Related Scripts (updated)

- `disk-testdisk-scan.sh` – now launches `testdisk` directly (no pipe) and prints the exact by-id paths the system reports.
- `disk-stress-test.sh` – same identifier handling + dock warning at the top.

## Applied Changes on Tower5810 (2026-07-24)

- GRUB: `usbcore.quirks=152d:2352:g` present in `/boot/grub/grub.cfg` (5 occurrences) via the IndianaDell override file.
- udev rule: `99-usb-dock.rules` installed; USB device `2-8` shows `power/control = on`, `power/autosuspend = -1`.
- **Clipboard fix**: 
  - `ARBOARD_BACKEND=wayland` added to `~/.bashrc` and to the top of all dock-related scripts.
  - Installed **CopyQ** clipboard manager with a user systemd service (`copyq.service`) because GNOME Wayland lacks the `data-control` protocol. This allows copies from Grok and other TUIs without requiring the terminal to stay focused.
- All scripts and documentation committed and pushed.

## eSATA Port on the Dock

The SSI/JMicron “2Bay Duplicator” dock exposes one **eSATA target (device) port**.

- It is **not** an eSATA host port.
- You connect the dock’s eSATA port **to a host PC’s eSATA port**.
- The internal SATA ports in the bays act as hosts to the drives.
- The dock also supports standalone/one-button offline cloning (source → destination) without a host PC.

### eSATA Availability on Lab Hosts

| Host | eSATA Ports | Notes |
|------|-------------|-------|
| **Tower5810** | None | Two Intel C610/X99 AHCI controllers (`00:11.4` sSATA + `00:1f.2` 6-port SATA) — internal SATA only. Rear I/O has no eSATA. |
| **Thumper (T5610)** | None | Single Intel C600/X79 6-port AHCI (`00:1f.2`) — internal SATA only. Rear I/O has no eSATA. |

**User note (2026-07-24):** Possible spare eSATA HBA card in storage. Topic deferred for later investigation.

Because neither primary lab host currently has an eSATA host port, the dock’s eSATA port cannot be used without adding an HBA or moving the drives internally.

## Future Improvements (optional)

- Add a “USB Dock Stability Checklist” one-pager.
- Create a companion `photorec` wrapper with the same stable identifier logic.
- Add the dock to `thumper-inventory.md` or `augury-lab-inventory.md` once it moves to the lab or after eSATA HBA testing.

*Document created 2026-07-24 during recovery of two 2 TB WD drives in a JMicron USB 2.0 dock on Tower5810. Updated same day to reflect USB 2.0 reality, applied system changes, and eSATA port analysis.*
