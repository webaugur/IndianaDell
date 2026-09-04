#!/usr/bin/env python3
"""Render ir-blaster-schematic.png (IR LED + NPN, RGB, keypad)."""
from pathlib import Path

import matplotlib.pyplot as plt
from matplotlib.patches import Circle, FancyBboxPatch, Polygon, Rectangle

OUT = Path(__file__).resolve().parent / "ir-blaster-schematic.png"


def wire(ax, pts):
    xs, ys = zip(*pts)
    ax.plot(xs, ys, color="#1a1a1a", lw=2.2, solid_capstyle="round", zorder=2)


def node(ax, x, y):
    ax.add_patch(Circle((x, y), 0.07, fc="#1a1a1a", zorder=5))


def label(ax, x, y, text, **kw):
    kw.setdefault("fontsize", 11)
    kw.setdefault("fontfamily", "DejaVu Sans")
    kw.setdefault("color", "#111")
    ax.text(x, y, text, **kw)


def zigzag(ax, x, y, n=5, w=1.45):
    xs, ys = [x, x + 0.15], [y, y]
    step = (w - 0.3) / n
    for i in range(n):
        xs.append(x + 0.15 + step * (i + 0.5))
        ys.append(y + (0.2 if i % 2 == 0 else -0.2))
    xs += [x + w - 0.15, x + w]
    ys += [y, y]
    ax.plot(xs, ys, color="#1a1a1a", lw=2.2)


def pin(ax, x, y, name, col):
    ax.add_patch(FancyBboxPatch((x - 0.4, y - 0.28), 1.55, 0.56, boxstyle="round,pad=0.02", fc=col, ec="none"))
    label(ax, x + 0.38, y, name, ha="center", va="center", color="white", fontsize=12, fontweight="bold")
    return x + 1.15, y


