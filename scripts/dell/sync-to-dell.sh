#!/usr/bin/env bash
#
# sync-to-dell.sh
# Rsync IndianaDell (and optionally DragonSDR/McFloater/secrets) to another
# Dell workstation over SSH.
#
# Two primary target profiles:
#   1. Thumper (user@thumper.local) — full stack
#      IndianaDell + DragonSDR + full McFloater + secrets
#
#   2. Face-only desktop (smaller machine for McFloater avatar/GUI)
#      IndianaDell core + McFloater face/render + secrets
#      (no DragonSDR, no heavy ZFS data)
#
# Usage examples:
#   scripts/dell/sync-to-dell.sh user@thumper.local
#   scripts/dell/sync-to-dell.sh --face-only user@face-desktop.local
#   scripts/dell/sync-to-dell.sh --secrets --dry-run user@thumper.local
#
set -euo pipefail

DRY_RUN=0
WITH_SECRETS=0
DO_DELETE=0
FACE_ONLY=0
TARGET=""

usage() {
  sed -n '4,22p' "$0"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)   DRY_RUN=1; shift ;;
    --secrets)   WITH_SECRETS=1; shift ;;
    --delete)    DO_DELETE=1; shift ;;
    --face-only) FACE_ONLY=1; shift ;;
    -h|--help)   usage ;;
    *)
      if [[ -z "$TARGET" ]]; then
        TARGET="$1"
      else
        echo "Unknown argument: $1" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

[[ -n "$TARGET" ]] || { echo "ERROR: target host required (user@host)"; exit 1; }

# Robust ROOT detection:
# Works both when run from scripts/dell/ and when installed to ~/bin/
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/../../bin/fix-indianadell.sh" ]]; then
  # Running from inside the IndianaDell tree (scripts/dell/)
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
elif [[ -d "$HOME/Documents/IndianaDell" ]]; then
  # Installed to ~/bin/ or elsewhere — use the canonical location
  ROOT="$HOME/Documents/IndianaDell"
else
  echo "ERROR: Cannot locate IndianaDell tree. Set INDIANADELL_ROOT or run from inside the repo."
  exit 1
fi

# Safety: never allow ROOT to be / or /home
if [[ "$ROOT" == "/" || "$ROOT" == "/home" ]]; then
  echo "ERROR: Refusing to use ROOT=$ROOT (would rsync the entire home or filesystem)"
  exit 1
fi

RSYNC_OPTS=(-a --info=progress2)

if [[ $DRY_RUN -eq 1 ]]; then
  RSYNC_OPTS+=(--dry-run)
fi
if [[ $DO_DELETE -eq 1 ]]; then
  RSYNC_OPTS+=(--delete)
fi

# --- Secret handling (re-uses logic from resolve-secrets.sh) -----------------
INDIANADELL_SECRET_REL_PATHS=( .ssh .grok .config/gh )

resolve_secret_source() {
  if command -v zpool >/dev/null 2>&1 && zpool list -H -o name rpool &>/dev/null; then
    if [[ -d /home/user && -f /home/user/.ssh/id_rsa ]]; then
      printf '/home/user\n'
      return 0
    fi
  fi
  printf '%s\n' "${HOME:?HOME not set}"
}

sync_tree() {
  local src="$1" dest="$2"
  echo ">>> rsync $src -> $TARGET:$dest"
  rsync "${RSYNC_OPTS[@]}" "$src/" "$TARGET:$dest/"
}

sync_secrets() {
  local src
  src="$(resolve_secret_source)"
  echo ">>> secrets source: $src"

  for rel in "${INDIANADELL_SECRET_REL_PATHS[@]}"; do
    if [[ -e "$src/$rel" ]]; then
      echo "    + $rel"
      rsync "${RSYNC_OPTS[@]}" --relative "$src/./$rel" "$TARGET:/home/user/"
    fi
  done
}

# --- Profile helpers ---------------------------------------------------------
is_thumper() {
  [[ "$TARGET" == *"thumper"* ]]
}

is_face_only_target() {
  [[ $FACE_ONLY -eq 1 ]]
}

# --- Main --------------------------------------------------------------------
echo "=== IndianaDell sync to $TARGET ==="
echo "Workspace: $ROOT"
[[ $DRY_RUN -eq 1 ]] && echo "(dry-run mode)"
[[ $WITH_SECRETS -eq 1 ]] && echo "(secrets enabled)"
[[ $DO_DELETE -eq 1 ]] && echo "(delete on target enabled)"
[[ $FACE_ONLY -eq 1 ]] && echo "(face-only profile)"

# 1. IndianaDell core
sync_tree "$ROOT" "/home/user/Documents/IndianaDell"

# 2. DragonSDR — full on Thumper, skipped for face-only
if is_thumper || [[ $FACE_ONLY -eq 0 ]]; then
  if [[ -d "$HOME/Documents/DragonSDR" ]]; then
    sync_tree "$HOME/Documents/DragonSDR" "/home/user/Documents/DragonSDR"
  else
    echo "NOTE: DragonSDR not found locally — skipping"
  fi
else
  echo "SKIP DragonSDR (face-only profile)"
fi

# 3. McFloater — full on Thumper, face-only subset on the small desktop
if [[ -d "$HOME/Documents/McFloater" ]]; then
  if is_face_only_target; then
    echo ">>> McFloater (face-only subset)"
    # Only the render + face crates + minimal runtime files
    rsync "${RSYNC_OPTS[@]}" \
      --include='crates/mcfloater-render/***' \
      --include='crates/mcfloater-lipsync/***' \
      --include='crates/mcfloater-core/***' \
      --include='crates/mcfloater-audio/***' \
      --include='assets/***' \
      --include='models/***' \
      --include='Cargo.toml' \
      --include='Cargo.lock' \
      --exclude='*' \
      "$HOME/Documents/McFloater/" "$TARGET:/home/user/Documents/McFloater/"
  else
    sync_tree "$HOME/Documents/McFloater" "/home/user/Documents/McFloater"
  fi
else
  echo "NOTE: McFloater not found locally — skipping"
fi

# 4. Optional secrets
if [[ $WITH_SECRETS -eq 1 ]]; then
  sync_secrets
fi

echo
echo "Sync complete."
[[ $DRY_RUN -eq 1 ]] && echo "(dry-run — nothing was actually changed on $TARGET)"