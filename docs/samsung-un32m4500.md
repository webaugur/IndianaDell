---
title: "Samsung UN32M4500 — Lab control manual"
author: "IndianaDell / Tower5810"
date: "2026-09-06"
---

# Samsung UN32M4500 — Lab control manual

Probed on the Tower5810 LAN, 2026-09-06. This is **lab knowledge**, not a replacement for Samsung’s e-Manual.

Pretty PDF: `UN32M4500-lab-manual.pdf` (`scripts/docs/build-samsung-tv-manual.py`).

**On-disk Samsung PDFs**

| File | What |
|------|------|
| `UN32M4500_User-manual.pdf` | Official 110-page English e-Manual (`ENG_US_KTSATSCL-1.0.8`, May 2017) |
| `UN28M4500AFXZA_Service-manual.pdf` | Unofficial 70-page SM, chassis **UNV72**, **24″/28″** M4500AF only |

---

## 1. Identity (live)

REST `GET http://10.0.0.31:8001/api/v2/` (no auth):

| Field | Value |
|-------|--------|
| Model | **UN32M4500** |
| Platform | `18_KANTS_FHD` (KANT-S, Tizen **3.0**, 2017 M-series; EDID week **4 of 2018**) |
| Name | `[TV] Dave's TV television` |
| Panel | **1366×768**, 32″ class |
| OS | Tizen |
| IP | **10.0.0.31** (Wi-Fi) · mDNS `Samsung.local` |
| Wi-Fi MAC | `64:1C:B0:1E:29:20` (WOL) |
| DUID | `uuid:dedb4dce-3ae8-4724-b187-f6a72457be4c` |
| Country | US |
| API | remote **2.0.25** |
| Developer Mode | **on** (`developerMode: 1`, Host PC **10.0.0.113**) |
| Frame / Art | `FrameTVSupport: false` |
| Voice remote | `VoiceSupport: false` |
| Touchpad / gamepad | **true** |
| Token auth | **true** (use **WSS :8002**) |
| DLNA DMP | **true**; PlayReady/Widevine **as renderer: false** |
| EDEN / Smart View | **true** |

EDID on Tower5810 `card2-DP-4`: manufacturer SAM, product `0F3B`, name `SAMSUNG` only. DDC/CI I²C 0x37 does **not** answer. No `/dev/cec` on mini-DP FirePros.

**Apps confirmed via REST**

| App | ID | Version (when probed) |
|-----|-----|------------------------|
| YouTube | `111299001912` | 2.1.486 |
| Prime Video | `3201512006785` | 8.0.1 |
| Disney+ | `3201901017640` | 26.4.0 |

Netflix / Hulu / Spotify IDs tried → 404 (not installed).

---

## 2. Open ports

| Port | Role |
|------|------|
| **8001** | HTTP REST + WS (plain WS returns `ms.channel.unauthorized`) |
| **8002** | HTTPS REST + **WSS** remote (pair here) |
| **9197** | UPnP DMR (AllShare) — volume / mute / AVTransport |
| **7678** | AllShare UPnP |
| **8080** | Generic WebServer, no useful routes found |
| **15500** | Smart View / EDEN TCP |
| **26101** | `sdb` (open while Developer Mode is on) |
| AirPlay | advertised (`model=UN4500`) |

---

## 3. How to enable Developer Mode

Must be on the **Apps** panel, not Smart Hub home.

1. Home → **Apps**.
2. Type **`12345`**.
3. Developer mode **On**, Host PC IP = Tower5810 **`10.0.0.113`** (install) or **`127.0.0.1`** (keep TizenBrew without a PC).
4. Full power cycle.

Verify: Apps banner **Develop Mode**, or `"developerMode":"1"` on `/api/v2/`. Firmware updates clear it.

---

## 4. Four stacks

**Infrared is the reference** (`indiana-ir-send` / Uno NEC). The other three are compared to it.

| Stack | Where | Pairing | Offline |
|-------|--------|---------|---------|
| **Infrared** | Uno 940 nm · `indiana-ir-send` | None | Yes |
| **WebSocket** | `:8001`/`:8002` keys + REST `/api/v2/` | On-screen **Allow**; token `~/.config/indianadell/samsungtv.token` | Yes (LAN) |
| **UPnP** | `:9197` RenderingControl + AVTransport | None | Yes (LAN) |
| **SmartThings** | Cloud `api.smartthings.com` (Alexa skill) | Samsung account | **No** |

