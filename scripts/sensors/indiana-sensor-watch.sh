#!/usr/bin/env bash
# Thermal / fan / disk watchdog for Tower5810.
#   indiana-sensor-watch            # daemon loop (root; systemd)
#   indiana-sensor-watch --once     # print table, no clock writes
#   indiana-sensor-watch --status   # same as --once
#   indiana-sensor-watch --restore  # put CPU/GPU clocks back (ExecStop)
#   indiana-sensor-watch --notify [test|restart|reload]
set -euo pipefail

TAG=indiana-sensor-watch
MODE=daemon
NOTIFY_KIND=""
CONF_SYS=/etc/indiana-sensor-watch.conf
RUNDIR=/run/indiana-sensor-watch
SNAP="$RUNDIR/cpu.orig"
RESTART_STAMP="$RUNDIR/restarting"
BOOT_DELAY_SEC=120
RESTART_WINDOW_SEC=90

# Defaults (conf overrides)
POLL_SEC=20
SMART_SEC=300
NOTIFY_SEC=300
STEP_SEC=40
RELEASE_HOLD_SEC=90
WARN_CPU=80
CRIT_CPU=90
CPU_RELEASE=72
CPU_FLOOR_KHZ=1600000
CPU_ABS_MIN_KHZ=1200000
CPU_STEP_KHZ=200000
WARN_GPU=80
CRIT_GPU=90
GPU_RELEASE=72
GPU_DISPLAY_MIN_IDX=2
GPU_HEADLESS_MIN_IDX=1
WARN_DIMM=70
CRIT_DIMM=85
WARN_SSD=60
CRIT_SSD=70
WARN_HDD=50
CRIT_HDD=60
WARN_CPU_FAN_RPM=400
IGNORE_FANS=fan2
RISE_20S=6
RISE_60S=10
KP=0.25
KI=0.02
THROTTLE=1
THROTTLE_CPU=1

NOW=0
FIRST=1
LAST_SMART=0
SMARTCTL=""

declare -A LAST_TEMP LAST_TS LAST_NOTIFY LAST_SEV LAST_STEP INTEGRAL COOL_OK
declare -A FAN_SEEN GPU_IS_DISPLAY GPU_KIND GPU_DEV GPU_FLOOR
declare -A DISK_TEMP DISK_KIND DISK_SKIP

log() {
  local pri=${2:-daemon.info}
  logger -t "$TAG" -p "$pri" -- "$1" || true
  printf '%s %s\n' "$(date '+%H:%M:%S')" "$1" >&2
}

load_conf() {
  local f
  for f in "$CONF_SYS" \
           "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/etc/indiana-sensor-watch.conf"; do
    [[ -r "$f" ]] || continue
    # shellcheck disable=SC1090
    source "$f"
    break
  done
}

say() {
  # Table output for --once/--status only (daemon stays quiet except alerts).
  [[ "$MODE" == once ]] || return 0
  printf '%s\n' "$*"
}

milli_c() {
  local v=$1
  if [[ "$v" -gt 1000 ]]; then
    echo $((v / 1000))
  else
    echo "$v"
  fi
}

sys_write() {
  local path=$1 val=$2
  [[ -w "$path" ]] || { log "WARN cannot write $path" daemon.warning; return 1; }
  printf '%s\n' "$val" >"$path"
}

find_smartctl() {
  if [[ -x /usr/sbin/smartctl ]]; then
    SMARTCTL=/usr/sbin/smartctl
  elif command -v smartctl >/dev/null 2>&1; then
    SMARTCTL=$(command -v smartctl)
  fi
}

# ---------------------------------------------------------------------------
# Notify graphical sessions from root
# ---------------------------------------------------------------------------

