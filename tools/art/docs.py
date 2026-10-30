"""Printed/handwritten documents: The Larkhaven Ledger newspaper, June's note, shelter registration card."""
from __future__ import annotations

import math

import numpy as np
from PIL import Image

from common import (PAL, Canvas, age_paper, from_np, halftone, hexc, mix, noise, print_finish, save, shade,
                    to_np)
from illus import (cd_emblem, comet, gull, halcyon_emblem, house, lighthouse, pine, shelter_entrance, starburst,
                   tuppence)

P = PAL
INK = P["ink"]
NEWS_INK = hexc("1E1C1A")
BLUE_INK = hexc("27408B")

MANIFEST = [
    ("newspaper_ledger", "The Larkhaven Ledger, Sat. Oct 14 1967: COMET PASSES TONIGHT / Halcyon opens Shelter No. 9",
     "Kitchen table / porch (Ch.1), readable close-up"),
    ("newspaper_ledger_aged", "Same paper, yellowed, folded, torn, stained (1978)", "Ruined town, diner, shelter"),
    ("note_june", "June's handwritten note on lined paper ('Follow the music... I'll leave the light on. — J.')",
     "On June's empty bunk in Shelter No. 9 (Ch.3), journal close-up"),
    ("note_registrar", "Halcyon Assured shelter registration card, typed, Resident #31", "Given by Registrar 9 at the door (Ch.1); journal item"),
]

# --------------------------------------------------------------------------- copy
COMET_STORY = (
    "LARKHAVEN, Oct. 14 — The Larkspur Comet, a visitor last seen when this coast was charted by sail, will make its "
    "closest pass tonight, and the whole town, it seems, intends to be on the bluff to greet it. "
    "Observers at the Mount Corwin station say the comet's head will clear the eastern hills shortly after nine "
    "o'clock and climb into the southern sky by midnight, its tail stretching some forty degrees. "
    "\"It is a harmless spectacle and a beautiful one,\" said Dr. Edwin Pell of the Larkhaven High Science Club, "
    "which will set out six telescopes beside the old signal house. \"The tail is nothing but a little dust and "
    "gas lit up by the Sun. Bring a blanket and a thermos and enjoy it.\" "
    "The Chamber of Commerce reports that more than four hundred residents attended last night's picnic, where the "
    "Harbor Swing Five played until the lanterns ran out and the Ladies' Auxiliary sold sixty-one pies. "
    "Fishing captains returning before dawn described a faint shimmer on the swells beyond the breakwater, "
    "which the Weather Bureau attributes to the comet's reflected light. Harbormaster Gus Oyelaran urged boaters "
    "to keep their lamps lit and their radios on. "
    "Residents are reminded that Bluff Road will be closed to automobiles after eight o'clock. Parking is "
    "available at Harbor Square, and the Halcyon Showroom will keep its doors open late with free coffee for "
    "comet watchers. "
    "Old-timers along the waterfront were less sure. \"My grandmother said the last one turned the milk,\" "
    "laughed Edna Marlow, who will serve a blueberry-and-lemon Comet Pie at the diner all weekend. \"I say a "
    "comet is a good excuse for pie.\" "
    "Pastor Whitcombe of the Seaside Chapel will ring the bell at nine o'clock so that the whole town may look up "
    "together, and the lighthouse will dim its lamp for one hour by special arrangement with the Coast Guard, so "
    "as not to spoil the view. "
    "Parents are asked to keep young children well back from the cliff edge, and dogs on leads. Volunteer "
    "wardens of the Larkhaven Civil Defense will be on hand with lanterns and first-aid kits. "
    "Those who miss tonight's pass will have to wait a good while for another chance: by the reckoning of the "
    "Mount Corwin observers, the Larkspur Comet will not return for some four hundred years. "
    "A full viewing guide, with a star chart, appears on Page 6."
)
SHELTER_STORY = (
    "Halcyon Electric Co. will open the doors of Halcyon Assured Shelter No. 9, set into the bluff above town, "
    "to registered residents this morning, the company announced Friday. "
    "The shelter, the ninth of its kind on the Pacific coast, offers bunks for one hundred twenty, a filtered-air "
    "plant, a ten-year pantry, and the company's new Somnol rest cycle, which a spokesman described as \"the "
    "gentlest night's sleep a family could ask for.\" "
    "Registration is being handled door to door by Halcyon courier units. Residents who have not yet received a "
    "visit may register in person at the Halcyon Showroom in Harbor Square. "
    "\"We hope no one ever needs it,\" said regional manager Clifford Ames at the ribbon-cutting. \"But peace of "
    "mind is the finest appliance we make.\" "
    "An open house with refreshments will be held at the shelter gate from ten o'clock. Household appliances, "
    "including Valet units, are not admitted below ground."
)
GLOW_STORY = (
    "Crews of the trawlers Mary Dean and Little Wren reported a pale violet glow on the water some three miles "
    "out before dawn. \"Like the sea had powdered its nose,\" said deckhand Lou Petrakis. The Coast Guard "
    "says there is no cause for alarm."
)
SWING_STORY = (
    "The Harbor Swing Five, fresh from a sold-out night on the bluff, will return to the bandstand at Marlow's "
    "Diner on Sunday afternoon. Dancing encouraged."
)


