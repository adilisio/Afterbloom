"""Eight collectible magazine covers (768x1024): mag_<id>.png"""
from __future__ import annotations

import math

import numpy as np

from common import PAL, Canvas, hexc, mix, print_finish, save, shade
from illus import (T, clipped, halcyon_emblem, atom, boomerang, burst_label, cloud, comet, ellipse_pts, fish, gull, house, ht_rect, ht_shape,
                   lighthouse, mountains, pine, ribbon, rocket, scallop_waves, spiky_star, starburst, sun, tuppence,
                   tv_set, wave_lines, waves)

W, H = 768, 1024
P = PAL
INK = P["ink"]

MANIFEST = [
    ("mag_steady_hand", "Magazine cover: Steady Hand Sportsman (marksmanship)", "Collectible magazine pickup / journal Mags tab; perk: steadier aim"),
    ("mag_tinker", "Magazine cover: Tinker & Spanner (robot repair hobbyists)", "Collectible magazine; perk: Tuppence repair/zap bonus"),
    ("mag_pantry", "Magazine cover: Gentleman's Pantry (cooking)", "Collectible magazine; perk: food heals more"),
    ("mag_astounding", "Magazine cover: Astounding Tomorrow (sci-fi pulp, comet + rocket)", "Collectible magazine; perk: SureShot/Focus"),
    ("mag_outdoorsman", "Magazine cover: Outdoorsman's Almanac (hiking)", "Collectible magazine; perk: sprint stamina"),
    ("mag_hearth", "Magazine cover: Halcyon Home & Hearth (Halcyon house magazine)", "Collectible magazine; living room coffee table (Ch.1)"),
    ("mag_detective", "Magazine cover: Pulp Detective Weekly (noir)", "Collectible magazine; perk: crit/loot finding"),
    ("mag_lighthouse", "Magazine cover: Coastal Keeper (lighthouses & sea)", "Collectible magazine; lighthouse cottage"),
]


def topline(C, y, items, fill, spec=("franklin", 15), tracking=1.5, x0=28, x1=W - 28):
    """Issue strip: items spread across the width (left, centre, right)."""
    C.text((x0, y), items[0], spec, fill, "lm", tracking)
    if len(items) == 3:
        C.text((W / 2, y), items[1], spec, fill, "mm", tracking)
    C.text((x1, y), items[-1], spec, fill, "rm", tracking)


def price_box(C, x, y, fill, text_fill, w=92, h=86):
    C.rect((x, y, x + w, y + h), fill=fill)
    C.text((x + w / 2, y + 36), "35¢", ("black", 34), text_fill, "mm")
    C.text((x + w / 2, y + 68), "OCT 1967", ("franklin", 14), text_fill, "mm", 1.0)


def finish(C, name, seed, **kw):
    img = print_finish(C.final(), seed, **kw)
    save(img, name)
    return img


# =========================================================================== 1 Steady Hand
def rifle(C, x, y, s, rot, wood=P["wood"], metal=INK):
    t = T(x, y, s, rot)
    # stock
    C.poly(t.pts([(-200, 8), (-200, 34), (-150, 30), (-60, 14), (-20, 14), (-20, -4), (-70, -4), (-150, 2)]), wood)
    C.poly(t.pts([(-200, 8), (-200, 34), (-188, 33), (-188, 8)]), shade(wood, 0.6))
    C.poly(t.pts([(-60, 14), (-40, 26), (-34, 14)]), shade(wood, 0.75))  # grip
    # receiver + barrel
    C.poly(t.pts([(-22, -8), (40, -8), (40, 8), (-22, 10)]), metal)
    C.poly(t.pts([(40, -4), (230, -3), (230, 3), (40, 5)]), metal)
    C.poly(t.pts([(20, 6), (150, 6), (150, 12), (20, 14)]), wood)  # fore-end
    C.line(t.pts([(10, -8), (18, -22)]), metal, t.r(5))   # bolt handle
    C.circle(*t(18, -24), t.r(5), fill=metal)
    C.poly(t.pts([(-6, 10), (4, 10), (2, 24), (-10, 26)]), metal)  # trigger guard
    C.poly(t.pts([(222, -3), (226, -11), (230, -3)]), metal)  # front sight


