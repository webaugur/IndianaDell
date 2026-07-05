#!/bin/bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
"$DIR/00-preflight.sh"
"$DIR/01-install-installer.sh"
"$DIR/02-install-drivers.sh"
"$DIR/03-set-groups.sh"
"$DIR/04-verify.sh"