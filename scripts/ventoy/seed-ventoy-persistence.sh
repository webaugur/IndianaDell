#!/usr/bin/env bash
# Seed the Ventoy Ubuntu casper-rw persistence image from the current session.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PERSIST_DAT="${PERSIST_DAT:-}"
MOUNT="${PERSIST_MOUNT:-/mnt/persist-seed}"
UPPER=""
LOOP_DEV=""
LOG="${SEED_LOG:-$HOME/.cache/seed-ventoy.log}"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "$LOG"; }

cleanup() {
    if [[ "${KEEP_MOUNT:-0}" == 1 ]]; then
        return
    fi
    if [[ -n "$MOUNT" && -n "$LOOP_DEV" ]] && mountpoint -q "$MOUNT" 2>/dev/null; then
        sudo umount "$MOUNT" 2>/dev/null || true
    fi
    if [[ -n "$LOOP_DEV" ]] && losetup "$LOOP_DEV" &>/dev/null; then
        sudo losetup -d "$LOOP_DEV" 2>/dev/null || true
    fi
}
trap cleanup EXIT

mkdir -p "$(dirname "$LOG")"

RESOLVE_SECRETS="${RESOLVE_SECRETS:-$HOME/bin/resolve-secrets.sh}"
[[ -r "$RESOLVE_SECRETS" ]] || RESOLVE_SECRETS="$ROOT/scripts/ventoy/resolve-secrets.sh"
# shellcheck source=resolve-secrets.sh
source "$RESOLVE_SECRETS"

running_on_casper_persistence() {
    findmnt -rn -o FSTYPE / 2>/dev/null | grep -qx overlay \
        && [[ -d /cow/upper ]]
}

