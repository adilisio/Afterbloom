"""Product labels (512x256): tonic bottle, two tins, two ammo boxes. Opaque, print-finished, lightly worn."""
from __future__ import annotations

import math

import numpy as np

from common import PAL, Canvas, age_paper, hexc, mix, print_finish, save, shade
from illus import T, ellipse_pts, fish, gull, halcyon_emblem, ribbon, spiky_star, starburst

W, H = 512, 256
P = PAL
INK = P["ink"]

MANIFEST = [
    ("label_pep_tonic", "Bottle label: Halcyon Pep Tonic (healing tonic)", "Aid item: healing tonic bottle (pickup + journal Items icon)"),
    ("label_sardines", "Tin label: Sea Biscuit Sardines", "Aid/food item: sardine tin"),
    ("label_beans", "Can wrap label: Gull Brand Pork & Beans", "Aid/food item: bean can (wrap around cylinder)"),
    ("label_ammo_pistol", "Ammo box face: .38 Halcyon Defense cartridges", "Ammo pickup for service pistol"),
    ("label_ammo_rifle", "Ammo box face: .30 Marksman cartridges", "Ammo pickup for bolt-action rifle"),
]


def finish(C, name, seed, wear=0.35):
    img = print_finish(C.final(), seed, misreg=0.8)
    if wear:
        img = age_paper(img, seed + 5, amount=wear, stains=1, tears=False, creases=0, foxing=8, fade=0.15)
        img = img.convert("RGB")
    save(img, name)
    return img


def frame(C, inset, col, width=3, r=10):
    C.rrect((inset, inset, W - inset, H - inset), r, outline=col, width=width)


def fine(C, xy, txt, col, size=10, anchor="mm", name="franklin"):
    C.text(xy, txt, (name, size), col, anchor)


def cartridge(C, x, y, s, rot=0, brass=P["brass"], lead=hexc("8C8C8C")):
    t = T(x, y, s, rot)
    C.poly(t.pts([(-9, -22), (-9, 34), (-11, 36), (-11, 42), (11, 42), (11, 36), (9, 34), (9, -22)]), brass)
    C.poly(t.pts([(3, -22), (9, -22), (9, 34), (3, 34)]), shade(brass, 0.8))
    C.poly(t.pts([(-8, -22), (-7, -36), (-3, -44), (3, -44), (7, -36), (8, -22)]), lead)
    C.poly(t.pts([(-8, -22), (-7, -36), (-4, -42), (-3, -30), (-4, -22)]), mix(lead, P["white"], 0.4))
    C.rect(t.box(-9, 30, 9, 33), fill=shade(brass, 0.65))


# --------------------------------------------------------------------------- Pep Tonic
def label_pep_tonic():
    C = Canvas(W, H, P["cream"])
    C.rect((0, 0, W, 34), fill=P["navy"])
    C.rect((0, H - 34, W, H), fill=P["navy"])
    for x in range(0, W, 24):
        starburst(C, x + 12, 17, 6, 1.6, 4, P["mustard"])
        starburst(C, x + 12, H - 17, 6, 1.6, 4, P["mustard"])
    C.rect((0, 34, W, 38), fill=P["red"])
    C.rect((0, H - 38, W, H - 34), fill=P["red"])
    # emblem
    halcyon_emblem(C, 84, 128, 58, P["navy"], P["mustard"], P["cream"], P["navy"], P["cream"])
    C.text((84, 202), "SINCE 1931", ("franklin", 10), P["navy"], "mm", 2)
    # wordmark & name
    C.text((156, 66), "Halcyon", ("pala_bi", 34), P["navy"], "lm")
    C.text((290, 70), "LABORATORIES", ("georgia_b", 11), P["navy"], "lm", 2.5)
    C.text((154, 118), "PEP TONIC", ("impact", 60), P["red"], "lm", 2)
    C.rect((156, 150, 486, 152), fill=P["navy"])
    C.text((156, 168), "Restorative Elixir for Vim & Vigor", ("georgia_bi", 17), P["navy"], "lm")
    C.text((156, 192), "IRON · MALT · VITAMIN B  —  Alc. 12% by vol.", ("franklin", 11), INK, "lm", 0.6)
    C.text((156, 208), "Take one tablespoon after meals, or as your physician directs.", ("georgia_i", 10.5), INK, "lm")
    spiky_star(C, 452, 96, 38, 14, P["mustard"], 0.8)
    C.text((452, 88), "8", ("black", 22), P["navy"], "mm")
    C.text((452, 108), "FL. OZ.", ("franklin", 10), P["navy"], "mm", 1)
    return finish(C, "label_pep_tonic", 401)