def mag_steady_hand():
    C = Canvas(W, H, P["mustard_lt"])
    # sky: halftone coral rising toward horizon
    ht_rect(C, (0, 170, W, 760), P["coral"], 0.0, 0.85, 7, 45)
    sun(C, 600, 560, 70, P["mustard"], 0)
    mountains(C, 700, 0, W, [(80, 210), (230, 120), (380, 260), (560, 150), (700, 230)], P["navy_lt"])
    mountains(C, 760, 0, W, [(0, 120), (150, 190), (330, 90), (520, 180), (768, 110)], P["teal"])
    for i, x in enumerate(range(10, 780, 46)):
        pine(C, x, 800 + (i % 3) * 8, 120 + (i * 37 % 50), shade(P["teal"], 0.7), P["wood_dk"])
    C.rect((0, 790, W, H), fill=hexc("B98B4E"))
    ht_rect(C, (0, 790, W, H), P["wood_dk"], 0.0, 0.6, 6, 15)
    # target on a stand
    cx, cy = 470, 520
    for lx in (-120, 120):
        C.poly([(cx + lx * 0.6 - 9, cy), (cx + lx - 9, 880), (cx + lx + 9, 880), (cx + lx * 0.6 + 9, cy)], P["wood_dk"])
    C.rect((cx - 205, cy - 205, cx + 205, cy + 205), fill=P["cream"])
    C.rect((cx - 205, cy - 205, cx + 205, cy + 205), outline=P["wood_dk"], width=6)
    for r, col in [(185, INK), (178, P["cream"]), (150, INK), (122, P["cream"]), (95, P["navy"]), (68, P["cream"]),
                   (44, P["red"]), (16, P["cream"])]:
        C.circle(cx, cy, r, fill=col)
    # shot group
    for hx, hy in [(cx - 6, cy + 4), (cx + 9, cy - 5), (cx + 2, cy + 12), (cx - 30, cy - 22)]:
        C.circle(hx, hy, 6.5, fill=P["cream"])
        C.circle(hx, hy, 4.5, fill=INK)
    # pin
    C.circle(cx - 190, cy - 190, 6, fill=hexc("9A9A9A"))
    C.circle(cx + 190, cy - 190, 6, fill=hexc("9A9A9A"))
    rifle(C, 360, 880, 1.5, -8)
    # masthead
    C.rect((0, 0, W, 170), fill=P["cream"])
    C.rect((0, 0, W, 34), fill=P["navy"])
    topline(C, 17, ["THE MAGAZINE OF THE CAREFUL SHOT", "OCTOBER 1967  ·  35¢"], P["cream"], ("franklin", 14), 1.6)
    C.text((W / 2 + 4, 104 + 4), "STEADY HAND", ("impact", 118), P["navy"], "mm", 2)
    C.text((W / 2, 104), "STEADY HAND", ("impact", 118), P["red"], "mm", 2)
    C.rect((40, 160, W - 40, 164), fill=P["navy"])
    C.rect((250, 150, W - 250, 176), fill=P["cream"])
    C.text((W / 2, 162), "S P O R T S M A N", ("georgia_b", 22), P["navy"], "mm", 2)
    # cover lines
    C.text((30, 222), "BREATHE.", ("black", 40), P["navy"], "la")
    C.text((30, 266), "HOLD.", ("black", 40), P["navy"], "la")
    C.text((30, 310), "SQUEEZE.", ("black", 40), P["red"], "la")
    C.para((32, 362, 262, 460), "The champion's secret to a trigger pull that never wavers", ("georgia_i", 19), INK, 1.2)
    ribbon(C, W / 2, 965, 560, 58, P["red"], "IRON SIGHTS vs. GLASS: Which Is Yours?", ("black", 26))
    burst_label(C, 655, 290, 82, P["navy"], [("DUCK", 26), ("SEASON", 22), ("PREVIEW!", 20)], P["mustard"], 16, -14)
    return finish(C, "mag_steady_hand", 101)


# =========================================================================== 2 Tinker & Spanner
def gear(C, cx, cy, r, teeth, fill, hole=None, rot=0.0):
    pts = []
    for i in range(teeth * 4):
        a = math.radians(rot) + i * 2 * math.pi / (teeth * 4)
        rr = r if (i % 4) in (1, 2) else r * 0.82
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    C.poly(pts, fill)
    if hole:
        C.circle(cx, cy, r * 0.35, fill=hole)


def spanner(C, x, y, s, rot, fill):
    t = T(x, y, s, rot)
    C.poly(t.pts([(-70, -7), (60, -7), (60, 7), (-70, 7)]), fill)
    C.circle(*t(70, 0), t.r(20), fill=fill)
    C.circle(*t(-78, 0), t.r(15), fill=fill)
    C.poly(t.pts([(78, -9), (100, -9), (100, 9), (78, 9)]), P["navy"])
    C.circle(*t(-78, 0), t.r(7), fill=P["navy"])


