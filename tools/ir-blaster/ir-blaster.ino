#include <string.h>

// indiana-blaster — Uno, no extra libraries.
// IR: D3 -- 1k -- 2N2222 base; emitter GND; 5V -- 100R -- IR LED -- collector.
// 4x4 keypad: rows D4-D7, cols D8-D11 (standard 123A / 456B / 789C / *0#D).
// RGB: D12=R D13=G A0=B, one 220Ω on the common (see RGB_COMMON_ANODE).
// Encoder (5-pin): C+SW1→GND, A/CLK→D2, B/DT→A1, SW2→A2. INPUT_PULLUP.
// Serial 115200. READY after reset.

const uint8_t IR_PIN = 3;
const uint8_t RGB_R = 12;
const uint8_t RGB_G = 13;
const uint8_t RGB_B = A0;
const uint8_t ENC_CLK = 2;  // A / CLK (INT0)
const uint8_t ENC_DT = A1;  // B / DT
const uint8_t ENC_SW = A2;  // push switch
// Typical PEC11: 20 detents/turn. 10 VOL± IR codes ≈ 10% of 0–100 Samsung volume.
const uint8_t ENC_DETENTS_REV = 20;
const uint8_t ENC_VOL_STEPS_REV = 10;
// 0 = common cathode (common -- 220Ω -- GND; R/G/B anodes to pins).
// 1 = common anode   (5V -- 220Ω -- common; R/G/B cathodes to pins).
#ifndef RGB_COMMON_ANODE
#define RGB_COMMON_ANODE 0
#endif
const uint16_t CARRIER_HALF_US = 13;
const uint8_t SEND_REPEATS = 3;
const uint16_t HOLD_MS = 500;
const uint16_t RGB_RED_MS = 500;     // red while/after IR, kills green/blue
const uint16_t RGB_STATUS_MS = 2500; // tap = green, hold = blue

static unsigned long rgb_red_until = 0;
static unsigned long rgb_status_until = 0;
static uint8_t rgb_status = 0; // 0 off, 1 tap green, 2 hold blue

const uint8_t ROW_PIN[4] = {4, 5, 6, 7};
const uint8_t COL_PIN[4] = {8, 9, 10, 11};
const char KEYMAP[4][4] = {
    {'1', '2', '3', 'A'},
    {'4', '5', '6', 'B'},
    {'7', '8', '9', 'C'},
    {'*', '0', '#', 'D'},
};

// Tasmota AA59 table except DOT (common Samsung dash; recapture if ignored)
// UNMUTE: no discrete unmute — send VOL+ (E0E0E01F) which unmutes on most Samsungs.
#define C_HDMI1 0xE0E09768UL
#define C_HDMI2 0xE0E043BCUL
#define C_HDMI3 0xE0E0A35CUL
#define C_HDMI4 0xE0E0639CUL
#define C_SOURCE 0xE0E0807FUL
#define C_POWERON 0xE0E09966UL
#define C_POWEROFF 0xE0E019E6UL
#define C_MUTE 0xE0E0F00FUL
#define C_VOLUP 0xE0E0E01FUL
#define C_VOLDOWN 0xE0E0D02FUL
#define C_HOME 0xE0E09E61UL
#define C_UP 0xE0E006F9UL
#define C_DOWN 0xE0E08679UL
#define C_LEFT 0xE0E0A659UL
#define C_RIGHT 0xE0E046B9UL
#define C_OK 0xE0E016E9UL
#define C_DOT 0xE0E0C43BUL
#define C_0 0xE0E08877UL
#define C_1 0xE0E020DFUL
#define C_2 0xE0E0A05FUL
#define C_3 0xE0E0609FUL
#define C_4 0xE0E010EFUL
#define C_5 0xE0E0906FUL
#define C_6 0xE0E050AFUL
#define C_7 0xE0E030CFUL
#define C_8 0xE0E0B04FUL
#define C_9 0xE0E0708FUL

struct Preset {
  const char *name;
  uint32_t code;
};

static const Preset PRESETS[] = {
    {"HDMI1", C_HDMI1},
    {"HDMI2", C_HDMI2},
    {"HDMI3", C_HDMI3},
    {"HDMI4", C_HDMI4},
    {"SOURCE", C_SOURCE},
    {"POWERON", C_POWERON},
    {"POWEROFF", C_POWEROFF},
    {"MUTE", C_MUTE},
    {"UNMUTE", C_VOLUP},
    {"VOLUP", C_VOLUP},
    {"VOLDOWN", C_VOLDOWN},
    {"HOME", C_HOME},
    {"UP", C_UP},
    {"DOWN", C_DOWN},
    {"LEFT", C_LEFT},
    {"RIGHT", C_RIGHT},
    {"OK", C_OK},
    {"DOT", C_DOT},
    {"0", C_0},
    {"1", C_1},
    {"2", C_2},
    {"3", C_3},
    {"4", C_4},
    {"5", C_5},
    {"6", C_6},
    {"7", C_7},
    {"8", C_8},
    {"9", C_9},
};