# --------------------------------------------------------------------------- Sardines
def label_sardines():
    SEA = P["teal"]
    C = Canvas(W, H, SEA)
    # wave pattern background
    for k in range(9):
        y = 30 + k * 26
        pts = [(x, y + 5 * math.sin(x / 18 + k)) for x in np.linspace(-5, W + 5, 120)]
        C.line(pts, mix(SEA, P["cream"], 0.18), 2)
    frame(C, 8, P["cream"], 3, 14)
    frame(C, 14, P["mustard"], 1.5, 10)
    # oval cartouche with fish
    C.ellipse((26, 46, 214, 210), fill=P["cream"])
    C.ellipse((32, 52, 208, 204), outline=P["red"], width=3)
    fish(C, 112, 110, 1.05, hexc("8FA3B0"), hexc("5F7584"), INK, False, False)
    fish(C, 132, 158, 0.85, hexc("A9B9C3"), hexc("5F7584"), INK, False, False)
    # name
    C.text_fit((368, 60), "SEA BISCUIT", "black", 240, 38, P["cream"], "mm", stroke=4, stroke_fill=P["red"])
    C.text_fit((368, 60), "SEA BISCUIT", "black", 240, 38, P["cream"], "mm")
    ribbon(C, 370, 112, 236, 40, P["red"], "SARDINES", ("impact", 34), P["cream"], tail=24, tracking=4)
    C.text((370, 158), "in Pure Olive Oil", ("georgia_bi", 22), P["mustard"], "mm")
    C.text((370, 188), "Packed at the Larkhaven Cannery, Larkhaven, Calif.", ("franklin", 10.5), P["cream"], "mm", 0.4)
    C.text((370, 222), "NET WT. 3¾ OZ.", ("black", 13), P["cream"], "mm", 2)
    C.text((120, 226), "KEY OPENS AT THIS END  ►", ("franklin", 9.5), P["cream"], "mm", 1)
    return finish(C, "label_sardines", 402)


# --------------------------------------------------------------------------- Pork & Beans
def bean_pot(C, x, y, s):
    t = T(x, y, s)
    C.ellipse(t.box(-46, -30, 46, -14), fill=hexc("6E3B24"))
    for bx, by in [(-26, -24), (-10, -27), (8, -25), (24, -23), (-16, -19), (2, -18), (18, -19), (34, -22), (-34, -21)]:
        C.ellipse(t.box(bx - 7, by - 4, bx + 7, by + 4), fill=hexc("B4562E"))
        C.ellipse(t.box(bx - 4, by - 3, bx, by - 1), fill=mix(hexc("B4562E"), P["white"], 0.4))
    C.chord(t.box(-52, -60, 52, 50), 0, 180, fill=P["wood"])
    C.rect(t.box(-52, -22, 52, -6), fill=P["wood"])
    C.rrect(t.box(-56, -26, 56, -14), t.r(6), fill=shade(P["wood"], 0.75))
    C.chord(t.box(30, -60, 52, 50), 270, 90, fill=shade(P["wood"], 0.8))
    for sx in (-1, 1):
        C.arc(t.box(sx * 56 - 10, -24, sx * 56 + 10, -4), 0, 360, shade(P["wood"], 0.6), t.r(3))
    C.rect(t.box(-30, 6, 30, 10), fill=P["mustard"])
    for k in range(3):
        C.arc(t.box(-14 + k * 12, -66 - k * 4, -4 + k * 12, -38 - k * 4), 100, 260, P["cream"], t.r(2))


def label_beans():
    BG = P["mustard"]
    C = Canvas(W, H, BG)
    C.rect((0, 0, W, 30), fill=P["red"])
    C.rect((0, H - 30, W, H), fill=P["red"])
    for x in range(0, W, 16):
        C.rect((x, 30, x + 8, 36), fill=P["cream"])
        C.rect((x, H - 36, x + 8, H - 30), fill=P["cream"])
    C.text((W / 2, 15), "GULL BRAND · FINE FOODS · LARKHAVEN · CALIF.", ("franklin", 11), P["cream"], "mm", 2.5)
    C.text((W / 2, H - 15), "NET WT. 1 LB. (16 OZ.)  ·  INGREDIENTS: BEANS, TOMATO, PORK, SUGAR, SALT, SPICE", ("franklin", 9.5),
           P["cream"], "mm", 0.6)
    # gull roundel
    C.circle(86, 128, 66, fill=P["navy"])
    C.circle(86, 128, 58, fill=P["sky"])
    C.pieslice((28, 70, 144, 186), 0, 180, fill=P["teal"])
    for k in range(3):
        y = 140 + k * 12
        C.line([(30 + k * 2, y), (142 - k * 2, y)], mix(P["teal"], P["white"], 0.4), 2)
    C.circle(86, 128, 58, outline=P["navy"], width=3)
    C.circle(110, 96, 12, fill=P["mustard"])
    gull(C, 80, 112, 1.6, P["navy"], 4.5, 0.6)
    gull(C, 58, 92, 0.8, P["navy"], 2.5, 0.3)
    # name block
    C.text((326, 62), "Gull Brand", ("georgia_bi", 34), P["navy"], "mm")
    C.text((326, 112), "PORK & BEANS", ("impact", 52), P["red"], "mm", 1.5, stroke=3, stroke_fill=P["cream"])
    C.text((326, 112), "PORK & BEANS", ("impact", 52), P["red"], "mm", 1.5)
    C.rect((196, 142, 422, 172), fill=P["navy"])
    C.text_fit((309, 157), "SLOW-BAKED IN TOMATO SAUCE", "franklin", 214, 14, P["cream"], "mm", 1.2)
    bean_pot(C, 462, 190, 0.5)
    C.text((198, 196), "Heat & serve — hearty enough", ("georgia_i", 13), INK, "lm")
    C.text((198, 212), "for any working man.", ("georgia_i", 13), INK, "lm")
    return finish(C, "label_beans", 403)


