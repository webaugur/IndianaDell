#!/usr/bin/env python3
"""Generate Plymouth animation frames from the extracted Dell BGRT logo.

Scene (top → bottom):
  1. Dell logo with soft breathing scale + rotating ring-orbit highlight
  2. Little wizard (bottom) waving a magic wand
  3. Fixed Cherokee text ᏃᏫᏍ that sparkles in place (does not move)

Outputs:
  Themes/boot/generated/dell-animation/animation-XXXX.png
  Themes/boot/generated/dell-animation/throbber-XXXX.png  (same frames)
  Themes/boot/generated/dell-animation/preview.gif
  Themes/boot/generated/dell-animation/bgrt-fallback.png
"""
from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SRC = ROOT / "boot" / "extracted" / "bgrt-firmware-oem.png"
DEFAULT_OUT = ROOT / "boot" / "generated" / "dell-animation"
# User-supplied wizard art (preferred). Staging is only a convenience drop zone.
WIZARD_CANDIDATES = (
    ROOT / "boot" / "overlay" / "wizard-watermark.png",
    ROOT / "boot" / "overlay" / "wizard.png",
    ROOT / "boot" / "overlay" / "wizard-watermark.jpg",
    ROOT / "boot" / "overlay" / "wizard.jpg",
    ROOT / "boot" / "staging" / "indianadell" / "wizard-watermark.png",
    ROOT / "boot" / "staging" / "indianadell" / "wizard.png",
    ROOT / "boot" / "staging" / "indianadell" / "wizard-watermark.jpg",
)

FRAME_COUNT = 60
# Tall canvas so logo (upper) + wizard/text (lower) share one Plymouth sprite
CANVAS_W = 520
CANVAS_H = 700

MAGIC_TEXT = "ᏃᏫᏍ"
CHEROKEE_FONT_CANDIDATES = (
    "/usr/share/fonts/truetype/noto/NotoSansCherokee-Regular.ttf",
    "/usr/share/fonts/truetype/noto/NotoSansCherokee-Bold.ttf",
    "/usr/share/fonts/truetype/freefont/FreeSans.ttf",
)


def load_logo(path: Path) -> Image.Image:
    """Load BGRT logo and convert solid black bg to transparent."""
    im = Image.open(path).convert("RGBA")
    arr = np.array(im)
    rgb = arr[:, :, :3].astype(np.float32)
    lum = 0.299 * rgb[:, :, 0] + 0.587 * rgb[:, :, 1] + 0.114 * rgb[:, :, 2]
    alpha = np.clip(lum / 18.0, 0.0, 1.0)
    alpha = np.where(lum < 8, 0.0, alpha)
    out = np.zeros_like(arr)
    out[:, :, 0] = 255
    out[:, :, 1] = 255
    out[:, :, 2] = 255
    out[:, :, 3] = (np.clip(alpha, 0.0, 1.0) * 255).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def ring_mask(h: int, w: int, cx: float, cy: float, r_outer: float, r_inner: float, softness: float = 1.8) -> np.ndarray:
    yy, xx = np.mgrid[0:h, 0:w]
    r = np.sqrt((yy - cy) ** 2 + (xx - cx) ** 2)
    outer = 1.0 / (1.0 + np.exp((r - r_outer) / softness))
    inner = 1.0 / (1.0 + np.exp((r_inner - r) / softness))
    return np.clip(outer * inner, 0.0, 1.0)


def angular_highlight(
    h: int,
    w: int,
    cx: float,
    cy: float,
    angle_deg: float,
    arc_width_deg: float = 70.0,
    falloff: float = 28.0,
) -> np.ndarray:
    yy, xx = np.mgrid[0:h, 0:w]
    ang = np.degrees(np.arctan2(-(yy - cy), (xx - cx)))
    d = (ang - angle_deg + 180.0) % 360.0 - 180.0
    half = arc_width_deg / 2.0
    weight = np.clip(1.0 - (np.abs(d) / half), 0.0, 1.0) ** 1.4
    weight = weight * np.exp(-0.5 * (d / falloff) ** 2)
    return np.clip(weight, 0.0, 1.0)


