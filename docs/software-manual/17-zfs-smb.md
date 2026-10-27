# Chapter 17 — ZFS SMB share (`/home`)

On Linux, OpenZFS `sharesmb` is **not** a kernel SMB server. It registers a Samba **usershare** (`net usershare`) and expects **`smbd`** to listen on TCP 445. Tower5810 shares the existing dataset `rpool/USERDATA/home_ulmkkv` (`mountpoint=/home`), which contains both `user` and `ubuntu`. `/root` is not shared.

## What gets installed

| Piece | Role |
|-------|------|
| apt `samba` | `smbd` + `net` (required for `zfs share` SMB) |
| apt `smbclient` | local smoke tests |
| `etc/samba/indianadell.conf` | LAN bind, no guest, `[home]` alias |
| `sharesmb=on` | only `rpool/USERDATA/home_ulmkkv` |
| `sharesmb=off` | `rpool/USERDATA` (no inherit) and `rpool/USERDATA/root_ulmkkv` |

Clients: `\\10.0.0.113\home`, `\\10.0.0.113\Documents` (`/home/user/Documents`), and the ZFS usershare `rpool_USERDATA_home_ulmkkv`.

**iPad / iOS Files:** needs `vfs objects = catia fruit streams_xattr`. Without fruit, Files.app lists the tree and opens directories `RDONLY` (see `smbstatus`) so writes to `user/Documents` fail even though `[home]` is `read only = no`.

**Do not** set `usershare template share = home`. Samba 4.23.6 `load_usershare_service` **SIGSEGV** on iPad TCON to the ZFS usershare (`/var/log/samba/log.mobile`). Template is the unavailable share `zfs-usershare-template` (`available = no`, `read only = no`). After a config change, delete the Files.app server and add it again (reboot alone can reuse a stale TCON).

## How it is installed

After Samba is on disk (rebuild Phase 2 installs `samba` + `smbclient`):

```bash
sudo bin/apply-zfs-smb
sudo smbpasswd -a user    # SMB password is a separate database
```

`apply-zfs-smb` copies the drop-in, inserts `include = /etc/samba/indianadell.conf` into **`[global]`** of `/etc/samba/smb.conf` (not after `[print$]` — that would leave usershares disabled), sets the three `sharesmb` properties, restarts `smbd`, then `zfs share -a smb`.

Do **not** install Samba and skip `apply-zfs-smb`. Ubuntu’s installer left `sharesmb=on` on `rpool/USERDATA`, which would inherit onto **`/root`**.

## How to verify

```bash
zfs get -r sharesmb rpool/USERDATA
# home_ulmkkv on (local); USERDATA and root_ulmkkv off
sudo net usershare list
# rpool_USERDATA_home_ulmkkv
ss -lnt | grep ':445'
# 10.0.0.113 and 127.0.0.1 only — not docker0/virbr0, not global IPv6
smbclient -L //10.0.0.113 -U user
smbclient //10.0.0.113/home -U user -c 'ls'
smbclient //10.0.0.113/Documents -U user -c 'ls'
```

Anonymous tree connect to `[home]` must be `NT_STATUS_ACCESS_DENIED`.

## How to customize

- LAN address: `interfaces` in `etc/samba/indianadell.conf` (today `10.0.0.113`). Re-run `sudo bin/apply-zfs-smb` after edits.
- Share name: `[home]` in that file. The ZFS usershare name follows the dataset.
- Narrower share (Documents only, or `/home/user` without `ubuntu`): smb.conf `path =`, not `sharesmb` — `sharesmb` can only export a **dataset**.
- UFW is inactive on this host. If you enable it, allow TCP 445 from `10.0.0.0/24` only.

## What rebuild does / does not do

| Does | Does not |
|------|----------|
| apt-install `samba` and `smbclient` (`APT_CORE`) | Run `apply-zfs-smb` |
| | Set `smbpasswd` |
| | Change ZFS `sharesmb` (survives reboot once set) |

Post-rebuild: `sudo bin/apply-zfs-smb` then `sudo smbpasswd -a user`.
