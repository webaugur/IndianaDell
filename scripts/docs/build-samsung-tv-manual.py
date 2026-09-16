#!/usr/bin/env python3
"""Build UN32M4500-lab-manual.pdf from probed lab knowledge."""
from __future__ import annotations

from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import letter, landscape
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "UN32M4500-lab-manual.pdf"

NAVY = colors.HexColor("#1B365D")
NAVY_MID = colors.HexColor("#2C5282")
RULE = colors.HexColor("#CBD5E0")
INK = colors.HexColor("#1A202C")
MUTED = colors.HexColor("#4A5568")
YES_BG = colors.HexColor("#C6F6D5")
YES_FG = colors.HexColor("#22543D")
NO_BG = colors.HexColor("#FED7D7")
NO_FG = colors.HexColor("#9B2C2C")
PART_BG = colors.HexColor("#FEEBC8")
PART_FG = colors.HexColor("#7B341E")
HEAD_BG = colors.HexColor("#1B365D")
ZEBRA = colors.HexColor("#F7FAFC")

# status: yes | no | part  — columns: ir, ws, upnp, st
FEATURES: list[tuple[str, str, str, str, str, str]] = [
    ("Power toggle", "part", "yes", "no", "part", "IR discrete ON/OFF; ST switch"),
    ("Power on from off", "yes", "part", "no", "part", "IR POWERON; WS WOL; ST Power on with Mobile"),
    ("Power off", "yes", "yes", "no", "yes", "IR POWEROFF"),
    ("Volume step ±1", "yes", "yes", "part", "yes", "UPnP: Get then Set ±1"),
    ("Set volume to N (0–100)", "no", "no", "yes", "yes", "Beyond IR; Alexa = ST; local = UPnP"),
    ("Read volume", "no", "no", "yes", "yes", "Probed GetVolume → 14"),
    ("Mute toggle", "yes", "yes", "no", "part", "IR/WS MUTE"),
    ("Mute on / off", "part", "no", "yes", "yes", "IR unmute = VOL+"),
    ("Read mute", "no", "no", "yes", "yes", ""),
    ("Source cycle", "yes", "yes", "no", "yes", "IR SOURCE"),
    ("Set HDMI 1/2 by name", "yes", "part", "no", "yes", "IR discrete HDMI1–4; WS KEY_HDMI1/2 flaky"),
    ("Read current input", "no", "no", "no", "yes", ""),
    ("D-pad, OK, Back, Home, Menu", "part", "yes", "no", "no", "IR: d-pad, OK, HOME; no Back/Menu preset"),
    ("Digits 0–9", "yes", "yes", "no", "part", "ST: tvChannel, not raw keys"),
    ("Channel up / down / set", "part", "yes", "no", "yes", "IR digits only; no CH± preset"),
    ("Read channel name", "no", "no", "no", "yes", ""),
    ("Launch app by ID", "no", "yes", "no", "part", "REST POST /applications/{id}; ST flaky on 2017"),
    ("Close app", "no", "yes", "no", "no", "REST DELETE"),
    ("List apps", "no", "yes", "no", "no", "samsungtv apps"),
    ("App running?", "no", "yes", "no", "part", "REST GET /applications/{id}"),
    ("Type text (IME)", "part", "yes", "no", "no", "IR: digits/dot only"),
    ("Touchpad / mouse", "no", "yes", "no", "no", "remote_touchPad true on this set"),
    ("Media keys on TV apps", "no", "part", "no", "yes", "KEY_PLAY vs ST mediaPlayback"),
    ("Push file/URL to TV", "no", "no", "yes", "no", "AVTransport"),
    ("Control pushed media", "no", "no", "yes", "no", ""),
    ("Device info", "no", "yes", "part", "yes", "REST GET /api/v2/"),
    ("Pairing", "no", "yes", "no", "part", "IR/UPnP none; WS Allow; ST account"),
    ("Works TV fully off", "yes", "no", "no", "part", "IR POWERON"),
    ("Works without internet", "yes", "yes", "yes", "no", ""),
    ("Art Mode", "no", "no", "no", "no", "FrameTVSupport: false"),
    ("Change Smart Hub / ads", "no", "no", "no", "no", "Settings + DNS, not APIs"),
    ("Sideload apps", "no", "no", "no", "no", "sdb :26101"),
]


