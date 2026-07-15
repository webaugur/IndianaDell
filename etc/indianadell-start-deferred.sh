#!/usr/bin/env bash
# Start deferred units after graphical.target (non-blocking per unit).
set -euo pipefail

LIST="${INDIANADELL_DEFERRED_LIST:-/etc/indianadell-deferred.list}"
LOG_TAG="indianadell-deferred"

log() { logger -t "$LOG_TAG" -- "$*" || printf '%s\n' "$*"; }

[[ -r "$LIST" ]] || { log "no list $LIST"; exit 0; }

# Give GDM/session a moment to claim the GPU and finish autologin
sleep 3

while read -r unit; do
  unit="${unit%%#*}"
  unit="$(echo "$unit" | tr -d '[:space:]')"
  [[ -z "$unit" ]] && continue
  if ! systemctl cat "$unit" &>/dev/null; then
    continue
  fi
  # Already active — skip
  if systemctl is-active --quiet "$unit" 2>/dev/null; then
    continue
  fi
  log "starting $unit"
  # --no-block: do not serialize long starts (docker, snapd, …)
  systemctl start --no-block "$unit" 2>/dev/null || log "WARN: failed to start $unit"
done < "$LIST"

log "deferred start batch issued"
exit 0