Alexa “set volume to 13” is **SmartThings `audioVolume.setVolume`**, not `KEY_VOLUP` and not IR.

Local CLI: `samsungtv` (`bin/samsungtv` → pipx `samsungtvws[cli]`). Defaults host `10.0.0.31`, port **8002**, token file as above. Opt out `SKIP_SAMSUNGTV=1`.

---

## 5. Feature comparison

**IR** = Uno blaster presets (reference). **WS** = local remote stack (WebSocket keys + REST `/api/v2/`). **UPnP** = DMR `:9197`. **ST** = SmartThings cloud (typical **2017 Tizen**; ST cells are capability-level, not live-called on this set).

| Feature | IR | WS | UPnP | ST | Note |
|---------|:--:|:--:|:----:|:--:|------|
| Power toggle | part | yes | no | part | IR is discrete ON/OFF, not toggle; ST `switch` |
| Power on from off | **yes** | part | no | part | IR `POWERON`; WS WOL; ST Power on with Mobile |
| Power off | **yes** | yes | no | yes | IR `POWEROFF` |
| Volume step ±1 | **yes** | yes | part | yes | UPnP: Get then Set ±1 |
| **Set volume to N (0–100)** | **no** | **no** | **yes** | **yes** | Beyond IR; Alexa = ST; local = UPnP `SetVolume` |
| Read volume | no | no | **yes** | **yes** | Probed `GetVolume` → 14 |
| Mute toggle | **yes** | yes | no | part | IR/WS `MUTE` |
| Mute on / off | part | no | **yes** | **yes** | IR unmute = VOL+ |
| Read mute | no | no | **yes** | **yes** | |
| Source cycle | **yes** | yes | no | yes | IR `SOURCE` |
| Set HDMI1/2 by name | **yes** | part | no | **yes** | IR discrete HDMI1–4; WS `KEY_HDMI1`/`2` often ignored |
| **Read current input** | **no** | **no** | no | **yes** | |
| D-pad, OK, Back, Home, Menu | part | **yes** | no | no | IR: d-pad, OK, HOME; no Back/Menu preset |
| Digits 0–9 | **yes** | yes | no | part | ST: `tvChannel`, not raw keys |
| Channel up/down/set | part | yes | no | yes | IR: digits only; no CH± preset |
| Read channel name | no | no | no | yes | |
| Launch app by ID | no | **yes** | no | part | REST `POST /applications/{id}`; ST flaky on 2017 |
| Close app | no | yes | no | no | REST `DELETE` |
| List apps | no | yes | no | no | WS `samsungtv apps` |
| App running? | no | yes | no | part | REST `GET /applications/{id}` |
| Type text (IME) | part | **yes** | no | no | IR: digits/dot only |
| Touchpad / mouse | no | **yes** | no | no | This set: `remote_touchPad` true |
| Media keys on TV apps | no | part | no | yes | `KEY_PLAY` vs ST `mediaPlayback` |
| Push file/URL to TV | no | no | **yes** | no | AVTransport |
| Control that pushed media | no | no | **yes** | no | |
| Device info | no | yes | part | yes | REST `/api/v2/` |
| Pairing | **no** | yes | **no** | part | IR/UPnP none; WS Allow; ST account |
| Works TV fully off | **yes** | no | no | part | IR `POWERON` |
| Works without internet | **yes** | **yes** | **yes** | **no** | |
| Art Mode | no | no | no | no | `FrameTVSupport: false` |
| Change Smart Hub / ads | no | no | no | no | Settings + DNS, not APIs |
| Sideload apps | no | no | no | no | `sdb` :26101 |

**Pick (IR as baseline)**

- What the blaster already does (HDMI2, power on/off, vol±, Home, digits) → stay on IR when the LAN stack is down.
- Absolute volume **13 / 33** → UPnP or SmartThings (IR cannot).
- Launch YouTube / type text / touchpad → `samsungtv`.
- Cast a file → UPnP.
- Read current input → SmartThings only.

---

## 6. WebSocket / REST recipes

