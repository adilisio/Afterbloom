"""In-game TV graphics (640x480, 4:3) shown on the Halcyon Starlight under a CRT shader: tv_<id>.png

Bold shapes, big type, high contrast so they survive near-B&W display and scanlines.
"""
from __future__ import annotations

import math

import numpy as np
from PIL import Image, ImageFilter

from common import PAL, Canvas, crystal_flower, from_np, hexc, mix, noise, save, shade, to_np
from illus import (T, cd_emblem, cloud, comet, ellipse_pts, gull, halcyon_emblem, halcyon_logo, house, ht_rect, ht_shape,
                   lighthouse, mountains, pine, rocket, sedan, starburst, sun, tuppence, tv_set, wave_lines, waves)

W, H = 640, 480
P = PAL
INK = P["ink"]
V = P["violet"]

MANIFEST = [
    ("tv_larkhaven_morning", "TV title card: 'Larkhaven Morning' with Hal Brightwater (sunrise over the bay)", "Starlight TV screen, Ch.1 morning show intro"),
    ("tv_anchor", "TV: anchor Hal Brightwater at his desk, cheerful, 'Larkhaven Morning' backdrop", "Starlight TV screen, Ch.1 news segments"),
    ("tv_anchor_grave", "TV: Hal Brightwater, grave, dim red 'Civil Defense' backdrop", "Starlight TV screen, Ch.1 when news turns grave"),
    ("tv_weather_map", "TV: cartoon coastal weather map (sun/cloud icons, temps)", "Starlight TV screen, weather segment"),
    ("tv_comet", "TV: last night's Larkspur Comet over the bluff, tiny picnickers", "Starlight TV screen, news segment"),
    ("tv_harbor_dust", "TV: fishing boats in the harbour, shimmering violet dust on the water", "Starlight TV screen, news turns strange"),
    ("tv_cloud", "TV: studio-window view of a towering violet Bloom cloud rolling over the bay", "Starlight TV screen, just before the emergency broadcast"),
    ("tv_ad_starlight", "TV ad: Halcyon Starlight console television", "Starlight TV screen, ad break"),
    ("tv_ad_valet", "TV ad: Halcyon Valet Mk II robot butler", "Starlight TV screen, ad break"),
    ("tv_ad_sweetcorn", "TV ad: Sunny Crunch breakfast cereal", "Starlight TV screen, ad break"),
    ("tv_emergency", "TV: CIVIL DEFENSE EMERGENCY — proceed calmly to your assigned shelter", "Starlight TV screen, Ch.2 emergency broadcast"),
    ("tv_test_pattern", "TV: original Halcyon/KLHV-6 test pattern", "Starlight TV screen, off-air / idle"),
    ("tv_please_stand_by", "TV: PLEASE STAND BY card with flustered Tuppence", "Starlight TV screen, signal interruption"),
]

NIGHT = hexc("1B2440")


def broadcast_finish(img, seed=0, soft=0.5, grain=4.0):
    """Light broadcast softness + film grain; the CRT shader adds the rest."""
    img = img.convert("RGB").filter(ImageFilter.GaussianBlur(soft))
    a = to_np(img)
    n = noise(W, H, W / 2, seed, 1) - 0.5
    a += n[..., None] * grain * 2
    return from_np(a, "RGB")


def finish(C, name, seed, **kw):
    img = broadcast_finish(C.final(), seed, **kw)
    save(img, name)
    return img


def rays(C, cx, cy, n, c1, c2, R=900, rot=0.0):
    C.rect((0, 0, W, H), fill=c1)
    for i in range(n):
        if i % 2:
            continue
        a0 = math.radians(rot + i * 360 / n)
        a1 = math.radians(rot + (i + 1) * 360 / n)
        C.poly([(cx, cy), (cx + R * math.cos(a0), cy + R * math.sin(a0)), (cx + R * math.cos(a1), cy + R * math.sin(a1))], c2)


def bug(C, x=W - 22, y=24, fg=P["cream"], bg=INK, label=None):
    """Station bug: KLHV channel 6 roundel, top right."""
    C.circle(x - 18, y + 14, 20, fill=bg)
    C.circle(x - 18, y + 14, 16, outline=fg, width=2)
    C.text((x - 18, y + 15), "6", ("black", 20), fg, "mm")
    C.text((x - 44, y + 14), "KLHV", ("black", 15), label or bg, "rm", 1)


def lower_third(C, title, sub=None, col=P["red"], live=False):
    y = 384
    C.rect((0, y, W, y + 52), fill=INK)
    C.rect((0, y, 16, y + 52), fill=col)
    C.text((34, y + 27), title, ("black", 26), P["cream"], "lm")
    if sub:
        C.rect((0, y + 52, W, y + 80), fill=col)
        C.text((34, y + 66), sub, ("franklin", 17), P["cream"], "lm", 1.5)
    if live:
        C.rrect((W - 104, y - 40, W - 24, y - 10), 4, fill=P["red"])
        C.circle(W - 90, y - 25, 6, fill=P["cream"])
        C.text((W - 56, y - 24), "LIVE", ("black", 18), P["cream"], "mm")


