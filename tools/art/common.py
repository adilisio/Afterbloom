"""Shared helpers for AFTERBLOOM generated 2D art.

Everything is drawn with Pillow primitives on a supersampled Canvas (design
coordinates are final-pixel coordinates; the canvas multiplies them by `ss`),
then finished with print effects (paper grain, ink mottling, misregistration,
halftone) and optionally aged (yellowing, stains, tears, rust, overgrowth).

All randomness is seeded, so re-running the scripts reproduces the outputs.
"""
from __future__ import annotations

import math
import os
from functools import lru_cache
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "textures" / "gen"
OUT.mkdir(parents=True, exist_ok=True)
FONT_DIR = Path(os.environ.get("WINDIR", "C:/Windows")) / "Fonts"


# --------------------------------------------------------------------------- colour
def hexc(h: str, a: int | None = None):
    h = h.lstrip("#")
    c = tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
    return c + (a,) if a is not None else c


PAL = {
    "cream": hexc("F3E6C8"),
    "teal": hexc("2F7F7A"),
    "coral": hexc("E07A5F"),
    "mustard": hexc("E3B23C"),
    "navy": hexc("23395B"),
    "red": hexc("C8553D"),
    "violet": hexc("9B5CFF"),  # Bloom only
    "ink": hexc("2A2522"),     # warm near-black printing ink
    "paper": hexc("FBF4E4"),
    "white": (255, 255, 255),
    "brass": hexc("C9A04A"),
    "brass_dk": hexc("8E6A2A"),
    "brass_lt": hexc("EBD08A"),
    "sky": hexc("A9D3CF"),
    "teal_lt": hexc("7FB8B0"),
    "coral_lt": hexc("F2B39E"),
    "mustard_lt": hexc("F1D98E"),
    "navy_lt": hexc("5B7397"),
    "wood": hexc("8A5A3B"),
    "wood_dk": hexc("5E3B26"),
    "sepia": hexc("704A2E"),
}


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(len(a)))


def shade(c, f):
    """f<1 darkens, f>1 lightens toward white."""
    if f <= 1:
        return tuple(int(v * f) for v in c[:3])
    return mix(c[:3], (255, 255, 255), min(1, f - 1))


# --------------------------------------------------------------------------- fonts
FONTS = {
    "georgia": "georgia.ttf", "georgia_b": "georgiab.ttf", "georgia_i": "georgiai.ttf", "georgia_bi": "georgiaz.ttf",
    "impact": "impact.ttf", "black": "ariblk.ttf", "franklin": "framd.ttf", "franklin_i": "framdit.ttf",
    "bahn": "bahnschrift.ttf", "script": "segoesc.ttf", "script_b": "segoescb.ttf",
    "print": "segoepr.ttf", "print_b": "segoeprb.ttf", "inkfree": "Inkfree.ttf", "gabriola": "Gabriola.ttf",
    "pala": "pala.ttf", "pala_b": "palab.ttf", "pala_i": "palai.ttf", "pala_bi": "palabi.ttf",
    "times": "times.ttf", "times_b": "timesbd.ttf", "times_i": "timesi.ttf", "times_bi": "timesbi.ttf",
    "courier": "cour.ttf", "courier_b": "courbd.ttf", "trebuc_b": "trebucbd.ttf", "trebuc_bi": "trebucbi.ttf",
    "verdana_b": "verdanab.ttf", "constan": "constan.ttf", "constan_b": "constanb.ttf",
    "constan_i": "constani.ttf", "constan_bi": "constanz.ttf", "cambria_b": "cambriab.ttf",
    "cambria_bi": "cambriaz.ttf", "arial": "arial.ttf", "arial_b": "arialbd.ttf", "lucon": "lucon.ttf",
    "mvboli": "mvboli.ttf", "sitka": "SitkaVF.ttf", "sitka_i": "SitkaVF-Italic.ttf", "comic": "comic.ttf",
    "corbel_b": "corbelb.ttf", "candara_b": "Candarab.ttf", "candara_bi": "Candaraz.ttf",
}


@lru_cache(maxsize=512)
def font(name: str, size: int, wght: int | None = None, wdth: int | None = None, opsz: int | None = None):
    """Load a Windows font by short name. Bahnschrift takes wght (300-700) / wdth (75-100)."""
    f = ImageFont.truetype(str(FONT_DIR / FONTS.get(name, name)), max(1, int(round(size))))
    if name == "bahn":
        f.set_variation_by_axes([wght or 400, wdth or 100])
    elif name.startswith("sitka"):
        f.set_variation_by_axes([opsz or 27, wght or 400])
    return f


# --------------------------------------------------------------------------- noise
def noise(w, h, cells, seed=0, octaves=1, persistence=0.5, tile=True):
    """Seamlessly tileable fBm value noise in [0,1], float32 (h, w)."""
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w), np.float32)
    amp, tot = 1.0, 0.0
    c = cells
    for _ in range(octaves):
        cx = max(1, int(round(c)))
        cy = max(1, int(round(c * h / w)))
        g = rng.random((cy, cx)).astype(np.float32)
        z = ndimage.zoom(g, (h / cy, w / cx), order=3, mode="grid-wrap", grid_mode=True)
        out += amp * z[:h, :w]
        tot += amp
        amp *= persistence
        c *= 2
    out /= tot
    lo, hi = out.min(), out.max()
    return (out - lo) / max(1e-6, hi - lo)


