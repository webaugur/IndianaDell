#!/usr/bin/env bash
# Wait for internet + DNS before Ventoy persistence seed (quiet by default).
#
# Exit 0 = OK to seed, 1 = skip seed (not a fatal error).
#
# Behavior:
#   1) Quiet poll for connectivity (default 120s) — no dialogs
#   2) During the wait, gently nudge NetworkManager (no GUI)
#   3) Only if still down after the wait: optional zenity once
#      (disable prompts with SEED_NETWORK_PROMPT=0)
#
# Env:
#   SEED_SKIP_NETWORK_CHECK=1   skip check entirely
#   SEED_NETWORK_WAIT_SECS=120  quiet wait before any prompt
#   SEED_NETWORK_PROMPT=1       show zenity if still down (default 1)
#   SEED_LOG                    log path
#
set -euo pipefail

LOG="${SEED_LOG:-$HOME/.cache/seed-ventoy.log}"
WAIT_SECS="${SEED_NETWORK_WAIT_SECS:-120}"
PROMPT="${SEED_NETWORK_PROMPT:-1}"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "$LOG"; }

dns_ok() {
    getent hosts github.com &>/dev/null \
        || getent hosts one.one.one.one &>/dev/null
}

internet_ok() {
    curl -fsS --max-time 8 -o /dev/null https://github.com 2>/dev/null \
        || curl -fsS --max-time 8 -o /dev/null https://1.1.1.1 2>/dev/null \
        || ping -c1 -W2 1.1.1.1 &>/dev/null
}

connectivity_ok() {
    dns_ok && internet_ok
}

connectivity_status() {
    local dns=down net=down
    dns_ok && dns=up
    internet_ok && net=up
    printf 'DNS=%s Internet=%s' "$dns" "$net"
}

# Quiet NetworkManager nudge (no dialogs)
nudge_network() {
    command -v nmcli &>/dev/null || return 0
    nmcli networking on 2>/dev/null || true
    nmcli radio wifi on 2>/dev/null || true
    # Prefer already-known ethernet/wifi that is disconnected
    local dev
    while IFS=: read -r dev _type state; do
        [[ "$state" == "disconnected" ]] || continue
        nmcli device connect "$dev" 2>/dev/null || true
    done < <(nmcli -t -f DEVICE,TYPE,STATE device 2>/dev/null || true)
}

# Quiet wait for DHCP + DNS + HTTPS
wait_for_network() {
    local waited=0
    local interval=2
    local max="${WAIT_SECS}"

    log "network: waiting up to ${max}s for connectivity (quiet)..."
    nudge_network

    while (( waited < max )); do
        if connectivity_ok; then
            log "network: OK after ${waited}s ($(connectivity_status))"
            return 0
        fi
        # re-nudge every 15s
        if (( waited > 0 && waited % 15 == 0 )); then
            nudge_network
            log "network: still waiting… ${waited}s ($(connectivity_status))"
        fi
        sleep "$interval"
        waited=$((waited + interval))
    done

    log "network: still down after ${max}s ($(connectivity_status))"
    return 1
}

prompt_skip_or_bring_up() {
    local detail="$1"

    if [[ "${PROMPT}" != "1" ]]; then
        return 1
    fi

    if [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] && command -v zenity &>/dev/null; then
        if zenity --question \
            --title="Uncle Wiggly 🥕🐰 — seed" \
            --width=480 \
            --text="Network still not ready after waiting ${WAIT_SECS}s.\n\n${detail}\n\nSeed needs internet only for optional git clone of IndianaDell into Uncle Wiggly’s rabbit hole.\n\n• Keep waiting (45s more + NM retry)\n• Skip seed — start Grok without seeding" \
            --ok-label="Keep waiting" \
            --cancel-label="Skip seed" \
            2>/dev/null; then
            return 0
        fi
        return 1
    fi

    # Non-GUI: do not block TTY for long — default skip
    log "network: no GUI prompt; skipping seed (set SEED_NETWORK_PROMPT=1 with zenity for dialog)"
    return 1
}

bring_up_network() {
    local waited=0

    log "network: final bring-up attempt"
    nudge_network
    if command -v nmcli &>/dev/null; then
        local conn
        conn="$(nmcli -t -f NAME,TYPE,DEVICE connection show --active 2>/dev/null | head -1 | cut -d: -f1 || true)"
        [[ -z "$conn" ]] && conn="$(nmcli -t -f NAME,TYPE connection show 2>/dev/null | awk -F: '$2~/ethernet|wifi|802-3|802-11/{print $1; exit}')"
        [[ -n "$conn" ]] && nmcli connection up id "$conn" 2>/dev/null || true
    fi

    while (( waited < 45 )); do
        if connectivity_ok; then
            log "network: connectivity restored ($(connectivity_status))"
            return 0
        fi
        sleep 1
        waited=$((waited + 1))
    done

    log "network: still down after final wait ($(connectivity_status))"
    return 1
}

ensure_network_before_seed() {
    if [[ "${SEED_SKIP_NETWORK_CHECK:-0}" == 1 ]]; then
        log "network: check skipped (SEED_SKIP_NETWORK_CHECK=1)"
        return 0
    fi

    # Fast path: already online (e.g. late re-seed)
    if connectivity_ok; then
        log "network: OK immediately ($(connectivity_status))"
        return 0
    fi

    # Main path: wait for DHCP without spamming the desktop
    if wait_for_network; then
        return 0
    fi

    # Only now (after quiet wait) may we prompt once
    if prompt_skip_or_bring_up "$(connectivity_status)"; then
        if bring_up_network; then
            return 0
        fi
        if [[ "${PROMPT}" == "1" && -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] && command -v zenity &>/dev/null; then
            zenity --warning --title="Uncle Wiggly 🥕🐰 — seed" \
                --text="Network is still down after waiting.\n\nSkipping seed into the rabbit hole; Grok will start anyway." \
                2>/dev/null || true
        fi
        return 1
    fi

    log "network: skipping seed (still down after quiet wait; no keep-waiting chosen)"
    return 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    mkdir -p "$(dirname "$LOG")"
    if ensure_network_before_seed; then
        exit 0
    fi
    exit 1
fi