notify_one() {
  local uid=$1 user=$2 urgency=$3 title=$4 body=$5
  [[ -n "$user" ]] || user=$(getent passwd "$uid" | cut -d: -f1)
  [[ -n "$user" ]] || return 1
  if systemd-run --quiet --pipe --wait --collect \
       --machine="${user}@.host" --user -- \
       /usr/bin/notify-send -u "$urgency" -a "$TAG" -- "$title" "$body" 2>/dev/null; then
    return 0
  fi
  local bus=/run/user/${uid}/bus
  [[ -S "$bus" ]] || return 1
  sudo -u "#${uid}" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=${bus}" \
    XDG_RUNTIME_DIR="/run/user/${uid}" \
    DISPLAY="${DISPLAY:-:0}" \
    WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}" \
    /usr/bin/notify-send -u "$urgency" -a "$TAG" -- "$title" "$body" 2>/dev/null
}

notify_users() {
  local urgency=$1 title=$2 body=$3
  local sent=0 sid uid user typ seat active
  command -v notify-send >/dev/null 2>&1 || {
    log "WARN notify-send not installed" daemon.warning
    return 1
  }
  if command -v loginctl >/dev/null 2>&1; then
    while read -r sid _; do
      [[ -n "${sid:-}" ]] || continue
      uid=$(loginctl show-session "$sid" -p User --value 2>/dev/null || true)
      user=$(loginctl show-session "$sid" -p Name --value 2>/dev/null || true)
      typ=$(loginctl show-session "$sid" -p Type --value 2>/dev/null || true)
      seat=$(loginctl show-session "$sid" -p Seat --value 2>/dev/null || true)
      active=$(loginctl show-session "$sid" -p Active --value 2>/dev/null || true)
      [[ "$active" == yes ]] || continue
      [[ "$typ" == wayland || "$typ" == x11 || "$typ" == tty || "$seat" == seat0 ]] || continue
      [[ -n "$uid" ]] || continue
      if notify_one "$uid" "$user" "$urgency" "$title" "$body"; then
        sent=$((sent + 1))
      fi
    done < <(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $1}')
  fi
  # Fallback: any live session bus under /run/user
  if [[ $sent -eq 0 ]]; then
    local bus
    for bus in /run/user/*/bus; do
      [[ -S "$bus" ]] || continue
      uid=$(echo "$bus" | awk -F/ '{print $4}')
      [[ "$uid" =~ ^[0-9]+$ ]] || continue
      (( uid >= 1000 )) || continue
      user=$(getent passwd "$uid" | cut -d: -f1)
      if notify_one "$uid" "$user" "$urgency" "$title" "$body"; then
        sent=$((sent + 1))
      fi
    done
  fi
  if [[ $sent -eq 0 ]]; then
    log "WARN desktop notify failed (no session bus)" daemon.warning
    return 1
  fi
  log "desktop notify sent to $sent session(s): $title"
  return 0
}

service_notice() {
  local kind=${1:-test}
  local title body
  case "$kind" in
    restart)
      title="Sensor watchdog restarted"
      body="Thermal/fan watch is running again. You will get another notice if a sensor is out of range."
      ;;
    reload)
      title="Sensor watchdog reloaded"
      body="Config re-read. Still watching temperatures and fans."
      ;;
    test)
      title="Sensor watchdog test"
      body="If you can read this, desktop alerts from the watchdog service are working."
      ;;
    *)
      title="Sensor watchdog"
      body="Watchdog notice ($kind)."
      ;;
  esac
  notify_users normal "$title" "$body"
}

mark_restarting() {
  mkdir -p "$RUNDIR"
  date +%s >"$RESTART_STAMP"
}

maybe_notice_restart() {
  [[ -f "$RESTART_STAMP" ]] || return 1
  local ts age
  ts=$(cat "$RESTART_STAMP" 2>/dev/null || echo 0)
  rm -f "$RESTART_STAMP"
  [[ "$ts" =~ ^[0-9]+$ ]] || return 1
  age=$((NOW - ts))
  (( age >= 0 && age < RESTART_WINDOW_SEC )) || return 1
  service_notice restart
  return 0
}

# key sev title body   sev: info|warn|crit
alert() {
  local key=$1 sev=$2 title=$3 body=$4
  local pri=daemon.warning urg=normal
  [[ "$sev" == crit ]] && { pri=daemon.crit; urg=critical; }
  [[ "$sev" == info ]] && pri=daemon.info
  log "$title — $body" "$pri"

  local last=${LAST_NOTIFY[$key]:-0}
  local lastsev=${LAST_SEV[$key]:-none}
  local escalate=0
  [[ "$sev" == crit && "$lastsev" != crit ]] && escalate=1
  if (( NOW - last < NOTIFY_SEC )) && [[ $escalate -eq 0 ]]; then
    return 0
  fi
  LAST_NOTIFY[$key]=$NOW
  LAST_SEV[$key]=$sev
  [[ "$sev" == info ]] && urg=low
  notify_users "$urg" "$title" "$body"
}

track_temp() {
  local key=$1 temp=$2
  local prev=${LAST_TEMP[$key]:-}
  local pts=${LAST_TS[$key]:-0}
  LAST_TEMP[$key]=$temp
  LAST_TS[$key]=$NOW
  [[ -n "$prev" ]] || return 0
  local dt=$((NOW - pts))
  [[ $dt -gt 0 ]] || return 0
  local d=$((temp - prev))
  if (( dt <= 25 && d >= RISE_20S )); then
    alert "rise:$key" warn "Temperature rising fast" \
      "$key rose ${d} C in ${dt}s, now ${temp} C"
  fi
  if (( dt <= 70 && d >= RISE_60S )); then
    alert "rise60:$key" warn "Temperature rising fast" \
      "$key rose ${d} C in ${dt}s, now ${temp} C"
  fi
}

pi_u() {
  local key=$1 temp=$2 target=$3 dt=$4
  local err
  err=$(awk -v t="$temp" -v g="$target" 'BEGIN { printf "%.3f", t-g }')
  local integ=${INTEGRAL[$key]:-0}
  integ=$(awk -v i="$integ" -v e="$err" -v dt="$dt" -v ki="$KI" \
    'BEGIN { n=i+e*dt; lim=2.0/ki; if (lim<20) lim=80; if (n>lim) n=lim; if (n<-lim) n=-lim; printf "%.3f", n }')
  INTEGRAL[$key]=$integ
  awk -v e="$err" -v i="$integ" -v kp="$KP" -v ki="$KI" \
    'BEGIN { printf "%.3f", kp*e + ki*i }'
}

can_step() {
  local key=$1 extra=${2:-0}
  local last=${LAST_STEP[$key]:-0}
  if [[ $extra -eq 1 ]]; then
    (( NOW - last >= POLL_SEC )) && return 0
    return 1
  fi
  (( NOW - last >= STEP_SEC ))
}

mark_step() { LAST_STEP[$1]=$NOW; }

# ---------------------------------------------------------------------------
# CPU
# ---------------------------------------------------------------------------

cpu_snapshot() {
  mkdir -p "$RUNDIR"
  if [[ ! -f "$SNAP" ]]; then
    {
      echo "no_turbo=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || echo 0)"
      echo "max_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null || echo 3500000)"
    } >"$SNAP"
  fi
}

cpu_restore() {
  [[ -r "$SNAP" ]] || return 0
  local no_turbo=0 max_freq=3500000
  # shellcheck disable=SC1090
  source "$SNAP"
  if [[ -w /sys/devices/system/cpu/intel_pstate/no_turbo ]]; then
    sys_write /sys/devices/system/cpu/intel_pstate/no_turbo "$no_turbo" || true
  fi
  local c
  for c in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_max_freq; do
    [[ -w "$c" ]] || continue
    sys_write "$c" "$max_freq" || true
  done
  log "CPU clocks restored (no_turbo=$no_turbo max=${max_freq}kHz)"
}

cpu_apply_step() {
  local step=$1
  # 0 = turbo on + original max; 1 = no_turbo; 2+ = drop 200 MHz from 3000
  local orig_max=3500000 orig_turbo=0
  if [[ -r "$SNAP" ]]; then
    local no_turbo max_freq
    # shellcheck disable=SC1090
    source "$SNAP"
    orig_max=${max_freq:-3500000}
    orig_turbo=${no_turbo:-0}
  fi
  local khz turbo
  if [[ "$step" -le 0 ]]; then
    turbo=$orig_turbo
    khz=$orig_max
  elif [[ "$step" -eq 1 ]]; then
    turbo=1
    khz=3000000
    (( khz > orig_max )) && khz=$orig_max
  else
    turbo=1
    khz=$((3000000 - (step - 1) * CPU_STEP_KHZ))
    local floor=$CPU_FLOOR_KHZ
    # Allow below desktop floor only if we were already at floor and still critical
    if [[ "$step" -ge 9 ]]; then
      floor=$CPU_ABS_MIN_KHZ
    fi
    (( khz < floor )) && khz=$floor
  fi
  if [[ -w /sys/devices/system/cpu/intel_pstate/no_turbo ]]; then
    sys_write /sys/devices/system/cpu/intel_pstate/no_turbo "$turbo" || true
  fi
  local c
  for c in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_max_freq; do
    [[ -w "$c" ]] || continue
    sys_write "$c" "$khz" || true
  done
  echo "$step" >"$RUNDIR/cpu.step"
  log "CPU throttle step=$step no_turbo=$turbo max=${khz}kHz" daemon.warning
}

cpu_current_step() {
  if [[ -r "$RUNDIR/cpu.step" ]]; then
    cat "$RUNDIR/cpu.step"
    return
  fi
  echo 0
}

sample_cpu() {
  local pkg="" coremax=0 t label
  for t in /sys/class/hwmon/hwmon*/temp*_input; do
    [[ -f "$t" ]] || continue
    local name
    name=$(cat "$(dirname "$t")/name" 2>/dev/null || true)
    [[ "$name" == coretemp ]] || continue
    label=$(cat "${t%_input}_label" 2>/dev/null || echo temp)
    local c
    c=$(milli_c "$(cat "$t")")
    if [[ "$label" == "Package id 0" ]]; then
      pkg=$c
    elif [[ "$label" == Core* ]]; then
      (( c > coremax )) && coremax=$c
    fi
  done
  [[ -n "$pkg" ]] || return 0
  local hottest=$pkg
  (( coremax > hottest )) && hottest=$coremax
  say "CPU package=${pkg}C hottest_core=${coremax}C"
  track_temp cpu "$hottest"
  local sev=""
  if (( hottest >= CRIT_CPU )); then sev=crit
  elif (( hottest >= WARN_CPU )); then sev=warn
  fi
  if [[ -n "$sev" ]]; then
    alert cpu "$sev" "CPU temperature $sev" \
      "Package ${pkg} C, hottest core ${coremax} C"
  fi

  [[ "$MODE" == daemon && "$THROTTLE_CPU" == 1 && "$(id -u)" -eq 0 ]] || return 0

  cpu_snapshot
  local step
  step=$(cpu_current_step)
  local dt=$POLL_SEC
  local u
  u=$(pi_u cpu "$hottest" "$WARN_CPU" "$dt")
  local extra=0
  local prev=${LAST_TEMP[cpu]:-$hottest}
  # LAST_TEMP already updated; use rise from this tick via track — extra if hot and rising
  if (( hottest >= WARN_CPU - 2 )); then
    extra=0
  fi

  if (( hottest >= WARN_CPU )); then
    COOL_OK[cpu]=0
    if can_step cpu "$extra"; then
      if awk -v u="$u" 'BEGIN { exit !(u >= 0.4) }' || (( hottest >= WARN_CPU )); then
        if (( hottest >= CRIT_CPU && step >= 8 )); then
          cpu_apply_step $((step + 1))
        elif (( step < 8 || hottest >= CRIT_CPU )); then
          cpu_apply_step $((step + 1))
        fi
        mark_step cpu
        if [[ "$step" -eq 0 ]]; then
          alert cpu-throt warn "CPU clocks reduced" \
            "Package ${pkg} C — disabling turbo / lowering max frequency"
        fi
      fi
    fi
  elif (( hottest <= CPU_RELEASE )); then
    COOL_OK[cpu]=$(( ${COOL_OK[cpu]:-0} + POLL_SEC ))
    if [[ "$step" -gt 0 ]] && can_step cpu; then
      if awk -v u="$u" 'BEGIN { exit !(u <= -0.3) }' || (( ${COOL_OK[cpu]} >= STEP_SEC )); then
        local ns=$((step - 1))
        (( ns < 0 )) && ns=0
        if [[ "$ns" -eq 0 && ${COOL_OK[cpu]} -ge $RELEASE_HOLD_SEC ]]; then
          cpu_restore
          echo 0 >"$RUNDIR/cpu.step"
          INTEGRAL[cpu]=0
          alert cpu-throt info "CPU clocks restored" \
            "Package ${pkg} C — full frequency restored"
        elif [[ "$ns" -gt 0 ]]; then
          cpu_apply_step "$ns"
        fi
        mark_step cpu
      fi
    fi
  else
    COOL_OK[cpu]=0
  fi
}

