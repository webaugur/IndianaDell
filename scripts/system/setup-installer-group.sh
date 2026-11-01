#!/bin/bash
# Make a group-readable installers folder on the DataStore1 volume so apt (user _apt) can read .deb files
# without the "Download is performed unsandboxed as root" warning.
# Run on the machine with DataStore1 mounted:  sudo bash setup-installer-group.sh
set -eu
[ "$(id -u)" -eq 0 ] || { echo "Run with sudo." >&2; exit 1; }
TARGET_USER=${SUDO_USER:?run via sudo from your own account}
MNT=/media/$TARGET_USER/DataStore1
mountpoint -q "$MNT" || { echo "$MNT is not mounted." >&2; exit 1; }

getent group installer >/dev/null || groupadd --system installer
usermod -aG installer "$TARGET_USER"
usermod -aG installer _apt

install -d -o root -g installer -m 2775 "$MNT/installers"

command -v setfacl >/dev/null || apt-get install -y acl
setfacl -m g:installer:x "/media/$TARGET_USER" "$MNT"

echo "Done. Put .deb files in $MNT/installers. Log out and in so $TARGET_USER picks up the group."