def styles() -> dict[str, ParagraphStyle]:
    base = getSampleStyleSheet()
    s: dict[str, ParagraphStyle] = {}
    s["cover_kicker"] = ParagraphStyle(
        "cover_kicker", parent=base["Normal"], fontName="Helvetica",
        fontSize=9, textColor=NAVY_MID, tracking=1.2, spaceAfter=6,
    )
    s["cover_title"] = ParagraphStyle(
        "cover_title", parent=base["Title"], fontName="Helvetica-Bold",
        fontSize=26, leading=30, textColor=NAVY, alignment=TA_LEFT, spaceAfter=8,
    )
    s["cover_sub"] = ParagraphStyle(
        "cover_sub", parent=base["Normal"], fontName="Helvetica",
        fontSize=11, leading=15, textColor=MUTED, spaceAfter=4,
    )
    s["h1"] = ParagraphStyle(
        "h1", parent=base["Heading1"], fontName="Helvetica-Bold",
        fontSize=14, textColor=NAVY, spaceBefore=14, spaceAfter=8,
    )
    s["h2"] = ParagraphStyle(
        "h2", parent=base["Heading2"], fontName="Helvetica-Bold",
        fontSize=11.5, textColor=NAVY_MID, spaceBefore=10, spaceAfter=6,
    )
    s["body"] = ParagraphStyle(
        "body", parent=base["Normal"], fontName="Helvetica",
        fontSize=9, leading=12.5, textColor=INK, spaceAfter=6,
    )
    s["small"] = ParagraphStyle(
        "small", parent=base["Normal"], fontName="Helvetica",
        fontSize=8, leading=11, textColor=MUTED, spaceAfter=4,
    )
    s["code"] = ParagraphStyle(
        "code", parent=base["Code"], fontName="Courier",
        fontSize=7.5, leading=10, textColor=INK, spaceAfter=8,
    )
    s["th"] = ParagraphStyle(
        "th", parent=base["Normal"], fontName="Helvetica-Bold",
        fontSize=7.5, leading=10, textColor=colors.white, alignment=TA_CENTER,
    )
    s["th_left"] = ParagraphStyle(
        "th_left", parent=s["th"], alignment=TA_LEFT,
    )
    s["feat"] = ParagraphStyle(
        "feat", parent=base["Normal"], fontName="Helvetica",
        fontSize=7.5, leading=10, textColor=INK,
    )
    s["note"] = ParagraphStyle(
        "note", parent=base["Normal"], fontName="Helvetica",
        fontSize=7, leading=9.5, textColor=MUTED,
    )
    s["yes"] = ParagraphStyle(
        "yes", parent=base["Normal"], fontName="Helvetica-Bold",
        fontSize=8, textColor=YES_FG, alignment=TA_CENTER,
    )
    s["no"] = ParagraphStyle(
        "no", parent=base["Normal"], fontName="Helvetica-Bold",
        fontSize=8, textColor=NO_FG, alignment=TA_CENTER,
    )
    s["part"] = ParagraphStyle(
        "part", parent=base["Normal"], fontName="Helvetica-Bold",
        fontSize=7.5, textColor=PART_FG, alignment=TA_CENTER,
    )
    s["footer"] = ParagraphStyle(
        "footer", parent=base["Normal"], fontName="Helvetica",
        fontSize=8, textColor=MUTED, alignment=TA_CENTER,
    )
    return s


def badge(status: str, st: dict[str, ParagraphStyle]) -> Paragraph:
    label = {"yes": "Yes", "no": "No", "part": "Partial"}[status]
    return Paragraph(label, st[status])


def badge_bg(status: str) -> colors.Color:
    return {"yes": YES_BG, "no": NO_BG, "part": PART_BG}[status]


