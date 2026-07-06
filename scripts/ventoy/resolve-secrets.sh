#!/usr/bin/env bash
# Resolve where IndianaDell secrets live at runtime vs on Ventoy persistence.
#
# Policy:
#   - Canonical store on Ventoy: casper-rw cow/upper/home/ubuntu/{.ssh,.grok,.config/gh}
#   - When ZFS rpool /home/user exists, treat it as the live secret source
#   - Runtime tools use $HOME after materialize; env vars point at resolved paths
#   - Never commit secrets to the IndianaDell git repo
set -euo pipefail

INDIANADELL_SECRET_REL_PATHS=(
    .ssh
    .grok
    .config/gh
)

INDIANADELL_SESSION_REL_PATHS=(
    .config/indianadell
    .config/autostart
    .config/dconf
    .local
    bin
    .cache
)

rpool_imported() {
    zpool list -H -o name rpool &>/dev/null
}

rpool_user_home_available() {
    [[ -d /home/user ]] || return 1
    [[ -f /home/user/.ssh/id_rsa ]] \
        || [[ -f /home/user/.config/gh/hosts.yml ]] \
        || [[ -f /home/user/.grok/auth.json ]] \
        || [[ -d /home/user/.grok ]]
}

# Where to READ secrets from right now (rpool user wins when present).
resolve_secret_source_home() {
    if rpool_user_home_available; then
        printf '/home/user\n'
        return 0
    fi
    printf '%s\n' "${HOME:?HOME is not set}"
}

# Where Ventoy persistence stores secrets (always ubuntu home in cow/upper).
persistence_secrets_home() {
    printf '%s\n' "/home/ubuntu"
}

secret_path_exists() {
    local home="$1" rel
    for rel in "${INDIANADELL_SECRET_REL_PATHS[@]}"; do
        [[ -e "$home/$rel" ]] && return 0
    done
    return 1
}

sync_secret_tree() {
    local src="$1" dest="$2" use_sudo="${3:-0}"
    local rel

    for rel in "${INDIANADELL_SECRET_REL_PATHS[@]}"; do
        [[ -e "$src/$rel" ]] || continue
        if [[ "$use_sudo" == 1 ]]; then
            sudo mkdir -p "$dest/$(dirname "$rel")"
            sudo rsync -a "$src/$rel/" "$dest/$rel/"
        else
            mkdir -p "$dest/$(dirname "$rel")"
            rsync -a "$src/$rel/" "$dest/$rel/"
        fi
    done

    if [[ -d "$dest/.ssh" ]]; then
        if [[ "$use_sudo" == 1 ]]; then
            sudo chown -R 1000:1000 "$dest/.ssh" "$dest/.grok" "$dest/.config" 2>/dev/null || true
            sudo chmod 700 "$dest/.ssh"
            sudo chmod 600 "$dest/.ssh/id_rsa" 2>/dev/null || true
        else
            chmod 700 "$dest/.ssh"
            chmod 600 "$dest/.ssh/id_rsa" 2>/dev/null || true
        fi
    fi
}

sync_session_tree() {
    local src="$1" dest="$2" use_sudo="${3:-0}"
    local rel

    for rel in "${INDIANADELL_SESSION_REL_PATHS[@]}"; do
        [[ -e "$src/$rel" ]] || continue
        if [[ "$use_sudo" == 1 ]]; then
            sudo mkdir -p "$dest/$(dirname "$rel")"
            sudo rsync -a "$src/$rel/" "$dest/$rel/"
        else
            mkdir -p "$dest/$(dirname "$rel")"
            rsync -a "$src/$rel/" "$dest/$rel/"
        fi
    done
}

# Copy live rpool secrets into $HOME (persistence overlay) for tool compatibility.
materialize_secrets_to_runtime_home() {
    local src log_fn="${1:-true}"
    src="$(resolve_secret_source_home)"

    if [[ "$src" == "$HOME" ]]; then
        configure_runtime_secret_env "$HOME"
        return 0
    fi

    if [[ "$log_fn" != "quiet" ]]; then
        printf '[secrets] materialize %s -> %s (rpool user home)\n' "$src" "$HOME" >&2
    fi
    sync_secret_tree "$src" "$HOME" 0
    configure_runtime_secret_env "$HOME"
}

# Write secrets into Ventoy persistence upper from the best live source.
sync_secrets_to_persistence() {
    local dest_root="$1"
    local src
    src="$(resolve_secret_source_home)"
    sync_secret_tree "$src" "$dest_root/home/ubuntu" 1
}

configure_runtime_secret_env() {
    local secrets_home="$1"
    export INDIANADELL_SECRETS_HOME="$secrets_home"

    if [[ -f "$secrets_home/.ssh/id_rsa" ]]; then
        export INDIANADELL_SSH_IDENTITY="$secrets_home/.ssh/id_rsa"
        export GIT_SSH_COMMAND="ssh -i ${INDIANADELL_SSH_IDENTITY} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
    else
        unset INDIANADELL_SSH_IDENTITY GIT_SSH_COMMAND
    fi

    if [[ -d "$secrets_home/.grok/bin" ]]; then
        export PATH="$secrets_home/.grok/bin:${PATH#*:}"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    materialize_secrets_to_runtime_home
    printf 'INDIANADELL_SECRETS_HOME=%s\n' "${INDIANADELL_SECRETS_HOME:-}"
    [[ -n "${INDIANADELL_SSH_IDENTITY:-}" ]] && printf 'INDIANADELL_SSH_IDENTITY=%s\n' "$INDIANADELL_SSH_IDENTITY"
fi