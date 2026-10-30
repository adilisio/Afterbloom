"""Framed family photos (illustrated, painterly, faded print finish): photo_<id>.png

Landscape 768x576, portrait 576x768. Each is an illustration drawn at the inner
size, then given a soft painterly wobble, faded colour (or sepia), grain,
vignette, and a white print border with light age.
"""
from __future__ import annotations

import math

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

from common import PAL, Canvas, age_paper, from_np, hexc, mix, noise, save, shade, to_np
from illus import T, cloud, ellipse_pts, gull, halcyon_logo, lighthouse, ribbon, starburst, sun, tuppence, tv_set, wave_lines

P = PAL
INK = P["ink"]
SKIN = hexc("EDC09A")
SKIN_D = hexc("D49C76")

MANIFEST = [
    ("photo_beach", "Framed photo: two siblings at the beach at sunset, seen from behind (768x576)", "Living room mantel / player's bedroom"),
    ("photo_lighthouse", "Framed photo: Larkhaven Light and keeper's cottage with radio mast (768x576)", "Hallway wall; lighthouse cottage"),
    ("photo_june", "Framed photo: stylized portrait of June, the player's sister (576x768)", "Player's bedroom nightstand; journal"),
    ("photo_tuppence", "Framed photo: Tuppence 'Employee of the Month', Sept 1967 (768x576)", "Kitchen wall / Halcyon showroom"),
    ("photo_parents", "Framed photo: parents' wedding, sepia silhouettes in an oval vignette (576x768)", "Living room side table"),
]


