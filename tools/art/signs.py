"""Storefront / street signs (opaque, full-rect) and their 1978 weathered variants: sign_<id>[_aged].png"""
from __future__ import annotations

import math

import numpy as np

from common import PAL, Canvas, age_sign, crystal_flower, hexc, mix, print_finish, save, shade
from illus import T, cd_emblem, cloud, gull, halcyon_logo, lighthouse, ribbon, starburst, sun, wave_lines, waves

P = PAL
INK = P["ink"]
STEEL = hexc("D8D4C8")
OLIVE = hexc("6E6F4E")
SIGN_GREEN = hexc("2D6A50")

MANIFEST = [
    ("sign_diner", "Marlow's Diner enamel storefront sign (script, coffee cup, starburst)", "Harbor Square diner facade, above door"),
    ("sign_general", "Harbor General Store painted wooden sign with anchors", "Harbor Square general store facade"),
    ("sign_cd_post", "Larkhaven Civil Defense Post enamel sign with CD-style emblem", "Civil Defense post (rifle pickup), Harbor Square"),
    ("sign_showroom", "Halcyon Showroom sign (navy, chrome edge, Halcyon lockup)", "Halcyon showroom storefront, Harbor Square"),
    ("sign_radio", "Larkhaven Free Radio - 1340 AM hand-painted wooden board", "Lighthouse keeper's cottage, by the door"),
    ("sign_shelter9", "HALCYON ASSURED SHELTER No. 9 stencil on olive steel, hazard stripes", "Above Shelter No. 9 gate in the bluff"),
    ("sign_gull_lane", "Gull Lane green-enamel street sign (512x128)", "Street sign post at Gull Lane corner"),
    ("sign_shelter_arrow", "SHELTER No. 9 -> directional arrow sign (512x128)", "Posts along Gull Lane / bluff road (dash to the shelter)"),
    ("sign_welcome", "Welcome to Larkhaven - Pop. 2,140 - Gateway to the Sea painted billboard (1024x512)", "Coast road town entrance"),
    ("sign_road_closed", "ROAD CLOSED barricade sign by order of Civil Defense (512x256)", "Barricades on coast road / blocked streets"),
]
MANIFEST += [(n + "_aged", d + " - 1978 weathered: faded, rusted/chipped, overgrown with violet Bloom flowers",
              p + " (Ch.4, 11 years later)") for n, d, p in list(MANIFEST)]


# --------------------------------------------------------------------------- helpers
def finish(C, seed):
    return print_finish(C.final(), seed, grain=0.55, mottle=0.35, misreg=0.0)


def fit_logo(C, box, **kw):
    """Draw the Halcyon lockup on a scratch layer, trim to its real ink bounds and fit it into box (design px).
    Returns the right edge actually used."""
    from PIL import Image
    sub = C.sub(900, 300)
    halcyon_logo(sub, 20, 130, 150, **kw)
    im = sub.img.crop(sub.img.getchannel("A").getbbox())
    x0, y0, x1, y1 = box
    sc = min((x1 - x0) * C.s / im.width, (y1 - y0) * C.s / im.height)
    im = im.resize((int(im.width * sc), int(im.height * sc)), Image.LANCZOS)
    X, Y = int(x0 * C.s), int(((y0 + y1) / 2) * C.s - im.height / 2)
    C.img.paste(im, (X, Y), im)
    return x0 + im.width / C.s


def add_blooms(img, seed, n):
    """A few violet Bloom crystal flowers near the bottom edge (fewer than overgrow() would add)."""
    w, h = img.size
    C = Canvas(w, h, (0, 0, 0, 0), 2, "RGBA")
    rng = np.random.default_rng(seed)
    for _ in range(n):
        x = rng.uniform(0.04, 0.96) * w
        y = h - rng.uniform(0.02, 0.22) * h
        crystal_flower(C, x, y, rng.uniform(6, 11) * max(0.8, h / 256), seed=int(rng.integers(1e6)))
    base = img.convert("RGBA")
    base.alpha_composite(C.final())
    return base.convert("RGB")


def out(img, name, seed, aged_kw, blooms=3):
    save(img, name)
    kw = dict(aged_kw)
    kw.setdefault("blooms", False)
    aged = age_sign(img, seed + 500, **kw)
    save(add_blooms(aged, seed + 900, blooms), name + "_aged")


