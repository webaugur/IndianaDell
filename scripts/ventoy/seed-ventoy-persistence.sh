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

    if chrome_seed_enabled; then
        log "chrome tier $(chrome_seed_tier): $(resolve_chrome_source_home) -> persistence (no caches)"
    else
        log "chrome: seed disabled (SEED_CHROME=off)"
    fi

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

# Live Ubuntu starts ubuntu-desktop-bootstrap (try-or-install) via a user unit.
# We want a normal desktop; keep an Install icon on ~/Desktop instead.
disable_installer_autostart() {
    local dest_root="$1"
    local unit wants_dir desk

    log "installer: disable autostart; keep Desktop Install icon"
    sudo mkdir -p \
        "$dest_root/usr/lib/systemd/user" \
        "$dest_root/etc/systemd/user" \
        "$dest_root/etc/indianadell" \
        "$dest_root/home/ubuntu/.config/systemd/user" \
        "$dest_root/home/ubuntu/.config/autostart" \
        "$dest_root/home/ubuntu/Desktop"

    unit="$dest_root/usr/lib/systemd/user/ubuntu-desktop-installer.service"
    sudo tee "$unit" >/dev/null <<'EOF'
# IndianaDell / Uncle Wiggly: do not auto-launch the installer.
# Use ~/Desktop/Install Ubuntu.desktop instead.
# Re-enable: touch /etc/indianadell/enable-installer-autostart and restore stock unit.
[Unit]
Description=Ubuntu Desktop Installer (autostart disabled)
ConditionPathExists=/etc/indianadell/enable-installer-autostart
PartOf=graphical-session.target
After=graphical-session.target
Conflicts=gnome-session@gnome-login.target

[Service]
Type=oneshot
ExecStart=/bin/true
Restart=no
EOF

    sudo rm -f "$dest_root/etc/indianadell/enable-installer-autostart"
    sudo ln -sfn /dev/null "$dest_root/etc/systemd/user/ubuntu-desktop-installer.service"
    sudo ln -sfn /dev/null "$dest_root/home/ubuntu/.config/systemd/user/ubuntu-desktop-installer.service"

    wants_dir="$dest_root/usr/lib/systemd/user/graphical-session.target.wants"
    sudo mkdir -p "$wants_dir"
    sudo rm -f "$wants_dir/ubuntu-desktop-installer.service"
    # Overlay whiteout hides lower-layer wants symlink if present
    sudo mknod "$wants_dir/ubuntu-desktop-installer.service" c 0 0 2>/dev/null \
        || sudo ln -sfn /dev/null "$wants_dir/ubuntu-desktop-installer.service"

    sudo tee "$dest_root/home/ubuntu/.config/autostart/ubuntu-desktop-installer.desktop" >/dev/null <<'EOF'
[Desktop Entry]
Type=Application
Name=Ubuntu Desktop Installer
Exec=/snap/bin/ubuntu-desktop-bootstrap --try-or-install
Hidden=true
X-GNOME-Autostart-enabled=false
EOF

    desk="$dest_root/home/ubuntu/Desktop/Install Ubuntu.desktop"
    sudo rm -f "$dest_root/home/ubuntu/Desktop/ubuntu-desktop-bootstrap_ubuntu-desktop-bootstrap.desktop"
    sudo tee "$desk" >/dev/null <<'EOF'
[Desktop Entry]
Type=Application
Version=1.0
Name=Install Ubuntu
Comment=Install this system permanently to your hard disk
Keywords=ubiquity;install;
Exec=/snap/bin/ubuntu-desktop-bootstrap
Icon=ubiquity
Terminal=false
Categories=GTK;System;Settings;
StartupNotify=true
EOF
    sudo chmod 0755 "$desk"
    sudo chown -R 1000:1000 \
        "$dest_root/home/ubuntu/Desktop" \
        "$dest_root/home/ubuntu/.config/systemd" \
        "$dest_root/home/ubuntu/.config/autostart"
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

# Resolve overlay upper dir inside the casper-rw image.
# Live Ubuntu/Ventoy images use upper/ (+ work/); older scripts used cow/upper.
resolve_persist_upper() {
    local root="$1"
    if [[ -d "$root/upper" ]]; then
        printf '%s\n' "$root/upper"
    elif [[ -d "$root/cow/upper" ]]; then
        printf '%s\n' "$root/cow/upper"
    else
        # Prefer modern layout when creating fresh
        printf '%s\n' "$root/upper"
    fi
}

seed_external_dat() {
    PERSIST_DAT="$(find_persist_dat)" || {
        log "skip: persistence image not found (Uncle Wiggly 🥕🐰 not mounted? label=Wiggly)"
        return 0
    }

    if mountpoint -q "$MOUNT" 2>/dev/null; then
        log "using already-mounted persistence at $MOUNT"
    else
        sudo mkdir -p "$MOUNT"
        LOOP_DEV="$(sudo losetup --show -f "$PERSIST_DAT")"
        sudo mount "$LOOP_DEV" "$MOUNT"
    fi
    UPPER="$(resolve_persist_upper "$MOUNT")"
    # Drop mistaken cow/ tree from older seed runs (real overlay is upper/)
    if [[ "$UPPER" == "$MOUNT/upper" && -d "$MOUNT/cow" ]]; then
        log "Uncle Wiggly: removing stale cow/ (seed target is upper/)"
        sudo rm -rf "$MOUNT/cow"
    fi
    sudo mkdir -p "$UPPER/home/ubuntu" "$UPPER/etc/gdm3" "$UPPER/var/lib/dpkg"

    log "mode: external seed -> Uncle Wiggly 🥕🐰 ($PERSIST_DAT)"
    log "overlay upper: $UPPER"
    sync_home_overlay "$UPPER"
    sync_system_overlay "$UPPER"
    disable_installer_autostart "$UPPER"

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