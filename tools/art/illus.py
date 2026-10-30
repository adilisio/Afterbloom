"""Reusable flat mid-century illustrations drawn on a common.Canvas.

Each function takes an anchor point and a scale `s`; shapes are authored in a
local unit space (roughly -100..100) and transformed. Colours default to the
house palette but can be overridden (e.g. greyscale for TV, sepia for photos).
"""
from __future__ import annotations

import math

import numpy as np

from common import PAL, Canvas, crystal_flower, hexc, mix, shade

P = PAL


class T:
    """Local transform: scale, rotation (deg), translation."""

    def __init__(self, cx, cy, s=1.0, rot=0.0, flip=False):
        self.cx, self.cy, self.s = cx, cy, s
        self.c, self.sn = math.cos(math.radians(rot)), math.sin(math.radians(rot))
        self.f = -1 if flip else 1

    def __call__(self, x, y):
        x *= self.f
        return (self.cx + (x * self.c - y * self.sn) * self.s, self.cy + (x * self.sn + y * self.c) * self.s)

    def pts(self, pts):
        return [self(x, y) for x, y in pts]

    def box(self, x0, y0, x1, y1):
        a, b = self(x0, y0), self(x1, y1)
        return (min(a[0], b[0]), min(a[1], b[1]), max(a[0], b[0]), max(a[1], b[1]))

    def r(self, v):
        return v * self.s


def ellipse_pts(cx, cy, rx, ry, a0=0, a1=360, n=48):
    return [(cx + rx * math.cos(math.radians(a)), cy + ry * math.sin(math.radians(a)))
            for a in np.linspace(a0, a1, n)]


# --------------------------------------------------------------------------- motifs
def starburst(C, cx, cy, r_out, r_in=None, n=8, fill=PAL["mustard"], rot=0.0):
    """Atomic-age sparkle star."""
    r_in = r_in if r_in is not None else r_out * 0.22
    pts = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        a = math.radians(rot + i * 180 / n - 90)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    C.poly(pts, fill)


def spiky_star(C, cx, cy, r, n=12, fill=PAL["red"], ratio=0.62, rot=0.0):
    """Price-flash burst (for 'NEW!' stickers)."""
    starburst(C, cx, cy, r, r * ratio, n, fill, rot)


def atom(C, cx, cy, r, color=PAL["navy"], width=3, nucleus=PAL["red"]):
    for k in range(3):
        rot = k * 60
        pts = [(cx + r * math.cos(t) * math.cos(math.radians(rot)) - r * 0.36 * math.sin(t) * math.sin(math.radians(rot)),
                cy + r * math.cos(t) * math.sin(math.radians(rot)) + r * 0.36 * math.sin(t) * math.cos(math.radians(rot)))
               for t in np.linspace(0, 2 * math.pi, 64)]
        C.line(pts, color, width)
    C.circle(cx, cy, r * 0.16, fill=nucleus)


def boomerang(C, cx, cy, s, fill, rot=0):
    t = T(cx, cy, s, rot)
    C.poly(t.pts([(-40, 10), (0, -14), (40, 10), (30, 16), (0, 2), (-30, 16)]), fill)


def sun(C, cx, cy, r, fill=PAL["mustard"], rays=16, ray_len=0.45, ray_fill=None, rot=0.0):
    ray_fill = ray_fill or fill
    for i in range(rays):
        a = math.radians(rot + i * 360 / rays)
        a1, a2 = a - math.pi / rays * 0.45, a + math.pi / rays * 0.45
        C.poly([(cx + r * 1.08 * math.cos(a1), cy + r * 1.08 * math.sin(a1)),
                (cx + r * (1.1 + ray_len) * math.cos(a), cy + r * (1.1 + ray_len) * math.sin(a)),
                (cx + r * 1.08 * math.cos(a2), cy + r * 1.08 * math.sin(a2))], ray_fill)
    C.circle(cx, cy, r, fill=fill)


def cloud(C, cx, cy, w, fill=PAL["white"], shadow=None):
    h = w * 0.32
    if shadow:
        cloud(C, cx + w * 0.04, cy + h * 0.18, w, shadow)
    C.rrect((cx - w / 2, cy - h * 0.1, cx + w / 2, cy + h * 0.5), h * 0.3, fill=fill)
    C.circle(cx - w * 0.2, cy, h * 0.5, fill=fill)
    C.circle(cx + w * 0.05, cy - h * 0.25, h * 0.7, fill=fill)
    C.circle(cx + w * 0.28, cy + h * 0.05, h * 0.45, fill=fill)


def gull(C, cx, cy, s, color=PAL["ink"], width=None, flap=0.0):
    t = T(cx, cy, s)
    w = width or max(1.5, 3.2 * s)
    up = -10 - flap * 8
    C.line([t(-22, up + 2), t(-14, up - 2), t(-6, up + 2), t(0, 0)], color, w)
    C.line([t(0, 0), t(6, up + 2), t(14, up - 2), t(22, up + 2)], color, w)


def waves(C, y, x0, x1, amp, wl, fill, depth=400, phase=0.0):
    """A filled band with a scalloped top edge."""
    pts = [(x0, y + depth)]
    x = x0
    while x <= x1 + wl:
        pts.append((x, y + amp * math.sin((x / wl) * 2 * math.pi + phase)))
        x += wl / 16
    pts.append((x1 + wl, y + depth))
    C.poly(pts, fill)


