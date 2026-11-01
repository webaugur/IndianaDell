#!/bin/bash
# Remove snapd and Firefox (snap) from Ubuntu 26.04 and keep them from coming back.
# Firmware updates and the app store come back as the regular deb packages (fwupd, gnome-software).
# Your Firefox profile in ~/snap is left alone; delete ~/snap yourself when you are sure.
# Run:  sudo bash remove-snapd.sh
set -eu
[ "$(id -u)" -eq 0 ] || { echo "Run with sudo." >&2; exit 1; }
pgrep -x firefox >/dev/null && { echo "Close Firefox first." >&2; exit 1; }

# Stop if removing snapd would take the desktop with it.
if apt-get -s purge snapd | grep '^Remv' | grep -E 'ubuntu-desktop|gdm3|gnome-shell|ubuntu-standard'; then
  echo "Purging snapd would remove the packages listed above. Stopping." >&2; exit 1
fi

# Replacements first.
apt-get install -y fwupd gnome-software || true

# Block snapd and Ubuntu's Firefox stub (which only installs the snap) from returning.
cat > /etc/apt/preferences.d/no-snapd <<'P'
Package: snapd
Pin: release a=*
Pin-Priority: -10
P
cat > /etc/apt/preferences.d/no-firefox-stub <<'P'
Package: firefox*
Pin: release o=Ubuntu
Pin-Priority: -1
P

snap remove --purge firefox 2>/dev/null || true
apt-get purge -y firefox snapd gnome-software-plugin-snap snapd-desktop-integration 2>/dev/null || apt-get purge -y snapd
apt-get autoremove -y --purge
systemctl daemon-reload

echo "Done. Leftover snap folders (check, then delete yourself):"
found=0
for d in /snap /var/lib/snapd /var/snap "$HOME/snap" ${SUDO_USER:+"/home/$SUDO_USER/snap"}; do
  [ -e "$d" ] && { echo "  $d"; found=1; }
done
[ "$found" -eq 1 ] || echo "  none"
