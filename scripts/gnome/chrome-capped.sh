#!/usr/bin/env bash
# chrome-capped — start Google Chrome inside the memory-limited chrome.slice.
# Every window/PWA started through this wrapper shares ONE budget (MemoryHigh/Max
# in ~/.config/systemd/user/chrome.slice). Past MemoryHigh the kernel reclaims
# Chrome's pages (into zram swap) instead of letting it squeeze the whole desktop;
# at MemoryMax the kernel OOM-kills Chrome only.
# Extra flags: CHROME_CAPPED_FLAGS="..." in the environment.
CHROME=/opt/google/chrome/google-chrome
FLAGS=(
  --renderer-process-limit=8                 # fold non-isolated tabs into fewer processes
  --js-flags=--max-old-space-size=3072       # cap each renderer's JS heap at 3 GiB
)
# shellcheck disable=SC2206
FLAGS+=(${CHROME_CAPPED_FLAGS:-})
if systemctl --user cat chrome.slice >/dev/null 2>&1; then
  exec systemd-run --user --scope --quiet --slice=chrome.slice -- "$CHROME" "${FLAGS[@]}" "$@"
fi
exec "$CHROME" "${FLAGS[@]}" "$@"