def wave_lines(C, y, x0, x1, amp, wl, color, width=2, phase=0.0):
    pts = []
    x = x0
    while x <= x1:
        pts.append((x, y + amp * math.sin((x / wl) * 2 * math.pi + phase)))
        x += wl / 16
    C.line(pts, color, width)


def scallop_waves(C, y, x0, x1, r, fill, rows=1, row_gap=None, depth=300):
    """Japanese-style rounded wave crests (very mid-century print)."""
    row_gap = row_gap or r * 0.9
    for k in range(rows):
        yy = y + k * row_gap
        off = (k % 2) * r
        C.rect((x0, yy, x1, yy + depth), fill=fill if k == 0 else None)
        x = x0 - off
        while x < x1 + r:
            C.pieslice((x - r, yy - r, x + r, yy + r), 180, 360, fill=fill)
            x += 2 * r


def pine(C, x, base, h, fill=PAL["teal"], trunk=PAL["wood_dk"], tiers=3):
    w = h * 0.42
    C.rect((x - h * 0.03, base - h * 0.15, x + h * 0.03, base), fill=trunk)
    for i in range(tiers):
        top = base - h + i * h * 0.22
        bot = base - h * 0.12 - (tiers - 1 - i) * h * 0.18
        ww = w * (0.55 + 0.45 * (i + 1) / tiers)
        C.poly([(x, top), (x + ww / 2, bot), (x - ww / 2, bot)], fill)


def mountains(C, base, x0, x1, peaks, fill, snow=None):
    """peaks: list of (x, height_above_base)."""
    pts = [(x0, base)]
    for x, hh in peaks:
        pts.append((x, base - hh))
    pts.append((x1, base))
    C.poly(pts, fill)
    if snow:
        for i in range(1, len(pts) - 1):
            x, y = pts[i]
            if base - y < 60:
                continue
            lx, ly = pts[i - 1]
            rx, ry = pts[i + 1]
            f = 0.22
            C.poly([(x, y), (x + (lx - x) * f, y + (ly - y) * f), (x - 3, y + (ly - y) * f * 0.8 + 8),
                    (x + (rx - x) * f, y + (ry - y) * f)], snow)


# --------------------------------------------------------------------------- objects
def rocket(C, cx, cy, s, rot=0.0, body=PAL["cream"], fin=PAL["red"], window=PAL["teal"], ink=PAL["ink"],
           flame=True, shade_col=None):
    """Classic finned 50s rocket, nose up in local space (nose y=-130, tail y=95, flame to ~185)."""
    t = T(cx, cy, s, rot)
    shade_col = shade_col or shade(body, 0.8)
    if flame:
        C.poly(t.pts([(-24, 95), (-12, 150), (0, 188), (12, 150), (24, 95)]), PAL["mustard"])
        C.poly(t.pts([(-14, 95), (0, 152), (14, 95)]), PAL["coral"])
        C.poly(t.pts([(-6, 95), (0, 122), (6, 95)]), PAL["white"])

    def half(u):
        if u < 0.55:
            return 42 * math.sin(math.pi / 2 * (u / 0.55)) ** 0.75
        return 42 - 14 * ((u - 0.55) / 0.45) ** 1.6

    prof = [(half(i / 40), -130 + 225 * i / 40) for i in range(41)]
    # rear fins
    C.poly(t.pts([(-32, 10), (-80, 78), (-78, 112), (-30, 86)]), fin)
    C.poly(t.pts([(32, 10), (80, 78), (78, 112), (30, 86)]), fin)
    outline = prof + [(-x, y) for x, y in reversed(prof)]
    C.poly(t.pts(outline), body)
    C.poly(t.pts([(x * 0.42, y) for x, y in prof] + list(reversed(prof))), shade_col)
    nose = [(x, y) for x, y in prof if y <= -62]
    C.poly(t.pts(nose + [(-x, y) for x, y in reversed(nose)]), fin)
    C.poly(t.pts([(x * 0.42, y) for x, y in nose] + list(reversed(nose))), shade(fin, 0.8))
    # centre fin (seen edge-on) and nozzle
    C.poly(t.pts([(-5, 20), (5, 20), (6, 112), (-6, 112)]), shade(fin, 0.85))
    C.poly(t.pts([(-24, 92), (24, 92), (18, 104), (-18, 104)]), ink)
    # porthole
    C.circle(*t(0, -24), t.r(17), fill=ink)
    C.circle(*t(0, -24), t.r(13), fill=window)
    C.circle(*t(-4, -28), t.r(4), fill=PAL["white"])