def bolt(C, x, y, r=7, col=STEEL):
    C.circle(x + 1, y + 1.5, r, fill=shade(col, 0.55))
    C.circle(x, y, r, fill=col)
    C.circle(x - r * 0.25, y - r * 0.25, r * 0.45, fill=mix(col, P["white"], 0.6))
    C.line([(x - r * 0.6, y + r * 0.35), (x + r * 0.6, y - r * 0.35)], shade(col, 0.5), max(1.2, r * 0.25))


def corner_bolts(w, h, inset=18):
    return [(inset, inset), (w - inset, inset), (inset, h - inset), (w - inset, h - inset)]


def planks(C, box, base, n=4, seed=0, vertical=False):
    """Painted-wood boards with grain lines and seams."""
    rng = np.random.default_rng(seed)
    x0, y0, x1, y1 = box
    C.rect(box, fill=base)
    for i in range(n):
        if vertical:
            a, b = x0 + (x1 - x0) * i / n, x0 + (x1 - x0) * (i + 1) / n
        else:
            a, b = y0 + (y1 - y0) * i / n, y0 + (y1 - y0) * (i + 1) / n
        tone = shade(base, rng.uniform(0.94, 1.0)) if rng.random() < 0.5 else mix(base, P["white"], rng.uniform(0, 0.05))
        C.rect((a, y0, b, y1) if vertical else (x0, a, x1, b), fill=tone)
        for _ in range(7):
            p = rng.uniform(a + 3, b - 3)
            L = rng.uniform(0.2, 0.7) * ((y1 - y0) if vertical else (x1 - x0))
            s0 = rng.uniform(y0 if vertical else x0, (y1 if vertical else x1) - L)
            pts = []
            for k in range(20):
                u = s0 + L * k / 19
                off = math.sin(k / 3 + p) * 1.5
                pts.append((p + off, u) if vertical else (u, p + off))
            C.line(pts, shade(tone, 0.9), 1.2)
        if i:
            C.line([(a, y0), (a, y1)] if vertical else [(x0, a), (x1, a)], shade(base, 0.6), 2.2)


def hazard(C, box, a=P["mustard"], b=INK, step=34):
    x0, y0, x1, y1 = box
    C.rect(box, fill=a)
    h = y1 - y0
    x = x0 - h
    k = 0
    while x < x1 + h:
        if k % 2:
            C.poly([(x, y1), (x + step, y1), (x + step + h, y0), (x + h, y0)], b)
        x += step
        k += 1
    # clean off overdraw outside the band is not needed: band is drawn first and covered by later panels


def stencil_text(C, x, y, s, spec, fill, bg, tracking=0.0, anchor="m", bridge=0.065):
    """Stencil lettering: draw per character, then cut bridges through letters with closed counters."""
    f = C.font(spec)
    size = spec[1]
    widths = [f.getlength(ch) / C.s for ch in s]
    total = sum(widths) + tracking * (len(s) - 1)
    cx = x - total / 2 if anchor == "m" else x
    bb = f.getbbox("H", anchor="ls")
    top, bot = bb[1] / C.s, bb[3] / C.s
    for ch, wch in zip(s, widths):
        C.text((cx, y), ch, spec, fill, "ls")
        mid = cx + wch / 2
        bw = size * bridge
        ht = bot - top
        cut = ht * 0.2      # bridges only sever the outer strokes, classic stencil style
        if ch in "ABDOPQR089&":
            C.rect((mid - bw / 2, y + top - 2, mid + bw / 2, y + top + cut), fill=bg)
            if ch in "BDOQ068&":
                C.rect((mid - bw / 2, y + bot - cut, mid + bw / 2, y + bot + 2), fill=bg)
            if ch in "B8":
                C.rect((mid - bw / 2, y + top + ht * 0.4, mid + bw / 2, y + top + ht * 0.6), fill=bg)
        elif ch == "o":
            ob = f.getbbox("o", anchor="ls")
            C.rect((mid - bw / 2, y + ob[1] / C.s - 2, mid + bw / 2, y + ob[1] / C.s + size * 0.09), fill=bg)
            C.rect((mid - bw / 2, y - size * 0.09, mid + bw / 2, y + 2), fill=bg)
        cx += wch + tracking


