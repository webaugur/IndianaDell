#!/usr/bin/env bash
# Idempotent KiCad 10.0 releases PPA for workstation rebuild.
# Sourced by rebuild-machine.sh and bin/fix-indianadell.sh.
# Uses the running distro codename (resolute, etc.) via add-apt-repository.
#
# shellcheck shell=bash

if ! declare -F log >/dev/null 2>&1; then
  log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
fi

ensure_kicad_ppa() {
  local sources_dir=/etc/apt/sources.list.d
  local found=0 f

  shopt -s nullglob
  for f in \
    "$sources_dir"/kicad-ubuntu-kicad-10_0-releases-*.sources \
    "$sources_dir"/kicad-ubuntu-kicad-10.0-releases-*.sources \
    "$sources_dir"/kicad-ubuntu-kicad-10_0-releases-*.list \
    "$sources_dir"/kicad-ubuntu-kicad-10.0-releases-*.list; do
    if [[ -f "$f" ]]; then
      found=1
      break
    fi
  done
  shopt -u nullglob

  if [[ "$found" -eq 0 ]]; then
    if ! command -v add-apt-repository >/dev/null 2>&1; then
      log "Installing software-properties-common (add-apt-repository missing)"
      sudo apt-get install -y software-properties-common || {
        log "ERROR: cannot install software-properties-common (needed for KiCad PPA)"
        return 1
      }
    fi
    log "Adding ppa:kicad/kicad-10.0-releases"
    sudo add-apt-repository -y ppa:kicad/kicad-10.0-releases || {
      log "ERROR: failed to add ppa:kicad/kicad-10.0-releases"
      return 1
    }
  else
    log "KiCad 10.0 PPA already present"
  fi
  sudo apt-get update -qq
}