def comet(C, hx, hy, angle_deg, length, head_r, color=PAL["white"], tail=PAL["mustard"], tail2=PAL["coral"],
          streaks=7, glow=None):
    """Comet head at (hx,hy), tail streaming opposite angle_deg (direction of travel)."""
    a = math.radians(angle_deg + 180)
    ca, sa = math.cos(a), math.sin(a)
    px, py = -sa, ca
    for i, col in enumerate([tail2, tail]):
        spread = head_r * (1.9 - i * 0.6)
        L = length * (1.0 - i * 0.18)
        C.poly([(hx + px * spread * 0.75, hy + py * spread * 0.75), (hx + ca * L + px * spread * 2.6, hy + sa * L + py * spread * 2.6),
                (hx + ca * L * 0.92 - px * spread * 1.2, hy + sa * L * 0.92 - py * spread * 1.2),
                (hx - px * spread * 0.75, hy - py * spread * 0.75)], col)
    rng = np.random.default_rng(int(hx + hy))
    for k in range(streaks):
        off = (k - streaks / 2) / streaks * head_r * 2.6
        L = length * rng.uniform(0.45, 1.05)
        C.line([(hx + px * off * 0.4, hy + py * off * 0.4), (hx + ca * L + px * off * 1.6, hy + sa * L + py * off * 1.6)],
               color, max(1.2, head_r * 0.09))
    if glow:
        C.glow(hx, hy, head_r * 3.2, glow, 0.9, 1.6)
    C.circle(hx, hy, head_r, fill=color)


def lighthouse(C, x, base, h, body=PAL["white"], stripe=PAL["red"], cap=PAL["red"], glass=PAL["mustard"],
               ink=PAL["ink"], stripes=3, beams=True, beam_col=None, beam_len=None, rock=None, shade_col=None):
    """Tapered striped lighthouse standing on (x, base); total height h."""
    tw_b, tw_t = h * 0.17, h * 0.11
    tower_top = base - h * 0.72
    shade_col = shade_col or shade(body, 0.85)
    lr_y0 = tower_top - h * 0.12
    if beams:
        bc = beam_col or mix(PAL["mustard_lt"], PAL["white"], 0.4)
        L = beam_len or h * 1.4
        cy = (lr_y0 + tower_top) / 2
        C.poly([(x, cy - 4), (x - L, cy - L * 0.22), (x - L, cy + L * 0.08), (x, cy + 4)], bc)
        C.poly([(x, cy - 4), (x + L * 0.8, cy - L * 0.14), (x + L * 0.8, cy + L * 0.05), (x, cy + 4)], bc)
    if rock:
        C.poly([(x - h * 0.32, base + h * 0.03), (x - h * 0.2, base - h * 0.04), (x + h * 0.15, base - h * 0.05),
                (x + h * 0.34, base + h * 0.03)], rock)
    C.poly([(x - tw_b / 2, base), (x - tw_t / 2, tower_top), (x + tw_t / 2, tower_top), (x + tw_b / 2, base)], body)
    # stripes
    n = stripes * 2
    for i in range(n):
        if i % 2 == 0:
            continue
        y0 = base - (base - tower_top) * i / n
        y1 = base - (base - tower_top) * (i + 1) / n
        w0 = tw_b + (tw_t - tw_b) * i / n
        w1 = tw_b + (tw_t - tw_b) * (i + 1) / n
        C.poly([(x - w0 / 2, y0), (x - w1 / 2, y1), (x + w1 / 2, y1), (x + w0 / 2, y0)], stripe)
    # shade side
    C.poly([(x + tw_b * 0.18, base), (x + tw_t * 0.18, tower_top), (x + tw_t / 2, tower_top), (x + tw_b / 2, base)],
           shade_col + ((90,) if len(shade_col) == 3 and C.mode == "RGBA" else ()))
    # door & window
    C.rrect((x - tw_b * 0.13, base - h * 0.09, x + tw_b * 0.13, base), tw_b * 0.12, fill=ink, corners=(True, True, False, False))
    C.rect((x - tw_b * 0.08, base - h * 0.42, x + tw_b * 0.08, base - h * 0.37), fill=ink)
    # gallery
    C.rect((x - tw_t * 0.85, tower_top - h * 0.018, x + tw_t * 0.85, tower_top + h * 0.012), fill=ink)
    # lantern room
    C.rect((x - tw_t * 0.42, lr_y0, x + tw_t * 0.42, tower_top - h * 0.018), fill=glass)
    for k in (-0.14, 0.14):
        C.rect((x + tw_t * k - 1, lr_y0, x + tw_t * k + 1, tower_top - h * 0.018), fill=ink)
    C.line([(x - tw_t * 0.62, tower_top - h * 0.045), (x + tw_t * 0.62, tower_top - h * 0.045)], ink, max(1, h * 0.005))
    # cap
    C.poly([(x - tw_t * 0.6, lr_y0), (x, lr_y0 - h * 0.08), (x + tw_t * 0.6, lr_y0)], cap)
    C.circle(x, lr_y0 - h * 0.085, h * 0.012, fill=ink)


def house(C, x, base, w, wall=PAL["cream"], roof=PAL["coral"], trim=PAL["white"], door=PAL["teal"],
          ink=PAL["ink"], window=PAL["mustard_lt"], chimney=True, style="ranch"):
    """Suburban ranch house; (x, base) is bottom-centre."""
    h = w * 0.36
    rh = w * 0.18
    if chimney:
        C.rect((x + w * 0.22, base - h - rh * 0.9, x + w * 0.3, base - h * 0.6), fill=shade(roof, 0.75))
    C.rect((x - w / 2, base - h, x + w / 2, base), fill=wall)
    C.poly([(x - w * 0.58, base - h + 2), (x - w * 0.36, base - h - rh), (x + w * 0.36, base - h - rh),
            (x + w * 0.58, base - h + 2)], roof)
    C.rect((x - w * 0.58, base - h - 1, x + w * 0.58, base - h + w * 0.015), fill=shade(roof, 0.7))
    # windows
    for wx in (-0.33, 0.25):
        x0 = x + w * wx - w * 0.09
        C.rect((x0, base - h * 0.75, x0 + w * 0.18, base - h * 0.32), fill=window)
        C.rect((x0 + w * 0.09 - 1, base - h * 0.75, x0 + w * 0.09 + 1, base - h * 0.32), fill=trim)
        C.rect((x0 - w * 0.012, base - h * 0.32, x0 + w * 0.192, base - h * 0.28), fill=trim)
    # door
    C.rect((x - w * 0.06, base - h * 0.78, x + w * 0.06, base), fill=door)
    C.circle(x + w * 0.035, base - h * 0.38, max(1, w * 0.008), fill=PAL["mustard"])
    C.rect((x - w * 0.12, base - 3, x + w * 0.12, base + 2), fill=shade(wall, 0.7))