# =========================================================================== title card
def tv_larkhaven_morning():
    C = Canvas(W, H, P["mustard_lt"])
    rays(C, 320, 330, 28, P["mustard_lt"], mix(P["mustard"], P["mustard_lt"], 0.35), rot=-90)
    sun(C, 320, 330, 110, P["mustard"], 0)
    C.circle(320, 330, 92, fill=mix(P["mustard"], P["coral"], 0.3))
    waves(C, 330, -20, W + 20, 8, 80, P["teal"], 200)
    waves(C, 362, -20, W + 20, 7, 64, shade(P["teal"], 0.75), 200, 1.2)
    waves(C, 396, -20, W + 20, 6, 52, P["navy"], 200, 2.4)
    lighthouse(C, 560, 352, 130, P["cream"], P["red"], P["red"], P["mustard"], INK, 3, False)
    C.poly([(500, 356), (530, 336), (600, 334), (628, 356)], shade(P["navy"], 0.8))
    for x, y, s in [(110, 230, 1.4), (170, 212, 1.0), (470, 226, 1.1)]:
        gull(C, x, y, s, INK)
    # title plate
    C.text((320 + 3, 90 + 3), "Larkhaven", ("pala_bi", 96), P["navy"], "mm")
    C.text((320, 90), "Larkhaven", ("pala_bi", 96), P["cream"], "mm", stroke=3, stroke_fill=P["navy"])
    C.rect((150, 140, 490, 196), fill=P["red"])
    C.text((320, 169), "MORNING", ("black", 44), P["cream"], "mm", 10)
    C.text((320, 446), "with HAL BRIGHTWATER", ("black", 22), P["cream"], "mm", 3)
    bug(C)
    return finish(C, "tv_larkhaven_morning", 201)


# =========================================================================== anchor
def anchor_figure(C, mood="happy"):
    skin = hexc("E9B98F")
    skin_d = hexc("C98F68")
    hair = hexc("3A2A20")
    suit = P["navy"] if mood == "happy" else hexc("1C2A44")
    cx = 320
    # torso
    C.rrect((196, 296, 444, 520), 56, fill=suit)
    C.poly([(300, 296), (340, 296), (320, 376)], P["white"])
    C.poly([(276, 300), (300, 296), (320, 376), (296, 420)], shade(suit, 0.75))     # left lapel
    C.poly([(364, 300), (340, 296), (320, 376), (344, 420)], shade(suit, 0.75))     # right lapel
    tie = P["red"] if mood == "happy" else hexc("6E2A22")
    C.poly([(312, 302), (328, 302), (325, 316), (315, 316)], shade(tie, 0.8))
    C.poly([(315, 316), (325, 316), (333, 368), (320, 384), (307, 368)], tie)
    C.rect((395, 330, 418, 336), fill=P["white"])   # pocket square
    # neck + head
    C.rect((300, 262, 340, 304), fill=skin_d)
    for ex in (258, 382):
        C.ellipse((ex - 11, 196, ex + 11, 238), fill=skin)
        C.ellipse((ex - 5, 206, ex + 5, 228), fill=skin_d)
    C.ellipse((266, 128, 374, 246), fill=skin)
    C.rrect((268, 176, 372, 284), 30, fill=skin)            # square jaw
    C.rect((268, 176, 280, 250), fill=skin)
    C.rect((360, 176, 372, 250), fill=skin)
    # hair: rounded crown, side part, a quiff, distinguished grey temples
    C.chord((260, 108, 380, 228), 180, 360, fill=hair)
    C.poly([(262, 168), (266, 196), (276, 196), (278, 164)], hair)
    C.poly([(378, 168), (374, 196), (364, 196), (362, 164)], hair)
    C.poly([(263, 182), (266, 196), (276, 196), (277, 180)], hexc("B8B4AC"))
    C.poly([(377, 182), (374, 196), (364, 196), (363, 180)], hexc("B8B4AC"))
    C.poly([(296, 118), (340, 104), (372, 108), (386, 128), (380, 150), (364, 136), (330, 130), (300, 134)], hair)
    C.line([(306, 126), (340, 114), (368, 118)], shade(hair, 1.45), 3)
    C.line([(294, 120), (286, 150)], shade(hair, 0.6), 3)
    # face
    if mood == "happy":
        for ex in (298, 342):
            C.line([(ex - 13, 182), (ex, 176), (ex + 13, 182)], hair, 5)
            C.ellipse((ex - 6, 192, ex + 6, 206), fill=INK)
            C.circle(ex - 2, 196, 2, fill=P["white"])
        C.arc((296, 214, 344, 258), 20, 160, INK, 4)
        C.chord((302, 232, 338, 252), 0, 180, fill=P["white"])
        C.circle(286, 228, 9, fill=mix(skin, P["coral"], 0.45))
        C.circle(354, 228, 9, fill=mix(skin, P["coral"], 0.45))
    else:
        for ex, sgn in ((298, 1), (342, -1)):
            C.line([(ex - 13, 180 - sgn * 4), (ex + 13, 180 + sgn * 4)], hair, 5)
            C.ellipse((ex - 6, 194, ex + 6, 206), fill=INK)
            C.circle(ex - 2, 198, 2, fill=P["white"])
        C.line([(304, 246), (336, 246)], INK, 4)
        C.line([(286, 210), (290, 222)], skin_d, 2)
        C.line([(354, 210), (350, 222)], skin_d, 2)
    C.poly([(320, 200), (312, 226), (322, 228)], skin_d)       # nose
    C.line([(320, 274), (320, 280)], skin_d, 2)                # chin cleft


