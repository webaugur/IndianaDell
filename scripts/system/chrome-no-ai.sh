#!/bin/bash
# Turn off Chrome's generative-AI features, including AI Mode in the address bar and New Tab page.
# Values: GenAiDefaultSettings 2 = disable covered AI features; AIModeSettings 1 = block AI Mode (only 0/1 are valid);
# GeminiSettings 1 = disable Gemini. "Ask Google about this page" is left alone on purpose.
# Run:  sudo bash chrome-no-ai.sh   then restart Chrome and check chrome://policy
set -eu
[ "$(id -u)" -eq 0 ] || { echo "Run with sudo." >&2; exit 1; }
D=/etc/opt/chrome/policies/managed
mkdir -p "$D"
cat > "$D/indianadell-no-ai.json" <<'J'
{
  "GenAiDefaultSettings": 2,
  "AIModeSettings": 1,
  "GeminiSettings": 1
}
J
echo "Wrote $D/indianadell-no-ai.json. Fully quit and reopen Chrome, then check chrome://policy."
echo "Undo: delete that file."