def fish(C, cx, cy, s, body=PAL["coral"], fin=PAL["mustard"], ink=PAL["ink"], flip=False, stripes=True, rot=0):
    t = T(cx, cy, s, rot, flip)
    C.poly(t.pts([(38, 0), (66, -24), (60, 0), (66, 24)]), fin)
    C.poly(t.pts([(-6, -26), (12, -40), (24, -22)]), fin)
    C.poly(t.pts(ellipse_pts(0, 0, 46, 26)), body)
    if stripes:
        for k in (6, 20):
            C.poly(t.pts([(k, -24), (k + 7, -22), (k + 7, 22), (k, 24)]), shade(body, 0.8))
    C.poly(t.pts([(-26, -18), (-20, 0), (-26, 18), (-30, 0)]), shade(body, 0.75))
    C.circle(*t(-30, -6), t.r(5.5), fill=PAL["white"])
    C.circle(*t(-31, -6), t.r(3), fill=ink)


def tv_set(C, x, base, w, wood=PAL["wood"], wood_dk=PAL["wood_dk"], screen=None, ink=PAL["ink"],
           chrome=hexc("D8D4C8"), screen_fn=None):
    """Halcyon Starlight console TV on splayed legs; (x, base) bottom-centre, width w. Returns screen box."""
    h = w * 0.72
    leg = h * 0.22
    for lx in (-0.4, 0.4):
        C.poly([(x + w * lx - w * 0.02, base - leg), (x + w * lx * 1.12 - w * 0.008, base),
                (x + w * lx * 1.12 + w * 0.008, base), (x + w * lx + w * 0.02, base - leg)], wood_dk)
    top = base - h
    C.rrect((x - w / 2, top, x + w / 2, base - leg), w * 0.04, fill=wood)
    C.rect((x - w / 2, base - leg - h * 0.05, x + w / 2, base - leg), fill=wood_dk)
    # screen
    sx0, sy0, sx1, sy1 = x - w * 0.42, top + h * 0.07, x + w * 0.16, base - leg - h * 0.1
    C.rrect((sx0 - w * 0.015, sy0 - w * 0.015, sx1 + w * 0.015, sy1 + w * 0.015), w * 0.06, fill=chrome)
    C.rrect((sx0, sy0, sx1, sy1), w * 0.05, fill=screen or hexc("3C4A48"))
    if screen_fn:
        screen_fn((sx0, sy0, sx1, sy1))
    C.ellipse((sx0 + (sx1 - sx0) * 0.08, sy0 + (sy1 - sy0) * 0.06, sx0 + (sx1 - sx0) * 0.38, sy0 + (sy1 - sy0) * 0.22),
              fill=mix(screen or hexc("3C4A48"), PAL["white"], 0.35))
    # speaker grille + knobs
    gx0, gx1 = x + w * 0.22, x + w * 0.44
    C.rrect((gx0, sy0, gx1, sy0 + (sy1 - sy0) * 0.55), w * 0.02, fill=wood_dk)
    for k in range(7):
        yy = sy0 + (sy1 - sy0) * 0.55 * (k + 0.5) / 7
        C.line([(gx0 + w * 0.02, yy), (gx1 - w * 0.02, yy)], shade(wood_dk, 1.25), max(1, w * 0.006))
    for k in range(2):
        kx = gx0 + (gx1 - gx0) * (0.28 + k * 0.44)
        ky = sy0 + (sy1 - sy0) * 0.8
        C.circle(kx, ky, w * 0.035, fill=chrome)
        C.circle(kx, ky, w * 0.018, fill=ink)
    return (sx0, sy0, sx1, sy1)