# Forward declaration helpers used by network gate (defined fully later)
resolve_indianadell_src() {
    local candidate
    for candidate in /home/user/Documents/IndianaDell "$HOME/Documents/IndianaDell"; do
        if [[ -d "$candidate/.git" || -f "$candidate/mount-rpool-recovery.sh" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

# Network is only required when we must git-clone IndianaDell into an external
# .dat image. Live casper overlay seed is local rsync only.
need_network_for_seed() {
    if running_on_casper_persistence; then
        return 1
    fi
    if resolve_indianadell_src >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

NETWORK_CHECK="${NETWORK_CHECK:-$HOME/bin/seed-network-check.sh}"
[[ -r "$NETWORK_CHECK" ]] || NETWORK_CHECK="$ROOT/scripts/ventoy/seed-network-check.sh"
if need_network_for_seed; then
    if [[ -r "$NETWORK_CHECK" ]]; then
        # shellcheck source=seed-network-check.sh
        source "$NETWORK_CHECK"
        if ! ensure_network_before_seed; then
            log "seed skipped (network down after wait; needed for git clone)"
            exit 0
        fi
    elif [[ "${SEED_SKIP_NETWORK_CHECK:-0}" != 1 ]]; then
        log "warning: $NETWORK_CHECK missing — proceeding without network check"
    fi
else
    log "network: not required for this seed mode (local only)"
fi

materialize_secrets_to_runtime_home quiet

find_persist_dat() {
    local candidate
    if [[ -n "$PERSIST_DAT" && -f "$PERSIST_DAT" ]]; then
        printf '%s\n' "$PERSIST_DAT"
        return 0
    fi
    for candidate in \
        /mnt/wiggly/persistence/ubuntu-26.04.dat \
        /run/media/user/Wiggly/persistence/ubuntu-26.04.dat \
        /run/media/ubuntu/Wiggly/persistence/ubuntu-26.04.dat \
        /media/ubuntu/Wiggly/persistence/ubuntu-26.04.dat \
        /media/user/Wiggly/persistence/ubuntu-26.04.dat; do
        if [[ -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

sync_indianadell_to() {
    local src="$1" dest="$2"
    local use_sudo="${3:-0}"

    mkdir -p "$(dirname "$dest")"
    if [[ "$use_sudo" == 1 ]]; then
        sudo mkdir -p "$dest"
        if [[ -d "$src/.git" ]]; then
            sudo rsync -a --delete \
                --exclude '.git/objects/pack/*.pack' \
                "$src/" "$dest/"
            sudo rsync -a "$src/.git/" "$dest/.git/"
        else
            sudo rsync -a "$src/" "$dest/"
        fi
        sudo chown -R 1000:1000 "$dest"
    else
        mkdir -p "$dest"
        if [[ -d "$src/.git" ]]; then
            rsync -a --delete \
                --exclude '.git/objects/pack/*.pack' \
                "$src/" "$dest/"
            rsync -a "$src/.git/" "$dest/.git/"
        else
            rsync -a "$src/" "$dest/"
        fi
    fi
}

sync_home_overlay() {
    local dest_root="$1"
    local secret_src session_src

    secret_src="$(resolve_secret_source_home)"
    session_src="${HOME}"

    log "secrets: $secret_src -> persistence (store on casper disk)"
    sync_secrets_to_persistence "$dest_root"

    log "session config: $session_src -> persistence"
    sync_session_tree "$session_src" "$dest_root/home/ubuntu" 1

    # Non-secret grok state beyond auth may live in session home
    if [[ "$session_src" != "$secret_src" && -d "$session_src/.grok" ]]; then
        log "grok sessions: merge from $session_src"
        sudo mkdir -p "$dest_root/home/ubuntu/.grok"
        sudo rsync -a "$session_src/.grok/" "$dest_root/home/ubuntu/.grok/"
    fi
}

sync_system_overlay() {
    local dest_root="$1"
    log "GDM autologin + dpkg state"
    sudo mkdir -p "$dest_root/etc/gdm3" "$dest_root/var/lib/dpkg" "$dest_root/var/lib/apt/lists" "$dest_root/etc/apt"
    sudo rsync -a /etc/gdm3/custom.conf "$dest_root/etc/gdm3/custom.conf"
    sudo rsync -a \
        /var/lib/dpkg/status /var/lib/dpkg/status-old /var/lib/dpkg/available \
        "$dest_root/var/lib/dpkg/"
    sudo rsync -a /var/lib/dpkg/info/ "$dest_root/var/lib/dpkg/info/"
    sudo rsync -a /var/lib/dpkg/alternatives/ "$dest_root/var/lib/dpkg/alternatives/" 2>/dev/null || true
    sudo rsync -a /var/lib/apt/lists/ "$dest_root/var/lib/apt/lists/" 2>/dev/null || true
    sudo rsync -a /etc/apt/ "$dest_root/etc/apt/"
}

seed_live_persistence() {
    local src dest="$HOME/Documents/IndianaDell"

    log "mode: live casper persistence (overlay active — skip .dat mount)"
    materialize_secrets_to_runtime_home
    if src="$(resolve_indianadell_src)"; then
        if [[ "$src" != "$(readlink -f "$dest" 2>/dev/null || echo "$dest")" ]]; then
            log "IndianaDell: $src -> $dest"
            sync_indianadell_to "$src" "$dest" 0
        fi
    fi
    sync
    log "done (live persistence)"
}

seed_external_dat() {
    PERSIST_DAT="$(find_persist_dat)" || {
        log "skip: persistence image not found (Ventoy stick not mounted?)"
        return 0
    }

    UPPER="$MOUNT/cow/upper"
    if mountpoint -q "$MOUNT" 2>/dev/null; then
        log "using already-mounted persistence at $MOUNT"
    else
        sudo mkdir -p "$MOUNT"
        LOOP_DEV="$(sudo losetup --show -f "$PERSIST_DAT")"
        sudo mount "$LOOP_DEV" "$MOUNT"
    fi
    sudo mkdir -p "$UPPER/home/ubuntu" "$UPPER/etc/gdm3" "$UPPER/var/lib/dpkg"

    log "mode: external seed -> $PERSIST_DAT"
    sync_home_overlay "$UPPER"
    sync_system_overlay "$UPPER"

    log "IndianaDell workspace"
    sudo mkdir -p "$UPPER/home/ubuntu/Documents"
    if src="$(resolve_indianadell_src)"; then
        sync_indianadell_to "$src" "$UPPER/home/ubuntu/Documents/IndianaDell" 1
    elif [[ ! -d "$UPPER/home/ubuntu/Documents/IndianaDell/.git" ]]; then
        sudo rm -rf "$UPPER/home/ubuntu/Documents/IndianaDell"
        clone_url="${INDIANADELL_REMOTE:-git@github.com:webaugur/IndianaDell.git}"
        sudo -u ubuntu GIT_LFS_SKIP_SMUDGE=1 \
            git clone "$clone_url" \
            "$UPPER/home/ubuntu/Documents/IndianaDell"
    fi

    sudo chown -R 1000:1000 "$UPPER/home/ubuntu"
    log "done"
    sudo du -sh "$UPPER/home/ubuntu" "$UPPER/var" "$MOUNT" 2>/dev/null | tee -a "$LOG" || true
    df -h "$MOUNT" 2>/dev/null | tee -a "$LOG" || true
}

if running_on_casper_persistence; then
    seed_live_persistence
else
    seed_external_dat
fi