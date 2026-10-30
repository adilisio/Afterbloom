"""Posters (1024x1536) and the Halcyon billboard (2048x1024), plus *_aged variants."""
from __future__ import annotations

import math

import numpy as np
from PIL import Image

from common import (PAL, Canvas, age_paper, from_np, hexc, mix, noise, overgrow, print_finish, save, shade,
                    to_np)
from illus import (T, cd_emblem, clipped, cloud, comet, gull, halcyon_emblem, halcyon_logo, house, ht_rect, ht_shape,
                   lighthouse, pine, ribbon, rocket, shelter_entrance, spiky_star, starburst, sun, tuppence, tv_set,
                   wave_lines, waves, burst_label)

P = PAL
INK = P["ink"]
PW, PH = 1024, 1536

MANIFEST = [
    ("poster_starlight_tv", "Halcyon ad poster: Starlight console television", "House living room / showroom / diner walls (1967)"),
    ("poster_starlight_tv_aged", "Aged/torn Starlight poster (1978)", "Same spots in ruined Larkhaven"),
    ("poster_valet_mk2", "Halcyon ad poster: Valet Mk II robot butler (Tuppence model)", "Showroom, kitchen, Gull Lane"),
    ("poster_valet_mk2_aged", "Aged/torn Valet Mk II poster", "Ruined showroom / streets (1978)"),
    ("poster_shelter", "Halcyon Assured Shelters: 'Sleep Soundly.' (Shelter No. 9)", "Bus stop, CD post, showroom, shelter lobby"),
    ("poster_shelter_aged", "Aged/torn shelter poster", "Shelter No. 9 interior after waking, ruined town"),
    ("poster_comet_picnic", "Town flyer: Larkspur Comet Night picnic on the bluff, Oct 13", "Diner, general store, noticeboards"),
    ("poster_comet_picnic_aged", "Aged/torn comet picnic flyer", "Noticeboards in 1978"),
    ("poster_civil_defense", "Civil Defense info poster: Know Your Shelter", "CD post, town hall, shelter corridor"),
    ("poster_civil_defense_aged", "Aged/torn civil defense poster", "CD post (rifle pickup), shelter (1978)"),
    ("billboard_halcyon", "2048x1024 Halcyon billboard: Tomorrow, Made Gentle.", "Billboard frame on the bluff road / harbor"),
    ("billboard_halcyon_aged", "Sun-bleached, peeling, overgrown billboard", "Same billboard in 1978"),
]


def sunrays(C, cx, cy, n, R, col_a, col_b=None, rot=0.0):
    """Alternating wedge rays radiating from (cx, cy) — classic mid-century backdrop."""
    for i in range(n):
        if col_b is None and i % 2:
            continue
        a0 = math.radians(rot + i * 360 / n)
        a1 = math.radians(rot + (i + 1) * 360 / n)
        C.poly([(cx, cy), (cx + R * math.cos(a0), cy + R * math.sin(a0)), (cx + R * math.cos(a1), cy + R * math.sin(a1))],
               col_a if i % 2 == 0 else col_b)


def sprinkle_stars(C, box, n, cols, seed, rmin=8, rmax=22, avoid=None):
    rng = np.random.default_rng(seed)
    x0, y0, x1, y1 = box
    k = 0
    while k < n:
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        if avoid and any(a[0] < x < a[2] and a[1] < y < a[3] for a in avoid):
            continue
        r = rng.uniform(rmin, rmax)
        starburst(C, x, y, r, r * 0.2, 4 if rng.random() < 0.6 else 8, cols[k % len(cols)])
        k += 1


def callout(C, x, y, tx, ty, lines, col, ink, align="l"):
    C.line([(x, y), (tx, ty)], col, 2.5)
    C.circle(x, y, 6, fill=col)
    yy = ty - (len(lines) - 1) * 17
    for i, (txt, spec) in enumerate(lines):
        C.text((tx + (8 if align == "l" else -8), yy + i * 34), txt, spec, ink if i else col, "lm" if align == "l" else "rm")


def finish(C, name, seed, aged_seed=None, **kw):
    img = print_finish(C.final(), seed, **kw)
    save(img, name)
    if aged_seed is not None:
        aged = age_paper(img, aged_seed, amount=0.8, stains=3, tears=True, creases=2, foxing=60, dust_violet=10)
        save(aged, name + "_aged")
    return img


