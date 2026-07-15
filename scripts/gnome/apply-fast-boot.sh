#!/usr/bin/env bash
# Boot-to-desktop speedups (keep Plymouth splash).
#
#   • Strip crashkernel= from GRUB cmdline (keep quiet splash)
#   • Disable NetworkManager-wait-online
#   • Lazy-load via sockets (docker, cups, snapd, libvirt, …)
#   • Defer remaining nonessential services until after graphical.target
#   • Disable kdump-tools
#
# Usage:
#   sudo bin/apply-fast-boot
#   sudo bin/apply-fast-boot --undo     # re-enable deferred units (best-effort)
#   sudo bin/apply-fast-boot --status
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ETC="$ROOT/etc"
MODE=apply

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

usage() {
  sed -n '2,14p' "$0"
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --undo) MODE=undo; shift ;;
    --status) MODE=status; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

[[ "$(id -u)" -eq 0 ]] || { echo "Run with sudo" >&2; exit 1; }

read_list() {
  local f="$1"
  [[ -r "$f" ]] || return 0
  while read -r line; do
    line="${line%%#*}"
    line="$(echo "$line" | tr -d '[:space:]')"
    [[ -n "$line" ]] && printf '%s\n' "$line"
  done < "$f"
}

unit_exists() {
  systemctl cat "$1" &>/dev/null
}

# ---------------------------------------------------------------------------
status_mode() {
  echo "=== cmdline ==="
  cat /proc/cmdline
  echo
  echo "=== NM wait-online ==="
  systemctl is-enabled NetworkManager-wait-online.service 2>/dev/null || true
  systemctl is-active NetworkManager-wait-online.service 2>/dev/null || true
  echo
  echo "=== deferred oneshot ==="
  systemctl is-enabled indianadell-deferred.service 2>/dev/null || true
  systemctl status indianadell-deferred.service --no-pager 2>/dev/null | head -12 || true
  echo
  echo "=== sample deferred units ==="
  for u in docker.service snapd.service libvirtd.service ModemManager.service cups-browsed.service; do
    printf '  %-30s enabled=%-10s active=%s\n' "$u" \
      "$(systemctl is-enabled "$u" 2>/dev/null || echo n/a)" \
      "$(systemctl is-active "$u" 2>/dev/null || echo n/a)"
  done
  echo
  echo "=== sockets (lazy) ==="
  for u in docker.socket snapd.socket cups.socket libvirtd.socket; do
    printf '  %-30s enabled=%-10s active=%s\n' "$u" \
      "$(systemctl is-enabled "$u" 2>/dev/null || echo n/a)" \
      "$(systemctl is-active "$u" 2>/dev/null || echo n/a)"
  done
  echo
  systemd-analyze 2>/dev/null || true
}

# ---------------------------------------------------------------------------
undo_mode() {
  log "UNDO: re-enabling deferred services (best-effort)"
  systemctl disable --now indianadell-deferred.service 2>/dev/null || true
  rm -f /etc/systemd/system/indianadell-deferred.service
  rm -f /usr/local/sbin/indianadell-start-deferred
  rm -f /etc/indianadell-deferred.list /etc/indianadell-socket-lazy.list

  while read -r u; do
    unit_exists "$u" || continue
    systemctl enable "$u" 2>/dev/null || true
  done < <(read_list "$ETC/indianadell-deferred.list")

  systemctl enable NetworkManager-wait-online.service 2>/dev/null || true
  systemctl enable kdump-tools.service 2>/dev/null || true

  # Restore kdump grub snippet name if we renamed it
  if [[ -f /etc/default/grub.d/kdump-tools.cfg.indianadell-disabled ]]; then
    mv -f /etc/default/grub.d/kdump-tools.cfg.indianadell-disabled \
      /etc/default/grub.d/kdump-tools.cfg
  fi
  rm -f /etc/default/grub.d/zz-indianadell-cmdline.cfg

  systemctl daemon-reload
  update-grub 2>/dev/null || true
  log "Undo complete. Reboot recommended. Some units may need: systemctl start NAME"
}