def identity_table(st: dict[str, ParagraphStyle]) -> Table:
    rows_src = [
        ("Model", "UN32M4500"),
        ("Platform", "18_KANTS_FHD · Tizen 3.0 · KANT-S · EDID week 4 / 2018"),
        ("Name", "[TV] Dave's TV television"),
        ("Panel", "1366×768 · 32″ class"),
        ("LAN", "10.0.0.31 (Wi-Fi) · Samsung.local · MAC 64:1C:B0:1E:29:20"),
        ("API", "remote 2.0.25 · TokenAuth · WSS :8002"),
        ("Developer Mode", "on · Host PC 10.0.0.113 · sdb :26101"),
        ("Apps (REST)", "YouTube 111299001912 · Prime 3201512006785 · Disney+ 3201901017640"),
    ]
    data = []
    for k, v in rows_src:
        data.append([
            Paragraph(f"<b>{k}</b>", st["feat"]),
            Paragraph(v, st["feat"]),
        ])
    for i, (k, v) in enumerate(rows_src):
        data[i][0] = Paragraph(f'<font color="white"><b>{k}</b></font>', st["feat"])
    t = Table(data, colWidths=[1.7 * inch, 8.5 * inch])
    cmds = [
        ("BACKGROUND", (0, 0), (0, -1), NAVY),
        ("BACKGROUND", (1, 0), (1, -1), colors.white),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 8),
        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
        ("LINEBELOW", (0, 0), (-1, -2), 0.25, RULE),
        ("BOX", (0, 0), (-1, -1), 0.8, NAVY),
        ("ROWBACKGROUNDS", (1, 0), (1, -1), [colors.white, ZEBRA]),
    ]
    t.setStyle(TableStyle(cmds))
    return t


def comparison_table(st: dict[str, ParagraphStyle]) -> Table:
    header = [
        Paragraph("Feature", st["th_left"]),
        Paragraph("Infrared<br/>reference · Uno", st["th"]),
        Paragraph("WebSocket<br/>:8001 / :8002", st["th"]),
        Paragraph("UPnP DMR<br/>:9197", st["th"]),
        Paragraph("SmartThings<br/>cloud / Alexa", st["th"]),
        Paragraph("Note", st["th_left"]),
    ]
    data = [header]
    for feat, ir, ws, up, sm, note in FEATURES:
        data.append([
            Paragraph(feat, st["feat"]),
            badge(ir, st),
            badge(ws, st),
            badge(up, st),
            badge(sm, st),
            Paragraph(note, st["note"]),
        ])
    # landscape usable width ~ 10.2"
    widths = [2.05 * inch, 1.05 * inch, 1.1 * inch, 1.05 * inch, 1.2 * inch, 3.75 * inch]
    t = Table(data, colWidths=widths, repeatRows=1)
    cmds: list = [
        ("BACKGROUND", (0, 0), (-1, 0), HEAD_BG),
        ("BACKGROUND", (1, 0), (1, 0), colors.HexColor("#2B6CB0")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("ALIGN", (1, 1), (4, -1), "CENTER"),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, -1), 3.5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3.5),
        ("BOX", (0, 0), (-1, -1), 0.6, NAVY),
        ("LINEAFTER", (1, 0), (1, -1), 1.2, colors.HexColor("#2B6CB0")),
        ("LINEBELOW", (0, 1), (-1, -2), 0.2, RULE),
    ]
    for r, (_feat, ir, ws, up, sm, _note) in enumerate(FEATURES, start=1):
        if r % 2 == 0:
            cmds.append(("BACKGROUND", (0, r), (0, r), ZEBRA))
            cmds.append(("BACKGROUND", (5, r), (5, r), ZEBRA))
        cmds.append(("BACKGROUND", (1, r), (1, r), badge_bg(ir)))
        cmds.append(("BACKGROUND", (2, r), (2, r), badge_bg(ws)))
        cmds.append(("BACKGROUND", (3, r), (3, r), badge_bg(up)))
        cmds.append(("BACKGROUND", (4, r), (4, r), badge_bg(sm)))
    t.setStyle(TableStyle(cmds))
    return t