# =========================================================================== Starlight TV
def poster_starlight_tv():
    C = Canvas(PW, PH, P["navy"])
    sunrays(C, 512, 800, 36, 1400, mix(P["navy"], P["navy_lt"], 0.35), None, 2)
    sprinkle_stars(C, (20, 260, PW - 20, 1150), 26, [P["mustard"], P["cream"], P["coral"]], 3,
                   avoid=[(150, 460, 870, 1160), (60, 120, 960, 420), (0, 560, 260, 680), (780, 580, 1024, 700)])
    C.text((512, 92), "PRESENTING THE ALL-NEW", ("franklin", 30), P["mustard"], "mm", 8)
    C.text((512 + 5, 210 + 5), "Bring the Stars", ("pala_bi", 128), INK, "mm")
    C.text((512, 210), "Bring the Stars", ("pala_bi", 128), P["cream"], "mm")
    C.text((512 + 5, 340 + 5), "Home!", ("pala_bi", 128), INK, "mm")
    C.text((512, 340), "Home!", ("pala_bi", 128), P["mustard"], "mm")

    def screen(box):
        x0, y0, x1, y1 = box

        def scene(S):
            S.rect(box, fill=hexc("BFE0DA"))
            sun_x, sun_y = (x0 + x1) / 2 - 20, y0 + (y1 - y0) * 0.6
            sun(S, sun_x, sun_y, 52, P["mustard"], 14, 0.5)
            waves(S, y0 + (y1 - y0) * 0.64, x0, x1, 7, 50, P["teal"], (y1 - y0) * 0.36 + 6)
            wave_lines(S, y0 + (y1 - y0) * 0.78, x0 + 20, x1 - 20, 5, 40, P["cream"], 3)
            rocket(S, x1 - 70, y0 + 80, 0.32, 35, P["cream"], P["red"], P["teal"])
            S.poly([(x0 + 60, y0 + (y1 - y0) * 0.66), (x0 + 120, y0 + (y1 - y0) * 0.66), (x0 + 110, y0 + (y1 - y0) * 0.71),
                    (x0 + 70, y0 + (y1 - y0) * 0.71)], P["red"])
            S.poly([(x0 + 88, y0 + (y1 - y0) * 0.66), (x0 + 88, y0 + (y1 - y0) * 0.5), (x0 + 112, y0 + (y1 - y0) * 0.65)],
                   P["cream"])
        clipped(C, lambda m: m.rrect(box, 34, fill=255), scene)
        C.rrect(box, 34, outline=hexc("D8D4C8"), width=6)

    # glow behind TV
    C.glow(512, 820, 520, P["mustard"], 0.35, 1.2)
    tv_set(C, 512, 1170, 660, screen_fn=screen)
    callout(C, 290, 770, 70, 610, [("21-INCH", ("black", 26)), ("Starlight tube", ("georgia_i", 24))], P["mustard"], P["cream"])
    callout(C, 770, 966, 960, 640, [("INSTANT-ON", ("black", 26)), ("no waiting!", ("georgia_i", 24))], P["mustard"], P["cream"], "r")
    callout(C, 810, 1080, 960, 1150, [("WALNUT", ("black", 26)), ("hand-rubbed", ("georgia_i", 24))], P["mustard"], P["cream"], "r")
    # bottom panel
    C.rect((0, 1210, PW, PH), fill=P["cream"])
    C.rect((0, 1210, PW, 1222), fill=P["red"])
    C.text((512, 1262), "THE HALCYON", ("georgia_b", 30), P["red"], "mm", 10)
    C.text((512, 1330), "STARLIGHT", ("black", 100), P["navy"], "mm", 8)
    C.text((512, 1398), "Console Television  ·  from $279.95, or $9 a month", ("georgia_i", 30), INK, "mm")
    halcyon_logo(C, 512, 1470, 66, P["navy"], P["mustard"], P["cream"], tagline=False, anchor="m")
    return finish(C, "poster_starlight_tv", 201, 301)


