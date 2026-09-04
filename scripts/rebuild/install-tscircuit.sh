#!/usr/bin/env bash
# Install tscircuit + capacity-autorouter (TypeScript → KiCad schematic/PCB).
# Sourced by rebuild-machine.sh and bin/fix-indianadell.sh.
# User-local prefix: $HOME/.local (no sudo npm; ~/.local/bin is already on PATH).
# Opt out with the rest of KiCad: SKIP_KICAD=1
#
# Upstream:
#   https://github.com/tscircuit/tscircuit
#   https://github.com/tscircuit/tscircuit-autorouter  (npm: @tscircuit/capacity-autorouter)
#
# shellcheck shell=bash

TSCIRCUIT_NPM_PREFIX="${TSCIRCUIT_NPM_PREFIX:-$HOME/.local}"
TSCIRCUIT_NPM_PACKAGES=(
  tscircuit
  @tscircuit/capacity-autorouter
  typescript
)

if ! declare -F log >/dev/null 2>&1; then
  log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
fi

tscircuit_cli_path() {
  printf '%s\n' "${TSCIRCUIT_NPM_PREFIX}/lib/node_modules/tscircuit/cli.mjs"
}

tscircuit_autorouter_dir() {
  printf '%s\n' "${TSCIRCUIT_NPM_PREFIX}/lib/node_modules/@tscircuit/capacity-autorouter"
}

tscircuit_installed() {
  [[ -f "$(tscircuit_cli_path)" ]] && [[ -d "$(tscircuit_autorouter_dir)" ]]
}

install_tscircuit() {
  if ! command -v node >/dev/null 2>&1; then
    log "ERROR: node not found (install nodejs from APT_KICAD first)"
    return 1
  fi
  if ! command -v npm >/dev/null 2>&1; then
    log "ERROR: npm not found (install npm from APT_KICAD first)"
    return 1
  fi

  mkdir -p "${TSCIRCUIT_NPM_PREFIX}/bin" "${TSCIRCUIT_NPM_PREFIX}/lib" || {
    log "ERROR: cannot create ${TSCIRCUIT_NPM_PREFIX}"
    return 1
  }

  log "npm install -g --prefix ${TSCIRCUIT_NPM_PREFIX} ${TSCIRCUIT_NPM_PACKAGES[*]}"
  if ! npm install -g --prefix "${TSCIRCUIT_NPM_PREFIX}" "${TSCIRCUIT_NPM_PACKAGES[@]}"; then
    log "ERROR: npm install tscircuit / @tscircuit/capacity-autorouter failed"
    return 1
  fi

  if ! tscircuit_installed; then
    log "ERROR: tscircuit packages missing after npm install under ${TSCIRCUIT_NPM_PREFIX}"
    return 1
  fi
  log "OK   tscircuit at ${TSCIRCUIT_NPM_PREFIX}"
}