# --------------------------------------------------------------------------- 1 diner
def coffee_cup(C, cx, cy, s, cup=P["cream"], band=P["red"], steam=P["cream"]):
    t = T(cx, cy, s)
    for k, dx in enumerate((-14, 0, 14)):
        pts = [t(dx + 6 * math.sin(v / 7 + k), -40 - v) for v in range(0, 44, 2)]
        C.line(pts, steam, t.r(4.5))
    C.ellipse(t.box(-56, 30, 56, 48), fill=shade(cup, 0.82))           # saucer
    C.arc(t.box(24, -24, 60, 18), 270, 90, cup, t.r(9))                  # handle
    C.poly(t.pts([(-40, -32), (40, -32), (32, 30), (-32, 30)]), cup)
    C.rect(t.box(-38, -16, 38, -4), fill=band)
    C.ellipse(t.box(-40, -38, 40, -26), fill=shade(cup, 0.9))
    C.ellipse(t.box(-34, -36, 34, -28), fill=P["wood_dk"])


def sign_diner():
    w, h = 1024, 256
    C = Canvas(w, h, P["teal"])
    C.rrect((10, 10, w - 10, h - 10), 26, fill=P["cream"])
    C.rrect((22, 22, w - 22, h - 22), 18, outline=P["red"], width=3)
    # left cup medallion
    C.circle(124, 122, 82, fill=P["red"])
    C.circle(124, 122, 72, outline=P["cream"], width=3)
    coffee_cup(C, 124, 132, 1.0)
    # script
    C.text((508, 132), "Marlow's", ("script_b", 112), P["red"], "mm", stroke=5, stroke_fill=P["mustard"],
           shadow=(5, 6, P["teal"]))
    C.rect((250, 196, 770, 199), fill=P["teal"])
    C.text((510, 216), "COFFEE  ·  PIE  ·  CHOWDER  ·  OPEN 6 A.M.", ("franklin", 19), P["teal"], "mm", 3)
    # DINER in starburst
    starburst(C, 892, 122, 100, 74, 16, P["mustard"], 0)
    C.circle(892, 122, 66, fill=P["teal"])
    C.text((892, 108), "DINER", ("black", 30), P["cream"], "mm", 1)
    C.text((892, 146), "EST. 1952", ("franklin", 14), P["mustard"], "mm", 2)
    for x, y in [(36, 36), (w - 36, 36), (36, h - 36), (w - 36, h - 36)]:
        bolt(C, x, y, 6)
    out(finish(C, 201), "sign_diner", 201,
        dict(rust=0.33, fade=0.5, chips=0.35, overgrowth=0.48, bolts=[(36, 36), (w - 36, 36)]))


# --------------------------------------------------------------------------- 2 general store
def anchor(C, cx, cy, s, col):
    t = T(cx, cy, s)
    C.ring(*t(0, -62), t.r(12), t.r(6), col)
    C.rect(t.box(-5, -50, 5, 52), fill=col)
    C.rect(t.box(-30, -38, 30, -28), fill=col)
    C.arc(t.box(-50, -10, 50, 62), 15, 165, col, t.r(10))
    for sx in (-1, 1):
        C.poly(t.pts([(sx * 52, 20), (sx * 40, 34), (sx * 60, 38)]), col)


def sign_general():
    w, h = 1024, 256
    C = Canvas(w, h, P["wood_dk"])
    planks(C, (0, 0, w, h), P["navy"], 4, 3)
    C.rect((14, 14, w - 14, h - 14), outline=P["cream"], width=4)
    C.rect((24, 24, w - 24, h - 24), outline=P["mustard"], width=2)
    anchor(C, 100, 128, 1.15, P["cream"])
    anchor(C, w - 100, 128, 1.15, P["cream"])
    C.text((w / 2, 74), "HARBOR", ("georgia_b", 82), P["cream"], "mm", 18, shadow=(3, 4, shade(P["navy"], 0.5)))
    C.rect((250, 124, 330, 127), fill=P["mustard"])
    C.rect((w - 330, 124, w - 250, 127), fill=P["mustard"])
    C.text((w / 2, 126), "GENERAL", ("georgia_bi", 34), P["mustard"], "mm", 6)
    C.text((w / 2, 180), "STORE", ("georgia_b", 56), P["cream"], "mm", 22, shadow=(3, 4, shade(P["navy"], 0.5)))
    C.text((w / 2, 225), "GROCERIES · TACKLE · HARDWARE · EST. 1911", ("franklin", 15), P["mustard"], "mm", 3)
    nails = [(40, 40), (w - 40, 40), (40, h - 40), (w - 40, h - 40)]
    for x, y in nails:
        C.circle(x, y, 4, fill=hexc("6B6B6B"))
    out(finish(C, 202), "sign_general", 202,
        dict(rust=0.06, fade=0.55, chips=0.56, overgrowth=0.64, metal=False, bolts=nails[:2]))


