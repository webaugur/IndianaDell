# IR blaster — see https://github.com/webaugur/indiana-blaster

# indiana-blaster

Arduino Uno Samsung IR remote: 940 nm LED, 4×4 keypad, RGB status, 5-pin rotary encoder, USB serial.

Repo: https://github.com/webaugur/indiana-blaster

## IR LED

```
Uno 5V ---- 100 Ω ---- IR LED anode (+)
                         IR LED cathode (−) ---- collector  2N2222 / 2N3904
Uno D3  ---- 1 kΩ ---- base
Uno GND --------------- emitter
```

Do not drive the LED from D3 alone. Aim the dome at the TV IR window.

## RGB status (one 220 Ω)

**D12 = R, D13 = G, A0 = B.**  
Tap → **green** 2.5 s. Hold → **blue** 2.5 s. After each IR burst → **red** 0.5 s (green/blue off while red is on, then the tap/hold color returns).

Common cathode (default):

```
D12 -- R anode
D13 -- G anode
A0  -- B anode
common cathode ---- 220 Ω ---- GND
```

Common anode: set `#define RGB_COMMON_ANODE 1` in `ir-blaster/ir-blaster.ino`, then `5V -- 220 Ω -- common anode` and R/G/B cathodes to the pins.

## 5-pin rotary encoder

```
C  (common)  ---- GND
A  (CLK)     ---- D2
B  (DT)      ---- A1
SW1          ---- GND
SW2          ---- A2
```

One full turn = **10 VOL+ or VOL−** (10% on a 0–100 Samsung scale). Default **20 detents/turn** (`ENC_DETENTS_REV`). Click = **MUTE**. Swap A/B if CW is backwards.

## 4×4 keypad (rows D4–D7, cols D8–D11)

```
        D8   D9  D10  D11
D4       1    2    3    A
D5       4    5    6    B
D6       7    8    9    C
D7       *    0    #    D
```

| Key | Tap | Hold (500 ms) |
|-----|-----|----------------|
| 0–9 | digit | 2/1/3 UP · 8/7/9 DOWN · 4 LEFT · 6 RIGHT · 5 OK |
| `*` | DOT | factory mode (standby: MUTE 1 8 2 POWER ON) |
| `0` | 0 | 3SPEED (extended factory; TV already in service menu) |
| `#` | POWER ON | POWER OFF |
| A | VOL+ | HDMI1 |
| B | MUTE | HDMI2 |
| C | VOL− | HDMI3 |
| D | HOME (Smart Hub) | HDMI4 |

Schematic: [`ir-blaster/ir-blaster-schematic.png`](ir-blaster/ir-blaster-schematic.png)  
Rebuild: `python3 ir-blaster/render-schematic.py`

## Flash (arduino-cli, no IDE)

```bash
sudo apt install arduino-cli
sudo usermod -aG dialout "$USER"   # then log out
./bin/indiana-ir-flash
./bin/indiana-ir-flash --port /dev/ttyACM0
./bin/indiana-ir-flash --compile-only
```

## USB serial

```bash
./bin/indiana-ir-send detect
./bin/indiana-ir-send poweron
./bin/indiana-ir-send hdmi2
./bin/indiana-ir-send volup
```

115200 8N1. Host waits for `READY`/`OK` on the port (Uno resets on open).

Pin map: D3 IR · D4–D11 keypad · D12/D13/A0 RGB · D2/A1/A2 encoder · D0/D1 USB serial. Free: A3–A5.