# ---------------------------------------------------------------------------
apply_mode() {
  log "Installing GRUB cmdline override (quiet splash, no crashkernel)"
  install -d /etc/default/grub.d
  install -m 0644 "$ETC/default/grub.d/zz-indianadell-cmdline.cfg" \
    /etc/default/grub.d/zz-indianadell-cmdline.cfg
  # Neutralize kdump append so it cannot win ordering races
  if [[ -f /etc/default/grub.d/kdump-tools.cfg ]]; then
    mv -f /etc/default/grub.d/kdump-tools.cfg \
      /etc/default/grub.d/kdump-tools.cfg.indianadell-disabled
    log "Renamed kdump-tools.cfg → kdump-tools.cfg.indianadell-disabled"
  fi
  # Keep fastboot timeout fragment if present
  if [[ -f "$ETC/default/grub.d/99-indianadell-fastboot.cfg" ]]; then
    install -m 0644 "$ETC/default/grub.d/99-indianadell-fastboot.cfg" \
      /etc/default/grub.d/99-indianadell-fastboot.cfg
  fi
  if [[ -f "$ETC/grub.d/99_indianadell_fastboot" ]]; then
    install -m 0755 "$ETC/grub.d/99_indianadell_fastboot" \
      /etc/grub.d/99_indianadell_fastboot
  fi
  # Ensure base defaults still say quiet splash
  if [[ -f /etc/default/grub ]]; then
    if grep -qE '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub; then
      sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/' /etc/default/grub
    fi
  fi

  log "update-grub"
  update-grub
  if grep -q 'crashkernel' /boot/grub/grub.cfg 2>/dev/null; then
    log "WARN: crashkernel still appears in grub.cfg — check /etc/default/grub.d/"
    grep -n crashkernel /boot/grub/grub.cfg | head -5 || true
  else
    log "grub.cfg: no crashkernel (good); splash retained via quiet splash"
  fi

  log "Disable NetworkManager-wait-online"
  systemctl disable --now NetworkManager-wait-online.service 2>/dev/null || \
    systemctl disable NetworkManager-wait-online.service 2>/dev/null || true
  systemctl mask NetworkManager-wait-online.service 2>/dev/null || true

  log "Disable kdump-tools service"
  systemctl disable --now kdump-tools.service 2>/dev/null || true

  log "Install deferred starter + unit lists"
  install -d /etc/systemd/system /usr/local/sbin
  install -m 0755 "$ETC/indianadell-start-deferred.sh" /usr/local/sbin/indianadell-start-deferred
  install -m 0644 "$ETC/indianadell-deferred.list" /etc/indianadell-deferred.list
  install -m 0644 "$ETC/indianadell-socket-lazy.list" /etc/indianadell-socket-lazy.list
  install -m 0644 "$ETC/systemd/system/indianadell-deferred.service" \
    /etc/systemd/system/indianadell-deferred.service

  log "Lazy sockets: enable socket, disable eager service where applicable"
  while read -r sock; do
    unit_exists "$sock" || continue
    systemctl enable "$sock" 2>/dev/null || true
    systemctl start "$sock" 2>/dev/null || true
    log "  socket on: $sock"
  done < <(read_list "$ETC/indianadell-socket-lazy.list")

  log "Disable deferred services from early boot (will start post-graphical)"
  while read -r u; do
    unit_exists "$u" || continue
    # Don't stop running session-critical stuff mid-apply if active desktop
    systemctl disable "$u" 2>/dev/null || true
    log "  disabled at boot: $u"
  done < <(read_list "$ETC/indianadell-deferred.list")

  # containerd is often pulled by docker — keep disabled; docker start brings it
  systemctl daemon-reload
  systemctl enable indianadell-deferred.service
  log "Enabled indianadell-deferred.service (WantedBy=graphical.target)"

  log "Done."
  echo
  echo "Summary:"
  echo "  • GRUB: quiet splash, crashkernel stripped"
  echo "  • NetworkManager-wait-online: masked"
  echo "  • kdump-tools: disabled"
  echo "  • Nonessential services: disabled at boot; started after graphical"
  echo "  • docker/cups/snapd/libvirt: socket-activated when possible"
  echo
  echo "BIOS checklist: docs/fast-boot.md"
  echo "Reboot to measure:  sudo reboot && … then: systemd-analyze"
  echo "Status later:       sudo bin/apply-fast-boot --status"
  echo "Undo:               sudo bin/apply-fast-boot --undo"
}

case "$MODE" in
  apply) apply_mode ;;
  undo) undo_mode ;;
  status) status_mode ;;
esac