# --------------------------------------------------------------------------- 3 civil defense post
def sign_cd_post():
    w, h = 1024, 256
    C = Canvas(w, h, P["navy"])
    C.rrect((10, 10, w - 10, h - 10), 14, fill=hexc("F4F0E6"))
    C.rrect((22, 22, w - 22, h - 22), 8, outline=P["navy"], width=5)
    cd_emblem(C, 140, 128, 92)
    C.text((262, 62), "LARKHAVEN", ("franklin", 30), P["red"], "lm", 12)
    C.text((258, 128), "CIVIL DEFENSE POST", ("bahn", 76, {"wght": 700, "wdth": 75}), P["navy"], "lm", 2)
    C.rect((262, 168, w - 48, 172), fill=P["red"])
    C.text((262, 200), "POST No. 3  ·  REPORT HERE IN AN EMERGENCY  ·  RADIO · FIRST AID · SUPPLIES",
           ("franklin", 16), P["navy"], "lm", 1.5)
    b = corner_bolts(w, h, 36)
    for x, y in b:
        bolt(C, x, y, 6)
    out(finish(C, 203), "sign_cd_post", 203, dict(rust=0.45, fade=0.4, chips=0.42, overgrowth=0.4, bolts=b[:2]))


# --------------------------------------------------------------------------- 4 showroom
def sign_showroom():
    w, h = 1024, 256
    C = Canvas(w, h, STEEL)
    C.rrect((0, 0, w, h), 30, fill=hexc("B9B4A6"))
    C.rrect((6, 6, w - 6, h - 6), 26, fill=STEEL)
    C.rect((10, 12, w - 10, 20), fill=mix(STEEL, P["white"], 0.6))
    C.rrect((18, 18, w - 18, h - 18), 20, fill=P["navy"])
    # boomerang accents
    C.poly([(18, 210), (420, 196), (440, 238), (18, 238)], shade(P["navy"], 0.8))
    right = fit_logo(C, (46, 40, 460, 214), fg=P["cream"], accent=P["mustard"], bg=P["navy"], tagline=True)
    dx = right + 28
    C.rect((dx, 46, dx + 3, 210), fill=P["mustard"])
    cx = (dx + w - 30) / 2 + 4
    C.text_fit((cx, 104), "SHOWROOM", "bahn", w - 50 - dx, 96, P["mustard"], "mm", 6, axes={"wght": 600, "wdth": 75})
    C.text_fit((cx, 172), "STARLIGHT TV  ·  VALET Mk II  ·  APPLIANCES", "franklin", w - 50 - dx, 18, P["cream"], "mm", 2.0)
    for x, y, r in [(960, 48, 13), (990, 200, 9), (dx + 10, 228, 7)]:
        starburst(C, x, y, r, r * 0.22, 4, P["mustard"])
    out(finish(C, 204), "sign_showroom", 204,
        dict(rust=0.27, fade=0.45, chips=0.28, overgrowth=0.48, bolts=[(60, 10), (w - 60, 10)]))


# --------------------------------------------------------------------------- 5 radio
def sign_radio():
    w, h = 1024, 256
    C = Canvas(w, h, P["wood"])
    planks(C, (0, 0, w, h), P["cream"], 3, 5)
    C.rect((10, 10, w - 10, h - 10), outline=P["teal"], width=6)
    # lighthouse with broadcast arcs
    lighthouse(C, 110, 236, 200, P["white"], P["red"], P["red"], P["mustard"], INK, 3, beams=False)
    ly = 236 - 200 * 0.78
    for k in range(3):
        r = 30 + k * 22
        C.arc((110 - r, ly - r, 110 + r, ly + r), 200, 250, P["teal"], 5)
        C.arc((110 - r, ly - r, 110 + r, ly + r), 290, 340, P["teal"], 5)
    C.text((222, 72), "LARKHAVEN", ("georgia_b", 40), P["teal"], "lm", 10)
    C.text((218, 142), "Free Radio", ("script_b", 74), P["red"], "lm")
    C.text((226, 212), "MUSIC · NEWS · FRIENDLY VOICES · ALL WELCOME", ("franklin", 16), P["teal"], "lm", 2)
    # dial badge
    C.circle(868, 128, 98, fill=P["teal"])
    C.circle(868, 128, 88, outline=P["cream"], width=3)
    for i in range(24):
        a = math.radians(i * 15)
        r0 = 76 if i % 2 else 70
        C.line([(868 + r0 * math.cos(a), 128 + r0 * math.sin(a)), (868 + 84 * math.cos(a), 128 + 84 * math.sin(a))],
               P["cream"], 2)
    C.text((868, 116), "1340", ("black", 46), P["mustard"], "mm")
    C.text((868, 160), "A M", ("franklin", 24), P["cream"], "mm", 4)
    nails = [(30, 30), (w - 30, 30), (30, h - 30), (w - 30, h - 30)]
    for x, y in nails:
        C.circle(x, y, 4, fill=hexc("6B6B6B"))
    out(finish(C, 205), "sign_radio", 205,
        dict(rust=0.06, fade=0.3, chips=0.32, overgrowth=0.36, metal=False, bolts=nails[:2]))


