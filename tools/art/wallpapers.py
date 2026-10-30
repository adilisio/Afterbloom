"""Seamlessly tileable mid-century wallpapers (1024x1024) + aged variants.

wallpaper_living   – muted warm atomic/floral (tulips, starbursts, boomerangs), half-drop repeat
wallpaper_bedroom  – soft stripes with little rosebuds
wallpaper_kitchen  – cheerful teapots, cups and lemons on a faint gingham check
*_aged             – faded, yellowed, water-stained, peeling at the strip seams (still seamless)
"""
from __future__ import annotations

import math

import numpy as np
from scipy import ndimage

from common import (PAL, Canvas, _stain_field, age_paper, from_np, hexc, mix, noise, print_finish, save, shade, tile2x2,
                    tile_check, to_np)
from illus import T, ellipse_pts, starburst

S = 1024
P = PAL

MANIFEST = [
    ("wallpaper_living", "Tileable wallpaper: muted warm atomic/floral (tulips, starbursts, boomerangs)", "Living room walls, 1967 house (Ch.1)"),
    ("wallpaper_living_aged", "Tileable wallpaper: living room pattern faded, stained, peeling at strip seams", "Living room walls, 1978 overgrown house (Ch.4)"),
    ("wallpaper_bedroom", "Tileable wallpaper: soft teal stripes with small rosebuds", "Player bedroom / June's room, 1967"),
    ("wallpaper_bedroom_aged", "Tileable wallpaper: bedroom pattern faded, stained, peeling", "Bedrooms, 1978"),
    ("wallpaper_kitchen", "Tileable wallpaper: teapots, cups and lemons on faint gingham check", "Kitchen walls, 1967"),
    ("wallpaper_kitchen_aged", "Tileable wallpaper: kitchen pattern faded, grease/water stained, peeling", "Kitchen walls, 1978"),
]


# --------------------------------------------------------------------------- helpers
def aniso_noise(w, h, cx, cy, seed, order=3):
    """Tileable value noise with independent lattice counts along x and y (for streaks)."""
    rng = np.random.default_rng(seed)
    g = rng.random((cy, cx)).astype(np.float32)
    z = ndimage.zoom(g, (h / cy, w / cx), order=order, mode="grid-wrap", grid_mode=True)[:h, :w]
    return (z - z.min()) / max(1e-6, z.max() - z.min())


def wrap_spots(w, h, seed, count, rmin, rmax, color, strength):
    """Wrapped foxing spots: returns (alpha, color) contributions as float arrays."""
    rng = np.random.default_rng(seed)
    acc = np.zeros((h, w), np.float32)
    for _ in range(count):
        cx, cy, r = rng.random() * w, rng.random() * h, rng.uniform(rmin, rmax)
        R = int(r * 3) + 2
        ys = (np.arange(int(cy) - R, int(cy) + R + 1)) % h
        xs = (np.arange(int(cx) - R, int(cx) + R + 1)) % w
        yy, xx = np.meshgrid(np.arange(int(cy) - R, int(cy) + R + 1), np.arange(int(cx) - R, int(cx) + R + 1), indexing="ij")
        d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / r
        m = np.clip(1.2 - d, 0, 1) * rng.uniform(0.4, 1.0) * strength
        acc[np.ix_(ys, xs)] = np.maximum(acc[np.ix_(ys, xs)], m)
    return acc


