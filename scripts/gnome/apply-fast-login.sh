#!/usr/bin/env bash
# Fast boot + GDM auto-login + greeter face icon (wizard watermark).
#
# - GRUB: zero menu timeout (including ZFS recordfail / os-prober delays)
# - GDM: AutomaticLogin for user "user"
# - Greeter avatar: Themes/boot/overlay/wizard-watermark.png (or wizard.png)
#
# Usage:
#   sudo bin/apply-fast-login
#   sudo bin/apply-fast-login --no-face    # skip avatar
#   sudo bin/apply-fast-login --no-grub    # skip GRUB (GDM/face only)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ETC="$ROOT/etc"
LOGIN_USER="${LOGIN_USER:-user}"
HOME_DIR="$(getent passwd "$LOGIN_USER" | cut -d: -f6)"
WIZARD_CANDIDATES=(
  "$ROOT/Themes/boot/overlay/wizard-watermark.png"
  "$ROOT/Themes/boot/overlay/wizard.png"
  "$ROOT/Themes/boot/overlay/wizard-watermark.jpg"
)

DO_GRUB=1
DO_GDM=1
DO_FACE=1

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

usage() {
  sed -n '2,12p' "$0"
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-grub) DO_GRUB=0; shift ;;
    --no-gdm) DO_GDM=0; shift ;;
    --no-face) DO_FACE=0; shift ;;
    --user) LOGIN_USER="$2"; HOME_DIR="$(getent passwd "$LOGIN_USER" | cut -d: -f6)"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

[[ "$(id -u)" -eq 0 ]] || { echo "Run with sudo" >&2; exit 1; }
[[ -n "$HOME_DIR" && -d "$HOME_DIR" ]] || {
  echo "ERROR: home for user '$LOGIN_USER' not found" >&2
  exit 1
}

# ---------------------------------------------------------------------------
# GRUB — instant boot
# ---------------------------------------------------------------------------
if [[ "$DO_GRUB" -eq 1 ]]; then
  log "Installing GRUB fastboot fragments"
  install -d /etc/default/grub.d /etc/grub.d
  install -m 0644 "$ETC/default/grub.d/99-indianadell-fastboot.cfg" \
    /etc/default/grub.d/99-indianadell-fastboot.cfg
  install -m 0755 "$ETC/grub.d/99_indianadell_fastboot" \
    /etc/grub.d/99_indianadell_fastboot

  # Also harden main /etc/default/grub if keys are present/commented
  if [[ -f /etc/default/grub ]]; then
    if grep -qE '^GRUB_TIMEOUT=' /etc/default/grub; then
      sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' /etc/default/grub
    else
      echo 'GRUB_TIMEOUT=0' >> /etc/default/grub
    fi
    if grep -qE '^GRUB_TIMEOUT_STYLE=' /etc/default/grub; then
      sed -i 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=hidden/' /etc/default/grub
    else
      echo 'GRUB_TIMEOUT_STYLE=hidden' >> /etc/default/grub
    fi
    if grep -qE '^#?GRUB_RECORDFAIL_TIMEOUT=' /etc/default/grub; then
      sed -i 's/^#\?GRUB_RECORDFAIL_TIMEOUT=.*/GRUB_RECORDFAIL_TIMEOUT=0/' /etc/default/grub
    else
      echo 'GRUB_RECORDFAIL_TIMEOUT=0' >> /etc/default/grub
    fi
  fi

  log "Running update-grub"
  update-grub
  if grep -q 'IndianaDell fastboot' /boot/grub/grub.cfg 2>/dev/null; then
    log "grub.cfg contains IndianaDell fastboot override"
  else
    log "WARN: fastboot marker not found in grub.cfg (check update-grub output)"
  fi
  # Show effective final timeout lines
  log "Final timeout lines in grub.cfg:"
  grep -nE 'set timeout|timeout_style' /boot/grub/grub.cfg | tail -8 || true
fi

# ---------------------------------------------------------------------------
# GDM auto-login
# ---------------------------------------------------------------------------
if [[ "$DO_GDM" -eq 1 ]]; then
  log "Configuring GDM AutomaticLogin for '$LOGIN_USER'"
  install -d /etc/gdm3
  # Prefer repo template, but ensure it targets LOGIN_USER
  if [[ -f "$ETC/gdm3/custom.conf" ]]; then
    install -m 0644 "$ETC/gdm3/custom.conf" /etc/gdm3/custom.conf
  fi
  # Patch / rewrite daemon section keys
  python3 - "$LOGIN_USER" <<'PY'
import re, sys
from pathlib import Path
user = sys.argv[1]
path = Path("/etc/gdm3/custom.conf")
text = path.read_text(encoding="utf-8") if path.is_file() else "[daemon]\n"
if "[daemon]" not in text:
    text = "[daemon]\n" + text
# Ensure keys inside [daemon]
def set_key(section_text: str, key: str, value: str) -> str:
    pat = re.compile(rf"(?m)^\s*#?\s*{re.escape(key)}\s*=.*$")
    line = f"{key}={value}"
    if pat.search(section_text):
        return pat.sub(line, section_text)
    # insert after [daemon]
    return re.sub(r"(?m)^\[daemon\]\s*$", f"[daemon]\n{line}", section_text, count=1)