def words_flow(C, boxes, text, spec, fill, leading=1.18, first_indent=12):
    """Flow justified text through a list of column boxes; returns leftover words."""
    words = text.split()
    sp = C.text_w(" ", spec)
    lh = spec[1] * leading
    i = 0
    first = True
    for (x0, y0, x1, y1) in boxes:
        y = y0
        while i < len(words) and y + lh <= y1 + 1:
            ind = first_indent if first else 0
            maxw = x1 - x0 - ind
            line = [words[i]]
            wsum = C.text_w(words[i], spec)
            j = i + 1
            while j < len(words) and wsum + sp * len(line) + C.text_w(words[j], spec) <= maxw:
                wsum += C.text_w(words[j], spec)
                line.append(words[j])
                j += 1
            last = j >= len(words)
            xs = x0 + ind
            if len(line) > 1 and not last:
                gap = (maxw - wsum) / (len(line) - 1)
            else:
                gap = sp
            cx = xs
            for w_ in line:
                C.text((cx, y), w_, spec, fill)
                cx += C.text_w(w_, spec) + gap
            y += lh
            i = j
            first = False
    return words[i:]


def halftone_photo(draw_fn, w, h, pitch=3.4, seed=0, ink=NEWS_INK, paper=(250, 246, 236)):
    """Render a greyscale illustration via draw_fn(C) and convert it to a newspaper halftone (RGB)."""
    C = Canvas(w, h, (235, 235, 235), 2)
    draw_fn(C)
    g = C.final().convert("L")
    big = g.resize((w * 3, h * 3), Image.BICUBIC)
    tone = 1.0 - to_np(big) / 255.0
    tone = np.clip(tone * 1.1 - 0.03, 0, 1)
    cov = halftone(tone, pitch * 3, 45, aa=1.6)
    a = np.array(paper, np.float32) * (1 - cov[..., None]) + np.array(ink, np.float32) * cov[..., None]
    out = from_np(a, "RGB").resize((w, h), Image.LANCZOS)
    return out


def grey(v):
    return (v, v, v)


def photo_comet(C):
    C.rect((0, 0, C.w, C.h), fill=grey(40))
    rng = np.random.default_rng(3)
    for _ in range(80):
        C.circle(rng.uniform(0, C.w), rng.uniform(0, C.h * 0.6), rng.uniform(0.6, 1.6), fill=grey(230))
    C.glow(C.w * 0.62, C.h * 0.3, 120, grey(120), 0.6, 1.4)
    comet(C, C.w * 0.62, C.h * 0.32, 160, C.w * 0.5, 9, grey(250), grey(190), grey(130), 8)
    C.poly([(0, C.h * 0.78), (C.w * 0.3, C.h * 0.68), (C.w * 0.7, C.h * 0.72), (C.w, C.h * 0.66), (C.w, C.h), (0, C.h)], grey(18))
    lighthouse(C, C.w * 0.85, C.h * 0.68, C.h * 0.38, grey(200), grey(90), grey(90), grey(240), grey(18), 3, True, grey(90), 120)
    for x in (0.2, 0.26, 0.34, 0.45, 0.52):
        C.circle(C.w * x, C.h * 0.7, 4, fill=grey(10))
        C.rect((C.w * x - 4, C.h * 0.7 + 2, C.w * x + 4, C.h * 0.74), fill=grey(10))


