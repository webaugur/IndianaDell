#!/bin/bash
# Block-device and filesystem sequential IO benchmark.
# Skips empty card-reader slots and active ZFS pool members for destructive tests.
# Usage:
#   sudo bin/iotest                  # survey all disks
#   sudo bin/iotest --disk sdc       # benchmark one blank disk (temp partition)
#   sudo COUNT=2048 bin/iotest       # 2 GiB per test (default 1024 MiB)

set -u
    10|
COUNT="${COUNT:-1024}"
BS="1M"
TARGET_DISK=""
MNT_BASE="/tmp/iotest-bench"
CLEANUP_TEMP_PART=1

usage() {
  cat <<'EOF'
Usage: sudo bin/iotest [--disk NAME] [--keep-partition]
    20|
  --disk NAME         Benchmark only this device (e.g. sdc or /dev/sdc).
                      Blank disks get a temporary partition + ext4 for real writes.
  --keep-partition    Leave the temporary partition/filesystem in place after --disk run.
  COUNT=N             Environment variable; size of each test in MiB (default 1024).

Notes:
  - Skips 0B card-reader phantom devices.
  - Skips raw block writes on imported ZFS pool members.
  - "Seq Write (filesystem)" uses a real file on a mounted filesystem, not /tmp alone.
    30|EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --disk)
      [[ $# -ge 2 ]] || { echo "Missing value for --disk" >&2; exit 1; }
      TARGET_DISK="${2#/dev/}"
      shift 2
      ;;
    40|    --keep-partition) CLEANUP_TEMP_PART=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "sudo required for block-device tests." >&2
  exit 1
fi
    50|
echo "=== Disk IO Benchmark ==="
echo "User: $(whoami) | Date: $(date) | Host: $(hostname)"
echo "Test size: ${COUNT} MiB per operation | Block size: ${BS}"
echo "=================================================="

skip_model() {
  local model="$1"
  [[ "$model" =~ Compact\ Flash|SM/xD|SD/MMC|M\.S\. ]] 
}
    60|
device_size_bytes() {
  blockdev --getsize64 "/dev/$1" 2>/dev/null || echo 0
}

has_partitions() {
  local dev="$1"
  lsblk -ln -o NAME "/dev/$dev" | grep -qE "^${dev}[0-9]+"
}

    70|is_zfs_member() {
  local dev="$1"
  lsblk -ln -o FSTYPE "/dev/$dev" 2>/dev/null | grep -q '^zfs_member$'
}

zfs_member_partitions() {
  local dev="$1"
  lsblk -ln -o NAME,FSTYPE "/dev/$dev" | awk '$2 == "zfs_member" {print $1}'
}

    80|print_dd_result() {
  local label="$1"
  local output="$2"
  if echo "$output" | grep -q 'copied'; then
    echo "$output" | tail -1 | awk -v lbl="$label" '{print lbl ": " $0}'
  else
    echo "${label}: FAILED — $(echo "$output" | tail -1)"
  fi
}

    90|run_dd_read() {
  local src="$1"
  local label="$2"
  local count="${3:-$COUNT}"
  local out

  out=$(dd if="$src" of=/dev/null bs="$BS" count="$count" iflag=direct 2>&1 | tail -1) || true
  if echo "$out" | grep -q 'copied'; then
    print_dd_result "$label" "$out"
    return
   100|  fi

  out=$(dd if="$src" of=/dev/null bs="$BS" count="$count" 2>&1 | tail -1) || true
  print_dd_result "$label (no direct IO)" "$out"
}

fs_preferred_count() {
  local dir="$1"
  local avail_k avail_m max_safe
  avail_k=$(df -Pk "$dir" | awk 'NR==2 {print $4}')
   110|  avail_m=$((avail_k / 1024))
  max_safe=$((avail_m / 2))
  if (( max_safe < 64 )); then
    echo 0
  elif (( max_safe < COUNT )); then
    echo "$max_safe"
  else
    echo "$COUNT"
  fi
}
   120|
run_dd_write_read() {
  local dir="$1"
  local label_prefix="$2"
  local count file out fstype direct_flags

  count=$(fs_preferred_count "$dir")
  if (( count == 0 )); then
    echo "${label_prefix}: skipped (mount too small for meaningful test)"
    return
   130|  fi

  fstype=$(findmnt -no FSTYPE "$dir" 2>/dev/null || echo unknown)
  direct_flags=(oflag=direct)
  read_flags=(iflag=direct)
  case "$fstype" in
    vfat|exfat|ntfs|ntfs3|fuseblk)
      direct_flags=()
      read_flags=()
      ;;
   140|  esac

  mkdir -p "$dir"
  file="$dir/iotest-${RANDOM}.bin"
  out=$(dd if=/dev/zero of="$file" bs="$BS" count="$count" "${direct_flags[@]}" conv=fdatasync 2>&1 | tail -1) || true
  print_dd_result "${label_prefix} Write (${count} MiB, ${fstype})" "$out"

  out=$(dd if="$file" of=/dev/null bs="$BS" "${read_flags[@]}" 2>&1 | tail -1) || true
  print_dd_result "${label_prefix} Read (${count} MiB)" "$out"

   150|  rm -f "$file"
}

