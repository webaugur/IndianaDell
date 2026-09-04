# Agent instructions (IndianaDell)

## Pull requests

- **Do not open, create, or draft GitHub pull requests** unless the user **explicitly** asks.
- Prefer branch push + status summary over PR creation by default.

## Lab hosts (read these when GPU / Thumper comes up)

| Host | Role | Doc |
|------|------|-----|
| **Tower5810** (this workspace default) | AMD FirePro ×3, rebuild-machine, themes | `docs/software-manual/06-gpu-and-display.md` |
| **Thumper** (`user@thumper.local`) | NVIDIA TITAN Xp, DragonSDR backup target, GPU inference | **`docs/thumper-gpu.md`** |
| **Thumper storage / ZFS / boot** | Disk IDs, pool GUIDs, GPT reconstruction | **`docs/thumper-storage.md`** |
| **Thumper hardware inventory** | CPU/RAM/GPU/disks after 26.04 reinstall | **`docs/thumper-inventory.md`** |

### Thumper GPU — do not forget

- Dual TITAN Xp: second card may have **inadequate air cooler** (bad water→air conversion).
- **Throttle** weak card: `nvidia-smi -i <N> -pl 125` and `-lgc 500,1200`; persist with systemd oneshot (examples in `docs/thumper-gpu.md`).
- Heavy CUDA (e.g. LingBot-Map): pin to good card with `CUDA_VISIBLE_DEVICES=0`.
- Install/serve LingBot-Map: `~/Documents/DragonSDR/tools/lingbot-map/` + `~/Data/lingbot-map/` on Thumper — not IndianaDell rebuild.
- Do **not** run `bin/apply-amdgpu` on Thumper.

When the user asks about second GPU, temperature throttling, or Thumper CUDA, **read `docs/thumper-gpu.md` first**.

## New scripts in bin/

After adding or modifying executable scripts under `bin/`:

- Run `bin/install-to-bin`
  (creates symlinks in `~/bin/` so the new commands are available in `$PATH` without typing the full path).

This step is required for any new command (e.g. `wssh`, `xeyes-thumper`, etc.) to be directly invocable from the shell.

## Desktop launchers in ~/Applications (DragonSDR / suite apps)

After creating or modifying any `.desktop` files under `~/Applications/` (Renode, Velxio, Ghidra, OpenWebRX, SDR++, etc.):

1. Run `scripts/gnome/fix-nautilus-desktop-launch.sh`
   (restores double-click execution via the xdg-desktop-launch MIME handler for Nautilus 50+).
2. Run `scripts/gnome/sync-desktop-icons.sh --dir ~/Applications`
   (sets `metadata::custom-icon` from each file’s `Icon=` line so Nautilus actually displays the branded icon).

Both scripts are required; the launcher fix alone does not update icon metadata. The icon sync script is the companion to the launcher fix.

## QEMU-lcgamboa shared-library builder — cost of regressions (2026-07-25)

**DragonSDR requirement (non-negotiable):**  
`tools/emulators/qemu-lcgamboa/build-all.sh` must produce `libqemu-<arch>.so` for **every** architecture in `targets.txt`. The `lcgamboa/picsimlab-esp32` script is only mandatory for the two ESP targets (Velxio compatibility). All other arches must also ship as shared libraries in the same build.

**Observed pattern:**  
The implementation repeatedly regressed to plain `qemu-system-<arch>` executables or deferred the shared-library work. This directly violated the explicit requirement.

**Business impact:**  
These regressions have consumed nearly a quarter of the user’s week and caused real monetary loss. Any future session touching the QEMU builder must treat the full shared-library requirement as binding and must not weaken, defer, or reinterpret it when facing implementation difficulty.

## Lab AI assistant / Home Assistant

Thumper as **McFloater master node** (voice, HA, KMC/Tuya plugs, later video call):

→ **`~/Documents/McFloater/docs/thumper-master-node.md`** and `deploy/thumper/`

Not IndianaDell rebuild scope; not DragonSDR.