# ---------------------------------------------------------------------------
# DIMM + fans (dell_smm)
# ---------------------------------------------------------------------------

sample_smm() {
  local h t f label c rpm
  for h in /sys/class/hwmon/hwmon*; do
    [[ "$(cat "$h/name" 2>/dev/null || true)" == dell_smm ]] || continue
    local i=0
    for t in "$h"/temp*_input; do
      [[ -f "$t" ]] || continue
      label=$(cat "${t%_input}_label" 2>/dev/null || echo temp)
      c=$(milli_c "$(cat "$t")")
      if [[ "$label" == SODIMM* || "$label" == SODIMM ]]; then
        i=$((i + 1))
        local key="dimm$i"
        say "DIMM ${key}=${c}C"
        track_temp "$key" "$c"
        if (( c >= CRIT_DIMM )); then
          alert "$key" crit "DIMM temperature critical" "$key is ${c} C"
        elif (( c >= WARN_DIMM )); then
          alert "$key" warn "DIMM temperature high" "$key is ${c} C"
        fi
      fi
    done
    for f in "$h"/fan*_input; do
      [[ -f "$f" ]] || continue
      local base
      base=$(basename "$f")
      base=${base%_input}
      label=$(cat "${f%_input}_label" 2>/dev/null || echo "$base")
      rpm=$(cat "$f" 2>/dev/null || echo 0)
      say "FAN ${base} (${label})=${rpm} RPM"
      case ",$IGNORE_FANS," in
        *",$base,"*) continue ;;
      esac
      if (( rpm > 200 )); then
        FAN_SEEN[$base]=1
      fi
      if [[ "$label" == "Processor Fan" || "$base" == fan1 ]]; then
        if (( rpm == 0 )); then
          alert fan-cpu crit "CPU fan stopped" "Processor Fan reads 0 RPM"
        elif (( rpm < WARN_CPU_FAN_RPM )); then
          alert fan-cpu warn "CPU fan slow" "Processor Fan is ${rpm} RPM"
        fi
      elif [[ "${FAN_SEEN[$base]:-0}" == 1 && "$rpm" -eq 0 ]]; then
        alert "fan-$base" crit "Chassis fan stopped" "$label ($base) dropped to 0 RPM"
      fi
    done
  done
}

