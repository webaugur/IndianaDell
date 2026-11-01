#!/usr/bin/env bash
#
# indianadell-tuning.sh — one hardware-adaptive performance-tuning tool for any
# IndianaDell-era Dell running Ubuntu/Debian (ZFS or ext4/btrfs/xfs root).
#
# Usage:
#   bin/apply-tuning report                 # no root: detected hardware + plan (paste this)
#   bin/apply-tuning status                 # no root: each step ok / differs / skipped
#   bin/apply-tuning apply --dry-run        # no root: exact actions, changes nothing
#   sudo bin/apply-tuning apply             # root steps (arc zram sysctl diskswap bfq initramfs ionice fast-boot [fast-login])
#   bin/apply-tuning apply                  # as your user: user steps (chrome-cap max-performance)
#   sudo bin/apply-tuning revert            # undo the root io steps (bin/revert-io-tuning)
# Options:
#   --only a,b    run only these steps        --skip a,b   skip these steps
#   --dry-run     print actions, change nothing
#   --config F    extra config file (after host profile and /etc/indianadell/tuning.conf)
# Steps: arc zram sysctl diskswap bfq initramfs ionice fast-boot fast-login chrome-cap max-performance
# Config precedence (later wins): computed defaults < etc/indianadell/hosts/<hostname>.conf (repo)
#   < /etc/indianadell/tuning.conf < --config FILE < environment variables.
#
set -uo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
ROOT_STEPS=(arc zram sysctl diskswap bfq initramfs ionice fast-boot fast-login)
USER_STEPS=(chrome-cap max-performance)
ALL_STEPS=("${ROOT_STEPS[@]}" "${USER_STEPS[@]}")
CFG_VARS=(ZRAM_SIZE ZRAM_ALGO ZRAM_PRIO ARC_MAX_GIB SWAPPINESS PAGE_CLUSTER BG_PROCS CHROME_HIGH CHROME_MAX
          ENABLE_FAST_LOGIN ENABLE_FAST_BOOT LOGIN_USER ZRAM_TAKEOVER FORCE_DESKTOP_POWER SKIP ONLY SWAPOFF_MARGIN_KB)

CMD="${1:-report}"; [[ $# -gt 0 ]] && shift
DRY=0; OPT_ONLY=""; OPT_SKIP=""; EXTRA_CFG=""
while [[ $# -gt 0 ]]; do case "$1" in
  --dry-run|-n) DRY=1; shift ;;
  --only) OPT_ONLY="$2"; shift 2 ;;  --only=*) OPT_ONLY="${1#*=}"; shift ;;
  --skip) OPT_SKIP="$2"; shift 2 ;;  --skip=*) OPT_SKIP="${1#*=}"; shift ;;
  --config) EXTRA_CFG="$2"; shift 2 ;;
  -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
  *) echo "unknown option: $1" >&2; exit 2 ;;
esac; done
case "$CMD" in report|status|apply|revert|plan) ;; -h|--help|help) sed -n '2,22p' "$0"; exit 0 ;;
  *) echo "unknown command: $CMD (report|status|apply|revert)" >&2; exit 2 ;; esac
[[ $CMD == plan ]] && { CMD=apply; DRY=1; }
IS_ROOT=0; [[ $EUID -eq 0 ]] && IS_ROOT=1

# ---------------------------------------------------------------- detection
HOST="$(hostname -s 2>/dev/null || cat /etc/hostname)"
MEM_KB=$(awk '/^MemTotal/{print $2}' /proc/meminfo)
MEM_GIB=$(( (MEM_KB + 524288) / 1048576 ))
ROOT_FS=$(findmnt -no FSTYPE / 2>/dev/null || echo unknown)
ZFS_LOADED=0; [[ -d /sys/module/zfs ]] && ZFS_LOADED=1
CHASSIS=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || echo 0)
PRODUCT=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo unknown)
LAPTOP=0
case "$CHASSIS" in 8|9|10|11|14|30|31|32) LAPTOP=1 ;; esac
ls /sys/class/power_supply/BAT* >/dev/null 2>&1 && LAPTOP=1
SESSION_TYPE="${XDG_SESSION_TYPE:-}"; DESKTOP="${XDG_CURRENT_DESKTOP:-}"
if [[ -z $DESKTOP ]] && command -v loginctl >/dev/null; then
  for s in $(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $1}'); do
    t=$(loginctl show-session "$s" -p Type --value 2>/dev/null); c=$(loginctl show-session "$s" -p Class --value 2>/dev/null)
    [[ $c == user && ( $t == wayland || $t == x11 ) ]] && { SESSION_TYPE=$t; DESKTOP=$(loginctl show-session "$s" -p Desktop --value 2>/dev/null); break; }
  done
