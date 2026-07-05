#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sudo cp "$ROOT/scripts/99-hackrf.rules" /etc/udev/rules.d/99-hackrf.rules
sudo udevadm control --reload-rules
sudo udevadm trigger
sudo usermod -aG plugdev "$USER" 2>/dev/null || true
echo "udev rules installed. Re-plug HackRF or log out/in for group plugdev."