def find_cherokee_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for path in CHEROKEE_FONT_CANDIDATES:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


# ---------------------------------------------------------------------------
# Wizard sprite — custom art (overlay/) preferred, procedural fallback
# ---------------------------------------------------------------------------

def _aa_ellipse(draw: ImageDraw.ImageDraw, box, fill, outline=None, width=1) -> None:
    draw.ellipse(box, fill=fill, outline=outline, width=width)


def find_wizard_path(explicit: Path | None = None) -> Path | None:
    if explicit is not None and explicit.is_file():
        return explicit
    for p in WIZARD_CANDIDATES:
        if p.is_file():
            return p
    return None


def load_wizard_sprite(path: Path) -> tuple[Image.Image, tuple[float, float]]:
    """Load user wizard art; knock out near-white bg; return (sprite, wand_tip_xy)."""
    im = Image.open(path).convert("RGBA")
    arr = np.array(im).astype(np.float32)
    rgb = arr[:, :, :3]
    # If almost fully opaque (flat white/paper bg), build soft alpha from distance-to-white
    if float(arr[:, :, 3].mean()) > 250:
        dist = np.linalg.norm(rgb - 255.0, axis=2)
        arr[:, :, 3] = np.clip((dist - 12.0) / 30.0, 0.0, 1.0) * 255.0

    alpha = arr[:, :, 3]
    # Tight crop to opaque content
    ys, xs = np.where(alpha > 16)
    if len(xs) == 0:
        return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA"), (
            arr.shape[1] * 0.75,
            arr.shape[0] * 0.2,
        )
    pad = 2
    x0 = max(0, int(xs.min()) - pad)
    y0 = max(0, int(ys.min()) - pad)
    x1 = min(arr.shape[1], int(xs.max()) + 1 + pad)
    y1 = min(arr.shape[0], int(ys.max()) + 1 + pad)
    crop = arr[y0:y1, x0:x1].copy()

    # Wand tip: brightest pink / white spark in the cropped sprite
    crgb = crop[:, :, :3]
    ca = crop[:, :, 3]
    lum = 0.299 * crgb[:, :, 0] + 0.587 * crgb[:, :, 1] + 0.114 * crgb[:, :, 2]
    pink = (crgb[:, :, 0] + crgb[:, :, 2]) - 1.2 * crgb[:, :, 1]
    spark = np.where(ca > 40, lum + 0.8 * np.clip(pink, 0, None), 0.0)
    spark = np.where((ca > 40) & (lum > 220), spark + 80.0, spark)
    if float(spark.max()) > 0:
        # Prefer upper half of sprite (wand is raised)
        upper = spark.copy()
        upper[int(upper.shape[0] * 0.55) :, :] = 0
        use = upper if float(upper.max()) > 0 else spark
        ty, tx = np.unravel_index(int(use.argmax()), use.shape)
        tip = (float(tx), float(ty))
    else:
        tip = (crop.shape[1] * 0.75, crop.shape[0] * 0.18)

    sprite = Image.fromarray(np.clip(crop, 0, 255).astype(np.uint8), "RGBA")
    return sprite, tip


def draw_wizard_custom(
    sprite: Image.Image,
    tip_xy: tuple[float, float],
    target_h: int = 200,
) -> tuple[Image.Image, tuple[float, float]]:
    """Place custom wizard FIXED in place (no bob/rotate). Sparkles use wand tip."""
    sw, sh = sprite.size
    scale = target_h / max(1, sh)
    nw, nh = max(1, int(sw * scale)), max(1, int(sh * scale))
    base = sprite.resize((nw, nh), Image.Resampling.LANCZOS)
    tip = (tip_xy[0] * scale, tip_xy[1] * scale)
    return base, tip