# =========================================================================== Valet Mk II
def poster_valet_mk2():
    C = Canvas(PW, PH, P["coral"])
    sunrays(C, 512, 560, 40, 1600, mix(P["coral"], P["cream"], 0.25), None, 0)
    C.circle(512, 640, 360, fill=mix(P["coral"], P["cream"], 0.55))
    C.circle(512, 640, 330, fill=P["cream"])
    ht_shape(C, lambda m: m.circle(512, 640, 330, fill=255), P["mustard"], C.rad_tone(512, 640, 330, 0.0, 0.55), 9, 45)
    # headline
    C.text((70, 92), "Your", ("pala_bi", 96), P["navy"], "lm")
    C.text((512 + 6, 200 + 6), "VALET Mk II", ("impact", 168), INK, "mm", 3)
    C.text((512, 200), "VALET Mk II", ("impact", 168), P["cream"], "mm", 3)
    tuppence(C, 500, 380, 2.25, "tray")
    burst_label(C, 860, 430, 112, P["red"], [("NEW", 46), ("for '67!", 30)], P["cream"], 18, -12, "black")
    # feature tags
    for i, (a, b) in enumerate([("POURS", "the tea"), ("PRESSES", "the trousers"), ("MINDS", "the kettle")]):
        y = 560 + i * 120
        C.rrect((40, y, 250, y + 92), 14, fill=P["navy"])
        C.text((145, y + 32), a, ("black", 30), P["mustard"], "mm", 2)
        C.text((145, y + 66), b, ("georgia_i", 25), P["cream"], "mm")
    # bottom
    C.rect((0, 1170, PW, PH), fill=P["navy"])
    C.rect((0, 1170, PW, 1180), fill=P["mustard"])
    C.text((512, 1250), "— a gentleman in every home.", ("pala_bi", 66), P["cream"], "mm")
    C.text((512, 1318), "Courteous · Tireless · Fully Assured  ·  See him at your Halcyon Showroom",
           ("georgia_i", 25), P["mustard"], "mm")
    halcyon_logo(C, 512, 1420, 80, P["cream"], P["mustard"], P["navy"], tagline=True, anchor="m")
    return finish(C, "poster_valet_mk2", 202, 302)


# =========================================================================== Shelter
def sleepy_moon(C, cx, cy, r):
    C.circle(cx, cy, r, fill=P["cream"])
    C.circle(cx + r * 0.5, cy - r * 0.25, r * 0.9, fill=hexc("1F2D4A"))
    # closed eye + smile on the crescent
    C.arc((cx - r * 0.72, cy - r * 0.18, cx - r * 0.38, cy + r * 0.08), 20, 160, INK, 4)
    C.arc((cx - r * 0.8, cy + r * 0.2, cx - r * 0.4, cy + r * 0.55), 10, 120, INK, 4)
    # nightcap
    C.poly([(cx - r * 0.92, cy - r * 0.42), (cx - r * 0.02, cy - r * 1.0), (cx + r * 0.3, cy - r * 1.55)], P["red"])
    C.poly([(cx - r * 0.92, cy - r * 0.42), (cx - r * 0.5, cy - r * 1.05), (cx + r * 0.3, cy - r * 1.55)], P["red"])
    C.circle(cx + r * 0.32, cy - r * 1.58, r * 0.14, fill=P["cream"])
    C.line([(cx - r * 0.95, cy - r * 0.4), (cx - r * 0.0, cy - r * 1.0)], P["cream"], r * 0.12)


