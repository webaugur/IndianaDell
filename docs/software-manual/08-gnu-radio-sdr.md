# Chapter 8 — GNU Radio and Desktop SDR

## What gets installed

| Component | Version | Packages / path |
|-----------|---------|-----------------|
| GNU Radio | 3.10.12.0 | `gnuradio`, `gnuradio-dev`, `gnuradio-doc` |
| Companion blocks | apt | `gr-osmosdr`, `gr-limesdr`, `gr-fosphor`, `gr-air-modes`, `gr-hpsdr`, `gr-dab`, `gr-satellites` |
| SoapySDR | apt + Python | `libsoapysdr-dev`, `python3-soapysdr`, modules |
| Hardware libs | apt | RTL-SDR, HackRF, Airspy, bladeRF, Lime, UHD |
| Desktop apps | apt | `gqrx-sdr`, `quisk`, `inspectrum`, `hacktv` |

**SoapySDR modules on this host:** HackRF, RTL-SDR (osmosdr), Airspy, bladeRF, Lime, MiriSDR, HydraSDR, PlutoSDR, Red Pitaya, remote, audio, UHD.

## How it is installed

All packages in `APT_SDR_HAM` (rebuild Phase 3). Dev libraries in `APT_CORE` support building OOT modules.

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
gnuradio-config-info --version
grcc --help | head -1
python3 -c "import gnuradio; print(gnuradio.__version__)"
python3 -c "import SoapySDR; print('SoapySDR OK')"
SoapySDRUtil --info
gqrx --version 2>/dev/null || command -v gqrx
```

With hardware attached:

```bash
rtl_test -t                  # RTL-SDR
hackrf_info                  # HackRF
```

## How to customize

- Add OOT modules: `sudo apt install gr-<name>` or build from source against `gnuradio-dev`
- GPU waterfall: `gr-fosphor` blocks in flowgraphs
- Filtered apt list: `apt-hamradio-dev-manifest.txt` (178 SDR/ham-related packages on full system)

## What rebuild does / does not do

| Does | Does not |
|------|----------|
| Install full GNU Radio + gr-* stack | Calibrate specific SDR hardware |
| Install gqrx, quisk, inspectrum | Install SDRangel or SigDigger |
| Verify `gnuradio-config-info`, `grcc`, `gqrx` in verify_stack | Flash firmware on SDR devices |