def photo_shelter(C):
    C.rect((0, 0, C.w, C.h), fill=grey(205))
    cloud(C) if False else None
    shelter_entrance(C, C.w * 0.5, C.h * 0.86, C.w * 0.62, grey(185), grey(140), grey(20), grey(230), "9", grey(95))
    for x, hh in [(0.08, 0.5), (0.18, 0.38), (0.86, 0.46), (0.95, 0.36)]:
        pine(C, C.w * x, C.h * 0.88, C.h * hh, grey(60), grey(40), 4)
    C.rect((0, C.h * 0.86, C.w, C.h), fill=grey(170))
    # ribbon + little crowd
    C.line([(C.w * 0.18, C.h * 0.76), (C.w * 0.82, C.h * 0.76)], grey(30), 3)
    for i, x in enumerate(np.linspace(0.08, 0.92, 11)):
        hh = C.h * (0.16 + 0.03 * (i % 3))
        bx = C.w * x
        C.circle(bx, C.h - hh - 2, hh * 0.17, fill=grey(30 + 15 * (i % 3)))
        C.rrect((bx - hh * 0.27, C.h - hh + hh * 0.16, bx + hh * 0.27, C.h + 30), hh * 0.2, fill=grey(30 + 18 * (i % 4)))


def ledger(aged=False):
    W, H = 1024, 1400
    C = Canvas(W, H, (250, 247, 238), 2)
    K = NEWS_INK
    M = 34
    # ears
    C.rect((M, 30, M + 190, 112), outline=K, width=2)
    C.text((M + 95, 46), "WEATHER", ("franklin", 15), K, "mm", 3)
    C.para((M + 10, 58, M + 182, 110), "Fair and cool. High 64, low 51. Comet visible after 9 p.m.", ("times", 14), K,
           1.1, "center")
    C.rect((W - M - 190, 30, W - M, 112), outline=K, width=2)
    C.text((W - M - 95, 52), "HOME EDITION", ("franklin", 15), K, "mm", 2)
    C.text((W - M - 95, 86), "10¢", ("times_b", 40), K, "mm")
    # masthead
    C.text((W / 2, 50), "The", ("times_bi", 26), K, "mm")
    C.text_fit((W / 2, 98), "Larkhaven Ledger", "times_b", 560, 84, K, "mm")
    C.rect((M, 134, W - M, 137), fill=K)
    C.rect((M, 140, W - M, 141), fill=K)
    C.text((M, 156), "VOL. LXXXI — No. 287", ("times", 15), K, "lm")
    C.text((W / 2, 156), "LARKHAVEN, ON THE PACIFIC — SATURDAY, OCTOBER 14, 1967", ("times_b", 15), K, "mm", 1)
    C.text((W - M, 156), "TWENTY-FOUR PAGES", ("times", 15), K, "rm")
    C.rect((M, 170, W - M, 171), fill=K)
    C.rect((M, 174, W - M, 177), fill=K)
    # banner headline
    C.text_fit((W / 2, 238), "COMET PASSES TONIGHT", "times_b", W - 2 * M, 112, K, "mm", 1)
    C.text((W / 2, 306), "Larkspur to Come Closest in Living Memory; Town Turns Out on the Bluff;", ("times_bi", 25), K, "mm")
    C.text((W / 2, 336), "Astronomers Call It ‘A Harmless Spectacle’", ("times_bi", 25), K, "mm")
    C.rect((M, 358, W - M, 359), fill=K)
    # column grid: 5 cols
    gut = 16
    cw = (W - 2 * M - 4 * gut) / 5
    colx = [M + i * (cw + gut) for i in range(5)]
    rule = mix(K, (250, 247, 238), 0.4)
    for i in range(1, 5):
        x = colx[i] - gut / 2
        C.rect((x, 372 if i == 3 else 780, x + 1, 1180), fill=rule)
    body = ("times", 13.5)
    # comet photo spanning cols 0-2
    pw = int(colx[2] + cw - colx[0])
    ph = 300
    photo = halftone_photo(photo_comet, pw, ph, 3.2, 1)
    C.paste(photo, (colx[0], 372))
    C.rect((colx[0], 372, colx[0] + pw, 372 + ph), outline=K, width=1)
    C.para((colx[0], 678, colx[0] + pw, 720),
           "TONIGHT'S VISITOR — The Larkspur Comet as sketched from Lantern Point by Ledger staff artist "
           "Ruth Ann Dale. Best viewing after nine o'clock, looking south over the bay.", ("times_i", 13), K, 1.15)
    C.rect((colx[0], 718, colx[0] + pw, 719), fill=K)
    C.text((colx[0], 738), "Townsfolk Gather for Once-in-a-Lifetime View", ("times_b", 20), K, "lm")
    C.text((colx[0], 762), "By HAROLD MERCER, Ledger Staff Writer", ("times_i", 13), K, "lm")
    left = words_flow(C, [(colx[0], 780, colx[0] + cw, 1176), (colx[1], 780, colx[1] + cw, 1176),
                          (colx[2], 780, colx[2] + cw, 1176)], COMET_STORY, body, K)
    # right: shelter story
    rx0, rx1 = colx[3], colx[4] + cw
    C.text((rx0 + (rx1 - rx0) / 2, 386), "HALCYON OPENS", ("times_b", 30), K, "mm")
    C.text((rx0 + (rx1 - rx0) / 2, 420), "SHELTER No. 9", ("times_b", 30), K, "mm")
    C.text((rx0 + (rx1 - rx0) / 2, 450), "TO RESIDENTS", ("times_b", 22), K, "mm", 2)
    C.rect((rx0 + 60, 468, rx1 - 60, 469), fill=K)
    C.para((rx0, 476, rx1, 530), "Bluff Refuge Ready ‘For Peace of Mind’; Open House Today at Ten",
           ("times_i", 17), K, 1.15, "center")
    sp = halftone_photo(photo_shelter, int(rx1 - rx0), 200, 3.2, 2)
    C.paste(sp, (rx0, 530))
    C.rect((rx0, 530, rx1, 730), outline=K, width=1)
    C.para((rx0, 736, rx1, 776), "RIBBON CUT — Residents gather at the gate of Shelter No. 9 on Larkhaven Bluff.",
           ("times_i", 13), K, 1.15)
    words_flow(C, [(colx[3], 780, colx[3] + cw, 1176), (colx[4], 780, colx[4] + cw, 1176)], SHELTER_STORY, body, K)
    # lower band
    C.rect((M, 1186, W - M, 1189), fill=K)
    by = 1200
    # small story 1
    C.text((colx[0], by + 10), "Fishermen Report Odd Glow", ("times_b", 18), K, "lm")
    words_flow(C, [(colx[0], by + 26, colx[1] + cw, H - 40)], GLOW_STORY, body, K)
    # ad box
    ax0, ax1 = colx[2], colx[3] + cw
    C.rect((ax0, by, ax1, H - 40), outline=K, width=3)
    C.rect((ax0 + 5, by + 5, ax1 - 5, H - 45), outline=K, width=1)
    C.text(((ax0 + ax1) / 2, by + 40), "Marlow's Diner", ("script_b", 34), K, "mm")
    C.text(((ax0 + ax1) / 2, by + 84), "COMET PIE", ("franklin", 30), K, "mm", 4)
    C.text(((ax0 + ax1) / 2, by + 114), "Blueberry & lemon — 25¢ a slice", ("times_i", 16), K, "mm")
    C.text(((ax0 + ax1) / 2, by + 140), "Harbor Square · Open 6 a.m.", ("times", 14), K, "mm")
    starburst(C, ax0 + 40, by + 84, 16, 3, 8, K)
    starburst(C, ax1 - 40, by + 84, 16, 3, 8, K)
    # small story 2
    C.text((colx[4], by + 10), "Swing Five Returns", ("times_b", 17), K, "lm")
    words_flow(C, [(colx[4], by + 26, colx[4] + cw, H - 40)], SWING_STORY, body, K)
    C.rect((M, H - 30, W - M, H - 29), fill=K)
    img = print_finish(C.final(), 401, paper=(250, 246, 236), grain=1.1, mottle=0.8, misreg=0.0)
    # faint centre fold
    a = to_np(img)
    yy = np.arange(H, dtype=np.float32)[:, None]
    fold = np.exp(-((yy - H / 2) / 2.0) ** 2) * 0.10 + np.exp(-((yy - H / 2 - 3) / 6.0) ** 2) * 0.04
    a *= (1 - fold)[..., None]
    img = from_np(a, "RGB")
    save(img, "newspaper_ledger")
    aged = age_paper(img, 402, amount=1.0, stains=4, tears=True, creases=1, foxing=90, fade=0.3,
                     yellow=(214, 180, 118), dust_violet=8)
    # strong centre fold crease in the aged copy
    a = to_np(aged)
    fold = np.exp(-((yy - H / 2) / 1.6) ** 2) * 0.28
    lift = np.exp(-((yy - H / 2 + 3) / 2.5) ** 2) * 0.18
    a[..., :3] = a[..., :3] * (1 - fold)[..., None] + (255 - a[..., :3]) * lift[..., None]
    save(from_np(a, "RGBA"), "newspaper_ledger_aged")