def poster_shelter():
    NIGHT = hexc("1F2D4A")
    C = Canvas(PW, PH, NIGHT)
    ht_rect(C, (0, 400, PW, 1100), P["navy_lt"], 0.0, 0.7, 9, 45)
    rng = np.random.default_rng(9)
    for _ in range(90):
        C.circle(rng.uniform(0, PW), rng.uniform(380, 900), rng.uniform(1, 2.6), fill=P["cream"])
    sprinkle_stars(C, (40, 420, PW - 40, 840), 9, [P["mustard"], P["cream"]], 5, 8, 16, avoid=[(600, 380, 960, 760)])
    sleepy_moon(C, 790, 600, 110)
    for x, s in [(120, 1.4), (190, 1.0)]:
        gull(C, x, 720 + (x % 50), s, P["cream"])
    # hill + shelter
    C.poly([(0, 1000), (200, 900), (420, 860), (640, 870), (860, 920), (PW, 960), (PW, PH), (0, PH)], hexc("2C5F5B"))
    shelter_entrance(C, 512, 1180, 380, hill=P["teal"])
    for x, h in [(90, 230), (180, 170), (850, 250), (950, 190), (300, 120), (730, 130)]:
        pine(C, x, 1190 + (x % 3) * 6, h, shade(P["teal"], 0.6), P["wood_dk"], 4)
    C.rect((0, 1180, PW, 1200), fill=hexc("C9C2B2"))
    C.poly([(430, 1200), (594, 1200), (660, 1290), (364, 1290)], hexc("B6AE9C"))
    # headline
    C.rect((0, 0, PW, 380), fill=P["cream"])
    C.text((512, 175), "Sleep Soundly.", ("pala_bi", 150), P["navy"], "mm")
    C.rect((150, 262, 874, 266), fill=P["red"])
    C.text((512, 318), "HALCYON ASSURED SHELTERS", ("georgia_b", 40), P["red"], "mm", 6)
    C.text((512, 60), "FOR THE FAMILIES OF LARKHAVEN", ("franklin", 24), P["navy"], "mm", 8)
    # info panel
    C.rect((0, 1290, PW, PH), fill=P["cream"])
    C.rect((0, 1290, PW, 1300), fill=P["mustard"])
    C.text((60, 1345), "SHELTER No. 9", ("black", 44), P["navy"], "lm", 2)
    C.text((60, 1392), "Larkhaven Bluff — now accepting resident registrations", ("georgia_i", 25), INK, "lm")
    C.text((60, 1436), "Bunks for 120 · Filtered Air · Ten-Year Pantry · Somnol® Rest Cycle", ("franklin", 21), INK, "lm")
    C.text((60, 1478), "Register today at your Halcyon Showroom, Harbor Square.", ("georgia_bi", 24), P["red"], "lm")
    halcyon_emblem(C, 920, 1410, 70, P["navy"], P["mustard"], P["cream"], P["navy"], P["cream"])
    return finish(C, "poster_shelter", 203, 303)


# =========================================================================== Comet picnic flyer
def picnic_people(C, base, ink):
    """Tiny folks on blankets with a telescope, silhouettes on the bluff."""
    def sitter(x, y, s=1.0):
        C.circle(x, y - 34 * s, 8 * s, fill=ink)
        C.poly([(x - 9 * s, y - 24 * s), (x + 9 * s, y - 24 * s), (x + 14 * s, y), (x - 12 * s, y)], ink)
        C.poly([(x + 8 * s, y - 6 * s), (x + 30 * s, y - 4 * s), (x + 30 * s, y + 2 * s), (x + 8 * s, y + 2 * s)], ink)

    C.poly([(250, base + 4), (380, base + 4), (400, base + 16), (230, base + 16)], P["coral"])
    sitter(280, base + 6)
    sitter(330, base + 6, 0.8)
    C.poly([(560, base + 4), (690, base + 4), (705, base + 16), (545, base + 16)], P["coral"])
    sitter(600, base + 6)
    C.circle(660, base - 4, 6, fill=ink)                         # picnic basket
    C.rect((645, base - 2, 675, base + 8), fill=ink)
    # telescope + standing kid pointing
    C.line([(470, base + 10), (480, base - 40), (490, base + 10)], ink, 3)
    C.line([(470, base - 46), (520, base - 76)], ink, 9)
    C.circle(440, base - 52, 8, fill=ink)
    C.poly([(432, base - 42), (448, base - 42), (452, base + 10), (428, base + 10)], ink)
    C.line([(446, base - 38), (476, base - 70)], ink, 4)


