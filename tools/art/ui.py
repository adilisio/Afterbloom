"""Journal / HUD UI textures.

ui_paper        1024² tileable old notebook paper (cream, faint ruled lines)
ui_leather      1024² tileable dark brown pebbled leather
icon_*          128² RGBA single-ink rubber-stamp icons for the journal tabs
compass_strip   2048x64 RGBA scrolling compass tape (x = heading/360*2048, N at x=0; wraps horizontally)
"""
from __future__ import annotations

import math

import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.spatial import cKDTree

from common import PAL, Canvas, from_np, hexc, mix, noise, paper_texture, save, shade, tile_check, to_np
from illus import T, ellipse_pts

P = PAL
S = 1024

MANIFEST = [
    ("ui_paper", "Tileable aged notebook paper, cream with faint blue rules", "Journal page background (Tab menu), note/quest panels"),
    ("ui_leather", "Tileable dark brown pebbled leather", "Journal cover / frame, pause menu backing"),
    ("icon_quests", "128px ink-stamp icon: pennant flag on a scroll", "Journal tab: Quests"),
    ("icon_items", "128px ink-stamp icon: buckled satchel", "Journal tab: Items/inventory"),
    ("icon_mags", "128px ink-stamp icon: magazine with starburst", "Journal tab: Magazines"),
    ("icon_radio", "128px ink-stamp icon: pocket transistor radio", "Journal tab: Radio"),
    ("icon_map", "128px ink-stamp icon: folded map with route + X", "Journal tab: Map"),
    ("icon_settings", "128px ink-stamp icon: gear", "Journal tab: Settings"),
    ("compass_strip", "2048x64 transparent compass tape, N/NE/E... + ticks; seamless horizontally; x = heading/360*2048 (N at x=0)",
     "HUD compass bar (scroll UV by heading)"),
]


# --------------------------------------------------------------------------- paper
def ui_paper():
    rng = np.random.default_rng(301)
    base = paper_texture(S, S, (244, 233, 205), 301, 1.4)
    a = base.copy()
    # large soft yellowing clouds + slightly darker blotches (tileable noise)
    cl = noise(S, S, 3, 302, 4)
    a *= (0.93 + 0.07 * cl)[..., None]
    yel = noise(S, S, 5, 303, 3)
    a = a * (1 - 0.08 * yel[..., None]) + np.array([214, 184, 128], np.float32) * 0.08 * yel[..., None]
    # faint blue ruled lines every 32 px (32 rows per tile), slightly broken by noise
    yy = np.arange(S, dtype=np.float32)[:, None].repeat(S, 1)
    ph = (yy - 20) % 32
    line = np.exp(-((ph - 0) ** 2) / 0.8) + np.exp(-((ph - 32) ** 2) / 0.8)
    line *= 0.75 + 0.25 * noise(S, S, 64, 304, 2)
    blue = np.array([120, 150, 175], np.float32)
    a = a * (1 - 0.32 * line[..., None]) + blue * 0.32 * line[..., None]
    # foxing specks, wrapped
    for _ in range(90):
        cx, cy, r = rng.random() * S, rng.random() * S, rng.uniform(0.8, 3.0)
        R = int(r * 3) + 2
        ys = np.arange(int(cy) - R, int(cy) + R + 1)
        xs = np.arange(int(cx) - R, int(cx) + R + 1)
        yy2, xx2 = np.meshgrid(ys, xs, indexing="ij")
        d = np.sqrt((xx2 - cx) ** 2 + (yy2 - cy) ** 2) / r
        m = (np.clip(1.2 - d, 0, 1) * rng.uniform(0.2, 0.5))[..., None]
        sub = a[np.ix_(ys % S, xs % S)]
        a[np.ix_(ys % S, xs % S)] = sub * (1 - m) + np.array([150, 105, 60], np.float32) * m
    img = from_np(a, "RGB")
    save(img, "ui_paper")
    return img