def ports_table(st: dict[str, ParagraphStyle]) -> Table:
    rows = [
        [Paragraph("<b>Port</b>", st["feat"]), Paragraph("<b>Role</b>", st["feat"])],
        [Paragraph("8001", st["feat"]), Paragraph("HTTP REST + WS (plain WS: unauthorized)", st["feat"])],
        [Paragraph("8002", st["feat"]), Paragraph("HTTPS REST + WSS remote (pair here)", st["feat"])],
        [Paragraph("9197", st["feat"]), Paragraph("UPnP DMR — SetVolume / SetMute / AVTransport", st["feat"])],
        [Paragraph("7678", st["feat"]), Paragraph("AllShare UPnP", st["feat"])],
        [Paragraph("26101", st["feat"]), Paragraph("sdb while Developer Mode is on", st["feat"])],
        [Paragraph("15500", st["feat"]), Paragraph("Smart View / EDEN", st["feat"])],
    ]
    rows[0] = [
        Paragraph('<font color="white"><b>Port</b></font>', st["feat"]),
        Paragraph('<font color="white"><b>Role</b></font>', st["feat"]),
    ]
    t = Table(rows, colWidths=[1.2 * inch, 9.0 * inch])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), NAVY),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, ZEBRA]),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 7),
        ("RIGHTPADDING", (0, 0), (-1, -1), 7),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ("BOX", (0, 0), (-1, -1), 0.6, NAVY),
        ("LINEBELOW", (0, 0), (-1, -2), 0.25, RULE),
    ]))
    return t


def footer(canvas, doc) -> None:
    canvas.saveState()
    w, h = doc.pagesize
    canvas.setFillColor(NAVY)
    canvas.rect(0, h - 10, w, 10, fill=1, stroke=0)
    canvas.setFillColor(NAVY)
    canvas.rect(0, 0, w, 28, fill=1, stroke=0)
    canvas.setFillColor(colors.white)
    canvas.setFont("Helvetica", 8)
    canvas.drawString(0.6 * inch, 12, "IndianaDell  ·  Tower5810  ·  UN32M4500 lab control")
    canvas.drawRightString(w - 0.6 * inch, 12, f"{doc.page}")
    canvas.restoreState()