def draw_wizard_procedural(wand_angle_deg: float, scale: float = 1.0) -> tuple[Image.Image, tuple[float, float]]:
    """Built-in line-art wizard (fallback only)."""
    W, H = 160, 200
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    white = (255, 255, 255, 255)
    soft = (230, 235, 255, 230)
    dim = (200, 210, 230, 200)
    star = (255, 250, 200, 255)
    d.ellipse([48, 178, 112, 194], fill=(255, 255, 255, 28))
    d.polygon([(80, 78), (38, 175), (122, 175)], fill=(245, 248, 255, 235))
    d.rounded_rectangle([55, 118, 105, 128], radius=3, fill=white)
    d.rounded_rectangle([52, 168, 72, 182], radius=4, fill=white)
    d.rounded_rectangle([88, 168, 108, 182], radius=4, fill=white)
    _aa_ellipse(d, [62, 48, 98, 88], fill=soft)
    d.ellipse([70, 64, 76, 72], fill=(40, 50, 80, 255))
    d.ellipse([84, 64, 90, 72], fill=(40, 50, 80, 255))
    d.polygon([(52, 62), (80, 8), (108, 62)], fill=white)
    d.ellipse([48, 56, 112, 72], fill=soft)
    shoulder = (108, 96)
    ang = math.radians(wand_angle_deg)
    ex = shoulder[0] + 34 * math.cos(ang)
    ey = shoulder[1] + 34 * math.sin(ang)
    tip_ang = ang - math.radians(18)
    sx = ex + 48 * math.cos(tip_ang)
    sy = ey + 48 * math.sin(tip_ang)
    d.line([shoulder, (ex, ey)], fill=dim, width=5)
    d.ellipse([ex - 6, ey - 6, ex + 6, ey + 6], fill=soft)
    d.line([(ex, ey), (sx, sy)], fill=(220, 200, 140, 255), width=3)
    star_pts = []
    for i in range(10):
        r = 9 if i % 2 == 0 else 4
        a = math.radians(-90 + i * 36)
        star_pts.append((sx + r * math.cos(a), sy + r * math.sin(a)))
    d.polygon(star_pts, fill=star)
    if scale != 1.0:
        nw, nh = int(W * scale), int(H * scale)
        im = im.resize((nw, nh), Image.Resampling.LANCZOS)
    return im, (sx * scale, sy * scale)


def draw_wizard(
    wand_angle_deg: float = -40.0,
    scale: float = 1.0,
    custom_sprite: Image.Image | None = None,
    custom_tip: tuple[float, float] | None = None,
    target_h: int = 200,
) -> tuple[Image.Image, tuple[float, float]]:
    """Return (sprite, magic_tip_local). Custom art is fixed in place."""
    if custom_sprite is not None:
        tip = custom_tip if custom_tip is not None else (
            custom_sprite.size[0] * 0.75,
            custom_sprite.size[1] * 0.2,
        )
        return draw_wizard_custom(custom_sprite, tip, target_h=target_h)
    return draw_wizard_procedural(wand_angle_deg, scale=scale)



