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

## Lab AI assistant / Home Assistant

Thumper as **McFloater master node** (voice, HA, KMC/Tuya plugs, later video call):

→ **`~/Documents/McFloater/docs/thumper-master-node.md`** and `deploy/thumper/`

Not IndianaDell rebuild scope; not DragonSDR.