# ---------------------------------------------------------------------------
# GPUs
# ---------------------------------------------------------------------------

discover_gpus() {
  local card dev pci did name conn
  GPU_KIND=()
  GPU_DEV=()
  GPU_IS_DISPLAY=()
  GPU_FLOOR=()
  for card in /sys/class/drm/card[0-9]; do
    [[ -f "$card/device/vendor" ]] || continue
    [[ "$(cat "$card/device/vendor")" == 0x1002 ]] || continue
    dev=$card/device
    pci=$(grep PCI_SLOT_NAME "$dev/uevent" | cut -d= -f2)
    did=$(cat "$dev/device")
    case "$did" in
      0x6809) name=W5000 ;;
      0x6649) name=W5100 ;;
      *) name=AMD ;;
    esac
    local id
    id=$(basename "$card")
    GPU_KIND[$id]=$name
    GPU_DEV[$id]=$dev
    GPU_IS_DISPLAY[$id]=0
    GPU_FLOOR[$id]=$GPU_HEADLESS_MIN_IDX
    for conn in "$card"-*/status; do
      [[ -f "$conn" ]] || continue
      if [[ "$(cat "$conn")" == connected ]]; then
        GPU_IS_DISPLAY[$id]=1
        GPU_FLOOR[$id]=$GPU_DISPLAY_MIN_IDX
      fi
    done
    say "GPU $id $name $pci display=${GPU_IS_DISPLAY[$id]}"
  done
}

