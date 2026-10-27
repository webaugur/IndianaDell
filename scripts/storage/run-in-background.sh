#!/usr/bin/env bash
# Run a command at the lowest CPU and disk priority so the desktop wins.
# Usage: bin/run-in-background cargo build --release
[[ $# -gt 0 ]] || { sed -n '2,4p' "$0"; exit 1; }
exec ionice -c3 nice -n 19 "$@"
