"""Dev helper: contact sheet of generated images.  python contact.py out.png scale name1 name2 ..."""
import sys
from PIL import Image
from common import OUT
out, scale, names = sys.argv[1], float(sys.argv[2]), sys.argv[3:]
ims = [Image.open(OUT / f"{n}.png").convert("RGBA") for n in names]
ims = [im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS) for im in ims]
cols = min(len(ims), max(1, int(1600 // max(i.width for i in ims))))
rows = (len(ims) + cols - 1) // cols
cw, ch = max(i.width for i in ims) + 8, max(i.height for i in ims) + 8
sheet = Image.new("RGBA", (cw * cols, ch * rows), (90, 90, 90, 255))
for k, im in enumerate(ims):
    sheet.alpha_composite(im, ((k % cols) * cw + 4, (k // cols) * ch + 4))
sheet.convert("RGB").save(out)
