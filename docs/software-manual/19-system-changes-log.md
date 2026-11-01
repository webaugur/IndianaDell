# Chapter 19 — System changes log

One entry per change, newest first. Scripts live in `scripts/system/` (and `scripts/storage/`). They need root, so David runs them with `sudo`; the status line records whether the result has been checked.

## 2026-11-01 — `scripts/system/make-freedos-flash-stick.sh` (Safar, any Ubuntu)

- **Machine:** run on Safar (Ubuntu 22.04) to build a USB stick for flashing the E6410 BIOS. Works on any machine with the tools below.
- **What it does:** checks the target is a whole, removable USB disk under 128 GB that holds no mounted system filesystem, shows model and size, and asks you to type the device name. It then wipes the stick and writes an MBR with one active FAT32 partition labelled `FLASH`, plus the syslinux `mbr.bin`. Boot runs syslinux → `chain.c32 freedos=KERNEL.SYS` → FreeDOS 1.4. Files come from the FreeDOS ISO: `KERNEL.SYS`, `COMMAND.COM`, and `EDIT.EXE` and `EDIT.HLP` in `C:\FDOS\BIN`. The script writes `FDCONFIG.SYS` and an `AUTOEXEC.BAT` that sets `PATH=C:\;C:\FDOS\BIN` and lists the steps. Each BIOS .exe is copied under an 8.3 name (`E6410Ann.EXE`) and gets its own `FLASHn.BAT`, numbered in ascending revision order so A11 comes first. Each batch file says what it will do and pauses before it runs the .exe. Everything is written with mtools and the stick is never mounted. Re-running rebuilds the stick from scratch.
- **Needs:** `parted dosfstools syslinux syslinux-common mtools p7zip-full fdisk` (all present on Safar). The FreeDOS ISO must be on the machine running the script. Set `FREEDOS_ISO`, or the script uses `/run/media/user/Wiggly/FreeDOS_14.iso`, then `~/Grok_Automation/FreeDOS_14.iso`. A copy is at `~/Grok_Automation/FreeDOS_14.iso` on Safar.
- **Run:** `sudo bash ~/Documents/IndianaDell/scripts/system/make-freedos-flash-stick.sh /dev/sdX ~/Downloads/e6410/E6410A11.exe ~/Downloads/e6410/Latitude_E6410_E6410ATG_A17.exe`. If DataStore1 is locked, use `~/Grok_Automation/make-freedos-flash-stick.sh` instead. Then boot the E6410 with F12 → USB Storage Device, and run `FLASH1`, reboot, then `FLASH2`.
- **Test without root:** `bash make-freedos-flash-stick.sh --image test.img <bios files>` builds a 256 MiB disk image. Booted in qemu on Safar, it reached the FreeDOS prompt with the menu, `PATH` was correct, and `EDIT` opened.
- **Undo:** reformat the stick (for example with GNOME Disks). The script changes nothing on the host.
- **Status:** written, not yet run on a real stick. The image boot was tested in qemu only.

## 2026-11-01 — `scripts/system/remove-snapd.sh` (Tower5810)

- **Machine:** Tower5810 (Ubuntu 26.04). Safar (Ubuntu 22.04) has no snapd at all, so it does not need this.
- **Before:** snapd 2.76 with snaps `firefox`, `firmware-updater`, `snap-store`, `snapd-desktop-integration`, `prompting-client`, `desktop-security-center`, plus runtimes `core24`, `gnome-46-2404`, `mesa-2404`, `gtk-common-themes`, `bare`, `snapd` (~1.5 GB in `/var/lib/snapd`). `snap list` was broken ("cannot find publisher details: snap-declaration").
- **What it changes:** stops first if purging snapd would remove `ubuntu-desktop`, `gdm3`, `gnome-shell` or `ubuntu-standard`. Installs the `fwupd` and `gnome-software` debs as replacements, pins snapd (`/etc/apt/preferences.d/no-snapd`) and Ubuntu's Firefox stub (`/etc/apt/preferences.d/no-firefox-stub`) out of apt, removes the Firefox snap, purges `firefox`, `snapd` and the snap plugins, runs `autoremove`, then lists leftover snap folders. It deletes no folders: `~/snap` (171 MB Firefox profile) is left for David to delete.
- **Why:** David dislikes snap and Firefox; Chrome is the browser.
- **Run:** close Firefox, then `sudo bash ~/Documents/IndianaDell/scripts/system/remove-snapd.sh`
- **Undo:** `sudo rm /etc/apt/preferences.d/no-snapd /etc/apt/preferences.d/no-firefox-stub && sudo apt install snapd`, then reinstall snaps as wanted.
- **Status:** written, run by David with sudo, not yet verified.