def sparkle_layer(
    width: int,
    height: int,
    text_bbox: tuple[int, int, int, int],
    frame_idx: int,
    n_frames: int,
    wand_tip: tuple[float, float] | None = None,
) -> Image.Image:
    """Twinkling stars around fixed text; denser near wand tip when casting."""
    layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    x0, y0, x1, y1 = text_bbox
    cx = (x0 + x1) / 2
    cy = (y0 + y1) / 2
    tw = max(1, x1 - x0)
    th = max(1, y1 - y0)

    # Fixed sparkle anchors around the glyph box (positions never move)
    n = 36
    anchors = []
    for i in range(n):
        a = 2 * math.pi * i / n + 0.4 * math.sin(i * 1.7)
        rx = tw * 0.68 + 22 * math.sin(i * 2.3)
        ry = th * 1.05 + 16 * math.cos(i * 1.9)
        px = cx + rx * math.cos(a)
        py = cy + ry * math.sin(a) * 0.78
        size = 2.0 + (i % 4) * 1.1
        phase = (i * 0.37) % 1.0
        anchors.append((px, py, size, phase))

    # Extra anchors along each character (deterministic grid in text box)
    for i in range(16):
        px = x0 + tw * ((i + 0.5) / 16)
        py = y0 + th * (0.15 + 0.7 * ((i * 3) % 5) / 4)
        anchors.append((px, py, 2.2 + (i % 3) * 0.7, (i * 0.19) % 1.0))

    t = frame_idx / n_frames
    for px, py, size, phase in anchors:
        # Twinkle envelope
        twinkle = 0.5 + 0.5 * math.sin(2 * math.pi * (t * 2.5 + phase))
        twinkle *= 0.55 + 0.45 * math.sin(2 * math.pi * (t * 5.0 + phase * 3))
        # Wand proximity boost: sparkles intensify as magic reaches the text
        boost = 0.0
        if wand_tip is not None:
            dist = math.hypot(px - wand_tip[0], py - wand_tip[1])
            boost = max(0.0, 1.0 - dist / 180.0) ** 1.3
        alpha = int(255 * min(1.0, 0.35 + 0.55 * twinkle + 0.65 * boost))
        if alpha < 18:
            continue
        s = size * (0.75 + 0.65 * twinkle + 0.45 * boost)
        col = (255, 250, 220, alpha)
        col2 = (180, 220, 255, max(0, alpha // 2))
        draw.line([(px - s * 2.4, py), (px + s * 2.4, py)], fill=col, width=max(1, int(s * 0.75)))
        draw.line([(px, py - s * 2.4), (px, py + s * 2.4)], fill=col, width=max(1, int(s * 0.75)))
        draw.line([(px - s, py - s), (px + s, py + s)], fill=col2, width=1)
        draw.line([(px - s, py + s), (px + s, py - s)], fill=col2, width=1)
        draw.ellipse([px - s * 0.45, py - s * 0.45, px + s * 0.45, py + s * 0.45], fill=col)

    # Magic stream: sparkles travel from fixed wand tip → Cherokee text
    if wand_tip is not None:
        n_stream = 22
        for i in range(n_stream):
            # Particles cycle along the path (wand → text)
            u = (t * 1.6 + i / n_stream) % 1.0
            # Slight arc from wand tip to text center
            mx = wand_tip[0] * (1 - u) + cx * u
            my = wand_tip[1] * (1 - u) + cy * u - 28 * math.sin(math.pi * u)
            # Perpendicular jitter (deterministic)
            jx = 4.0 * math.sin(i * 2.7 + t * 8)
            jy = 3.0 * math.cos(i * 1.9 + t * 7)
            mx += jx
            my += jy
            pulse = 0.55 + 0.45 * math.sin(2 * math.pi * (t * 4 + i * 0.17))
            # Brighter near ends (wand cast + text hit)
            edge = 0.55 + 0.45 * (1.0 - abs(2 * u - 1.0))
            a = int(230 * pulse * edge)
            if a < 28:
                continue
            r = 1.4 + 2.2 * pulse * (1.1 - 0.4 * u)
            # Pink/gold like the wand starburst in the art
            col = (
                255,
                int(200 + 40 * (1 - u)),
                int(230 + 25 * u),
                a,
            )
            draw.ellipse([mx - r, my - r, mx + r, my + r], fill=col)
            # Tiny cross sparkle every few particles
            if i % 3 == 0:
                s = 2.0 + 1.5 * pulse
                draw.line([(mx - s * 1.8, my), (mx + s * 1.8, my)], fill=col, width=1)
                draw.line([(mx, my - s * 1.8), (mx, my + s * 1.8)], fill=col, width=1)

    # Soft bloom
    bloom = layer.filter(ImageFilter.GaussianBlur(1.5))
    return Image.alpha_composite(bloom, layer)


def render_magic_text(font_size: int = 52) -> tuple[Image.Image, tuple[int, int, int, int]]:
    """Render fixed ᏃᏫᏍ with a soft glow. Returns image and tight bbox in that image."""
    font = find_cherokee_font(font_size)
    # Measure
    probe = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    pd = ImageDraw.Draw(probe)
    bbox = pd.textbbox((0, 0), MAGIC_TEXT, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    pad = 28
    im = Image.new("RGBA", (tw + pad * 2, th + pad * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    origin = (pad - bbox[0], pad - bbox[1])
    # Soft white glow under text
    glow = Image.new("RGBA", im.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.text(origin, MAGIC_TEXT, font=font, fill=(200, 220, 255, 180))
    glow = glow.filter(ImageFilter.GaussianBlur(6))
    im = Image.alpha_composite(im, glow)
    d = ImageDraw.Draw(im)
    d.text(origin, MAGIC_TEXT, font=font, fill=(255, 255, 255, 255))
    # Actual ink bbox inside im
    ink = (pad, pad, pad + tw, pad + th)
    return im, ink


def draw_logo_layer(
    logo: Image.Image,
    frame_idx: int,
    n_frames: int,
    box_w: int,
    box_h: int,
) -> Image.Image:
    """Dell ring-orbit in a box_w × box_h region (transparent outside logo)."""
    t = frame_idx / n_frames
    pulse = 0.5 + 0.5 * math.sin(2 * math.pi * t)
    scale = 0.94 + 0.06 * pulse
    logo_opacity = 0.82 + 0.18 * pulse
    angle = -360.0 * t

    base = Image.new("RGBA", (box_w, box_h), (0, 0, 0, 0))
    lw, lh = logo.size
    fit = min(box_w / lw, box_h / lh) * 0.90
    target_w = int(lw * scale * fit)
    target_h = int(lh * scale * fit)
    scaled = logo.resize((target_w, target_h), Image.Resampling.LANCZOS)

    ambient = scaled.copy()
    alpha = np.array(ambient.split()[-1]).astype(np.float32)
    alpha = (alpha * logo_opacity).astype(np.uint8)
    ambient.putalpha(Image.fromarray(alpha, "L"))

    ax = (box_w - target_w) // 2
    ay = (box_h - target_h) // 2

    glow = ambient.filter(ImageFilter.GaussianBlur(radius=10 + 6 * pulse))
    glow_arr = np.array(glow).astype(np.float32)
    glow_arr[:, :, 3] *= 0.22 + 0.18 * pulse
    glow = Image.fromarray(np.clip(glow_arr, 0, 255).astype(np.uint8), "RGBA")
    base.alpha_composite(glow, (ax, ay))
    base.alpha_composite(ambient, (ax, ay))

    # Ring highlight in full-box coordinates
    cx = box_w / 2.0
    cy = box_h / 2.0
    r_mid = (min(target_w, target_h) / 2.0) * (145.1 / 152.0)
    r_outer = r_mid + 8.0
    r_inner = r_mid - 8.0
    ring = ring_mask(box_h, box_w, cx, cy, r_outer, r_inner, softness=1.6)
    highlight = angular_highlight(box_h, box_w, cx, cy, angle, arc_width_deg=78.0, falloff=32.0)
    trail = angular_highlight(box_h, box_w, cx, cy, angle + 28.0, arc_width_deg=120.0, falloff=50.0)
    tip = angular_highlight(box_h, box_w, cx, cy, angle - 8.0, arc_width_deg=28.0, falloff=12.0)
    intensity = np.clip(ring * (0.35 * trail + 0.95 * highlight) + ring * tip * 0.85, 0.0, 1.0)

    layer = np.zeros((box_h, box_w, 4), dtype=np.float32)
    layer[:, :, 0] = 230 + 25 * tip
    layer[:, :, 1] = 240 + 15 * tip
    layer[:, :, 2] = 255
    layer[:, :, 3] = intensity * 255.0
    hi_img = Image.fromarray(np.clip(layer, 0, 255).astype(np.uint8), "RGBA")
    hi_img = hi_img.filter(ImageFilter.GaussianBlur(radius=1.2))
    base.alpha_composite(hi_img)
    bloom = hi_img.filter(ImageFilter.GaussianBlur(radius=8))
    bloom_a = np.array(bloom).astype(np.float32)
    bloom_a[:, :, 3] *= 0.45
    base.alpha_composite(Image.fromarray(np.clip(bloom_a, 0, 255).astype(np.uint8), "RGBA"))
    return base


def composite_frame(
    logo: Image.Image,
    frame_idx: int,
    n_frames: int,
    canvas_w: int = CANVAS_W,
    canvas_h: int = CANVAS_H,
    text_img: Image.Image | None = None,
    text_ink: tuple[int, int, int, int] | None = None,
    wizard_sprite: Image.Image | None = None,
    wizard_tip: tuple[float, float] | None = None,
) -> Image.Image:
    """Full boot scene: Dell logo (top) + fixed wizard + sparkling text (bottom)."""
    t = frame_idx / n_frames
    out = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 255))

    # --- Upper: Dell logo ---
    logo_h = int(canvas_h * 0.52)
    logo_layer = draw_logo_layer(logo, frame_idx, n_frames, canvas_w, logo_h)
    out.alpha_composite(logo_layer, (0, 12))

    # --- Lower stage: wizard + fixed sparkling text (centered as a group) ---
    stage_top = int(canvas_h * 0.55)

    if text_img is None or text_ink is None:
        text_img, text_ink = render_magic_text(58)
    tw, th = text_img.size

    # Wizard is FIXED in place; only sparkles animate from wand → text
    wizard, tip_local = draw_wizard(
        custom_sprite=wizard_sprite,
        custom_tip=wizard_tip,
        target_h=200,
    )
    ww, wh = wizard.size

    # Layout: [wizard][gap][text] centered as one unit — both fixed every frame
    gap = 10
    group_w = ww + gap + tw
    group_x = (canvas_w - group_w) // 2
    wiz_x = group_x
    wiz_y = stage_top + 4
    text_x = group_x + ww + gap
    # Align text roughly with mid torso / wand height of the fixed wizard
    text_y = stage_top + max(36, int(wh * 0.38))

    ink_abs = (
        text_x + text_ink[0],
        text_y + text_ink[1],
        text_x + text_ink[2],
        text_y + text_ink[3],
    )

    out.alpha_composite(wizard, (wiz_x, wiz_y))
    wand_tip_abs = (wiz_x + tip_local[0], wiz_y + tip_local[1])

    # Glyphs stay put; only brightness shimmers (sparkle layer does the rest)
    shimmer = 0.90 + 0.10 * (0.5 + 0.5 * math.sin(2 * math.pi * (t * 2.0)))
    text_draw = text_img.copy()
    ta = np.array(text_draw).astype(np.float32)
    ta[:, :, 3] *= shimmer
    text_draw = Image.fromarray(np.clip(ta, 0, 255).astype(np.uint8), "RGBA")
    out.alpha_composite(text_draw, (text_x, text_y))

    sparks = sparkle_layer(
        canvas_w,
        canvas_h,
        ink_abs,
        frame_idx,
        n_frames,
        wand_tip=wand_tip_abs,
    )
    out.alpha_composite(sparks)

    return out.convert("RGBA")


def write_frames(
    logo: Image.Image,
    out_dir: Path,
    n_frames: int = FRAME_COUNT,
    canvas_w: int = CANVAS_W,
    canvas_h: int = CANVAS_H,
    wizard_sprite: Image.Image | None = None,
    wizard_tip: tuple[float, float] | None = None,
) -> list[Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    for p in out_dir.glob("animation-*.png"):
        p.unlink()
    for p in out_dir.glob("throbber-*.png"):
        p.unlink()

    text_img, text_ink = render_magic_text(58)
    # Verify glyphs rendered (not tofu boxes)
    arr = np.array(text_img)
    if arr[:, :, 3].sum() < 1000:
        print("WARNING: magic text may not have rendered (check Cherokee font)", file=sys.stderr)

    paths: list[Path] = []
    for i in range(n_frames):
        frame = composite_frame(
            logo, i, n_frames, canvas_w=canvas_w, canvas_h=canvas_h,
            text_img=text_img, text_ink=text_ink,
            wizard_sprite=wizard_sprite,
            wizard_tip=wizard_tip,
        )
        name = f"{i + 1:04d}"
        anim = out_dir / f"animation-{name}.png"
        throb = out_dir / f"throbber-{name}.png"
        frame.save(anim, optimize=True)
        frame.save(throb, optimize=True)
        paths.append(anim)
        if (i + 1) % 10 == 0 or i == 0:
            print(f"  frame {i + 1:02d}/{n_frames}")
    return paths


def write_preview_gif(frame_paths: list[Path], out_path: Path, duration_ms: int = 40) -> None:
    frames = [Image.open(p).convert("P", palette=Image.ADAPTIVE, colors=128) for p in frame_paths]
    frames[0].save(
        out_path,
        save_all=True,
        append_images=frames[1:],
        duration=duration_ms,
        loop=0,
        optimize=True,
    )


def write_fallback(logo: Image.Image, out_path: Path, size: int = 128) -> None:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 255))
    s = int(size * 0.9)
    scaled = logo.resize((s, s), Image.Resampling.LANCZOS)
    w, h = scaled.size
    canvas.alpha_composite(scaled, ((size - w) // 2, (size - h) // 2))
    canvas.save(out_path, optimize=True)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--src", type=Path, default=DEFAULT_SRC, help="Source Dell BGRT PNG")
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT, help="Output directory")
    ap.add_argument("--frames", type=int, default=FRAME_COUNT, help="Frame count (default 60)")
    ap.add_argument("--width", type=int, default=CANVAS_W, help=f"Canvas width (default {CANVAS_W})")
    ap.add_argument("--height", type=int, default=CANVAS_H, help=f"Canvas height (default {CANVAS_H})")
    ap.add_argument(
        "--wizard",
        type=Path,
        default=None,
        help="Custom wizard image (default: boot/overlay/wizard.png or wizard-watermark.jpg)",
    )
    ap.add_argument(
        "--procedural-wizard",
        action="store_true",
        help="Force built-in line-art wizard instead of overlay art",
    )
    args = ap.parse_args()

    if not args.src.is_file():
        print(f"ERROR: source logo not found: {args.src}", file=sys.stderr)
        print("Run: bin/themes-extract", file=sys.stderr)
        return 1

    print(f"Source: {args.src}")
    print(f"Output: {args.out}")
    print(f"Scene: Dell logo + wizard + sparkling {MAGIC_TEXT!r}")
    logo = load_logo(args.src)
    print(f"Logo size: {logo.size}")
    print(f"Canvas: {args.width}×{args.height}")

    wizard_sprite = None
    wizard_tip = None
    if not args.procedural_wizard:
        wiz_path = find_wizard_path(args.wizard)
        if wiz_path is not None:
            wizard_sprite, wizard_tip = load_wizard_sprite(wiz_path)
            # Keep normalized transparent PNG in overlay for reuse / preview
            overlay_png = ROOT / "boot" / "overlay" / "wizard.png"
            try:
                overlay_png.parent.mkdir(parents=True, exist_ok=True)
                wizard_sprite.save(overlay_png)
            except OSError:
                pass
            print(
                f"Wizard: FIXED custom art from {wiz_path} "
                f"({wizard_sprite.size[0]}×{wizard_sprite.size[1]}) "
                f"wand_tip=({wizard_tip[0]:.0f},{wizard_tip[1]:.0f})"
            )
        else:
            print("Wizard: procedural (no overlay wizard art found)")
    else:
        print("Wizard: procedural (--procedural-wizard)")

    paths = write_frames(
        logo, args.out, n_frames=args.frames,
        canvas_w=args.width, canvas_h=args.height,
        wizard_sprite=wizard_sprite,
        wizard_tip=wizard_tip,
    )
    preview = args.out / "preview.gif"
    write_preview_gif(paths, preview)
    write_fallback(logo, args.out / "bgrt-fallback.png")

    bg = Image.new("RGB", (1920, 1080), (0, 0, 0))
    bg.save(args.out / "background.png")

    # Also export a static watermark-sized strip of the text for optional use
    text_img, _ = render_magic_text(40)
    text_img.save(args.out / "magic-text.png")

    print(f"Wrote {len(paths)} animation + throbber frames")
    print(f"Preview: {preview}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