static void carrier_mark(uint16_t usec) {
  unsigned long end = micros() + usec;
  while ((long)(end - micros()) > 0) {
    digitalWrite(IR_PIN, HIGH);
    delayMicroseconds(CARRIER_HALF_US);
    digitalWrite(IR_PIN, LOW);
    delayMicroseconds(CARRIER_HALF_US);
  }
}

static void ir_space(uint16_t usec) {
  digitalWrite(IR_PIN, LOW);
  delayMicroseconds(usec);
}

static void send_samsung(uint32_t code) {
  carrier_mark(4500);
  ir_space(4500);
  for (int i = 31; i >= 0; i--) {
    carrier_mark(560);
    if (code & (1UL << i))
      ir_space(1690);
    else
      ir_space(560);
  }
  carrier_mark(560);
  digitalWrite(IR_PIN, LOW);
}

static void rgb_drive(uint8_t pin, bool on) {
#if RGB_COMMON_ANODE
  digitalWrite(pin, on ? LOW : HIGH);
#else
  digitalWrite(pin, on ? HIGH : LOW);
#endif
}

static void rgb_set(bool r, bool g, bool b) {
  rgb_drive(RGB_R, r);
  rgb_drive(RGB_G, g);
  rgb_drive(RGB_B, b);
}

static void rgb_note_tap(void) {
  rgb_status = 1;
  rgb_status_until = millis() + RGB_STATUS_MS;
}

static void rgb_note_hold(void) {
  rgb_status = 2;
  rgb_status_until = millis() + RGB_STATUS_MS;
}

static void rgb_note_tx(void) {
  rgb_red_until = millis() + RGB_RED_MS;
}

static void rgb_poll(void) {
  unsigned long now = millis();
  if ((long)(rgb_red_until - now) > 0) {
    rgb_set(true, false, false);
    return;
  }
  if ((long)(rgb_status_until - now) > 0) {
    if (rgb_status == 1)
      rgb_set(false, true, false);
    else if (rgb_status == 2)
      rgb_set(false, false, true);
    else
      rgb_set(false, false, false);
    return;
  }
  rgb_set(false, false, false);
}

static void send_named_n(const char *name, uint32_t code, uint8_t repeats) {
  for (uint8_t n = 0; n < repeats; n++) {
    send_samsung(code);
    if (n + 1 < repeats)
      delay(40);
  }
  rgb_note_tx();
  rgb_set(true, false, false);
  Serial.print(F("OK "));
  Serial.println(name);
}

static void send_named(const char *name, uint32_t code) {
  send_named_n(name, code, SEND_REPEATS);
}

static void trim_inplace(char *s) {
  size_t n = strlen(s);
  while (n && (s[n - 1] == '\n' || s[n - 1] == '\r' || s[n - 1] == ' '))
    s[--n] = 0;
  char *p = s;
  while (*p == ' ')
    p++;
  if (p != s)
    memmove(s, p, strlen(p) + 1);
  for (char *q = s; *q; q++) {
    if (*q >= 'a' && *q <= 'z')
      *q = (char)(*q - 'a' + 'A');
  }
}

static bool parse_hex32(const char *s, uint32_t *out) {
  if (s[0] == '0' && s[1] == 'X')
    s += 2;
  if (strlen(s) == 0 || strlen(s) > 8)
    return false;
  uint32_t v = 0;
  for (const char *p = s; *p; p++) {
    char c = *p;
    uint8_t nib;
    if (c >= '0' && c <= '9')
      nib = (uint8_t)(c - '0');
    else if (c >= 'A' && c <= 'F')
      nib = (uint8_t)(c - 'A' + 10);
    else
      return false;
    v = (v << 4) | nib;
  }
  *out = v;
  return true;
}

static void fire_preset(const char *name) {
  for (uint8_t i = 0; i < sizeof(PRESETS) / sizeof(PRESETS[0]); i++) {
    if (strcmp(name, PRESETS[i].name) == 0) {
      send_named(PRESETS[i].name, PRESETS[i].code);
      return;
    }
  }
  Serial.println(F("ERR unknown"));
}

static void handle_line(char *line) {
  trim_inplace(line);
  if (line[0] == 0)
    return;
  if (strcmp(line, "HELP") == 0) {
    Serial.println(F("OK HDMI1-4 SOURCE POWERON POWEROFF MUTE UNMUTE VOLUP VOLDOWN HOME UP DOWN LEFT RIGHT OK DOT 0-9 SEND <hex>"));
    return;
  }
  if (strncmp(line, "SEND ", 5) == 0) {
    uint32_t code;
    if (!parse_hex32(line + 5, &code)) {
      Serial.println(F("ERR bad hex"));
      return;
    }
    rgb_note_tap();
    send_named("SEND", code);
    return;
  }
  rgb_note_tap();
  fire_preset(line);
}