# --------------------------------------------------------------------------- 6 shelter 9 stencil
def sign_shelter9():
    w, h = 1024, 256
    C = Canvas(w, h, OLIVE)
    hazard(C, (0, 0, w, 30))
    hazard(C, (0, h - 30, w, h))
    C.rect((0, 30, w, h - 30), fill=OLIVE)
    C.rect((0, 30, w, 34), fill=shade(OLIVE, 0.7))
    C.rect((0, h - 34, w, h - 30), fill=shade(OLIVE, 0.7))
    cream = hexc("EDE6D2")
    spec1 = ("bahn", 46, {"wght": 700, "wdth": 75})
    spec2 = ("bahn", 104, {"wght": 700, "wdth": 75})
    stencil_text(C, w / 2, 92, "HALCYON  ASSURED", spec1, cream, OLIVE, 10)
    stencil_text(C, w / 2, 200, "SHELTER No. 9", spec2, P["mustard"], OLIVE, 6)
    C.rect((150, 108, 300, 112), fill=cream)
    C.rect((w - 300, 108, w - 150, 112), fill=cream)
    b = [(26, 58), (w - 26, 58), (26, h - 58), (w - 26, h - 58), (w / 2, 58)]
    for x, y in b[:4]:
        bolt(C, x, y, 8, hexc("A8A89A"))
    out(finish(C, 206), "sign_shelter9", 206, dict(rust=0.54, fade=0.3, chips=0.49, overgrowth=0.72, bolts=b[:4]))


# --------------------------------------------------------------------------- 7 street sign
def sign_gull_lane():
    w, h = 512, 128
    C = Canvas(w, h, SIGN_GREEN)
    C.rrect((6, 6, w - 6, h - 6), 12, outline=P["white"], width=4)
    gull(C, 62, 72, 1.25, P["white"], 3.4)
    C.text((278, 66), "GULL LANE", ("bahn", 70, {"wght": 600, "wdth": 80}), P["white"], "mm", 4)
    C.text((278, 108), "100 – 199", ("franklin", 14), P["white"], "mm", 3)
    C.text((w - 30, 30), "N", ("franklin", 14), P["white"], "mm")
    C.line([(w - 30, 44), (w - 30, 60)], P["white"], 2)
    b = [(28, 24), (w - 60, 24)]
    out(finish(C, 207), "sign_gull_lane", 207, dict(rust=0.42, fade=0.45, chips=0.42, overgrowth=0.32, bolts=b))


# --------------------------------------------------------------------------- 8 shelter arrow
def sign_shelter_arrow():
    w, h = 512, 128
    C = Canvas(w, h, INK)
    C.rect((4, 4, w - 4, h - 4), fill=P["mustard"])
    C.rect((10, 10, w - 10, h - 10), outline=INK, width=3)
    C.circle(62, 64, 40, fill=P["navy"])
    C.ring(62, 64, 34, 2.5, P["mustard"])
    C.text((62, 66), "9", ("black", 46), P["cream"], "mm")
    C.text((112, 56), "SHELTER No. 9", ("bahn", 52, {"wght": 700, "wdth": 75}), INK, "lm", 2)
    C.text((114, 98), "HALCYON ASSURED · ½ MILE", ("franklin", 15), INK, "lm", 2)
    # arrow
    C.poly([(392, 50), (448, 50), (448, 28), (494, 64), (448, 100), (448, 78), (392, 78)], P["red"])
    b = [(24, 64), (w - 14, 18)]
    out(finish(C, 208), "sign_shelter_arrow", 208, dict(rust=0.42, fade=0.5, chips=0.42, overgrowth=0.4, bolts=[(30, 14), (w - 30, 14)]))


