#!/usr/bin/env bash
# Install samsungtv CLI (PyPI: samsungtvws[cli]) via pipx.
# Sourced by rebuild-machine.sh and bin/fix-indianadell.sh.
# Opt out: SKIP_SAMSUNGTV=1
#
# Upstream: https://github.com/xchwarze/samsung-tv-ws-api
# CLI binary: samsungtv  (Tizen WebSocket/REST remote, 2016+)
#
# shellcheck shell=bash

SAMSUNGTV_PIPX_PKG="${SAMSUNGTV_PIPX_PKG:-samsungtvws}"
SAMSUNGTV_PIPX_SPEC="${SAMSUNGTV_PIPX_SPEC:-samsungtvws[cli]}"
SAMSUNGTV_PIPX_BIN="${SAMSUNGTV_PIPX_BIN:-$HOME/.local/pipx/venvs/${SAMSUNGTV_PIPX_PKG}/bin/samsungtv}"
SAMSUNGTV_USER_BIN="${SAMSUNGTV_USER_BIN:-$HOME/.local/bin/samsungtv}"

if ! declare -F log >/dev/null 2>&1; then
  log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
fi

samsungtv_cli_path() {
  local p
  for p in "$SAMSUNGTV_PIPX_BIN" "$SAMSUNGTV_USER_BIN"; do
    if [[ -x "$p" ]]; then
      printf '%s\n' "$p"
      return 0
    fi
  done
  return 1
}

samsungtv_installed() {
  samsungtv_cli_path >/dev/null
}

ensure_pipx() {
  if command -v pipx >/dev/null 2>&1; then
    return 0
  fi
  log "pipx not on PATH — installing apt package pipx"
  if ! sudo apt-get install -y pipx; then
    log "ERROR: apt install pipx failed"
    return 1
  fi
  if ! command -v pipx >/dev/null 2>&1; then
    log "ERROR: pipx still missing after apt install"
    return 1
  fi
  pipx ensurepath >/dev/null 2>&1 || true
}

install_samsungtv() {
  ensure_pipx || return 1

  if samsungtv_installed && [[ "${SAMSUNGTV_FORCE:-0}" != 1 ]]; then
    log "OK   samsungtv already at $(samsungtv_cli_path)"
    return 0
  fi

  log "pipx install ${SAMSUNGTV_PIPX_SPEC}"
  if pipx list --short 2>/dev/null | awk '{print $1}' | grep -qx "$SAMSUNGTV_PIPX_PKG"; then
    if ! pipx upgrade "$SAMSUNGTV_PIPX_PKG"; then
      log "WARN pipx upgrade ${SAMSUNGTV_PIPX_PKG} failed — trying reinstall"
      pipx install --force "$SAMSUNGTV_PIPX_SPEC" || {
        log "ERROR: pipx install ${SAMSUNGTV_PIPX_SPEC} failed"
        return 1
      }
    fi
  else
    pipx install "$SAMSUNGTV_PIPX_SPEC" || {
      log "ERROR: pipx install ${SAMSUNGTV_PIPX_SPEC} failed"
      return 1
    }
  fi

  if ! samsungtv_installed; then
    log "ERROR: samsungtv missing after pipx install"
    return 1
  fi
  log "OK   samsungtv at $(samsungtv_cli_path)"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  install_samsungtv
fi
