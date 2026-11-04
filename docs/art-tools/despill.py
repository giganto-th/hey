"""Remove the green fringe left by chroma keying on wispy hair/fur: no pixel may be greener than it is red."""
import sys, glob
import numpy as np
from PIL import Image
for pattern in sys.argv[1:]:
    for f in glob.glob(pattern, recursive=True):
        a = np.asarray(Image.open(f).convert("RGBA")).astype(np.float32)
        r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
        spill = np.clip(g - np.maximum(r, b) * 1.02, 0, None)
        g2 = g - spill
        # near-transparent greenish dust goes away entirely
        dust = (al < 90) & (g > r + 8)
        al2 = np.where(dust, 0, al)
        Image.fromarray(np.dstack([r, g2, b, al2]).clip(0, 255).astype(np.uint8)).save(f)