# =========================================================================== June's note
def note_june():
    W, H = 768, 1024
    C = Canvas(W, H, (250, 248, 240), 2)
    # ruled paper
    top = 140
    gap = 54
    for y in np.arange(top, H - 20, gap):
        C.line([(0, y), (W, y)], (150, 182, 214), 1.6)
    C.line([(92, 0), (92, H)], (222, 120, 120), 2)
    C.line([(97, 0), (97, H)], (232, 160, 160), 1)
    for y in (180, 512, 844):
        C.circle(40, y, 17, fill=(70, 66, 62))
    # handwriting, line by line on the rules with slight drift
    lines = [
        ("They said we couldn't", 0), ("wake you. We tried", 0), ("for days.", 0), ("", 0),
        ("We're going to the", 0), ("lighthouse — Rory's radio.", 0), ("Follow the music.", 1), ("", 0),
        ("I'll leave the light on.", 0), ("", 0), ("— J.", 2),
    ]
    rng = np.random.default_rng(31)
    spec = ("inkfree", 54)
    y = top + gap * 1 - 6
    for i, (txt, kind) in enumerate(lines):
        if txt:
            x0 = 120 + rng.uniform(-4, 6) if kind != 2 else 470
            sub = C.sub(W, 90)
            sub.text((x0, 62), txt, spec, BLUE_INK + (255,), "ls")
            if kind == 1:
                w = C.text_w(txt, spec)
                pts = [(x0 + t * w, 72 + math.sin(t * 9) * 1.5) for t in np.linspace(0, 1, 30)]
                sub.line(pts, BLUE_INK + (255,), 2.5)
                sub.line([(p[0], p[1] + 6) for p in pts[2:-3]], BLUE_INK + (255,), 2)
            C.paste_canvas(sub, (0, y - 62 + 4), rotate=rng.uniform(-0.8, 0.8))
        y += gap
    # crossed-out word in margin note + doodles: lighthouse with beams and music notes
    lx, ly = 300, 960
    C.line([(lx - 18, ly), (lx - 12, ly - 90), (lx + 12, ly - 90), (lx + 18, ly)], BLUE_INK, 2.5, False)
    C.line([(lx - 18, ly), (lx + 18, ly)], BLUE_INK, 2.5)
    C.rect((lx - 14, ly - 108, lx + 14, ly - 90), outline=BLUE_INK, width=2.5)
    C.line([(lx - 16, ly - 108), (lx, ly - 124), (lx + 16, ly - 108)], BLUE_INK, 2.5)
    for k in (-1, 1):
        C.line([(lx + k * 18, ly - 100), (lx + k * 90, ly - 124)], BLUE_INK, 2)
        C.line([(lx + k * 18, ly - 96), (lx + k * 90, ly - 84)], BLUE_INK, 2)
    for nx, ny in [(400, 850), (430, 822), (370, 884)]:
        C.ellipse((nx - 9, ny - 6, nx + 7, ny + 6), fill=BLUE_INK)
        C.line([(nx + 6, ny), (nx + 6, ny - 34)], BLUE_INK, 2.5)
        C.line([(nx + 6, ny - 34), (nx + 18, ny - 24)], BLUE_INK, 2.5)
    # little heart after the signature
    hx, hy = 638, top + gap * 11 - 28
    C.circle(hx - 6, hy, 7, outline=BLUE_INK, width=2.5)
    C.circle(hx + 6, hy, 7, outline=BLUE_INK, width=2.5)
    C.line([(hx - 13, hy + 2), (hx, hy + 18), (hx + 13, hy + 2)], BLUE_INK, 2.5)
    img = print_finish(C.final(), 501, paper=(252, 250, 244), grain=0.8, mottle=0.4, misreg=0)
    # torn-from-spiral top edge
    a = to_np(img.convert("RGBA"))
    xs = np.arange(W)
    edge = 10 + 6 * noise(W, 8, W / 6, 9, 2)[0] + 4 * (np.sin(xs / 24 * math.pi) > 0.6)
    yy = np.arange(H)[:, None]
    a[..., 3] *= np.clip((yy - edge[None, :]) / 1.2, 0, 1)
    img = from_np(a, "RGBA")
    aged = age_paper(img, 502, amount=0.45, stains=1, tears=False, creases=2, foxing=25, fade=0.12, dust_violet=5)
    save(aged, "note_june")