fi
DM=none
if [[ -L /etc/systemd/system/display-manager.service ]]; then DM=$(basename "$(readlink -f /etc/systemd/system/display-manager.service)" .service); fi
HAS_GRUB=0; command -v update-grub >/dev/null && [[ -f /etc/default/grub ]] && HAS_GRUB=1
HAS_NM=0; systemctl cat NetworkManager.service >/dev/null 2>&1 && HAS_NM=1
HAS_CHROME=0; { [[ -e /usr/share/applications/google-chrome.desktop ]] || command -v google-chrome-stable >/dev/null; } && HAS_CHROME=1
HAS_GSETTINGS=0; command -v gsettings >/dev/null && HAS_GSETTINGS=1
INITRAMFS_TOOL=none; command -v update-initramfs >/dev/null && INITRAMFS_TOOL=update-initramfs
[[ $INITRAMFS_TOOL == none ]] && command -v dracut >/dev/null && INITRAMFS_TOOL=dracut

# Foreign zram managers (avoid double zram)
ZRAM_FOREIGN=""
[[ -x /usr/lib/systemd/system-generators/zram-generator || -x /lib/systemd/system-generators/zram-generator ]] && ZRAM_FOREIGN+="zram-generator "
for u in zram-config.service zramswap.service; do
  [[ $(systemctl is-enabled "$u" 2>/dev/null) == enabled ]] && ZRAM_FOREIGN+="${u%.service} "
done
ZRAM_FOREIGN="${ZRAM_FOREIGN% }"
OUR_ZRAM_UNIT=/etc/systemd/system/zram-swap.service

# Disks: name rota tran type
mapfile -t DISKS < <(lsblk -dnpo NAME,ROTA,TRAN,TYPE 2>/dev/null | awk '$4=="disk"{sub("/dev/","",$1); print $1, $2, ($3==""?"-":$3)}')

# ---------------------------------------------------------------- config
round_gib() { awk -v k="$1" -v f="$2" 'BEGIN{printf "%d", (k*f/1048576)+0.5}'; }
clamp() { local v=$1 lo=$2 hi=$3; (( v < lo )) && v=$lo; (( v > hi )) && v=$hi; echo "$v"; }
D_ZRAM_GIB=$(clamp "$(round_gib "$MEM_KB" 0.75)" 2 32)
D_ARC_GIB=$(clamp "$(round_gib "$MEM_KB" 0.25)" 1 16)
D_CHROME_MAX=$(clamp "$(round_gib "$MEM_KB" 0.375)" 2 64)
declare -A ENVSAVE=()
for v in "${CFG_VARS[@]}"; do [[ -n ${!v+x} ]] && ENVSAVE[$v]="${!v}"; done
ZRAM_SIZE="${D_ZRAM_GIB}G"; ZRAM_ALGO=zstd; ZRAM_PRIO=100; ARC_MAX_GIB=$D_ARC_GIB
SWAPPINESS=100; PAGE_CLUSTER=0; BG_PROCS="cargo rustc dsd-fme commander"
CHROME_MAX="${D_CHROME_MAX}G"; CHROME_HIGH="$((D_CHROME_MAX>2 ? D_CHROME_MAX-1 : 1))G"
ENABLE_FAST_LOGIN=0; ENABLE_FAST_BOOT=1; LOGIN_USER="${SUDO_USER:-}"; ZRAM_TAKEOVER=0
FORCE_DESKTOP_POWER=0; SKIP=""; ONLY=""; SWAPOFF_MARGIN_KB=1500000
[[ -z $LOGIN_USER && $IS_ROOT -eq 0 ]] && LOGIN_USER=$(id -un)
[[ -z $LOGIN_USER ]] && LOGIN_USER=$(getent passwd 1000 | cut -d: -f1)
CFG_FILES=()
for f in "$ROOT/etc/indianadell/hosts/$HOST.conf" /etc/indianadell/tuning.conf ${EXTRA_CFG:+"$EXTRA_CFG"}; do
  # shellcheck disable=SC1090
  [[ -r $f ]] && { source "$f"; CFG_FILES+=("$f"); }
