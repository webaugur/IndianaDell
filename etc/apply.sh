#!/bin/bash
# Install ./etc configs onto B1GMB42 (Tower5810). Run: sudo bin/apply-amdgpu
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ETC="$ROOT/etc"

install -d /etc/udev/rules.d /etc/modprobe.d /etc/X11/xorg.conf.d
install -d /etc/profile.d /etc/gdm3 /usr/local/sbin

install -m 0644 "$ETC/udev/rules.d/99-amdgpu-multigpu.rules" /etc/udev/rules.d/
install -m 0644 "$ETC/modprobe.d/amdgpu-multigpu.conf" /etc/modprobe.d/
install -m 0644 "$ETC/X11/xorg.conf.d/20-amdgpu-multi-gpu.conf" /etc/X11/xorg.conf.d/
install -m 0644 "$ETC/profile.d/amdgpu-multigpu.sh" /etc/profile.d/
install -m 0644 "$ETC/gdm3/custom.conf" /etc/gdm3/custom.conf
install -d /etc/environment.d
install -m 0644 "$ETC/environment.d/99-amdgpu-wayland.conf" /etc/environment.d/

# Max DPM clocks on all amdgpu cards (live + udev on future boots)
install -m 0755 "$ETC/amdgpu-set-dpm-performance.sh" /usr/local/sbin/indiana-amdgpu-dpm-performance
/usr/local/sbin/indiana-amdgpu-dpm-performance || true
udevadm control --reload-rules 2>/dev/null || true

# Retired W5100 pin files
rm -f /etc/udev/rules.d/99-amdgpu-w5100-primary.rules
rm -f /etc/X11/xorg.conf.d/10-amdgpu-w5100-primary.conf
rm -f /etc/systemd/system/gdm.service.d/10-w5100-display.conf
rm -f /etc/profile.d/amdgpu-w5100-wayland.sh
rm -f /dev/dri/dri-primary-w5100

update-initramfs -u 2>/dev/null || true
echo "Applied unpinned 3-GPU amdgpu config (DPM performance on all cards). Reboot recommended."
