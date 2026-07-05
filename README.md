# IndianaDell

Dell Precision T5810 (B1GMB42) workstation project — hardware inventory, rebuild scripts, themes, HackRF tooling, and recovery utilities.

## Layout

| Path | Purpose |
|------|---------|
| `bin/` | Machine launchers (`dellmerge`, `gpu-stress`, `rebuild-machine`, …) |
| `scripts/` | Supporting scripts (rebuild, GPU, storage, GitHub push helpers) |
| `amd-radeon/` | AMDGPU install/verify scripts |
| `hackrf/` | HackRF / Mayhem tooling (repos excluded from git; re-download with scripts) |
| `Themes/` | Boot/login/desktop theme mirrors and installers |
| `FactoryDocs/` | Dell vendor CABs/PDFs (local archive; large binaries) |
| `docs/` | Software manual sources and feature notes |
| `mount-rpool-recovery.sh` | ZFS `rpool` recovery mount (chroot default, `--overlay` optional) |

## Push to GitHub

Repository: https://github.com/webaugur/IndianaDell (private)

**Full push (recommended — includes binaries and FactoryDocs):**

```bash
gh auth login
bin/push-repo
```

**Partial sync via GitHub MCP (text/small files only):**

```bash
python3 scripts/generate-mcp-push-batches.py /tmp/indianadell-push-batches
scripts/push-mcp-batches.sh /tmp/indianadell-push-batches
```

## Recovery

```bash
sudo ./mount-rpool-recovery.sh mount      # chroot layout under /recovery
sudo ./mount-rpool-recovery.sh chroot     # enter chroot
sudo ./mount-rpool-recovery.sh umount
```