mounted_writable_targets() {
  local dev="$1"
  lsblk -ln -o NAME,MOUNTPOINT,FSTYPE "/dev/$dev" | while read -r part mp fstype; do
    [[ -z "$mp" || "$mp" == "[SWAP]" ]] && continue
    [[ -d "$mp" && -w "$mp" ]] || continue
    echo "$mp"
  done
   160|}

bench_blank_disk() {
  local dev="$1"
  local model="$2"
  local disk="/dev/$dev"
  local part="${disk}-part1"
  local mnt="${MNT_BASE}-${dev}"
  local min_bytes=$(( (COUNT + 256) * 1024 * 1024 ))

   170|  if [[ "$(device_size_bytes "$dev")" -lt "$min_bytes" ]]; then
    echo "Status: disk too small for ${COUNT} MiB test"
    return
  fi

  if has_partitions "$dev"; then
    echo "Status: disk has existing partitions; refusing destructive setup"
    echo "        Wipe the disk first, or benchmark a mounted filesystem instead."
    return
  fi
   180|
  echo "Status: blank disk — creating temporary partition for real write test"
  parted -s "$disk" mklabel gpt mkpart primary ext4 1MiB 100%
  partprobe "$disk" 2>/dev/null || true
  udevadm settle
  sleep 1

  if [[ ! -b "$part" ]]; then
    echo "Status: failed to create ${part}"
    return
   190|  fi

  mkfs.ext4 -F -L iotest-temp "$part" >/dev/null
  mkdir -p "$mnt"
  mount "$part" "$mnt"
  run_dd_write_read "$mnt" "Seq"
  umount "$mnt"
  rmdir "$mnt" 2>/dev/null || true

  if [[ "$CLEANUP_TEMP_PART" -eq 1 ]]; then
   200|    wipefs -a "$part" >/dev/null 2>&1 || true
    wipefs -a "$disk" >/dev/null 2>&1 || true
    parted -s "$disk" mklabel gpt >/dev/null
    partprobe "$disk" 2>/dev/null || true
    echo "Status: temporary partition removed; disk left blank"
  else
    echo "Status: left ${part} formatted ext4 (label iotest-temp)"
  fi
}

   210|bench_device() {
  local dev="$1"
  local size model
  size=$(lsblk -dn -o SIZE "/dev/$dev" 2>/dev/null || echo "?")
  model=$(lsblk -dn -o MODEL "/dev/$dev" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  echo ""
  echo "--- /dev/${dev} (${size}, ${model:-unknown model}) ---"

  if [[ "$size" == "0B" ]] || skip_model "$model"; then
   220|    echo "Status: skipped (empty slot / card reader)"
    return
  fi

  if is_zfs_member "$dev"; then
    echo "Status: ZFS pool member — skipping destructive raw writes"
    local part mp tested=0
    while read -r part; do
      run_dd_read "/dev/$part" "Seq Read (raw /dev/$part)"
    done < <(zfs_member_partitions "$dev")
   230|    while read -r mp; do
      [[ -z "$mp" ]] && continue
      echo "Mount: $mp"
      run_dd_write_read "$mp" "Seq (filesystem)"
      tested=1
    done < <(mounted_writable_targets "$dev")
    [[ "$tested" -eq 1 ]] || true
    return
  fi

   240|  if has_partitions "$dev"; then
    local mp tested=0
    while read -r mp; do
      [[ -z "$mp" ]] && continue
      echo "Mount: $mp"
      run_dd_write_read "$mp" "Seq (filesystem)"
      tested=1
    done < <(mounted_writable_targets "$dev")

    if [[ "$tested" -eq 0 ]]; then
   250|      echo "Status: partitioned but not mounted — read-only raw test"
      run_dd_read "/dev/$dev" "Seq Read (raw)"
    fi
    return
  fi

  bench_blank_disk "$dev" "$model"
}

mapfile -t DEVICES < <(lsblk -d -n -o NAME,TYPE | awk '$2=="disk" && $1 ~ /^(sd|nvme|vd)/ {print $1}')
   260|
if [[ -n "$TARGET_DISK" ]]; then
  found=0
  for dev in "${DEVICES[@]}"; do
    if [[ "$dev" == "$TARGET_DISK" ]]; then
      bench_device "$dev"
      found=1
      break
    fi
  done
   270|  if [[ "$found" -eq 0 ]]; then
    echo "Device not found: $TARGET_DISK" >&2
    exit 1
  fi
else
  for dev in "${DEVICES[@]}"; do
    bench_device "$dev"
  done
fi

   280|echo ""
echo "=== ZFS pools ==="
zpool list -v 2>/dev/null || echo "No ZFS pools"
echo ""
zpool status -v 2>/dev/null || true