# --------------------------------------------------------------------------- leather
def ui_leather():
    rng = np.random.default_rng(311)
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    pts = rng.random((9000, 2)) * S
    tree = cKDTree(pts, boxsize=S)
    q = np.stack([xx.ravel() + 0.5, yy.ravel() + 0.5], 1) % S
    d, _ = tree.query(q, k=2)
    f1 = d[:, 0].reshape(S, S)
    f2 = d[:, 1].reshape(S, S)
    crease = np.clip((f2 - f1) / 3.0, 0, 1)                  # 0 in the grooves between pebbles
    groove = np.exp(-((f2 - f1) / 1.7) ** 2)
    height = -2.6 * ndimage.gaussian_filter(groove, 1.6, mode="wrap") - 0.8 * groove
    height += 2.0 * noise(S, S, 8, 312, 4)
    # wrinkle lines
    wr = noise(S, S, 12, 313, 3)
    height += 2.0 * np.clip(1 - np.abs(wr - 0.5) * 18, 0, 1) * -1
    height = ndimage.gaussian_filter(height, 0.7, mode="wrap")
    gx = np.roll(height, -1, 1) - np.roll(height, 1, 1)
    gy = np.roll(height, -1, 0) - np.roll(height, 1, 0)
    light = np.clip(0.85 + (-gx * 0.45 - gy * 0.65) * 0.42, 0.55, 1.2)
    base = np.array([80, 47, 29], np.float32)
    dark = np.array([46, 27, 17], np.float32)
    var = noise(S, S, 4, 314, 4)
    col = base[None, None] * (0.75 + 0.45 * var[..., None]) * 0.85 + dark[None, None] * 0.15
    col = col * light[..., None]
    col = col * (0.78 + 0.22 * crease[..., None])
    # subtle wear sheen on high spots
    hi = np.clip((noise(S, S, 3, 315, 3) - 0.55) * 2, 0, 1) * 0.12
    col = col + (np.array([170, 120, 80], np.float32) - col) * hi[..., None] * np.clip(light - 0.8, 0, 1)[..., None]
    img = from_np(col, "RGB")
    save(img, "ui_leather")
    return img


# --------------------------------------------------------------------------- stamp icons
STAMP_INK = hexc("3B2A20")  # dark sepia ink; tint in-engine via modulate if needed
SS = 4


def stamp_finish(C, name, seed, ink=STAMP_INK):
    """C: Canvas mode 'L' (255 = inked). Rough the edges and speckle the ink like a rubber stamp."""
    m = to_np(C.img) / 255.0                       # at SS resolution
    h, w = m.shape
    m = ndimage.gaussian_filter(m, 1.6)
    edge_noise = noise(w, h, w / 10, seed, 3) - 0.5
    m = np.clip((m - 0.5 + edge_noise * 0.35) * 6 + 0.5, 0, 1)
    # ink voids / uneven pressure
    voids = noise(w, h, w / 6, seed + 1, 2)
    press = noise(w, h, 3, seed + 2, 2)
    m *= 1 - np.clip((voids - 0.68 + press * 0.12) * 5, 0, 1) * 0.85
    m *= 0.86 + 0.14 * press
    a = from_np(m * 255, "L").resize((C.w, C.h), Image.LANCZOS)
    img = Image.new("RGBA", (C.w, C.h), ink + (0,))
    img.putalpha(a)
    save(img, name)
    return img


def icon_canvas():
    C = Canvas(128, 128, 0, SS, "L")
    return C


def ring(C):
    C.ring(64, 64, 60, 4, 255)
    C.ring(64, 64, 53.5, 1.6, 255)


def icon_quests():
    C = icon_canvas()
    ring(C)
    # scroll
    C.rrect((30, 70, 98, 96), 6, outline=255, width=4)
    C.ellipse((24, 70, 38, 96), outline=255, width=4)
    C.ellipse((90, 70, 104, 96), outline=255, width=4)
    for y in (79, 87):
        C.line([(44, y), (84, y)], 255, 2.5)
    # pennant flag on a pole planted in the scroll
    C.line([(56, 72), (56, 26)], 255, 4)
    C.poly([(58, 26), (92, 36), (58, 48)], 255)
    C.circle(56, 24, 3.5, fill=255)
    return stamp_finish(C, "icon_quests", 321)


def icon_items():
    C = icon_canvas()
    ring(C)
    # satchel body + flap + buckle + strap
    C.arc((34, 14, 94, 64), 200, 340, 255, 4)
    C.rrect((28, 46, 100, 100), 9, outline=255, width=4.5)
    C.poly([(28, 52), (100, 52), (100, 70), (64, 78), (28, 70)], 255)
    C.rrect((57, 66, 71, 84), 3, fill=0, outline=255, width=3)
    C.line([(64, 72), (64, 90)], 255, 3)
    C.line([(36, 92), (92, 92)], 255, 2)
    return stamp_finish(C, "icon_items", 322)


def icon_mags():
    C = icon_canvas()
    ring(C)
    # back page offset, front cover
    C.poly([(42, 30), (92, 26), (96, 98), (46, 102)], 255)
    C.poly([(45, 34), (89, 30), (92, 95), (49, 98)], 0)
    C.rect((32, 30, 82, 102), fill=255)
    C.rect((36, 34, 78, 98), fill=0)
    C.rect((36, 34, 78, 50), fill=255)                     # masthead band
    C.rect((42, 40, 72, 44), fill=0)
    # starburst on cover
    pts = []
    for i in range(16):
        r = 15 if i % 2 == 0 else 7
        a = math.radians(i * 22.5 - 90)
        pts.append((57 + r * math.cos(a), 72 + r * math.sin(a)))
    C.poly(pts, 255)
    C.line([(40, 92), (74, 92)], 255, 2.5)
    return stamp_finish(C, "icon_mags", 323)


