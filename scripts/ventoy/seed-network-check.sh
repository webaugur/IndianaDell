#!/usr/bin/env bash
# Verify internet + DNS before Ventoy persistence seed; offer to bring network up.
# Exit 0 = OK to seed, 1 = skip seed (not a fatal error).
set -euo pipefail

LOG="${SEED_LOG:-$HOME/.cache/seed-ventoy.log}"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "$LOG"; }

dns_ok() {
    getent hosts github.com &>/dev/null \
        || getent hosts one.one.one.one &>/dev/null
}

internet_ok() {
    curl -fsS --max-time 10 -o /dev/null https://github.com 2>/dev/null \
        || curl -fsS --max-time 10 -o /dev/null https://1.1.1.1 2>/dev/null
}

connectivity_ok() {
    dns_ok && internet_ok
}

connectivity_status() {
    local dns=down net=down
    dns_ok && dns=up
    internet_ok && net=up
    printf 'DNS=%s Internet=%s\n' "$dns" "$net"
}

bring_up_network() {
    local dev waited=0

    log "network: attempting to bring up connectivity"
    if command -v nmcli &>/dev/null; then
        nmcli networking on 2>/dev/null || true
        nmcli radio wifi on 2>/dev/null || true
        for dev in $(nmcli -t -f DEVICE,TYPE,STATE device \
            | awk -F: '$3=="disconnected" && $2!="loopback" {print $1}'); do
            nmcli device connect "$dev" 2>/dev/null || true
        done
        local conn
        conn="$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | head -1 | cut -d: -f1)"
        [[ -n "$conn" ]] || conn="$(nmcli -t -f NAME connection show 2>/dev/null | head -1)"
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

    log "network: still down after wait ($(connectivity_status))"
    return 1
}

prompt_skip_or_bring_up() {
    local detail="$1"

    if [[ -n "${DISPLAY:-}" ]] && command -v zenity &>/dev/null; then
        if zenity --question \
            --title="Ventoy persistence seed" \
            --width=420 \
            --text="Internet or DNS is not reachable before seeding.\n\n${detail}\n\n• Bring up network — try NetworkManager and wait for connectivity\n• Skip seed — continue to Grok without seeding" \
            --ok-label="Bring up network" \
            --cancel-label="Skip seed"; then
            return 0
        fi
        return 1
    fi

    printf 'seed-network-check: %s — skip seed? [y/N] ' "$detail" >&2
    if read -r -t 30 answer && [[ "$answer" =~ ^[Yy] ]]; then
        return 0
    fi
    return 1
}

ensure_network_before_seed() {
    if [[ "${SEED_SKIP_NETWORK_CHECK:-0}" == 1 ]]; then
        log "network: check skipped (SEED_SKIP_NETWORK_CHECK=1)"
        return 0
    fi

    if connectivity_ok; then
        log "network: OK ($(connectivity_status))"
        return 0
    fi

    log "network: down before seed ($(connectivity_status))"

    if prompt_skip_or_bring_up "$(connectivity_status)"; then
        if bring_up_network; then
            return 0
        fi
        if [[ -n "${DISPLAY:-}" ]] && command -v zenity &>/dev/null; then
            zenity --warning --title="Ventoy persistence seed" \
                --text="Network is still down after trying to connect.\n\nSkipping seed; Grok will start anyway." \
                2>/dev/null || true
        fi
        return 1
    fi

    log "network: user chose to skip seed"
    return 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    mkdir -p "$(dirname "$LOG")"
    if ensure_network_before_seed; then
        exit 0
    fi
    exit 1
fi