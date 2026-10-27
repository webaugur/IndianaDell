#!/usr/bin/env bash
# check-chrome-cap — re-apply the Chrome memory cap if an update (or a newly installed web app) un-did it.
# Run by chrome-cap-check.timer / .path (user units installed by apply-chrome-cap). Safe to run by hand.
# Exit 0 always; output goes to the journal:  journalctl --user -u chrome-cap-check
set -uo pipefail
APPS="$HOME/.local/share/applications"; WRAP="$HOME/bin/chrome-capped"
ROOT_FILE="$HOME/.config/chrome-cap/root"; SLICE="$HOME/.config/systemd/user/chrome.slice"
[[ -r $ROOT_FILE ]] || { echo "no $ROOT_FILE; run bin/apply-chrome-cap first"; exit 0; }
ROOT="$(cat "$ROOT_FILE")"
bad=()
[[ -x $WRAP ]] || bad+=("wrapper missing")
[[ -e $SLICE ]] || bad+=("chrome.slice missing")
for f in "$APPS"/chrome-*.desktop "$APPS"/google-chrome.desktop "$APPS"/com.google.Chrome.desktop; do
  [[ -e $f ]] || continue
  grep -q '^Exec=.*/opt/google/chrome/google-chrome\|^Exec=/usr/bin/google-chrome' "$f" && bad+=("$(basename "$f") bypasses the cap")
done
# system launcher present but no user override (Chrome package reinstalled)?
for n in google-chrome com.google.Chrome; do
  [[ -e /usr/share/applications/$n.desktop && ! -e $APPS/$n.desktop ]] && bad+=("$n.desktop override missing")
done
if ((${#bad[@]}==0)); then echo "chrome cap intact"; exit 0; fi
printf 'chrome cap damaged: %s\n' "${bad[*]}"
high=5G; max=6G
[[ -r $SLICE ]] && { h=$(sed -n 's/^MemoryHigh=//p' "$SLICE"); m=$(sed -n 's/^MemoryMax=//p' "$SLICE"); high=${h:-$high}; max=${m:-$max}; }
"$ROOT/bin/apply-chrome-cap" --high "$high" --max "$max" && echo "re-applied (high=$high max=$max)"
command -v notify-send >/dev/null && notify-send "Chrome cap re-applied" "An update had reset the Chrome launchers: ${bad[*]}" || true
exit 0