gpu_temp() {
  local dev=$1 t
  for t in "$dev"/hwmon/hwmon*/temp1_input; do
    [[ -f "$t" ]] || continue
    milli_c "$(cat "$t")"
    return 0
  done
  echo ""
}

gpu_sclk_index() {
  local dev=$1
  [[ -r "$dev/pp_dpm_sclk" ]] || { echo ""; return; }
  awk '/\*/ { print $1+0; exit }' "$dev/pp_dpm_sclk"
}

gpu_sclk_max() {
  local dev=$1
  [[ -r "$dev/pp_dpm_sclk" ]] || { echo ""; return; }
  awk 'NF { n=$1+0 } END { print n }' "$dev/pp_dpm_sclk"
}

gpu_apply_w5100() {
  local dev=$1 idx=$2
  sys_write "$dev/power_dpm_force_performance_level" manual || return 1
  sys_write "$dev/pp_dpm_sclk" "$idx" || return 1
}

gpu_release() {
  local dev=$1
  sys_write "$dev/power_dpm_force_performance_level" auto || true
}

gpu_w5000_level() {
  cat "$1/power_dpm_force_performance_level" 2>/dev/null || echo auto
}

sample_gpus() {
  local id dev name temp role
  for id in "${!GPU_DEV[@]}"; do
    dev=${GPU_DEV[$id]}
    name=${GPU_KIND[$id]}
    if [[ ${GPU_IS_DISPLAY[$id]} -eq 1 ]]; then role=display; else role=headless; fi
    temp=$(gpu_temp "$dev")
    [[ -n "$temp" ]] || continue
    local dpm
    dpm=$(cat "$dev/power_dpm_force_performance_level" 2>/dev/null || echo '?')
    say "GPU $id $name $role ${temp}C dpm=$dpm"
    track_temp "gpu:$id" "$temp"
    local sev=""
    if (( temp >= CRIT_GPU )); then sev=crit
    elif (( temp >= WARN_GPU )); then sev=warn
    fi
    if [[ -n "$sev" ]]; then
      alert "gpu:$id" "$sev" "GPU temperature $sev" \
        "$name $id ($role) is ${temp} C"
    fi

    [[ "$MODE" == daemon && "$THROTTLE" == 1 && "$(id -u)" -eq 0 ]] || continue

    local key="gpu:$id"
    local dt=$POLL_SEC
    local u
    u=$(pi_u "$key" "$temp" "$WARN_GPU" "$dt")
    local extra=0
    if (( temp >= WARN_GPU - 2 )); then extra=0; fi

    if [[ "$name" == W5100 && -r "$dev/pp_dpm_sclk" ]]; then
      local cur max floor
      cur=$(gpu_sclk_index "$dev")
      max=$(gpu_sclk_max "$dev")
      floor=${GPU_FLOOR[$id]}
      [[ -n "$cur" ]] || cur=$max
      if (( temp >= WARN_GPU )); then
        COOL_OK[$key]=0
        if can_step "$key" "$extra"; then
          local nxt=$((cur - 1))
          (( nxt < floor )) && nxt=$floor
          if [[ "$nxt" -lt "$cur" ]]; then
            gpu_apply_w5100 "$dev" "$nxt" || true
            mark_step "$key"
            log "GPU $id step sclk $cur -> $nxt at ${temp}C" daemon.warning
            if [[ "$dpm" == auto ]]; then
              alert "gpu-throt:$id" warn "GPU clocks reduced" \
                "$name $id ${temp} C — stepping sclk down"
            fi
          fi
        fi
      elif (( temp <= GPU_RELEASE )); then
        COOL_OK[$key]=$(( ${COOL_OK[$key]:-0} + POLL_SEC ))
        if can_step "$key"; then
          if [[ "$dpm" != auto && ${COOL_OK[$key]} -ge $RELEASE_HOLD_SEC && "$cur" -ge "$max" ]]; then
            gpu_release "$dev"
            INTEGRAL[$key]=0
            mark_step "$key"
            alert "gpu-throt:$id" info "GPU clocks restored" \
              "$name $id cooled to ${temp} C — DPM auto"
          elif [[ "$dpm" != auto && "$cur" -lt "$max" ]]; then
            gpu_apply_w5100 "$dev" $((cur + 1)) || true
            mark_step "$key"
            log "GPU $id step sclk $cur -> $((cur + 1)) at ${temp}C"
          elif [[ "$dpm" != auto && "$cur" -ge "$max" && ${COOL_OK[$key]} -ge $RELEASE_HOLD_SEC ]]; then
            gpu_release "$dev"
            INTEGRAL[$key]=0
            mark_step "$key"
            alert "gpu-throt:$id" info "GPU clocks restored" \
              "$name $id cooled to ${temp} C — DPM auto"
          fi
        fi
      else
        COOL_OK[$key]=0
      fi
    else
      # W5000: auto <-> low only
      local lvl
      lvl=$(gpu_w5000_level "$dev")
      if (( temp >= WARN_GPU )); then
        COOL_OK[$key]=0
        if [[ "$lvl" != low ]] && can_step "$key"; then
          sys_write "$dev/power_dpm_force_performance_level" low || true
          mark_step "$key"
          log "GPU $id W5000 auto -> low at ${temp}C" daemon.warning
          alert "gpu-throt:$id" warn "GPU clocks reduced" \
            "$name $id ${temp} C — DPM low"
        fi
      elif (( temp <= GPU_RELEASE )); then
        COOL_OK[$key]=$(( ${COOL_OK[$key]:-0} + POLL_SEC ))
        if [[ "$lvl" == low && ${COOL_OK[$key]} -ge $RELEASE_HOLD_SEC ]] && can_step "$key"; then
          gpu_release "$dev"
          INTEGRAL[$key]=0
          mark_step "$key"
          alert "gpu-throt:$id" info "GPU clocks restored" \
            "$name $id cooled to ${temp} C — DPM auto"
        fi
      else
        COOL_OK[$key]=0
      fi
    fi
  done
}