def halftone(tone, pitch, angle=45.0, aa=1.0, origin=(0.0, 0.0)):
    """Coverage (0..1) of a round-dot halftone screen for a tone field (0..1)."""
    h, w = tone.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    xx -= origin[0]
    yy -= origin[1]
    a = math.radians(angle)
    u = (xx * math.cos(a) + yy * math.sin(a)) / pitch
    v = (-xx * math.sin(a) + yy * math.cos(a)) / pitch
    fu = u - np.round(u)
    fv = v - np.round(v)
    d = np.sqrt(fu * fu + fv * fv)
    r = np.sqrt(np.clip(tone, 0, 1) / math.pi)
    cov = np.clip((r - d) * pitch / aa + 0.5, 0, 1)
    cov[tone <= 0.001] = 0
    return cov.astype(np.float32)


def to_np(img):
    return np.asarray(img).astype(np.float32)


def from_np(a, mode=None):
    return Image.fromarray(np.clip(a + 0.5, 0, 255).astype(np.uint8), mode)


# --------------------------------------------------------------------------- canvas
class Canvas:
    """Supersampled drawing surface. Coordinates are in final pixels."""

    def __init__(self, w, h, bg=(255, 255, 255), ss=2, mode="RGB", wrap=False):
        self.w, self.h, self.s, self.mode, self.wrap = w, h, ss, mode, wrap
        self.img = Image.new(mode, (w * ss, h * ss), bg)
        self.d = ImageDraw.Draw(self.img)

    # ---- coordinate helpers
    def _p(self, pts, dx=0, dy=0):
        s = self.s
        return [((x + dx) * s, (y + dy) * s) for x, y in pts]

    def _b(self, box, dx=0, dy=0):
        s = self.s
        x0, y0, x1, y1 = box
        return [(min(x0, x1) + dx) * s, (min(y0, y1) + dy) * s, (max(x0, x1) + dx) * s, (max(y0, y1) + dy) * s]

    def _offs(self):
        if not self.wrap:
            return [(0, 0)]
        return [(i * self.w, j * self.h) for i in (-1, 0, 1) for j in (-1, 0, 1)]

    def _w(self, width):
        return max(1, int(round(width * self.s))) if width else 0

    # ---- primitives
    def rect(self, box, fill=None, outline=None, width=1):
        for dx, dy in self._offs():
            self.d.rectangle(self._b(box, dx, dy), fill=fill, outline=outline, width=self._w(width))

    def rrect(self, box, r, fill=None, outline=None, width=1, corners=None):
        x0, y0, x1, y1 = self._b(box)
        r = max(0, min(r * self.s, (x1 - x0) / 2 - 1, (y1 - y0) / 2 - 1)) / self.s
        for dx, dy in self._offs():
            self.d.rounded_rectangle(self._b(box, dx, dy), radius=r * self.s, fill=fill, outline=outline,
                                     width=self._w(width), corners=corners)

    def ellipse(self, box, fill=None, outline=None, width=1):
        for dx, dy in self._offs():
            self.d.ellipse(self._b(box, dx, dy), fill=fill, outline=outline, width=self._w(width))

    def circle(self, cx, cy, r, fill=None, outline=None, width=1):
        self.ellipse((cx - r, cy - r, cx + r, cy + r), fill, outline, width)

    def poly(self, pts, fill=None, outline=None, width=1):
        for dx, dy in self._offs():
            p = self._p(pts, dx, dy)
            if fill is not None:
                self.d.polygon(p, fill=fill)
            if outline is not None:
                self.d.line(p + [p[0]], fill=outline, width=self._w(width), joint="curve")

    def line(self, pts, fill, width=1, round_caps=True):
        for dx, dy in self._offs():
            p = self._p(pts, dx, dy)
            self.d.line(p, fill=fill, width=self._w(width), joint="curve")
            if round_caps and width > 1.5:
                r = width * self.s / 2
                for x, y in (p[0], p[-1]):
                    self.d.ellipse([x - r, y - r, x + r, y + r], fill=fill)

    def arc(self, box, start, end, fill, width=1):
        for dx, dy in self._offs():
            self.d.arc(self._b(box, dx, dy), start, end, fill=fill, width=self._w(width))

    def pieslice(self, box, start, end, fill=None, outline=None, width=1):
        for dx, dy in self._offs():
            self.d.pieslice(self._b(box, dx, dy), start, end, fill=fill, outline=outline, width=self._w(width))

    def chord(self, box, start, end, fill=None, outline=None, width=1):
        for dx, dy in self._offs():
            self.d.chord(self._b(box, dx, dy), start, end, fill=fill, outline=outline, width=self._w(width))

    def ring(self, cx, cy, r, width, fill):
        self.ellipse((cx - r, cy - r, cx + r, cy + r), outline=fill, width=width)

    # ---- text
    def font(self, spec):
        """spec: (name, size) or (name, size, dict(axes))."""
        name, size = spec[0], spec[1]
        kw = spec[2] if len(spec) > 2 else {}
        return font(name, size * self.s, **kw)

    def text_w(self, s, spec, tracking=0.0):
        f = self.font(spec)
        if not tracking:
            return f.getlength(s) / self.s
        return (sum(f.getlength(ch) for ch in s) + tracking * self.s * (len(s) - 1)) / self.s

    def text_bbox(self, s, spec):
        f = self.font(spec)
        b = f.getbbox(s)
        return tuple(v / self.s for v in b)

    def text(self, xy, s, spec, fill, anchor="la", tracking=0.0, stroke=0, stroke_fill=None, shadow=None):
        """Draw text. anchor like Pillow ('mm','ms','la'...). tracking in px. shadow=(dx,dy,color)."""
        if shadow:
            dx, dy, col = shadow
            self.text((xy[0] + dx, xy[1] + dy), s, spec, col, anchor, tracking, stroke, col)
        f = self.font(spec)
        x, y = xy
        sw = int(round(stroke * self.s))
        if not tracking:
            for ox, oy in self._offs():
                self.d.text(((x + ox) * self.s, (y + oy) * self.s), s, font=f, fill=fill, anchor=anchor,
                            stroke_width=sw, stroke_fill=stroke_fill)
            return
        total = self.text_w(s, spec, tracking)
        h = anchor[0]
        x0 = x - (total / 2 if h == "m" else total if h == "r" else 0)
        va = "l" + anchor[1]
        cx = x0
        for ch in s:
            for ox, oy in self._offs():
                self.d.text(((cx + ox) * self.s, (y + oy) * self.s), ch, font=f, fill=fill, anchor=va,
                            stroke_width=sw, stroke_fill=stroke_fill)
            cx += f.getlength(ch) / self.s + tracking

    def fit_size(self, s, name, max_w, max_size, tracking=0.0, **axes):
        size = max_size
        while size > 6:
            spec = (name, size, axes) if axes else (name, size)
            if self.text_w(s, spec, tracking) <= max_w:
                return spec
            size -= 1
        return (name, size, axes) if axes else (name, size)

    def text_fit(self, xy, s, name, max_w, max_size, fill, anchor="mm", tracking=0.0, **kw):
        axes = kw.pop("axes", {})
        spec = self.fit_size(s, name, max_w, max_size, tracking, **axes)
        self.text(xy, s, spec, fill, anchor, tracking, **kw)
        return spec

    def text_arc(self, cx, cy, r, s, spec, fill, center_deg=-90, tracking=0.0, inside=False):
        """Text along a circle; center_deg is the angle (deg, 0=east, -90=north) of the text centre.
        inside=False: letters stand on the arc reading clockwise (top arc). inside=True: bottom arc, reading
        left-to-right counter-clockwise."""
        f = self.font(spec)
        widths = [f.getlength(ch) / self.s + tracking for ch in s]
        total = sum(widths) - tracking
        ang_total = math.degrees(total / r)
        sign = -1 if inside else 1
        a = center_deg - sign * ang_total / 2
        for ch, wch in zip(s, widths):
            amid = a + sign * math.degrees((wch - tracking) / 2 / r)
            rad = math.radians(amid)
            px, py = cx + r * math.cos(rad), cy + r * math.sin(rad)
            size = int(f.size * 2)
            tile = Image.new("RGBA", (size, size), (0, 0, 0, 0))
            td = ImageDraw.Draw(tile)
            td.text((size / 2, size / 2), ch, font=f, fill=fill, anchor="ms" if not inside else "mt")
            rot = -(amid + 90) if not inside else -(amid - 90)
            tile = tile.rotate(rot, resample=Image.BICUBIC, center=(size / 2, size / 2))
            X, Y = int(px * self.s - size / 2), int(py * self.s - size / 2)
            if self.img.mode == "RGBA":
                self.img.alpha_composite(tile, (X, Y)) if X >= 0 and Y >= 0 else self.img.paste(tile, (X, Y), tile)
            else:
                self.img.paste(tile, (X, Y), tile)
            a += sign * math.degrees(wch / r)

    def para(self, box, text, spec, fill, leading=1.25, align="left", indent=0, tracking=0):
        """Word-wrapped paragraph(s) inside box. Returns y after the last line."""
        x0, y0, x1, y1 = box
        maxw = x1 - x0
        f = self.font(spec)
        sp = f.getlength(" ") / self.s
        lh = spec[1] * leading
        y = y0
        for pi, ptxt in enumerate(text.split("\n")):
            words = ptxt.split()
            lines, cur = [], []
            for w_ in words:
                trial = " ".join(cur + [w_])
                lim = maxw - (indent if not lines else 0)
                if cur and self.text_w(trial, spec) > lim:
                    lines.append(cur)
                    cur = [w_]
                else:
                    cur.append(w_)
            if cur:
                lines.append(cur)
            for li, ws in enumerate(lines):
                if y + lh > y1 + lh * 0.2:
                    return y
                xs = x0 + (indent if li == 0 else 0)
                last = li == len(lines) - 1
                line = " ".join(ws)
                if align == "justify" and not last and len(ws) > 1:
                    wsum = sum(self.text_w(w_, spec) for w_ in ws)
                    gap = (x1 - xs - wsum) / (len(ws) - 1)
                    cx = xs
                    for w_ in ws:
                        self.text((cx, y), w_, spec, fill)
                        cx += self.text_w(w_, spec) + gap
                elif align == "center":
                    self.text(((x0 + x1) / 2, y), line, spec, fill, anchor="ma")
                elif align == "right":
                    self.text((x1, y), line, spec, fill, anchor="ra")
                else:
                    self.text((xs, y), line, spec, fill, tracking=tracking)
                y += lh
        return y

    # ---- masks / fills
    def mask(self):
        return Canvas(self.w, self.h, 0, self.s, "L", self.wrap)

    def grid(self):
        """Pixel-centre coordinates in design units, at supersampled resolution."""
        H, W = self.img.size[1], self.img.size[0]
        yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
        return (xx + 0.5) / self.s, (yy + 0.5) / self.s

    def fill_cov(self, cov, color):
        """Composite a solid colour using a float coverage array (0..1) at ss resolution."""
        a = from_np(np.clip(cov, 0, 1) * 255, "L")
        solid = Image.new(self.img.mode, self.img.size, color)
        self.img.paste(solid, (0, 0), a)

    def fill_mask(self, m, color, alpha=1.0):
        cov = to_np(m.img) / 255.0 * alpha
        self.fill_cov(cov, color)

    def halftone_mask(self, m, color, tone, pitch=6.0, angle=45.0):
        """Fill mask with halftone dots of `color`; tone is scalar or (H,W) array at ss res (0..1)."""
        H, W = self.img.size[1], self.img.size[0]
        t = np.full((H, W), tone, np.float32) if np.isscalar(tone) else tone
        cov = halftone(t, pitch * self.s, angle, aa=self.s * 0.9) * (to_np(m.img) / 255.0)
        self.fill_cov(cov, color)

    def lin_tone(self, x0, y0, x1, y1, t0, t1):
        xx, yy = self.grid()
        dx, dy = x1 - x0, y1 - y0
        L2 = dx * dx + dy * dy
        t = np.clip(((xx - x0) * dx + (yy - y0) * dy) / L2, 0, 1)
        return (t0 + (t1 - t0) * t).astype(np.float32)

    def rad_tone(self, cx, cy, r, t0, t1):
        xx, yy = self.grid()
        t = np.clip(np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / r, 0, 1)
        return (t0 + (t1 - t0) * t).astype(np.float32)

    def gradient_mask(self, m, c0, c1, x0, y0, x1, y1):
        """Smooth two-colour gradient inside mask (use sparingly; print is mostly flat)."""
        t = self.lin_tone(x0, y0, x1, y1, 0, 1)[..., None]
        a = np.array(c0, np.float32) * (1 - t) + np.array(c1, np.float32) * t
        g = from_np(a, "RGB")
        self.img.paste(g, (0, 0), m.img)

    def glow(self, cx, cy, r, color, alpha=1.0, falloff=2.0):
        """Soft radial glow (smooth falloff) centred at cx,cy with radius r."""
        S = self.s
        x0, y0 = max(0, int((cx - r) * S)), max(0, int((cy - r) * S))
        x1, y1 = min(self.img.width, int((cx + r) * S) + 1), min(self.img.height, int((cy + r) * S) + 1)
        if x1 <= x0 or y1 <= y0:
            return
        yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
        d = np.sqrt((xx / S - cx) ** 2 + (yy / S - cy) ** 2) / r
        a = np.clip(1 - d, 0, 1) ** falloff * alpha
        region = self.img.crop((x0, y0, x1, y1))
        solid = Image.new(self.img.mode, region.size, color)
        region.paste(solid, (0, 0), from_np(a * 255, "L"))
        self.img.paste(region, (x0, y0))

    def paste(self, im, xy, mask=None):
        """Paste an image given in final-pixel scale (it is upscaled by ss)."""
        im2 = im.resize((im.width * self.s, im.height * self.s), Image.LANCZOS)
        X, Y = int(xy[0] * self.s), int(xy[1] * self.s)
        if mask is None and im2.mode == "RGBA":
            mask = im2
        elif mask is not None:
            mask = mask.resize(im2.size, Image.LANCZOS)
        self.img.paste(im2, (X, Y), mask)

    def sub(self, w, h, bg=(0, 0, 0, 0)):
        return Canvas(w, h, bg, self.s, "RGBA")

    def paste_canvas(self, c, xy, rotate=0.0):
        """Composite another Canvas (same ss) at xy (top-left), optional rotation about its centre."""
        im = c.img
        if rotate:
            im = im.rotate(rotate, resample=Image.BICUBIC, expand=True)
            X = int((xy[0] + c.w / 2) * self.s - im.width / 2)
            Y = int((xy[1] + c.h / 2) * self.s - im.height / 2)
        else:
            X, Y = int(xy[0] * self.s), int(xy[1] * self.s)
        if im.mode == "RGBA":
            self.img.paste(im, (X, Y), im)
        else:
            self.img.paste(im, (X, Y))

    def final(self):
        if self.s == 1:
            return self.img.copy()
        if self.wrap:
            # downsample with wrap-aware filtering: pad, resize, crop
            W, H = self.img.size
            p = self.s * 4
            big = Image.new(self.img.mode, (W + 2 * p, H + 2 * p))
            for i in (-1, 0, 1):
                for j in (-1, 0, 1):
                    big.paste(self.img, (p + i * W, p + j * H))
            small = big.resize(((W + 2 * p) // self.s, (H + 2 * p) // self.s), Image.LANCZOS)
            return small.crop((4, 4, 4 + self.w, 4 + self.h))
        return self.img.resize((self.w, self.h), Image.LANCZOS)


# --------------------------------------------------------------------------- print finish
def paper_texture(w, h, base=(252, 247, 236), seed=1, strength=1.0, tile=True):
    n1 = noise(w, h, w / 3, seed, octaves=2)            # fine grain
    n2 = noise(w, h, 6, seed + 1, octaves=4)            # blotchy cloudiness
    rng = np.random.default_rng(seed + 2)
    fib = rng.random((h, w)).astype(np.float32)
    fib = ndimage.uniform_filter1d(fib, 9, axis=1, mode="wrap")   # horizontal fibres
    v = 1.0 - strength * (0.035 * (n1 - 0.5) + 0.05 * (n2 - 0.5) + 0.05 * (fib - 0.5))
    a = np.array(base, np.float32)[None, None, :] * v[..., None]
    return np.clip(a, 0, 255)


def misregister(a, offs=((1.2, -0.6), (-0.8, 0.9), (0.5, 0.7))):
    """Shift the C, M, Y residual plates (after pulling a K plate) by fractional pixels."""
    rgb = a[..., :3] / 255.0
    cmy = 1.0 - rgb
    k = cmy.min(axis=2, keepdims=True)
    res = cmy - k
    out = np.empty_like(res)
    for i, (dx, dy) in enumerate(offs):
        out[..., i] = ndimage.shift(res[..., i], (dy, dx), order=1, mode="nearest")
    cmy2 = np.clip(out + k, 0, 1)
    b = a.copy()
    b[..., :3] = (1.0 - cmy2) * 255.0
    return b


def print_finish(img, seed=0, paper=(252, 247, 236), grain=1.0, mottle=1.0, misreg=1.0, screen=0.0,
                 screen_pitch=3.2, tile=False):
    """Make a flat illustration look printed on paper. img RGB/RGBA (alpha preserved)."""
    alpha = img.getchannel("A") if img.mode == "RGBA" else None
    a = to_np(img.convert("RGB"))
    h, w = a.shape[:2]
    if misreg:
        o = ((1.1 * misreg, -0.5 * misreg), (-0.7 * misreg, 0.8 * misreg), (0.4 * misreg, 0.6 * misreg))
        if tile:
            o = tuple((round(x), round(y)) for x, y in o)
            rgb = a / 255.0
            cmy = 1 - rgb
            k = cmy.min(axis=2, keepdims=True)
            res = cmy - k
            for i, (dx, dy) in enumerate(o):
                res[..., i] = np.roll(res[..., i], (int(dy), int(dx)), axis=(0, 1))
            a = (1 - np.clip(res + k, 0, 1)) * 255
        else:
            a = misregister(a, o)
    ink = 1.0 - a.mean(axis=2) / 255.0
    if screen:
        lum = a.mean(axis=2) / 255.0
        dots = halftone(np.clip((1 - lum) * 1.15, 0, 1), screen_pitch, 45)
        f = 1 - screen * (1 - dots) * np.clip(ink * 2.2, 0, 1) * 0.35
        a = a + (255 - a) * (1 - f[..., None])
    if mottle:
        n = noise(w, h, max(4, w / 24), seed + 11, octaves=3)
        n2 = noise(w, h, w / 4, seed + 12, octaves=1)
        lift = mottle * (0.10 * n + 0.06 * n2) * np.clip(ink * 1.6, 0, 1)
        a = a + (255 - a) * lift[..., None]
    if grain:
        pt = paper_texture(w, h, paper, seed + 3, grain, tile)
        a = a * pt / 255.0
    out = from_np(a, "RGB")
    if alpha is not None:
        out = out.convert("RGBA")
        out.putalpha(alpha)
    return out


# --------------------------------------------------------------------------- aging
def _stain_field(w, h, seed, count, tile=False, size=(0.08, 0.3)):
    """Water-stain tide marks: returns (fill, ring) float arrays."""
    rng = np.random.default_rng(seed)
    fill = np.zeros((h, w), np.float32)
    ring = np.zeros((h, w), np.float32)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    warp = noise(w, h, 6, seed + 5, octaves=4, tile=True) - 0.5
    var = noise(w, h, 24, seed + 6, octaves=2, tile=True)
    for _ in range(count):
        cx, cy = rng.random() * w, rng.random() * h
        r = rng.uniform(*size) * max(w, h)
        dx = xx - cx
        dy = yy - cy
        if tile:
            dx = (dx + w / 2) % w - w / 2
            dy = (dy + h / 2) % h - h / 2
        d = np.sqrt(dx * dx * rng.uniform(0.7, 1.3) + dy * dy * rng.uniform(0.7, 1.3)) / r + warp * 0.22
        inside = np.clip((1 - d) * 8, 0, 1) * (0.6 + 0.4 * var)
        fill = np.maximum(fill, inside * rng.uniform(0.25, 0.55))
        ring = np.maximum(ring, np.exp(-((d - 1) / 0.012) ** 2) * (0.5 + 0.5 * var) * rng.uniform(0.5, 0.9))
    return fill, ring


def age_paper(img, seed=0, amount=1.0, stains=3, tears=True, creases=2, foxing=40, fade=0.35, tile=False,
              yellow=(222, 196, 140), dust_violet=0):
    """Yellow, fade, stain and tear a printed piece. Returns RGBA (torn edges are transparent)."""
    img = img.convert("RGBA")
    alpha = to_np(img.getchannel("A")) / 255.0
    a = to_np(img.convert("RGB"))
    h, w = a.shape[:2]
    rng = np.random.default_rng(seed)
    # fade + desaturate + yellow
    lum = a.mean(axis=2, keepdims=True)
    a = a * (1 - 0.35 * amount) + lum * 0.35 * amount
    a = a * (1 - fade * amount) + 255 * fade * amount * 0.92
    yel = noise(w, h, 3, seed + 1, octaves=3, tile=tile)
    yc = np.array(yellow, np.float32) / 255.0
    t = (0.45 + 0.55 * yel)[..., None] * amount
    a = a * (1 - t + t * yc)
    # edge darkening (sun / handling)
    if not tile:
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        e = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy)) / (0.06 * min(w, h))
        e = np.clip(e + (noise(w, h, 12, seed + 9, 3) - 0.5) * 0.8, 0, 1)
        a *= (0.80 + 0.20 * e)[..., None] ** amount
    # stains
    if stains:
        f, r = _stain_field(w, h, seed + 2, stains, tile)
        brown = np.array([150, 110, 60], np.float32) / 255.0
        a = a * (1 - 0.22 * f[..., None] * (1 - brown)) * (1 - 0.3 * r[..., None] * (1 - brown))
    # foxing spots
    for _ in range(int(foxing * amount)):
        cx, cy, r = rng.random() * w, rng.random() * h, rng.uniform(1, 4.5)
        x0, x1 = int(max(0, cx - r * 3)), int(min(w, cx + r * 3))
        y0, y1 = int(max(0, cy - r * 3)), int(min(h, cy + r * 3))
        if x1 <= x0 or y1 <= y0:
            continue
        yy2, xx2 = np.mgrid[y0:y1, x0:x1]
        d = np.sqrt((xx2 - cx) ** 2 + (yy2 - cy) ** 2) / r
        m = np.clip(1.2 - d, 0, 1)[..., None] * rng.uniform(0.2, 0.5)
        a[y0:y1, x0:x1] *= 1 - m * (1 - np.array([0.62, 0.45, 0.28]))
    # creases
    for i in range(creases):
        vertical = rng.random() < 0.5
        pos = rng.uniform(0.3, 0.7) * (w if vertical else h)
        wob = (noise(w, h, 4, seed + 20 + i, 2) - 0.5) * 6
        coord = np.mgrid[0:h, 0:w][1 if vertical else 0].astype(np.float32)
        d = coord - pos + wob
        light = np.exp(-((d - 1.2) / 1.0) ** 2) * 0.25
        dark = np.exp(-((d + 1.0) / 1.4) ** 2) * 0.22
        a = a * (1 - dark[..., None]) + (255 - a) * light[..., None]
    # scuffs: lighten speckles where ink is
    sc = noise(w, h, w / 6, seed + 30, 2)
    sc = np.clip((sc - 0.72) * 6, 0, 1) * noise(w, h, 4, seed + 31, 2)
    a = a + (238 - a) * (sc * 0.6 * amount)[..., None]
    if dust_violet:
        # a few faint luminous Bloom spore specks (1978 aging)
        for _ in range(dust_violet):
            cx, cy, r = rng.random() * w, rng.random() * h, rng.uniform(1.5, 4)
            x0, x1 = int(max(0, cx - r * 4)), int(min(w, cx + r * 4))
            y0, y1 = int(max(0, cy - r * 4)), int(min(h, cy + r * 4))
            if x1 <= x0 or y1 <= y0:
                continue
            yy2, xx2 = np.mgrid[y0:y1, x0:x1]
            d = np.sqrt((xx2 - cx) ** 2 + (yy2 - cy) ** 2) / r
            m = (np.clip(1.3 - d, 0, 1) ** 1.5)[..., None] * 0.55
            a[y0:y1, x0:x1] = a[y0:y1, x0:x1] * (1 - m) + np.array(PAL["violet"], np.float32) * m
    # tears
    if tears and not tile:
        alpha = alpha * torn_alpha(w, h, seed + 40, amount)
    out = from_np(a, "RGB").convert("RGBA")
    out.putalpha(from_np(alpha * 255, "L"))
    return out