# Only patch the [daemon] section
parts = re.split(r"(?m)(?=^\[)", text)
out = []
for part in parts:
    if part.startswith("[daemon]"):
        part = set_key(part, "AutomaticLoginEnable", "true")
        part = set_key(part, "AutomaticLogin", user)
        if "WaylandEnable" not in part:
            part = set_key(part, "WaylandEnable", "true")
    out.append(part)
path.write_text("".join(out), encoding="utf-8")
print(path.read_text())
PY
  log "GDM custom.conf written"
fi

# ---------------------------------------------------------------------------
# Greeter / AccountsService face icon
# ---------------------------------------------------------------------------
if [[ "$DO_FACE" -eq 1 ]]; then
  SRC=""
  for c in "${WIZARD_CANDIDATES[@]}"; do
    if [[ -f "$c" ]]; then SRC="$c"; break; fi
  done
  if [[ -z "$SRC" ]]; then
    log "WARN: no wizard image in Themes/boot/overlay/ — skipping face icon"
  else
    log "Setting greeter face for '$LOGIN_USER' from $SRC"
    install -d /var/lib/AccountsService/icons
    # AccountsService prefers PNG under /var/lib/AccountsService/icons/<username>
    FACE_ICON="/var/lib/AccountsService/icons/${LOGIN_USER}"
    # Normalize to square-ish PNG for greeter (keep aspect, pad transparent)
    python3 - "$SRC" "$FACE_ICON" <<'PY'
import sys
from pathlib import Path
from PIL import Image
src, dst = Path(sys.argv[1]), Path(sys.argv[2])
im = Image.open(src).convert("RGBA")
# Knock near-white paper bg if fully opaque JPEG-like
import numpy as np
arr0 = np.array(im)
if float(arr0[:, :, 3].mean()) > 250:
    arr = arr0.astype(float)
    dist = ((arr[:, :, :3] - 255) ** 2).sum(axis=2) ** 0.5
    arr[:, :, 3] = (dist > 18).astype(float) * 255
    im = Image.fromarray(arr.astype("uint8"), "RGBA")
# Fit into 512×512, preserve aspect
size = 512
im.thumbnail((size, size), Image.Resampling.LANCZOS)
canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
canvas.paste(im, ((size - im.width) // 2, (size - im.height) // 2), im)
canvas.save(dst, format="PNG", optimize=True)
print(f"wrote {dst} {canvas.size}")
PY
    chown root:root "$FACE_ICON"
    chmod 644 "$FACE_ICON"

    # Also ~/.face for GNOME/AccountsService fallback
    install -m 0644 "$FACE_ICON" "$HOME_DIR/.face"
    # Some greeters also look for .face.icon
    install -m 0644 "$FACE_ICON" "$HOME_DIR/.face.icon"
    chown "${LOGIN_USER}:${LOGIN_USER}" "$HOME_DIR/.face" "$HOME_DIR/.face.icon"

    # AccountsService user record
    AS_USER="/var/lib/AccountsService/users/${LOGIN_USER}"
    install -d /var/lib/AccountsService/users
    if [[ -f "$AS_USER" ]]; then
      if grep -qE '^Icon=' "$AS_USER"; then
        sed -i "s|^Icon=.*|Icon=${FACE_ICON}|" "$AS_USER"
      elif grep -qE '^\[User\]' "$AS_USER"; then
        sed -i "/^\[User\]/a Icon=${FACE_ICON}" "$AS_USER"
      else
        printf '\n[User]\nIcon=%s\n' "$FACE_ICON" >> "$AS_USER"
      fi
      # Ensure SystemAccount=false so user appears
      if ! grep -qE '^SystemAccount=' "$AS_USER"; then
        sed -i "/^\[User\]/a SystemAccount=false" "$AS_USER" 2>/dev/null || \
          printf 'SystemAccount=false\n' >> "$AS_USER"
      fi
    else
      cat > "$AS_USER" <<EOF
[User]
SystemAccount=false
Icon=${FACE_ICON}
EOF
    fi
    chmod 644 "$AS_USER"
    # Restart AccountsService so greeter picks it up without full reboot
    systemctl reload accounts-daemon 2>/dev/null || systemctl restart accounts-daemon 2>/dev/null || true
    log "Face icon installed: $FACE_ICON"
    log "Also: $HOME_DIR/.face"
  fi
fi

log "Done."
echo
echo "Summary:"
[[ "$DO_GRUB" -eq 1 ]] && echo "  • GRUB menu timeout forced to 0 (fastboot fragment + RECORDFAIL=0)"
[[ "$DO_GDM" -eq 1 ]] && echo "  • GDM AutomaticLogin → $LOGIN_USER"
[[ "$DO_FACE" -eq 1 ]] && echo "  • Greeter avatar → wizard watermark"
echo
echo "Reboot to apply boot + auto-login fully:"
echo "  sudo reboot"