# ---------------------------------------------------------------------------
# Disks (SMART)
# ---------------------------------------------------------------------------

is_usb_block() {
  local d=$1
  readlink -f "/sys/block/${d}/device" 2>/dev/null | grep -q /usb
}

smart_raw() {
  local dev=$1
  local out rc=0
  if is_usb_block "$(basename "$dev")"; then
    local typ
    for typ in sat scsi usb ''; do
      if [[ -n "$typ" ]]; then
        out=$("$SMARTCTL" -n standby,0 -d "$typ" -A "$dev" 2>/dev/null) && break
      else
        out=$("$SMARTCTL" -n standby,0 -A "$dev" 2>/dev/null) && break
      fi
    done
  else
    out=$("$SMARTCTL" -n standby,0 -A "$dev" 2>/dev/null) || rc=$?
  fi
  # smartctl 2 = standby
  if [[ $rc -eq 2 ]] || grep -qi 'Device is in STANDBY' <<<"${out:-}"; then
    echo STANDBY
    return 0
  fi
  if [[ $rc -ne 0 && -z "${out:-}" ]]; then
    echo DENIED
    return 0
  fi
  printf '%s\n' "${out:-}"
}

parse_smart_temp() {
  local text=$1
  echo "$text" | awk '
    $1 == 194 { print $10; exit }
    /Temperature_Celsius/ { print $10; exit }
    /Current Drive Temperature/ { print $4; exit }
    /Airflow_Temperature_Cel/ { print $10; exit }
    /Temperature:/ { gsub(/[^0-9]/,"",$2); if ($2+0>0) { print $2; exit } }
  '
}

