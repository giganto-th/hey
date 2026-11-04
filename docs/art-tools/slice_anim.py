# -*- coding: utf-8 -*-
"""Slice a 5x2 animation sheet (10 frames) into 480px canvases, keeping the generator's motion."""
import sys, os, json
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
from slice import key, OUT
IDLE_H = 346          # px of an adult standing bird on the 480 canvas (same as the single poses)
COLS, ROWS = 5, 2

def load(sheet):
    im = key(Image.open(sheet)); W, H = im.size
    cw, ch = W // COLS, H // ROWS
    frames = []
    for i in range(COLS * ROWS):
        c, r = i % COLS, i // COLS
        cell = im.crop((c*cw, r*ch, (c+1)*cw, (r+1)*ch))
        al = np.asarray(cell.split()[3]); ys, xs = np.where(al > 40)
        frames.append((cell, (xs.min(), ys.min(), xs.max()+1, ys.max()+1), xs.mean()))
    return frames, cw, ch

def scale_standing(frames):
    x0, y0, x1, y1 = frames[0][1]
    return IDLE_H / (y1 - y0)

def build(sheet, outdir, name, mode, scale):
    frames, cw, ch = load(sheet)
    base_bottom = frames[0][1][3]
    base_cx = frames[0][2]
    base_top = frames[0][1][1]
    os.makedirs(outdir, exist_ok=True)
    for i, (cell, bb, cx) in enumerate(frames):
        c = cell.resize((round(cell.width*scale), round(cell.height*scale)), Image.LANCZOS)
        # position by cell coordinates: x so that frame 1's centroid is centred, y by mode
        px = round(OUT/2 - base_cx*scale)
        if mode == "ground":
            py = round(OUT - 2 - base_bottom*scale)
            dy = (bb[3] - base_bottom)
            if abs(dy) < 0.03*ch: py -= round(dy*scale)          # grounded frame: snap feet to the baseline
        elif mode == "top":
            py = round(OUT - 2 - IDLE_H - base_top*scale + 0)
        else:  # centre of the canvas
            py = round(OUT*0.5 - ch*scale/2)
        big = Image.new("RGBA", (OUT*3, OUT*3), (0,0,0,0))
        big.alpha_composite(c, (px + OUT, py + OUT))      # the cell may be larger than the canvas: crop afterwards
        canvas = big.crop((OUT, OUT, OUT*2, OUT*2))
        canvas.save(os.path.join(outdir, f"{name}_{i}.png"))
    sheetimg = Image.new("RGBA", (OUT//3*5, OUT//3*2), (225,225,230,255))
    for i in range(10):
        im = Image.open(os.path.join(outdir, f"{name}_{i}.png")).resize((OUT//3, OUT//3))
        sheetimg.alpha_composite(im, ((i%5)*OUT//3, (i//5)*OUT//3))
    sheetimg.save(os.path.join(outdir, f"_{name}_contact.png"))

MODES = {"idle":"ground","walk":"ground","type":"ground","eat":"ground","dance":"ground","sleep":"ground",
         "flap":"ground","fly":"center","startled":"ground","dizzy":"ground","carried":"top","happy":"ground"}
STANDING = ["idle","walk","type","eat","dance","flap","startled","happy"]

def run(root, out):
    ks = {}
    for n in MODES:
        sheet = f"{root}/{n}/sheet.png"
        if os.path.exists(sheet):
            frames, cw, ch = load(sheet)
            ks[n] = (scale_standing(frames), cw, ch)
    ref = [ks[n][0] * ks[n][2] for n in STANDING if n in ks]
    K = float(np.mean(ref))       # scale * cell height: stable across sheets
    for n, (sc, cw, ch) in ks.items():
        scale = sc if n in STANDING else K / ch
        build(f"{root}/{n}/sheet.png", out, n, MODES[n], scale)
        print(n, "scale", round(scale, 3), "(standing)" if n in STANDING else "(from K)")

if __name__ == "__main__":
    run(sys.argv[1], sys.argv[2])
