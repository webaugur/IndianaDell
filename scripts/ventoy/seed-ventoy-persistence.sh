#!/usr/bin/env bash
# Seed the Ventoy Ubuntu casper-rw persistence image from the current session.
set -euo pipefail

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

NETWORK_CHECK="${NETWORK_CHECK:-$HOME/bin/seed-network-check.sh}"
if [[ -r "$NETWORK_CHECK" ]]; then
    # shellcheck source=/home/ubuntu/bin/seed-network-check.sh
    source "$NETWORK_CHECK"
    if ! ensure_network_before_seed; then
        log "seed skipped (network down or user declined)"
        exit 0
    fi
elif [[ "${SEED_SKIP_NETWORK_CHECK:-0}" != 1 ]]; then
    log "warning: $NETWORK_CHECK missing — proceeding without network check"
fi

running_on_casper_persistence() {
    findmnt -rn -o FSTYPE / 2>/dev/null | grep -qx overlay \
        && [[ -d /cow/upper ]]
}

find_persist_dat() {
    local candidate
    if [[ -n "$PERSIST_DAT" && -f "$PERSIST_DAT" ]]; then
        printf '%s\n' "$PERSIST_DAT"
        return 0
    fi
    for candidate in \
        /mnt/wiggly/persistence/ubuntu-26.04.dat \
        /run/media/ubuntu/Wiggly/persistence/ubuntu-26.04.dat \
        /media/ubuntu/Wiggly/persistence/ubuntu-26.04.dat; do
        if [[ -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

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
    local use_sudo="${2:-1}"
    local rel

    log "home/ubuntu (.grok, .config, .ssh, .local, bin, autostart)"
    if [[ "$use_sudo" == 1 ]]; then
        sudo rsync -a --delete /home/ubuntu/.grok/ "$dest_root/home/ubuntu/.grok/"
        for rel in .config/indianadell .config/gh .config/autostart .config/dconf .ssh .local bin .cache; do
            [[ -e "/home/ubuntu/$rel" ]] || continue
            sudo mkdir -p "$dest_root/home/ubuntu/$(dirname "$rel")"
            sudo rsync -a "/home/ubuntu/$rel/" "$dest_root/home/ubuntu/$rel/"
        done
    else
        : # on live persistence, home is already in /cow/upper
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

sync_ssh_from_user() {
    local dest_root="$1"
    [[ -f /home/user/.ssh/id_rsa ]] || return 0
    log "SSH deploy key from /home/user/.ssh"
    sudo mkdir -p "$dest_root/home/ubuntu/.ssh"
    sudo rsync -a /home/user/.ssh/id_rsa /home/user/.ssh/id_rsa.pub \
        /home/user/.ssh/config "$dest_root/home/ubuntu/.ssh/" 2>/dev/null || true
    sudo chown -R 1000:1000 "$dest_root/home/ubuntu/.ssh"
    sudo chmod 700 "$dest_root/home/ubuntu/.ssh"
    sudo chmod 600 "$dest_root/home/ubuntu/.ssh/id_rsa" 2>/dev/null || true
}

seed_live_persistence() {
    local src dest="$HOME/Documents/IndianaDell"

    log "mode: live casper persistence (overlay active — skip .dat mount)"
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
    sync_home_overlay "$UPPER" 1
    sync_ssh_from_user "$UPPER"
    sync_system_overlay "$UPPER"

    log "IndianaDell workspace"
    sudo mkdir -p "$UPPER/home/ubuntu/Documents"
    if src="$(resolve_indianadell_src)"; then
        sync_indianadell_to "$src" "$UPPER/home/ubuntu/Documents/IndianaDell" 1
    elif [[ ! -d "$UPPER/home/ubuntu/Documents/IndianaDell/.git" ]]; then
        sudo rm -rf "$UPPER/home/ubuntu/Documents/IndianaDell"
        sudo -u ubuntu GIT_LFS_SKIP_SMUDGE=1 \
            git clone https://github.com/webaugur/IndianaDell.git \
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