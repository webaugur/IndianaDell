# Chapter 8 — GNU Radio and Desktop SDR

## Ownership

GNU Radio, SoapySDR, and desktop SDR apps are installed by the **DragonSDR** suite, not by IndianaDell apt lists.

| Item | Location |
|------|----------|
| Suite install | `~/Documents/DragonSDR/bin/install-suite` |
| Package list | `~/Documents/DragonSDR/tools/package-lists.sh` (`APT_SDR`) |
| IndianaDell wrapper | `bin/install-dragonsdr` |

## What gets installed

| Component | Packages / path |
|-----------|-----------------|
| GNU Radio | `gnuradio`, `gnuradio-dev`, `gnuradio-doc` |
| Companion blocks | `gr-osmosdr`, `gr-limesdr`, `gr-fosphor`, `gr-air-modes`, `gr-hpsdr`, `gr-dab`, `gr-satellites` |
| SoapySDR | `libsoapysdr-dev`, `python3-soapysdr`, modules |
| Hardware libs | RTL-SDR, HackRF, Airspy, bladeRF, Lime, UHD |
| Desktop apps | `gqrx-sdr`, `quisk`, `inspectrum`, `hacktv` |

**SoapySDR modules (typical host):** HackRF, RTL-SDR (osmosdr), Airspy, bladeRF, Lime, MiriSDR, HydraSDR, PlutoSDR, Red Pitaya, remote, audio, UHD.

## How it is installed

```bash
bin/install-dragonsdr              # full suite (apt + HackRF workspace)
# or only packages:
bin/install-dragonsdr --apt-only
```

Called automatically during `bin/rebuild-machine` when `~/Documents/DragonSDR` is present (`SKIP_DRAGONSDR=1` to skip).

**Typical workflow:**

```bash
grcc myflowgraph.grc          # compile Companion graph
gqrx                          # general receiver GUI
quisk                         # transceiver GUI
inspectrum capture.cf32       # visualize IQ files
```

For HackRF-specific host tools and URH, see Chapter 10.

## How to verify

```bash
bin/install-dragonsdr --verify-only
gnuradio-config-info --version
python3 -c "import SoapySDR; print('SoapySDR OK')"
SoapySDRUtil --info
command -v gqrx
```