done
for v in "${!ENVSAVE[@]}"; do printf -v "$v" '%s' "${ENVSAVE[$v]}"; done
[[ -n $OPT_ONLY ]] && ONLY="$OPT_ONLY"; SKIP="${SKIP:+$SKIP,}$OPT_SKIP"
ZRAM_BYTES=$(numfmt --from=iec "$ZRAM_SIZE")
ARC_BYTES=$(( ARC_MAX_GIB * 1073741824 ))

# ---------------------------------------------------------------- helpers
say()  { printf '%s\n' "$*"; }
hdr()  { printf '\n== %s ==\n' "$*"; }
run()  { if (( DRY )); then say "  would run: $*"; else say "  + $*"; "$@"; fi; }
# put_file PATH MODE CONTENT : idempotent install
put_file() {
  local p=$1 m=$2 c=$3
  if [[ -f $p ]] && [[ "$(cat "$p")" == "$c" ]]; then say "  ok: $p already correct"; return 1; fi
  if (( DRY )); then say "  would write $p:"; printf '%s\n' "$c" | sed 's/^/      | /'; return 0; fi
  install -d "$(dirname "$p")"; printf '%s\n' "$c" > "$p"; chmod "$m" "$p"; say "  wrote $p"; return 0
}
inlist() { local x=$1 l=",${2// /,},"; [[ $l == *",$x,"* ]]; }
want_step() {
  local s=$1
  [[ -n $ONLY ]] && ! inlist "$s" "$ONLY" && return 1
  inlist "$s" "$SKIP" && return 1
  return 0
}
is_root_step() { inlist "$1" "${ROOT_STEPS[*]}"; }
SUDO_CMD="sudo $ROOT/bin/apply-tuning apply"
# Rotational, non-USB disks (USB flash sticks and dock bridges often claim rotational=1).
rot_disks() { for d in "${DISKS[@]}"; do set -- $d; [[ $2 == 1 && $3 != usb ]] && echo "$1"; done; }
sched_of() { sed -n 's/.*\[\(.*\)\].*/\1/p' "/sys/block/$1/queue/scheduler" 2>/dev/null; }