def torn_alpha(w, h, seed, amount=1.0, corner_bites=2):
    """Ragged paper edges + a couple of torn-away corners. Returns float (h,w)."""
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    jag = noise(w, h, w / 10, seed, octaves=3)
    e = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy))
    edge = 2 + 9 * jag * amount
    a = np.clip((e - edge) / 1.2, 0, 1)
    for _ in range(corner_bites):
        cx = rng.choice([0, w]) + rng.uniform(-0.05, 0.05) * w
        cy = rng.choice([0, h]) + rng.uniform(-0.05, 0.05) * h
        ang = rng.uniform(0, math.pi)
        nx, ny = math.cos(ang), math.sin(ang)
        r = rng.uniform(0.08, 0.2) * min(w, h) * amount
        d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) - r - (jag - 0.5) * 30
        a *= np.clip(d / 1.5, 0, 1)
    # a long rip from an edge
    if amount > 0.6:
        x0 = rng.uniform(0.2, 0.8) * w
        length = rng.uniform(0.08, 0.18) * h
        top = rng.random() < 0.5
        yline = yy if top else (h - 1 - yy)
        wob = (noise(w, h, 8, seed + 3, 3) - 0.5) * 24
        dist = np.abs(xx - x0 - wob - yline * 0.25)
        gap = np.clip(1 - yline / length, 0, 1) * 5
        a *= np.clip((dist - gap) / 1.2, 0, 1) * (yline < length) + (yline >= length)
    return a


