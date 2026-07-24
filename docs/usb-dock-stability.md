# USB-SATA Dock Stability (JMicron 152d:2352)

**Host:** Tower5810 (and any machine using the same cheap USB dock)  
**Dock chipset:** JMicron ATA/ATAPI Bridge (USB VID:PID `152d:2352`)  
**Problem:** Dock frequently drops the SATA link during sustained or random I/O (testdisk, fio, long SMART tests, etc.).

## Symptoms

- Disks (`sdd`, `sde`) disappear from `lsblk` or `dmesg` mid-operation.
- `testdisk` keyboard input stops responding (caused by piping the TUI through `tee`).
- SMART data unavailable unless the correct `-d` type is forced.
- Power management (autosuspend) or the `uas` driver are the usual culprits.

## Root Causes (in order of likelihood)

1. USB autosuspend / power management on the host.
2. Marginal power delivery through the USB cable or dock PSU.
3. `uas` (USB Attached SCSI) vs `usb-storage` driver instability on this JMicron part.
4. Cable quality / length / EMI.
5. Host controller quirks (ASMedia, older Intel).
6. Dock firmware bugs under sustained load.

## Files Added to `bin/`

| Script / File | Purpose |
|---------------|---------|
| `usb-dock-power-state.sh` | Shows `power/control`, `power/autosuspend`, driver binding (`uas` vs `usb-storage`), and `max_sectors_kb` for the dock and its `sdX` devices. |
| `smartctl-usb-dock.sh` | Tries `-d sat`, `-d scsi`, `-d usb`, and no `-d` flag until one returns valid SMART data. |
| `99-usb-dock.rules` | udev rule that disables autosuspend, raises queue depth, and optionally forces `usb-storage`. Review before installing. |
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

- `power/control = on` and `power/autosuspend = -1` on the USB device.
- Same settings on any `scsi_disk` that appears from this bridge.
- Raises `queue/max_sectors_kb` to 1024 on the resulting block devices.
- (Commented) optional force of `usb-storage` driver instead of `uas`.

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

## Decision Tree

1. Power-cycle dock + try different cable + different USB port → still disconnects?
2. Apply the udev rule + reboot → still disconnects?
3. Add `usbcore.quirks=152d:2352:g` to GRUB → still disconnects?
4. Blacklist `uas` for this VID:PID and force `usb-storage` → still disconnects?
5. If yes to all → this dock is unsuitable for sustained random I/O. Move drives inside the machine or replace the enclosure.

## Notes on SMART Passthrough

Many JMicron USB 3 bridges only expose SMART when `-d sat` or `-d scsi` is forced. Some firmware revisions simply do not implement it at all. If the wrapper script fails on all attempts, the only reliable workaround is a real SATA connection or a better enclosure (ASM2358 / RTL9210 based with external PSU).

## Related Scripts (updated)

- `disk-testdisk-scan.sh` – now launches `testdisk` directly (no pipe) and prints the exact by-id paths the system reports.
- `disk-stress-test.sh` – same identifier handling + dock warning at the top.

## Future Improvements (optional)

- Add a “USB Dock Stability Checklist” one-pager.
- Create a companion `photorec` wrapper with the same stable identifier logic.
- Add the dock to `thumper-inventory.md` or `augury-lab-inventory.md` once it moves to the lab.

*Document created 2026-07-24 during recovery of two 2 TB WD drives in a JMicron USB dock on Tower5810.*
