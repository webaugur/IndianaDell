#!/usr/bin/env bash
# Seed Ventoy persistence (if needed), then launch Grok fullscreen in Ptyxis.
set -euo pipefail

WORKDIR="${GROK_WORKDIR:-/home/ubuntu/Documents/IndianaDell}"
SESSION_ID="${GROK_SESSION_ID:-0e3b583e-38da-4bf9-870a-0c54a421ce2b}"
GROK_BIN="${GROK_BIN:-$HOME/.grok/bin/grok}"
SEED_SCRIPT="${SEED_SCRIPT:-$HOME/bin/seed-ventoy-persistence.sh}"
MARKER="$HOME/.cache/grok-autostart-once"

mkdir -p "$(dirname "$MARKER")" "$WORKDIR"

if [[ ! -x "$GROK_BIN" ]]; then
    printf 'grok-indianadell-launch: %s not found\n' "$GROK_BIN" >&2
    exit 1
fi

# Avoid duplicate windows if the desktop file fires more than once per login.
if [[ -f "$MARKER" ]]; then
    age=$(( $(date +%s) - $(stat -c %Y "$MARKER") ))
    if (( age < 120 )); then
        exit 0
    fi
fi
touch "$MARKER"

# Sync session state into persistence before resuming Grok.
if [[ -x "$SEED_SCRIPT" ]]; then
    "$SEED_SCRIPT" || printf 'grok-indianadell-launch: seed failed (continuing)\n' >&2
fi

cd "$WORKDIR"

exec ptyxis \
    --fullscreen \
    --working-directory="$WORKDIR" \
    --title="Grok — IndianaDell" \
    -- \
    "$GROK_BIN" -r "$SESSION_ID" --always-approve