sample_disks() {
  [[ -n "$SMARTCTL" ]] || { say 'DISK smartctl not installed'; return 0; }
  if (( NOW - LAST_SMART < SMART_SEC )) && [[ "$MODE" == daemon ]]; then
    return 0
  fi
  LAST_SMART=$NOW
  local b rot model temp raw
  for b in /sys/block/sd*; do
    [[ -e "$b" ]] || continue
    local name
    name=$(basename "$b")
    model=$(cat "$b/device/model" 2>/dev/null | sed 's/[[:space:]]\+$//')
    rot=$(cat "$b/queue/rotational" 2>/dev/null || echo 1)
    raw=$(smart_raw "/dev/$name")
    if [[ "$raw" == STANDBY ]]; then
      say "DISK /dev/$name $model standby (not woken)"
      continue
    fi
    if [[ "$raw" == DENIED ]]; then
      say "DISK /dev/$name $model need-root for SMART"
      continue
    fi
    temp=$(parse_smart_temp "$raw")
    [[ -n "$temp" && "$temp" != "-" ]] || {
      say "DISK /dev/$name $model temp=n/a"
      continue
    }
    # drop junk
    temp=${temp%%.*}
    [[ "$temp" =~ ^[0-9]+$ ]] || continue
    local kind=hdd warn=$WARN_HDD crit=$CRIT_HDD
    if [[ "$rot" == 0 ]]; then
      kind=ssd; warn=$WARN_SSD; crit=$CRIT_SSD
    fi
    say "DISK /dev/$name $model $kind ${temp}C"
    track_temp "disk:$name" "$temp"
    if (( temp >= crit )); then
      alert "disk:$name" crit "Disk temperature critical" \
        "/dev/$name ($model) is ${temp} C"
    elif (( temp >= warn )); then
      alert "disk:$name" warn "Disk temperature high" \
        "/dev/$name ($model) is ${temp} C"
    fi
  done
}

