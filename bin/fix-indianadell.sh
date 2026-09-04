#!/usr/bin/env bash
#
# fix-indianadell.sh
# The single authoritative verifier for every non-optional IndianaDell item.
#
# Verifies and repairs (with --fix) the complete non-optional stack:
#   - All APT_CORE packages (package-lists.sh is the source of truth)
#   - APT_KICAD (KiCad 10 + ngspice/gerbv + tscircuit) unless SKIP_KICAD=1
#   - All required bin/ launchers
#   - All system configuration files under etc/ (amdgpu, grub, udev, gdm, etc.)
#   - Environment variables, CopyQ autostart, USB dock stability
#   - GNOME session / performance / boot fixes that are required on this host
#
# Matches the documented requirements in:
#   - docs/software-manual/appendix-a-bin-launchers.md
#   - docs/software-manual/appendix-b-apt-packages.md
#   - docs/software-manual/03-post-rebuild-checklist.md
#   - docs/usb-dock-stability.md
#   - scripts/rebuild/rebuild-machine.sh
#
# Usage:
#   bin/fix-indianadell.sh                 # report status (yes/no per item)
#   bin/fix-indianadell.sh --fix           # install/repair everything missing
#   bin/fix-indianadell.sh --verify-only   # exit non-zero if anything missing
#   bin/fix-indianadell.sh --essential-only # skip optional items (e.g. Plymouth)
#
set -euo pipefail

FIX=0
VERIFY_ONLY=0
ESSENTIAL_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --fix) FIX=1 ;;
    --verify-only) VERIFY_ONLY=1 ;;
    --essential-only) ESSENTIAL_ONLY=1 ;;
    -h|--help)
      sed -n '4,26p' "$0"
      exit 0
      ;;
    *) echo "Unknown argument: $arg"; exit 1 ;;
  esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="/tmp/fix-indianadell.log"
need_fix=0

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "$LOG"; }

# Single source of truth for packages
# shellcheck source=scripts/rebuild/package-lists.sh
source "$ROOT/scripts/rebuild/package-lists.sh"
# shellcheck source=scripts/rebuild/ensure-kicad-ppa.sh
source "$ROOT/scripts/rebuild/ensure-kicad-ppa.sh"
# shellcheck source=scripts/rebuild/install-tscircuit.sh
source "$ROOT/scripts/rebuild/install-tscircuit.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

check_pkg() {
  local pkg="$1"
  if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q 'install ok installed'; then
    log "OK   apt: $pkg"
  else
    log "MISS apt: $pkg"
    need_fix=1
    if [[ $FIX -eq 1 ]]; then
      sudo apt install -y "$pkg" || true
      log "FIXED $pkg"
    fi
  fi
}

check_bin() {
  local name="$1"
  if [[ -x "$ROOT/bin/$name" ]]; then
    log "OK   bin: $name"
  else
    log "MISS bin: $name"
    need_fix=1
    # No auto-fix: the launcher must exist in the tree; user must pull or restore
  fi
}

check_file() {
  local src="$1" dst="$2" desc="$3"
  if [[ -f "$dst" ]]; then
    log "OK   $desc"
  else
    log "MISS $desc"
    need_fix=1
    if [[ $FIX -eq 1 ]]; then
      sudo cp "$src" "$dst"
      log "FIXED $desc"
    fi
  fi
}

check_bashrc_var() {
  local var="$1" value="$2" comment="$3"
  if grep -q "^export $var=$value" "$HOME/.bashrc" 2>/dev/null; then
    log "OK   $var=$value"
  else
    log "MISS $var=$value  ($comment)"
    need_fix=1
    if [[ $FIX -eq 1 ]]; then
      echo -e "\n# $comment\nexport $var=$value" >> "$HOME/.bashrc"
      log "FIXED $var"
    fi
  fi
}

check_copyq_autostart() {
  local desktop="$HOME/.config/autostart/com.github.hluk.copyq.desktop"
  if [[ -f "$desktop" ]]; then
    log "OK   CopyQ autostart"
  else
    log "MISS CopyQ autostart"
    need_fix=1
    if [[ $FIX -eq 1 ]]; then
      mkdir -p "$HOME/.config/autostart"
      cat > "$desktop" << 'DESKTOP'
[Desktop Entry]
Type=Application
Name=CopyQ
GenericName=Clipboard Manager
Icon=copyq
Exec=copyq
Terminal=false
Categories=Utility;Qt;
StartupNotify=false
X-GNOME-Autostart-enabled=true
DESKTOP
      log "FIXED CopyQ autostart"
    fi
  fi
}