def tuppence(C, cx, top, s, pose="wave", body=PAL["brass"], dark=PAL["brass_dk"], light=PAL["brass_lt"],
             glass=None, tie=PAL["red"], eye=PAL["mustard"], ink=PAL["ink"], glove=PAL["white"], tray=None,
             outline=None, glow=None):
    """Tuppence, Halcyon Valet Mk II. (cx, top) is the top of the dome; ~330 units tall at s=1.
    pose: 'wave', 'tray', 'bow', 'stand', 'thumbs'."""
    t = T(cx, top, s)
    glass = glass or mix(PAL["sky"], PAL["white"], 0.45)
    ow = outline
    lw = 3.0
    # legs
    for sx in (-1, 1):
        C.poly(t.pts([(sx * 18 - 8, 250), (sx * 18 + 8, 250), (sx * 20 + 8, 300), (sx * 20 - 8, 300)]), dark)
        for k in range(3):
            y = 258 + k * 13
            C.line(t.pts([(sx * 19 - 9, y), (sx * 19 + 9, y)]), shade(dark, 0.75), t.r(2.2))
        C.ellipse(t.box(sx * 24 - 24, 294, sx * 24 + 24, 318), fill=glove)        # spats
        C.chord(t.box(sx * 24 - 26, 300, sx * 24 + 26, 330), 180, 360, fill=ink)  # shoes
    # hips
    C.poly(t.pts([(-48, 220), (48, 220), (36, 256), (-36, 256)]), dark)
    # arms behind?  draw arms after torso for front poses
    # torso
    C.rrect(t.box(-62, 112, 62, 232), t.r(30), fill=body)
    C.rrect(t.box(18, 112, 62, 232), t.r(26), fill=dark, corners=(False, True, True, False))
    C.rrect(t.box(-50, 116, -30, 228), t.r(10), fill=light)
    for y in (140, 205):
        C.line(t.pts([(-60, y), (60, y)]), dark, t.r(3))
    for x in (-44, 44):
        for y in (126, 218):
            C.circle(*t(x, y), t.r(3.2), fill=light if x < 0 else body)
    # chest plate with Halcyon sun badge
    C.rrect(t.box(-26, 152, 26, 194), t.r(8), fill=light)
    C.rrect(t.box(-22, 156, 22, 190), t.r(6), fill=PAL["navy"])
    C.pieslice(t.box(-12, 166, 12, 190), 180, 360, fill=PAL["mustard"])
    for k in range(3):
        C.line(t.pts([(-16, 180 + k * 4), (16, 180 + k * 4)]), PAL["cream"], t.r(1.6))
    # collar
    C.rrect(t.box(-36, 92, 36, 114), t.r(8), fill=dark)
    C.rect(t.box(-36, 100, 36, 104), fill=light)
    # dome base ring + face
    C.rrect(t.box(-50, 78, 50, 98), t.r(9), fill=body)
    C.rect(t.box(14, 80, 48, 96), fill=dark)
    # glass dome
    C.chord(t.box(-46, 0, 46, 156), 180, 360, fill=glass)
    # face plate inside the dome
    C.chord(t.box(-34, 26, 34, 120), 180, 360, fill=body)
    C.chord(t.box(-34, 26, 34, 120), 290, 360, fill=dark)
    C.rect(t.box(-34, 72, 34, 80), fill=body)
    # eyes
    for ex in (-14, 14):
        C.circle(*t(ex, 46), t.r(10.5), fill=ink)
        C.circle(*t(ex, 46), t.r(8), fill=eye)
        if glow:
            C.circle(*t(ex, 46), t.r(5), fill=glow)
        C.circle(*t(ex - 2.5, 43), t.r(2.6), fill=PAL["white"])
    # moustache grille / smile
    C.arc(t.box(-12, 52, 12, 72), 20, 160, ink, t.r(3))
    # dome highlight
    C.arc(t.box(-38, 8, 38, 150), 205, 250, PAL["white"], t.r(4))
    C.circle(*t(-22, 20), t.r(3), fill=PAL["white"])
    # antenna
    C.line(t.pts([(0, 0), (0, -16)]), dark, t.r(3))
    C.circle(*t(0, -20), t.r(6), fill=PAL["red"] if not glow else glow)
    # bow tie
    C.poly(t.pts([(0, 110), (-26, 98), (-26, 124)]), tie)
    C.poly(t.pts([(0, 110), (26, 98), (26, 124)]), tie)
    C.rrect(t.box(-7, 103, 7, 117), t.r(3), fill=shade(tie, 0.75))

    def arm(pts, hand_at, mitten=True):
        C.line(t.pts(pts), dark, t.r(15))
        C.line(t.pts(pts), body, t.r(10))
        for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
            for u in (0.33, 0.66):
                px, py = ax + (bx - ax) * u, ay + (by - ay) * u
                C.circle(*t(px, py), t.r(6.5), fill=dark)
        hx, hy = hand_at
        C.circle(*t(hx, hy), t.r(13), fill=glove)
        C.circle(*t(hx - 4, hy - 4), t.r(4), fill=mix(glove, PAL["white"], 0.6))

    # shoulders
    for sx in (-1, 1):
        C.circle(*t(sx * 64, 128), t.r(14), fill=dark)
    if pose == "wave":
        arm([(-64, 128), (-86, 170), (-80, 216)], (-78, 226))
        arm([(64, 128), (100, 98), (108, 46)], (108, 34))
        for k in range(3):  # wave marks
            C.arc(t.box(118 + k * 8, 10 - k * 6, 150 + k * 10, 50 + k * 4), 300, 30, ink, t.r(2.5))
    elif pose == "tray":
        arm([(-64, 128), (-92, 160), (-66, 176)], (-60, 176))
        arm([(64, 128), (96, 150), (112, 128)], (112, 120))
        # tray with tea set held up on right
        tx = 112
        C.ellipse(t.box(tx - 54, 104, tx + 54, 116), fill=hexc("D8D4C8"))
        C.rect(t.box(tx - 54, 108, tx + 54, 112), fill=hexc("B9B4A6"))
        C.rrect(t.box(tx - 34, 72, tx - 2, 106), t.r(10), fill=PAL["white"])     # teapot
        C.poly(t.pts([(tx - 34, 84), (tx - 50, 74), (tx - 46, 70), (tx - 32, 80)]), PAL["white"])
        C.arc(t.box(tx - 6, 78, tx + 8, 98), 270, 90, PAL["white"], t.r(3))
        C.circle(*t(tx - 18, 70), t.r(4), fill=PAL["teal"])
        C.rect(t.box(tx - 34, 86, tx - 2, 90), fill=PAL["teal"])
        C.rrect(t.box(tx + 12, 90, tx + 34, 106), t.r(5), fill=PAL["white"])   # cup
        C.rect(t.box(tx + 12, 94, tx + 34, 97), fill=PAL["teal"])
        for k in range(3):
            C.arc(t.box(tx + 14 + k * 6, 66 - k * 6, tx + 24 + k * 6, 86 - k * 6), 100, 260, shade(PAL["white"], 0.75), t.r(1.8))
    elif pose == "thumbs":
        arm([(-64, 128), (-86, 170), (-80, 216)], (-78, 226))
        arm([(64, 128), (96, 160), (110, 132)], (110, 124))
        C.rrect(t.box(104, 96, 116, 118), t.r(5), fill=glove)
    elif pose == "bow":
        arm([(-64, 128), (-70, 170), (-40, 190)], (-34, 190))
        arm([(64, 128), (84, 170), (82, 214)], (80, 222))
    else:  # stand
        arm([(-64, 128), (-84, 170), (-80, 216)], (-78, 226))
        arm([(64, 128), (84, 170), (80, 216)], (78, 226))