def age_wallpaper(img, seed, strip=512, peel=1.0, grease=False):
    """Seamless aging: fade/yellow/stain via age_paper(tile=True), then drip streaks, foxing and
    peeling along vertical strip seams (every `strip` px, so it repeats with the tile)."""
    w, h = img.size
    out = age_paper(img, seed, amount=0.85, stains=0, tears=False, creases=0, foxing=0, fade=0.3, tile=True)
    a = to_np(out.convert("RGB"))
    # soft water stains with faint tide lines (weaker than age_paper's so the repeat doesn't read)
    f, r = _stain_field(w, h, seed + 11, 3, tile=True, size=(0.07, 0.16))
    brown_s = np.array([150, 110, 60], np.float32) / 255.0
    a = a * (1 - 0.14 * f[..., None] * (1 - brown_s)) * (1 - 0.16 * r[..., None] * (1 - brown_s))
    # vertical drip streaks from water running down the wall
    streak = aniso_noise(w, h, 48, 3, seed + 1)
    streak = np.clip((streak - 0.62) * 3.5, 0, 1) * aniso_noise(w, h, 6, 4, seed + 2)
    brown = np.array([150, 112, 66], np.float32)
    a = a * (1 - 0.30 * streak[..., None]) + brown * 0.30 * streak[..., None]
    # foxing / mildew dots
    fx = wrap_spots(w, h, seed + 3, 140, 1.0, 4.0, None, 0.45)
    a = a * (1 - fx[..., None]) + np.array([128, 92, 55], np.float32) * fx[..., None]
    mil = wrap_spots(w, h, seed + 4, 60, 2.0, 7.0, None, 0.25) * noise(w, h, 6, seed + 5, 3)
    a = a * (1 - mil[..., None]) + np.array([92, 98, 70], np.float32) * mil[..., None]
    if grease:
        g = noise(w, h, 3, seed + 6, 4)
        g = np.clip((g - 0.55) * 2.5, 0, 1) * 0.22
        a = a * (1 - g[..., None]) + np.array([170, 120, 50], np.float32) * g[..., None]
    # peeling along strip seams: exposed plaster + curled lifted edge with shadow
    xx = np.arange(w, dtype=np.float32)[None, :].repeat(h, 0) + 37   # seams at x=475 and x=987
    d = np.minimum(xx % strip, strip - (xx % strip))           # distance to nearest seam (periodic)
    side = np.where((xx % strip) < strip / 2, 1.0, -1.0)
    pn = aniso_noise(w, h, 4, 10, seed + 7)                      # how far the peel reaches along the seam
    reach = np.clip((pn - 0.45) * 2.2, 0, 1) * 70 * peel
    reach = reach * np.clip(side * 0.5 + 0.75, 0, 1)             # peel mostly to one side
    rough = (noise(w, h, 64, seed + 8, 2) - 0.5) * 10
    peeled = np.clip((reach - d + rough) / 1.5, 0, 1)
    plaster = np.array([196, 184, 160], np.float32) * (0.9 + 0.12 * noise(w, h, 128, seed + 9, 2))[..., None]
    shadow = np.clip(1 - np.abs(d - reach - rough - 3) / 4, 0, 1) * (reach > 2) * 0.45
    curl = np.clip(1 - np.abs(d - reach - rough + 1) / 2.0, 0, 1) * (reach > 2) * 0.5
    a = a * (1 - peeled[..., None]) + plaster * peeled[..., None]
    a = a * (1 - shadow[..., None] * 0.6)
    a = a + (255 - a) * (curl[..., None] * 0.35)
    # seam line itself (slight gap / dirt)
    seam = np.clip(1 - d / 1.2, 0, 1) * 0.35
    a = a * (1 - seam[..., None])
    return from_np(a, "RGB")


def tulip(C, x, y, s, petal, leaf, stem):
    """Stylised mid-century tulip; (x, y) = base of stem."""
    t = T(x, y, s)
    C.line(t.pts([(0, 0), (2, -30), (0, -62)]), stem, t.r(4))
    C.poly(t.pts([(0, -8), (-30, -34), (-34, -54), (-4, -22)]), leaf)
    C.poly(t.pts([(2, -18), (28, -40), (30, -60), (4, -30)]), leaf)
    # three petals
    C.poly(t.pts([(-18, -62), (-22, -92), (-8, -82), (0, -100), (8, -82), (22, -92), (18, -62), (0, -54)]), petal)
    C.poly(t.pts([(0, -100), (8, -82), (18, -62), (0, -54)]), shade(petal, 0.85))
    C.circle(*t(0, -66), t.r(4), fill=mix(petal, P["white"], 0.5))


