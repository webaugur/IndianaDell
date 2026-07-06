# IndianaDell PATH — project tools/scripts override system binaries.
# Sourced from ~/.bashrc (and ~/.profile for non-bash login shells).

indianadell_resolve_root() {
    if [[ -n "${INDIANADELL_ROOT:-}" && -d "${INDIANADELL_ROOT}/bin" ]]; then
        printf '%s\n' "$INDIANADELL_ROOT"
        return 0
    fi
    local candidate
    for candidate in \
        "$HOME/Documents/IndianaDell" \
        "/home/user/Documents/IndianaDell"; do
        if [[ -d "$candidate/bin" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

indianadell_path_prepend() {
    local root entry cleaned="" p
    local -a paths=()
    local -a path_parts=()

    root="$(indianadell_resolve_root)" || return 0
    export INDIANADELL_ROOT="$root"

    paths+=("$root/bin")
    for entry in \
        "$root/scripts" \
        "$root/scripts/dell" \
        "$root/scripts/gpu" \
        "$root/scripts/gnome" \
        "$root/scripts/rebuild" \
        "$root/scripts/storage" \
        "$root/scripts/docs"; do
        [[ -d "$entry" ]] && paths+=("$entry")
    done

    [[ -d "$HOME/bin" ]] && paths+=("$HOME/bin")
    [[ -d "$HOME/.grok/bin" ]] && paths+=("$HOME/.grok/bin")
    [[ -d "$HOME/.local/bin" ]] && paths+=("$HOME/.local/bin")

    IFS=':' read -ra path_parts <<< "${PATH:-}"
    for p in "${path_parts[@]}"; do
        [[ -z "$p" ]] && continue
        local skip=0
        for entry in "${paths[@]}"; do
            if [[ "$p" == "$entry" ]]; then
                skip=1
                break
            fi
        done
        if (( ! skip )); then
            cleaned+="${p}:"
        fi
    done

    local prefix=""
    for entry in "${paths[@]}"; do
        prefix+="${entry}:"
    done

    export PATH="${prefix}${cleaned%:}"
}

indianadell_path_prepend