static char scan_keypad() {
  for (uint8_t r = 0; r < 4; r++) {
    for (uint8_t i = 0; i < 4; i++)
      digitalWrite(ROW_PIN[i], HIGH);
    digitalWrite(ROW_PIN[r], LOW);
    delayMicroseconds(50);  // settle after row drive (not a wait-and-hope)
    for (uint8_t c = 0; c < 4; c++) {
      if (digitalRead(COL_PIN[c]) == LOW)
        return KEYMAP[r][c];
    }
  }
  return 0;
}

static void keypad_event(char key, bool held) {
  if (held)
    rgb_note_hold();
  else
    rgb_note_tap();
  if (key >= '0' && key <= '9') {
    if (held) {
      switch (key) {
        case '1':
        case '2':
        case '3':
          fire_preset("UP");
          break;
        case '7':
        case '8':
        case '9':
          fire_preset("DOWN");
          break;
        case '4':
          fire_preset("LEFT");
          break;
        case '6':
          fire_preset("RIGHT");
          break;
        case '5':
          fire_preset("OK");
          break;
        default:
          break;
      }
      return;
    }
    char n[2] = {key, 0};
    fire_preset(n);
    return;
  }
  switch (key) {
    case '*':
      fire_preset("DOT");
      break;
    case '#':
      fire_preset(held ? "POWEROFF" : "POWERON");
      break;
    case 'A':
      fire_preset(held ? "HDMI1" : "VOLUP");
      break;
    case 'B':
      fire_preset(held ? "HDMI2" : "MUTE");
      break;
    case 'C':
      fire_preset(held ? "HDMI3" : "VOLDOWN");
      break;
    case 'D':
      fire_preset(held ? "HDMI4" : "HOME");
      break;
    default:
      break;
  }
}

static void poll_keypad() {
  static char down = 0;
  static unsigned long t0 = 0;
  static bool hold_sent = false;
  char k = scan_keypad();
  unsigned long now = millis();
  if (k && k == down) {
    if (!hold_sent && (now - t0) >= HOLD_MS) {
      keypad_event(k, true);
      hold_sent = true;
    }
    return;
  }
  if (down && !k) {
    if (!hold_sent)
      keypad_event(down, false);
    down = 0;
    hold_sent = false;
    return;
  }
  if (k && k != down) {
    down = k;
    t0 = now;
    hold_sent = false;
  }
}

static void poll_encoder() {
  static uint8_t last_clk = 1;
  static int8_t acc = 0;
  static unsigned long last_edge = 0;
  static uint8_t sw_down = 0;
  static unsigned long sw_t0 = 0;
  unsigned long now = millis();
  uint8_t clk = digitalRead(ENC_CLK);
  if (last_clk == HIGH && clk == LOW && (now - last_edge) >= 2) {
    last_edge = now;
    int8_t dir = (digitalRead(ENC_DT) == HIGH) ? 1 : -1;
    acc += dir;
    int8_t thresh = (int8_t)(ENC_DETENTS_REV / ENC_VOL_STEPS_REV);
    if (thresh < 1)
      thresh = 1;
    while (acc >= thresh) {
      rgb_note_tap();
      send_named_n("VOLUP", C_VOLUP, 1);
      acc -= thresh;
    }
    while (acc <= -thresh) {
      rgb_note_tap();
      send_named_n("VOLDOWN", C_VOLDOWN, 1);
      acc += thresh;
    }
  }
  last_clk = clk;

  uint8_t sw = digitalRead(ENC_SW) == LOW;
  if (sw && !sw_down) {
    sw_down = 1;
    sw_t0 = now;
  } else if (!sw && sw_down) {
    sw_down = 0;
    if ((now - sw_t0) < HOLD_MS) {
      rgb_note_tap();
      fire_preset("MUTE");
    }
  }
}

void setup() {
  pinMode(IR_PIN, OUTPUT);
  digitalWrite(IR_PIN, LOW);
  pinMode(RGB_R, OUTPUT);
  pinMode(RGB_G, OUTPUT);
  pinMode(RGB_B, OUTPUT);
  rgb_set(false, false, false);
  rgb_status = 0;
  rgb_red_until = 0;
  rgb_status_until = 0;
  pinMode(ENC_CLK, INPUT_PULLUP);
  pinMode(ENC_DT, INPUT_PULLUP);
  pinMode(ENC_SW, INPUT_PULLUP);
  for (uint8_t i = 0; i < 4; i++) {
    pinMode(ROW_PIN[i], OUTPUT);
    digitalWrite(ROW_PIN[i], HIGH);
    pinMode(COL_PIN[i], INPUT_PULLUP);
  }
  Serial.begin(115200);
  while (!Serial) {
    ;
  }
  Serial.println(F("READY"));
}

void loop() {
  static char buf[48];
  static uint8_t n = 0;
  while (Serial.available()) {
    char c = (char)Serial.read();
    if (c == '\n' || c == '\r') {
      buf[n] = 0;
      n = 0;
      handle_line(buf);
    } else if (n + 1 < sizeof(buf)) {
      buf[n++] = c;
    } else {
      n = 0;
      Serial.println(F("ERR overflow"));
    }
  }
  poll_keypad();
  poll_encoder();
  rgb_poll();
}