def daisy(C, x, y, r, petal, centre, n=8):
    for i in range(n):
        a = i * 2 * math.pi / n
        C.ellipse((x + math.cos(a) * r * 0.6 - r * 0.32, y + math.sin(a) * r * 0.6 - r * 0.32,
                   x + math.cos(a) * r * 0.6 + r * 0.32, y + math.sin(a) * r * 0.6 + r * 0.32), fill=petal)
    C.circle(x, y, r * 0.32, fill=centre)


def boomerang(C, x, y, s, rot, fill):
    t = T(x, y, s, rot)
    pts = [(-40, 8), (-30, -2), (0, -12), (30, -2), (40, 8), (28, 10), (0, 0), (-28, 10)]
    C.poly(t.pts(pts), fill)


def finish_tile(C, name, seed, paper=(250, 244, 230), misreg=0.8):
    # roll by a few px so no pattern edge sits exactly on the tile border (keeps seam metrics honest)
    base = from_np(np.roll(to_np(C.final()), (7, 11), axis=(0, 1)), "RGB")
    img = print_finish(base, seed, paper=paper, tile=True, misreg=misreg)
    save(img, name)
    return img


# --------------------------------------------------------------------------- living
def wallpaper_living():
    bg = hexc("E4D0A8")
    C = Canvas(S, S, bg, 2, wrap=True)
    teal = mix(P["teal"], bg, 0.22)
    coral = mix(P["coral"], bg, 0.18)
    mustard = mix(P["mustard"], bg, 0.12)
    brown = hexc("7A5638")
    olive = hexc("8C8B57")
    cream = mix(P["cream"], P["white"], 0.3)
    lozenge = shade(bg, 0.95)
    # soft lozenge trellis in a slightly deeper ground tone
    for gy in range(8):
        for gx in range(8):
            cx, cy = gx * 128 + (64 if gy % 2 else 0), gy * 128 + 64
            C.poly([(cx, cy - 58), (cx + 40, cy), (cx, cy + 58), (cx - 40, cy)], lozenge)
    rng = np.random.default_rng(31)
    cell = 512
    for gy in range(2):
        for gx in range(2):
            x0 = gx * cell
            y0 = gy * cell + (cell / 2 if gx % 2 else 0)      # half-drop
            # motif A: tulip bouquet
            bx, by = x0 + 130, y0 + 250
            tulip(C, bx - 34, by, 1.15, mustard, olive, brown)
            tulip(C, bx + 36, by + 4, 1.2, teal, olive, brown)
            tulip(C, bx, by + 14, 1.55, coral, teal, brown)
            daisy(C, bx - 62, by - 30, 16, cream, coral, 8)
            daisy(C, bx + 70, by - 44, 13, cream, mustard, 7)
            # motif B: atomic starburst with orbits
            cx, cy = x0 + 380, y0 + 110
            for k in range(12):
                a = k * math.pi / 6 + 0.13
                L = 58 if k % 2 == 0 else 40
                C.line([(cx, cy), (cx + math.cos(a) * L, cy + math.sin(a) * L)], brown, 2.2)
                C.circle(cx + math.cos(a) * (L + 4), cy + math.sin(a) * (L + 4), 5.5 if k % 2 == 0 else 4,
                         fill=teal if k % 4 == 0 else coral if k % 4 == 2 else mustard)
            C.circle(cx, cy, 11, fill=mustard)
            C.circle(cx, cy, 5, fill=brown)
            # motif C: crossed boomerangs + sparkles
            boomerang(C, x0 + 390, y0 + 380, 1.25, -30, teal)
            boomerang(C, x0 + 410, y0 + 400, 1.0, 35, coral)
            for _ in range(7):
                sx, sy = x0 + rng.uniform(0, cell), y0 + rng.uniform(0, cell)
                starburst(C, sx, sy, rng.uniform(7, 12), 2.2, 4, mix(brown, bg, 0.35))
            for _ in range(10):
                C.circle(x0 + rng.uniform(0, cell), y0 + rng.uniform(0, cell), 3, fill=mix(teal, bg, 0.3))
    return finish_tile(C, "wallpaper_living", 201)


