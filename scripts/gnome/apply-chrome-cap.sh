#!/usr/bin/env bash
# apply-chrome-cap — cap Chrome's RAM with a systemd user slice and point its launchers at chrome-capped.
# No sudo needed.   Usage: bin/apply-chrome-cap [--high 5G] [--max 6G] | --revert
# Note: Chrome rewrites its own PWA .desktop files on update; re-run this after a Chrome update.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HIGH=5G; MAX=6G; REVERT=0
while [[ $# -gt 0 ]]; do case "$1" in
  --high) HIGH=$2; shift 2;; --max) MAX=$2; shift 2;; --revert) REVERT=1; shift;;
  -h|--help) sed -n '2,5p' "$0"; exit 0;; *) echo "unknown: $1" >&2; exit 1;; esac; done
APPS="$HOME/.local/share/applications"; UNITDIR="$HOME/.config/systemd/user"; BK="$HOME/Backups/chrome-cap"
WRAP="$HOME/bin/chrome-capped"
mkdir -p "$APPS" "$UNITDIR" "$BK" "$HOME/bin"
ALIASES="$HOME/.bash_aliases"; MARK_BEGIN="# >>> indianadell chrome-cap >>>"; MARK_END="# <<< indianadell chrome-cap <<<"
strip_aliases() { [[ -f $ALIASES ]] && sed -i "/^${MARK_BEGIN//\//\\/}\$/,/^${MARK_END//\//\\/}\$/d" "$ALIASES" || true; }

if [[ $REVERT -eq 1 ]]; then
  rm -f "$UNITDIR/chrome.slice" "$WRAP"; strip_aliases
  for f in "$BK"/*.desktop; do [[ -e $f ]] || continue; cp -f "$f" "$APPS/$(basename "$f")"; done
  for n in google-chrome com.google.Chrome; do [[ -e $BK/$n.desktop.system ]] && rm -f "$APPS/$n.desktop"; done
  systemctl --user daemon-reload; update-desktop-database "$APPS" 2>/dev/null || true
  echo "Reverted."; exit 0
fi

install -m 755 "$ROOT/scripts/gnome/chrome-capped.sh" "$WRAP"
cat > "$UNITDIR/chrome.slice" <<UNIT
[Unit]
Description=Memory budget for Google Chrome (IndianaDell apply-chrome-cap)
[Slice]
MemoryHigh=$HIGH
MemoryMax=$MAX
MemoryAccounting=yes
CPUWeight=80
IOWeight=50
UNIT
systemctl --user daemon-reload

# System launchers: copy to the user dir with Exec rewritten.
for n in google-chrome com.google.Chrome; do
  src=/usr/share/applications/$n.desktop; [[ -e $src ]] || continue
  if [[ ! -e $APPS/$n.desktop ]]; then touch "$BK/$n.desktop.system"; fi
  sed "s#^Exec=/usr/bin/google-chrome-stable#Exec=$WRAP#" "$src" > "$APPS/$n.desktop"
done
# Chrome-generated PWA launchers: back up, then rewrite Exec.
for f in "$APPS"/chrome-*.desktop; do
  [[ -e $f ]] || continue
  b="$BK/$(basename "$f")"; [[ -e $b ]] || cp "$f" "$b"
  sed -i "s#^Exec=/opt/google/chrome/google-chrome#Exec=$WRAP#" "$f"
done
update-desktop-database "$APPS" 2>/dev/null || true
# Terminal aliases (~/.bashrc sources ~/.bash_aliases on Ubuntu).
strip_aliases
cat >> "$ALIASES" <<ALIAS
$MARK_BEGIN
alias google-chrome='$WRAP'
alias google-chrome-stable='$WRAP'
alias chrome='$WRAP'
$MARK_END
ALIAS
echo "Chrome slice: MemoryHigh=$HIGH MemoryMax=$MAX"
systemctl --user cat chrome.slice | sed -n '1,12p'
echo "Wrapper: $WRAP   (close all Chrome windows, then relaunch from the app grid)"
