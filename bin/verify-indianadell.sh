#!/usr/bin/env bash
#
# verify-indianadell.sh
# Thin wrapper that runs the IndianaDell compatibility checker in verify-only mode.
#
# This is the read-only counterpart to fix-indianadell.sh.
# It never modifies the system; it only reports what is missing.
#
# Usage:
#   bin/verify-indianadell.sh
#   bin/verify-indianadell.sh --essential-only
#
exec "$(dirname "${BASH_SOURCE[0]}")/fix-indianadell.sh" --verify-only "$@"