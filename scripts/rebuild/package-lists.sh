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
  vulkan-tools mesa-utils mesa-utils-bin clinfo x11-apps flatpak gh
  smartmontools ddcutil arduino-cli
  # Wayland clipboard + Qt/GNOME theming (see bin/fix-desktop-integration.sh)
  wl-clipboard copyq adwaita-qt adwaita-qt6 qt6-gtk-platformtheme qt5-gtk-platformtheme
)

# KiCad 10 (EDA) — optional but installed by default on workstation rebuild.
# Requires PPA: ppa:kicad/kicad-10.0-releases (see ensure_kicad_ppa in
# scripts/rebuild/ensure-kicad-ppa.sh). Opt out: SKIP_KICAD=1
# kicad-doc-id is omitted until the PPA ships 10.x (universe is still 9.0.8).
APT_KICAD=(
  kicad
  kicad-libraries          # pulls symbols, footprints, packages3d, templates
  kicad-symbols
  kicad-footprints
  kicad-packages3d         # large (~1GB+); keep — “useful options” includes 3D
  kicad-templates
  kicad-demos
  kicad-dbg
  kicad-doc-en
  kicad-doc-de
  kicad-doc-fr
  kicad-doc-es
  kicad-doc-it
  kicad-doc-ja
  kicad-doc-pl
  kicad-doc-ru
  kicad-doc-zh
  kicad-doc-ca
  kicad-gruvbox-theme
  ngspice                  # Eeschema / simulation companion
  gerbv                    # standalone Gerber viewer (optional companion)
  nodejs                   # tscircuit CLI (TypeScript → KiCad)
  npm
)

# Legacy name kept empty so older docs/scripts that reference APT_SDR_HAM do not expand unbound.
# Prefer DragonSDR APT_SUITE via bin/install-dragonsdr.
APT_SDR_HAM=()