# --------------------------------------------------------------------------- ammo
def label_ammo_pistol():
    C = Canvas(W, H, P["navy"])
    C.rect((0, 0, 196, H), fill=P["red"])
    for k in range(-6, 14):
        x = k * 30
        C.poly([(x, 0), (x + 14, 0), (x + 14 - 120, H), (x - 120, H)], shade(P["red"], 0.9))
    C.rect((202, 0, W, H), fill=P["navy"])
    C.rect((196, 0, 202, H), fill=P["cream"])
    for i, x in enumerate((60, 98, 136)):
        cartridge(C, x, 132 + (i % 2) * 6, 1.5)
    C.text((98, 226), "50 CARTRIDGES", ("black", 14), P["cream"], "mm", 1)
    C.text((98, 26), "CENTER-FIRE", ("franklin", 12), P["cream"], "mm", 2)
    # right panel
    halcyon_emblem(C, 236, 44, 24, P["mustard"], P["mustard"], P["navy"], P["cream"], P["navy"])
    C.text((268, 36), "Halcyon", ("pala_bi", 24), P["cream"], "lm")
    C.text((270, 58), "DEFENSE PRODUCTS DIVISION", ("franklin", 9.5), P["mustard"], "lm", 1.2)
    C.text((354, 118), ".38", ("impact", 74), P["mustard"], "mm", 1)
    C.text((354, 166), "SPECIAL", ("black", 24), P["cream"], "mm", 6)
    C.rect((214, 186, 496, 188), fill=P["mustard"])
    C.text((355, 204), "For Home & Shelter Security", ("georgia_bi", 15), P["cream"], "mm")
    C.text((355, 228), "158 GR. LEAD ROUND NOSE  ·  KEEP OUT OF REACH OF CHILDREN", ("franklin", 8.5), mix(P["cream"], P["navy"], 0.25),
           "mm", 0.4)
    return finish(C, "label_ammo_pistol", 404, 0.3)


def label_ammo_rifle():
    GREEN = hexc("3F5B3A")
    C = Canvas(W, H, P["cream"])
    C.rect((0, 0, W, 64), fill=GREEN)
    C.rect((0, H - 44, W, H), fill=GREEN)
    C.rect((0, 64, W, 70), fill=P["mustard"])
    C.rect((0, H - 50, W, H - 44), fill=P["mustard"])
    C.text((24, 34), "MARKSMAN", ("bahn", 44, {"wght": 700, "wdth": 75}), P["cream"], "lm", 5)
    C.text((W - 24, 24), "AMMUNITION CO.", ("franklin", 12), P["mustard"], "rm", 2)
    C.text((W - 24, 46), "LARKHAVEN · CALIF.", ("franklin", 10), P["cream"], "rm", 2)
    # target emblem
    cx, cy = 86, 138
    for r, col in [(56, GREEN), (48, P["cream"]), (38, GREEN), (28, P["cream"]), (18, P["red"]), (7, P["cream"])]:
        C.circle(cx, cy, r, fill=col)
    C.line([(cx - 64, cy), (cx + 64, cy)], INK, 1.5)
    C.line([(cx, cy - 64), (cx, cy + 64)], INK, 1.5)
    C.text((292, 112), ".30", ("impact", 72), P["red"], "mm", 1)
    C.text((390, 96), "CAL.", ("black", 16), GREEN, "lm", 2)
    C.text((390, 124), "RIFLE", ("black", 16), GREEN, "lm", 2)
    C.text_fit((286, 168), "20 CENTER-FIRE CARTRIDGES", "black", 262, 15, INK, "mm", 0.5)
    C.text((310, 190), "Precision for the Steady Hand", ("georgia_bi", 15), GREEN, "mm")
    for i in range(5):
        cartridge(C, 444 + i * 12, 170, 0.55, 0)
    C.text((W / 2, H - 22), "150 GR. POINTED SOFT POINT  ·  NOT FOR USE IN WORN OR DEFECTIVE ARMS", ("franklin", 9),
           P["cream"], "mm", 0.6)
    return finish(C, "label_ammo_rifle", 405, 0.3)


ALL = [label_pep_tonic, label_sardines, label_beans, label_ammo_pistol, label_ammo_rifle]

if __name__ == "__main__":
    import sys
    only = sys.argv[1:]
    for fn in ALL:
        if not only or fn.__name__ in only:
            fn()