def age_sign(img, seed=0, rust=1.0, fade=0.45, chips=1.0, grime=1.0, overgrowth=1.0, metal=True,
             bolts=None, blooms=True):
    """Weather a painted sign: sun-fade, chipped paint, rust bloom/streaks, grime, creeping vines and
    a few violet Bloom crystal flowers. Returns RGB (signs stay opaque)."""
    img = img.convert("RGB")
    a = to_np(img)
    h, w = a.shape[:2]
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    # sun fade: lighten + desaturate, more at top
    lum = a.mean(axis=2, keepdims=True)
    topf = (1 - yy / h * 0.4)[..., None]
    a = a * (1 - 0.4 * fade) + lum * 0.4 * fade
    a = a + (236 - a) * (fade * 0.45 * topf * (0.7 + 0.6 * noise(w, h, 4, seed + 1, 3)[..., None]))
    sub = np.array([118, 108, 98], np.float32) if metal else np.array([150, 120, 85], np.float32)
    rustc = np.array([140, 68, 32], np.float32)
    rustd = np.array([88, 42, 22], np.float32)
    # chipped paint
    n = noise(w, h, max(6, w / 40), seed + 2, octaves=5)
    edge = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy)) / (0.12 * min(w, h))
    chip = (n - 0.78 + 0.18 * np.clip(1 - edge, 0, 1) * chips) * 12 * chips
    chip = np.clip(chip, 0, 1)
    if metal:
        rn = noise(w, h, max(8, w / 30), seed + 3, 4)
        base = sub * (1 - rn[..., None]) + rustc * rn[..., None]
    else:
        g = noise(w * 1, h, w / 4, seed + 3, 2)
        base = sub * (0.8 + 0.4 * g[..., None])
    a = a * (1 - chip[..., None]) + base * chip[..., None]
    # rust bloom near edges + streaks from bolts
    if rust:
        rn = noise(w, h, max(6, w / 25), seed + 4, 5)
        rb = np.clip((rn - 0.55 + 0.35 * np.clip(1 - edge, 0, 1)) * 5 * rust, 0, 1)
        a = a * (1 - 0.85 * rb[..., None]) + (rustc * (1 - rn[..., None]) + rustd * rn[..., None]) * 0.85 * rb[..., None]
        pts = bolts or [(rng.uniform(0.05, 0.95) * w, rng.uniform(0.0, 0.4) * h) for _ in range(4)]
        for bx, by in pts:
            wid = rng.uniform(3, 9) * w / 1024
            length = rng.uniform(0.25, 0.7) * h
            wob = (noise(w, h, 6, int(bx + by) + seed, 2) - 0.5) * wid * 2
            dx = np.abs(xx - bx - wob)
            dy = yy - by
            s = np.clip(1 - dx / wid, 0, 1) * np.clip(1 - dy / length, 0, 1) * (dy > 0)
            s *= 0.55 * rust * (0.6 + 0.4 * noise(w, h, w / 8, seed + 7, 1))
            a = a * (1 - s[..., None]) + rustc * s[..., None]
    # grime gradient from bottom + speckle
    if grime:
        g = np.clip((yy / h - 0.45) * 1.5, 0, 1) * (0.5 + 0.5 * noise(w, h, 8, seed + 8, 3))
        a *= (1 - 0.35 * grime * g)[..., None]
        sp = noise(w, h, w / 3, seed + 9, 1)
        a *= (1 - 0.12 * grime * np.clip((sp - 0.6) * 3, 0, 1))[..., None]
    out = from_np(a, "RGB")
    if overgrowth:
        out = overgrow(out, seed + 50, overgrowth, blooms)
    return out