def shelter_entrance(C, x, base, w, concrete=hexc("C9C2B2"), door=hexc("9AA3A6"), ink=PAL["ink"],
                     accent=PAL["mustard"], number="9", hill=PAL["teal"], stripe=True):
    """Halcyon Assured shelter portal set into a hillside: concrete arch, twin sliding doors, sun emblem."""
    h = w * 0.7
    C.pieslice((x - w * 1.3, base - h * 1.2, x + w * 1.3, base + h * 1.0), 180, 360, fill=hill)
    C.rrect((x - w / 2, base - h, x + w / 2, base + 4), w * 0.36, fill=concrete, corners=(True, True, False, False))
    C.rrect((x - w * 0.38, base - h * 0.8, x + w * 0.38, base), w * 0.27, fill=shade(concrete, 0.75),
            corners=(True, True, False, False))
    dx0, dx1 = x - w * 0.32, x + w * 0.32
    C.rect((dx0, base - h * 0.55, dx1, base), fill=door)
    C.rect((x - 1.5, base - h * 0.55, x + 1.5, base), fill=ink)
    if stripe:
        n = 10
        for k in range(n):
            if k % 2 == 0:
                x0 = dx0 + (dx1 - dx0) * k / n
                C.poly([(x0, base), (x0 + (dx1 - dx0) / n, base), (x0 + (dx1 - dx0) / n + 8, base - h * 0.07),
                        (x0 + 8, base - h * 0.07)], accent)
        C.rect((dx0, base - h * 0.075, dx1, base - h * 0.07), fill=ink)
    # emblem above doors: rising sun with number
    ey = base - h * 0.66
    C.circle(x, ey, w * 0.11, fill=accent)
    C.circle(x, ey, w * 0.085, fill=PAL["navy"])
    C.text((x, ey + 1), number, ("black", w * 0.11), PAL["cream"], anchor="mm")
    for sx in (-1, 1):
        C.circle(x + sx * w * 0.42, base - h * 0.62, w * 0.025, fill=accent)


def sedan(C, x, base, w, body=PAL["teal"], roof=PAL["cream"], ink=PAL["ink"], chrome=hexc("E4E0D6"), flip=False):
    """Finned 60s sedan side view, (x, base) bottom-centre."""
    t = T(x, base, w / 200, 0, flip)
    C.poly(t.pts([(-100, -14), (-98, -36), (-60, -42), (-36, -66), (34, -66), (56, -42), (96, -40), (100, -50),
                  (104, -14)]), body)
    C.poly(t.pts([(-30, -62), (30, -62), (50, -42), (-52, -42)]), roof)
    C.poly(t.pts([(-24, -58), (-4, -58), (-4, -44), (-42, -44)]), hexc("A9C9C9"))
    C.poly(t.pts([(2, -58), (26, -58), (44, -44), (2, -44)]), hexc("A9C9C9"))
    C.line(t.pts([(-98, -30), (100, -30)]), chrome, t.r(3))
    C.rect(t.box(-104, -18, 106, -12), fill=chrome)
    for wx in (-62, 64):
        C.circle(*t(wx, -12), t.r(16), fill=ink)
        C.circle(*t(wx, -12), t.r(8), fill=chrome)


