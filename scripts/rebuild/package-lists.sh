# IndianaDell apt package lists — single source of truth for *workstation* restore.
# Sourced by scripts/rebuild/rebuild-machine.sh and documented in
# docs/software-manual/appendix-b-apt-packages.md (keep in sync).
#
# SDR / ham / HackRF packages live in DragonSDR:
#   ~/Documents/DragonSDR/tools/package-lists.sh
# Install via: bin/install-dragonsdr  (or DragonSDR bin/install-suite)
#
# shellcheck shell=bash

APT_CORE=(
  build-essential cmake pkg-config git curl wget unzip
  python3-pip python3-venv python3-dev
  python3-numpy python3-scipy python3-matplotlib python3-yaml python3-requests python3-pyqt5 python3-psutil
  libssl-dev clang llvm-dev libclang-dev
  libusb-1.0-0-dev libfftw3-dev libvolk-dev portaudio19-dev libsndfile1-dev
  libboost-dev libboost-program-options-dev
  pandoc texlive-latex-recommended texlive-fonts-recommended texlive-xetex
  vulkan-tools mesa-utils mesa-utils-bin clinfo flatpak gh
)

# Legacy name kept empty so older docs/scripts that reference APT_SDR_HAM do not expand unbound.
# Prefer DragonSDR APT_SUITE via bin/install-dragonsdr.
APT_SDR_HAM=()