# --------------------------------------------------------------------------- bedroom
def rosebud(C, x, y, s, petal, leaf, stem):
    t = T(x, y, s)
    C.line(t.pts([(0, 0), (-3, 16), (0, 30)]), stem, t.r(2.4))
    C.poly(t.pts([(-1, 14), (-16, 8), (-20, 18), (-4, 20)]), leaf)
    C.poly(t.pts([(0, 22), (14, 16), (17, 25), (2, 27)]), leaf)
    C.ellipse(t.box(-10, -12, 10, 6), fill=petal)
    C.chord(t.box(-10, -12, 10, 6), 200, 340, fill=shade(petal, 0.82))
    C.arc(t.box(-6, -8, 6, 4), 180, 330, mix(petal, P["white"], 0.5), t.r(1.6))
    C.poly(t.pts([(-9, 0), (0, 10), (9, 0), (0, 4)]), leaf)


def wallpaper_bedroom():
    bg = hexc("F2E9D6")
    C = Canvas(S, S, bg, 2, wrap=True)
    stripe = mix(P["teal_lt"], bg, 0.55)
    line = mix(P["teal"], bg, 0.55)
    period = 128
    for x in range(0, S, period):
        C.rect((x, 0, x + 44, S), fill=stripe)
        C.rect((x + 50, 0, x + 52, S), fill=line)
        C.rect((x - 8, 0, x - 6, S), fill=line)
    petal = mix(P["coral"], P["white"], 0.15)
    leaf = mix(P["teal"], hexc("7A8B5A"), 0.5)
    stem = hexc("6E7A50")
    for k, x in enumerate(range(0, S, period)):
        cx = x + 89
        for j, y in enumerate(range(0, S, 128)):
            yy = y + (64 if k % 2 else 0) + 20
            rosebud(C, cx, yy, 1.0, petal if (j + k) % 3 else mix(P["mustard"], P["white"], 0.2), leaf, stem)
            C.circle(cx - 20, yy + 64, 2.2, fill=mix(petal, bg, 0.3))
            C.circle(cx + 20, yy + 64, 2.2, fill=mix(petal, bg, 0.3))
            C.circle(cx, yy + 74, 2.2, fill=mix(leaf, bg, 0.3))
        # tiny forget-me-nots inside the wide stripe
        for y in range(0, S, 64):
            daisy(C, x + 22, y + 32 + (32 if k % 2 else 0), 6, mix(P["cream"], P["white"], 0.4), mix(P["mustard"], bg, 0.2), 5)
    return finish_tile(C, "wallpaper_bedroom", 202)


# --------------------------------------------------------------------------- kitchen
def teapot(C, x, y, s, body, accent, flip=False):
    """(x, y) = centre of pot body."""
    t = T(x, y, s, 0, flip)
    C.arc(t.box(24, -22, 58, 18), 270, 90, body, t.r(7)) if not flip else C.arc(t.box(-58, -22, -24, 18), 90, 270, body, t.r(7))
    C.poly(t.pts([(-30, 2), (-56, -26), (-62, -24), (-48, 12)]), body)               # spout
    C.ellipse(t.box(-38, -30, 38, 30), fill=body)                                     # body
    C.chord(t.box(-38, -30, 38, 30), 20, 160, fill=shade(body, 0.85))
    C.rect(t.box(-37, -4, 37, 3), fill=accent)                                        # band
    C.ellipse(t.box(-20, -40, 20, -26), fill=shade(body, 0.9))                        # lid
    C.circle(*t(0, -42), t.r(6), fill=accent)
    C.ellipse(t.box(-26, -20, -14, -10), fill=mix(body, P["white"], 0.55))            # highlight
    C.circle(*t(-8, 15), t.r(4), fill=mix(accent, P["white"], 0.3))
    C.circle(*t(8, 15), t.r(4), fill=mix(accent, P["white"], 0.3))