def photo_finish(img, seed, sepia=False, border=18, bottom=None, caption=None, wobble=4.0, age=0.3):
    """Painterly wobble + faded print + white border. img is the inner picture (RGB)."""
    a = to_np(img.convert("RGB"))
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    nx = noise(w, h, w / 16, seed, 3) - 0.5
    ny = noise(w, h, w / 16, seed + 1, 3) - 0.5
    for c in range(3):
        a[..., c] = ndimage.map_coordinates(a[..., c], [yy + ny * wobble * 2, xx + nx * wobble * 2], order=1, mode="reflect")
    img = from_np(a, "RGB").filter(ImageFilter.GaussianBlur(0.9))
    a = to_np(img)
    # brush-stroke texture: short diagonal streaks modulate value
    rng = np.random.default_rng(seed + 2)
    r = rng.random((h, w)).astype(np.float32)
    streak = ndimage.uniform_filter(r, size=(1, 9))
    streak = ndimage.rotate(streak, 30, reshape=False, mode="wrap")
    a *= (1 + (streak - 0.5) * 0.22)[..., None]
    lum = a.mean(axis=2, keepdims=True)
    if sepia:
        t = np.clip(lum / 255, 0, 1)
        dark, light = np.array([62, 40, 26], np.float32), np.array([242, 226, 196], np.float32)
        a = dark + (light - dark) * t
    else:
        a = a * 0.8 + lum * 0.2          # slight desaturation
        a = a * 0.84 + 30                 # lifted blacks / faded
        a[..., 0] *= 1.04
        a[..., 2] *= 0.88
    # vignette
    d = np.sqrt(((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2)
    a *= (1 - 0.28 * np.clip(d - 0.55, 0, 1) ** 1.3)[..., None]
    a += (rng.random((h, w)).astype(np.float32)[..., None] - 0.5) * 14
    pic = from_np(a, "RGB")
    bottom = bottom if bottom is not None else border
    W2, H2 = w + 2 * border, h + border + bottom
    paper = Image.new("RGB", (W2, H2), (244, 240, 230))
    paper.paste(pic, (border, border))
    if caption:
        C = Canvas(W2, H2, (0, 0, 0, 0), 2, "RGBA")
        C.text((border + 6, h + border + bottom / 2 + 2), caption, ("inkfree", bottom * 0.55), hexc("2B3A67"), "lm")
        paper = paper.convert("RGBA")
        paper.alpha_composite(C.final())
    out = age_paper(paper, seed + 9, amount=age, stains=0, tears=False, creases=0, foxing=12, fade=0.1)
    return out.convert("RGB")


def gradient(C, box, c0, c1):
    m = C.mask()
    m.rect(box, fill=255)
    x0, y0, x1, y1 = box
    C.gradient_mask(m, c0, c1, x0, y0, x0, y1)


# =========================================================================== figures from behind
def kid_back(C, x, base, h, hair, top, bottom, girl=False, hand_to=None, other_hand=None, pail=False, stripes=None):
    """A child seen from behind. hand_to = (x, y) the inner hand reaches to (holding hands)."""
    u = h / 100
    # legs
    for sx in (-1, 1):
        C.rrect((x + sx * 5 * u - 4 * u, base - 40 * u, x + sx * 5 * u + 4 * u, base), 3 * u, fill=SKIN)
    if not girl:
        for sx in (-1, 1):
            C.rrect((x + sx * 5 * u - 5 * u, base - 50 * u, x + sx * 5 * u + 5 * u, base - 20 * u), 2 * u, fill=bottom)
    # torso / dress
    if girl:
        C.poly([(x - 10 * u, base - 68 * u), (x + 10 * u, base - 68 * u), (x + 17 * u, base - 34 * u), (x - 17 * u, base - 34 * u)], top)
        C.rect((x - 10 * u, base - 70 * u, x + 10 * u, base - 64 * u), fill=shade(top, 0.85))
    else:
        C.rrect((x - 11 * u, base - 72 * u, x + 11 * u, base - 46 * u), 4 * u, fill=top)
        if stripes:
            for k in range(4):
                yy = base - 68 * u + k * 6 * u
                C.rect((x - 11 * u, yy, x + 11 * u, yy + 2.4 * u), fill=stripes)
    # arms
    sh_y = base - 68 * u
    for sx in (-1, 1):
        sx_x = x + sx * 10 * u
        if hand_to and ((hand_to[0] - x) * sx > 0):
            C.line([(sx_x, sh_y), hand_to], SKIN, 4 * u)
            C.circle(*hand_to, 3 * u, fill=SKIN)
        else:
            hx, hy = (x + sx * 15 * u, base - 42 * u)
            C.line([(sx_x, sh_y), (hx, hy)], SKIN, 4 * u)
            C.circle(hx, hy, 3 * u, fill=SKIN)
            if pail and sx == -1:
                C.poly([(hx - 6 * u, hy + 4 * u), (hx + 6 * u, hy + 4 * u), (hx + 4.5 * u, hy + 15 * u), (hx - 4.5 * u, hy + 15 * u)], P["red"])
                C.arc((hx - 6 * u, hy - 4 * u, hx + 6 * u, hy + 10 * u), 180, 360, INK, 1)
    # head (back of head = hair)
    C.rect((x - 3 * u, base - 78 * u, x + 3 * u, base - 70 * u), fill=SKIN_D)
    C.circle(x, base - 86 * u, 10 * u, fill=hair)
    if girl:
        for sx in (-1, 1):
            C.ellipse((x + sx * 12 * u - 4 * u, base - 86 * u, x + sx * 12 * u + 4 * u, base - 72 * u), fill=hair)
            C.circle(x + sx * 10 * u, base - 87 * u, 2.6 * u, fill=P["coral"])
    else:
        C.chord((x - 10 * u, base - 96 * u, x + 10 * u, base - 74 * u), 0, 180, fill=shade(hair, 0.85))
    # long evening shadow toward the camera
    return


# =========================================================================== beach
def photo_beach():
    w, h = 732, 540
    C = Canvas(w, h, P["cream"])
    gradient(C, (0, 0, w, 260), mix(P["coral_lt"], P["navy_lt"], 0.25), P["mustard_lt"])
    sun(C, 470, 252, 46, mix(P["mustard"], P["white"], 0.4), 0)
    C.glow(470, 252, 140, P["mustard_lt"], 0.6, 1.4)
    cloud(C, 160, 90, 180, mix(P["coral_lt"], P["white"], 0.4))
    cloud(C, 600, 60, 130, mix(P["coral_lt"], P["white"], 0.5))
    # sea
    C.rect((0, 260, w, 360), fill=mix(P["teal"], P["navy"], 0.25))
    for k in range(8):
        wave_lines(C, 270 + k * 11, -10, w + 10, 2, 40 + 6 * k, mix(P["teal"], P["white"], 0.3), 1.5, k)
    for k in range(10):
        y = 262 + k * 9
        ww = 20 + k * 8
        C.line([(470 - ww / 2, y), (470 + ww / 2, y)], mix(P["mustard_lt"], P["white"], 0.5), 2.5)
    # headland + tiny lighthouse
    C.poly([(600, 262), (650, 240), (732, 236), (732, 262)], hexc("50624F"))
    lighthouse(C, 690, 240, 50, P["cream"], P["red"], P["red"], P["mustard"], INK, 3, False)
    # surf + sand
    C.poly([(0, 350), (w, 342), (w, h), (0, h)], hexc("D9BE8E"))
    C.poly([(0, 350), (w, 342), (w, 372), (0, 382)], hexc("C3A273"))  # wet sand
    for k in range(3):
        wave_lines(C, 352 + k * 6, -10, w + 10, 3, 90, mix(P["white"], P["teal_lt"], 0.2), 3 - k * 0.6, k * 2)
    # footprints
    for k in range(9):
        y = h - 10 - k * 18
        x = 470 + k * 16
        C.ellipse((x - 14, y - 4, x - 6, y + 4), fill=hexc("C3A273"))
        C.ellipse((x + 6 - (k % 2) * 4, y - 12, x + 14 - (k % 2) * 4, y - 4), fill=hexc("C3A273"))
    # shadows
    C.poly([(312, 488), (348, 488), (330, 540), (280, 540)], hexc("C8AA7C"))
    C.poly([(392, 488), (420, 488), (416, 540), (380, 540)], hexc("C8AA7C"))
    # the siblings, holding hands
    kid_back(C, 330, 488, 250, hexc("5A3A26"), hexc("F4F0E4"), P["navy"], False, hand_to=(368, 420),
             stripes=P["navy_lt"])
    kid_back(C, 406, 488, 180, hexc("8A4A26"), P["coral"], None, True, hand_to=(368, 420), pail=False)
    # bucket and spade
    C.poly([(220, 470), (246, 470), (242, 498), (224, 498)], P["red"])
    C.arc((218, 458, 248, 488), 180, 360, INK, 2)
    C.line([(254, 498), (268, 452)], P["wood"], 3)
    C.poly([(262, 448), (276, 450), (272, 430), (266, 430)], P["teal"])
    for x, y, s in [(240, 150, 0.9), (275, 130, 0.7), (560, 170, 0.6)]:
        gull(C, x, y, s, hexc("4A4440"))
    img = photo_finish(C.final(), 301, border=18)
    save(img, "photo_beach")


# =========================================================================== lighthouse
def photo_lighthouse():
    w, h = 732, 540
    C = Canvas(w, h, P["cream"])
    gradient(C, (0, 0, w, 330), mix(P["sky"], P["navy_lt"], 0.35), mix(P["sky"], P["white"], 0.4))
    cloud(C, 140, 110, 220, P["white"], mix(P["sky"], P["navy_lt"], 0.3))
    cloud(C, 560, 70, 170, P["white"], mix(P["sky"], P["navy_lt"], 0.3))
    C.rect((0, 320, w, h), fill=mix(P["teal"], P["navy"], 0.35))
    for k in range(10):
        wave_lines(C, 330 + k * 20, -10, w + 10, 3, 60 + 7 * k, mix(P["teal"], P["white"], 0.25), 2, k)
    # rocky point
    C.poly([(170, 420), (240, 340), (340, 316), (520, 314), (620, 340), (700, 410), (732, 460), (732, h), (130, h)], hexc("6E6A5E"))
    C.poly([(240, 340), (340, 316), (520, 314), (620, 340), (560, 352), (300, 356)], hexc("7E8A5A"))  # grass cap
    for x, y, r in [(200, 450, 40), (660, 470, 50), (300, 500, 46), (520, 490, 60)]:
        C.ellipse((x - r, y - r * 0.5, x + r, y + r * 0.5), fill=hexc("5E5A50"))
    rng = np.random.default_rng(5)
    for x in range(150, 720, 22):
        y = 436 + 30 * max(0, (x - 560) / 160) - 10 * max(0, (260 - x) / 110) + rng.uniform(-4, 4)
        C.ellipse((x - 14, y - 4, x + 14, y + 4), fill=mix(P["white"], P["teal_lt"], 0.2))
    # keeper's cottage with Rory's radio mast
    C.rect((300, 270, 410, 336), fill=P["cream"])
    C.poly([(290, 272), (355, 230), (420, 272)], P["red"])
    C.rect((318, 290, 340, 312), fill=P["navy_lt"])
    C.rect((372, 296, 392, 336), fill=P["teal"])
    C.rect((380, 200, 386, 250), fill=hexc("6A6A6A"))
    C.line([(330, 240), (383, 112), (436, 240)], hexc("6A6A6A"), 2)
    C.line([(383, 112), (383, 250)], hexc("6A6A6A"), 3)
    for k in range(5):
        y = 130 + k * 22
        C.line([(383 - (y - 112) * 0.42, y), (383 + (y - 112) * 0.42, y)], hexc("8A8A8A"), 1)
    C.circle(383, 110, 4, fill=P["red"])
    lighthouse(C, 500, 330, 300, P["cream"], P["red"], P["red"], P["mustard"], INK, 3, False)
    for x, y, s in [(110, 230, 1.0), (150, 210, 0.7), (640, 200, 0.8)]:
        gull(C, x, y, s, hexc("4A4440"))
    img = photo_finish(C.final(), 302, border=18)
    save(img, "photo_lighthouse")


# =========================================================================== June
def photo_june():
    w, h = 540, 732
    C = Canvas(w, h, P["teal"])
    m = C.mask()
    m.rect((0, 0, w, h), fill=255)
    C.halftone_mask(m, mix(P["teal"], P["white"], 0.3), C.rad_tone(270, 300, 420, 0.9, 0.0), 9, 45)
    C.glow(270, 300, 300, mix(P["teal"], P["white"], 0.35), 0.7, 1.2)
    hair = hexc("7A3E22")
    hair_l = hexc("9A5530")
    cx = 270
    # hair back (bob with flipped ends)
    C.rrect((cx - 146, 150, cx + 146, 452), 140, fill=hair, corners=(True, True, False, False))
    C.ellipse((cx - 176, 402, cx - 100, 462), fill=hair)
    C.ellipse((cx + 100, 402, cx + 176, 462), fill=hair)
    C.arc((cx - 168, 410, cx - 112, 448), 120, 300, hair_l, 5)
    C.arc((cx + 112, 410, cx + 168, 448), 240, 60, hair_l, 5)
    # shoulders: mustard cardigan, white peter-pan collar
    C.rect((cx - 32, 430, cx + 32, 510), fill=SKIN_D)
    C.rrect((cx - 210, 492, cx + 210, h + 40), 110, fill=P["mustard"])
    C.poly([(cx - 4, 500), (cx + 4, 500), (cx + 30, h), (cx - 30, h)], shade(P["mustard"], 0.85))
    for k in range(3):
        C.circle(cx, 590 + k * 50, 6, fill=P["cream"])
    C.pieslice((cx - 96, 470, cx + 2, 556), 180, 360, fill=P["white"])
    C.pieslice((cx - 2, 470, cx + 96, 556), 180, 360, fill=P["white"])
    C.poly([(cx - 96, 513), (cx - 4, 500), (cx - 2, 520), (cx - 70, 540)], P["white"])
    C.poly([(cx + 96, 513), (cx + 4, 500), (cx + 2, 520), (cx + 70, 540)], P["white"])
    C.circle(cx, 524, 8, fill=P["red"])  # little brooch
    # face
    C.ellipse((cx - 92, 196, cx + 92, 452), fill=SKIN)
    C.ellipse((cx - 104, 300, cx - 80, 344), fill=SKIN)  # ears (peeking)
    C.ellipse((cx + 80, 300, cx + 104, 344), fill=SKIN)
    C.circle(cx - 92, 352, 5, fill=P["white"])           # pearl earrings
    C.circle(cx + 92, 352, 5, fill=P["white"])
    # bangs: side-swept fringe + headband
    C.chord((cx - 104, 170, cx + 104, 330), 180, 360, fill=hair)
    C.poly([(cx - 100, 250), (cx - 60, 270), (cx + 10, 262), (cx + 70, 240), (cx + 102, 252), (cx + 98, 210), (cx - 98, 210)], hair)
    C.arc((cx - 106, 168, cx + 106, 330), 196, 344, P["coral"], 12)
    C.line([(cx - 40, 222), (cx + 30, 246)], hair_l, 3)
    # brows, eyes
    for sx in (-1, 1):
        ex = cx + sx * 40
        C.arc((ex - 26, 272, ex + 26, 300), 205, 335, hexc("5A2E18"), 5)
        C.ellipse((ex - 13, 306, ex + 13, 330), fill=P["white"])
        C.ellipse((ex - 9, 306, ex + 9, 330), fill=hexc("4A6A5A"))
        C.circle(ex, 318, 5, fill=INK)
        C.circle(ex - 4, 313, 3, fill=P["white"])
        C.rect((ex - 15, 298, ex + 15, 310), fill=SKIN)                 # relaxed upper lid
        C.line([(ex - 14, 312), (ex, 308), (ex + 14, 312)], INK, 3.5)
        C.line([(ex + sx * 13, 311), (ex + sx * 20, 305)], INK, 2.5)   # lash flick
        C.arc((ex - 10, 318, ex + 10, 336), 30, 150, SKIN_D, 1.5)      # smile crease
    # nose, cheeks, freckles, smile
    C.arc((cx - 10, 350, cx + 10, 368), 20, 160, SKIN_D, 3)
    for sx in (-1, 1):
        C.glow(cx + sx * 54, 372, 26, mix(SKIN, P["coral"], 0.6), 0.6, 1.0)
        for fx, fy in [(-8, -6), (4, -10), (10, 2), (-2, 6), (-12, 4)]:
            C.circle(cx + sx * 50 + fx, 362 + fy, 1.8, fill=SKIN_D)
    C.chord((cx - 26, 382, cx + 26, 412), 0, 180, fill=hexc("B84A3A"))
    C.chord((cx - 19, 385, cx + 19, 401), 0, 180, fill=P["white"])
    C.arc((cx - 30, 376, cx + 30, 410), 20, 160, hexc("8A3A2A"), 2.5)
    img = photo_finish(C.final(), 303, border=18, bottom=18)
    save(img, "photo_june")


# =========================================================================== Tuppence
def rosette(C, x, y, r):
    C.poly([(x - r * 0.5, y), (x - r * 0.9, y + r * 2.2), (x - r * 0.4, y + r * 1.9), (x - r * 0.05, y + r * 2.3), (x, y)], P["red"])
    C.poly([(x + r * 0.5, y), (x + r * 0.9, y + r * 2.2), (x + r * 0.4, y + r * 1.9), (x + r * 0.05, y + r * 2.3), (x, y)], shade(P["red"], 0.8))
    starburst(C, x, y, r * 1.15, r * 0.85, 14, P["mustard"])
    C.circle(x, y, r * 0.62, fill=P["cream"])
    C.text((x, y + 1), "No.1", ("black", r * 0.5), P["red"], "mm")


def photo_tuppence():
    w, h = 732, 500
    C = Canvas(w, h, P["navy"])
    # showroom wall with sunburst panel
    C.rect((0, 0, w, 380), fill=mix(P["navy"], P["teal"], 0.25))
    for i in range(24):
        if i % 2:
            continue
        a0, a1 = math.radians(i * 15), math.radians((i + 1) * 15)
        C.poly([(366, 250), (366 + 800 * math.cos(a0), 250 + 800 * math.sin(a0)), (366 + 800 * math.cos(a1), 250 + 800 * math.sin(a1))],
               mix(P["navy"], P["teal"], 0.38))
    C.rect((0, 380, w, h), fill=hexc("C9B79A"))
    for x in range(0, w, 60):
        C.line([(x, 380), (x - 40, h)], hexc("B5A385"), 2)
    # banner
    ribbon(C, 366, 54, 470, 54, P["red"], "EMPLOYEE OF THE MONTH", ("black", 30), P["cream"])
    C.text((366, 104), "SEPTEMBER 1967", ("georgia_b", 20), P["mustard"], "mm", 4)
    # a Starlight on display at the right, a potted plant at the left
    tv_set(C, 640, 410, 150)
    C.poly([(60, 410), (110, 410), (102, 360), (68, 360)], P["coral"])
    for k, (dx, ln) in enumerate([(-40, 90), (-20, 120), (0, 140), (22, 115), (40, 85)]):
        C.line([(85, 362), (85 + dx, 362 - ln)], hexc("4E6B3A"), 6)
        C.ellipse((85 + dx - 10, 362 - ln - 16, 85 + dx + 10, 362 - ln + 8), fill=hexc("6E8B4A"))
    # Tuppence, beaming
    C.ellipse((290, 450, 460, 476), fill=shade(hexc("C9B79A"), 0.8))
    tuppence(C, 372, 140, 0.98, "thumbs")
    rosette(C, 330, 300, 17)
    # flash bloom on the brass
    C.glow(352, 260, 120, P["white"], 0.25, 1.5)
    img = photo_finish(C.final(), 304, border=18, bottom=58, wobble=1.6, caption="Our Tuppence — Employee of the Month! Sept. '67")
    save(img, "photo_tuppence")


# =========================================================================== parents (sepia)
def photo_parents():
    w, h = 540, 732
    C = Canvas(w, h, hexc("D8D0C0"))
    C.glow(270, 330, 360, P["white"], 0.9, 1.0)
    # floral arch
    for k in range(40):
        a = math.radians(180 + k * 180 / 39)
        x, y = 270 + 200 * math.cos(a), 300 + 230 * math.sin(a)
        C.circle(x, y, 14 if k % 2 else 10, fill=hexc("9A8E7A"))
        C.circle(x + 6, y - 4, 6, fill=hexc("C8BCA8"))
    C.rect((64, 296, 82, 700), fill=hexc("9A8E7A"))
    C.rect((458, 296, 476, 700), fill=hexc("9A8E7A"))
    C.rect((0, 660, w, h), fill=hexc("B8AE9C"))
    SIL = hexc("3A2E26")
    # groom (left)
    gx = 214
    C.rect((gx - 34, 440, gx - 4, 668), fill=SIL)
    C.rect((gx + 4, 440, gx + 34, 668), fill=SIL)
    C.ellipse((gx - 40, 656, gx - 2, 672), fill=SIL)
    C.ellipse((gx + 2, 656, gx + 40, 672), fill=SIL)
    C.rrect((gx - 52, 270, gx + 52, 500), 26, fill=SIL)
    C.rect((gx - 10, 236, gx + 10, 276), fill=SIL)
    C.ellipse((gx - 30, 178, gx + 30, 252), fill=SIL)
    C.ellipse((gx - 32, 172, gx + 34, 214), fill=SIL)
    C.ellipse((gx - 38, 204, gx - 26, 228), fill=SIL)
    C.ellipse((gx + 26, 204, gx + 38, 228), fill=SIL)
    C.circle(gx + 30, 300, 9, fill=hexc("E8E0D0"))  # boutonniere
    # bride (right): veil, fitted bodice, A-line skirt
    bx = 324
    C.poly([(bx - 16, 196), (bx + 30, 186), (bx + 120, 640), (bx + 40, 662), (bx - 40, 660)], hexc("BDB2A0"))   # veil
    C.poly([(bx - 26, 300), (bx + 26, 300), (bx + 96, 668), (bx - 96, 668)], hexc("4A3C32"))
    C.rrect((bx - 34, 262, bx + 34, 340), 18, fill=SIL)
    C.rect((bx - 8, 236, bx + 8, 266), fill=SIL)
    C.ellipse((bx - 28, 186, bx + 28, 250), fill=SIL)
    C.ellipse((bx - 36, 180, bx + 28, 224), fill=SIL)   # up-do
    C.ellipse((bx - 30, 176, bx + 10, 196), fill=hexc("E8E0D0"))  # veil comb
    # linked arms + bouquet
    C.line([(gx + 46, 320), (bx - 20, 360)], SIL, 22)
    C.line([(bx + 28, 300), (bx + 6, 380)], SIL, 14)
    for k in range(9):
        a = k * 40
        C.circle(bx - 4 + 18 * math.cos(math.radians(a)), 388 + 14 * math.sin(math.radians(a)), 11, fill=hexc("F2ECE0"))
    C.circle(bx - 4, 388, 10, fill=hexc("D8D0C0"))
    for k in range(4):
        C.line([(bx - 8 + k * 4, 398), (bx - 14 + k * 6, 452)], hexc("6A5A4A"), 2)
    img = C.final()
    # oval studio vignette
    a = to_np(img)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt(((xx - w / 2) / (w * 0.46)) ** 2 + ((yy - h * 0.47) / (h * 0.47)) ** 2)
    f = np.clip((d - 0.86) / 0.18, 0, 1)[..., None]
    a = a * (1 - f) + np.array([236, 230, 216], np.float32) * f
    img = from_np(a, "RGB")
    out = photo_finish(img, 305, sepia=True, border=18, bottom=18, wobble=3, age=0.55)
    save(out, "photo_parents")


ALL = [photo_beach, photo_lighthouse, photo_june, photo_tuppence, photo_parents]

if __name__ == "__main__":
    import sys
    only = sys.argv[1:]
    for fn in ALL:
        if not only or fn.__name__ in only:
            fn()
