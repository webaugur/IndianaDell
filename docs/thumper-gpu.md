# Thumper GPU notes (lab host)

**Host:** `thumper.local` (`user@thumper.local`, 10.0.0.30)  
**Chassis:** Dell Precision **T5610** (X79-era workstation)  
**Primary role:** always-on lab box — DragonSDR backups, GPU inference (e.g. LingBot-Map), bulk `~/Data` ZFS pool  
**Related:** `~/Documents/DragonSDR/tools/lingbot-map/README.md` (CUDA app install/serve)  
**Storage / ZFS / boot reconstruction:** **`docs/thumper-storage.md`**  
**Full hardware inventory:** **`docs/thumper-inventory.md`** (2026-07-23: dual GPU AMD 6350 + TITAN Xp, ~4 TB dual-HDD data)

This page is the **lab-host companion** to Tower5810 Chapter 6 (AMD FirePro multi-GPU). Thumper is **NVIDIA**, not covered by `bin/apply-amdgpu`.

---

## Current GPU inventory (as of 2026-07-17)

| Index | Device | VRAM | Notes |
|-------|--------|------|--------|
| **0** | NVIDIA **TITAN Xp** (GP102) | **12 GB** | Good air cooler; primary compute + display |
| — | (optional second TITAN Xp) | 12 GB | Identical SKU; **heatsink inadequate** (was water-cooled, converted back poorly) — only add if power-capped |

```bash
ssh user@thumper.local 'nvidia-smi -L; nvidia-smi --query-gpu=index,name,memory.total,temperature.gpu,power.limit --format=csv'
```

**Driver (snapshot):** 535.146.02 — reports max CUDA **12.2**.  
**Do not** expect official upstream stacks that need **CUDA 12.8** wheels without a driver upgrade. Prefer **torch cu121** (or older) for TITAN Xp / driver 535.

### Thermal limits (TITAN Xp, from `nvidia-smi -q`)

| Limit | Value |
|-------|--------|
| Target temperature | **84 °C** |
| HW thermal slowdown | **96 °C** |
| Shutdown | **99 °C** |
| Default power limit | **250 W** |
| Min / max power limit | **125 W** / **300 W** |

Built-in thermal throttling only kicks hard near the top of that range. A weak cooler should be **power- and clock-capped** long before 96 °C.

---

## Would a second card help?

| Workload | Second card useful? |
|----------|---------------------|
| Single large model (e.g. LingBot-Map one process) | **No** — one job sticks to one GPU; 12 GB is per-device |
| Two concurrent CUDA jobs | **Yes** — pin with `CUDA_VISIBLE_DEVICES` |
| Display + separate compute | **Maybe** — keep UI on GPU0, jobs on GPU1 |

**PSU / slot:** two TITAN Xps at stock ≈ 2×250 W class. Confirm free PCIe slot and PSU headroom on the T5610 before installing. Prefer **≥1000–1200 W** quality supply and case airflow.

**Policy if second card is installed:**

- Treat **GPU 0** (good cooler) as default heavy compute (`CUDA_VISIBLE_DEVICES=0`).
- Treat **GPU 1** (weak cooler) as light/secondary only; apply **power + clock locks** below at boot.

---

## Locking / throttling NVIDIA GPUs

There is no simple “never exceed 70 °C” user knob on the proprietary driver. Practical controls:

1. **Power limit** (`-pl`) — best heat reduction  
2. **Locked graphics clocks** (`-lgc`) — hard ceiling  
3. **Locked memory clocks** (`-lmc`) — optional  
4. Built-in SW/HW thermal slowdown — safety net only  

All of these need **root** once (or a root systemd unit). Settings **reset on reboot** unless persisted.

### One-shot commands (after second card is present)

```bash
# On thumper — GPU 1 = weak cooler example
sudo nvidia-smi -i 1 -pl 125              # min allowed on Xp; stock is 250
sudo nvidia-smi -i 1 -lgc 500,1200        # graphics MHz min,max
# optional:
# sudo nvidia-smi -i 1 -lmc 405,4004

# Verify
nvidia-smi -q -i 1 -d POWER,CLOCK,TEMPERATURE | less
nvidia-smi -i 1 --query-gpu=power.limit,clocks.sm,temperature.gpu --format=csv
```

### Reset to defaults