check_udev_rule() {
  local rule="99-usb-dock.rules"
  if [[ -f /etc/udev/rules.d/$rule ]]; then
    log "OK   udev: $rule"
  else
    log "MISS udev: $rule (USB dock stability)"
    need_fix=1
    if [[ $FIX -eq 1 ]]; then
      sudo cp "$ROOT/bin/$rule" /etc/udev/rules.d/
      sudo udevadm control --reload-rules
      sudo udevadm trigger
      log "FIXED $rule"
    fi
  fi
}

check_kicad() {
  if [[ "${SKIP_KICAD:-0}" == 1 ]]; then
    log "SKIP kicad (SKIP_KICAD=1)"
    return 0
  fi

  if [[ $FIX -eq 1 ]]; then
    ensure_kicad_ppa || {
      log "MISS KiCad PPA (ensure_kicad_ppa failed)"
      need_fix=1
      return 1
    }
  fi

  local p
  for p in "${APT_KICAD[@]}"; do
    check_pkg "$p"
  done

  local c
  for c in kicad kicad-cli ngspice node npm; do
    if command -v "$c" >/dev/null 2>&1; then
      log "OK   cmd: $c"
    else
      log "MISS cmd: $c"
      need_fix=1
    fi
  done

  local ver
  # pcbnew prints wx asserts on stderr; version still comes from stdout.
  if ver=$(python3 -c 'import pcbnew,sys; v=pcbnew.Version(); print(v); sys.exit(0 if str(v).startswith("10.") else 1)' 2>/dev/null); then
    log "OK   pcbnew python $ver"
  else
    log "MISS/FAIL pcbnew python (need 10.*)"
    need_fix=1
  fi

  if [[ $FIX -eq 1 ]]; then
    install_tscircuit || {
      log "MISS tscircuit npm install"
      need_fix=1
    }
  fi
  if tscircuit_installed; then
    log "OK   tscircuit + @tscircuit/capacity-autorouter"
  else
    log "MISS tscircuit (npm: tscircuit + @tscircuit/capacity-autorouter)"
    need_fix=1
  fi
}

# Soft-fail Docker / Docker Compose (non-optional for some lab workflows
# but must never break the overall IndianaDell verification).
check_docker_compose() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    log "OK   docker compose"
    return 0
  fi

  log "MISS docker compose (soft fail — will not block IndianaDell)"
  if [[ $FIX -eq 1 ]]; then
    echo -e "\033[1;31m[SOFT FAIL]\033[0m Attempting to install docker + docker compose..."
    if ! sudo apt update && sudo apt install -y docker.io docker-compose-v2; then
      echo -e "\033[1;31m[SOFT FAIL]\033[0m docker install failed on this system (non-fatal)."
      echo "          You can install manually later: sudo apt install docker.io docker-compose-v2"
      echo "          Then: sudo usermod -aG docker \$USER && newgrp docker"
    else
      sudo usermod -aG docker "$USER" 2>/dev/null || true
      log "FIXED docker compose (soft)"
    fi
  fi
}

# ---------------------------------------------------------------------------
# Hardware detection (keep checks generic where possible)
# ---------------------------------------------------------------------------

