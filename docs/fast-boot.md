# Fast boot — Tower5810 (B1GMB42)

Goal: keep the **Plymouth splash**, reach the **desktop sooner**, defer lab/daemons until after login.

## Apply / undo

```bash
sudo bin/apply-fast-boot          # install all speedups
sudo bin/apply-fast-boot --status # cmdline, deferred units, analyze
sudo bin/apply-fast-boot --undo   # best-effort restore
```

Also used for login speed (separate):

```bash
sudo bin/apply-fast-login   # GRUB menu timeout 0, GDM autologin, wizard face
```

After changes, **reboot** and compare:

```bash
systemd-analyze
systemd-analyze blame | head -25
systemd-analyze critical-chain
```

---

## What the script changes

| Change | Effect |
|--------|--------|
| Strip `crashkernel=` from GRUB | Frees reserved RAM; slightly less boot work. **Splash kept** (`quiet splash`). |
| Mask `NetworkManager-wait-online` | ~several seconds; desktop no longer waits for “network online”. |
| Disable `kdump-tools` | Matches no-crashkernel policy. |
| Socket-lazy: docker, cups, snapd, libvirt | Daemon starts on first use (socket still enabled). |
| Defer long list after `graphical.target` | VMs, snaps, modem, printers, lighttpd, bluetooth, cloud-init, etc. start **after** the desktop path. |

Lists (edit to taste, then re-run `apply-fast-boot`):

- `etc/indianadell-deferred.list` → `/etc/indianadell-deferred.list`
- `etc/indianadell-socket-lazy.list` → `/etc/indianadell-socket-lazy.list`

---

## BIOS / firmware (Dell Precision T5810) — manual

Firmware alone was ~**36s** of a ~96s cold boot. Ubuntu cannot fix POST. In **F2 Setup** (values vary by BIOS A34):

### High impact

1. **Fast Boot / Quick Boot** — enable if present (skips some device tests).
2. **Boot mode** — leave **UEFI**; avoid legacy option ROMs you do not need.
3. **Unused SATA / disks** — disable ports for empty or rarely used drives (spin-up of a Hitachi HDD was ~11s of device settle on this host).
4. **PXE / Network Boot** — disable on NICs you never boot from (saves enumeration and “press key” style delays).
5. **USB boot support** — disable if you never boot USB from firmware (or limit to “boot menu only”).

### Medium impact

6. **Serial / parallel / legacy I/O** — disable if unused.
7. **Thunderbolt / add-in card wait** — if a security “wait for devices” or pre-boot optROM delay exists, reduce or disable for cards you do not boot from.
8. **Memory testing** — full memory test on every POST: off / reduced if there is a toggle.
9. **Numlock / keyboard errors** — “Halt on all errors” → **Open** or **No errors** so a flaky KB does not pause POST.
10. **Virtualization** — leave **VT-x/VT-d** on if you use KVM/libvirt (no POST win; do not disable for speed if you need VMs).

### Optional / situational

11. **Multi-display / primary GPU** — set primary to the GPU that drives your main monitor so firmware and GDM do not hunt outputs as long.
12. **Secure Boot** — leaving it as-is is fine; toggling rarely saves material time on this platform.
13. **RAID / AHCI** — keep the mode your install expects (AHCI/ZFS). Do not switch modes for speed.

### After BIOS changes

Save & exit, cold boot once, then:

```bash
systemd-analyze
# firmware time is the first number:
# Startup finished in X (firmware) + …
```

---

## What stays early (do not defer)

These remain on the normal boot path so the desktop still works:

- `gdm`, `accounts-daemon`, `NetworkManager` (without wait-online)
- `dbus`, `systemd-logind`, `polkit`, `udisks2`, `upower`
- ZFS import/mount units, `udev`, `apparmor`
- `gpu-manager`, `switcheroo-control` (multi-GPU)
- `power-profiles-daemon`, `wpa_supplicant` (if you use Wi‑Fi at login)

---

## Trade-offs

| Defer / lazy | First-use cost |
|--------------|----------------|
| Docker | First `docker` command starts engine (~seconds) |
| Snap | First snap app may wait on `snapd` |
| CUPS | First print may start cupsd |
| libvirt | First `virsh`/virt-manager starts daemon |
| Bluetooth | Adapters appear a few seconds after login |

If something must always be up immediately after login (e.g. always-on containers), remove it from `indianadell-deferred.list`, run `sudo systemctl enable --now NAME`, and re-run `apply-fast-boot` only if you change lists.

---

## Related

- Plymouth theme: `bin/themes-install-boot --animated-dell`
- Preview splash safely: `bin/themes-preview-boot`
- Autologin + face: `bin/apply-fast-login`