# --------------------------------------------------------------------------- 9 welcome billboard
def sign_welcome():
    w, h = 1024, 512
    C = Canvas(w, h, P["wood_dk"])
    planks(C, (0, 0, w, h), P["wood"], 6, 9)
    x0, y0, x1, y1 = 30, 30, w - 30, h - 30
    # painted scene
    C.rect((x0, y0, x1, y1), fill=P["sky"])
    C.rect((x0, y0, x1, y0 + 120), fill=mix(P["sky"], P["cream"], 0.45))
    sun(C, 905, 118, 56, P["mustard"], 18, 0.35)
    cloud(C, 610, 72, 130, P["white"])
    # sea and headland
    C.rect((x0, 330, x1, y1), fill=P["teal"])
    for k in range(4):
        wave_lines(C, 350 + k * 28, x0, x1, 4, 60, mix(P["teal"], P["cream"], 0.4), 3, k)
    C.poly([(700, 340), (770, 304), (880, 292), (x1, 300), (x1, 400), (700, 400)], hexc("4E6B3A"))
    lighthouse(C, 880, 300, 200, P["white"], P["red"], P["red"], P["mustard"], INK, 3, beams=False)
    for x, y, s in [(500, 282, 1.1), (560, 262, 0.85), (640, 290, 0.7)]:
        gull(C, x, y, s, INK)
    # sand
    waves(C, 440, x0, x1, 6, 140, hexc("E8D4A2"), y1 - 440)
    C.rect((x0, y1 - 4, x1, y1), fill=hexc("E8D4A2"))
    # lettering
    C.text((70, 92), "Welcome to", ("script_b", 56), P["red"], "lm")
    C.text_fit((64, 196), "LARKHAVEN", "black", 720, 118, P["cream"], "lm", 2, stroke=4, stroke_fill=P["navy"],
               shadow=(6, 7, P["navy"]))
    C.rrect((70, 262, 380, 312), 24, fill=P["red"])
    C.text((225, 288), "POP. 2,140", ("franklin", 30), P["cream"], "mm", 4)
    ribbon(C, 340, 450, 470, 52, P["navy"], "Gateway to the Sea", ("georgia_bi", 34), P["cream"])
    # frame
    C.rect((x0 - 4, y0 - 4, x1 + 4, y1 + 4), outline=P["cream"], width=6)
    nails = [(15, 15), (w - 15, 15), (15, h - 15), (w - 15, h - 15)]
    out(finish(C, 209), "sign_welcome", 209,
        dict(rust=0.06, fade=0.55, chips=0.56, overgrowth=0.72, metal=False, bolts=nails[:2]))


# --------------------------------------------------------------------------- 10 road closed
def sign_road_closed():
    w, h = 512, 256
    C = Canvas(w, h, P["white"])
    C.rect((0, 0, w, 160), fill=hexc("F4F0E6"))
    C.rect((10, 10, w - 10, 150), outline=INK, width=6)
    C.text((w / 2, 66), "ROAD CLOSED", ("bahn", 78, {"wght": 700, "wdth": 75}), INK, "mm", 4)
    C.text((w / 2, 124), "BY ORDER OF LARKHAVEN CIVIL DEFENSE", ("franklin", 16), P["red"], "mm", 2)
    # striped barricade rail
    C.rect((0, 160, w, h), fill=P["white"])
    x = -100
    k = 0
    while x < w + 100:
        if k % 2 == 0:
            C.poly([(x, h), (x + 46, h), (x + 46 + 96, 160), (x + 96, 160)], P["red"])
        x += 46
        k += 1
    C.rect((0, 158, w, 166), fill=INK)
    b = [(26, 210), (w - 26, 210)]
    for x_, y_ in b:
        bolt(C, x_, y_, 7)
    out(finish(C, 210), "sign_road_closed", 210, dict(rust=0.42, fade=0.45, chips=0.42, overgrowth=0.56, bolts=b))


ALL = [sign_diner, sign_general, sign_cd_post, sign_showroom, sign_radio, sign_shelter9, sign_gull_lane,
       sign_shelter_arrow, sign_welcome, sign_road_closed]

if __name__ == "__main__":
    import sys
    only = sys.argv[1:]
    for fn in ALL:
        if not only or fn.__name__ in only:
            fn()
