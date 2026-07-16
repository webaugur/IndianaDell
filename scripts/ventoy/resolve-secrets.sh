#!/usr/bin/env bash
# Resolve where IndianaDell secrets live at runtime vs on Ventoy persistence.
#
# Policy:
#   - Canonical store on Ventoy: casper-rw cow/upper/home/ubuntu/{.ssh,.grok,.config/gh}
#   - When ZFS rpool /home/user exists, treat it as the live secret source
#   - Runtime tools use $HOME after materialize; env vars point at resolved paths
#   - Chrome tier seed (SEED_CHROME, default c): curated profile, never caches
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
    # Intentionally no full .cache — Tower home cache can fill the casper image.
)

# Chrome profile seed tiers (SEED_CHROME=off|a|b|c|d; default c).
#   a — bookmarks + Preferences only (thin)
#   b — a + Local State + Secure Preferences
#   c — b + Login Data + Web Data + Extensions + Local Extension Settings
#   d — full Default profile minus caches (large)
# Never copies Cache / Code Cache / GPU* / Service Worker / blob_storage.
CHROME_CONFIG_REL=".config/google-chrome"
CHROME_TIER_C_PROFILE_FILES=(
    Bookmarks
    Bookmarks.bak
    Preferences
    "Secure Preferences"
    "Login Data"
    "Login Data-journal"
    "Web Data"
    "Web Data-journal"
)
CHROME_TIER_C_PROFILE_DIRS=(
    Extensions
    "Local Extension Settings"
)
CHROME_TIER_C_ROOT_FILES=(
    "Local State"
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

# Chrome profile source: prefer rpool when it has a google-chrome config tree.
resolve_chrome_source_home() {
    if [[ -d /home/user/$CHROME_CONFIG_REL ]]; then
        printf '/home/user\n'
        return 0
    fi
    if [[ -d "${HOME:?HOME is not set}/$CHROME_CONFIG_REL" ]]; then
        printf '%s\n' "$HOME"
        return 0
    fi
    # Fall back to secret source even if chrome missing (no-op sync).
    resolve_secret_source_home
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

# Normalize SEED_CHROME (default: c). Returns 0 if seeding enabled.
chrome_seed_enabled() {
    local tier="${SEED_CHROME:-c}"
    case "${tier,,}" in
        0|off|no|false|none|'') return 1 ;;
        a|b|c|d) return 0 ;;
        *) return 0 ;; # unknown → treat as enabled (c semantics)
    esac
}

chrome_seed_tier() {
    local tier="${SEED_CHROME:-c}"
    case "${tier,,}" in
        0|off|no|false|none|'') printf 'off\n' ;;
        a|b|c|d) printf '%s\n' "${tier,,}" ;;
        *) printf 'c\n' ;;
    esac
}

# List Chrome profile dirs under a config root (Default, Profile N).
chrome_profile_dirs() {
    local chrome_root="$1"
    local d base
    [[ -d "$chrome_root" ]] || return 0
    for d in "$chrome_root"/Default "$chrome_root"/Profile\ *; do
        [[ -d "$d" ]] || continue
        base="$(basename "$d")"
        # skip non-profile dirs that might match globs poorly
        case "$base" in
            Default|Profile\ *) printf '%s\n' "$base" ;;
        esac
    done
}

_rsync_one() {
    local src="$1" dest="$2" use_sudo="${3:-0}"
    # -S: keep sparse holes (Chrome extension trees often look smaller on ZFS)
    if [[ -d "$src" ]]; then
        if [[ "$use_sudo" == 1 ]]; then
            sudo mkdir -p "$dest"
            sudo rsync -aS "$src/" "$dest/"
        else
            mkdir -p "$dest"
            rsync -aS "$src/" "$dest/"
        fi
    elif [[ -e "$src" ]]; then
        if [[ "$use_sudo" == 1 ]]; then
            sudo mkdir -p "$(dirname "$dest")"
            sudo rsync -aS "$src" "$dest"
        else
            mkdir -p "$(dirname "$dest")"
            rsync -aS "$src" "$dest"
        fi
    fi
}

# Tier C: bookmarks, prefs, Local State, logins, autofill Web Data, extensions.
# Intentionally excludes Cache, Code Cache, GPU*, Service Worker, History bulk, etc.
sync_chrome_tier_c() {
    local src_home="$1" dest_home="$2" use_sudo="${3:-0}"
    local chrome_src chrome_dest prof name

    chrome_src="$src_home/$CHROME_CONFIG_REL"
    chrome_dest="$dest_home/$CHROME_CONFIG_REL"
    [[ -d "$chrome_src" ]] || return 0

    if [[ "$use_sudo" == 1 ]]; then
        sudo mkdir -p "$chrome_dest"
    else
        mkdir -p "$chrome_dest"
    fi

    for name in "${CHROME_TIER_C_ROOT_FILES[@]}"; do
        [[ -e "$chrome_src/$name" ]] || continue
        _rsync_one "$chrome_src/$name" "$chrome_dest/$name" "$use_sudo"
    done

    while IFS= read -r prof; do
        [[ -n "$prof" ]] || continue
        if [[ "$use_sudo" == 1 ]]; then
            sudo mkdir -p "$chrome_dest/$prof"
        else
            mkdir -p "$chrome_dest/$prof"
        fi
        for name in "${CHROME_TIER_C_PROFILE_FILES[@]}"; do
            [[ -e "$chrome_src/$prof/$name" ]] || continue
            _rsync_one "$chrome_src/$prof/$name" "$chrome_dest/$prof/$name" "$use_sudo"
        done
        for name in "${CHROME_TIER_C_PROFILE_DIRS[@]}"; do
            [[ -d "$chrome_src/$prof/$name" ]] || continue
            _rsync_one "$chrome_src/$prof/$name" "$chrome_dest/$prof/$name" "$use_sudo"
        done
    done < <(chrome_profile_dirs "$chrome_src")

    if [[ "$use_sudo" == 1 ]]; then
        sudo chown -R 1000:1000 "$chrome_dest" 2>/dev/null || true
        sudo chmod 700 "$chrome_dest" 2>/dev/null || true
    else
        chmod 700 "$chrome_dest" 2>/dev/null || true
    fi
}

