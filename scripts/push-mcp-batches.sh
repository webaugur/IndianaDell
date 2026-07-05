#!/usr/bin/env bash
# Push pre-generated MCP batch files using grok CLI + GitHub MCP.
set -euo pipefail

BATCH_DIR="${1:-/tmp/indianadell-push-batches}"
GROK="${GROK_BIN:-grok}"

if ! command -v "$GROK" >/dev/null; then
    echo "error: grok CLI not found (set GROK_BIN)" >&2
    exit 1
fi

shopt -s nullglob
batches=("$BATCH_DIR"/batch-*.json)
if ((${#batches[@]} == 0)); then
    echo "error: no batch files in $BATCH_DIR" >&2
    exit 1
fi

for batch in "${batches[@]}"; do
    echo "Pushing $(basename "$batch") ..."
    "$GROK" -p "Read ${batch} and call the GitHub MCP push_files tool (server grok_com_github) with the JSON object fields as arguments (owner, repo, branch, message, files). Return only commit sha and repo URL." \
        --yolo \
        --cwd /home/user/Documents/IndianaDell \
        --max-turns 8 \
        --output-format plain
done

echo "MCP batch push complete."