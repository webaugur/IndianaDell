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
- `etc/modprobe.d/amdgpu-multigpu.conf`
- `etc/udev/rules.d/99-amdgpu-multigpu.rules`
- `etc/profile.d/amdgpu-multigpu.sh`
- `etc/gdm3/custom.conf` (if present)

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