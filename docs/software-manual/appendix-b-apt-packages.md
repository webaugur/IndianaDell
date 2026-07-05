# Appendix B — Apt Packages by Chapter

**Source of truth:** `scripts/rebuild/package-lists.sh` (`APT_CORE` + `APT_SDR_HAM`).  
**Total:** 90 packages installed by `bin/rebuild-machine` (37 core + 53 SDR/ham).  
**Full system snapshot:** `apt-full-manifest.txt` (~2257 packages after rebuild).  
**SDR/ham filter:** `apt-hamradio-dev-manifest.txt` (~178 related packages).

Packages below are grouped by manual chapter. Shared dev libraries appear under Chapter 4 and are reused by Chapters 8–10.

## Chapter 4 — Development

`build-essential`, `cmake`, `pkg-config`, `git`, `curl`, `wget`, `unzip`, `python3-pip`, `python3-venv`, `python3-dev`, `python3-numpy`, `python3-scipy`, `python3-matplotlib`, `python3-yaml`, `python3-requests`, `python3-pyqt5`, `python3-psutil`, `libssl-dev`, `clang`, `llvm-dev`, `libclang-dev`, `libusb-1.0-0-dev`, `libfftw3-dev`, `libvolk-dev`, `portaudio19-dev`, `libsndfile1-dev`, `libboost-dev`, `libboost-program-options-dev`, `pandoc`, `texlive-latex-recommended`, `texlive-fonts-recommended`, `texlive-xetex`

## Chapter 6 — GPU and Display

`vulkan-tools`, `mesa-utils`, `mesa-utils-bin`, `clinfo`

## Chapter 8 — GNU Radio and SDR

`gnuradio`, `gnuradio-dev`, `gnuradio-doc`, `gr-osmosdr`, `gr-limesdr`, `gr-fosphor`, `gr-air-modes`, `gr-hpsdr`, `gr-dab`, `gr-satellites`, `libsoapysdr-dev`, `python3-soapysdr`, `soapysdr-module-osmosdr`, `soapysdr-module-mirisdr`, `uhd-soapysdr`, `rtl-sdr`, `librtlsdr-dev`, `airspy`, `libairspy-dev`, `bladerf`, `libbladerf-dev`, `limesuite`, `limesuite-udev`, `uhd-host`, `libuhd-dev`, `gqrx-sdr`, `quisk`, `inspectrum`, `hacktv`

## Chapter 9 — Ham Radio

`libhamlib-dev`, `libhamlib-utils`, `python3-hamlib`, `fldigi`, `wsjtx`, `wsjtx-data`, `chirp`, `direwolf`, `gpredict`, `grig`, `xastir`, `xastir-data`

## Chapter 10 — HackRF and Mayhem

`hackrf`, `hackrf-firmware`, `libhackrf-dev`, `hackrf-doc`, `dfu-util`, `openocd`, `gcc-arm-none-eabi`, `binutils-arm-none-eabi`, `libnewlib-arm-none-eabi`, `ccache`, `lz4`, `bzip2`

(Also uses Chapter 8 packages for GNU Radio/SoapySDR integration.)

## Chapter 11 — Flatpak

`flatpak` (application `org.telegram.desktop` installed via flatpak, not apt)

## Chapters 5, 7, 12, 13 — No dedicated apt arrays

Themes, GNOME prefs, machine utilities, and FactoryDocs use workspace scripts or Ubuntu desktop packages already on the base install (`gdm3`, `gnome-shell`, `plymouth`, Yaru themes) — not enumerated separately in `package-lists.sh`.