def overgrow(img, seed=0, amount=1.0, blooms=True):
    """Vines and leaves creeping up from the bottom/sides, with violet Bloom crystal flowers."""
    w, h = img.size
    ss = 2
    C = Canvas(w, h, (0, 0, 0, 0), ss, "RGBA")
    rng = np.random.default_rng(seed)
    greens = [hexc("4E6B3A"), hexc("3B5530"), hexc("6E8B4A"), hexc("2F4427")]
    n_vines = int(round((2 + 3 * amount) * max(1, w / h / 2)))
    tips = []
    for i in range(n_vines):
        x = rng.uniform(0.02, 0.98) * w
        y = h + 4
        ang = -math.pi / 2 + rng.uniform(-0.6, 0.6)
        L = rng.uniform(0.35, 0.95) * h * amount
        pts = [(x, y)]
        steps = 22
        for s in range(steps):
            ang += rng.uniform(-0.35, 0.35)
            ang = max(-math.pi + 0.3, min(-0.3, ang))
            x += math.cos(ang) * L / steps
            y += math.sin(ang) * L / steps
            pts.append((x, y))
        col = greens[i % len(greens)]
        C.line(pts, col + (255,), width=max(2, w / 400))
        for j, (px, py) in enumerate(pts[2::2]):
            side = 1 if j % 2 else -1
            lsz = rng.uniform(5, 11) * min(1.6, w / 700 + 0.5)
            la = rng.uniform(0, 2 * math.pi)
            lx, ly = px + side * lsz * 0.8, py - lsz * 0.3
            leaf = [(lx + math.cos(la + t) * lsz * (1 if k % 2 == 0 else 0.45), ly + math.sin(la + t) * lsz * (1 if k % 2 == 0 else 0.45))
                    for k, t in enumerate(np.linspace(0, 2 * math.pi, 9)[:-1])]
            C.poly(leaf, greens[(i + j) % len(greens)] + (255,))
        tips.append(pts[-1])
        tips.append(pts[len(pts) // 2])
    # grass tufts along the bottom
    for k in range(int(w / 9 * amount)):
        x = rng.uniform(0, w)
        hgt = rng.uniform(0.05, 0.22) * h * amount
        lean = rng.uniform(-0.4, 0.4) * hgt
        C.poly([(x - 2.5, h + 2), (x + lean, h - hgt), (x + 2.5, h + 2)], greens[k % 4] + (255,))
    if blooms:
        nb = max(1, int(round((1 + 2 * amount) * max(1, w / h / 2))))
        spots = [tips[int(rng.integers(len(tips)))] for _ in range(nb)] + \
                [(rng.uniform(0.05, 0.95) * w, h - rng.uniform(0, 0.12) * h) for _ in range(nb)]
        for (bx, by) in spots:
            crystal_flower(C, bx, by, rng.uniform(7, 14) * min(2.0, w / 600 + 0.5), seed=int(rng.integers(1e6)))
    lay = C.final()
    base = img.convert("RGBA")
    base.alpha_composite(lay)
    return base.convert("RGB")


def crystal_flower(C, cx, cy, r, seed=0, glow=True):
    """Small violet Bloom crystal flower: faceted shard petals around a bright core."""
    rng = np.random.default_rng(seed)
    v = PAL["violet"]
    if glow:
        for k in range(5, 0, -1):
            C.circle(cx, cy, r * (0.9 + k * 0.35), fill=v + (int(14 + 6 * (5 - k)),))
    n = int(rng.integers(5, 8))
    base_a = rng.uniform(0, math.pi)
    for i in range(n):
        a = base_a + i * 2 * math.pi / n
        L = r * rng.uniform(0.8, 1.25)
        wv = r * 0.32
        tip = (cx + math.cos(a) * L, cy + math.sin(a) * L)
        l = (cx + math.cos(a - 0.5) * wv, cy + math.sin(a - 0.5) * wv)
        rr = (cx + math.cos(a + 0.5) * wv, cy + math.sin(a + 0.5) * wv)
        C.poly([(cx, cy), l, tip], shade(v, 0.72) + (255,))
        C.poly([(cx, cy), tip, rr], shade(v, 1.35) + (255,))
    C.circle(cx, cy, r * 0.28, fill=(246, 232, 255, 255))


# --------------------------------------------------------------------------- misc
def save(img, name, quiet=False):
    p = OUT / f"{name}.png"
    if img.mode == "RGBA":
        a = img.getchannel("A")
        if a.getextrema()[0] == 255:
            img = img.convert("RGB")
    img.save(p, optimize=True)
    if not quiet:
        print("wrote", p.name, img.size)
    return p


def tile_check(img):
    """Return (seam_err, interior_err): mean abs diff across the wrap seam vs adjacent interior columns."""
    a = to_np(img.convert("RGB"))
    seam = (np.abs(a[:, 0] - a[:, -1]).mean() + np.abs(a[0] - a[-1]).mean()) / 2
    inner = (np.abs(a[:, 1:] - a[:, :-1]).mean() + np.abs(a[1:] - a[:-1]).mean()) / 2
    return float(seam), float(inner)


def tile2x2(img):
    w, h = img.size
    t = Image.new(img.mode, (w * 2, h * 2))
    for i in range(2):
        for j in range(2):
            t.paste(img, (i * w, j * h))
    return t