def mag_tinker():
    BLUE = hexc("2B4C7E")
    C = Canvas(W, H, BLUE)
    # blueprint grid
    for x in range(0, W, 24):
        C.line([(x, 0), (x, H)], mix(BLUE, P["white"], 0.12 if x % 96 else 0.25), 1)
    for y in range(0, H, 24):
        C.line([(0, y), (W, y)], mix(BLUE, P["white"], 0.12 if y % 96 else 0.25), 1)
    lc = mix(BLUE, P["white"], 0.55)
    # blueprint drawing of a valet arm + dimension lines
    C.circle(150, 560, 70, outline=lc, width=2)
    C.circle(150, 560, 30, outline=lc, width=2)
    C.line([(150, 470), (150, 650)], lc, 1)
    C.line([(60, 560), (240, 560)], lc, 1)
    C.line([(80, 680), (220, 680)], lc, 2)
    C.text((150, 698), "Ø 140 mm", ("courier_b", 15), lc, "mm")
    C.rect((560, 420, 720, 560), outline=lc, width=2)
    C.line([(560, 420), (720, 560)], lc, 1)
    C.line([(720, 420), (560, 560)], lc, 1)
    C.text((640, 578), "SERVO HOUSING — FIG. 3", ("courier_b", 13), lc, "mm")
    gear(C, 110, 860, 60, 12, mix(BLUE, P["white"], 0.3), BLUE, 8)
    gear(C, 190, 930, 38, 9, mix(BLUE, P["white"], 0.3), BLUE, 0)
    # glow behind robot
    C.circle(400, 640, 250, fill=mix(BLUE, P["mustard"], 0.18))
    C.circle(400, 640, 210, fill=mix(BLUE, P["mustard"], 0.32))
    tuppence(C, 392, 360, 1.5, "thumbs")
    spanner(C, 580, 600, 1.05, -50, hexc("D8D4C8"))
    # oil can at feet
    C.poly([(560, 870), (620, 870), (612, 930), (568, 930)], P["red"])
    C.poly([(605, 878), (660, 840), (664, 846), (612, 888)], hexc("D8D4C8"))
    C.text((590, 905), "OIL", ("black", 14), P["cream"], "mm")
    # masthead
    C.rect((0, 0, W, 198), fill=P["mustard"])
    C.rect((0, 198, W, 206), fill=INK)
    gear(C, 70, 98, 58, 10, INK, P["mustard"], 4)
    gear(C, W - 70, 98, 58, 10, INK, P["mustard"], 13)
    C.text((W / 2, 70), "TINKER", ("bahn", 92, {"wght": 700, "wdth": 75}), INK, "mm", 6)
    C.text((W / 2, 150), "& SPANNER", ("bahn", 70, {"wght": 700, "wdth": 75}), P["red"], "mm", 5)
    C.rect((0, 206, W, 238), fill=INK)
    topline(C, 222, ["FOR THE HOME MECHANIC", "OCT 1967 · No. 118", "35¢"], P["mustard"], ("franklin", 15), 1.5)
    # cover lines
    C.rect((24, 262, 300, 410), fill=P["cream"])
    C.text((40, 296), "KEEP YOUR VALET", ("black", 20), P["red"], "lm")
    C.text((40, 330), "HUMMING", ("black", 36), INK, "lm")
    C.para((40, 352, 290, 410), "12 lube points owners forget", ("georgia_i", 18), INK, 1.15)
    C.text((W - 28, 286), "Build a", ("georgia_bi", 26), P["cream"], "rm")
    C.text((W - 28, 324), "TRANSISTOR PAL", ("black", 28), P["mustard"], "rm")
    C.text((W - 28, 358), "for under $5", ("georgia_bi", 26), P["cream"], "rm")
    ribbon(C, W / 2 + 40, 975, 520, 54, P["red"], "Readers' Workshop: The Toaster That Sings", ("georgia_bi", 25))
    return finish(C, "mag_tinker", 102)


# =========================================================================== 3 Gentleman's Pantry
def gingham(C, box, col, cell=28):
    x0, y0, x1, y1 = box
    a = mix(col, P["white"], 0.55)
    for x in range(int(x0), int(x1), cell * 2):
        C.rect((x, y0, x + cell, y1), fill=a)
    for y in range(int(y0), int(y1), cell * 2):
        C.rect((x0, y, x1, y + cell), fill=a)
    for x in range(int(x0), int(x1), cell * 2):
        for y in range(int(y0), int(y1), cell * 2):
            C.rect((x, y, x + cell, y + cell), fill=col)


def jello(C, cx, base, s):
    """Tiered gelatin mould with vertical fluting."""
    t = T(cx, base, s)
    layers = [(P["red"], 118, 58), (P["mustard"], 98, 50), (P["teal_lt"], 78, 44), (P["coral"], 56, 38)]
    y = 0
    for col, hw, hh in layers:
        C.rrect(t.box(-hw, y - hh, hw, y), t.r(18), fill=col)
        nf = 6
        for k in range(nf):
            x0 = -hw + (k + 0.62) * hw * 2 / nf
            C.rrect(t.box(x0, y - hh + 8, x0 + hw * 2 / nf * 0.3, y - 6), t.r(6), fill=shade(col, 0.84))
        C.rrect(t.box(-hw + 8, y - hh + 8, -hw + 8 + hw * 0.12, y - 8), t.r(6), fill=mix(col, P["white"], 0.5))
        C.rect(t.box(-hw + 6, y - 6, hw - 6, y), fill=shade(col, 0.7))
        y -= hh
    C.circle(*t(0, y - 14), t.r(18), fill=P["red"])
    C.line(t.pts([(0, y - 30), (10, y - 60)]), P["teal"], t.r(4))
    C.circle(*t(-6, y - 20), t.r(5), fill=P["white"])