Pair once (`Allow` on the TV). Prefer port **8002**.

```bash
samsungtv device-info
samsungtv home
samsungtv volume-up
samsungtv send-key KEY_SOURCE
samsungtv send-key KEY_HDMI2          # may no-op
samsungtv apps
samsungtv app-run 111299001912        # YouTube
curl -s http://10.0.0.31:8001/api/v2/applications/111299001912
```

REST is **not** a remote: `GET /api/v2/`, `GET|POST|DELETE|PUT /api/v2/applications/{id}` only. No `KEY_*`, no volume N.

Input keys (WS): `KEY_SOURCE`, `KEY_HDMI`, `KEY_TV`, `KEY_DTV`, `KEY_ANTENA`, `KEY_HDMI1`–`KEY_HDMI4` (try; often ignored), plus unused component/AV/S-Video/DVI.

---

## 7. UPnP absolute volume (Alexa-equivalent, local)

Probed working. No pairing.

```bash
# GetVolume — SOAPAction …#GetVolume
# SetVolume — SOAPAction …#SetVolume  <DesiredVolume>13</DesiredVolume>
curl -sS -X POST 'http://10.0.0.31:9197/upnp/control/RenderingControl1' \
  -H 'Content-Type: text/xml; charset="utf-8"' \
  -H 'SOAPAction: "urn:schemas-upnp-org:service:RenderingControl:1#GetVolume"' \
  --data '<?xml version="1.0"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:GetVolume xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1"><InstanceID>0</InstanceID><Channel>Master</Channel></u:GetVolume></s:Body></s:Envelope>'
```

Mute: `GetMute` / `SetMute`. AVTransport reported `NO_MEDIA_PRESENT` when idle.

Phone: **YAACC** (F-Droid) or **BubbleUPnP** — volume/mute/cast, not HDMI/Home.

---

## 8. SmartThings / Alexa

```text
“Alexa, set Dave's TV to 13”
  → Alexa.Speaker SetVolume { volume: 13 }
  → ST audioVolume.setVolume([13])
```

Needs the TV on the Samsung account. 2017: Settings → General → Network → Expert Settings → **Power On with Mobile**. PAT from account.smartthings.com. Not exercised live on this LAN.

---

## 9. IR (`indiana-ir-send`)

Uno 940 nm, NEC. Discrete codes this WS stack lacks:

| Command | Code |
|---------|------|
| HDMI1–4 | `E0E09768` / `E0E043BC` / `E0E0A35C` / `E0E0639C` |
| POWER ON / OFF | `E0E09966` / `E0E019E6` |
| SOURCE, MUTE, VOL±, HOME, d-pad, digits | see `tools/ir-blaster/ir-blaster.ino` |

Unmute = VOL+ (`E0E0E01F`). Works with Smart Hub down.

Factory mode (US / NTSC, TV in **standby**): hold **`*`** or `indiana-ir-send factory` → MUTE, 1, 8, 2, POWER ON. Limited menus without a factory remote.

Discrete factory keys (same NEC as a service remote): hold **`0`** (next to `*`) or `indiana-ir-send 3speed` → `0xE0E03CC3`. `indiana-ir-send factorykey` → FACTORY `0xE0E0DC23` (INFO then FACTORY with the set **on**). FACTORY+3SPEED opens the extended service menu — easy to brick.

---

## 10. Sideload (Tizen 3 / Chromium 47)

Developer Mode + Apps2Samsung or TizenBrew. **Add to Home** rearranges the bottom bar; APIs cannot restyle Smart Hub or strip promo tiles.

Worth trying: TizenBrew, TizenTube (YouTube ads). Likely fail: Overscan, Moonlight WASM, Stremio Tizen 4, Flutter `.tpk`. USB `.wgt` drop does not work. APKs do not work.

Ads / bar: Settings → Internet Based Advertisements off; Terms & Policy uncheck Viewing Information + Interest-Based Ads; remove TV Plus; Autorun Smart Hub off. Pi-hole for leftover beacons.

---

## 11. What we did not verify

SmartThings live on this DUID; `KEY_HDMI2` actually switching; 32″-specific pages in the 24/28 service SM; DDC/CI after OSD enable; WOL from full power-off.