def main():
    fig, ax = plt.subplots(figsize=(17.2, 10.4), dpi=140)
    ax.set_xlim(0, 17.2)
    ax.set_ylim(0, 10.4)
    ax.set_aspect("equal")
    ax.axis("off")
    fig.patch.set_facecolor("#f4f1ea")
    ax.set_facecolor("#f4f1ea")

    ax.add_patch(
        FancyBboxPatch(
            (0.35, 0.85),
            3.35,
            8.55,
            boxstyle="round,pad=0.04,rounding_size=0.12",
            facecolor="#1b6b4a",
            edgecolor="#0d3d2a",
            lw=2,
        )
    )
    label(ax, 2.02, 9.05, "Arduino Uno", ha="center", va="center", color="white", fontsize=14, fontweight="bold")
    label(ax, 2.02, 8.68, "ATmega328P", ha="center", va="center", color="#d4f5e6", fontsize=9)

    p5v = pin(ax, 1.05, 8.05, "5V", "#c0392b")
    pd3 = pin(ax, 1.05, 7.15, "D3", "#f39c12")
    pgnd = pin(ax, 1.05, 6.25, "GND", "#2c3e50")
    pd2 = pin(ax, 1.05, 5.40, "D2", "#8e44ad")
    pr = pin(ax, 1.05, 4.55, "D12", "#c0392b")
    pg = pin(ax, 1.05, 3.65, "D13", "#1e8449")
    pb = pin(ax, 1.05, 2.85, "A0", "#2471a3")
    pa1 = pin(ax, 1.05, 2.05, "A1", "#8e44ad")
    pa2 = pin(ax, 1.05, 1.25, "A2", "#8e44ad")
    for p in (p5v, pd3, pgnd, pd2, pr, pg, pb, pa1, pa2):
        node(ax, p[0], p[1])
    label(ax, 2.02, 4.95, "enc CLK", ha="center", color="#e8d5f5", fontsize=8)

    # --- IR: 100Ω, LED, NPN ---
    zigzag(ax, 4.4, 8.05)
    label(ax, 5.12, 8.52, "100 Ω", ha="center", fontsize=12, fontweight="bold")
    zigzag(ax, 4.4, 7.15)
    label(ax, 5.12, 7.62, "1 kΩ", ha="center", fontsize=12, fontweight="bold")
    label(ax, 5.12, 6.72, "base", ha="center", fontsize=9, color="#444")

    tx, ty = 7.85, 7.15
    ax.add_patch(Circle((tx, ty), 0.68, fc="#ece6d8", ec="#1a1a1a", lw=2))
    ax.plot([tx - 0.32, tx + 0.12], [ty, ty], color="#1a1a1a", lw=2)
    ax.plot([tx + 0.12, tx + 0.4], [ty, ty + 0.5], color="#1a1a1a", lw=2)
    ax.plot([tx + 0.12, tx + 0.4], [ty, ty - 0.5], color="#1a1a1a", lw=2)
    ax.annotate(
        "",
        xy=(tx + 0.4, ty - 0.5),
        xytext=(tx + 0.2, ty - 0.2),
        arrowprops=dict(arrowstyle="->", color="#1a1a1a", lw=1.8),
    )
    label(ax, tx, ty - 0.98, "2N2222 / 2N3904", ha="center", fontsize=10, fontweight="bold")
    label(ax, tx - 0.9, ty + 0.02, "B", fontsize=10, color="#555")
    label(ax, tx + 0.52, ty + 0.62, "C", fontsize=10, color="#555")
    label(ax, tx + 0.52, ty - 0.7, "E", fontsize=10, color="#555")

    lx, ly = 7.85, 8.05
    ax.add_patch(Circle((lx - 0.26, ly), 0.2, fc="#f7d6d6", ec="#1a1a1a", lw=1.5))
    ax.plot([lx - 0.08, lx + 0.26], [ly + 0.26, ly], color="#1a1a1a", lw=2)
    ax.plot([lx - 0.08, lx + 0.26], [ly - 0.26, ly], color="#1a1a1a", lw=2)
    ax.plot([lx + 0.26, lx + 0.26], [ly - 0.3, ly + 0.3], color="#1a1a1a", lw=2)
    ax.annotate("", xy=(lx + 1.05, ly + 0.5), xytext=(lx + 0.42, ly + 0.16),
                arrowprops=dict(arrowstyle="->", color="#8e1b1b", lw=1.6))
    ax.annotate("", xy=(lx + 1.05, ly + 0.18), xytext=(lx + 0.42, ly - 0.06),
                arrowprops=dict(arrowstyle="->", color="#8e1b1b", lw=1.6))
    label(ax, lx + 1.15, ly + 0.42, "IR 940 nm", fontsize=11, fontweight="bold", color="#8e1b1b")

    wire(ax, [(p5v[0], p5v[1]), (4.4, 8.05)])
    wire(ax, [(5.85, 8.05), (7.59, 8.05)])
    wire(ax, [(8.11, 8.05), (8.7, 8.05), (8.7, 7.65), (tx + 0.4, ty + 0.5)])
    wire(ax, [(pd3[0], pd3[1]), (4.4, 7.15)])
    wire(ax, [(5.85, 7.15), (tx - 0.68, 7.15)])
    wire(ax, [(tx + 0.4, ty - 0.5), (tx + 0.4, 6.25), (pgnd[0], pgnd[1])])

    # --- RGB common-cathode, one 220Ω ---
    label(ax, 6.4, 5.05, "RGB  (common cathode default)", ha="center", fontsize=11, fontweight="bold")
    colors = [
        (4.55, "#c0392b", "R"),
        (5.55, "#1e8449", "G"),
        (6.55, "#2471a3", "B"),
    ]
    for x, col, name in colors:
        ax.add_patch(Circle((x, 4.15), 0.22, fc=col, ec="#1a1a1a", lw=1.4, alpha=0.85))
        ax.plot([x - 0.18, x + 0.18], [4.0, 3.72], color="#1a1a1a", lw=1.8)
        ax.plot([x + 0.18, x - 0.18], [4.0, 3.72], color="#1a1a1a", lw=1.8)
        ax.plot([x - 0.22, x + 0.22], [3.72, 3.72], color="#1a1a1a", lw=1.8)
        label(ax, x, 4.55, name, ha="center", fontsize=11, fontweight="bold", color=col)
    # anodes up to pins
    wire(ax, [(pr[0], pr[1]), (4.55, 4.55), (4.55, 4.37)])
    wire(ax, [(pg[0], pg[1]), (3.7, 3.65), (5.55, 3.65), (5.55, 4.37)])
    node(ax, 3.7, 3.65)
    wire(ax, [(pb[0], pb[1]), (3.7, 2.75), (6.55, 2.75), (6.55, 3.72)])
    node(ax, 3.7, 2.75)
    # common cathode bus
    wire(ax, [(4.55, 3.72), (4.55, 3.35), (6.55, 3.35), (6.55, 3.72)])
    zigzag(ax, 6.7, 3.35, w=1.2)
    label(ax, 7.3, 3.78, "220 Ω", ha="center", fontsize=11, fontweight="bold")
    wire(ax, [(7.9, 3.35), (8.55, 3.35), (8.55, 6.25)])
    node(ax, 8.55, 6.25)
    label(ax, 6.4, 2.48, "common cathode → GND", ha="center", fontsize=8, color="#444")

    # --- 5-pin rotary encoder ---
    ax.add_patch(FancyBboxPatch((3.85, 0.15), 6.7, 2.2, boxstyle="round,pad=0.04", fc="#fff", ec="#8e44ad", lw=1.6))
    label(ax, 7.2, 2.1, "5-pin encoder", ha="center", fontsize=11, fontweight="bold")
    enc_pins = [("C", "GND"), ("A CLK", "D2"), ("B DT", "A1"), ("SW1", "GND"), ("SW2", "A2")]
    for i, (top, bot) in enumerate(enc_pins):
        x = 4.2 + i * 1.22
        ax.add_patch(FancyBboxPatch((x, 1.15), 1.08, 0.72, boxstyle="round,pad=0.02", fc="#8e44ad", ec="none"))
        label(ax, x + 0.54, 1.62, top, ha="center", va="center", color="white", fontsize=7.5, fontweight="bold")
        label(ax, x + 0.54, 0.92, bot, ha="center", fontsize=8, color="#333")
    label(ax, 7.2, 0.38, "1 turn = 10% vol   click = mute   swap A/B if reversed", ha="center", fontsize=8, color="#444")
    wire(ax, [(pd2[0], pd2[1]), (3.55, 5.40), (3.55, 1.51), (4.2, 1.51)])
    wire(ax, [(pa1[0], pa1[1]), (5.42, 2.05), (5.42, 1.51)])
    wire(ax, [(pa2[0], pa2[1]), (7.86, 1.25), (7.86, 1.51)])
    wire(ax, [(pgnd[0], 6.25), (9.05, 6.25), (9.05, 0.55), (4.74, 0.55), (4.74, 0.92)])

    # Title
    label(ax, 8.6, 10.05, "indiana-blaster", ha="center", fontsize=18, fontweight="bold")
    label(ax, 8.6, 9.65, "Uno  ·  115200  ·  keypad + RGB + encoder + indiana-ir-send", ha="center", fontsize=11, color="#333")

    # Keypad
    ax.add_patch(FancyBboxPatch((10.85, 2.55), 5.9, 6.5, boxstyle="round,pad=0.05", fc="#fff", ec="#333", lw=1.4))
    label(ax, 13.8, 8.75, "4×4 keypad", ha="center", fontsize=13, fontweight="bold")
    label(ax, 13.8, 8.38, "rows D4–D7    cols D8–D11", ha="center", fontsize=9, color="#444")
    cells = [
        ("1", "2", "3", "A vol+/H1"),
        ("4", "5 OK", "6", "B mute/H2"),
        ("7", "8", "9", "C vol-/H3"),
        ("* DOT", "0", "# on/off", "D home/H4"),
    ]
    for r, row in enumerate(cells):
        for c, txt in enumerate(row):
            x = 11.1 + c * 1.35
            y = 7.45 - r * 0.95
            col = "#1b6b4a" if c == 3 or (r == 3 and c in (0, 2)) else "#2c3e50"
            ax.add_patch(FancyBboxPatch((x, y), 1.22, 0.78, boxstyle="round,pad=0.02", fc=col, ec="none"))
            label(ax, x + 0.61, y + 0.39, txt, ha="center", va="center", color="white", fontsize=8)

    label(ax, 13.8, 3.35, "hold 2/8/4/6 arrows   hold 5 OK", ha="center", fontsize=9, color="#333")
    label(ax, 13.8, 2.95, "hold A–D = HDMI   hold # = power off", ha="center", fontsize=9, color="#333")

    notes = (
        "IR: 940 nm via NPN, not from D3. RGB: one 220 Ω on common (CC as drawn).\n"
        "Encoder: C+SW1 to GND. A/CLK→D2  B/DT→A1  SW2→A2. 20 detents/turn, 10 VOL± = 10%."
    )
    ax.add_patch(FancyBboxPatch((10.85, 0.15), 5.9, 2.2, boxstyle="round,pad=0.05", fc="#fff", ec="#bbb", lw=1))
    ax.text(11.05, 2.15, notes, va="top", fontsize=9, fontfamily="DejaVu Sans", color="#222", linespacing=1.45)

    fig.tight_layout(pad=0.25)
    fig.savefig(OUT, dpi=140, facecolor=fig.get_facecolor())
    plt.close()
    print(OUT)


if __name__ == "__main__":
    main()