def mag_pantry():
    C = Canvas(W, H, P["cream"])
    # wallpaper backdrop: teal with little stars
    C.rect((0, 220, W, 640), fill=P["teal"])
    for i, y in enumerate(range(250, 640, 64)):
        for x in range(30 + (i % 2) * 48, W, 96):
            starburst(C, x, y, 12, 3, 4, mix(P["teal"], P["cream"], 0.35))
    # table with gingham cloth
    C.rect((0, 640, W, H), fill=P["white"])
    gingham(C, (0, 640, W, H), P["red"], 30)
    C.rect((0, 636, W, 652), fill=shade(P["red"], 0.7))
    # platter + jello
    C.ellipse((214, 760, 554, 840), fill=shade(P["cream"], 0.82))
    C.ellipse((204, 740, 564, 820), fill=hexc("E9E3D3"))
    C.ellipse((234, 752, 534, 808), fill=hexc("F6F2E8"))
    jello(C, 384, 790, 1.25)
    # cutlery
    for sx, kind in ((-1, "fork"), (1, "knife")):
        x = 384 + sx * 300
        C.rrect((x - 9, 680, x + 9, 960), 8, fill=hexc("D8D4C8"))
        if kind == "fork":
            for k in (-7, 0, 7):
                C.rect((x + k - 2, 640, x + k + 2, 700), fill=hexc("D8D4C8"))
        else:
            C.rrect((x - 14, 610, x + 10, 760), 12, fill=hexc("E8E4DA"))
    # masthead
    C.rect((0, 0, W, 220), fill=P["cream"])
    C.text((W / 2, 38), "THE", ("georgia_b", 22), P["red"], "mm", 8)
    C.text((W / 2 + 3, 100 + 3), "Gentleman's", ("pala_bi", 92), P["mustard"], "mm")
    C.text((W / 2, 100), "Gentleman's", ("pala_bi", 92), P["navy"], "mm")
    C.rect((60, 152, 230, 155), fill=P["red"])
    C.rect((W - 230, 152, W - 60, 155), fill=P["red"])
    C.text((W / 2, 160), "PANTRY", ("georgia_b", 48), P["red"], "mm", 14)
    topline(C, 202, ["GOOD EATING FOR THE MODERN MAN", "OCTOBER 1967", "35¢"], P["navy"], ("franklin", 14), 1.2)
    # cover lines on teal
    C.text((32, 262), "Sunday Roast", ("georgia_bi", 40), P["cream"], "la")
    C.text((32, 308), "in Under an Hour!", ("georgia_bi", 32), P["mustard"], "la")
    C.text((32, 430), "THE BACHELOR'S", ("black", 22), P["cream"], "la")
    C.text((32, 458), "GUIDE TO GELATIN", ("black", 30), P["mustard"], "la")
    C.text((32, 498), "seven shimmering showstoppers", ("georgia_i", 19), P["cream"], "la")
    burst_label(C, 640, 320, 86, P["red"], [("CANNED", 22), ("GOODS,", 22), ("UNCANNY", 18), ("RESULTS", 18)], P["cream"], 18, 10)
    return finish(C, "mag_pantry", 103)


