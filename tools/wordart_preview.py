#!/usr/bin/env python3
"""WordArt design sheet: render heavy CJK text, warp it through an Office-style
envelope (top/bottom curves per column), fill with a horizontal rainbow, add
outlines and a hard shadow. Outputs a comparison sheet PNG and an animated GIF.

Usage: python3 tools/wordart_preview.py OUT_DIR
Needs Pillow + numpy only.
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
HEAVY = ROOT / "assets/fonts/NotoSansSC-Black.otf"
OBLIQUE = ROOT / "assets/fonts/SmileySans-Oblique.ttf"


# ---------------------------------------------------------------- masks ----

def dilate_square(m, r):
    """Square (chebyshev) dilation: thickens strokes but keeps corners sharp,
    unlike a stroke/round brush."""
    if r <= 0:
        return m
    out = m.copy()
    for axis in (0, 1):
        src = out.copy()
        for k in range(1, r + 1):
            out = np.maximum(out, np.roll(src, k, axis))
            out = np.maximum(out, np.roll(src, -k, axis))
    return out


def text_masks(text, font_path, px, bold, rims, tracking=0.0):
    """Return float masks (0..1) for the glyph core and each outline radius,
    all on the same canvas. `bold` thickens the core with a square kernel."""
    font = ImageFont.truetype(str(font_path), px)
    pad = max(rims) + bold + 8
    adv = [font.getlength(ch) + px * tracking for ch in text]
    l, t, r, b = font.getbbox(text)
    w = int(sum(adv) + pad * 2 + px * 0.2)
    h = b - t + pad * 2
    im = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(im)
    x = pad
    for ch, a in zip(text, adv):
        d.text((x, pad - t), ch, font=font, fill=255)
        x += a
    base = np.asarray(im, dtype=np.float32) / 255.0
    return [dilate_square(base, bold)] + [dilate_square(base, bold + rr) for rr in rims]


# ------------------------------------------------------------- envelope ----

def warp(mask, top, bottom, out_h):
    """Map each column of `mask` so its rows span [top[x], bottom[x]] in an
    output of height out_h. top/bottom are arrays of length width (pixels)."""
    h, w = mask.shape
    ys = np.arange(out_h, dtype=np.float32)[:, None]            # (H,1)
    span = np.maximum(bottom - top, 1.0)[None, :]               # (1,W)
    src_y = (ys - top[None, :]) / span * (h - 1)                # (H,W)
    valid = (src_y >= 0) & (src_y <= h - 1)
    y0 = np.clip(np.floor(src_y).astype(int), 0, h - 1)
    y1 = np.clip(y0 + 1, 0, h - 1)
    fy = src_y - np.floor(src_y)
    xs = np.broadcast_to(np.arange(w)[None, :], src_y.shape)
    v = mask[y0, xs] * (1 - fy) + mask[y1, xs] * fy
    return np.where(valid, v, 0.0)


def envelope(kind, w, h, phase=0.0, amp=0.35):
    """Top/bottom curves (pixels) for a glyph band of height h across width w.
    Output height is returned too."""
    x = np.linspace(0.0, 1.0, w, dtype=np.float32)
    H = int(h * (1 + amp * 2.2)) + 4
    c = H / 2
    if kind == "flat":
        top = np.full(w, c - h / 2)
        bot = np.full(w, c + h / 2)
    elif kind == "wave":          # WordArt "Wave 1": band bobs and breathes
        s = np.sin(2 * math.pi * (x * 1.15) + phase)
        mid = c + s * h * amp * 0.55
        half = h / 2 * (1 + 0.28 * np.cos(2 * math.pi * (x * 1.15) + phase))
        top, bot = mid - half, mid + half
    elif kind == "inflate":       # tall in the middle
        k = np.sin(math.pi * x)
        half = h / 2 * (0.78 + amp * 1.1 * k)
        top, bot = c - half, c + half
    elif kind == "rise":          # perspective: grows to the right, wavy top
        k = 0.65 + 0.7 * x
        bot = np.full(w, c + h * 0.62)
        top = bot - h * k - h * 0.12 * np.sin(2 * math.pi * x * 1.5 + phase)
    elif kind == "arch":          # whole band bends upward
        mid = c + h * amp * 0.9 * (1 - np.sin(math.pi * x)) - h * amp * 0.45
        top, bot = mid - h / 2, mid + h / 2
    else:
        raise ValueError(kind)
    return top.astype(np.float32), bot.astype(np.float32), H


# ----------------------------------------------------------------- fill ----

def hsv_to_rgb(hh, s, v):
    i = np.floor(hh * 6).astype(int) % 6
    f = hh * 6 - np.floor(hh * 6)
    p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    r = np.choose(i, [v, q, p, p, t, v])
    g = np.choose(i, [t, v, v, q, p, p])
    b = np.choose(i, [p, p, t, v, v, q])
    return np.stack([r, g, b], -1)


def rainbow(H, W, shift=0.0, wavy=0.0, phase=0.0, sat=0.95, val=1.0):
    """Horizontal red→violet rainbow across the line (like the reference)."""
    x = np.linspace(0, 1, W, dtype=np.float32)[None, :]
    y = np.linspace(0, 1, H, dtype=np.float32)[:, None]
    hue = 0.0 + 0.78 * x + shift + wavy * np.sin(y * 7 + x * 9 + phase)
    rgb = hsv_to_rgb(np.mod(np.broadcast_to(hue, (H, W)), 1.0), sat, val)
    # print gloss: brighter top, darker bottom
    gloss = 1 + 0.28 * np.clip(0.45 - y, 0, 1) * 2 - 0.22 * np.clip(y - 0.6, 0, 1) * 2.5
    return np.clip(rgb * gloss[..., None], 0, 1)


def flat(H, W, color):
    return np.broadcast_to(np.array(color, np.float32) / 255.0, (H, W, 3)).copy()


# -------------------------------------------------------------- compose ----

def compose(layers, H, W):
    """layers: list of (mask HxW, rgb HxWx3 or tuple, (dx,dy)) back to front."""
    out = np.zeros((H, W, 4), np.float32)
    for mask, rgb, (dx, dy) in layers:
        m = np.zeros((H, W), np.float32)
        hs, ws = mask.shape
        ys, xs = max(dy, 0), max(dx, 0)
        m[ys:ys + hs - max(-dy, 0) - max(dy, 0) + max(dy, 0), xs:xs + ws] = 0  # noop for clarity
        m = np.roll(np.roll(np.pad(mask, ((0, H - hs), (0, W - ws))), dy, 0), dx, 1)
        col = rgb if isinstance(rgb, np.ndarray) else flat(H, W, rgb)
        if col.shape[:2] != (H, W):
            col = np.pad(col, ((0, H - col.shape[0]), (0, W - col.shape[1]), (0, 0)), mode="edge")
        a = m[..., None]
        out[..., :3] = col * a + out[..., :3] * (1 - a)
        out[..., 3:] = a + out[..., 3:] * (1 - a)
    return Image.fromarray((out * 255).astype(np.uint8), "RGBA")


def wordart(text, style, px=150, phase=0.0, font=HEAVY):
    """style: dict(env, amp, bold, fill, rim, outer, shadow, wavy)."""
    bold = int(px * style.get("bold", 0.04))
    rim = int(px * style.get("rim", 0.0))
    outer = int(px * style.get("outer", 0.035))
    rims = sorted({max(rim, 1), max(outer, rim + 1)})
    core, *outs = text_masks(text, font, px, bold, rims, style.get("tracking", 0.0))
    h, w = core.shape
    stretch = style.get("stretch", 1.0)
    top, bot, H = envelope(style.get("env", "wave"), w, int(h * stretch), phase, style.get("amp", 0.35))
    wc = warp(core, top, bot, H)
    wo = [warp(m, top, bot, H) for m in outs]
    shadow = int(px * style.get("shadow", 0.0))
    W2, H2 = w + shadow + 2, H + shadow + 2
    fill = style.get("fill", "rainbow")
    if fill == "rainbow":
        fill_rgb = rainbow(H, w, shift=-phase * 0.05 * style.get("scroll", 0), wavy=style.get("wavy", 0.0), phase=phase)
        fill_rgb = np.pad(fill_rgb, ((0, H2 - H), (0, W2 - w), (0, 0)), mode="edge")
    else:
        fill_rgb = fill
    outline_col = style.get("outline", (40, 10, 70))
    layers = []
    if shadow:
        layers.append((wo[-1], style.get("shadow_col", (30, 8, 60)), (shadow, shadow)))
    if style.get("outline_mode") == "darker" and fill == "rainbow":
        # thin outline in a darker shade of the same hue (the reference look)
        dark = np.clip(fill_rgb * 0.45, 0, 1)
        layers.append((wo[-1], dark, (0, 0)))
    else:
        layers.append((wo[-1], outline_col, (0, 0)))
        if rim:
            layers.append((wo[0], style.get("rim_col", (255, 255, 255)), (0, 0)))
    layers.append((wc, fill_rgb, (0, 0)))
    return compose(layers, H2, W2)


STYLES = {
    "A 原教旨：参考图加粗，细深色描边": dict(env="rise", amp=0.35, bold=0.035, outer=0.02, outline_mode="darker", stretch=1.55, tracking=0.04),
    "B 波浪 + 白边 + 深色外框 + 硬阴影": dict(env="wave", amp=0.32, bold=0.035, rim=0.035, outer=0.07, shadow=0.06, stretch=1.4, tracking=0.06),
    "C 中间鼓起来": dict(env="inflate", amp=0.3, bold=0.035, rim=0.03, outer=0.065, shadow=0.05, stretch=1.3, tracking=0.06),
    "D 拱形 + 细描边 + 阴影": dict(env="arch", amp=0.32, bold=0.035, outer=0.02, outline_mode="darker", shadow=0.05, stretch=1.5, tracking=0.04),
    "E 更粗（方角膨胀加倍）": dict(env="wave", amp=0.28, bold=0.065, rim=0.03, outer=0.065, shadow=0.05, stretch=1.4, tracking=0.12),
}


def sheet(out_dir: Path):
    rows = []
    label_font = ImageFont.truetype(str(HEAVY), 26)
    for name, st in STYLES.items():
        img = wordart("城市涌现出来了", st, px=130)
        rows.append((name, img))
    W = max(r[1].width for r in rows) + 80
    H = sum(r[1].height + 50 for r in rows) + 40
    bg = Image.new("RGBA", (W, H))
    grad = np.linspace(0, 1, H)[:, None]
    top_c, bot_c = np.array([200, 225, 255]), np.array([60, 90, 160])
    bgarr = (top_c * (1 - grad) + bot_c * grad)[:, None, :].repeat(W, 1).astype(np.uint8)
    bg = Image.fromarray(np.concatenate([bgarr[:, :, 0, :] if bgarr.ndim == 4 else bgarr, np.full((H, W, 1), 255, np.uint8)], -1), "RGBA")
    d = ImageDraw.Draw(bg)
    y = 20
    for name, img in rows:
        d.text((20, y), name, font=label_font, fill=(20, 20, 50))
        bg.alpha_composite(img, ((W - img.width) // 2, y + 30))
        y += img.height + 50
    p = out_dir / "wordart_sheet.png"
    bg.convert("RGB").save(p)
    print(p)


def gif(out_dir: Path, text="城市涌现出来了", key="B 波浪 + 白边 + 深色外框 + 硬阴影", frames=24):
    st = STYLES[key]
    imgs = [wordart(text, dict(st, scroll=1), px=120, phase=2 * math.pi * i / frames) for i in range(frames)]
    W = max(i.width for i in imgs) + 40
    H = max(i.height for i in imgs) + 40
    out = []
    for im in imgs:
        bg = Image.new("RGBA", (W, H), (150, 200, 255, 255))
        bg.alpha_composite(im, ((W - im.width) // 2, (H - im.height) // 2))
        out.append(bg.convert("P", palette=Image.ADAPTIVE, colors=255))
    p = out_dir / "wordart_wave.gif"
    out[0].save(p, save_all=True, append_images=out[1:], duration=60, loop=0, optimize=False)
    print(p)


if __name__ == "__main__":
    d = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    d.mkdir(parents=True, exist_ok=True)
    sheet(d)
    gif(d)
