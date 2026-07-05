# Chapter 4 — Development Toolchain

## What gets installed

| Component | Version / path | Install source |
|-----------|----------------|----------------|
| Python | 3.14 (system) | Ubuntu base + apt |
| pip, venv | apt | `python3-pip`, `python3-venv` |
| numpy, scipy, matplotlib | apt | science stack |
| PyQt5 | apt | GNU Radio Companion, some tools |
| Rust | 1.96.1 stable | rustup to `~/.cargo/bin` |
| C/C++ build | apt | `build-essential`, `cmake`, `pkg-config` |
| Clang/LLVM | apt | bindgen-style Rust, native tooling |
| SSL/USB/FFTW/Volk | apt dev libs | SDR and native builds |
| ARM cross-compile | apt | PortaPack Mayhem firmware (`gcc-arm-none-eabi`) |
| pandoc + XeLaTeX | apt | Manual PDF generation |
| Git, curl, wget | apt | repos and downloads |

**Python bindings verified on this host:** `gnuradio`, `SoapySDR`, `Hamlib` (capital H in Python).

**Project venv:** URH lives in `hackrf/venv-urh/` (Chapter 10), not system-wide.

## How it is installed

**Apt (rebuild Phase 2):** packages listed in Appendix B under "Development" and shared dev libraries.

**Rust (rebuild Phase 5):**

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
source ~/.cargo/env
```

Rebuild skips rustup if `rustc` is already on PATH.

## How to verify

```bash
python3 --version
python3 -c "import numpy, scipy, matplotlib; print('OK')"
. ~/.cargo/env && rustc --version && cargo --version
cmake --version | head -1
arm-none-eabi-gcc --version | head -1
pandoc --version | head -1
xelatex --version | head -1
```

## How to customize

- **New Python project venv:** `python3 -m venv myproject/.venv && . myproject/.venv/bin/activate`
- **Rust toolchain:** `rustup toolchain install stable`, `rustup component add clippy`
- **Per-project Rust SDR crates:** `cargo add rtlsdr` etc. — no workspace scaffold ships with IndianaDell
- **Manual PDF:** `bin/build-software-manual` or pandoc on any `.md` in the repo

## What rebuild does / does not do

| Does | Does not |
|------|----------|
| Install all dev apt packages | Create application-specific venvs beyond URH |
| Install rustup if missing | Pin a non-stable Rust toolchain |
| chmod workspace scripts | Install IDE or editor plugins |