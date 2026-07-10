#!/usr/bin/env bash
# Download and extract Fohdeesha PERC crossflash bundle (FreeDOS + Linux ISOs).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CACHE="${PERC_CACHE:-$ROOT/.cache/perc-crossflash}"
ZIP_NAME="perc-crossflash-v2.6.zip"
ZIP_URL="${FOHDEESHA_ZIP_URL:-https://fohdeesha.com/docs/store/perc/perc-crossflash-v2.6.zip}"
ZIP_MD5="3fa29fe46b879058b3a8db9181cb519e"
INCOMING="$ROOT/FactoryDocs/_incoming"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { log "ERROR: $*"; exit 1; }

mkdir -p "$CACHE" "$CACHE/extract"

resolve_zip() {
    if [[ -n "${PERC_ZIP:-}" && -f "$PERC_ZIP" ]]; then
        printf '%s\n' "$PERC_ZIP"
        return 0
    fi
    if [[ -f "$CACHE/$ZIP_NAME" ]]; then
        printf '%s\n' "$CACHE/$ZIP_NAME"
        return 0
    fi
    local incoming
    for incoming in "$INCOMING"/perc-crossflash*.zip "$INCOMING"/PERC*.zip; do
        [[ -f "$incoming" ]] || continue
        printf '%s\n' "$incoming"
        return 0
    done
    return 1
}

download_zip() {
    local dest="$CACHE/$ZIP_NAME"
    log "Downloading $ZIP_URL"
    curl -fL --retry 3 --retry-delay 5 -o "$dest.part" "$ZIP_URL"
    mv "$dest.part" "$dest"
    log "Saved $dest"
    printf '%s\n' "$dest"
}

verify_md5() {
    local zip="$1"
    command -v md5sum >/dev/null || { log "WARN: md5sum missing — skip checksum"; return 0; }
    local got
    got="$(md5sum "$zip" | awk '{print $1}')"
    [[ "$got" == "$ZIP_MD5" ]] || die "MD5 mismatch for $zip (got $got, expected $ZIP_MD5)"
    log "MD5 OK"
}

extract_zip() {
    local zip="$1"
    rm -rf "$CACHE/extract"
    mkdir -p "$CACHE/extract"
    unzip -q -o "$zip" -d "$CACHE/extract"
    log "Extracted to $CACHE/extract"
}

find_isos() {
    mapfile -t _perc_isos < <(find "$CACHE/extract" -iname '*.iso' | sort)
    ((${#_perc_isos[@]} >= 2)) || die "Expected 2+ ISOs in bundle, found ${#_perc_isos[@]}"
    for iso in "${_perc_isos[@]}"; do
        log "  ISO: $iso"
    done
}

main() {
    local zip
    if zip="$(resolve_zip)"; then
        log "Using existing zip: $zip"
        [[ "$zip" != "$CACHE/$ZIP_NAME" ]] && cp -f "$zip" "$CACHE/$ZIP_NAME"
    else
        zip="$(download_zip)"
    fi
    verify_md5 "$CACHE/$ZIP_NAME"
    extract_zip "$CACHE/$ZIP_NAME"
    find_isos
    log "Ready: $CACHE/extract"
}

main "$@"