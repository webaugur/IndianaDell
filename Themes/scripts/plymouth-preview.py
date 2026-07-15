#!/usr/bin/env python3
"""Windowed Plymouth two-step theme simulator (no root, no initramfs).

Approximates the stock Ubuntu two-step layout so you can judge scale,
alignment, watermark, and animation before installing a boot theme.

  bin/themes-preview-boot
  bin/themes-preview-boot --animated-dell
  bin/themes-preview-boot --theme Themes/boot/staging/indianadell
  bin/themes-preview-boot --width 1280 --height 720

Keys:
  Esc / q     Quit
  Space       Pause / resume
  F           Toggle fullscreen
  1           Boot animation mode
  2           Fake password-dialog layout
  R           Restage theme (if --animated-dell / default stage path)
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageTk

try:
    import tkinter as tk
except ImportError as e:  # pragma: no cover
    print("ERROR: tkinter is required for the preview window", file=sys.stderr)
    raise SystemExit(1) from e

ROOT = Path(__file__).resolve().parents[1]  # Themes/
REPO = ROOT.parent
DEFAULT_STAGE = ROOT / "boot" / "staging" / "indianadell"
DEFAULT_PLYMOUTH = ROOT / "boot" / "indianadell" / "indianadell.plymouth"
BGRT_PNG = ROOT / "boot" / "extracted" / "bgrt-firmware-oem.png"
STAGE_SCRIPT = ROOT / "scripts" / "install-boot-theme.sh"


def parse_color(value: str) -> tuple[int, int, int]:
    """Parse 0xRRGGBB or #RRGGBB to RGB tuple."""
    s = value.strip().lower()
    if s.startswith("0x"):
        s = s[2:]
    elif s.startswith("#"):
        s = s[1:]
    n = int(s, 16)
    return ((n >> 16) & 0xFF, (n >> 8) & 0xFF, n & 0xFF)


def parse_float(value: str, default: float) -> float:
    try:
        return float(value.strip())
    except (TypeError, ValueError):
        return default


def load_theme_config(theme_dir: Path) -> dict:
    """Load key settings from *.plymouth in theme_dir (or default template)."""
    plymouth_files = sorted(theme_dir.glob("*.plymouth"))
    path = plymouth_files[0] if plymouth_files else DEFAULT_PLYMOUTH
    text = path.read_text(encoding="utf-8", errors="replace")

    # configparser needs section headers; file already has them
    # Strip locale Name[xx]= lines that can confuse some parsers — keep simple regex map
    cfg: dict[str, str] = {}
    section = ""
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or line.startswith(";"):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            continue
        if "=" not in line:
            continue
        key, _, val = line.partition("=")
        key, val = key.strip(), val.strip()
        # Prefer [two-step] and mode sections; last write wins for duplicates
        cfg[key] = val
        cfg[f"{section}.{key}"] = val

    use_fw = cfg.get("boot-up.UseFirmwareBackground", cfg.get("UseFirmwareBackground", "true"))
    return {
        "path": path,
        "image_dir": Path(cfg.get("ImageDir", str(theme_dir))),
        "h_align": parse_float(cfg.get("HorizontalAlignment", "0.5"), 0.5),
        "v_align": parse_float(cfg.get("VerticalAlignment", "0.7"), 0.7),
        "wm_h": parse_float(cfg.get("WatermarkHorizontalAlignment", "0.5"), 0.5),
        "wm_v": parse_float(cfg.get("WatermarkVerticalAlignment", "0.96"), 0.96),
        "dlg_h": parse_float(cfg.get("DialogHorizontalAlignment", "0.5"), 0.5),
        "dlg_v": parse_float(cfg.get("DialogVerticalAlignment", "0.7"), 0.7),
        "bg_start": parse_color(cfg.get("BackgroundStartColor", "0x000000")),
        "bg_end": parse_color(cfg.get("BackgroundEndColor", "0x000000")),
        "use_firmware": use_fw.lower() in ("1", "true", "yes"),
        "font": cfg.get("Font", "Ubuntu 12"),
    }


def place(screen_w: int, screen_h: int, img_w: int, img_h: int, hx: float, hy: float) -> tuple[int, int]:
    """Plymouth-style fractional alignment (0=left/top, 0.5=center, 1=right/bottom)."""
    x = int((screen_w - img_w) * hx)
    y = int((screen_h - img_h) * hy)
    return x, y


