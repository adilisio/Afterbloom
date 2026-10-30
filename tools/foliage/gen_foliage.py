"""Procedural foliage alpha textures: leaf clusters, pine needles, grass blades (white-ish albedo, tinted in shader)."""
import math, random
from PIL import Image, ImageDraw, ImageFilter
OUT = "assets/textures/foliage/"
random.seed(7)

def leaf_cluster(path, n=420, size=512):
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx = cy = size / 2
    for i in range(n):
        r = (random.random() ** 0.6) * size * 0.46
        a = random.random() * math.tau
        x, y = cx + math.cos(a) * r, cy + math.sin(a) * r
        L = random.uniform(16, 30); W = L * random.uniform(0.38, 0.55)
        ang = random.random() * math.tau
        shade = random.uniform(0.62, 1.0)
        # leaf polygon (pointed ellipse) + midrib
        pts = []
        for k in range(14):
            t = k / 13 * math.pi
            px = math.cos(t) * L / 2
            py = math.sin(t) * W / 2 * (1 - 0.3 * (math.cos(t) > 0.6))
            pts.append((px, py))
        pts += [(p[0], -p[1]) for p in reversed(pts)]
        rot = [(x + p[0] * math.cos(ang) - p[1] * math.sin(ang), y + p[0] * math.sin(ang) + p[1] * math.cos(ang)) for p in pts]
        c = int(255 * shade)
        d.polygon(rot, fill=(c, c, c, 255))
        d.line([(x - math.cos(ang) * L / 2, y - math.sin(ang) * L / 2), (x + math.cos(ang) * L / 2, y + math.sin(ang) * L / 2)], fill=(int(c * 0.75),) * 3 + (255,), width=1)
    # small twigs
    for i in range(30):
        a = random.random() * math.tau
        r = random.uniform(0.1, 0.45) * size
        d.line([(cx, cy), (cx + math.cos(a) * r, cy + math.sin(a) * r)], fill=(90, 70, 55, 255), width=2)
    im.save(path)

def pine(path, size=512):
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # a branch from left-centre to right with needles along it, drooping
    for b in range(9):
        y0 = size * (0.12 + b * 0.09)
        x0 = 4
        length = size * random.uniform(0.75, 0.97)
        pts = [(x0 + t * length, y0 + (t ** 2) * size * 0.06) for t in [i / 40 for i in range(41)]]
        d.line(pts, fill=(95, 75, 60, 255), width=3)
        for (px, py) in pts[2:]:
            for s in (-1, 1):
                for k in range(2):
                    a = s * random.uniform(0.6, 1.2) + 0.3
                    L = random.uniform(10, 18) * (1.1 - (px / size) * 0.4)
                    c = int(255 * random.uniform(0.6, 1.0))
                    d.line([(px, py), (px + math.cos(a) * L, py + math.sin(a) * L)], fill=(c, c, c, 255), width=2)
    im.save(path)

def grass(path, size=256):
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for i in range(70):
        x = random.uniform(8, size - 8)
        h = random.uniform(0.45, 0.98) * size
        bend = random.uniform(-0.25, 0.25) * size
        w = random.uniform(2.5, 5.0)
        c = int(255 * random.uniform(0.65, 1.0))
        pts_l, pts_r = [], []
        for k in range(12):
            t = k / 11
            px = x + bend * t * t
            py = size - t * h
            ww = w * (1 - t)
            pts_l.append((px - ww, py)); pts_r.append((px + ww, py))
        d.polygon(pts_l + list(reversed(pts_r)), fill=(c, c, c, 255))
    im.save(path)

leaf_cluster(OUT + "leaf_cluster.png")
pine(OUT + "pine_branch.png")
grass(OUT + "grass_blades.png")
print("ok")
