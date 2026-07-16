#!/usr/bin/env bash
# Pull IndianaDell + LFS; optional verify/docs.
# SDR nested clones live under DragonSDR (pull that repo separately).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=remote.sh
source "$ROOT/scripts/github/remote.sh"

VERIFY=0
BUILD_DOCS=0
PULL_DRAGONSDR=0

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

usage() {
  sed -n '2,20p' "$0"
}

for arg in "$@"; do
  case "$arg" in
    --verify) VERIFY=1 ;;
    --build-docs) BUILD_DOCS=1 ;;
    --dragonsdr) PULL_DRAGONSDR=1 ;;
    --rebuild-hackrf)
      echo "NOTE: --rebuild-hackrf moved to DragonSDR. Use:" >&2
      echo "  ${DRAGONSDR_ROOT:-$HOME/Documents/DragonSDR}/bin/install-suite" >&2
      echo "  (or SKIP_HACKRF_BUILD=0 after pulling DragonSDR)" >&2
      exit 1
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $arg (try --help)" >&2; exit 1 ;;
  esac
done

materialize_secrets() {
  if [[ -r "$HOME/bin/resolve-secrets.sh" ]]; then
    # shellcheck source=/dev/null
    source "$HOME/bin/resolve-secrets.sh"
    materialize_secrets_to_runtime_home quiet
  elif [[ -r "$ROOT/scripts/ventoy/resolve-secrets.sh" ]]; then
    # shellcheck source=/dev/null
    source "$ROOT/scripts/ventoy/resolve-secrets.sh"
    materialize_secrets_to_runtime_home quiet
  fi
}

ensure_git_lfs() {
  if ! command -v git-lfs >/dev/null; then
    log "Installing git-lfs (FactoryDocs large binaries)"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq git-lfs
  fi
  git lfs install >/dev/null
}

pull_main_repo() {
  log "=== IndianaDell (${INDIANADELL_BRANCH}) ==="
  cd "$ROOT"
  indianadell_ensure_origin "$ROOT"
  GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new}"
  export GIT_SSH_COMMAND
  git fetch origin --prune
  git pull --ff-only origin "${INDIANADELL_BRANCH}"
  ensure_git_lfs
  git lfs pull
  log "HEAD: $(git log --oneline -1)"
}

pull_dragonsdr() {
  local ds="${DRAGONSDR_ROOT:-$HOME/Documents/DragonSDR}"
  if [[ ! -d "${ds}/.git" ]]; then
    log "WARN: DragonSDR not a git repo at $ds — skip"
    return 0
  fi
  log "=== DragonSDR ==="
  git -C "$ds" fetch --all --prune
  local branch
  branch="$(git -C "$ds" symbolic-ref -q --short HEAD 2>/dev/null || echo main)"
  if git -C "$ds" rev-parse --verify "origin/${branch}" >/dev/null 2>&1; then
    git -C "$ds" pull --ff-only origin "$branch"
  else
    git -C "$ds" pull --ff-only 2>/dev/null || log "WARN: DragonSDR pull failed"
  fi
  log "  $(git -C "$ds" log --oneline -1)"
  # Nested hackrf/repos
  local repo
  for repo in "$ds"/hackrf/repos/*/; do
    [[ -d "${repo}/.git" ]] || continue
    name="$(basename "$repo")"
    log "=== DragonSDR hackrf/repos/${name} ==="
    git -C "$repo" fetch --all --prune || true
    git -C "$repo" pull --ff-only 2>/dev/null || log "  WARN: ${name} left as-is"
    if [[ "$name" == "mayhem-firmware" ]] && [[ -f "${repo}/.gitmodules" ]]; then
      git -C "$repo" submodule update --init --recursive || true
    fi
  done
}

materialize_secrets
pull_main_repo

if [[ "$PULL_DRAGONSDR" -eq 1 ]]; then
  pull_dragonsdr
fi

if [[ "$VERIFY" -eq 1 ]]; then
  log "=== rebuild-machine --verify-only ==="
  "$ROOT/bin/rebuild-machine" --verify-only
fi

if [[ "$BUILD_DOCS" -eq 1 ]]; then
  log "=== build-all-docs ==="
  "$ROOT/bin/build-all-docs"
fi

log "Sync complete: ${INDIANADELL_WEB_URL}"
