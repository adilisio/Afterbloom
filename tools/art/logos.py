"""Logos with transparent backgrounds: Halcyon (white + colour), AFTERBLOOM title, Larkhaven Free Radio."""
from __future__ import annotations

import math

import numpy as np
from PIL import Image, ImageFilter

from common import PAL, Canvas, crystal_flower, from_np, hexc, mix, save, shade, to_np
from illus import halcyon_emblem, halcyon_logo, lighthouse, starburst

P = PAL
INK = P["ink"]

MANIFEST = [
    ("logo_halcyon", "Halcyon Electric Co. lockup (kingfisher emblem + wordmark + tagline), white on transparent",
     "UI overlays, TV idents, decals on Tuppence / props (tint in shader)"),
    ("logo_halcyon_color", "Halcyon lockup in brand colours (navy/mustard/cream), transparent", "Menus, loading screens, decals"),
    ("logo_title", "AFTERBLOOM game title logo, 2048x512, transparent; violet crystal-flower O", "Title screen / cold-open title card"),
    ("logo_lfr", "Larkhaven Free Radio roundel (lighthouse + radio waves, 1340 AM), transparent", "Radio UI, journal Radio tab, lighthouse decals"),
]


def trim_center(img, W, H, pad=24):
    """Crop to content bbox and centre on a WxH transparent canvas (scaling down if needed)."""
    bb = img.getchannel("A").getbbox()
    img = img.crop(bb)
    s = min(1.0, (W - 2 * pad) / img.width, (H - 2 * pad) / img.height)
    if s < 1:
        img = img.resize((int(img.width * s), int(img.height * s)), Image.LANCZOS)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.alpha_composite(img, ((W - img.width) // 2, (H - img.height) // 2))
    return out


def unpremultiply_fix(img):
    """Avoid dark fringes: fill RGB of transparent pixels with the nearest opaque colour (approx via blur)."""
    a = to_np(img)
    al = a[..., 3:4] / 255.0
    rgb = a[..., :3]
    blur = to_np(Image.fromarray(np.clip(rgb * al, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3)))
    wb = to_np(img.getchannel("A").filter(ImageFilter.GaussianBlur(3)))[..., None] / 255.0
    fillc = np.where(wb > 0.01, blur / np.maximum(wb, 0.01), rgb)
    rgb2 = np.where(al > 0.02, rgb, fillc)
    a[..., :3] = rgb2
    return from_np(a, "RGBA")


# =========================================================================== Halcyon
def logo_halcyon():
    W, H = 2048, 640
    # colour version on transparency
    C = Canvas(W, H, (0, 0, 0, 0), 2, "RGBA")
    halcyon_logo(C, 60, 300, 420, P["navy"] + (255,), P["mustard"] + (255,), P["cream"] + (255,), tagline=True)
    col = trim_center(C.final(), W, H)
    save(unpremultiply_fix(col), "logo_halcyon_color")
    # white version: render white-on-black and use luminance as alpha
    C2 = Canvas(W, H, (0, 0, 0), 2, "RGB")
    halcyon_logo(C2, 60, 300, 420, (255, 255, 255), (150, 150, 150), (0, 0, 0), tagline=True)
    lum = C2.final().convert("L")
    white = Image.new("RGBA", (W, H), (255, 255, 255, 0))
    white.putalpha(lum)
    save(trim_center(white, W, H), "logo_halcyon")


# =========================================================================== AFTERBLOOM title
def logo_title():
    W, H = 2048, 512
    C = Canvas(W, H, (0, 0, 0, 0), 2, "RGBA")
    word = "AFTERBL" + "OOM"
    spec = ("georgia_b", 210)
    track = 26
    # measure with the 2nd O replaced by a flower of the same advance
    widths = [C.text_w(ch, spec) for ch in word]
    total = sum(widths) + track * (len(word) - 1)
    x = (W - total) / 2
    base = 330
    cream = P["cream"] + (255,)
    navy = shade(P["navy"], 0.75) + (255,)
    gold = P["mustard"] + (255,)
    violet = P["violet"]
    # comet sweep arc over the word (thin double line ending in a spark at the flower)
    flower_i = 8
    fx = x + sum(widths[:flower_i]) + track * flower_i + widths[flower_i] / 2
    fy = base - 72
    p0, p1, p2 = (x + 30, base - 200), (W * 0.45, base - 330), (fx - 70, fy - 70)
    pts = [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
            (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]) for t in np.linspace(0, 1, 80)]
    for i in range(len(pts) - 1):
        u = i / (len(pts) - 1)
        C.line([pts[i], pts[i + 1]], mix(P["cream"], P["mustard"], u) + (int(60 + 195 * u),), 1 + 6 * u ** 1.5, False)
    # letters: extruded navy shadow, then cream face with gold inline
    for pass_ in ("shadow", "face"):
        cx = x
        for i, ch in enumerate(word):
            if i == flower_i:
                cx += widths[i] + track
                continue
            if pass_ == "shadow":
                for k in range(1, 15):
                    C.text((cx + k * 0.9, base + k * 0.9), ch, spec, navy, "ls")
            else:
                C.text((cx, base), ch, spec, cream, "ls")
            cx += widths[i] + track
    # thin gold rules + small caps tagline
    gap = C.text_w("LARKHAVEN · 1967", ("georgia_b", 34), 12) / 2 + 36
    C.rect((x + 10, base + 48, W / 2 - gap, base + 52), fill=gold)
    C.rect((W / 2 + gap, base + 48, x + total - 10, base + 52), fill=gold)
    C.text((W / 2, base + 50), "LARKHAVEN · 1967", ("georgia_b", 34), cream, "mm", 12)
    # the bloom O: glow, ring of crystal petals, bright core
    C.glow(fx, fy, 210, violet, 0.55, 1.8)
    r = 82
    C.ring(fx, fy, r * 0.98, 16, shade(violet, 0.55) + (255,))
    rng = np.random.default_rng(5)
    for i in range(12):
        a = i * 2 * math.pi / 12 + 0.13
        L = r * (1.55 if i % 2 == 0 else 1.25)
        wv = r * 0.36
        tip = (fx + math.cos(a) * L, fy + math.sin(a) * L)
        l = (fx + math.cos(a - 0.38) * wv * 1.6, fy + math.sin(a - 0.38) * wv * 1.6)
        rr = (fx + math.cos(a + 0.38) * wv * 1.6, fy + math.sin(a + 0.38) * wv * 1.6)
        mid = (fx + math.cos(a) * r * 0.45, fy + math.sin(a) * r * 0.45)
        C.poly([mid, l, tip], shade(violet, 0.7) + (255,))
        C.poly([mid, tip, rr], mix(violet, P["white"], 0.35) + (255,))
    C.circle(fx, fy, r * 0.62, fill=shade(violet, 0.5) + (255,))
    C.circle(fx, fy, r * 0.5, fill=violet + (255,))
    C.glow(fx, fy, r * 0.6, (250, 240, 255), 0.95, 1.2)
    starburst(C, fx, fy, r * 0.5, r * 0.08, 4, (255, 250, 255, 255), 0)
    # a couple of drifting motes
    for dx, dy, rr_ in [(140, -110, 9), (190, -40, 6), (-150, -130, 7), (230, -150, 5)]:
        C.glow(fx + dx, fy + dy, rr_ * 3, violet, 0.6, 1.5)
        C.circle(fx + dx, fy + dy, rr_ * 0.6, fill=(240, 225, 255, 255))
    # glows were pasted over transparent black: un-premultiply so they stay violet, not grey
    a = to_np(C.img)
    al = a[..., 3:4] / 255.0
    semi = (al > 0.003) & (al < 0.999)
    a[..., :3] = np.where(semi, np.clip(a[..., :3] / np.maximum(al, 0.003), 0, 255), a[..., :3])
    C.img = from_np(a, "RGBA")
    img = trim_center(C.final(), W, H, 16)
    save(unpremultiply_fix(img), "logo_title")


# =========================================================================== Larkhaven Free Radio
def logo_lfr():
    W = H = 1024
    C = Canvas(W, H, (0, 0, 0, 0), 2, "RGBA")
    cx, cy, R = 512, 512, 480
    navy, cream, teal, red, gold = (P[k] + (255,) for k in ("navy", "cream", "teal", "red", "mustard"))
    C.circle(cx, cy, R, fill=navy)
    C.ring(cx, cy, R - 18, 6, gold)
    C.circle(cx, cy, R * 0.68, fill=teal)
    C.text_arc(cx, cy, R * 0.82, "LARKHAVEN FREE RADIO", ("black", 64), cream, -90, 8)
    # lower ribbon with frequency
    C.text_arc(cx, cy, R * 0.83, "BROADCASTING FROM THE LIGHT", ("franklin", 38), gold, 90, 5, inside=True)
    for sx in (-1, 1):
        starburst(C, cx + sx * R * 0.83, cy, 18, 5, 4, gold)
    # inner scene: sea, lighthouse, radio waves
    m = C.mask()
    m.circle(cx, cy, R * 0.68, fill=255)
    sub = Canvas(W, H, (0, 0, 0, 0), 2, "RGBA")
    sub.rect((0, 0, W, H), fill=teal)
    for k in range(4):
        sub.arc((cx - 60 - k * 70, 330 - 60 - k * 70, cx + 60 + k * 70, 330 + 60 + k * 70), 200, 340, cream, 14)
    sub.rect((0, 640, W, H), fill=navy)
    for k in range(3):
        y = 664 + k * 30
        pts = [(x, y + 6 * math.sin(x / 26 + k)) for x in range(0, W, 6)]
        sub.line(pts, mix(P["navy"], P["cream"], 0.4) + (255,), 5)
    sub.poly([(cx - 150, 650), (cx - 70, 600), (cx + 80, 602), (cx + 160, 650)], shade(P["navy"], 0.7) + (255,))
    lighthouse(sub, cx, 612, 330, cream, red, red, gold, navy, 3, False)
    a = to_np(sub.img.getchannel("A")) * (to_np(m.img) / 255.0)
    sub.img.putalpha(from_np(a, "L"))
    C.img.alpha_composite(sub.img)
    # frequency plate
    C.rrect((cx - 170, 720, cx + 170, 820), 18, fill=red)
    C.rrect((cx - 162, 728, cx + 162, 812), 14, outline=cream, width=4)
    C.text((cx, 772), "1340 AM", ("black", 66), cream, "mm", 4)
    save(unpremultiply_fix(C.final()), "logo_lfr")


ALL = [logo_halcyon, logo_title, logo_lfr]

if __name__ == "__main__":
    import sys
    only = sys.argv[1:]
    for fn in ALL:
        if not only or fn.__name__ in only:
            fn()