def person_back(C, x, base, h, hair=PAL["wood_dk"], shirt=PAL["coral"], pants=PAL["navy"], skin=hexc("E8B996"),
                girl=False, arm_up=None):
    """Simple stylized figure seen from behind (for photos/illustrations)."""
    head = h * 0.13
    C.poly([(x - h * 0.08, base - h * 0.5), (x - h * 0.07, base), (x - h * 0.01, base), (x, base - h * 0.4),
            (x + h * 0.01, base), (x + h * 0.07, base), (x + h * 0.08, base - h * 0.5)], pants if not girl else skin)
    if girl:
        C.poly([(x - h * 0.13, base - h * 0.36), (x - h * 0.08, base - h * 0.75), (x + h * 0.08, base - h * 0.75),
                (x + h * 0.13, base - h * 0.36)], shirt)
    else:
        C.rrect((x - h * 0.1, base - h * 0.78, x + h * 0.1, base - h * 0.46), h * 0.04, fill=shirt)
    # arms
    for sx in (-1, 1):
        if arm_up == sx:
            C.line([(x + sx * h * 0.09, base - h * 0.74), (x + sx * h * 0.2, base - h * 0.9), (x + sx * h * 0.24, base - h * 1.02)],
                   skin, h * 0.045)
        else:
            C.line([(x + sx * h * 0.095, base - h * 0.74), (x + sx * h * 0.13, base - h * 0.5)], skin, h * 0.045)
    C.rect((x - h * 0.03, base - h * 0.82, x + h * 0.03, base - h * 0.76), fill=skin)
    C.circle(x, base - h * 0.88, head * 0.75, fill=hair)
    if girl:
        C.ellipse((x - head * 0.95, base - h * 0.86, x + head * 0.95, base - h * 0.74), fill=hair)


# --------------------------------------------------------------------------- layout decorations
def ht_rect(C, box, color, t0, t1, pitch=6.0, angle=45.0, direction="v"):
    """Halftone gradient (tone t0 -> t1) inside a rectangle; direction 'v' top->bottom, 'h' left->right."""
    m = C.mask()
    m.rect(box, fill=255)
    x0, y0, x1, y1 = box
    tone = C.lin_tone(x0, y0, x0, y1, t0, t1) if direction == "v" else C.lin_tone(x0, y0, x1, y0, t0, t1)
    C.halftone_mask(m, color, tone, pitch, angle)


def ht_shape(C, draw_fn, color, tone, pitch=6.0, angle=45.0):
    """Halftone fill of an arbitrary shape: draw_fn(mask_canvas) draws it with fill=255."""
    m = C.mask()
    draw_fn(m)
    C.halftone_mask(m, color, tone, pitch, angle)


def ribbon(C, cx, cy, w, h, fill, text=None, spec=None, text_fill=PAL["cream"], tail=None, drop=None,
           tracking=0):
    """Banner ribbon with folded, notched tails."""
    tail = tail if tail is not None else h * 0.9
    d = drop if drop is not None else h * 0.28
    dk = shade(fill, 0.68)
    for sx in (-1, 1):
        ex = cx + sx * w / 2
        inner, outer = ex - sx * h * 0.3, ex + sx * tail
        C.poly([(inner, cy - h / 2 + d), (outer, cy - h / 2 + d), (outer - sx * h * 0.35, cy + d),
                (outer, cy + h / 2 + d), (inner, cy + h / 2 + d)], dk)
        C.poly([(ex, cy + h / 2), (ex + sx * 0.001, cy + h / 2 + d), (ex - sx * h * 0.3, cy + h / 2 + d)], shade(fill, 0.45))
    C.rect((cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2), fill=fill)
    if text:
        C.text_fit((cx, cy + 1), text, spec[0], w - h * 0.5, spec[1], text_fill, "mm", tracking)


def burst_label(C, cx, cy, r, fill, lines, text_fill=PAL["cream"], n=14, rot=-12, font_name="black"):
    from illus import spiky_star  # noqa
    spiky_star(C, cx, cy, r, n, fill, 0.8, 0)
    # text in a rotated sub-canvas
    sub = C.sub(int(r * 2), int(r * 2))
    total = sum(sz for _, sz in lines) * 1.05
    y = r - total / 2
    for txt, sz in lines:
        sub.text_fit((r, y + sz * 0.55), txt, font_name, r * 1.45, sz, text_fill, "mm")
        y += sz * 1.05
    C.paste_canvas(sub, (cx - r, cy - r), rotate=-rot)