def poster_comet_picnic():
    C = Canvas(PW, PH, P["cream"])
    NAVY, CORAL = P["navy"], P["red"]
    # border
    C.rect((24, 24, PW - 24, PH - 24), outline=NAVY, width=6)
    C.rect((38, 38, PW - 38, PH - 38), outline=NAVY, width=2)
    C.text((512, 96), "THE LARKHAVEN CHAMBER OF COMMERCE PRESENTS", ("franklin", 24), NAVY, "mm", 4)
    C.text((512, 205), "LARKSPUR", ("black", 132), NAVY, "mm", 6)
    C.text((512, 330), "COMET NIGHT", ("impact", 128), CORAL, "mm", 8)
    # vignette circle
    cx, cy, R = 512, 760, 330
    C.circle(cx, cy, R + 14, fill=CORAL)
    C.circle(cx, cy, R, fill=NAVY)
    m = C.mask()
    m.circle(cx, cy, R, fill=255)
    C.halftone_mask(m, mix(NAVY, P["cream"], 0.35), C.lin_tone(cx, cy + R, cx, cy - R, 0.75, 0.0), 8, 45)
    sub = Canvas(PW, PH, (0, 0, 0, 0), C.s, "RGBA")
    rng = np.random.default_rng(13)
    for _ in range(60):
        sub.circle(rng.uniform(cx - R, cx + R), rng.uniform(cy - R, cy + 80), rng.uniform(1, 2.5), fill=P["cream"] + (255,))
    comet(sub, 430, 640, 160, 470, 26, P["cream"] + (255,), P["mustard"] + (255,), CORAL + (255,), 9)
    # bluff + lighthouse far off
    sub.poly([(cx - R, cy + 170), (cx - 120, cy + 110), (cx + 150, cy + 120), (cx + R, cy + 150), (cx + R, cy + R),
              (cx - R, cy + R)], hexc("1A2236") + (255,))
    lighthouse(sub, cx + 250, cy + 150, 120, P["cream"] + (255,), CORAL + (255,), CORAL + (255,), P["mustard"] + (255,),
               hexc("1A2236") + (255,), 2, False)
    picnic_people(sub, cy + 112, hexc("1A2236") + (255,))
    # clip sub to circle
    a = to_np(sub.img.getchannel("A")) * (to_np(m.img) / 255.0)
    sub.img.putalpha(from_np(a, "L"))
    C.img.paste(sub.img, (0, 0), sub.img)
    C.ring(cx, cy, R + 7, 3, P["cream"])
    # text block
    C.text((512, 1150), "Picnic on the Bluff", ("pala_bi", 92), NAVY, "mm")
    C.rect((150, 1214, 874, 1262), fill=NAVY)
    C.text((512, 1239), "FRIDAY · OCTOBER 13 · DUSK TILL MIDNIGHT", ("franklin", 30), P["cream"], "mm", 3)
    lines = ["Lemonade & Pie by the Ladies' Auxiliary", "Telescopes courtesy of the Larkhaven High Science Club",
             "Music by the Harbor Swing Five  ·  Admission Free"]
    for i, l in enumerate(lines):
        C.text((512, 1305 + i * 40), l, ("georgia_i", 28), INK, "mm")
        if i < 2:
            starburst(C, 512, 1325 + i * 40, 7, 1.6, 4, CORAL)
    C.text((512, 1440), "BRING A BLANKET — SEE IT ONCE IN A LIFETIME!", ("black", 28), CORAL, "mm", 1)
    C.text((512, 1484), "Courtesy of Halcyon Electric Co. — Tomorrow, Made Gentle.", ("georgia_i", 20), NAVY, "mm")
    return finish(C, "poster_comet_picnic", 204, 304, screen=0.0, misreg=1.6)


# =========================================================================== Civil Defense
def icon_siren(C, cx, cy, s, col):
    t = T(cx, cy, s)
    C.rect(t.box(-4, 0, 4, 70), fill=col)
    C.poly(t.pts([(-40, -40), (8, -18), (8, 4), (-40, 26)]), col)
    C.rect(t.box(4, -22, 20, 8), fill=col)
    for k in range(3):
        C.arc(t.box(-80 - k * 18, -36 - k * 18, -20 + k * 18, 24 + k * 18), 145, 215, col, t.r(5))


def icon_family(C, cx, cy, s, col):
    t = T(cx, cy, s)
    for x, h in [(-36, 1.0), (0, 0.95), (34, 0.62)]:
        C.circle(*t(x, 30 - 92 * h), t.r(12 * (0.8 + 0.2 * h)), fill=col)
        C.rrect(t.box(x - 14 * h - 4, 30 - 74 * h, x + 14 * h + 4, 30), t.r(8), fill=col)
    C.line(t.pts([(-18, -10), (-14, -10)]), col, t.r(6))


def icon_arrow_shelter(C, cx, cy, s, col, bg):
    t = T(cx, cy, s)
    C.poly(t.pts([(-70, -14), (0, -14), (0, -38), (40, 0), (0, 38), (0, 14), (-70, 14)]), col)
    C.rrect(t.box(46, -42, 96, 42), t.r(22), fill=col, corners=(True, True, False, False))
    C.rect(t.box(56, -10, 86, 42), fill=bg)
    C.text(t(71, -20), "9", ("black", 22 * s), bg, "mm")