has_amdgpu() {
  # True only if at least one GPU is currently bound to the amdgpu driver.
  # This distinguishes Tower5810 (3× FirePro on amdgpu) from
  # Thumper (HD 6350 on legacy radeon + NVIDIA TITAN Xp for compute).
  #
  # Primary method: walk /sys/class/drm for devices whose driver symlink
  # points to the amdgpu module. This is more reliable than parsing lspci.
  shopt -s nullglob
  local found=0
  for dev in /sys/class/drm/card*/device/driver; do
    [[ -e "$dev" ]] || continue
    if readlink "$dev" 2>/dev/null | grep -q '/amdgpu$'; then
      found=1
      break
    fi
  done
  shopt -u nullglob

  if [[ $found -eq 1 ]]; then
    return 0
  fi

  # Fallback: lspci text (some systems may not expose the sysfs link cleanly)
  if lspci -k 2>/dev/null | grep -qi 'Kernel driver in use: amdgpu'; then
    return 0
  fi

  return 1
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

echo "=== IndianaDell Full Compatibility Check ==="
echo "Log: $LOG"
echo

# 1. APT packages (package-lists.sh is the single source of truth)
for p in "${APT_CORE[@]}"; do
  check_pkg "$p"
done
check_kicad

# 2. Required bin/ launchers (non-optional for a working IndianaDell machine)
for b in \
  dellmerge gpu-stress iotest apply-amdgpu rebuild-machine \
  apply-dark-mode apply-max-performance apply-fast-boot apply-fast-login \
  apply-sensor-watch indiana-sensor-watch indiana-monitor-input \
  indiana-ir-send indiana-ir-flash \
  tsci tscircuit \
  fix-nautilus-desktop-launch sync-desktop-icons \
  themes-extract themes-install-boot themes-restore-boot \
  install-dragonsdr hackrf-env \
  efi-timing-suite build-software-manual build-all-docs \
  pull-repo push-repo \
  amd-preflight amd-verify amd-uninstall \
  build-zfs-recovery-doc setup-wiggly-ventoy; do
  check_bin "$b"
done

# 3. System configuration files (etc/)
# Generic (safe on any hardware)
check_file "$ROOT/etc/default/grub.d/99-indianadell-fastboot.cfg" /etc/default/grub.d/99-indianadell-fastboot.cfg "GRUB fastboot"
check_file "$ROOT/etc/default/grub.d/zz-indianadell-cmdline.cfg"   /etc/default/grub.d/zz-indianadell-cmdline.cfg   "GRUB cmdline quirk"
check_file "$ROOT/etc/gdm3/custom.conf"           /etc/gdm3/custom.conf           "GDM custom.conf"

# AMD GPU stack — only required when AMD hardware is present
if has_amdgpu; then
  check_file "$ROOT/etc/modprobe.d/amdgpu-multigpu.conf" /etc/modprobe.d/amdgpu-multigpu.conf "amdgpu multigpu"
  check_file "$ROOT/etc/profile.d/amdgpu-multigpu.sh"    /etc/profile.d/amdgpu-multigpu.sh    "amdgpu profile"
  check_file "$ROOT/etc/environment.d/99-amdgpu-wayland.conf" /etc/environment.d/99-amdgpu-wayland.conf "Wayland env"
  check_file "$ROOT/etc/udev/rules.d/99-amdgpu-multigpu.rules" /etc/udev/rules.d/99-amdgpu-multigpu.rules "amdgpu udev"
else
  log "SKIP amdgpu stack (no card bound to amdgpu driver)"
fi

check_udev_rule   # USB dock (harmless on any machine)

# 4. Environment variables (Wayland clipboard + Qt theming)
check_bashrc_var "ARBOARD_BACKEND" "wayland" "Wayland clipboard for Rust TUIs"
check_bashrc_var "QT_QPA_PLATFORMTHEME" "gtk3" "Qt apps use GTK/Adwaita on GNOME"

# 5. CopyQ autostart (required on GNOME Wayland)
check_copyq_autostart

# 6. Deferred service (fast-boot)
if systemctl is-enabled indianadell-deferred.service >/dev/null 2>&1; then
  log "OK   systemd: indianadell-deferred.service"
else
  log "MISS systemd: indianadell-deferred.service"
  need_fix=1
  if [[ $FIX -eq 1 ]]; then
    sudo cp "$ROOT/etc/systemd/system/indianadell-deferred.service" /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable indianadell-deferred.service
    log "FIXED deferred service"
  fi
fi

# 6b. Sensor watchdog
if systemctl is-enabled indianadell-sensor-watch.service >/dev/null 2>&1; then
  log "OK   systemd: indianadell-sensor-watch.service"
else
  log "MISS systemd: indianadell-sensor-watch.service"
  need_fix=1
  if [[ $FIX -eq 1 ]]; then
    sudo "$ROOT/bin/apply-sensor-watch"
    log "FIXED sensor-watch service"
  fi
fi

# 7. ZFS force import (required on any IndianaDell ZFS host)
if grep -q 'ZPOOL_IMPORT_OPTS="-f"' /etc/default/zfs 2>/dev/null; then
  log "OK   ZFS: ZPOOL_IMPORT_OPTS=-f"
else
  log "MISS ZFS: ZPOOL_IMPORT_OPTS=-f (boot can hang after unclean shutdown)"
  need_fix=1
  if [[ $FIX -eq 1 ]]; then
    if [[ -f /etc/default/zfs ]]; then
      sudo sed -i 's/^ZPOOL_IMPORT_OPTS=.*/ZPOOL_IMPORT_OPTS="-f"/' /etc/default/zfs || true
    else
      echo 'ZPOOL_IMPORT_OPTS="-f"' | sudo tee -a /etc/default/zfs >/dev/null
    fi
    log "FIXED ZFS force import"
  fi
fi

# 8. IndianaDell PATH shim (makes bin/ launchers take precedence)
path_shim="$HOME/.config/indianadell/path.sh"
if [[ -f "$path_shim" ]]; then
  log "OK   PATH shim: $path_shim"
else
  log "MISS PATH shim (bin/ launchers may not override system tools)"
  need_fix=1
  if [[ $FIX -eq 1 ]]; then
    mkdir -p "$(dirname "$path_shim")"
    cat > "$path_shim" << 'SHIM'
# IndianaDell PATH override (generated by fix-indianadell.sh)
export INDIANADELL_ROOT="$HOME/Documents/IndianaDell"
export PATH="$INDIANADELL_ROOT/bin:$PATH"
SHIM
    # Ensure it is sourced from .bashrc if not already
    if ! grep -q 'indianadell/path.sh' "$HOME/.bashrc" 2>/dev/null; then
      echo -e "\n# IndianaDell tools first\n[[ -f $path_shim ]] && source $path_shim" >> "$HOME/.bashrc"
    fi
    log "FIXED PATH shim"
  fi
fi

# 9. Docker Compose (soft fail — never blocks overall verification)
check_docker_compose

# 9. Plymouth boot theme (optional but enabled by default)
#    Use --essential-only to skip this check.
if [[ $ESSENTIAL_ONLY -eq 0 ]]; then
  # The active theme is stored via the default.plymouth symlink, not in
  # plymouthd.conf on this system.  We therefore resolve the symlink target.
  target="$(readlink -f /usr/share/plymouth/themes/default.plymouth 2>/dev/null || true)"
  if [[ "$target" == */indianadell/indianadell.plymouth ]]; then
    log "OK   Plymouth: indianadell theme active"
  else
    log "MISS Plymouth: indianadell theme (optional)"
    need_fix=1
    if [[ $FIX -eq 1 ]]; then
      if [[ -x "$ROOT/bin/themes-install-boot" ]]; then
        sudo "$ROOT/bin/themes-install-boot" || true
        log "FIXED Plymouth theme (via themes-install-boot)"
      else
        log "SKIP Plymouth fix (themes-install-boot not found)"
      fi
    fi
  fi
else
  log "SKIP Plymouth (essential-only mode)"
fi

# 10. Optional external projects (DragonSDR, McFloater)
#     These are never fatal and never set need_fix.  They are reported only
#     so the user knows the full lab stack status.
if [[ $ESSENTIAL_ONLY -eq 0 ]]; then
  if [[ -d "$HOME/Documents/DragonSDR" && -x "$HOME/Documents/DragonSDR/bin/install-suite" ]]; then
    log "OK   DragonSDR: suite present"
  else
    log "MISS DragonSDR (optional) — not required for IndianaDell core"
  fi

  if [[ -d "$HOME/Documents/McFloater" && -f "$HOME/Documents/McFloater/Cargo.toml" ]]; then
    log "OK   McFloater: source present"
  else
    log "MISS McFloater (optional) — not required for IndianaDell core"
  fi
else
  log "SKIP DragonSDR/McFloater (essential-only mode)"
fi

# ---------------------------------------------------------------------------
# Optional hooks (DragonSDR, McFloater, etc.)
# These are never fatal.  If the external project provides a
# bin/verify-indianadell.sh (or equivalent), we call it with --verify-only.
# The hook is responsible for printing its own OK/MISS lines.
# ---------------------------------------------------------------------------

for hook in \
  "$HOME/Documents/DragonSDR/bin/verify-indianadell.sh" \
  "$HOME/Documents/McFloater/bin/verify-indianadell.sh"; do
  if [[ -x "$hook" ]]; then
    log "HOOK $(basename "$(dirname "$hook")")"
    "$hook" --verify-only || true   # never fail the main script
  fi
done

echo
if [[ $need_fix -eq 0 ]]; then
  echo "This machine is fully IndianaDell compatible."
else
  if [[ $FIX -eq 0 && $VERIFY_ONLY -eq 0 ]]; then
    echo "Run with --fix to install/repair the missing items."
  fi
fi

if [[ $VERIFY_ONLY -eq 1 ]]; then
  exit $need_fix
fi
