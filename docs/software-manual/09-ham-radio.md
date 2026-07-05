# Chapter 9 — Ham Radio (Desktop)

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

Apt packages in `APT_SDR_HAM` (rebuild Phase 3).

**xastir debconf:** rebuild preseeds `xastir/install-setuid boolean false` to avoid interactive install hangs.

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
bin/rebuild-machine --verify-only   # checks fldigi, wsjtx, chirpw
```

Configure rig control in each app via Hamlib model selection.

## How to customize

- Radio definitions: CHIRP stock configs + your radio CSV
- WSJT-X: `~/.config/WSJT-X/`
- xastir maps: `xastir-data` package + user map sources
- direwolf: `~/.direwolf/direwolf.conf`

## What rebuild does / does not do

| Does | Does not |
|------|----------|
| Install all ham desktop apps + Hamlib | Configure radios or call signs |
| Preseed xastir setuid prompt | Set up APRS IS or igates |
| Verify fldigi, wsjtx, chirpw commands | Install fldigi/WSJT-X from source |