# =========================================================================== 4 Astounding Tomorrow
def mag_astounding():
    SPACE = hexc("1A2236")
    C = Canvas(W, H, SPACE)
    rng = np.random.default_rng(4)
    ht_rect(C, (0, 200, W, H), P["navy"], 0.9, 0.2, 7, 30)
    for _ in range(140):
        x, y = rng.uniform(0, W), rng.uniform(200, H)
        C.circle(x, y, rng.uniform(0.7, 2.2), fill=P["cream"])
    for _ in range(9):
        starburst(C, rng.uniform(20, W - 20), rng.uniform(240, 900), rng.uniform(7, 14), 2, 4, P["cream"])
    # ringed planet
    px, py, pr = 600, 330, 110
    C.ellipse((px - 200, py - 34, px + 200, py + 34), outline=P["mustard"], width=10)
    C.circle(px, py, pr, fill=P["coral"])
    ht_shape(C, lambda m: m.circle(px, py, pr, fill=255), shade(P["red"], 0.8), C.lin_tone(px - pr, py, px + pr, py, 0.0, 0.9), 6, 45)
    for k, yy in enumerate((-50, -10, 40)):
        C.chord((px - pr, py + yy - 10, px + pr, py + yy + 10), 0, 180, fill=mix(P["coral"], P["mustard"], 0.5))
    C.arc((px - 200, py - 34, px + 200, py + 34), 0, 180, P["mustard"], 10)
    # the comet (Larkspur) — lilac hint in the tail
    comet(C, 190, 590, 150, 330, 20, P["white"], mix(P["cream"], P["violet"], 0.35), mix(P["coral"], P["violet"], 0.45), 9,
          glow=mix(SPACE, P["violet"], 0.5))
    # moon surface
    C.ellipse((-200, 820, W + 200, 1300), fill=hexc("C9C2B2"))
    for cx, cy, r in [(120, 900, 40), (420, 870, 26), (620, 940, 50), (300, 980, 30)]:
        C.ellipse((cx - r, cy - r * 0.35, cx + r, cy + r * 0.35), fill=shade(hexc("C9C2B2"), 0.8))
    rocket(C, 560, 690, 1.05, 24, P["cream"], P["red"], P["teal"])
    # masthead: pulp
    C.rect((0, 0, W, 200), fill=P["mustard"])
    C.poly([(0, 200), (W, 200), (W, 212), (0, 222)], P["red"])
    C.text((30, 60), "ASTOUNDING", ("impact", 96), P["red"], "lm", 1)
    C.text((34, 146), "TOMORROW", ("impact", 92), INK, "lm", 7)
    C.rect((W - 150, 18, W - 22, 178), fill=INK)
    C.text((W - 86, 62), "35¢", ("black", 40), P["mustard"], "mm")
    C.text((W - 86, 108), "OCT", ("impact", 30), P["cream"], "mm", 2)
    C.text((W - 86, 142), "1967", ("impact", 30), P["cream"], "mm", 2)
    C.text((W - 86, 168), "NO. 47", ("franklin", 13), P["cream"], "mm", 1)
    # cover lines
    C.text((30, 252), "THE COMET", ("impact", 46), P["mustard"], "la", 2)
    C.text((30, 300), "THAT CAME", ("impact", 46), P["mustard"], "la", 2)
    C.text((30, 348), "TO STAY", ("impact", 46), P["mustard"], "la", 2)
    C.text((32, 406), "a startling novelette by LYDIA MARSH", ("georgia_i", 18), P["cream"], "la")
    C.rect((26, 852, 300, 944), fill=P["red"])
    C.text((163, 880), "ROBOTS OF THE", ("black", 20), P["cream"], "mm")
    C.text((163, 916), "RUST MOON", ("impact", 38), P["mustard"], "mm", 2)
    C.text((W - 30, 990), "PLUS: Is Anybody Out There? — and 4 more tales", ("georgia_bi", 21), INK, "rm")
    return finish(C, "mag_astounding", 104, paper=(250, 244, 230))


# =========================================================================== 5 Outdoorsman's Almanac
def hiker(C, x, base, h, pack=P["red"], body=INK):
    t = T(x, base, h / 200)
    C.poly(t.pts([(-14, -100), (-26, 0), (-14, 0), (0, -70), (10, -40), (22, 0), (34, 0), (16, -100)]), body)  # legs
    C.rrect(t.box(-18, -168, 18, -96), t.r(10), fill=body)
    C.rrect(t.box(-46, -170, -8, -100), t.r(8), fill=pack)  # backpack
    C.rect(t.box(-48, -110, -6, -98), fill=P["wood_dk"])    # bedroll
    C.circle(*t(4, -186), t.r(15), fill=body)
    C.poly(t.pts([(-14, -194), (22, -194), (14, -206), (-6, -206)]), body)   # hat
    C.line(t.pts([(14, -150), (40, -110), (50, -40)]), body, t.r(7))
    C.line(t.pts([(50, -120), (58, 0)]), P["wood_dk"], t.r(4))  # walking stick


