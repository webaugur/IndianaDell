# Chapter 6 — GPU and Display

## What gets installed

| Component | Source | Purpose |
|-----------|--------|---------|
| `vulkan-tools`, `mesa-utils`, `clinfo` | apt (APT_CORE) | Vulkan/OpenGL/OpenCL diagnostics |
| `etc/` multi-GPU configs | workspace | Wayland, X11, udev, GDM tweaks |
| `amd-radeon/` scripts | workspace | Optional ROCm driver install |
| `bin/gpu-stress` | workspace | 3-GPU Vulkan smoke test |

**Hardware (this machine):** 2x AMD FirePro W5000 + 1x FirePro W5100. Vulkan and OpenCL work for graphics/compute smoke tests. **ROCm ML/HIP is not supported** on these cards (see Chapter 14).

## How it is installed

**Apt (automated):** GPU utility packages install during rebuild Phase 2.

**Session configs (manual):**

```bash
sudo bin/apply-amdgpu    # runs etc/apply.sh
sudo reboot
```

`etc/apply.sh` installs:

- `etc/environment.d/99-amdgpu-wayland.conf`
- `etc/X11/xorg.conf.d/20-amdgpu-multi-gpu.conf`
- `etc/modprobe.d/amdgpu-multigpu.conf` (`runpm=0`)
- `etc/udev/rules.d/99-amdgpu-multigpu.rules` (tags + DPM auto hook)
- `etc/amdgpu-set-dpm-auto.sh` → `/usr/local/sbin/indiana-amdgpu-dpm-auto`
- `etc/profile.d/amdgpu-multigpu.sh`
- `etc/gdm3/custom.conf` (if present)

**DPM auto (all cards):** every amdgpu uses load-based clocks (`auto` / `balanced`). These FirePro W5000/W5100 overheat when pinned to `high`. `apply-amdgpu` runs the helper immediately; udev re-applies when cards appear at boot.

```bash
# verify
for c in /sys/class/drm/card[0-9]/device; do
  [[ -f $c/power_dpm_force_performance_level ]] || continue
  echo "$(basename $(dirname $c)): level=$(cat $c/power_dpm_force_performance_level) state=$(cat $c/power_dpm_state)"
done
# expect: level=auto  state=balanced  on card1..card3
```

Do not set `high` on this machine. To force clocks only for a short smoke test: `echo high | sudo tee …/power_dpm_force_performance_level`, then `echo auto` when done.

**Optional ROCm:**

```bash
bin/amd-preflight        # check prerequisites
bin/amd-install          # full driver stack from amd-radeon/
bin/amd-verify
bin/amd-uninstall        # remove if needed
```

## How to verify

```bash
vkcube                   # Vulkan cube (per display)
clinfo | head -30        # OpenCL platforms/devices
glxinfo -B               # OpenGL renderer
bin/gpu-stress 60 vkcube # stress all GPUs ~60s
lspci -nn | grep -i vga
```

## How to customize

- Edit files under `etc/` before re-running `sudo bin/apply-amdgpu`
- ROCm install scripts and README in `amd-radeon/` — machine-specific; read preflight output
- Hardware details: `B1GMB42-slot-port-inventory.md` Video section

## What rebuild does / does not do

| Does | Does not |
|------|----------|
| Install mesa-utils, vulkan-tools, clinfo | Run `apply-amdgpu` |
| Ensure `bin/gpu-stress` is executable | Install ROCm |
| | Configure monitor layout (use GNOME Settings) |

**Required post-rebuild:** `sudo bin/apply-amdgpu` + reboot (Chapter 3).

## Sensor watchdog

`thermald` does not run on this Haswell Xeon. `bin/apply-sensor-watch` installs `indianadell-sensor-watch.service` (starts after `graphical.target`, sleeps 120 s on a cold boot, then polls). It logs out-of-range CPU/GPU/DIMM/fan/SMART temps to syslog, pops a GNOME notification on the logged-in session bus, and steps GPU clocks / CPU `scaling_max_freq` down until under 80 °C (back up after a 72 °C deadband). Disk SMART uses `smartctl -n standby,0` so sleeping HDDs are not woken.

A desktop notice is sent on **`systemctl reload`** and **`systemctl restart`**, not on first start or stop. Test the path without cycling the unit:

```bash
sudo indiana-sensor-watch --notify test
sudo systemctl reload indianadell-sensor-watch
```

```bash
sudo bin/apply-sensor-watch
indiana-sensor-watch --once
journalctl -t indiana-sensor-watch -f
```

Config: `/etc/indiana-sensor-watch.conf` (defaults in `etc/indiana-sensor-watch.conf`). `THROTTLE=0` / `THROTTLE_CPU=0` disable clock writes. `dell_smm` fan2 is ignored (unused HDD_FAN header).

## Monitor input select

These FirePros are mini-DP only. There is no `/dev/cec`, so HDMI-CEC cannot switch the set.

`indiana-monitor-input` uses **DDC/CI** (`ddcutil`, VCP 60) on the current cable:

```bash
indiana-monitor-input detect
indiana-monitor-input grab    # request DisplayPort-1 (this PC)
indiana-monitor-input set hdmi1
```

Verified on this Samsung (2018) via `card2-DP-4` / i2c-7: EDID works, **I2C 0x37 does not answer**. Until the OSD “DDC/CI” option is on (or a different panel is used), `grab` will fail with that fact. User must be in group `i2c` (or use sudo).

## IR HDMI select (Arduino Uno)

When DDC/CEC cannot switch the TV, a 940 nm LED on an Uno can send one Samsung discrete code. Wiring and flash: `tools/ir-blaster/README.md`.

```bash
indiana-ir-flash                 # arduino-cli; no IDE
indiana-ir-send hdmi2
```

Host waits for `READY`/`OK` on the serial fd (Uno resets on port open). Group `dialout` required.
---

## Lab host note — Thumper (NVIDIA)

This chapter is **Tower5810 / AMD only**. The lab host **`thumper.local`** (Dell Precision T5610) runs **NVIDIA TITAN Xp** and is **not** configured with `apply-amdgpu`.

**Full Thumper GPU doc** (inventory, dual-card plan, **power/clock locking**, LingBot-Map pointer):

→ [`docs/thumper-gpu.md`](../thumper-gpu.md)

Summary: a second TITAN Xp with a weak cooler can be limited with `nvidia-smi -pl` / `-lgc` (and a oneshot systemd unit). Prefer `CUDA_VISIBLE_DEVICES` so heavy jobs stay on the well-cooled card. DragonSDR LingBot-Map lives under `~/Data/lingbot-map` on Thumper — see also `~/Documents/DragonSDR/tools/lingbot-map/README.md`.
