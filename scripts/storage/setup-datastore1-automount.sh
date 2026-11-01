#!/bin/bash
# setup-datastore1-automount.sh: unlock DataStore1 at boot with a keyfile on the
# encrypted root, mount it via crypttab/fstab (nofail, 5s timeout), and install
# /usr/local/sbin/datastore1 (eject|mount|status) for swapping the module bay.
# Written for Safar's DataStore1 LUKS volume, UUID e65a9ecc-36de-468f-9953-761421991865,
# hard-coded below (and in the helper); edit UUID/MNT for other machines.
# Unlock and mount DataStore1 at boot with a keyfile; never block boot if the disk is absent.
# Run once:  sudo bash setup-datastore1-automount.sh
set -eu
[ "$(id -u)" -eq 0 ] || { echo "Run with sudo." >&2; exit 1; }

UUID=e65a9ecc-36de-468f-9953-761421991865      # LUKS container (sdb)
NAME=datastore1                                # new mapper name
KEY=/etc/cryptsetup-keys.d/$NAME.key           # on the encrypted root, root-only
MNT=/media/user/DataStore1
DEV=/dev/disk/by-uuid/$UUID
[ -e "$DEV" ] || { echo "LUKS disk $UUID not present." >&2; exit 1; }

# 1. keyfile (random, root-only) and add it as an extra LUKS key (asks your current passphrase once)
install -d -m 0700 /etc/cryptsetup-keys.d
if [ ! -e "$KEY" ]; then
  ( umask 077; head -c 64 /dev/urandom > "$KEY" )
  chmod 0400 "$KEY"
fi
if ! cryptsetup open --test-passphrase --key-file "$KEY" "$DEV" 2>/dev/null; then
  echo "Type the current DataStore1 passphrase to add the keyfile:"
  cryptsetup luksAddKey "$DEV" "$KEY"
fi

# 2. crypttab + fstab, nofail so a missing disk (DVD in the bay) never stops boot
cp -n /etc/crypttab /etc/crypttab.pre-datastore1
cp -n /etc/fstab /etc/fstab.pre-datastore1
grep -q "^$NAME " /etc/crypttab || \
  echo "$NAME UUID=$UUID $KEY luks,nofail,x-systemd.device-timeout=5s" >> /etc/crypttab
mkdir -p "$MNT"
grep -q " $MNT " /etc/fstab || \
  echo "/dev/mapper/$NAME $MNT ext4 defaults,nofail,x-systemd.device-timeout=5s 0 2" >> /etc/fstab

# 3. helper to take the disk out safely (for the DVD) and put it back
cat > /usr/local/sbin/datastore1 <<'HELP'
#!/bin/bash
# datastore1 eject | mount | status
set -u
UUID=e65a9ecc-36de-468f-9953-761421991865
NAME=datastore1
MNT=/media/user/DataStore1
KEY=/etc/cryptsetup-keys.d/$NAME.key
[ "$(id -u)" -eq 0 ] || exec sudo "$0" "$@"
case "${1:-status}" in
  eject)
    umount "$MNT" || { echo "Busy: close programs using DataStore1 (cd out of it too)." >&2; exit 1; }
    for m in /dev/mapper/$NAME /dev/mapper/luks-$UUID; do [ -e "$m" ] && cryptsetup close "$(basename "$m")"; done
    disk=$(readlink -f "/dev/disk/by-uuid/$UUID" 2>/dev/null)
    [ -n "$disk" ] && sync && echo 1 > "/sys/block/$(basename "$disk")/device/delete"
    echo "DataStore1 is unmounted, locked and detached. Safe to remove the drive." ;;
  mount)
    for h in /sys/class/scsi_host/host*/scan; do echo '- - -' > "$h"; done
    udevadm settle; sleep 2
    [ -e "/dev/disk/by-uuid/$UUID" ] || { echo "Disk not found. Check it is seated, or reboot." >&2; exit 1; }
    [ -e /dev/mapper/$NAME ] || cryptsetup open --key-file "$KEY" "/dev/disk/by-uuid/$UUID" "$NAME"
    mountpoint -q "$MNT" || mount "$MNT"
    echo "DataStore1 mounted at $MNT." ;;
  status) findmnt "$MNT" || echo "DataStore1 is not mounted." ;;
  *) echo "usage: datastore1 eject|mount|status" >&2; exit 2 ;;
esac
HELP
chmod 0755 /usr/local/sbin/datastore1

systemctl daemon-reload
echo
echo "Done. Backups: /etc/crypttab.pre-datastore1 and /etc/fstab.pre-datastore1."
echo "Reboot to switch over (it is mounted now by the desktop). After that DataStore1 mounts at boot with no prompt."
echo "To use the DVD:  sudo datastore1 eject   ...later:  sudo datastore1 mount"
