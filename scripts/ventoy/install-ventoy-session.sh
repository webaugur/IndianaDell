#!/usr/bin/env bash
# Install Ventoy persistence session helpers into the ubuntu user home.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VENTOY="$ROOT/scripts/ventoy"

install -d "$HOME/bin" "$HOME/.config/autostart" "$HOME/.config/indianadell"
install -m755 "$VENTOY/grok-indianadell-launch.sh" "$HOME/bin/"
install -m755 "$VENTOY/seed-ventoy-persistence.sh" "$HOME/bin/"
install -m755 "$VENTOY/seed-network-check.sh" "$HOME/bin/"
install -m755 "$VENTOY/resolve-secrets.sh" "$HOME/bin/"
install -m644 "$VENTOY/grok-indianadell.desktop" "$HOME/.config/autostart/"
install -m644 "$ROOT/scripts/profile/indianadell-path.sh" "$HOME/.config/indianadell/path.sh"

if ! grep -q 'indianadell/path.sh' "$HOME/.bashrc" 2>/dev/null; then
    cat >>"$HOME/.bashrc" <<'EOF'

# >>> IndianaDell + user PATH (overrides system) >>>
[[ -r "$HOME/.config/indianadell/path.sh" ]] && source "$HOME/.config/indianadell/path.sh"
# <<< IndianaDell + user PATH <<<

# >>> IndianaDell secrets (rpool /home/user when available) >>>
[[ -r "$HOME/bin/resolve-secrets.sh" ]] && source "$HOME/bin/resolve-secrets.sh" && materialize_secrets_to_runtime_home quiet
# <<< IndianaDell secrets <<<
EOF
fi

printf 'Installed Ventoy session helpers to ~/bin and ~/.config\n'
printf 'Secrets stay on Ventoy persistence; runtime pulls from /home/user when rpool is available.\n'