def build() -> None:
    st = styles()
    story = []

    story.append(Paragraph("INDIANADELL  ·  TOWER5810  ·  PROBED 2026-09-06", st["cover_kicker"]))
    story.append(Paragraph("Samsung UN32M4500", st["cover_title"]))
    story.append(Paragraph(
        "Lab control manual — Infrared (reference), WebSocket, UPnP, and SmartThings. "
        "Not a substitute for Samsung’s e-Manual.",
        st["cover_sub"],
    ))
    story.append(Spacer(1, 10))
    story.append(identity_table(st))
    story.append(Spacer(1, 12))
    story.append(Paragraph("Open ports", st["h1"]))
    story.append(ports_table(st))
    story.append(Spacer(1, 10))
    story.append(Paragraph(
        "DDC/CI on <font face='Courier'>card2-DP-4</font> does not answer. "
        "No HDMI-CEC on FirePro mini-DP. Developer Mode is on "
        "(Host PC 10.0.0.113). Frame/Art and voice remote are off.",
        st["small"],
    ))
    story.append(Paragraph(
        "On disk: <font face='Courier'>UN32M4500_User-manual.pdf</font> "
        "(official 110-page e-Manual) and "
        "<font face='Courier'>UN28M4500AFXZA_Service-manual.pdf</font> "
        "(24″/28″ M4500AF service book, chassis UNV72).",
        st["small"],
    ))

    story.append(PageBreak())
    story.append(Paragraph("Protocol comparison", st["h1"]))
    story.append(Paragraph(
        "<b>Infrared</b> (first column, blue rule) is the reference: Uno 940&nbsp;nm "
        "<font face='Courier'>indiana-ir-send</font> presets. "
        "<b>WebSocket</b> is the local remote stack on :8001/:8002 "
        "(keys plus REST <font face='Courier'>/api/v2/</font>). "
        "<b>UPnP</b> is AllShare DMR on :9197 (live GetVolume worked). "
        "<b>SmartThings</b> is the cloud Alexa uses; those cells are typical "
        "<b>2017 Tizen</b> capabilities, not live-called on this DUID. "
        "Green = yes · amber = partial · red = no.",
        st["body"],
    ))
    story.append(Spacer(1, 8))
    story.append(comparison_table(st))
    story.append(Spacer(1, 8))
    story.append(Paragraph(
        "<b>Pick (IR as baseline):</b> HDMI2, power on/off, vol±, Home, digits → IR when LAN is down. "
        "Absolute volume 13/33 → UPnP or SmartThings (IR cannot). "
        "Launch YouTube / type text / touchpad → <font face='Courier'>samsungtv</font>. "
        "Cast a file → UPnP. Read current input → SmartThings only.",
        st["body"],
    ))

    story.append(PageBreak())
    story.append(Paragraph("Recipes", st["h1"]))
    story.append(Paragraph("Developer Mode", st["h2"]))
    story.append(Paragraph(
        "Apps panel (not Smart Hub home) → type <b>12345</b> → On → "
        "Host PC <font face='Courier'>10.0.0.113</font> (or "
        "<font face='Courier'>127.0.0.1</font> after TizenBrew) → full power cycle.",
        st["body"],
    ))
    story.append(Paragraph("WebSocket CLI  ·  samsungtv", st["h2"]))
    story.append(Paragraph(
        "pipx <font face='Courier'>samsungtvws[cli]</font>; wrapper "
        "<font face='Courier'>bin/samsungtv</font> defaults host 10.0.0.31, "
        "port 8002, token <font face='Courier'>~/.config/indianadell/samsungtv.token</font>. "
        "First run: Allow on the TV. Opt out <font face='Courier'>SKIP_SAMSUNGTV=1</font>. "
        "REST is not a remote: GET/POST/DELETE/PUT applications/{id} only.",
        st["body"],
    ))
    story.append(Paragraph(
        "samsungtv device-info<br/>"
        "samsungtv home<br/>"
        "samsungtv app-run 111299001912<br/>"
        "samsungtv send-key KEY_SOURCE",
        st["code"],
    ))
    story.append(Paragraph("UPnP absolute volume (Alexa-equivalent, local)", st["h2"]))
    story.append(Paragraph(
        "No pairing. POST <font face='Courier'>http://10.0.0.31:9197/upnp/control/RenderingControl1</font> "
        "SOAPAction <font face='Courier'>…RenderingControl:1#SetVolume</font> with "
        "<font face='Courier'>&lt;DesiredVolume&gt;13&lt;/DesiredVolume&gt;</font>. "
        "GetVolume / GetMute / SetMute on the same service. "
        "Phone: YAACC (F-Droid) or BubbleUPnP — volume and cast, not HDMI/Home.",
        st["body"],
    ))
    story.append(Paragraph("SmartThings / Alexa", st["h2"]))
    story.append(Paragraph(
        "“Alexa, set Dave's TV to 13” → Alexa.Speaker SetVolume → "
        "ST <font face='Courier'>audioVolume.setVolume([13])</font>. "
        "2017: Settings → General → Network → Expert Settings → "
        "<b>Power On with Mobile</b>. Not exercised live here.",
        st["body"],
    ))
    story.append(Paragraph("IR  ·  indiana-ir-send", st["h2"]))
    story.append(Paragraph(
        "Discrete HDMI1–4 and POWER ON/OFF (NEC E0E0…). WS has no KEY_VOL11 "
        "and no reliable KEY_HDMI2. Unmute = VOL+.",
        st["body"],
    ))
    story.append(Paragraph("Sideload / Smart Hub", st["h2"]))
    story.append(Paragraph(
        "Tizen 3 / Chromium 47. TizenBrew + TizenTube possible. Overscan / "
        "Moonlight WASM / Stremio Tizen 4 likely fail. APIs cannot rearrange "
        "promo tiles; use Settings ads toggles, remove TV Plus, Autorun Smart Hub off.",
        st["body"],
    ))
    story.append(Paragraph("Not verified", st["h2"]))
    story.append(Paragraph(
        "SmartThings live on this DUID; KEY_HDMI2 actually switching; "
        "32″ pages in the 24/28″ service SM; DDC/CI after OSD enable; "
        "WOL from full power-off.",
        st["body"],
    ))
    story.append(Paragraph(
        "Source: <font face='Courier'>docs/samsung-un32m4500.md</font>",
        st["small"],
    ))

    doc = SimpleDocTemplate(
        str(OUT),
        pagesize=landscape(letter),
        leftMargin=0.5 * inch,
        rightMargin=0.5 * inch,
        topMargin=0.45 * inch,
        bottomMargin=0.5 * inch,
        title="Samsung UN32M4500 — Lab control manual",
        author="IndianaDell",
    )
    doc.build(story, onFirstPage=footer, onLaterPages=footer)
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    build()
