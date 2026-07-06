#!/usr/bin/env bash
# Pull IndianaDell + nested GitHub clones + LFS; optional verify/docs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=remote.sh
source "$ROOT/scripts/github/remote.sh"

VERIFY=0
BUILD_DOCS=0
REBUILD_HACKRF=0

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

usage() {
  sed -n '2,20p' "$0"
}

for arg in "$@"; do
  case "$arg" in
    --verify) VERIFY=1 ;;
    --build-docs) BUILD_DOCS=1 ;;
    --rebuild-hackrf) REBUILD_HACKRF=1 ;;
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

pull_nested_repo() {
  local dir="$1"
  local name
  name="$(basename "$dir")"
  [[ -d "${dir}/.git" ]] || return 0
  log "=== hackrf/repos/${name} ==="
  git -C "$dir" fetch --all --prune
  local branch
  branch="$(git -C "$dir" symbolic-ref -q --short HEAD 2>/dev/null || true)"
  if [[ -n "$branch" ]] && git -C "$dir" rev-parse --verify "origin/${branch}" >/dev/null 2>&1; then
    git -C "$dir" pull --ff-only origin "$branch"
  else
    git -C "$dir" pull --ff-only 2>/dev/null || log "WARN: ${name} — no upstream; left at $(git -C "$dir" log --oneline -1)"
  fi
  if [[ "$name" == "mayhem-firmware" ]] && [[ -f "${dir}/.gitmodules" ]]; then
    log "  mayhem-firmware: submodule update"
    git -C "$dir" submodule update --init --recursive
  fi
  log "  $(git -C "$dir" log --oneline -1)"
}

pull_hackrf_repos() {
  log "=== Nested GitHub repos ==="
  local repo
  for repo in "$ROOT"/hackrf/repos/*/; do
    pull_nested_repo "$repo"
  done
}

rebuild_hackrf_host() {
  log "=== Rebuild HackRF host tools ==="
  mkdir -p "$ROOT/hackrf/build"
  cmake -S "$ROOT/hackrf/repos/hackrf/host" -B "$ROOT/hackrf/build" \
    -DCMAKE_INSTALL_PREFIX="$ROOT/hackrf/local"
  cmake --build "$ROOT/hackrf/build" -j"$(nproc)"
}

materialize_secrets
pull_main_repo
pull_hackrf_repos

if [[ "$REBUILD_HACKRF" -eq 1 ]]; then
  rebuild_hackrf_host
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