def mag_outdoorsman():
    C = Canvas(W, H, P["mustard_lt"])
    ht_rect(C, (0, 150, W, 560), P["coral"], 0.75, 0.05, 7, 45)
    sun(C, 384, 520, 120, P["mustard"], 24, 0.35, mix(P["mustard"], P["coral"], 0.3))
    mountains(C, 620, 0, W, [(60, 260), (200, 380), (330, 250), (470, 360), (640, 230), (768, 290)], P["navy_lt"], P["cream"])
    mountains(C, 700, 0, W, [(0, 150), (130, 230), (300, 120), (480, 200), (640, 110), (768, 170)], P["navy"])
    C.rect((0, 690, W, H), fill=P["teal"])
    # trail
    C.poly([(330, 690), (380, 690), (520, H), (180, H)], hexc("D8B98A"))
    ht_shape(C, lambda m: m.poly([(330, 690), (380, 690), (520, H), (180, H)], 255), P["wood"], 0.25, 5, 20)
    for i, (x, b, hh) in enumerate([(40, 860, 260), (120, 900, 300), (650, 880, 280), (730, 940, 330), (240, 760, 120),
                                    (520, 760, 140), (580, 790, 170)]):
        pine(C, x, b, hh, shade(P["teal"], 0.65 if i % 2 else 0.5), P["wood_dk"], 4)
    hiker(C, 420, 880, 210)
    for x, y, s in [(200, 360, 1.2), (250, 335, 0.9), (520, 330, 1.0)]:
        gull(C, x, y, s, INK)
    # masthead
    C.rect((0, 0, W, 150), fill=P["teal"])
    C.text((W / 2, 30), "OUTDOORSMAN'S", ("georgia_b", 30), P["mustard"], "mm", 9)
    C.text((W / 2, 100), "ALMANAC", ("black", 84), P["cream"], "mm", 6)
    C.rect((0, 150, W, 182), fill=P["cream"])
    topline(C, 166, ["TRAIL · CAMP · COAST", "OCTOBER 1967", "35¢"], P["teal"], ("franklin", 15), 2)
    # cover lines
    C.rrect((24, 206, 330, 312), 10, fill=P["cream"])
    C.text((42, 236), "50 MILES OF", ("black", 22), P["teal"], "lm")
    C.text((42, 272), "COAST TRAIL", ("black", 32), P["red"], "lm")
    C.text((44, 298), "mapped, mile by mile", ("georgia_i", 17), INK, "lm")
    C.text((W - 30, 222), "Pack Light,", ("georgia_bi", 36), P["navy"], "ra")
    C.text((W - 30, 262), "Walk Far", ("georgia_bi", 36), P["navy"], "ra")
    ribbon(C, W / 2, 975, 560, 54, P["red"], "Reading the Weather by the Gulls", ("georgia_bi", 27))
    return finish(C, "mag_outdoorsman", 105)


