#!/usr/bin/env bash
# Configure Tower5810 Samba for ZFS sharesmb of /home (not /root).
# Usage: sudo bin/apply-zfs-smb
#
# Does not set the SMB password. After this: sudo smbpasswd -a user
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONF_SRC="$ROOT/etc/samba/indianadell.conf"
CONF_DST="/etc/samba/indianadell.conf"
SMB_CONF="/etc/samba/smb.conf"
INCLUDE_LINE="include = /etc/samba/indianadell.conf"
HOME_DS="rpool/USERDATA/home_ulmkkv"
USERDATA_DS="rpool/USERDATA"
ROOT_DS="rpool/USERDATA/root_ulmkkv"
SMB_USER="user"

log() { printf '[apply-zfs-smb] %s\n' "$*"; }
die() { printf '[apply-zfs-smb] ERROR: %s\n' "$*" >&2; exit 1; }

[[ "$(id -u)" -eq 0 ]] || die "run as root (sudo bin/apply-zfs-smb)"
[[ -f "$CONF_SRC" ]] || die "missing $CONF_SRC"
command -v zfs >/dev/null || die "zfs not found"

if ! dpkg-query -W -f='${Status}' samba 2>/dev/null | grep -q 'install ok installed'; then
  log "installing samba + smbclient"
  DEBIAN_FRONTEND=noninteractive apt-get install -y samba smbclient
fi
if ! dpkg-query -W -f='${Status}' smbclient 2>/dev/null | grep -q 'install ok installed'; then
  DEBIAN_FRONTEND=noninteractive apt-get install -y smbclient
fi

command -v smbd >/dev/null || die "smbd missing after samba install"
command -v net >/dev/null || die "net(8) missing after samba install (need samba-common-bin)"
command -v testparm >/dev/null || die "testparm missing"

install -d -m 0755 /etc/samba
install -m 0644 "$CONF_SRC" "$CONF_DST"

[[ -f "$SMB_CONF" ]] || die "missing $SMB_CONF"

# Include MUST sit in [global]. Appending after [print$] makes Samba treat it as
# a print-share parameter; `net usershare` then still sees max shares = 0.
python3 - "$SMB_CONF" "$INCLUDE_LINE" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
include_line = sys.argv[2]
marker = "# IndianaDell ZFS /home SMB — managed by apply-zfs-smb"
assign_re = re.compile(r"^\s*;?\s*usershare max shares\s*=")

lines = path.read_text().splitlines(keepends=True)
kept = [ln for ln in lines if marker not in ln and ln.strip() != include_line]

out = []
in_global = False
saw_max = False
for ln in kept:
    stripped = ln.strip()
    if stripped.startswith("[") and stripped.endswith("]"):
        in_global = stripped == "[global]"
    if in_global and assign_re.match(ln):
        if not saw_max:
            out.append("   usershare max shares = 100\n")
            saw_max = True
        continue
    out.append(ln)
kept = out

block_lines = []
if not saw_max:
    block_lines.append("   usershare max shares = 100\n")
block_lines.append(f"\n{marker}\n{include_line}\n")
block = "".join(block_lines)

inserted = False
out = []
for ln in kept:
    if (not inserted) and ln.startswith("#======================= Share Definitions"):
        out.append(block)
        inserted = True
    out.append(ln)
if not inserted:
    out.append(block)
path.write_text("".join(out))
PY
log "installed $CONF_DST and [global] include in $SMB_CONF"

if ! id -u "$SMB_USER" >/dev/null 2>&1; then
  die "unix user $SMB_USER does not exist"
fi
if getent group sambashare >/dev/null; then
  usermod -aG sambashare "$SMB_USER"
  log "added $SMB_USER to sambashare"
fi

# Property only; do not call into Samba until smbd is up.
zfs set -u sharesmb=off "$USERDATA_DS"
zfs set -u sharesmb=off "$ROOT_DS"
zfs set -u sharesmb=on "$HOME_DS"
log "sharesmb: $USERDATA_DS=off $ROOT_DS=off $HOME_DS=on"

testparm -s >/dev/null || die "testparm rejected smb.conf"

# Recreate the ZFS usershare after smb.conf changes (template share is
# applied when smbd loads the usershare file).
zfs unshare -a smb 2>/dev/null || true

systemctl enable smbd.service
systemctl restart smbd.service
systemctl is-active --quiet smbd.service || die "smbd failed to start"

# Readiness: smbd is Type=notify; is-active means it is listening.
if ! ss -lnt | grep -q ':445'; then
  die "smbd is active but nothing is listening on TCP 445"
fi

if ! zfs share -a smb; then
  die "zfs share -a smb failed (net usershare). Check /var/lib/samba/usershares and smbd logs"
fi

log "usershares:"
net usershare list || true
log "sharesmb:"
zfs get -o name,value,source -r sharesmb "$USERDATA_DS"
log "listening:"
ss -lnt | grep -E ':445|:139' || true

if pdbedit -L -v "$SMB_USER" >/dev/null 2>&1; then
  log "SMB account $SMB_USER already exists in tdbsam"
else
  log "SMB account $SMB_USER is not in tdbsam yet — run: sudo smbpasswd -a $SMB_USER"
fi

log "done. Client: \\\\10.0.0.113\\home  (or the ZFS usershare name)"