def anchor_desk(C, mood="happy"):
    wood = P["wood"] if mood == "happy" else shade(P["wood"], 0.6)
    C.rect((0, 372, W, H), fill=wood)
    C.rect((0, 366, W, 382), fill=shade(wood, 0.7))
    # papers + hands
    C.poly([(236, 368), (330, 362), (334, 380), (238, 386)], P["white"])
    C.poly([(320, 366), (408, 360), (410, 376), (324, 382)], mix(P["white"], P["cream"], 0.6))
    skin = hexc("E9B98F")
    C.ellipse((246, 352, 288, 380), fill=skin)
    C.ellipse((372, 350, 414, 378), fill=skin)
    C.rect((236, 352, 268, 368), fill=P["navy"] if mood == "happy" else hexc("1C2A44"))
    C.rect((396, 350, 428, 366), fill=P["navy"] if mood == "happy" else hexc("1C2A44"))
    # microphone
    C.rect((150, 300, 156, 372), fill=hexc("9A9A9A"))
    C.ellipse((126, 362, 180, 376), fill=hexc("6A6A6A"))
    C.rrect((136, 262, 170, 312), 14, fill=hexc("B8B8B8"))
    for k in range(5):
        C.line([(140, 272 + k * 8), (166, 272 + k * 8)], hexc("6A6A6A"), 2)
    # desk plaque
    plaque = P["cream"] if mood == "happy" else shade(P["cream"], 0.6)
    C.rect((200, 404, 440, 456), fill=plaque)
    C.rect((206, 410, 434, 450), outline=INK, width=2)
    C.text((320, 431), "KLHV · 6 · NEWS", ("black", 22), INK, "mm", 2)


def tv_anchor():
    C = Canvas(W, H, P["teal"])
    # backdrop: show logo panel with sunrise
    rays(C, 320, 260, 32, P["teal"], mix(P["teal"], P["cream"], 0.15), rot=-90)
    C.rect((0, 0, W, 112), fill=P["cream"])
    C.rect((0, 112, W, 120), fill=P["red"])
    C.text((320, 38), "Larkhaven", ("pala_bi", 50), P["navy"], "mm")
    C.text((320, 80), "M O R N I N G", ("black", 22), P["red"], "mm", 2)
    sun(C, 84, 66, 30, P["mustard"], 12)
    sun(C, 556, 66, 30, P["mustard"], 12)
    anchor_figure(C, "happy")
    anchor_desk(C, "happy")
    bug(C, W - 16, 132)
    return finish(C, "tv_anchor", 202)


def tv_anchor_grave():
    C = Canvas(W, H, hexc("5A1E1A"))
    for k in range(0, W, 40):
        C.rect((k, 0, k + 20, 380), fill=hexc("4A1714"))
    C.rect((0, 0, W, 112), fill=hexc("2A0E0C"))
    C.rect((0, 112, W, 120), fill=P["red"])
    C.text((320, 58), "CIVIL DEFENSE", ("black", 44), hexc("E8C9A8"), "mm", 3)
    for x in (56, 584):
        cd_emblem(C, x, 58, 42, hexc("E8C9A8"), hexc("2A0E0C"), P["red"], hexc("E8C9A8"), P["mustard"], ring_text=False)
    anchor_figure(C, "grave")
    anchor_desk(C, "grave")
    img = C.final()
    # dim, top-lit key light
    a = to_np(img)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    v = 1 - 0.45 * np.clip(np.sqrt(((xx - 320) / 380) ** 2 + ((yy - 180) / 300) ** 2), 0, 1)
    a *= v[..., None]
    a[..., 0] *= 1.04
    a[..., 2] *= 0.92
    img = from_np(a, "RGB")
    C2 = Canvas(W, H, (0, 0, 0))
    C2.paste(img, (0, 0))
    C2.rrect((24, 136, 196, 164), 4, fill=P["red"])
    C2.text((110, 151), "SPECIAL BULLETIN", ("black", 15), P["cream"], "mm", 1)
    return finish(C2, "tv_anchor_grave", 203)


# =========================================================================== weather
def weather_icon(C, kind, x, y, s=1.0):
    if kind == "sun":
        sun(C, x, y, 26 * s, P["mustard"], 12, 0.5)
        C.arc((x - 12 * s, y - 6 * s, x + 12 * s, y + 14 * s), 20, 160, INK, 3)
        C.circle(x - 8 * s, y - 6 * s, 3 * s, fill=INK)
        C.circle(x + 8 * s, y - 6 * s, 3 * s, fill=INK)
    elif kind == "cloud":
        cloud(C, x, y, 90 * s, P["white"], hexc("9AA6AE"))
    elif kind == "partly":
        sun(C, x + 18 * s, y - 14 * s, 20 * s, P["mustard"], 10, 0.5)
        cloud(C, x - 6 * s, y + 6 * s, 76 * s, P["white"], hexc("9AA6AE"))
    elif kind == "fog":
        for k in range(3):
            C.line([(x - 34 * s + k * 6, y - 12 * s + k * 12 * s), (x + 34 * s + k * 6, y - 12 * s + k * 12 * s)], P["white"], 6 * s)