sync_chrome_tier_a() {
    local src_home="$1" dest_home="$2" use_sudo="${3:-0}"
    local chrome_src chrome_dest prof name
    chrome_src="$src_home/$CHROME_CONFIG_REL"
    chrome_dest="$dest_home/$CHROME_CONFIG_REL"
    [[ -d "$chrome_src" ]] || return 0
    if [[ "$use_sudo" == 1 ]]; then sudo mkdir -p "$chrome_dest"
    else mkdir -p "$chrome_dest"; fi
    while IFS= read -r prof; do
        [[ -n "$prof" ]] || continue
        if [[ "$use_sudo" == 1 ]]; then sudo mkdir -p "$chrome_dest/$prof"
        else mkdir -p "$chrome_dest/$prof"; fi
        for name in Bookmarks Bookmarks.bak Preferences; do
            [[ -e "$chrome_src/$prof/$name" ]] || continue
            _rsync_one "$chrome_src/$prof/$name" "$chrome_dest/$prof/$name" "$use_sudo"
        done
    done < <(chrome_profile_dirs "$chrome_src")
    if [[ "$use_sudo" == 1 ]]; then
        sudo chown -R 1000:1000 "$chrome_dest" 2>/dev/null || true
    fi
}

sync_chrome_tier_b() {
    local src_home="$1" dest_home="$2" use_sudo="${3:-0}"
    local chrome_src chrome_dest prof name
    chrome_src="$src_home/$CHROME_CONFIG_REL"
    chrome_dest="$dest_home/$CHROME_CONFIG_REL"
    [[ -d "$chrome_src" ]] || return 0
    if [[ "$use_sudo" == 1 ]]; then sudo mkdir -p "$chrome_dest"
    else mkdir -p "$chrome_dest"; fi
    for name in "Local State"; do
        [[ -e "$chrome_src/$name" ]] || continue
        _rsync_one "$chrome_src/$name" "$chrome_dest/$name" "$use_sudo"
    done
    while IFS= read -r prof; do
        [[ -n "$prof" ]] || continue
        if [[ "$use_sudo" == 1 ]]; then sudo mkdir -p "$chrome_dest/$prof"
        else mkdir -p "$chrome_dest/$prof"; fi
        for name in Bookmarks Bookmarks.bak Preferences "Secure Preferences"; do
            [[ -e "$chrome_src/$prof/$name" ]] || continue
            _rsync_one "$chrome_src/$prof/$name" "$chrome_dest/$prof/$name" "$use_sudo"
        done
    done < <(chrome_profile_dirs "$chrome_src")
    if [[ "$use_sudo" == 1 ]]; then
        sudo chown -R 1000:1000 "$chrome_dest" 2>/dev/null || true
    fi
}

# Dispatch by SEED_CHROME tier (default c).
sync_chrome_seed() {
    local src_home="$1" dest_home="$2" use_sudo="${3:-0}"
    case "$(chrome_seed_tier)" in
        off) return 0 ;;
        a) sync_chrome_tier_a "$src_home" "$dest_home" "$use_sudo" ;;
        b) sync_chrome_tier_b "$src_home" "$dest_home" "$use_sudo" ;;
        c|d)
            # d reserved for fuller profile; same as c for now (caches excluded)
            sync_chrome_tier_c "$src_home" "$dest_home" "$use_sudo"
            ;;
    esac
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
    if chrome_seed_enabled; then
        local chrome_src
        chrome_src="$(resolve_chrome_source_home)"
        if [[ "$log_fn" != "quiet" ]]; then
            printf '[secrets] chrome tier %s: %s -> %s\n' "$(chrome_seed_tier)" "$chrome_src" "$HOME" >&2
        fi
        sync_chrome_seed "$chrome_src" "$HOME" 0
    fi
    configure_runtime_secret_env "$HOME"
}

# Write secrets into Ventoy persistence upper from the best live source.
sync_secrets_to_persistence() {
    local dest_root="$1"
    local src chrome_src
    src="$(resolve_secret_source_home)"
    sync_secret_tree "$src" "$dest_root/home/ubuntu" 1
    if chrome_seed_enabled; then
        chrome_src="$(resolve_chrome_source_home)"
        sync_chrome_seed "$chrome_src" "$dest_root/home/ubuntu" 1
    fi
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