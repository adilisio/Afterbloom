"""Tile screenshots into one image: python montage.py out.png a.png b.png ... [--w 800]"""
import sys
from PIL import Image, ImageDraw
args = sys.argv[1:]
w = 800
if "--w" in args:
    i = args.index("--w"); w = int(args[i + 1]); del args[i:i + 2]
out, files = args[0], args[1:]
ims = [Image.open(f).convert("RGB") for f in files]
h = int(w * ims[0].height / ims[0].width)
cols = 2 if len(ims) > 1 else 1
rows = (len(ims) + cols - 1) // cols
M = Image.new("RGB", (w * cols, h * rows), (20, 20, 20))
d = ImageDraw.Draw(M)
for k, (im, f) in enumerate(zip(ims, files)):
    x, y = (k % cols) * w, (k // cols) * h
    M.paste(im.resize((w, h), Image.LANCZOS), (x, y))
    d.text((x + 6, y + 4), f.split("/")[-1], fill=(255, 255, 0))
M.save(out)
