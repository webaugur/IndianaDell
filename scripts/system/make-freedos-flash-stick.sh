#!/bin/bash
# make-freedos-flash-stick.sh — turn a USB stick into a bootable FreeDOS (FAT32)
# stick that carries Dell BIOS updaters (written for the Latitude E6410, legacy BIOS).
#
# Usage:
#   sudo bash make-freedos-flash-stick.sh /dev/sdX [bios.exe ...]
#   bash make-freedos-flash-stick.sh --image FILE [bios.exe ...]   # test: build a 256 MiB disk image, no root
#
# Env:
#   FREEDOS_ISO  FreeDOS 1.4 ISO (must exist on THIS machine).
#                Default: /run/media/user/Wiggly/FreeDOS_14.iso, then ~/Grok_Automation/FreeDOS_14.iso
#   ASSUME_YES=1 skip the typed confirmation (image mode never asks).
#
# Boot chain: syslinux mbr.bin -> ldlinux (FAT32) -> chain.c32 freedos=KERNEL.SYS -> FreeDOS -> AUTOEXEC.BAT
# Needs: parted, mkfs.vfat (dosfstools), syslinux + syslinux-common, mtools, p7zip-full.
# Everything is written with mtools; the stick is never mounted. Re-running wipes and rebuilds it.
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }
SYSLINUX_BIOS=/usr/lib/syslinux/modules/bios
MBR_BIN=/usr/lib/syslinux/mbr/mbr.bin

MODE=device
if [ "${1:-}" = "--image" ]; then MODE=image; shift; fi
[ $# -ge 1 ] || die "usage: sudo bash $0 /dev/sdX [bios.exe ...]  |  $0 --image FILE [bios.exe ...]"
TARGET=$1; shift

for t in parted mkfs.vfat syslinux mcopy mmd 7z sfdisk; do
  command -v "$t" >/dev/null 2>&1 || die "missing $t (apt install parted dosfstools syslinux syslinux-common mtools p7zip-full fdisk)"
done
[ -f "$MBR_BIN" ] && [ -f "$SYSLINUX_BIOS/chain.c32" ] || die "syslinux-common files missing ($MBR_BIN, $SYSLINUX_BIOS/chain.c32)"

ISO=${FREEDOS_ISO:-}
if [ -z "$ISO" ]; then
  for c in /run/media/user/Wiggly/FreeDOS_14.iso "${SUDO_USER:+/home/$SUDO_USER}/Grok_Automation/FreeDOS_14.iso" "$HOME/Grok_Automation/FreeDOS_14.iso"; do
    [ -f "$c" ] && { ISO=$c; break; }
  done
fi
[ -n "$ISO" ] && [ -f "$ISO" ] || die "FreeDOS ISO not found; set FREEDOS_ISO=/path/FreeDOS_14.iso"

# BIOS files: check they exist and give each an 8.3 name (E6410Ann.EXE)
BIOS_SRC=(); BIOS_DOS=()
for f in "$@"; do
  [ -f "$f" ] || die "no such file: $f"
  b=$(basename "$f" | tr '[:lower:]' '[:upper:]')
  rev=$(printf '%s\n' "$b" | sed -n 's/.*A\([0-9][0-9]\)\.EXE$/\1/p')
  [ -n "$rev" ] || die "can't find a BIOS revision (Ann.exe) in $f"
  BIOS_SRC+=("$f"); BIOS_DOS+=("E6410A$rev.EXE")
done

if [ "$MODE" = device ]; then
  [ "$(id -u)" -eq 0 ] || die "run with sudo"
  [ -b "$TARGET" ] || die "$TARGET is not a block device"
  name=$(basename "$(readlink -f "$TARGET")")
  [ -e "/sys/block/$name" ] || die "$TARGET is a partition; give the whole disk (e.g. /dev/sdb)"
  [ "$(cat /sys/block/$name/removable)" = 1 ] || die "$name is not removable"
  tran=$(lsblk -dno TRAN "/dev/$name" | tr -d ' ')
  [ "$tran" = usb ] || die "$name transport is '$tran', not usb"
  bytes=$(lsblk -bdno SIZE "/dev/$name" | tr -d ' ')
  [ "$bytes" -gt 0 ] && [ "$bytes" -lt $((128*1024*1024*1024)) ] || die "$name size $bytes is not between 0 and 128 GB"
  rootsrc=$(findmnt -no SOURCE / || true)
  while read -r src mp; do
    case "$src" in /dev/${name}|/dev/${name}[0-9]*|/dev/${name}p[0-9]*)
      case "$mp" in /|/boot*|/usr*|/var*|/home*|/etc*|"[SWAP]") die "$src is mounted at $mp (system filesystem)";; esac;;
    esac
  done < <(lsblk -lnpo NAME,MOUNTPOINT "/dev/$name" | awk 'NF==2')
  case "$rootsrc" in /dev/${name}*) die "root filesystem is on $name";; esac
  echo "Target: /dev/$name  $(lsblk -dno VENDOR,MODEL "/dev/$name" | xargs)  $((bytes/1000000)) MB"
  lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "/dev/$name"
  echo "ALL DATA ON /dev/$name WILL BE ERASED."
  if [ "${ASSUME_YES:-0}" != 1 ]; then
    read -r -p "Type $name to continue: " ans
    [ "$ans" = "$name" ] || die "not confirmed"
  fi
  # unmount any of its partitions (e.g. desktop auto-mount)
  for p in $(lsblk -lnpo NAME "/dev/$name" | tail -n +2); do
    umount "$p" 2>/dev/null || true
  done
  DISK=/dev/$name
else
  rm -f "$TARGET"
  truncate -s 256M "$TARGET"
  DISK=$TARGET
fi

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

