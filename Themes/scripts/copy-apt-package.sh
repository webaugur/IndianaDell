#!/usr/bin/env bash
# Copy files owned by an apt package under /usr/share into Themes mirror.
set -euo pipefail
PKG="${1:?package name}"
DEST="${2:?destination dir}"

if ! dpkg-query -W -f='${Status}' "$PKG" 2>/dev/null | grep -q 'install ok installed'; then
  echo "Package not installed: $PKG" >&2
  exit 1
fi

mkdir -p "$DEST"
count=0
while IFS= read -r path; do
  [[ "$path" == /usr/share/* ]] || continue
  [[ -f "$path" ]] || continue
  install -D "$path" "$DEST${path}"
  count=$((count + 1))
done < <(dpkg -L "$PKG" 2>/dev/null)

echo "$PKG -> $DEST ($count files under /usr/share)"