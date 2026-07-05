#!/usr/bin/env bash
# Restore the IndianaDell software stack on a fresh Ubuntu install.
# Does NOT partition disks, install ZFS, or flash BIOS — software only.
#
# Usage:
#   ./scripts/rebuild/rebuild-machine.sh           # full restore
#   ./scripts/rebuild/rebuild-machine.sh --verify-only
#   SKIP_TELEGRAM=1 ./scripts/rebuild/rebuild-machine.sh
#   SKIP_HACKRF_BUILD=1 ./scripts/rebuild/rebuild-machine.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG="${ROOT}/scripts/rebuild/last-run.log"
VERIFY_ONLY=0

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "$LOG"; }
die() { log "ERROR: $*"; exit 1; }

for arg in "$@"; do
  case "$arg" in
    --verify-only) VERIFY_ONLY=1 ;;
    -h|--help)
      sed -n '2,9p' "$0"
      exit 0
      ;;
    *) die "Unknown argument: $arg (try --help)" ;;
  esac
done

# shellcheck source=package-lists.sh
source "$(dirname "${BASH_SOURCE[0]}")/package-lists.sh"

verify_stack() {
  local fail=0
  log "=== Verification ==="
  for p in "${APT_CORE[@]}" "${APT_SDR_HAM[@]}"; do
    if ! dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q 'install ok installed'; then
      log "MISS apt: $p"
      fail=1
    fi
  done
  for c in rustc cargo gnuradio-config-info grcc gqrx fldigi wsjtx chirpw hackrf_info inspectrum pandoc xelatex vkcube; do
    command -v "$c" >/dev/null || { log "MISS cmd: $c"; fail=1; }
  done
  [[ -x "${ROOT}/hackrf/venv-urh/bin/urh" ]] || { log "MISS: URH venv"; fail=1; }
  [[ -f "${ROOT}/hackrf/releases/FIRMWARE_mayhem_v2.4.0.zip" ]] || { log "MISS: Mayhem firmware zip"; fail=1; }
  [[ -d "${ROOT}/hackrf/sd-card/mayhem-v2.4.0/APPS" ]] || { log "MISS: Mayhem SD tree"; fail=1; }
  [[ -x "${ROOT}/hackrf/build/hackrf-tools/src/hackrf_sweep" ]] || { log "MISS: hackrf_sweep (built)"; fail=1; }
  for b in dellmerge gpu-stress iotest apply-amdgpu rebuild-machine; do
    [[ -x "${ROOT}/bin/$b" ]] || { log "MISS bin: $b"; fail=1; }
  done
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
echo 'xastir xastir/install-setuid boolean false' | sudo debconf-set-selections

log "Phase 1: apt update"
sudo apt-get update -qq

log "Phase 2: core + dev packages (${#APT_CORE[@]})"
sudo apt-get install -y "${APT_CORE[@]}"

log "Phase 3: SDR / ham / HackRF packages (${#APT_SDR_HAM[@]})"
sudo apt-get install -y "${APT_SDR_HAM[@]}"

if [[ "${SKIP_TELEGRAM:-0}" != 1 ]]; then
  log "Phase 4: Flatpak + Telegram"
  if ! flatpak remote-list | grep -q flathub; then
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  fi
  flatpak install -y flathub org.telegram.desktop 2>&1 | tee -a "$LOG" || log "WARN: Telegram flatpak install failed (non-fatal)"
fi

log "Phase 5: Rust (rustup)"
if ! command -v rustc >/dev/null; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile default
fi
# shellcheck disable=SC1091
[[ -f "${HOME}/.cargo/env" ]] && source "${HOME}/.cargo/env"
rustc --version | tee -a "$LOG"

log "Phase 6: HackRF repos"
mkdir -p "${ROOT}/hackrf/repos"
clone_if_missing() {
  local url="$1" name="$2"
  if [[ -d "${ROOT}/hackrf/repos/${name}/.git" ]]; then
    log "  skip clone $name"
  else
    git clone --depth 1 "$url" "${ROOT}/hackrf/repos/${name}"
  fi
}
clone_if_missing https://github.com/greatscottgadgets/hackrf.git hackrf
clone_if_missing https://github.com/portapack-mayhem/mayhem-firmware.git mayhem-firmware
clone_if_missing https://github.com/sharebrained/portapack-hackrf.git portapack-hackrf
clone_if_missing https://github.com/jopohl/urh.git urh
clone_if_missing https://github.com/fsphil/hacktv.git hacktv
if [[ ! -f "${ROOT}/hackrf/repos/mayhem-firmware/hackrf/firmware/CMakeLists.txt" ]]; then
  git -C "${ROOT}/hackrf/repos/mayhem-firmware" submodule update --init --recursive
fi

if [[ "${SKIP_HACKRF_BUILD:-0}" != 1 ]]; then
  log "Phase 7: Build HackRF host tools"
  mkdir -p "${ROOT}/hackrf/build"
  cmake -S "${ROOT}/hackrf/repos/hackrf/host" -B "${ROOT}/hackrf/build" -DCMAKE_INSTALL_PREFIX="${ROOT}/hackrf/local"
  cmake --build "${ROOT}/hackrf/build" -j"$(nproc)"
fi

log "Phase 8: Mayhem firmware + SD card assets"
"${ROOT}/hackrf/scripts/download-mayhem.sh" 2>&1 | tee -a "$LOG"
"${ROOT}/hackrf/scripts/prepare-sdcard.sh" 2>&1 | tee -a "$LOG"

log "Phase 9: URH virtualenv"
if [[ ! -x "${ROOT}/hackrf/venv-urh/bin/urh" ]]; then
  python3 -m venv "${ROOT}/hackrf/venv-urh"
  "${ROOT}/hackrf/venv-urh/bin/pip" install -U pip wheel
  "${ROOT}/hackrf/venv-urh/bin/pip" install urh
fi

log "Phase 10: udev + bin permissions"
"${ROOT}/hackrf/scripts/setup-udev.sh" 2>&1 | tee -a "$LOG"
chmod +x "${ROOT}/bin/"* "${ROOT}/scripts/"*/*.sh "${ROOT}/scripts/rebuild/"*.sh 2>/dev/null || true
chmod +x "${ROOT}/amd-radeon/"*.sh "${ROOT}/hackrf/scripts/"*.sh 2>/dev/null || true

save_manifests

log "Phase 11: verify"
if verify_stack; then
  log "Rebuild complete."
  log "Optional: sudo bin/apply-amdgpu && reboot"
  log "Optional: bin/amd-install (ROCm — machine-specific)"
  log "Docs: bin/build-software-manual"
else
  die "Rebuild finished with verification failures — see $LOG"
fi