def icon_warden(C, cx, cy, s, col, bg):
    t = T(cx, cy, s)
    C.chord(t.box(-34, -64, 34, -4), 180, 360, fill=col)                     # helmet
    C.rect(t.box(-44, -36, 44, -30), fill=col)
    C.circle(*t(0, -18), t.r(16), fill=col)
    C.rrect(t.box(-30, 2, 30, 64), t.r(12), fill=col)
    C.rect(t.box(-30, 16, -16, 30), fill=bg)                                  # armband
    C.line(t.pts([(24, 10), (48, -30), (52, -56)]), col, t.r(10))              # raised hand
    C.circle(*t(52, -60), t.r(9), fill=col)


def poster_civil_defense():
    C = Canvas(PW, PH, P["cream"])
    NAVY, RED = P["navy"], P["red"]
    C.rect((0, 0, PW, 300), fill=RED)
    C.text((512, 70), "A MESSAGE FROM LARKHAVEN CIVIL DEFENSE", ("franklin", 26), P["cream"], "mm", 5)
    C.text_fit((512, 186), "KNOW YOUR SHELTER", "impact", 940, 132, P["cream"], "mm", 2, shadow=(5, 5, INK))
    C.rect((0, 300, PW, 312), fill=NAVY)
    cd_emblem(C, 512, 470, 130, NAVY, P["cream"], RED, P["cream"], P["mustard"], True)
    C.text((512, 640), "In an emergency, every second is calmer with a plan.", ("georgia_i", 30), INK, "mm")
    steps = [
        ("1", "WHEN THE SIREN", "SOUNDS", "Stop what you are doing.", icon_siren),
        ("2", "GATHER YOUR", "FAMILY", "Pets in carriers, please.", icon_family),
        ("3", "PROCEED CALMLY", "TO YOUR SHELTER", "Walk. Do not run.", icon_arrow_shelter),
        ("4", "FOLLOW THE", "WARDEN", "Wardens wear the CD armband.", icon_warden),
    ]
    for i, (num, l1, l2, small, icon) in enumerate(steps):
        col, row = i % 2, i // 2
        x0, y0 = 50 + col * 472, 690 + row * 300
        C.rrect((x0, y0, x0 + 452, y0 + 280), 18, fill=NAVY if i % 3 == 0 else P["teal"])
        C.circle(x0 + 50, y0 + 50, 32, fill=P["mustard"])
        C.text((x0 + 50, y0 + 52), num, ("black", 38), INK, "mm")
        if icon in (icon_arrow_shelter, icon_warden):
            icon(C, x0 + 226, y0 + 100, 0.9, P["cream"], NAVY if i % 3 == 0 else P["teal"])
        else:
            icon(C, x0 + 236, y0 + 92, 0.9, P["cream"])
        C.text((x0 + 226, y0 + 180), l1, ("black", 28), P["cream"], "mm", 1)
        C.text((x0 + 226, y0 + 216), l2, ("black", 32), P["mustard"], "mm", 1)
        C.text((x0 + 226, y0 + 254), small, ("georgia_i", 21), P["cream"], "mm")
    # fill-in card
    C.rect((50, 1300, PW - 50, 1430), fill=P["white"])
    C.rect((50, 1300, PW - 50, 1430), outline=NAVY, width=3)
    C.text((80, 1338), "YOUR ASSIGNED SHELTER:", ("franklin", 26), NAVY, "lm", 2)
    C.line([(410, 1352), (PW - 80, 1352)], NAVY, 2)
    C.text((430, 1334), "No. 9 — Bluff Road", ("inkfree", 40), hexc("2C3E8F"), "lm")
    C.text((80, 1394), "NEAREST CD POST:", ("franklin", 26), NAVY, "lm", 2)
    C.line([(340, 1408), (PW - 80, 1408)], NAVY, 2)
    C.text((360, 1390), "Harbor Square", ("inkfree", 40), hexc("2C3E8F"), "lm")
    C.text((512, 1468), "DO NOT USE THE TELEPHONE  ·  TUNE TO EMERGENCY BROADCAST  ·  REMAIN CALM", ("franklin", 21),
           RED, "mm", 1)
    C.text((512, 1502), "Community shelters provided in cooperation with Halcyon Electric Co.", ("georgia_i", 19), INK, "mm")
    return finish(C, "poster_civil_defense", 205, 305, misreg=1.3)