## 2026-11-01 — `scripts/system/setup-installer-group.sh` (machine with DataStore1, Safar)

- **What it changes:** creates system group `installer` with David's user and `_apt` as members; creates `/media/<user>/DataStore1/installers` owned `root:installer`, mode `2775` (group-writable, setgid); adds ACL `g:installer:x` on `/media/<user>` and the DataStore1 mount point (installs `acl` if missing).
- **Why:** so `apt install ./file.deb` from that folder stops warning "Download is performed unsandboxed as root as file ... couldn't be accessed by user '_apt'".
- **Run:** with DataStore1 mounted, `sudo bash ~/Documents/IndianaDell/scripts/system/setup-installer-group.sh`, then log out and in.
- **Undo:** `sudo setfacl -x g:installer /media/$USER /media/$USER/DataStore1; sudo gpasswd -d $USER installer; sudo gpasswd -d _apt installer; sudo groupdel installer` (the `installers` folder can stay).
- **Status:** written, run by David with sudo, not yet verified.

## 2026-11-01 — `scripts/system/chrome-no-ai.sh` (Safar and Tower5810)

- **What it changes:** writes Chrome managed policy `/etc/opt/chrome/policies/managed/indianadell-no-ai.json` with `GenAiDefaultSettings=2` (disable covered AI features), `AIModeSettings=1` (block AI Mode; only 0 and 1 are valid, 2 is rejected), `GeminiSettings=1` (disable Gemini). "Ask Google about this page" is deliberately left on (it requires David to ask).
- **Why:** David does not want Chrome's generative-AI features.
- **Run:** `sudo bash ~/Documents/IndianaDell/scripts/system/chrome-no-ai.sh`, fully quit Chrome, reopen, check `chrome://policy`. Chrome then shows "Managed by your organization" — expected.
- **Undo:** `sudo rm /etc/opt/chrome/policies/managed/indianadell-no-ai.json` and restart Chrome.
- **Status:** written, run by David with sudo, not yet verified.

## 2026-11-01 — Safar hardware and setup facts (no script)

- **Machine:** Dell Latitude E6410, service tag **836M0M1** (from `~/dmi.txt`, 2023; confirm on the sticker).
- **BIOS:** A09 (2011). Planned upgrade to **A17** with `~/Downloads/e6410/Latitude_E6410_E6410ATG_A17.exe`: copy it to a FAT32 USB stick, AC adapter in, F12 at boot, "BIOS Flash Update". Do not extract the .exe. `~/Documents/dell-flash-unlock` is cloned but not needed for this, and not built or run.
- **RAM:** maxed at 2×4 GB DDR3 (Dell service manual: 1/2/4 GB SODIMMs, max 8 GB). No 16 GB upgrade.
- **GPU:** NVIDIA NVS 3100M (GT218) on proprietary `nvidia-340` 340.108 from a PPA, X11 only. **Warning:** `nouveau` may freeze on this chip, and the 340 driver is not expected to build on Ubuntu 26.04, so **26.04 is not recommended on Safar**; stay on 22.04.
- **gpu-manager:** masked by hand with `sudo systemctl mask gpu-manager.service` (undo: `sudo systemctl unmask gpu-manager.service`). Also added to `bin/apply-tuning` as the `gpu-manager` step (single-GPU machines only; see Chapter 18).
- **Chrome AI policy:** `chrome-no-ai.sh` above.
- **TimeWarp:** 1.5.0 installed with `uv tool install --python 3.12 --editable ~/Documents/TimeWarp` into `~/.local` (Safar has Python 3.10; uv fetched 3.12 under home). A daily routine (~10:00 Eastern) syncs Safar's TimeWarp to Tower5810's commit.
- **Documents:** project folders rsynced from Tower5810 via `10.0.0.113`. Safar → Tower5810 SSH works; Tower5810 → Safar failed host-key verification, so copies are pulled from Safar.
- **`~/Grok_Automation`:** created on Safar for agent worktrees and builds.
