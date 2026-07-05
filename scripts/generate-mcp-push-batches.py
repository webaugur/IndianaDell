#!/usr/bin/env python3
"""Generate JSON batch files for GitHub MCP push_files."""
from __future__ import annotations

import base64
import json
import os
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
OUT = Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/indianadell-push-batches")
OWNER = "webaugur"
REPO_NAME = "IndianaDell"
BRANCH = "main"
MAX_FILES = 40
MAX_BYTES = 4_500_000


def file_entry(path: str) -> dict | None:
    full = REPO / path
    if not full.is_file():
        return None
    data = full.read_bytes()
    if len(data) > 500_000:
        return None
    try:
        text = data.decode("utf-8")
        return {"path": path, "content": text}
    except UnicodeDecodeError:
        return {
            "path": path,
            "content": base64.b64encode(data).decode("ascii"),
            "encoding": "base64",
        }


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    files = subprocess.check_output(["git", "ls-files"], cwd=REPO, text=True).strip().split("\n")

    batch: list[dict] = []
    batch_bytes = 0
    batch_idx = 0
    skipped = 0

    for path in files:
        entry = file_entry(path)
        if entry is None:
            skipped += 1
            continue
        size = len(entry["content"].encode("utf-8"))
        if batch and (len(batch) >= MAX_FILES or batch_bytes + size > MAX_BYTES):
            out = OUT / f"batch-{batch_idx:04d}.json"
            payload = {
                "owner": OWNER,
                "repo": REPO_NAME,
                "branch": BRANCH,
                "message": f"Sync IndianaDell batch {batch_idx}",
                "files": batch,
            }
            out.write_text(json.dumps(payload), encoding="utf-8")
            batch_idx += 1
            batch = []
            batch_bytes = 0
        batch.append(entry)
        batch_bytes += size

    if batch:
        out = OUT / f"batch-{batch_idx:04d}.json"
        payload = {
            "owner": OWNER,
            "repo": REPO_NAME,
            "branch": BRANCH,
            "message": f"Sync IndianaDell batch {batch_idx}",
            "files": batch,
        }
        out.write_text(json.dumps(payload), encoding="utf-8")
        batch_idx += 1

    print(f"Wrote {batch_idx} batches to {OUT} (skipped {skipped} large/missing files)")
    print("Push with: scripts/push-mcp-batches.sh")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())