def load_frames(theme_dir: Path) -> list[Image.Image]:
    """Load animation-*.png, falling back to throbber-*.png."""
    anim = sorted(theme_dir.glob("animation-*.png"))
    if not anim:
        anim = sorted(theme_dir.glob("throbber-*.png"))
    if not anim:
        raise FileNotFoundError(
            f"No animation-*.png or throbber-*.png in {theme_dir}\n"
            "Run: python3 Themes/scripts/generate-dell-animation.py\n"
            "  or: Themes/scripts/install-boot-theme.sh --stage-only --animated-dell"
        )
    return [Image.open(p).convert("RGBA") for p in anim]


def load_optional(theme_dir: Path, name: str) -> Image.Image | None:
    p = theme_dir / name
    if p.is_file():
        return Image.open(p).convert("RGBA")
    return None


def scale_bg(bg: Image.Image, w: int, h: int) -> Image.Image:
    """Cover-scale background to fill screen (center crop)."""
    bw, bh = bg.size
    scale = max(w / bw, h / bh)
    nw, nh = max(1, int(bw * scale)), max(1, int(bh * scale))
    resized = bg.resize((nw, nh), Image.Resampling.LANCZOS)
    x = (nw - w) // 2
    y = (nh - h) // 2
    return resized.crop((x, y, x + w, y + h)).convert("RGBA")