# =========================================================================== registration card
def typed(C, xy, txt, spec=("courier_b", 22), fill=(28, 26, 30), seed=0):
    rng = np.random.default_rng(seed)
    x, y = xy
    f = C.font(spec)
    for ch in txt:
        dy = rng.normal(0, 0.5)
        dark = rng.uniform(0.0, 0.35)
        col = mix(fill, (240, 236, 224), dark)
        C.text((x + rng.normal(0, 0.25), y + dy), ch, spec, col, "ls")
        x += f.getlength(ch) / C.s


def note_registrar():
    W, H = 1024, 640
    CARD = (244, 236, 214)
    NAVY = P["navy"]
    C = Canvas(W, H, CARD, 2)
    # stub with perforation
    sx = 820
    for y in range(10, H, 14):
        C.circle(sx, y, 2.6, fill=shade(CARD, 0.75))
    C.rect((0, 0, W, 92), fill=NAVY)
    halcyon_emblem(C, 62, 46, 36, P["mustard"], P["mustard"], P["cream"], NAVY, P["cream"])
    C.text((114, 32), "HALCYON ASSURED COMMUNITY SHELTERS", ("georgia_b", 24), P["cream"], "lm", 2)
    C.text((114, 64), "Resident Registration Card  ·  Form HA-9", ("georgia_i", 19), P["mustard"], "lm")
    C.text((W - 102, 32), "ADMIT", ("franklin", 18), P["cream"], "mm", 3)
    C.text((W - 102, 62), "ONE", ("franklin", 18), P["cream"], "mm", 3)
    fields = [
        (126, "SHELTER No.", "9  (LARKHAVEN BLUFF)"),
        (178, "HOUSEHOLD", "14 GULL LANE, LARKHAVEN"),
        (230, "BUNK ASSIGNMENT", "DORMITORY B, BUNK 31"),
        (282, "REST CYCLE", "SOMNOL (STANDARD) - APPROVED"),
        (334, "REGISTERED BY", "COURIER UNIT R-9"),
        (386, "DATE / TIME", "OCT 14 1967   09:12 AM"),
    ]
    for i, (y, label, val) in enumerate(fields):
        C.text((40, y), label, ("franklin", 15), NAVY, "ls", 1.5)
        C.line([(210, y + 4), (sx - 30, y + 4)], mix(NAVY, CARD, 0.4), 1.2)
        typed(C, (222, y), val, seed=10 + i)
    # resident number box
    C.text((40, 444), "RESIDENT No.", ("franklin", 15), NAVY, "ls", 1.5)
    C.rect((40, 456, 250, 556), outline=NAVY, width=3)
    typed(C, (70, 536), "31", ("courier_b", 84), seed=7)
    C.para((280, 452, 580, 620),
           "Present this card at the shelter gate. Admission is limited to registered residents of the household named "
           "above. Household appliances, including Valet units, remain above ground. Halcyon Electric Co. thanks you "
           "for your trust — Tomorrow, Made Gentle.", ("georgia_i", 15), NAVY, 1.3)
    # stub
    C.text(((sx + W) / 2, 140), "STUB", ("franklin", 15), NAVY, "mm", 4)
    C.text(((sx + W) / 2, 196), "SHELTER", ("franklin", 14), NAVY, "mm", 1)
    typed(C, ((sx + W) / 2 - 10, 236), "9", ("courier_b", 40), seed=3)
    C.text(((sx + W) / 2, 290), "RESIDENT", ("franklin", 14), NAVY, "mm", 1)
    typed(C, ((sx + W) / 2 - 26, 336), "31", ("courier_b", 40), seed=4)
    for k in range(6):
        y = 420 + k * 26
        C.rect((sx + 30, y, W - 30, y + 14), fill=(28, 26, 30) if k % 2 == 0 else mix(NAVY, CARD, 0.5))
    # red rubber stamp
    st = C.sub(250, 110)
    red = P["red"] + (255,)
    st.rrect((8, 8, 242, 102), 12, outline=red, width=5)
    st.rrect((16, 16, 234, 94), 8, outline=red, width=2)
    st.text((125, 50), "ASSURED", ("black", 40), red, "mm", 4)
    st.text((125, 81), "★  RESIDENT  ★", ("franklin", 14), red, "mm", 3)
    # erode the stamp ink
    a = to_np(st.img)
    nz = noise(st.img.width, st.img.height, 40, 12, 3)
    a[..., 3] *= np.clip((nz - 0.25) * 3, 0.15, 1) * 0.85
    st.img = from_np(a, "RGBA")
    C.paste_canvas(st, (572, 470), rotate=9)
    img = print_finish(C.final(), 601, paper=(252, 249, 240), grain=1.0, mottle=0.5, misreg=0.4)
    # punched corner + mild handling
    a = to_np(img.convert("RGBA"))
    yy, xx = np.mgrid[0:H, 0:W]
    a[..., 3] *= np.clip((np.sqrt((xx - 36.0) ** 2 + (yy - 600.0) ** 2) - 14) / 1.2, 0, 1)
    corner = np.clip((xx + yy - 10) / 1.5, 0, 1) * np.clip(((W - xx) + yy - 10) / 1.5, 0, 1) * \
        np.clip((xx + (H - yy) - 10) / 1.5, 0, 1) * np.clip(((W - xx) + (H - yy) - 10) / 1.5, 0, 1)
    a[..., 3] *= corner
    img = from_np(a, "RGBA")
    img = age_paper(img, 602, amount=0.25, stains=0, tears=False, creases=1, foxing=10, fade=0.05)
    save(img, "note_registrar")


def newspaper_ledger():
    ledger()


ALL = [newspaper_ledger, note_june, note_registrar]

if __name__ == "__main__":
    import sys
    only = sys.argv[1:]
    for fn in ALL:
        if not only or fn.__name__ in only:
            fn()
