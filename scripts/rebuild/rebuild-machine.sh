#!/usr/bin/env bash
# Restore the IndianaDell software stack on a fresh Ubuntu install.
# Does NOT partition disks, install ZFS, or flash BIOS — software only.
#
# SDR / ham / HackRF are installed from DragonSDR when present:
#   ~/Documents/DragonSDR/bin/install-suite
#
# Usage:
#   ./scripts/rebuild/rebuild-machine.sh           # full restore
#   ./scripts/rebuild/rebuild-machine.sh --verify-only
#   SKIP_TELEGRAM=1 ./scripts/rebuild/rebuild-machine.sh
#   SKIP_DRAGONSDR=1 ./scripts/rebuild/rebuild-machine.sh
#   SKIP_HACKRF_BUILD=1 ./scripts/rebuild/rebuild-machine.sh   # forwarded to DragonSDR
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG="${ROOT}/scripts/rebuild/last-run.log"
DRAGONSDR_ROOT="${DRAGONSDR_ROOT:-$HOME/Documents/DragonSDR}"
VERIFY_ONLY=0

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "$LOG"; }
die() { log "ERROR: $*"; exit 1; }

for arg in "$@"; do
  case "$arg" in
    --verify-only) VERIFY_ONLY=1 ;;
    -h|--help)
      sed -n '2,14p' "$0"
      exit 0
      ;;
    *) die "Unknown argument: $arg (try --help)" ;;
  esac
done

# shellcheck source=package-lists.sh
source "$(dirname "${BASH_SOURCE[0]}")/package-lists.sh"

dragonsdr_install() {
  local suite="${DRAGONSDR_ROOT}/bin/install-suite"
  if [[ ! -x "$suite" ]]; then
    suite="${DRAGONSDR_ROOT}/tools/install-suite.sh"
  fi
  [[ -x "$suite" ]] || return 1
  "$suite" "$@"
}

verify_stack() {
  local fail=0
  log "=== Verification ==="
  for p in "${APT_CORE[@]}"; do
    if ! dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q 'install ok installed'; then
      log "MISS apt: $p"
      fail=1
    fi
  done
  for c in rustc cargo pandoc xelatex vkcube; do
    command -v "$c" >/dev/null || { log "MISS cmd: $c"; fail=1; }
  done
  for b in dellmerge gpu-stress iotest apply-amdgpu rebuild-machine; do
    [[ -x "${ROOT}/bin/$b" ]] || { log "MISS bin: $b"; fail=1; }
  done

  if [[ "${SKIP_DRAGONSDR:-0}" == 1 ]]; then
    log "SKIP DragonSDR verification"
  elif [[ -x "${DRAGONSDR_ROOT}/bin/install-suite" ]] || [[ -x "${DRAGONSDR_ROOT}/tools/install-suite.sh" ]]; then
    if dragonsdr_install --verify-only; then
      log "OK   DragonSDR suite"
    else
      log "MISS DragonSDR suite (run bin/install-dragonsdr)"
      fail=1
    fi
  else
    log "WARN DragonSDR not found at ${DRAGONSDR_ROOT} — SDR suite not verified"
  fi

  if flatpak list --app 2>/dev/null | grep -q org.telegram.desktop; then
    log "OK   flatpak: Telegram"
  elif [[ "${SKIP_TELEGRAM:-0}" == 1 ]]; then
    log "SKIP flatpak: Telegram"
  else
    log "MISS flatpak: Telegram"
    fail=1
  fi
  if [[ "$fail" -eq 0 ]]; then
    log "All checks passed."
  else
    log "Some checks failed."
    return 1
  fi
}

save_manifests() {
  mkdir -p "${ROOT}/scripts/rebuild"
  dpkg-query -W -f='${Package}\n' | sort > "${ROOT}/apt-full-manifest.txt"
  dpkg-query -W -f='${Package}\n' 2>/dev/null | grep -iE \
    'gnuradio|hamlib|gr-|fldigi|wsjtx|rtl-sdr|hackrf|soapysdr|gqrx|quisk|chirp|direwolf|gpredict|grig|xastir|uhd|limesuite|airspy|bladerf|python3-dev|build-essential|cmake|librtlsdr|libhackrf|libuhd|libvolk|libfftw|portaudio|libclang|clang|llvm-dev|libssl-dev|libusb|libsndfile|libboost|pandoc|texlive|vulkan|mesa-utils|clinfo|flatpak' \
    | sort > "${ROOT}/apt-hamradio-dev-manifest.txt"
  log "Saved apt-full-manifest.txt and apt-hamradio-dev-manifest.txt"
}

if [[ "$VERIFY_ONLY" -eq 1 ]]; then
  verify_stack
  exit $?
fi

: >"$LOG"
log "IndianaDell rebuild starting (ROOT=$ROOT)"

command -v apt-get >/dev/null || die "apt-get not found — is this Ubuntu/Debian?"
[[ "$(id -u)" -eq 0 ]] && die "Run as normal user; script will call sudo for apt."

export DEBIAN_FRONTEND=noninteractive

log "Phase 1: apt update"
sudo apt-get update -qq

log "Phase 2: core + workstation packages (${#APT_CORE[@]})"
sudo apt-get install -y "${APT_CORE[@]}"

if [[ "${SKIP_TELEGRAM:-0}" != 1 ]]; then
  log "Phase 3: Flatpak + Telegram"
  if ! flatpak remote-list | grep -q flathub; then
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  fi
  flatpak install -y flathub org.telegram.desktop 2>&1 | tee -a "$LOG" || log "WARN: Telegram flatpak install failed (non-fatal)"
fi

log "Phase 4: Rust (rustup)"
if ! command -v rustc >/dev/null; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile default
fi
# shellcheck disable=SC1091
[[ -f "${HOME}/.cargo/env" ]] && source "${HOME}/.cargo/env"
rustc --version | tee -a "$LOG"

if [[ "${SKIP_DRAGONSDR:-0}" == 1 ]]; then
  log "Phase 5: SKIP DragonSDR (SKIP_DRAGONSDR=1)"
elif dragonsdr_install; then
  log "Phase 5: DragonSDR suite installed"
else
  log "WARN Phase 5: DragonSDR not found at ${DRAGONSDR_ROOT}"
  log "  Clone: git clone https://github.com/webaugur/DragonSDR.git ${DRAGONSDR_ROOT}"
  log "  Then:  ${ROOT}/bin/install-dragonsdr"
fi

log "Phase 6: bin permissions"
chmod +x "${ROOT}/bin/"* "${ROOT}/scripts/"*/*.sh "${ROOT}/scripts/rebuild/"*.sh 2>/dev/null || true
chmod +x "${ROOT}/amd-radeon/"*.sh 2>/dev/null || true

save_manifests

log "Phase 7: verify"
if verify_stack; then
  log "Rebuild complete."
  log "Optional: sudo bin/apply-amdgpu && reboot"
  log "Optional: bin/amd-install (ROCm — machine-specific)"
  log "SDR: bin/install-dragonsdr  (or DragonSDR bin/install-suite)"
  log "Docs: bin/build-software-manual"
else
  die "Rebuild finished with verification failures — see $LOG"
fi
