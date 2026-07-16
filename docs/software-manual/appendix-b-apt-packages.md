# Appendix B — Apt Packages by Chapter

**Workstation packages:** `scripts/rebuild/package-lists.sh` (`APT_CORE` only).  
**SDR / ham / HackRF packages:** `~/Documents/DragonSDR/tools/package-lists.sh` (`APT_SDR`, `APT_HAM`, `APT_SDR_BUILD`).  
**Install SDR suite:** `bin/install-dragonsdr` → DragonSDR `bin/install-suite`.  
**Full system snapshot:** `apt-full-manifest.txt` (after rebuild).  
**SDR/ham filter snapshot:** `apt-hamradio-dev-manifest.txt`.

## Chapter 4 — Development (IndianaDell `APT_CORE`)

`build-essential`, `cmake`, `pkg-config`, `git`, `curl`, `wget`, `unzip`, `python3-pip`, `python3-venv`, `python3-dev`, `python3-numpy`, `python3-scipy`, `python3-matplotlib`, `python3-yaml`, `python3-requests`, `python3-pyqt5`, `python3-psutil`, `libssl-dev`, `clang`, `llvm-dev`, `libclang-dev`, `libusb-1.0-0-dev`, `libfftw3-dev`, `libvolk-dev`, `portaudio19-dev`, `libsndfile1-dev`, `libboost-dev`, `libboost-program-options-dev`, `pandoc`, `texlive-latex-recommended`, `texlive-fonts-recommended`, `texlive-xetex`, `gh`

## Chapter 6 — GPU and Display

`vulkan-tools`, `mesa-utils`, `mesa-utils-bin`, `clinfo`

## Chapter 8 — GNU Radio and SDR (DragonSDR `APT_SDR` + build libs)

`gnuradio`, `gnuradio-dev`, `gnuradio-doc`, `gr-osmosdr`, `gr-limesdr`, `gr-fosphor`, `gr-air-modes`, `gr-hpsdr`, `gr-dab`, `gr-satellites`, `libsoapysdr-dev`, `python3-soapysdr`, `soapysdr-module-osmosdr`, `soapysdr-module-mirisdr`, `uhd-soapysdr`, `rtl-sdr`, `librtlsdr-dev`, `airspy`, `libairspy-dev`, `bladerf`, `libbladerf-dev`, `limesuite`, `limesuite-udev`, `uhd-host`, `libuhd-dev`, `gqrx-sdr`, `quisk`, `inspectrum`, `hacktv`

## Chapter 9 — Ham Radio (DragonSDR `APT_HAM`)

`libhamlib-dev`, `libhamlib-utils`, `python3-hamlib`, `fldigi`, `wsjtx`, `wsjtx-data`, `chirp`, `direwolf`, `gpredict`, `grig`, `xastir`, `xastir-data`

## Chapter 10 — HackRF and Mayhem (DragonSDR `APT_SDR`)

`hackrf`, `hackrf-firmware`, `libhackrf-dev`, `hackrf-doc`, `dfu-util`, `openocd`, `gcc-arm-none-eabi`, `binutils-arm-none-eabi`, `libnewlib-arm-none-eabi`, `ccache`, `lz4`, `bzip2`

## Chapter 11 — Flatpak

`flatpak` (application `org.telegram.desktop` installed via flatpak, not apt)

## Chapters 5, 7, 12, 13 — No dedicated apt arrays

Themes, GNOME prefs, machine utilities, and FactoryDocs use workspace scripts or Ubuntu desktop packages already on the base install.