# =========================================================================== Billboard
def billboard_halcyon():
    BW, BH = 2048, 1024
    C = Canvas(BW, BH, P["cream"])
    sunrays(C, 1350, 1150, 44, 2400, mix(P["cream"], P["mustard"], 0.35), None, 0)
    C.circle(1350, 1150, 560, fill=P["mustard"])
    C.circle(1350, 1150, 470, fill=mix(P["mustard"], P["coral"], 0.4))
    waves(C, 905, 0, BW, 12, 120, P["teal"], 200)
    waves(C, 950, 0, BW, 10, 100, shade(P["teal"], 0.8), 200, 1.3)
    # products
    house(C, 1110, 905, 330, P["cream"], P["coral"], P["white"], P["teal"])
    tv_set(C, 1420, 905, 300)
    tuppence(C, 1760, 420, 1.45, "wave")
    for x, y, s in [(1050, 360, 1.6), (1130, 320, 1.2), (1210, 380, 1.0)]:
        gull(C, x, y, s, P["navy"])
    # left copy
    halcyon_logo(C, 90, 230, 190, P["navy"], P["red"], P["cream"], tagline=False)
    C.text((96, 520), "Tomorrow,", ("pala_bi", 150), P["red"], "lm")
    C.text((96, 680), "Made Gentle.", ("pala_bi", 150), P["navy"], "lm")
    C.rect((0, 960, BW, BH), fill=P["navy"])
    C.text((BW / 2, 992), "TELEVISION  ·  RADIO  ·  VALET ROBOTS  ·  ASSURED SHELTERS  —  SEE THEM ALL AT THE HALCYON "
           "SHOWROOM, HARBOR SQUARE", ("franklin", 30), P["cream"], "mm", 3)
    img = print_finish(C.final(), 206, screen=0.0)
    save(img, "billboard_halcyon")
    # aged: sun-bleached, peeling sheets, overgrown
    aged = age_paper(img, 306, amount=0.85, stains=3, tears=False, creases=0, foxing=30, fade=0.5, dust_violet=14)
    aged = peel_sheets(aged.convert("RGB"), 307)
    aged = overgrow(aged, 308, 0.55, True)
    save(aged, "billboard_halcyon_aged")
    return img


def peel_sheets(img, seed, cols=4, rows=2, pieces=7):
    """Billboard paper is pasted in sheets: tear chunks away from sheet edges, revealing an older ad
    (faded colour) or bare grey board, with a pale torn-paper rim."""
    w, h = img.size
    a = to_np(img)
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    sw, sh = w / cols, h / rows
    board = np.array([128, 124, 114], np.float32) * (0.85 + 0.3 * noise(w, h, 40, seed + 1, 3)[..., None])
    olds = [np.array(c, np.float32) for c in ((196, 150, 126), (150, 164, 172), (218, 206, 176))]
    for k in range(pieces):
        c, r = int(rng.integers(cols)), int(rng.integers(rows))
        x0, y0 = c * sw, r * sh
        xa = x0 + rng.uniform(0, 0.5) * sw
        xb = min(x0 + sw, xa + rng.uniform(0.25, 0.55) * sw)
        depth = rng.uniform(0.15, 0.45) * sh
        from_top = rng.random() < 0.6
        u = np.clip((xx - xa) / max(1, xb - xa), 0, 1)
        prof = np.clip(np.sin(u * math.pi), 0, 1) ** 0.6
        jag = noise(w, h, w / 7, seed + 20 + k, 3)
        dd = depth * prof * (0.55 + 0.6 * jag)
        rel = (yy - y0) if from_top else (y0 + sh - yy)
        inband = (xx >= xa) & (xx < xb) & (rel >= 0) & (rel < sh)
        torn = inband & (rel < dd)
        rim = inband & (rel >= dd) & (rel < dd + 2.0 + 3 * jag)
        oldc = olds[k % 3] * (0.85 + 0.25 * noise(w, h, 12, seed + 40 + k, 2)[..., None])
        bare = noise(w, h, 10, seed + 60 + k, 3) > 0.62
        reveal = np.where(bare[..., None], board, oldc)
        a[torn] = reveal[torn]
        a[rim] = np.array([236, 230, 214], np.float32)
    for c in range(1, cols):
        x = int(c * sw)
        a[:, x - 1:x + 1] *= 0.82
    for r in range(1, rows):
        y = int(r * sh)
        a[y - 1:y + 1] *= 0.85
    return from_np(a, "RGB")


ALL = [poster_starlight_tv, poster_valet_mk2, poster_shelter, poster_comet_picnic, poster_civil_defense,
       billboard_halcyon]

if __name__ == "__main__":
    import sys
    only = sys.argv[1:]
    for fn in ALL:
        if not only or fn.__name__ in only:
            fn()