# --------------------------------------------------------------------------- Halcyon brand
def halcyon_emblem(C, cx, cy, r, ring=P["navy"], sun_col=P["mustard"], wave=P["cream"], bird=P["navy"], bg=P["cream"]):
    """Halcyon kingfisher-over-rising-sun emblem (also used by logos.py)."""
    C.circle(cx, cy, r, fill=ring)
    C.circle(cx, cy, r * 0.86, fill=bg)
    # rising sun half disc + rays
    for i in range(9):
        a = math.radians(180 + 10 + i * 20)
        C.poly([(cx, cy + r * 0.12), (cx + r * 0.84 * math.cos(a - 0.09), cy + r * 0.12 + r * 0.84 * math.sin(a - 0.09)),
                (cx + r * 0.84 * math.cos(a + 0.09), cy + r * 0.12 + r * 0.84 * math.sin(a + 0.09))], mix(sun_col, bg, 0.45))
    C.pieslice((cx - r * 0.42, cy - r * 0.3, cx + r * 0.42, cy + r * 0.54), 180, 360, fill=sun_col)
    # waves
    C.poly([(cx + r * 0.86 * math.cos(math.radians(a)), cy + r * 0.86 * math.sin(math.radians(a)))
            for a in np.linspace(8, 172, 40)], ring)
    for k in range(3):
        y = cy + r * (0.24 + k * 0.17)
        pts = [(cx + x, y + math.sin(x / (r * 0.12)) * r * 0.035) for x in np.linspace(-r * 0.8, r * 0.8, 60)
               if (x * x + (y - cy) ** 2) < (r * 0.84) ** 2]
        if len(pts) > 1:
            C.line(pts, wave, max(1.5, r * 0.045))
    # kingfisher in flight (stylized swoop)
    t = T(cx - r * 0.02, cy - r * 0.36, r / 110, 14)
    C.poly(t.pts(ellipse_pts(-6, 0, 40, 13)), bird)                                   # body
    C.poly(t.pts([(-40, -4), (-74, -14), (-70, 6), (-38, 6)]), bird)                 # tail
    C.circle(*t(30, -6), t.r(16), fill=bird)                                         # head
    C.poly(t.pts([(40, -14), (84, -2), (42, 0)]), bird)                              # dagger beak
    C.poly(t.pts([(-18, -6), (-44, -58), (-20, -52), (14, -8)]), bird)               # raised wing
    C.poly(t.pts([(-4, 6), (-26, 34), (-8, 30), (12, 6)]), bird)                     # lower wing
    C.circle(*t(34, -10), t.r(3.5), fill=bg)                                         # eye


def halcyon_logo(C, x, y, h, fg=PAL["navy"], accent=PAL["mustard"], bg=PAL["cream"], tagline=True, anchor="l",
                 emblem=True):
    """Standard Halcyon lockup: kingfisher emblem + 'Halcyon' (Palatino Bold Italic) + 'ELECTRIC CO.' +
    optional tagline. (x, y) = left (anchor 'l') or centre ('m') of the lockup's vertical middle; h = emblem height.
    Returns total width."""
    r = h / 2
    word = ("pala_bi", h * 0.92)
    ww = C.text_w("Halcyon", word)
    total = (h * 1.12 if emblem else 0) + ww
    x0 = x - total / 2 if anchor == "m" else x
    if emblem:
        halcyon_emblem(C, x0 + r, y, r, fg, accent, bg, fg, bg)
    tx = x0 + (h * 1.12 if emblem else 0)
    C.text((tx, y + h * 0.12), "Halcyon", word, fg, "ls")
    C.rect((tx + h * 0.06, y + h * 0.2, tx + ww, y + h * 0.235), fill=accent)
    C.text((tx + h * 0.08, y + h * 0.4), "ELECTRIC CO.", ("georgia_b", h * 0.16), fg, "lm", h * 0.035)
    if tagline:
        C.text((tx + h * 0.08, y + h * 0.64), "Tomorrow, Made Gentle.", ("georgia_i", h * 0.17), fg, "lm")
    return total


# --------------------------------------------------------------------------- Civil Defense
def cd_emblem(C, cx, cy, r, ring=PAL["navy"], field=PAL["cream"], shield=PAL["red"], mark=PAL["cream"],
              star=PAL["mustard"], ring_text=True, text_col=None):
    """Larkhaven Civil Defense emblem (original): ringed roundel, red shield, 'CD' monogram under a beacon star.
    Use ring_text=False at small sizes. Works in monochrome by passing greys."""
    text_col = text_col or field
    C.circle(cx, cy, r, fill=ring)
    inner = r * (0.74 if ring_text else 0.86)
    C.circle(cx, cy, inner, fill=field)
    C.ring(cx, cy, inner - r * 0.05, max(1, r * 0.025), ring)
    s = inner * 0.78
    pts = [(cx - s * 0.62, cy - s * 0.62), (cx + s * 0.62, cy - s * 0.62), (cx + s * 0.62, cy + s * 0.05)]
    pts += [(cx + s * 0.62 * math.cos(a), cy + s * 0.05 + s * 0.85 * math.sin(a))
            for a in np.linspace(0, math.pi, 24)]
    C.poly(pts, shield)
    starburst(C, cx, cy - s * 0.3, s * 0.3, s * 0.1, 4, star)
    C.text((cx, cy + s * 0.32), "CD", ("black", s * 0.55), mark, "mm")
    if ring_text:
        C.text_arc(cx, cy, r * 0.8, "LARKHAVEN", ("franklin", r * 0.17), text_col, -90, r * 0.03)
        C.text_arc(cx, cy, r * 0.8, "CIVIL DEFENSE", ("franklin", r * 0.17), text_col, 90, r * 0.02, inside=True)
        for sx in (-1, 1):
            C.circle(cx + sx * r * 0.87, cy, r * 0.035, fill=text_col)


def clipped(C, mask_fn, draw_fn):
    """Draw draw_fn(sub) on a scratch layer and composite it only inside mask_fn(mask) (fill=255)."""
    from common import to_np, from_np
    sub = Canvas(C.w, C.h, (0, 0, 0, 0), C.s, "RGBA")
    draw_fn(sub)
    m = C.mask()
    mask_fn(m)
    a = to_np(sub.img.getchannel("A")) * (to_np(m.img) / 255.0)
    sub.img.putalpha(from_np(a, "L"))
    if C.img.mode == "RGBA":
        C.img.alpha_composite(sub.img)
    else:
        C.img.paste(sub.img.convert("RGB"), (0, 0), sub.img.getchannel("A"))