```bash
sudo nvidia-smi -i 1 -pl 250
sudo nvidia-smi -i 1 -rgc    # reset GPU clocks
sudo nvidia-smi -i 1 -rmc    # reset memory clocks
```

### Pin jobs to a card

```bash
CUDA_VISIBLE_DEVICES=0  ./tools/lingbot-map/serve.sh     # good card
CUDA_VISIBLE_DEVICES=1  some_lighter_cuda_job            # weak card only
```

### Persist at boot (recommended when dual-GPU is live)

Create a systemd unit on **thumper** (not checked into Tower5810 `etc/` yet — host-specific):

```ini
# /etc/systemd/system/thumper-gpu-throttle.service
[Unit]
Description=Throttle poorly cooled NVIDIA GPU(s) on Thumper
After=nvidia-persistenced.service multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes
# Adjust index if enumeration differs after dual install
ExecStart=/usr/bin/nvidia-smi -i 1 -pl 125
ExecStart=/usr/bin/nvidia-smi -i 1 -lgc 500,1200

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now thumper-gpu-throttle.service
systemctl status thumper-gpu-throttle.service
```

If only **one** card is installed, **do not** enable this unit against index 1 (it will fail or hit the wrong device). Revisit after dual-GPU install and confirm `nvidia-smi -L` order.

### Monitoring

```bash
watch -n2 'nvidia-smi --query-gpu=index,name,temperature.gpu,power.draw,power.limit,utilization.gpu,memory.used --format=csv'
# thermal events:
nvidia-smi -q -d PERFORMANCE | grep -A20 'Clocks Event Reasons'
```

If a weak card still hits **~90 °C+** at **125 W**, stop using it until the cooler is fixed.

---

## LingBot-Map (DragonSDR) on Thumper

Streaming 3D reconstruction demo — **not** part of IndianaDell rebuild.

| Path | Role |
|------|------|
| `~/Documents/DragonSDR/Robbyant/lingbot-map/` | Source clone |
| `~/Data/lingbot-map/` | venv, models (~4.4 GB), `inputs/`, `outputs/`, `lingbot-map.env` |
| `~/Documents/DragonSDR/tools/lingbot-map/` | `install.sh`, `serve.sh`, user systemd unit |

```bash
# install / update (on thumper)
cd ~/Documents/DragonSDR
./tools/lingbot-map/install.sh --download-model long

# interactive viser viewer (default port 8080)
./tools/lingbot-map/serve.sh
# http://thumper.local:8080
```

**Upload media:** no browser upload. Copy into `~/Data/lingbot-map/inputs/` then:

```bash
./tools/lingbot-map/serve.sh --video_path ~/Data/lingbot-map/inputs/my.mp4 --fps 5 --first_k 60
# or: --image_folder ~/Data/lingbot-map/inputs/frames --mask_sky
```

VRAM tips for 12 GB TITAN Xp are in `lingbot-map.env` / DragonSDR `tools/lingbot-map/README.md` (`--use_sdpa`, `--offload_to_cpu`, etc.).

---

## Relation to Tower5810 (B1GMB42)

| Host | GPU stack | IndianaDell tooling |
|------|-----------|---------------------|
| **Tower5810** | 3× AMD FirePro (W5000/W5100) | `bin/apply-amdgpu`, `bin/gpu-stress`, Chapter 6 |
| **Thumper** | 1–2× NVIDIA TITAN Xp | This doc; `nvidia-smi` power/clock locks; DragonSDR lingbot-map |

Do **not** run `apply-amdgpu` on Thumper. Do **not** expect ROCm ML on either host’s current GPUs for modern stacks without checking Chapter 14 (Tower) / CUDA capability (Thumper sm_61).

---

## Agent / follow-up checklist

When installing the second TITAN Xp or changing cooling:

1. Confirm `nvidia-smi -L` indices and which physical card is weak.  
2. Install `thumper-gpu-throttle.service` (or equivalent) for the weak index only.  
3. Smoke-test heat under load with `watch nvidia-smi` for 10+ minutes.  
4. Keep LingBot-Map and other heavy jobs on the good card via `CUDA_VISIBLE_DEVICES`.  
5. Update this file’s inventory table with the new dual-GPU state.

*Captured 2026-07-17 during DragonSDR LingBot-Map bring-up on thumper.local.*