def try_font(size: int = 14) -> ImageFont.ImageFont:
    for path in (
        "/usr/share/fonts/truetype/ubuntu/Ubuntu-R.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/freefont/FreeSans.ttf",
    ):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def composite_frame(
    screen_w: int,
    screen_h: int,
    cfg: dict,
    frame: Image.Image,
    watermark: Image.Image | None,
    background: Image.Image | None,
    bgrt: Image.Image | None,
    mode: str,
    entry: Image.Image | None,
    lock: Image.Image | None,
    frame_index: int,
    n_frames: int,
    paused: bool,
) -> Image.Image:
    """Build one full-screen preview frame."""
    # Base fill
    r, g, b = cfg["bg_start"]
    canvas = Image.new("RGBA", (screen_w, screen_h), (r, g, b, 255))

    if background is not None:
        canvas.alpha_composite(scale_bg(background, screen_w, screen_h))

    # Faux UEFI BGRT (static OEM logo, roughly center — two-step places firmware image separately)
    if cfg["use_firmware"] and bgrt is not None:
        # Typical BGRT is centered; keep modest size like firmware 304×307
        bx, by = place(screen_w, screen_h, bgrt.width, bgrt.height, 0.5, 0.42)
        canvas.alpha_composite(bgrt, (bx, by))

    # Spinner / scene animation
    fw, fh = frame.size
    sx, sy = place(screen_w, screen_h, fw, fh, cfg["h_align"], cfg["v_align"])
    canvas.alpha_composite(frame, (sx, sy))

    # Watermark
    if watermark is not None:
        ww, wh = watermark.size
        wx, wy = place(screen_w, screen_h, ww, wh, cfg["wm_h"], cfg["wm_v"])
        canvas.alpha_composite(watermark, (wx, wy))

    # Fake password dialog mode
    if mode == "password":
        dlg = Image.new("RGBA", (screen_w, screen_h), (0, 0, 0, 0))
        draw = ImageDraw.Draw(dlg)
        # Dim overlay lightly
        dim = Image.new("RGBA", (screen_w, screen_h), (0, 0, 0, 100))
        canvas.alpha_composite(dim)

        entry_img = entry
        if entry_img is None:
            # Synthetic entry field
            entry_img = Image.new("RGBA", (320, 40), (40, 40, 40, 230))
            ed = ImageDraw.Draw(entry_img)
            ed.rectangle([0, 0, 319, 39], outline=(180, 180, 180, 255), width=1)
            ed.text((12, 10), "••••••••", font=try_font(16), fill=(220, 220, 220, 255))

        ew, eh = entry_img.size
        ex, ey = place(screen_w, screen_h, ew, eh, cfg["dlg_h"], cfg["dlg_v"])
        if lock is not None:
            lw, lh = lock.size
            canvas.alpha_composite(lock, (ex - lw - 12, ey + (eh - lh) // 2))
        canvas.alpha_composite(entry_img, (ex, ey))
        font = try_font(13)
        draw = ImageDraw.Draw(canvas)
        label = "Password:"
        draw.text((ex, ey - 22), label, font=font, fill=(230, 230, 230, 255))

    # HUD chrome (simulator only — not part of real Plymouth)
    hud = ImageDraw.Draw(canvas)
    font = try_font(12)
    status = "PAUSED" if paused else "PLAY"
    hud_text = (
        f"Plymouth preview  {screen_w}×{screen_h}  "
        f"frame {frame_index + 1}/{n_frames}  [{status}]  mode={mode}  "
        f"align=({cfg['h_align']:.2f},{cfg['v_align']:.2f})  "
        f"Esc quit · Space pause · F fullscreen · 1 boot · 2 password"
    )
    # Shadow
    hud.text((11, 11), hud_text, font=font, fill=(0, 0, 0, 180))
    hud.text((10, 10), hud_text, font=font, fill=(180, 200, 220, 220))

    return canvas


def stage_theme(animated_dell: bool, extra_args: list[str] | None = None) -> Path:
    """Run install script with --stage-only; return staged theme dir."""
    cmd = ["bash", str(STAGE_SCRIPT), "--stage-only"]
    if animated_dell:
        cmd.append("--animated-dell")
    if extra_args:
        cmd.extend(extra_args)
    print("Staging theme:", " ".join(cmd))
    subprocess.run(cmd, check=True)
    return DEFAULT_STAGE


class PreviewApp:
    def __init__(
        self,
        theme_dir: Path,
        width: int,
        height: int,
        fps: float,
        start_mode: str = "boot",
        animated_dell: bool = False,
    ) -> None:
        self.theme_dir = theme_dir
        self.screen_w = width
        self.screen_h = height
        self.fps = max(1.0, fps)
        self.mode = start_mode
        self.animated_dell = animated_dell
        self.paused = False
        self.fullscreen = False
        self.frame_i = 0
        self._load_assets()

        self.root = tk.Tk()
        self.root.title(f"Plymouth preview — {theme_dir.name}")
        self.root.configure(bg="#000000")
        self.root.geometry(f"{width}x{height}")
        self.label = tk.Label(self.root, bg="#000000", borderwidth=0)
        self.label.pack(fill=tk.BOTH, expand=True)

        self.root.bind("<Escape>", lambda e: self.root.destroy())
        self.root.bind("q", lambda e: self.root.destroy())
        self.root.bind("Q", lambda e: self.root.destroy())
        self.root.bind("<space>", self._toggle_pause)
        self.root.bind("f", self._toggle_fullscreen)
        self.root.bind("F", self._toggle_fullscreen)
        self.root.bind("1", lambda e: self._set_mode("boot"))
        self.root.bind("2", lambda e: self._set_mode("password"))
        self.root.bind("r", self._restage)
        self.root.bind("R", self._restage)
        self.root.protocol("WM_DELETE_WINDOW", self.root.destroy)

        self._photo: ImageTk.PhotoImage | None = None
        self._tick()

    def _load_assets(self) -> None:
        self.cfg = load_theme_config(self.theme_dir)
        # Prefer assets from theme_dir even if ImageDir points elsewhere
        asset_dir = self.theme_dir
        self.frames = load_frames(asset_dir)
        self.watermark = load_optional(asset_dir, "watermark.png")
        self.background = load_optional(asset_dir, "background.png")
        self.entry = load_optional(asset_dir, "entry.png")
        self.lock = load_optional(asset_dir, "lock.png")
        self.bgrt = None
        if self.cfg["use_firmware"] and BGRT_PNG.is_file():
            self.bgrt = Image.open(BGRT_PNG).convert("RGBA")
        print(
            f"Theme: {self.theme_dir}\n"
            f"  frames={len(self.frames)}  "
            f"align=({self.cfg['h_align']},{self.cfg['v_align']})  "
            f"firmware_bg={self.cfg['use_firmware']}  "
            f"watermark={'yes' if self.watermark else 'no'}"
        )

    def _set_mode(self, mode: str) -> None:
        self.mode = mode

    def _toggle_pause(self, _event=None) -> None:
        self.paused = not self.paused

    def _toggle_fullscreen(self, _event=None) -> None:
        self.fullscreen = not self.fullscreen
        self.root.attributes("-fullscreen", self.fullscreen)
        if not self.fullscreen:
            self.root.geometry(f"{self.screen_w}x{self.screen_h}")

    def _restage(self, _event=None) -> None:
        try:
            stage_theme(self.animated_dell)
            self.theme_dir = DEFAULT_STAGE
            self._load_assets()
            self.frame_i = 0
            print("Restaged OK")
        except subprocess.CalledProcessError as e:
            print(f"Restage failed: {e}", file=sys.stderr)

    def _current_size(self) -> tuple[int, int]:
        # Use actual widget size when available (window resize / fullscreen)
        w = self.label.winfo_width()
        h = self.label.winfo_height()
        if w < 64 or h < 64:
            return self.screen_w, self.screen_h
        return w, h

    def _render(self) -> None:
        w, h = self._current_size()
        frame = self.frames[self.frame_i % len(self.frames)]
        img = composite_frame(
            w,
            h,
            self.cfg,
            frame,
            self.watermark,
            self.background,
            self.bgrt,
            self.mode,
            self.entry,
            self.lock,
            self.frame_i % len(self.frames),
            len(self.frames),
            self.paused,
        )
        self._photo = ImageTk.PhotoImage(img)
        self.label.configure(image=self._photo)

    def _tick(self) -> None:
        self._render()
        if not self.paused:
            self.frame_i = (self.frame_i + 1) % len(self.frames)
        delay_ms = int(1000 / self.fps)
        self.root.after(delay_ms, self._tick)

    def run(self) -> None:
        self.root.mainloop()


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Safe windowed Plymouth two-step preview (no root, no install).",
    )
    ap.add_argument(
        "--theme",
        type=Path,
        default=None,
        help="Theme directory with .plymouth + animation frames",
    )
    ap.add_argument(
        "--animated-dell",
        action="store_true",
        help="Stage indianadell with animated Dell+wizard frames, then preview",
    )
    ap.add_argument(
        "--stage",
        action="store_true",
        help="Force re-stage default indianadell into boot/staging/ before preview",
    )
    ap.add_argument("--width", type=int, default=0, help="Window width (0=auto ~1280 or screen)")
    ap.add_argument("--height", type=int, default=0, help="Window height (0=auto ~720 or screen)")
    ap.add_argument("--fps", type=float, default=25.0, help="Animation FPS (default 25)")
    ap.add_argument(
        "--mode",
        choices=("boot", "password"),
        default="boot",
        help="Initial mode",
    )
    ap.add_argument(
        "--no-hud",
        action="store_true",
        help=argparse.SUPPRESS,  # reserved
    )
    args = ap.parse_args()

    animated = args.animated_dell
    theme: Path | None = args.theme

    def needs_stage(path: Path) -> bool:
        return not path.is_dir() or not list(path.glob("animation-*.png"))

    if theme is not None:
        theme = theme.expanduser().resolve()
        if not theme.is_dir():
            print(f"ERROR: theme directory not found: {theme}", file=sys.stderr)
            return 1
    else:
        # No --theme: stage into boot/staging/indianadell when asked or missing
        want_animated = animated
        if not want_animated and not args.stage:
            # Default convenience: if generated Dell frames exist, stage that scene
            gen = ROOT / "boot" / "generated" / "dell-animation" / "animation-0001.png"
            want_animated = gen.is_file()

        if args.stage or animated or needs_stage(DEFAULT_STAGE):
            stage_theme(animated_dell=want_animated)
        theme = DEFAULT_STAGE.resolve()

    # Default window size: prefer 1280×720 (manageable); allow full HD via flags
    width = args.width or 1280
    height = args.height or 720
    # Try to pick something sensible from the display if available
    if args.width == 0 and args.height == 0:
        try:
            root = tk.Tk()
            root.withdraw()
            sw, sh = root.winfo_screenwidth(), root.winfo_screenheight()
            root.destroy()
            # Window ~70% of screen, capped
            width = min(1920, max(960, int(sw * 0.7)))
            height = min(1080, max(540, int(sh * 0.7)))
        except tk.TclError:
            pass

    app = PreviewApp(
        theme_dir=theme,
        width=width,
        height=height,
        fps=args.fps,
        start_mode=args.mode,
        animated_dell=animated,
    )
    app.run()
    return 0


if __name__ == "__main__":
    # Fix clumsy default staging branch — cleaner rewrite in main path
    raise SystemExit(main())
