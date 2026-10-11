#!/usr/bin/env python3
"""WordArt design sheet.

Render heavy CJK text, warp it through an Office-style envelope (top/bottom
curves per column), fill the NAME with a poster-style gradient and the suffix
with a flat colour, add a white rim + fat dark outline + hard shadow.
Outputs a comparison sheet PNG and an animated GIF of the wave.

Usage: python3 tools/wordart_preview.py OUT_DIR
Needs Pillow + numpy only. The Godot side mirrors these numbers in
scripts/wordart_line.gd and assets/shaders/wordart_*.gdshader.
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
HEAVY = ROOT / "assets/fonts/NotoSansSC-Black.otf"

# Poster palettes: saturated and a bit dark, so every stop survives on a bright
# sky AND on grass. No lemon yellow / pale cyan (those were unreadable).
PALETTES = {
    "热彩": ["#ff1f5a", "#ff7a00", "#ffb800", "#18c13a", "#1d6bff", "#8a2cff"],
    "粉蓝紫": ["#ff2e97", "#a43cff", "#3a5bff", "#00a8ff"],
    "红橙金": ["#e0001b", "#ff5a00", "#ffb000"],
    "绿蓝": ["#00c853", "#00b0ff", "#2962ff"],
}
SUFFIX_COLORS = {"黄": "#ffe100", "白": "#ffffff"}
DARK = (26, 8, 70)


def hex_rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32) / 255.0


# ---------------------------------------------------------------- masks ----

def dilate_square(m, r):
    """Square (chebyshev) dilation: thickens strokes, keeps corners sharp."""
    if r <= 0:
        return m
    out = m.copy()
    for axis in (0, 1):
        src = out.copy()
        for k in range(1, r + 1):
            out = np.maximum(out, np.roll(src, k, axis))
            out = np.maximum(out, np.roll(src, -k, axis))
    return out


def text_bases(segments, font_path, px, pad, tracking=0.0):
    """segments: [(text, scale)] on one shared baseline. Returns one base mask
    per segment (same canvas) and the x where the first segment ends."""
    fonts = [ImageFont.truetype(str(font_path), max(8, int(px * s))) for _, s in segments]
    big = ImageFont.truetype(str(font_path), px)
    asc, desc = big.getmetrics()
    w = pad * 2 + int(px * 0.3)
    for (t, s), f in zip(segments, fonts):
        w += int(sum(f.getlength(ch) + px * s * tracking for ch in t))
    h = asc + desc + pad * 2
    x = float(pad)
    name_end = 0
    bases = []
    for i, ((t, s), f) in enumerate(zip(segments, fonts)):
        im = Image.new("L", (w, h), 0)
        d = ImageDraw.Draw(im)
        fa, _ = f.getmetrics()
        for ch in t:
            d.text((x, pad + asc - fa), ch, font=f, fill=255)
            x += f.getlength(ch) + px * s * tracking
        if i == 0:
            name_end = int(x - px * s * tracking * 0.5)
        bases.append(np.asarray(im, dtype=np.float32) / 255.0)
    return bases, name_end


# ------------------------------------------------------------- envelope ----

def wave_envelope(w, h, phase=0.0, amp=0.32, cycles=1.15):
    """WordArt "Wave": the band bobs up/down and breathes taller/shorter."""
    x = np.linspace(0.0, 1.0, w, dtype=np.float32)
    H = int(h * (1 + amp * 2.2)) + 4
    c = H / 2
    a = 2 * math.pi * x * cycles + phase
    mid = c + np.sin(a) * h * amp * 0.55
    half = h / 2 * (1 + 0.28 * np.cos(a))
    return (mid - half).astype(np.float32), (mid + half).astype(np.float32), H


def warp(mask, top, bottom, out_h):
    h, w = mask.shape
    ys = np.arange(out_h, dtype=np.float32)[:, None]
    span = np.maximum(bottom - top, 1.0)[None, :]
    src_y = (ys - top[None, :]) / span * (h - 1)
    valid = (src_y >= 0) & (src_y <= h - 1)
    y0 = np.clip(np.floor(src_y).astype(int), 0, h - 1)
    y1 = np.clip(y0 + 1, 0, h - 1)
    fy = src_y - np.floor(src_y)
    xs = np.broadcast_to(np.arange(w)[None, :], src_y.shape)
    v = mask[y0, xs] * (1 - fy) + mask[y1, xs] * fy
    return np.where(valid, v, 0.0)


# ----------------------------------------------------------------- fill ----

def palette_fill(H, W, x0, x1, stops):
    """Gradient along x across [x0, x1] through the palette stops, with a
    print-style gloss (lighter top, darker bottom)."""
    cols = np.stack([hex_rgb(s) for s in stops])
    u = np.clip((np.arange(W, dtype=np.float32) - x0) / max(x1 - x0, 1), 0, 1)
    pos = u * (len(stops) - 1)
    i0 = np.clip(np.floor(pos).astype(int), 0, len(stops) - 1)
    i1 = np.clip(i0 + 1, 0, len(stops) - 1)
    f = (pos - i0)[:, None]
    row = cols[i0] * (1 - f) + cols[i1] * f                       # (W,3)
    img = np.broadcast_to(row[None, :, :], (H, W, 3)).copy()
    y = np.linspace(0, 1, H, dtype=np.float32)[:, None, None]
    gloss = 1 + 0.35 * np.clip(0.42 - y, 0, 1) * 2.2 - 0.25 * np.clip(y - 0.62, 0, 1) * 2.6
    return np.clip(img * gloss, 0, 1)


# -------------------------------------------------------------- compose ----

def over(dst, mask, rgb, dx=0, dy=0):
    H, W = dst.shape[:2]
    m = np.zeros((H, W), np.float32)
    hs, ws = mask.shape
    hh, ww = min(hs, H - dy), min(ws, W - dx)
    m[dy:dy + hh, dx:dx + ww] = mask[:hh, :ww]
    col = rgb if isinstance(rgb, np.ndarray) else np.broadcast_to(np.array(rgb, np.float32) / 255.0, (H, W, 3))
    a = m[..., None]
    dst[..., :3] = col * a + dst[..., :3] * (1 - a)
    dst[..., 3:] = a + dst[..., 3:] * (1 - a)


def wordart(name, suffix, palette="热彩", suffix_color="黄", px=150, phase=0.0,
            bold=0.035, rim=0.045, outer=0.11, shadow=0.075, stretch=1.4, amp=0.32,
            suffix_scale=0.62, tracking=0.06):
    b, r, o = int(px * bold), int(px * rim), int(px * outer)
    sp = px * suffix_scale
    sb, so = int(sp * bold), int(sp * outer * 0.75)   # suffix: own weights, no white rim
    (nb, sbase), name_end = text_bases([(name, 1.0), (suffix, suffix_scale)], HEAVY, px, o + b + 8, tracking)
    s_core = dilate_square(sbase, sb)
    core = np.maximum(dilate_square(nb, b), s_core)
    rim_m = np.maximum(dilate_square(nb, b + r), s_core)
    out_m = np.maximum(dilate_square(nb, b + o), dilate_square(sbase, sb + so))
    h, w = core.shape
    top, bot, H = wave_envelope(w, int(h * stretch), phase, amp)
    core, rim_m, out_m = (warp(m, top, bot, H) for m in (core, rim_m, out_m))
    sh = int(px * shadow)
    W2, H2 = w + sh + 2, H + sh + 2
    img = np.zeros((H2, W2, 4), np.float32)
    fill = palette_fill(H2, W2, int(o), name_end, PALETTES[palette])
    suf = hex_rgb(SUFFIX_COLORS[suffix_color])
    x = np.arange(W2)[None, :, None]
    fill = np.where(x < name_end, fill, suf[None, None, :])
    over(img, out_m, DARK, sh, sh)            # hard shadow
    over(img, out_m, DARK)                    # fat dark outline
    over(img, rim_m, (255, 255, 255))         # white rim
    over(img, core, fill)                     # fill
    return Image.fromarray((img * 255).astype(np.uint8), "RGBA")


ROWS = [
    ("1 热彩 + 黄后缀", dict(name="城市", suffix="涌现出来了。", palette="热彩", suffix_color="黄")),
    ("2 粉蓝紫 + 白后缀", dict(name="城市", suffix="涌现出来了。", palette="粉蓝紫", suffix_color="白")),
    ("3 红橙金 + 白后缀", dict(name="城市", suffix="涌现出来了。", palette="红橙金", suffix_color="白")),
    ("4 绿蓝 + 黄后缀", dict(name="城市", suffix="涌现出来了。", palette="绿蓝", suffix_color="黄")),
    ("5 长名字 · 热彩", dict(name="两个杀毒软件打起来了", suffix="。", palette="热彩", suffix_color="黄")),
    ("6 单字 · 粉蓝紫", dict(name="钱", suffix="涌现出来了。", palette="粉蓝紫", suffix_color="黄")),
]


def background(W, H):
    # left half sky, right half grass: captions must read on both
    y = np.linspace(0, 1, H)[:, None, None]
    sky = np.array([170, 210, 255]) * (1 - y) + np.array([225, 240, 255]) * y
    grass = np.array([120, 175, 95])
    xmask = (np.arange(W)[None, :, None] > W // 2)
    arr = np.broadcast_to(np.where(xmask, grass, sky), (H, W, 3)).astype(np.uint8)
    return Image.fromarray(np.concatenate([arr, np.full((H, W, 1), 255, np.uint8)], -1), "RGBA")


def sheet(out_dir: Path):
    label_font = ImageFont.truetype(str(HEAVY), 24)
    imgs = [(t, wordart(px=120, **kw)) for t, kw in ROWS]
    W = max(i.width for _, i in imgs) + 60
    H = sum(i.height + 36 for _, i in imgs) + 30
    bg = background(W, H)
    d = ImageDraw.Draw(bg)
    y = 14
    for t, im in imgs:
        d.text((14, y), t, font=label_font, fill=(20, 20, 50))
        bg.alpha_composite(im, ((W - im.width) // 2, y + 22))
        y += im.height + 36
    p = out_dir / "wordart_sheet.png"
    bg.convert("RGB").save(p)
    print(p)


def gif(out_dir: Path, frames=24):
    imgs = [wordart("城市", "涌现出来了。", px=120, phase=2 * math.pi * i / frames) for i in range(frames)]
    W = max(i.width for i in imgs) + 40
    H = max(i.height for i in imgs) + 40
    out = []
    for im in imgs:
        bg = background(W, H)
        bg.alpha_composite(im, ((W - im.width) // 2, (H - im.height) // 2))
        out.append(bg.convert("P", palette=Image.ADAPTIVE, colors=255))
    p = out_dir / "wordart_wave.gif"
    out[0].save(p, save_all=True, append_images=out[1:], duration=60, loop=0)
    print(p)


if __name__ == "__main__":
    d = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    d.mkdir(parents=True, exist_ok=True)
    sheet(d)
    gif(d)