def tv_weather_map():
    C = Canvas(W, H, P["navy"])
    # ocean with wave ticks
    for y in range(110, H, 34):
        for x in range(10 + (y // 34 % 2) * 30, 330, 60):
            C.arc((x, y, x + 24, y + 14), 200, 340, mix(P["navy"], P["cream"], 0.3), 2)
    # land (east) with coastline wiggle
    rng = np.random.default_rng(3)
    pts = []
    for i, y in enumerate(np.linspace(80, H, 26)):
        x = 330 + 40 * math.sin(y / 60) + rng.uniform(-10, 10)
        if 220 < y < 270:
            x += 46  # Larkhaven bay
        pts.append((x, y))
    land = pts + [(W, H), (W, 80)]
    C.poly(land, P["cream"])
    C.line(pts, INK, 4)
    mountains(C, 330, 470, W + 20, [(520, 90), (580, 140), (640, 100)], mix(P["cream"], P["teal"], 0.35))
    for x, y in [(450, 420), (480, 440), (520, 410)]:
        pine(C, x, y, 40, P["teal"], P["wood_dk"])
    # icons + temps
    weather_icon(C, "sun", 520, 236, 1.4)
    C.text((520, 296), "64°", ("black", 34), P["red"], "mm")
    weather_icon(C, "partly", 470, 130, 0.9)
    C.text((540, 132), "61°", ("black", 24), INK, "mm")
    weather_icon(C, "fog", 160, 260, 1.0)
    C.text((160, 296), "OFFSHORE FOG", ("franklin", 14), P["cream"], "mm", 1)
    weather_icon(C, "cloud", 150, 150, 0.9)
    # wind arrow
    C.line([(180, 360), (290, 340)], P["mustard"], 6)
    C.poly([(290, 330), (312, 336), (294, 352)], P["mustard"])
    C.text((200, 384), "W 8 mph", ("black", 16), P["mustard"], "mm")
    # towns
    towns = [("LARKHAVEN", 392, 246, True), ("PORT ELLERY", 368, 138, False), ("CAPE WREN", 376, 400, False)]
    for name, x, y, star in towns:
        if star:
            starburst(C, x, y, 14, 5, 5, P["red"])
        else:
            C.circle(x, y, 6, fill=INK)
        sp = ("black", 15 if star else 13)
        tw = C.text_w(name, sp, 1)
        C.rrect((x + 12, y - 11, x + 24 + tw, y + 11), 4, fill=P["cream"])
        C.text((x + 18, y), name, sp, INK, "lm", 1)
    # header
    C.rect((0, 0, W, 76), fill=P["mustard"])
    C.rect((0, 76, W, 84), fill=INK)
    C.text((24, 30), "LARKHAVEN WEATHER", ("black", 26), INK, "lm", 1)
    C.text((26, 60), "SATURDAY · OCTOBER 14, 1967", ("franklin", 16), INK, "lm", 2)
    C.rrect((W - 210, 14, W - 20, 64), 8, fill=INK)
    C.text((W - 115, 39), "SUNNY & MILD", ("black", 20), P["mustard"], "mm")
    return finish(C, "tv_weather_map", 204)


# =========================================================================== comet / harbour / cloud
def picnicker(C, x, base, s, seated=True, col=INK):
    if seated:
        C.ellipse((x - 5 * s, base - 22 * s, x + 5 * s, base - 12 * s), fill=col)
        C.poly([(x - 6 * s, base - 12 * s), (x + 6 * s, base - 12 * s), (x + 10 * s, base), (x - 9 * s, base)], col)
        C.line([(x + 3 * s, base - 9 * s), (x + 9 * s, base - 22 * s)], col, 2 * s)  # arm pointing up
    else:
        C.ellipse((x - 4 * s, base - 30 * s, x + 4 * s, base - 22 * s), fill=col)
        C.poly([(x - 5 * s, base - 22 * s), (x + 5 * s, base - 22 * s), (x + 4 * s, base), (x - 4 * s, base)], col)


def tv_comet():
    C = Canvas(W, H, NIGHT)
    ht_rect(C, (0, 0, W, 260), hexc("4A5E8E"), 0.0, 0.95, 6, 45)
    rng = np.random.default_rng(11)
    for _ in range(110):
        C.circle(rng.uniform(0, W), rng.uniform(0, 240), rng.uniform(0.6, 1.8), fill=P["cream"])
    for _ in range(7):
        starburst(C, rng.uniform(10, W - 10), rng.uniform(10, 220), rng.uniform(5, 9), 1.5, 4, P["cream"])
    hx, hy = 330, 120
    comet(C, hx, hy, 200, 400, 17, P["white"], mix(P["cream"], V, 0.3), mix(P["navy_lt"], V, 0.5), 10,
          glow=mix(NIGHT, V, 0.5))
    # sea, lit by the comet
    SEA = hexc("31446E")
    C.rect((0, 252, W, H), fill=SEA)
    for k in range(9):
        wave_lines(C, 262 + k * 14, 0, W, 2, 50, mix(SEA, P["cream"], 0.12 + 0.02 * k), 1.5, k)
    for k in range(14):
        y = 258 + k * 9
        w_ = 30 + k * 6 + rng.uniform(-8, 8)
        x0 = hx - w_ / 2 + rng.uniform(-10, 10)
        for seg in range(3):
            sx0 = x0 + seg * w_ / 3 + rng.uniform(0, 6)
            C.line([(sx0, y), (sx0 + w_ / 3 * rng.uniform(0.3, 0.8), y)], mix(SEA, mix(P["cream"], V, 0.25), 0.7 - k * 0.035), 2.5)
    C.poly([(470, 254), (540, 244), (640, 246), (640, 256)], hexc("1A2238"))
    lighthouse(C, 600, 248, 40, P["cream"], P["red"], P["red"], P["mustard"], INK, 3, False)
    C.glow(600, 214, 22, P["mustard_lt"], 0.8, 1.5)
    # the bluff, picnickers silhouetted against the bright water
    BL = hexc("0D111E")
    C.poly([(0, 296), (40, 288), (180, 292), (300, 302), (360, 318), (400, 350), (430, H), (0, H)], BL)
    for x, hh in [(14, 70), (40, 54), (64, 62)]:
        pine(C, x, 296, hh, BL, BL)
    sedan(C, 120, 292, 80, BL, BL, BL, BL)
    picnicker(C, 196, 296, 2.3)
    picnicker(C, 226, 297, 2.0)
    picnicker(C, 262, 300, 2.3, False)
    C.line([(266, 252), (282, 236)], BL, 4)     # pointing at the comet
    picnicker(C, 306, 305, 1.9)
    C.rect((172, 293, 214, 297), fill=BL)       # basket
    # a little lantern glow on the blanket
    C.glow(240, 300, 26, P["mustard"], 0.7, 1.6)
    C.circle(240, 296, 3.5, fill=P["mustard_lt"])
    lower_third(C, "LAST NIGHT ON THE BLUFF", "THE LARKSPUR COMET PASSES LARKHAVEN", P["navy"])
    bug(C, label=P["cream"])
    return finish(C, "tv_comet", 205)


def boat(C, x, base, s, hull=P["red"], cabin=P["cream"], flip=False):
    t = T(x, base, s, 0, flip)
    C.poly(t.pts([(-60, -20), (66, -24), (50, 0), (-50, 0)]), hull)
    C.rect(t.box(-56, -24, 62, -19), fill=P["cream"])
    C.rect(t.box(-30, -52, 6, -24), fill=cabin)
    C.rect(t.box(-24, -46, -12, -36), fill=INK)
    C.rect(t.box(-8, -46, 2, -36), fill=INK)
    C.line(t.pts([(26, -24), (26, -92)]), INK, t.r(3))
    C.line(t.pts([(26, -80), (60, -40)]), INK, t.r(2))
    C.line(t.pts([(26, -88), (-40, -30)]), INK, t.r(1.5))


def tv_harbor_dust():
    C = Canvas(W, H, hexc("D8CFC0"))
    ht_rect(C, (0, 0, W, 210), mix(V, P["cream"], 0.55), 0.6, 0.0, 6, 45)   # a lilac cast in the morning haze
    # far hills + town
    C.poly([(0, 170), (120, 130), (260, 150), (380, 120), (520, 150), (W, 130), (W, 210), (0, 210)], hexc("9DA9A0"))
    for i, x in enumerate(range(20, W, 46)):
        h = 22 + (i * 13 % 18)
        C.rect((x, 200 - h, x + 34, 210), fill=[P["cream"], P["coral_lt"], P["teal_lt"]][i % 3])
        C.poly([(x - 3, 200 - h), (x + 17, 186 - h), (x + 37, 200 - h)], [P["red"], P["navy_lt"], P["coral"]][i % 3])
    # water
    WATER = hexc("2D5B66")
    C.rect((0, 210, W, H), fill=WATER)
    # violet dust sheen bands on the water
    xx, yy = C.grid()
    n = noise(W * 2, H * 2, 18, 5, 4)
    band = np.clip((n - 0.45) * 3, 0, 1) * (yy > 212)
    sheen = band * (0.35 + 0.65 * np.clip((yy - 210) / 270, 0, 1))
    C.fill_cov(sheen * 0.55, mix(V, P["white"], 0.15))
    for k in range(12):
        wave_lines(C, 226 + k * 22, -10, W + 10, 2.5, 40 + k * 6, mix(WATER, P["cream"], 0.3), 2, k * 0.7)
    # pier
    C.rect((440, 236, W, 252), fill=P["wood_dk"])
    for x in range(450, W, 30):
        C.rect((x, 252, x + 7, 330), fill=P["wood_dk"])
    # boats
    boat(C, 150, 300, 1.15, P["red"], P["cream"])
    boat(C, 360, 268, 0.8, P["teal"], P["cream"], True)
    boat(C, 560, 236, 0.6, P["mustard"], P["cream"])
    for x, y, s in [(240, 90, 1.0), (290, 70, 0.8), (90, 110, 0.7)]:
        gull(C, x, y, s, INK)
    # glittering dust motes
    rng = np.random.default_rng(13)
    for _ in range(60):
        x, y = rng.uniform(0, W), rng.uniform(214, 380)
        r = rng.uniform(1.5, 4.5)
        C.glow(x, y, r * 4, V, 0.6, 1.5)
        starburst(C, x, y, r * 1.8, r * 0.4, 4, mix(V, P["white"], 0.6))
    for _ in range(40):
        C.circle(rng.uniform(0, W), rng.uniform(0, 210), rng.uniform(0.8, 2), fill=mix(V, P["white"], 0.35))
    lower_third(C, "STRANGE DUST IN THE HARBOR", "FISHERMEN REPORT A GLITTERING FILM ON THE WATER", P["teal"], live=True)
    bug(C)
    return finish(C, "tv_harbor_dust", 206)


def billow_row(C, y, x0, x1, r0, r1, base, lit, dark, rng, step=0.8):
    x = x0
    while x < x1 + r1:
        r = rng.uniform(r0, r1)
        yy = y + rng.uniform(-r * 0.35, r * 0.2)
        C.circle(x, yy, r, fill=base)
        C.circle(x - r * 0.18, yy - r * 0.2, r * 0.78, fill=lit)
        C.chord((x - r, yy - r, x + r, yy + r), 20, 160, fill=dark)
        x += r * step * 2


def tv_cloud():
    C = Canvas(W, H, hexc("E9D9B8"))
    # clear morning sky to the right, the wall eating it from the left
    ht_rect(C, (0, 0, W, 330), hexc("8FB6C8"), 0.9, 0.2, 6, 45)
    sun(C, 560, 96, 26, P["mustard_lt"], 0)
    rng = np.random.default_rng(17)
    WALL = mix(V, P["navy"], 0.35)
    DARK = mix(V, INK, 0.55)
    LIT = mix(V, P["white"], 0.3)
    TOP = mix(V, P["white"], 0.55)
    # wall silhouette: towering on the left, sloping down to the right, billowy crest
    top_y = lambda x: 10 + 0.45 * x
    m = C.mask()
    m.poly([(-10, 330)] + [(x, top_y(x) + 30) for x in range(-10, 600, 10)] + [(600, 330)], 255)
    x = -10
    crest = []
    while x < 590:
        r = rng.uniform(26, 48) * (1.25 - x / 900)
        cy = top_y(x) + r * 0.7
        m.circle(x, cy, r, fill=255)
        crest.append((x, cy, r))
        x += r * 1.1
    xx, yy = C.grid()
    n = noise(xx.shape[1], xx.shape[0], 9, 23, 5)
    n2 = noise(xx.shape[1], xx.shape[0], 28, 24, 3)
    depth = np.clip((yy - (10 + 0.45 * xx)) / 300, 0, 1)
    light = 0.95 - 0.9 * depth + 0.55 * (n - 0.5) + 0.25 * (n2 - 0.5) + 0.1 * (xx / W)
    mask = to_np(m.img) / 255.0
    tones = [(DARK, -9), (WALL, 0.34), (LIT, 0.58), (TOP, 0.79)]
    for col, th in tones:
        C.fill_cov(mask * np.clip((light - th) * 40, 0, 1), col)
    # crest highlights so each billow reads as a rounded cell
    for x, cy, r in crest:
        C.arc((x - r * 0.8, cy - r * 0.85, x + r * 0.8, cy + r * 0.75), 200, 300, mix(TOP, P["white"], 0.4), 3)
    # glow motes and fallstreaks to the water
    for i in range(28):
        C.glow(rng.uniform(0, 560), rng.uniform(80, 320), rng.uniform(20, 50), mix(V, P["white"], 0.6), 0.45, 1.5)
    # bay with the violet edge rolling over it
    BAY = hexc("2F5268")
    C.rect((0, 320, W, H), fill=BAY)
    yy = C.grid()[1]
    C.fill_cov(np.clip(1 - np.abs(yy - 324) / 16, 0, 1) * 0.85, mix(V, P["white"], 0.45))
    for k in range(6):
        wave_lines(C, 334 + k * 14, -10, W + 10, 2, 46, mix(BAY, P["cream"], 0.25), 2, k)
    C.poly([(0, 322), (300, 322), (420, 326), (0, 344)], mix(V, BAY, 0.4))
    lighthouse(C, 600, 326, 60, P["cream"], P["red"], P["red"], P["mustard"], INK, 3, False)
    C.poly([(560, 330), (585, 318), (630, 318), (W, 330)], hexc("3A4A3A"))
    # town rooftops in the foreground (lit by sun, still normal)
    ROOF = [P["coral"], P["teal"], P["red"], P["navy_lt"], P["mustard"]]
    for i, x in enumerate(range(-10, W, 62)):
        h = 34 + (i * 23 % 30)
        C.rect((x, 452 - h, x + 54, H), fill=P["cream"] if i % 2 else mix(P["cream"], P["coral_lt"], 0.5))
        C.poly([(x - 6, 452 - h), (x + 27, 428 - h), (x + 60, 452 - h)], ROOF[i % 5])
        C.rect((x + 18, 462 - h, x + 34, 476 - h), fill=INK)
    # studio window frame + half-raised blind
    FR = hexc("2A2522")
    C.rect((0, 0, W, 22), fill=FR)
    C.rect((0, 0, 22, H), fill=FR)
    C.rect((W - 22, 0, W, H), fill=FR)
    C.rect((0, H - 22, W, H), fill=FR)
    C.rect((W / 2 - 6, 0, W / 2 + 6, H), fill=FR)
    C.rect((0, 236, W, 246), fill=FR)
    C.rect((22, 22, W - 22, 62), fill=hexc("D8CDB4"))
    for k in range(3):
        C.line([(22, 32 + k * 11), (W - 22, 32 + k * 11)], hexc("A99E86"), 2)
    C.line([(W - 110, 62), (W - 110, 130)], hexc("D8CDB4"), 2)
    C.circle(W - 110, 134, 5, fill=hexc("D8CDB4"))
    C.rrect((36, 430, 132, 456), 4, fill=P["red"])
    C.circle(50, 443, 5, fill=P["cream"])
    C.text((90, 444), "LIVE", ("black", 16), P["cream"], "mm")
    return finish(C, "tv_cloud", 207)


# =========================================================================== ads
def tv_ad_starlight():
    C = Canvas(W, H, P["navy"])
    rays(C, 230, 270, 24, P["navy"], shade(P["navy"], 1.12))
    for x, y, r in [(70, 60, 20), (560, 330, 14), (600, 90, 10), (420, 420, 12), (40, 380, 12)]:
        starburst(C, x, y, r, r * 0.2, 4, P["mustard"])

    def scr(box):
        x0, y0, x1, y1 = box
        C.rrect(box, 18, fill=hexc("D8E8E4"))
        starburst(C, (x0 + x1) / 2, (y0 + y1) / 2, 46, 8, 8, P["mustard"])
        C.text(((x0 + x1) / 2, y1 - 20), "Ch. 6", ("black", 14), P["navy"], "mm")
        C.rrect(box, 18, outline=hexc("D8D4C8"), width=4)
    tv_set(C, 200, 424, 290, screen_fn=scr)
    C.text((320, 44), "The New", ("pala_bi", 36), P["cream"], "mm")
    C.text((320, 104), "STARLIGHT", ("black", 72), P["mustard"], "mm", 3)
    C.para((372, 220, W - 30, 330), "Picture-perfect evenings for the whole family", ("georgia_bi", 24), P["cream"], 1.2, "right")
    C.rrect((400, 344, W - 30, 388), 22, fill=P["red"])
    C.text((((400 + W - 30) / 2), 366), "21-INCH CONSOLE", ("black", 18), P["cream"], "mm")
    C.rect((0, 432, W, H), fill=P["cream"])
    halcyon_logo(C, 320, 452, 40, P["navy"], P["mustard"], P["cream"], tagline=False, anchor="m")
    return finish(C, "tv_ad_starlight", 208)


def tv_ad_valet():
    C = Canvas(W, H, P["coral_lt"])
    rays(C, 210, 300, 28, P["coral_lt"], mix(P["coral_lt"], P["white"], 0.35))
    C.circle(210, 290, 170, fill=P["mustard_lt"])
    tuppence(C, 200, 112, 0.92, "tray")
    C.ellipse((110, 410, 300, 430), fill=shade(P["coral_lt"], 0.8))
    C.text((W - 30, 70), "Your", ("pala_bi", 40), P["navy"], "ra")
    C.text((W - 26, 104), "VALET", ("black", 66), P["red"], "ra", 2)
    C.text((W - 30, 196), "Mk II", ("pala_bi", 50), P["navy"], "ra")
    C.rect((400, 258, W - 30, 262), fill=P["navy"])
    C.para((392, 272, W - 30, 360), "A gentleman in every home.", ("georgia_bi", 26), P["navy"], 1.2, "right")
    C.para((392, 352, W - 30, 430), "Pours tea · Minds the door · Never forgets a birthday", ("franklin", 16), INK, 1.3, "right")
    C.rect((0, 432, W, H), fill=P["navy"])
    halcyon_logo(C, 320, 452, 40, P["cream"], P["mustard"], P["navy"], tagline=False, anchor="m")
    return finish(C, "tv_ad_valet", 209)


def cereal_box(C, x, y, w, h):
    C.rect((x + w, y + 10, x + w + w * 0.22, y + h), fill=shade(P["mustard"], 0.7))
    C.poly([(x, y), (x + w, y), (x + w + w * 0.22, y + 10), (x + w * 0.22, y + 10)], shade(P["mustard"], 1.2))
    C.rect((x, y, x + w, y + h), fill=P["mustard"])
    C.rect((x, y, x + w, y + h * 0.26), fill=P["red"])
    C.text((x + w / 2, y + h * 0.08), "Sunny", ("pala_bi", w * 0.24), P["cream"], "mm")
    C.text((x + w / 2, y + h * 0.19), "CRUNCH", ("black", w * 0.17), P["mustard"], "mm", 1)
    sun_face(C, x + w / 2, y + h * 0.55, w * 0.25)
    C.text((x + w / 2, y + h * 0.9), "TOASTED CORN STARS", ("black", w * 0.07), P["red"], "mm")


def sun_face(C, cx, cy, r):
    sun(C, cx, cy, r, P["coral"], 14, 0.4, P["red"])
    C.circle(cx, cy, r * 0.86, fill=hexc("F7D46A"))
    for ex in (-0.32, 0.32):
        C.arc((cx + ex * r - r * 0.16, cy - r * 0.36, cx + ex * r + r * 0.16, cy - r * 0.04), 200, 340, INK, max(2, r * 0.09))
    C.chord((cx - r * 0.45, cy - r * 0.1, cx + r * 0.45, cy + r * 0.55), 0, 180, fill=INK)
    C.chord((cx - r * 0.3, cy + r * 0.18, cx + r * 0.3, cy + r * 0.52), 0, 180, fill=P["red"])
    C.circle(cx - r * 0.55, cy + r * 0.12, r * 0.13, fill=P["coral"])
    C.circle(cx + r * 0.55, cy + r * 0.12, r * 0.13, fill=P["coral"])


def tv_ad_sweetcorn():
    C = Canvas(W, H, P["teal"])
    rays(C, 470, 250, 30, P["teal"], mix(P["teal"], P["white"], 0.18))
    # table
    C.rect((0, 380, W, H), fill=P["cream"])
    for x in range(0, W, 40):
        C.rect((x, 380, x + 20, H), fill=mix(P["cream"], P["coral"], 0.25))
    cereal_box(C, 400, 70, 160, 300)
    # bowl with flakes + spoon
    C.chord((60, 300, 320, 440), 0, 180, fill=P["white"])
    C.chord((60, 300, 320, 440), 0, 180, outline=P["navy"], width=4)
    C.rect((70, 366, 310, 372), fill=P["navy"])
    rng = np.random.default_rng(21)
    for _ in range(26):
        x, y = rng.uniform(84, 296), rng.uniform(340, 368)
        starburst(C, x, y, rng.uniform(9, 14), 4, 5, P["mustard"], rng.uniform(0, 70))
    C.line([(250, 330), (330, 250)], hexc("C8C8C8"), 8)
    C.ellipse((322, 226, 356, 262), fill=hexc("D8D8D8"))
    for x, y in [(110, 300), (170, 280), (240, 296)]:
        starburst(C, x, y, 10, 2, 4, P["white"])
    # headline
    C.text((40, 60), "The breakfast", ("pala_bi", 40), P["cream"], "la")
    C.text((40, 104), "that SHINES!", ("black", 40), P["mustard"], "la")
    C.rrect((40, 174, 330, 214), 20, fill=P["red"])
    C.text((185, 194), "NOW WITH CORN STARS!", ("black", 17), P["cream"], "mm")
    return finish(C, "tv_ad_sweetcorn", 210)


# =========================================================================== emergency / off-air
def tv_emergency():
    C = Canvas(W, H, hexc("1A1716"))
    # hazard stripes top and bottom
    for yb in (0, H - 34):
        C.rect((0, yb, W, yb + 34), fill=P["mustard"])
        for x in range(-40, W + 40, 44):
            C.poly([(x, yb + 34), (x + 22, yb + 34), (x + 44, yb), (x + 22, yb)], INK)
    C.rect((0, 34, W, 104), fill=P["red"])
    C.text((320, 70), "CIVIL DEFENSE EMERGENCY", ("black", 36), P["cream"], "mm", 1)
    cd_emblem(C, 140, 250, 104)
    C.text((470, 158), "PROCEED", ("black", 44), P["cream"], "mm", 2)
    C.text((470, 206), "CALMLY", ("black", 44), P["mustard"], "mm", 2)
    C.text((470, 250), "TO YOUR ASSIGNED", ("black", 22), P["cream"], "mm", 1)
    C.text((470, 286), "SHELTER", ("black", 44), P["cream"], "mm", 4)
    C.rect((290, 318, 620, 322), fill=P["red"])
    C.text((460, 346), "THIS IS NOT A TEST", ("black", 22), P["red"], "mm", 2)
    C.text((320, 412), "Residents of Shelter No. 9 — the bluff road is open.  Keep this station tuned.",
           ("franklin", 16), P["cream"], "mm", 0.5)
    return finish(C, "tv_emergency", 211, grain=6)


def tv_test_pattern():
    G = [hexc("101010"), hexc("3A3A3A"), hexc("6A6A6A"), hexc("9A9A9A"), hexc("CACACA"), hexc("F2F2F2")]
    C = Canvas(W, H, hexc("7A7A7A"))
    cx, cy = 320, 240
    # corner circles + border wedges
    for x, y in [(70, 70), (W - 70, 70), (70, H - 70), (W - 70, H - 70)]:
        C.circle(x, y, 52, fill=G[5])
        C.circle(x, y, 40, fill=G[0])
        C.circle(x, y, 26, fill=G[5])
        C.circle(x, y, 12, fill=G[0])
    for i in range(32):
        a0, a1 = i * 360 / 32, (i + 0.5) * 360 / 32
        C.pieslice((cx - 300, cy - 300, cx + 300, cy + 300), a0, a1, fill=G[1])
    # big circle
    C.circle(cx, cy, 200, fill=G[4])
    C.ring(cx, cy, 200, 6, G[0])
    # resolution wedges (converging lines)
    for side in (-1, 1):
        for k in range(14):
            y = cy - 40 + k * 6
            C.line([(cx + side * 190, y), (cx + side * 92, cy - 6 + k)], G[0], 1.2)
    for side in (-1, 1):
        for k in range(14):
            x = cx - 40 + k * 6
            C.line([(x, cy + side * 190), (cx - 6 + k, cy + side * 92)], G[0], 1.2)
    # grey step bar
    for i, g in enumerate(G):
        C.rect((cx - 150 + i * 50, cy + 120, cx - 100 + i * 50, cy + 160), fill=g)
    C.ring(cx, cy, 128, 3, G[0])
    C.circle(cx, cy, 90, fill=G[5])
    halcyon_emblem(C, cx, cy, 82, G[0], G[3], G[5], G[0], G[5])
    # crosshairs
    C.line([(cx - 200, cy), (cx - 92, cy)], G[0], 3)
    C.line([(cx + 92, cy), (cx + 200, cy)], G[0], 3)
    # call sign plates
    C.rect((cx - 120, cy - 178, cx + 120, cy - 134), fill=G[0])
    C.text((cx, cy - 156), "KLHV · 6", ("black", 30), G[5], "mm", 4)
    C.rect((cx - 175, H - 40, cx + 175, H - 10), fill=G[0])
    C.text((cx, H - 25), "HALCYON STARLIGHT · LARKHAVEN, CAL.", ("franklin", 15), G[5], "mm", 1.5)
    return finish(C, "tv_test_pattern", 212)


def tv_please_stand_by():
    C = Canvas(W, H, P["mustard"])
    rays(C, 470, 300, 24, P["mustard"], mix(P["mustard"], P["white"], 0.28))
    # Tuppence with a spanner, sweat drops, sparking cable
    tuppence(C, 500, 120, 0.88, "wave")
    for x, y in [(440, 150), (560, 140), (576, 168)]:
        C.poly([(x, y - 10), (x + 6, y + 2), (x, y + 8), (x - 6, y + 2)], P["teal_lt"])
    C.line([(380, 440), (410, 420), (360, 400), (330, 420)], INK, 5)
    starburst(C, 330, 420, 22, 6, 8, P["red"])
    C.text((36, 110), "PLEASE", ("black", 58), P["navy"], "la", 1)
    C.text((36, 176), "STAND BY", ("black", 58), P["red"], "la", 1)
    C.para((42, 280, 330, 400), "We are experiencing a slight technical difficulty. Our engineers are on the case!",
           ("georgia_bi", 22), INK, 1.25)
    bug(C, W - 16, 18)
    return finish(C, "tv_please_stand_by", 213)


ALL = [tv_larkhaven_morning, tv_anchor, tv_anchor_grave, tv_weather_map, tv_comet, tv_harbor_dust, tv_cloud,
       tv_ad_starlight, tv_ad_valet, tv_ad_sweetcorn, tv_emergency, tv_test_pattern, tv_please_stand_by]

if __name__ == "__main__":
    import sys
    only = sys.argv[1:]
    for fn in ALL:
        if not only or fn.__name__ in only:
            fn()
