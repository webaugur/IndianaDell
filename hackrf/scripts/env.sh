#!/usr/bin/env bash
# Source this file:  . ~/Documents/IndianaDell/hackrf/scripts/env.sh
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export HACKRF_HOME="$ROOT"
export PATH="$ROOT/build/hackrf-tools/src:$ROOT/local/bin:${HOME}/.cargo/bin:$PATH"
export LD_LIBRARY_PATH="$ROOT/build/libhackrf/src:${LD_LIBRARY_PATH:-}"
alias urh='"$ROOT/venv-urh/bin/urh"'
alias mayhem-build='"$ROOT/scripts/build-mayhem.sh"'
alias mayhem-flash='"$ROOT/scripts/flash-mayhem.sh"'
alias mayhem-sdcard='"$ROOT/scripts/prepare-sdcard.sh"'