def cup(C, x, y, s, body, accent):
    t = T(x, y, s)
    C.ellipse(t.box(-30, 10, 30, 22), fill=shade(P["cream"], 0.9))                    # saucer
    C.arc(t.box(12, -10, 32, 8), 270, 90, body, t.r(4.5))
    C.chord(t.box(-20, -26, 20, 18), 0, 180, fill=body)
    C.rect(t.box(-20, -6, 20, -4), fill=body)
    C.rect(t.box(-18, -3, 18, 2), fill=accent)
    C.ellipse(t.box(-20, -10, 20, -2), fill=mix(body, P["white"], 0.3))
    for k in range(2):
        C.arc(t.box(-8 + k * 10, -36, 2 + k * 10, -14), 100, 260, mix(body, P["white"], 0.5), t.r(1.8))


def lemon(C, x, y, s, rot=0):
    t = T(x, y, s, rot)
    C.poly(t.pts(ellipse_pts(0, 0, 18, 12, n=32)), P["mustard"])
    C.poly(t.pts([(16, -3), (24, 0), (16, 3)]), P["mustard"])
    C.poly(t.pts([(-16, -3), (-23, 0), (-16, 3)]), P["mustard"])
    C.ellipse(t.box(-10, -8, 0, -3), fill=mix(P["mustard"], P["white"], 0.5))
    C.poly(t.pts([(-4, -11), (6, -24), (12, -14)]), P["teal"])


def wallpaper_kitchen():
    bg = hexc("F6EEDB")
    C = Canvas(S, S, bg, 2, wrap=True)
    chk = mix(P["teal_lt"], bg, 0.72)
    chk2 = mix(P["teal_lt"], bg, 0.45)
    cell = 32
    for x in range(0, S, cell * 2):
        C.rect((x, 0, x + cell, S), fill=chk)
    for y in range(0, S, cell * 2):
        C.rect((0, y, S, y + cell), fill=chk)
    for x in range(0, S, cell * 2):
        for y in range(0, S, cell * 2):
            C.rect((x, y, x + cell, y + cell), fill=chk2)
    cols = [(P["coral"], P["teal"]), (P["teal"], P["mustard"]), (P["red"], P["cream"]), (P["mustard"], P["coral"])]
    g = 256
    for gy in range(4):
        for gx in range(4):
            x0, y0 = gx * g, gy * g
            body, acc = cols[(gx + gy * 2) % 4]
            # white plate behind each motif for cheer
            C.circle(x0 + 72, y0 + 80, 62, fill=bg)
            teapot(C, x0 + 74, y0 + 84, 0.95, body, acc, flip=(gx + gy) % 2 == 1)
            C.circle(x0 + 200, y0 + 205, 46, fill=bg)
            cup(C, x0 + 200, y0 + 210, 0.95, cols[(gx + gy * 2 + 1) % 4][0], cols[(gx + gy * 2 + 1) % 4][1])
            lemon(C, x0 + 200, y0 + 70, 0.9, -20)
            lemon(C, x0 + 70, y0 + 205, 0.8, 30)
    return finish_tile(C, "wallpaper_kitchen", 203)


# --------------------------------------------------------------------------- aged
def aged(name, seed, **kw):
    from PIL import Image
    from common import OUT
    src = Image.open(OUT / f"{name}.png").convert("RGB")
    img = age_wallpaper(src, seed, **kw)
    save(img, f"{name}_aged")
    return img


def wallpaper_living_aged():
    return aged("wallpaper_living", 211)


def wallpaper_bedroom_aged():
    return aged("wallpaper_bedroom", 212, peel=1.2)


def wallpaper_kitchen_aged():
    return aged("wallpaper_kitchen", 213, grease=True)


ALL = [wallpaper_living, wallpaper_bedroom, wallpaper_kitchen, wallpaper_living_aged, wallpaper_bedroom_aged,
       wallpaper_kitchen_aged]

if __name__ == "__main__":
    import sys
    only = sys.argv[1:]
    for fn in ALL:
        if not only or fn.__name__ in only:
            img = fn()
            print("   tile_check (seam, interior):", tuple(round(v, 2) for v in tile_check(img)))