# ---------------------------------------------------------------- steps
# Each step_X: in status mode (STATUS=1) prints ok/differs; otherwise applies (or dry-runs).
STATUS=0
step_arc() {
  if (( ! ZFS_LOADED )); then say "  skip: zfs module not loaded (root fs $ROOT_FS)"; return; fi
  local cur; cur=$(cat /sys/module/zfs/parameters/zfs_arc_max)
  say "  want zfs_arc_max=$ARC_BYTES (${ARC_MAX_GIB} GiB of ${MEM_GIB} GiB RAM); live=$cur"
  if (( STATUS )); then
    [[ $cur == "$ARC_BYTES" ]] && say "  live: ok" || say "  live: DIFFERS"
    [[ "$(cat /etc/modprobe.d/zfs-arc.conf 2>/dev/null)" == "options zfs zfs_arc_max=${ARC_BYTES}" ]] && say "  persistent: ok" || say "  persistent: DIFFERS"
    return; fi
  [[ $cur == "$ARC_BYTES" ]] && say "  ok: live value" || { if (( DRY )); then say "  would write $ARC_BYTES > /sys/module/zfs/parameters/zfs_arc_max"; else echo "$ARC_BYTES" > /sys/module/zfs/parameters/zfs_arc_max && say "  set live"; fi; }
  put_file /etc/modprobe.d/zfs-arc.conf 0644 "options zfs zfs_arc_max=${ARC_BYTES}" && NEED_INITRAMFS=1
}
zram_unit() {
cat <<UNIT
[Unit]
Description=zram compressed swap
After=local-fs.target
Before=swap.target
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'modprobe zram num_devices=1; echo ${ZRAM_ALGO} > /sys/block/zram0/comp_algorithm; echo ${ZRAM_SIZE} > /sys/block/zram0/disksize; mkswap /dev/zram0; swapon -p ${ZRAM_PRIO} /dev/zram0'
ExecStop=/bin/sh -c 'swapoff /dev/zram0; echo 1 > /sys/block/zram0/reset'
[Install]
WantedBy=swap.target
UNIT
}
step_zram() {
  say "  want ${ZRAM_SIZE} ${ZRAM_ALGO} prio ${ZRAM_PRIO} (rule: 75% of ${MEM_GIB} GiB RAM, clamped 2..32G => ${D_ZRAM_GIB}G; config may override)"
  if [[ -n $ZRAM_FOREIGN && $ZRAM_TAKEOVER != 1 ]]; then
    say "  skip: another zram manager is active ($ZRAM_FOREIGN); set ZRAM_TAKEOVER=1 to replace it"; return; fi
  local live=0 algo=""
  [[ -e /sys/block/zram0/disksize ]] && live=$(cat /sys/block/zram0/disksize) && algo=$(sed -n 's/.*\[\(.*\)\].*/\1/p' /sys/block/zram0/comp_algorithm)
  say "  live: zram0 disksize=$live algo=${algo:-none} unit=$([[ -f $OUR_ZRAM_UNIT ]] && echo present || echo absent)"
  if (( STATUS )); then
    [[ $live == "$ZRAM_BYTES" && $algo == "$ZRAM_ALGO" ]] && say "  live: ok" || say "  live: DIFFERS"
    [[ "$(cat $OUR_ZRAM_UNIT 2>/dev/null)" == "$(zram_unit)" ]] && say "  unit: ok" || say "  unit: DIFFERS"
    return; fi
  if [[ -n $ZRAM_FOREIGN ]]; then
    for u in zram-config zramswap; do [[ $ZRAM_FOREIGN == *$u* ]] && run systemctl disable --now "$u.service"; done
    [[ $ZRAM_FOREIGN == *zram-generator* ]] && put_file /etc/systemd/zram-generator.conf 0644 "# disabled by IndianaDell tuning (ZRAM_TAKEOVER=1)" ; true
  fi
  local changed=0
  put_file "$OUR_ZRAM_UNIT" 0644 "$(zram_unit)" && changed=1
  if (( changed )); then run systemctl daemon-reload; fi
  if [[ $(systemctl is-enabled zram-swap.service 2>/dev/null) != enabled ]]; then run systemctl enable zram-swap.service; fi
  if [[ $live == 0 || ! -e /sys/block/zram0 ]]; then run systemctl start zram-swap.service
  elif [[ $live != "$ZRAM_BYTES" ]]; then
    say "  size differs: resizing via resize-zram-swap (only if contents fit in free RAM)"
    run "$ROOT/scripts/storage/resize-zram-swap.sh" "$ZRAM_SIZE"
  else say "  ok: live zram already ${ZRAM_SIZE}"; fi
}
step_sysctl() {
  local want; want=$(printf 'vm.swappiness=%s\nvm.page-cluster=%s' "$SWAPPINESS" "$PAGE_CLUSTER")
  local s p; s=$(cat /proc/sys/vm/swappiness); p=$(cat /proc/sys/vm/page-cluster)
  say "  want swappiness=$SWAPPINESS page-cluster=$PAGE_CLUSTER; live $s/$p"
  if (( STATUS )); then
    [[ $s == "$SWAPPINESS" && $p == "$PAGE_CLUSTER" ]] && say "  live: ok" || say "  live: DIFFERS"
    [[ "$(cat /etc/sysctl.d/60-zram.conf 2>/dev/null)" == "$want" ]] && say "  persistent: ok" || say "  persistent: DIFFERS"; return; fi
  put_file /etc/sysctl.d/60-zram.conf 0644 "$want"
  [[ $s == "$SWAPPINESS" && $p == "$PAGE_CLUSTER" ]] && say "  ok: live values" || run sysctl -q -p /etc/sysctl.d/60-zram.conf
}
step_diskswap() {
  local any=0 name used avail
  while read -r name _t _s used _p; do
    [[ $name == Filename || $name == /dev/zram* ]] && continue
    any=1; avail=$(awk '/MemAvailable/{print $2}' /proc/meminfo)
    if (( STATUS )); then say "  live: DIFFERS — disk swap active: $name (${used} KiB used)"; continue; fi
    if (( used < avail - SWAPOFF_MARGIN_KB )); then run swapoff "$name"
    else say "  $name: ${used} KiB used, only ${avail} KiB available — NOT swapping off now (fstab still fixed; reboot or re-run)"; fi
  done < /proc/swaps
  (( any )) || say "  live: ok — no disk-backed swap active"
  local n; n=$(awk '$1!~/^#/ && $3=="swap"' /etc/fstab | wc -l)
  if (( n == 0 )); then say "  fstab: ok — no active swap lines"
  elif (( STATUS )); then say "  fstab: DIFFERS — $n active swap line(s)"
  elif (( DRY )); then say "  would comment out in /etc/fstab (backup first):"; awk '$1!~/^#/ && $3=="swap"' /etc/fstab | sed 's/^/      | /'
  else
    install -d -m 700 /root/io-tuning-backup; [[ -e /root/io-tuning-backup/fstab.orig ]] || cp /etc/fstab /root/io-tuning-backup/fstab.orig
    cp /etc/fstab "/root/io-tuning-backup/fstab.$(date +%Y%m%d-%H%M%S)"
    awk '($1!~/^#/ && $3=="swap"){print "#disabled-by-io-tuning# " $0; next}{print}' /etc/fstab > /etc/fstab.indianadell.tmp && mv /etc/fstab.indianadell.tmp /etc/fstab
    say "  commented $n fstab swap line(s); backups in /root/io-tuning-backup/"; NEED_DAEMON_RELOAD=1
  fi
  if (( ZFS_LOADED )); then for z in $(zfs list -H -t volume -o name 2>/dev/null | grep -i swap); do say "  note: swap zvol $z left in place (reclaim with 'sudo zfs destroy $z' when happy)"; done; fi
}
BFQ_RULE='ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"'
step_bfq() {
  local rot; rot=$(rot_disks | tr '\n' ' ')
  for d in "${DISKS[@]}"; do set -- $d; say "  disk $1: rotational=$2 bus=$3 scheduler=$(sched_of "$1")$([[ $2 == 1 && $3 == usb ]] && echo '  (USB: left alone)')"; done
  if [[ -z $rot ]]; then say "  skip: no rotational disks (SSD/NVMe/eMMC keep their default scheduler)"; return; fi
  if (( STATUS )); then
    for d in $rot; do [[ $(sched_of "$d") == bfq ]] && say "  $d: ok" || say "  $d: DIFFERS (not bfq)"; done
    [[ "$(cat /etc/udev/rules.d/60-hdd-bfq.rules 2>/dev/null)" == "$BFQ_RULE" ]] && say "  udev rule: ok" || say "  udev rule: DIFFERS"
    [[ "$(cat /etc/modules-load.d/bfq.conf 2>/dev/null)" == bfq ]] && say "  modules-load: ok" || say "  modules-load: DIFFERS"; return; fi
  grep -qw bfq /sys/block/"${rot%% *}"/queue/scheduler || run modprobe bfq
  put_file /etc/modules-load.d/bfq.conf 0644 bfq
  put_file /etc/udev/rules.d/60-hdd-bfq.rules 0644 "$BFQ_RULE" && run udevadm control --reload
  for d in $rot; do
    [[ $(sched_of "$d") == bfq ]] && { say "  ok: $d already bfq"; continue; }
    if (( DRY )); then say "  would write bfq > /sys/block/$d/queue/scheduler"; else echo bfq > "/sys/block/$d/queue/scheduler" && say "  $d -> bfq"; fi
  done
}
step_initramfs() {
  if (( STATUS )); then say "  (no live state; runs only when the ARC cap file changes)"; return; fi
  if (( ! NEED_INITRAMFS )); then say "  ok: nothing changed that needs a new initramfs"; return; fi
  case $INITRAMFS_TOOL in update-initramfs) run update-initramfs -u ;; dracut) run dracut -f ;; *) say "  WARN: no initramfs tool found" ;; esac
}
step_ionice() {
  local found=0
  for n in $BG_PROCS; do for p in $(pgrep -x "$n"); do found=1
    if (( STATUS )); then say "  $n ($p): $(ionice -p "$p" 2>/dev/null)"; else run ionice -c3 -p "$p"; fi; done; done
  (( found )) || say "  ok: none of ($BG_PROCS) running"
}
step_fast_boot() {
  if [[ $ENABLE_FAST_BOOT != 1 ]]; then say "  skip: ENABLE_FAST_BOOT=$ENABLE_FAST_BOOT"; return; fi
  local args=(); (( STATUS || DRY )) && args=(--dry-run)
  if (( STATUS || DRY || IS_ROOT )); then "$ROOT/scripts/gnome/apply-fast-boot.sh" "${args[@]}" 2>&1 | sed 's/^/  /'
  fi
}
step_fast_login() {
  if [[ $ENABLE_FAST_LOGIN != 1 ]]; then say "  skip: GDM auto-login is opt-in (set ENABLE_FAST_LOGIN=1); login user would be '$LOGIN_USER', DM=$DM"; return; fi
  if [[ $DM != gdm* ]]; then say "  skip: display manager is '$DM', only GDM is supported"; return; fi
  say "  auto-login user=$LOGIN_USER (GRUB 0s menu, GDM AutomaticLogin, greeter face)"
  local g; g=$(sed -n 's/^\s*AutomaticLogin\s*=\s*//p' /etc/gdm3/custom.conf 2>/dev/null)
  if (( STATUS )); then [[ $g == "$LOGIN_USER" ]] && say "  gdm: ok" || say "  gdm: DIFFERS (AutomaticLogin='${g}')"; return; fi
  if (( DRY )) && [[ $g == "$LOGIN_USER" ]]; then say "  ok: GDM AutomaticLogin=$g already (re-running the script is idempotent)"; return; fi
  if (( DRY )); then say "  would run: $ROOT/scripts/gnome/apply-fast-login.sh --user $LOGIN_USER$( ((HAS_GRUB)) || echo ' --no-grub')"; return; fi
  local a=(--user "$LOGIN_USER"); (( HAS_GRUB )) || a+=(--no-grub)
  "$ROOT/scripts/gnome/apply-fast-login.sh" "${a[@]}"
}
step_chrome_cap() {
  if (( ! HAS_CHROME )); then say "  skip: Google Chrome not installed"; return; fi
  say "  want chrome.slice MemoryHigh=$CHROME_HIGH MemoryMax=$CHROME_MAX (rule: max=37.5% RAM => ${D_CHROME_MAX}G, high=max-1G)"
  local h; h=$(eval echo "~$LOGIN_USER")
  local f="$h/.config/systemd/user/chrome.slice"
  local okc=0; [[ -f $f ]] && grep -qx "MemoryHigh=$CHROME_HIGH" "$f" && grep -qx "MemoryMax=$CHROME_MAX" "$f" && okc=1
  if (( STATUS )); then
    if (( okc )); then say "  ok: $f"; else say "  DIFFERS: $f $(grep -E '^Memory(High|Max)=' "$f" 2>/dev/null | tr '\n' ' ')"; fi; return; fi
  if (( DRY && okc )); then say "  ok: slice already $CHROME_HIGH/$CHROME_MAX (re-run only after a Chrome update)"; return; fi
  if (( DRY )); then say "  would run (as $LOGIN_USER, no sudo): $ROOT/scripts/gnome/apply-chrome-cap.sh --high $CHROME_HIGH --max $CHROME_MAX"; return; fi
  "$ROOT/scripts/gnome/apply-chrome-cap.sh" --high "$CHROME_HIGH" --max "$CHROME_MAX"
}
step_max_performance() {
  if (( LAPTOP )) && [[ $FORCE_DESKTOP_POWER != 1 ]]; then say "  skip: laptop/battery detected (set FORCE_DESKTOP_POWER=1 to apply)"; return; fi
  if (( ! HAS_GSETTINGS )) || [[ $DESKTOP != *GNOME* ]]; then say "  skip: needs a GNOME session (desktop='${DESKTOP:-none}')"; return; fi
  if (( STATUS )); then
    say "  sleep-inactive-ac-type=$(gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 2>/dev/null) idle-delay=$(gsettings get org.gnome.desktop.session idle-delay 2>/dev/null) profile=$(powerprofilesctl get 2>/dev/null || echo n/a)"; return; fi
  if (( DRY )); then say "  would run (as user): $ROOT/scripts/gnome/apply-max-performance.sh  (no suspend/dim/lock, night light off, performance profile)"; return; fi
  "$ROOT/scripts/gnome/apply-max-performance.sh"
}

