# Chapter 12 — Machine Utilities

## What gets installed

Workspace scripts for inventory, storage benchmark, and GPU stress — no dedicated apt packages beyond shared GPU utils (`mesa-utils`, `vulkan-tools`).

| Utility | Launcher | Script | Output |
|---------|----------|--------|--------|
| Dell inventory | `bin/dellmerge` | `scripts/dell/dellmerge.sh` | stdout / `*.report` files |
| Storage survey | `bin/iotest` | `scripts/storage/iotest.sh` | IO metrics (sudo) |
| GPU stress | `bin/gpu-stress` | `scripts/gpu/gpu-stress.sh` | Vulkan/EGL per GPU |

**Example reports in workspace:** `b1gmb42.report`, `B1GMB42.ioperf` (from prior runs).

## How it is installed

Scripts ship with the workspace. Rebuild Phase 10 runs `chmod +x` on `bin/*` and `scripts/*/*.sh`.

```bash
bin/dellmerge > b1gmb42.report
sudo bin/iotest
bin/gpu-stress 60 vkcube
```

## How to verify

```bash
[[ -x bin/dellmerge && -x bin/iotest && -x bin/gpu-stress ]] && echo OK
bin/rebuild-machine --verify-only   # checks dellmerge, gpu-stress, iotest, apply-amdgpu
head -20 b1gmb42.report 2>/dev/null || bin/dellmerge | head -20
```

## How to customize

- Edit `scripts/dell/dellmerge.sh` to add inventory fields
- `gpu-stress` accepts duration and backend (`vkcube` default)
- `iotest` targets block devices — read script header before running on production pools

## What rebuild does / does not do

| Does | Does not |
|------|----------|
| chmod utility launchers | Run dellmerge or iotest automatically |
| Verify launcher executables exist | Archive reports to a fixed path |