# ---------------------------------------------------------------------------
# Modes
# ---------------------------------------------------------------------------

restore_all() {
  mark_restarting
  cpu_restore
  local id
  discover_gpus >/dev/null || true
  for id in "${!GPU_DEV[@]}"; do
    gpu_release "${GPU_DEV[$id]}"
  done
  log "restore complete"
}

print_once() {
  echo "=== $TAG $(date) ==="
  discover_gpus
  sample_cpu || true
  sample_smm || true
  sample_gpus || true
  find_smartctl
  NOW=$(date +%s)
  LAST_SMART=0
  sample_disks || true
}

on_hup() {
  load_conf
  NOW=$(date +%s)
  log "SIGHUP — reloaded config"
  service_notice reload || true
}

loop() {
  mkdir -p "$RUNDIR"
  find_smartctl
  [[ "$(id -u)" -eq 0 ]] || log "WARN not root — throttle writes disabled" daemon.warning
  if [[ "$(id -u)" -eq 0 ]]; then
    cpu_snapshot
    trap 'restore_all; exit 0' INT TERM
    trap 'on_hup' HUP
  fi
  discover_gpus >/dev/null || true
  if maybe_notice_restart; then
    log "restart (skipped boot delay)"
  else
    log "cold start — waiting ${BOOT_DELAY_SEC}s before first sample"
    sleep "$BOOT_DELAY_SEC"
  fi
  log "started poll=${POLL_SEC}s smart=${SMART_SEC}s throttle=$THROTTLE cpu=$THROTTLE_CPU"
  while true; do
    NOW=$(date +%s)
    discover_gpus >/dev/null || true
    sample_cpu || true
    sample_smm || true
    sample_gpus || true
    sample_disks || true
    FIRST=0
    # sleep in the background so SIGHUP (systemctl reload) runs the trap now
    sleep "$POLL_SEC" &
    wait $! || true
  done
}

usage() {
  sed -n '2,7p' "$0"
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --once|--status) MODE=once; shift ;;
    --restore) MODE=restore; shift ;;
    --notify)
      MODE=notify
      NOTIFY_KIND=${2:-test}
      if [[ $# -ge 2 && "$2" != -* ]]; then
        NOTIFY_KIND=$2
        shift 2
      else
        shift
      fi
      ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

load_conf
NOW=$(date +%s)

case "$MODE" in
  once) print_once ;;
  restore) restore_all ;;
  notify) service_notice "$NOTIFY_KIND" ;;
  daemon) loop ;;
esac