# =========================================================================== 6 Halcyon Home & Hearth
def mag_hearth():
    C = Canvas(W, H, P["cream"])
    # room interior: wall + floor
    C.rect((0, 230, W, 760), fill=P["coral_lt"])
    for x in range(0, W, 64):
        starburst(C, x + 32, 270 + (x // 64 % 2) * 60, 10, 2.5, 4, mix(P["coral_lt"], P["white"], 0.5))
        starburst(C, x + 32, 390 + (x // 64 % 2) * 60, 10, 2.5, 4, mix(P["coral_lt"], P["white"], 0.5))
    C.rect((0, 760, W, H), fill=P["teal"])
    ht_rect(C, (0, 760, W, H), shade(P["teal"], 0.7), 0.0, 0.7, 6, 0)
    # starburst wall clock
    for i in range(12):
        a = math.radians(i * 30)
        C.line([(140 + 34 * math.cos(a), 330 + 34 * math.sin(a)), (140 + 74 * math.cos(a), 330 + 74 * math.sin(a))],
               P["wood_dk"], 4)
        C.circle(140 + 76 * math.cos(a), 330 + 76 * math.sin(a), 5, fill=P["mustard"])
    C.circle(140, 330, 32, fill=P["cream"])
    C.line([(140, 330), (140, 308)], INK, 3)
    C.line([(140, 330), (156, 336)], INK, 3)
    # floor lamp
    C.line([(712, 470), (712, 770)], INK, 4)
    C.poly([(680, 400), (744, 400), (760, 470), (664, 470)], P["mustard"])
    C.ellipse((682, 762, 742, 776), fill=INK)
    # TV
    def scr(box):
        x0, y0, x1, y1 = box

        def scene(S):
            S.rect(box, fill=hexc("CFE3DF"))
            sun(S, (x0 + x1) / 2, y0 + (y1 - y0) * 0.55, 30, P["mustard"], 12)
            waves(S, y0 + (y1 - y0) * 0.66, x0, x1, 4, 30, P["teal"], (y1 - y0) * 0.34 + 4)
        clipped(C, lambda m: m.rrect(box, 20, fill=255), scene)
        C.rrect(box, 20, outline=hexc("D8D4C8"), width=4)
    tv_set(C, 300, 800, 330, screen_fn=scr)
    tuppence(C, 560, 470, 0.95, "tray")
    # masthead
    C.rect((0, 0, W, 230), fill=P["navy"])
    halcyon_emblem(C, 92, 108, 66, P["mustard"], P["mustard"], P["cream"], P["navy"], P["cream"])
    C.text((178, 54), "HALCYON", ("georgia_b", 30), P["mustard"], "lm", 12)
    C.text((174, 126), "Home & Hearth", ("pala_bi", 76), P["cream"], "lm")
    C.rect((178, 172, W - 30, 174), fill=P["mustard"])
    C.text((178, 196), "Tomorrow, Made Gentle.", ("georgia_i", 20), P["mustard"], "lm")
    C.text((W - 30, 196), "OCTOBER 1967 · 35¢", ("franklin", 15), P["cream"], "rm", 1.5)
    # cover lines
    C.rect((W - 300, 250, W - 24, 380), fill=P["navy"])
    C.text((W - 162, 278), "MEET THE", ("franklin", 18), P["cream"], "mm", 4)
    C.text((W - 162, 318), "Starlight '68", ("pala_bi", 40), P["mustard"], "mm")
    C.text((W - 162, 356), "COLOR COMES HOME!", ("black", 18), P["cream"], "mm")
    C.text((28, 450), "Your Shelter,", ("georgia_bi", 32), P["navy"], "la")
    C.text((28, 488), "Your Peace of Mind", ("georgia_bi", 32), P["navy"], "la")
    C.text((30, 530), "Halcyon Assured No. 9 opens its doors", ("georgia_i", 17), INK, "la")
    ribbon(C, W / 2, 970, 560, 54, P["red"], "Recipes from the Halcyon Test Kitchen", ("georgia_bi", 26))
    return finish(C, "mag_hearth", 106)


# =========================================================================== 7 Pulp Detective Weekly
def fedora_man(C, x, base, h, col=INK):
    t = T(x, base, h / 300)
    C.poly(t.pts([(-60, 0), (-70, -150), (-58, -200), (58, -200), (70, -150), (60, 0), (20, 0), (0, -60), (-20, 0)]), col)  # coat
    C.poly(t.pts([(-62, -196), (-40, -232), (40, -232), (62, -196)]), col)   # shoulders
    C.rect(t.box(-14, -246, 14, -228), fill=col)
    C.ellipse(t.box(-24, -290, 24, -236), fill=col)
    C.ellipse(t.box(-56, -292, 56, -276), fill=col)                        # brim
    C.poly(t.pts([(-30, -284), (-26, -318), (0, -310), (26, -318), (30, -284)]), col)  # crown
    C.line(t.pts([(-28, -290), (28, -290)]), P["red"], t.r(5))             # hat band
    # cigarette ember + smoke
    C.circle(*t(32, -252), t.r(3), fill=P["mustard"])


def mag_detective():
    C = Canvas(W, H, hexc("37465A"))
    ht_rect(C, (0, 220, W, H), hexc("1E1B22"), 0.2, 0.95, 7, 45)
    # big yellow window with blinds and woman silhouette
    wx0, wy0, wx1, wy1 = 360, 250, 720, 650
    C.rect((wx0, wy0, wx1, wy1), fill=P["mustard"])
    # silhouette in window
    t = T(560, 650, 1.0)
    C.ellipse(t.box(-28, -330, 28, -268), fill=hexc("1E1B22"))
    C.ellipse(t.box(-50, -350, 40, -300), fill=hexc("1E1B22"))  # bouffant
    C.poly(t.pts([(-16, -272), (16, -272), (60, -220), (40, 0), (-40, 0), (-60, -220)]), hexc("1E1B22"))
    for k in range(13):
        y = wy0 + 12 + k * 31
        C.rect((wx0, y, wx1, y + 12), fill=shade(P["mustard"], 0.62))
    C.rect((wx0 - 10, wy0 - 10, wx1 + 10, wy0), fill=INK)
    C.rect((wx0 - 10, wy1, wx1 + 10, wy1 + 12), fill=INK)
    # blind shadows across the wall/floor
    for k in range(9):
        y = 700 + k * 36
        C.poly([(0, y + 90), (W, y), (W, y + 14), (0, y + 104)], mix(hexc("1E1B22"), P["mustard"], 0.18))
    # street lamp glow + rain
    C.glow(140, 330, 300, P["coral"], 0.75, 1.3)
    C.line([(140, 330), (140, H)], INK, 10)
    C.poly([(110, 320), (170, 320), (156, 290), (124, 290)], INK)
    C.circle(140, 332, 12, fill=P["mustard"])
    rng = np.random.default_rng(7)
    for _ in range(170):
        x, y = rng.uniform(-40, W), rng.uniform(220, H)
        C.line([(x, y), (x + 10, y + 34)], mix(hexc("1E1B22"), P["cream"], 0.35), 1.2)
    fedora_man(C, 220, 1010, 560)
    # masthead
    C.rect((0, 0, W, 220), fill=P["red"])
    C.text((W / 2, 42), "PULP", ("impact", 60), INK, "mm", 30)
    C.text((W / 2 + 4, 134 + 4), "DETECTIVE", ("impact", 120), INK, "mm", 2)
    C.text((W / 2, 134), "DETECTIVE", ("impact", 120), P["cream"], "mm", 2)
    C.rect((0, 196, W, 224), fill=INK)
    topline(C, 210, ["WEEKLY", "OCTOBER 14, 1967", "35¢"], P["mustard"], ("franklin", 15), 3)
    # cover lines
    C.text((W - 32, 690), "THE LIGHTHOUSE", ("impact", 46), P["cream"], "ra", 1)
    C.text((W - 32, 738), "MURDERS", ("impact", 70), P["red"], "ra", 2)
    C.text((W - 32, 820), "Complete Novel: Fog Over Pier Nine", ("georgia_bi", 22), P["mustard"], "ra")
    C.rect((W - 330, 880, W - 24, 960), fill=P["mustard"])
    C.text((W - 177, 906), "DEAD MEN", ("black", 26), INK, "mm")
    C.text((W - 177, 938), "DON'T TUNE IN", ("black", 26), P["red"], "mm")
    return finish(C, "mag_detective", 107, paper=(248, 242, 228))


# =========================================================================== 8 Coastal Keeper
def mag_lighthouse():
    NIGHT = hexc("22314F")
    C = Canvas(W, H, NIGHT)
    ht_rect(C, (0, 180, W, 700), P["teal"], 0.0, 0.75, 7, 45)
    rng = np.random.default_rng(8)
    for _ in range(70):
        C.circle(rng.uniform(0, W), rng.uniform(190, 520), rng.uniform(0.7, 1.8), fill=P["cream"])
    # moon
    C.circle(110, 440, 46, fill=P["cream"])
    C.circle(132, 430, 41, fill=mix(NIGHT, P["teal"], 0.3))
    # headland + lighthouse
    C.poly([(300, 760), (420, 640), (560, 610), (690, 640), (W, 700), (W, 820), (300, 820)], hexc("2A3A2F"))
    lighthouse(C, 560, 640, 400, P["cream"], P["red"], P["red"], P["mustard"], INK, 3, True,
               mix(P["mustard_lt"], P["white"], 0.2), 190)
    C.rect((600, 590, 660, 640), fill=P["cream"])  # keeper's cottage
    C.poly([(594, 592), (630, 566), (666, 592)], P["red"])
    C.rect((618, 606, 632, 620), fill=P["mustard"])
    # sea
    C.rect((0, 700, W, H), fill=P["navy"])
    for k in range(7):
        wave_lines(C, 730 + k * 40, -10, W + 10, 6, 70 + k * 8, mix(P["navy"], P["cream"], 0.25 + k * 0.05), 3, k)
    scallop_waves(C, 930, -40, W + 40, 32, P["teal"], 1, depth=120)
    for x in range(-40, W + 40, 64):
        C.arc((x - 22, 930 - 22, x + 22, 930 + 22), 180, 360, P["cream"], 3)
    # little boat
    C.poly([(140, 800), (250, 800), (232, 826), (158, 826)], P["red"])
    C.line([(195, 800), (195, 720)], INK, 3)
    C.poly([(198, 724), (198, 796), (246, 796)], P["cream"])
    for x, y, s in [(330, 420, 1.0), (380, 450, 0.8), (260, 470, 0.7)]:
        gull(C, x, y, s, P["cream"])
    # masthead
    C.rect((0, 0, W, 180), fill=P["cream"])
    C.text((W / 2, 30), "THE MAGAZINE OF SHORE & SEA", ("franklin", 16), P["navy"], "mm", 4)
    C.text((W / 2, 106), "Coastal Keeper", ("georgia_bi", 90), P["navy"], "mm")
    for x in (60, W - 60):
        starburst(C, x, 106, 18, 4, 4, P["red"])
    C.rect((0, 166, W, 170), fill=P["red"])
    topline(C, 196, ["VOL. 9 · NO. 10", "OCTOBER 1967", "35¢"], P["cream"], ("franklin", 15), 2)
    # cover lines
    C.text((30, 236), "Keeping the Light:", ("georgia_bi", 34), P["cream"], "la")
    C.text((32, 276), "A NIGHT AT LARKHAVEN LIGHT", ("black", 20), P["mustard"], "la")
    C.text((30, 560), "KNOTS", ("black", 34), P["mustard"], "la")
    C.text((30, 600), "every keeper", ("georgia_bi", 24), P["cream"], "la")
    C.text((30, 630), "should know", ("georgia_bi", 24), P["cream"], "la")
    ribbon(C, W / 2, 985, 520, 52, P["red"], "Storm Season: Are You Ready?", ("georgia_bi", 27))
    return finish(C, "mag_lighthouse", 108, paper=(250, 244, 230))


ALL = [mag_steady_hand, mag_tinker, mag_pantry, mag_astounding, mag_outdoorsman, mag_hearth, mag_detective, mag_lighthouse]

if __name__ == "__main__":
    import sys
    only = sys.argv[1:]
    for fn in ALL:
        if not only or fn.__name__ in only:
            fn()
