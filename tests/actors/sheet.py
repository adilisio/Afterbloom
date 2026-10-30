"""Contact sheet: python sheet.py out.png cols crop(x0,y0,x1,y1 fractions) img1 img2 ..."""
import sys
from PIL import Image
out, cols, crop = sys.argv[1], int(sys.argv[2]), [float(v) for v in sys.argv[3].split(',')]
ims = [Image.open(p) for p in sys.argv[4:]]
w, h = ims[0].size
box = (int(w * crop[0]), int(h * crop[1]), int(w * crop[2]), int(h * crop[3]))
cw = 480
ch = int(cw * (box[3] - box[1]) / (box[2] - box[0]))
rows = (len(ims) + cols - 1) // cols
sheet = Image.new('RGB', (cw * cols, ch * rows))
for i, im in enumerate(ims):
    sheet.paste(im.crop(box).resize((cw, ch)), ((i % cols) * cw, (i // cols) * ch))
sheet.save(out)
print(out, sheet.size)
