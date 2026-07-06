# IndianaDell GitHub remote defaults — source from push/pull scripts.
# shellcheck shell=bash

INDIANADELL_GITHUB_OWNER="${INDIANADELL_GITHUB_OWNER:-webaugur}"
INDIANADELL_GITHUB_REPO="${INDIANADELL_GITHUB_REPO:-IndianaDell}"
INDIANADELL_BRANCH="${INDIANADELL_BRANCH:-main}"

# SSH works without gh/credential helper on Tower5810; override with INDIANADELL_REMOTE.
INDIANADELL_REMOTE="${INDIANADELL_REMOTE:-git@github.com:${INDIANADELL_GITHUB_OWNER}/${INDIANADELL_GITHUB_REPO}.git}"
INDIANADELL_WEB_URL="https://github.com/${INDIANADELL_GITHUB_OWNER}/${INDIANADELL_GITHUB_REPO}"

indianadell_ensure_origin() {
  local repo_dir="$1"
  cd "$repo_dir"
  if ! git remote get-url origin >/dev/null 2>&1; then
    git remote add origin "$INDIANADELL_REMOTE"
  else
    git remote set-url origin "$INDIANADELL_REMOTE"
  fi
}

indianadell_remote_needs_gh() {
  [[ "${INDIANADELL_REMOTE}" == https://* ]]
}