# ---------------------------------------------------------------- report
print_detect() {
  hdr "Detected ($HOST, $(date '+%F %T %Z'))"
  say "  model: $PRODUCT  chassis_type=$CHASSIS  laptop=$LAPTOP"
  say "  OS: $(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-?}")  kernel $(uname -r)"
  say "  RAM: ${MEM_GIB} GiB ($MEM_KB KiB)   CPU: $(nproc) threads, $(sed -n 's/^model name\s*: //p' /proc/cpuinfo | head -1)"
  say "  root fs: $ROOT_FS   zfs loaded: $ZFS_LOADED   initramfs: $INITRAMFS_TOOL   grub: $HAS_GRUB"
  say "  session: ${SESSION_TYPE:-?} desktop: ${DESKTOP:-?} display manager: $DM   NetworkManager: $HAS_NM   Chrome: $HAS_CHROME"
  say "  swaps:"; sed 1d /proc/swaps | awk '{printf "    %s %s size=%sKiB used=%sKiB prio=%s\n",$1,$2,$3,$4,$5}'
  [[ $(sed 1d /proc/swaps | wc -l) == 0 ]] && say "    (none)"
  say "  fstab swap lines: $(awk '$1!~/^#/ && $3=="swap"' /etc/fstab | wc -l)   foreign zram managers: ${ZRAM_FOREIGN:-none}"
  say "  config files: ${CFG_FILES[*]:-none (computed defaults only)}"
  say "  effective: ZRAM_SIZE=$ZRAM_SIZE ARC_MAX_GIB=$ARC_MAX_GIB SWAPPINESS=$SWAPPINESS PAGE_CLUSTER=$PAGE_CLUSTER CHROME=$CHROME_HIGH/$CHROME_MAX FAST_BOOT=$ENABLE_FAST_BOOT FAST_LOGIN=$ENABLE_FAST_LOGIN LOGIN_USER=$LOGIN_USER"
}
NEED_INITRAMFS=0; NEED_DAEMON_RELOAD=0
run_steps() {
  local s fn
  for s in "${ALL_STEPS[@]}"; do
    want_step "$s" || continue
    hdr "$s$(is_root_step "$s" && echo ' [root]' || echo ' [user]')"
    fn="step_${s//-/_}"
    if [[ $CMD == apply ]] && (( ! DRY )); then
      if is_root_step "$s" && (( ! IS_ROOT )); then say "  needs root — run with sudo: $SUDO_CMD --only $s"; continue; fi
      if ! is_root_step "$s" && (( IS_ROOT )); then say "  user step — run without sudo as $LOGIN_USER: $ROOT/bin/apply-tuning apply --only $s"; continue; fi
    fi
    "$fn"
  done
  if [[ $CMD == apply ]] && (( ! DRY )) && (( NEED_DAEMON_RELOAD )); then systemctl daemon-reload; fi
}

case "$CMD" in
  report)
    print_detect
    say; say "---- status (what is live now) ----"; STATUS=1; DRY=1; run_steps
    say; say "---- plan (what 'apply' would do; nothing changed) ----"; STATUS=0; DRY=1; run_steps
    say; say "Apply root steps:  $SUDO_CMD     User steps: $ROOT/bin/apply-tuning apply" ;;
  status) print_detect; STATUS=1; DRY=1; run_steps ;;
  apply)
    (( DRY )) && say "DRY RUN — nothing will be changed"
    print_detect; run_steps
    (( DRY )) || say $'\nFinished. Verify: bin/apply-tuning status' ;;
  revert)
    if (( DRY )); then say "would run: $ROOT/scripts/storage/revert-io-tuning.sh  (fast-boot undo: sudo bin/apply-fast-boot --undo; chrome: bin/apply-chrome-cap --revert)"; exit 0; fi
    (( IS_ROOT )) || { say "run with sudo: sudo $ROOT/bin/apply-tuning revert"; exit 1; }
    exec "$ROOT/scripts/storage/revert-io-tuning.sh" ;;
esac
