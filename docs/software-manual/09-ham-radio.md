# Chapter 9 — Ham Radio (Desktop)

## Ownership

Desktop ham applications are part of the **DragonSDR** suite (`APT_HAM` in `tools/package-lists.sh`).

## What gets installed

| Application | Command | Apt package | Role |
|-------------|---------|-------------|------|
| fldigi | `fldigi` | `fldigi` | Digital modes (PSK, RTTY, …) |
| WSJT-X | `wsjtx` | `wsjtx`, `wsjtx-data` | FT8, JT65, weak-signal |
| CHIRP | `chirpw`, `chirpc` | `chirp` | Radio programming |
| direwolf | `direwolf` | `direwolf` | Sound-card TNC / APRS |
| gpredict | `gpredict` | `gpredict` | Satellite pass prediction |
| grig | `grig` | `grig` | Hamlib rig control GUI |
| xastir | `xastir` | `xastir`, `xastir-data` | APRS map client |
| Hamlib | API | `libhamlib-dev`, `libhamlib-utils`, `python3-hamlib` | Rig control library |

## How it is installed

```bash
bin/install-dragonsdr
# omit ham apps:
SKIP_HAM=1 bin/install-dragonsdr
```

**xastir debconf:** suite install preseeds `xastir/install-setuid boolean false` to avoid interactive hangs.

```bash
fldigi &
wsjtx &
chirpw &
direwolf -p
gpredict &
grig &
xastir &
```

## How to verify

```bash
command -v fldigi wsjtx chirpw direwolf gpredict grig xastir
python3 -c "import Hamlib; print('Hamlib OK')"
bin/install-dragonsdr --verify-only
```

Configure rig control in each app via Hamlib model selection.