echo ">> extracting FreeDOS files from $ISO"
7z e -y -o"$WORK/iso" "$ISO" FDOS-x86/KERNEL.SYS COMMAND.COM freedos/bin/edit.exe freedos/bin/edit.hlp >/dev/null
for f in KERNEL.SYS COMMAND.COM edit.exe edit.hlp; do [ -s "$WORK/iso/$f" ] || die "$f not found in ISO"; done

echo ">> partitioning $DISK (MBR, one active FAT32 partition)"
wipefs -a "$DISK" >/dev/null 2>&1 || true
printf 'label: dos\nstart=2048, type=c, bootable\n' | sfdisk --no-reread "$DISK" >/dev/null
dd if="$MBR_BIN" of="$DISK" bs=440 count=1 conv=notrunc 2>/dev/null

if [ "$MODE" = device ]; then
  partprobe "$DISK" 2>/dev/null || blockdev --rereadpt "$DISK" 2>/dev/null || true
  command -v udevadm >/dev/null && udevadm settle || sleep 2
  PART=$(lsblk -lnpo NAME "$DISK" | sed -n 2p)
  [ -b "$PART" ] || die "partition node not found on $DISK"
else
  PART=$WORK/fs.img
  sectors=$(( $(stat -c %s "$DISK") / 512 - 2048 ))
  truncate -s $((sectors*512)) "$PART"
fi

mkfs.vfat -F 32 -n FLASH -h 2048 "$PART" >/dev/null
MTOOLS_SKIP_CHECK=1 mmd -i "$PART" ::/syslinux
syslinux --install --directory /syslinux "$PART"

# DOS text files need CRLF
dosfile() { sed 's/$/\r/' > "$1"; }
cat <<'CFG' | dosfile "$WORK/syslinux.cfg"
DEFAULT freedos
PROMPT 0
TIMEOUT 0
LABEL freedos
  COM32 /syslinux/chain.c32
  APPEND freedos=/KERNEL.SYS
CFG
cat <<'CFG' | dosfile "$WORK/FDCONFIG.SYS"
FILES=40
BUFFERS=20
LASTDRIVE=Z
SHELL=C:\COMMAND.COM C:\ /E:1024 /P=C:\AUTOEXEC.BAT
CFG
{
  echo '@ECHO OFF'
  echo 'SET DOSDIR=C:\FDOS'
  echo 'SET PATH=C:\;C:\FDOS\BIN'
  echo 'SET HELPPATH=C:\FDOS\BIN'
  echo 'ECHO.'
  echo 'ECHO  FreeDOS BIOS flash stick (Dell Latitude E6410)'
  echo 'ECHO  ---------------------------------------------'
  echo 'ECHO  Keep the AC adapter plugged in. Do not power off while flashing.'
  echo 'ECHO  Order: from A10 or older, flash A11 first, then the newer one.'
  echo 'ECHO.'
} > "$WORK/AUTOEXEC.BAT.u"

# Flash batch files: A11 (or lowest) first, ascending
n=0
mapfile -t ORDER < <(for i in "${!BIOS_DOS[@]}"; do echo "${BIOS_DOS[$i]} $i"; done | sort -u -k1,1 | awk '{print $2}')
for i in "${ORDER[@]}"; do
  n=$((n+1)); exe=${BIOS_DOS[$i]}
  {
    echo '@ECHO OFF'
    echo "ECHO Step $n: flash $exe"
    echo "ECHO The laptop reboots and flashes by itself. Keep AC power connected."
    echo 'ECHO Press Ctrl+C to cancel, or'
    echo 'PAUSE'
    echo "C:\\$exe"
  } | dosfile "$WORK/FLASH$n.BAT"
  echo "ECHO  FLASH$n  - runs $exe" >> "$WORK/AUTOEXEC.BAT.u"
done
[ $n -gt 0 ] || echo 'ECHO  (no BIOS files were copied to this stick)' >> "$WORK/AUTOEXEC.BAT.u"
{ echo 'ECHO  EDIT     - FreeDOS editor'; echo 'ECHO.'; } >> "$WORK/AUTOEXEC.BAT.u"
dosfile "$WORK/AUTOEXEC.BAT" < "$WORK/AUTOEXEC.BAT.u"

echo ">> copying files"
export MTOOLS_SKIP_CHECK=1
M=(-i "$PART")
mcopy "${M[@]}" -o "$SYSLINUX_BIOS/chain.c32" "$SYSLINUX_BIOS/libcom32.c32" "$SYSLINUX_BIOS/libutil.c32" "$WORK/syslinux.cfg" ::/syslinux/
mcopy "${M[@]}" -o "$WORK/iso/KERNEL.SYS" "$WORK/iso/COMMAND.COM" "$WORK/FDCONFIG.SYS" "$WORK/AUTOEXEC.BAT" ::/
mmd "${M[@]}" ::/FDOS ::/FDOS/BIN
mcopy "${M[@]}" -o "$WORK/iso/edit.exe" ::/FDOS/BIN/EDIT.EXE
mcopy "${M[@]}" -o "$WORK/iso/edit.hlp" ::/FDOS/BIN/EDIT.HLP
for i in "${!BIOS_SRC[@]}"; do mcopy "${M[@]}" -o "${BIOS_SRC[$i]}" "::/${BIOS_DOS[$i]}"; done
for ((k=1;k<=n;k++)); do mcopy "${M[@]}" -o "$WORK/FLASH$k.BAT" ::/; done

if [ "$MODE" = image ]; then
  dd if="$PART" of="$DISK" bs=1M seek=1 conv=notrunc status=none
fi
sync
mdir "${M[@]}" -/ ::/ 2>/dev/null | grep -vE '^\s*$' || true
echo ">> done: $DISK. Boot the E6410 with F12 -> USB Storage Device."