def icon_radio():
    C = icon_canvas()
    ring(C)
    C.line([(80, 40), (98, 16)], 255, 3)                    # antenna
    C.circle(98, 15, 3.5, fill=255)
    C.rrect((28, 38, 100, 98), 12, outline=255, width=4.5)
    # speaker grille (dots)
    for gx in range(4):
        for gy in range(4):
            C.circle(42 + gx * 9, 54 + gy * 9, 2.6, fill=255)
    # dial
    C.circle(82, 66, 12, outline=255, width=3.5)
    C.line([(82, 66), (88, 58)], 255, 3)
    C.rect((36, 86, 92, 90), fill=255)
    for k in range(6):
        C.rect((40 + k * 9, 82, 41.5 + k * 9, 86), fill=255)
    return stamp_finish(C, "icon_radio", 324)


def icon_map():
    C = icon_canvas()
    ring(C)
    panels = [[(24, 36), (50, 28), (50, 96), (24, 104)], [(50, 28), (78, 36), (78, 104), (50, 96)],
              [(78, 36), (104, 28), (104, 96), (78, 104)]]
    for k, pts in enumerate(panels):
        C.poly(pts, 255)
        inset = [(pts[0][0] + 3.5, pts[0][1] + 4.5), (pts[1][0] - 3.5, pts[1][1] + 4.5),
                 (pts[2][0] - 3.5, pts[2][1] - 4.5), (pts[3][0] + 3.5, pts[3][1] - 4.5)]
        C.poly(inset, 0 if k != 1 else 0)
    # dashed route + X
    route = [(32, 88), (42, 74), (56, 80), (64, 62), (76, 58), (84, 46)]
    for (x0, y0), (x1, y1) in zip(route[:-1], route[1:]):
        C.line([(x0, y0), (x0 + (x1 - x0) * 0.6, y0 + (y1 - y0) * 0.6)], 255, 3)
    C.line([(86, 38), (98, 50)], 255, 4)
    C.line([(98, 38), (86, 50)], 255, 4)
    return stamp_finish(C, "icon_map", 325)


def icon_settings():
    C = icon_canvas()
    ring(C)
    cx, cy, r = 64, 64, 34
    pts = []
    teeth = 10
    for i in range(teeth * 4):
        a = i * 2 * math.pi / (teeth * 4) + 0.1
        rr = r if (i % 4) in (1, 2) else r * 0.78
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    C.poly(pts, 255)
    C.circle(cx, cy, 13, fill=0)
    C.circle(cx, cy, 20, outline=0, width=2.5)
    return stamp_finish(C, "icon_settings", 326)


# --------------------------------------------------------------------------- compass strip
def compass_strip():
    W, H = 2048, 64
    ink = P["cream"]
    edge = hexc("1C1714")
    C = Canvas(W, H, edge + (0,), 2, "RGBA", wrap=True)
    ppd = W / 360.0
    labels = {0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SW", 270: "W", 315: "NW"}

    def draw(col, grow):
        # baseline rule
        C.rect((0, 50 - grow, W, 52 + grow), fill=col)
        for deg in range(0, 360, 5):
            x = deg * ppd
            if deg % 45 == 0:
                continue
            L = 14 if deg % 15 == 0 else 7
            wdt = 2.2 if deg % 15 == 0 else 1.4
            C.rect((x - wdt / 2 - grow, 50 - L - grow, x + wdt / 2 + grow, 51 + grow), fill=col)
            if deg % 15 == 0:
                C.text((x, 28), str(deg), ("franklin", 11), col, "ms", stroke=grow, stroke_fill=col)
        for deg, lab in labels.items():
            x = deg * ppd
            if lab == "N":
                # north: diamond pointer + bold letter
                C.poly([(x, 40 - grow), (x + 7 + grow, 50), (x, 60 + grow), (x - 7 - grow, 50)], col)
                C.text((x, 34), "N", ("georgia_b", 30), col, "ms", stroke=grow, stroke_fill=col)
            else:
                big = len(lab) == 1
                C.text((x, 34), lab, ("georgia_b", 26 if big else 19), col, "ms", stroke=grow, stroke_fill=col)
                C.rect((x - 1.6 - grow, 38 - grow, x + 1.6 + grow, 51 + grow), fill=col)

    draw(edge + (200,), 1.6)        # soft dark outline for legibility on bright skies
    draw(ink + (255,), 0)
    # north accent in mustard
    C.poly([(0, 42), (6, 50), (0, 58), (-6, 50)], P["red"] + (255,))
    img = C.final()
    save(img, "compass_strip")
    return img


ALL = [ui_paper, ui_leather, icon_quests, icon_items, icon_mags, icon_radio, icon_map, icon_settings, compass_strip]

if __name__ == "__main__":
    import sys
    only = sys.argv[1:]
    for fn in ALL:
        if not only or fn.__name__ in only:
            img = fn()
            if fn.__name__ in ("ui_paper", "ui_leather"):
                print("   tile_check (seam, interior):", tuple(round(v, 2) for v in tile_check(img)))
