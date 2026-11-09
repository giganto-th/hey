#!/usr/bin/env python3
"""Pin the keyboard (and so the feet beside it) in the pets' typing clips.

The generated typing frames each place the keyboard a little differently (up to ~30 px of a 480 px frame), so in the app
the keyboard and the bird's legs slide back and forth while it types. This finds the keyboard in every frame (dark, grey,
near the ground) and translates each frame so the keyboard sits where it does in the median frame.

    python3 docs/art-tools/register_type.py            # report only
    python3 docs/art-tools/register_type.py --write    # rewrite the PNGs in place
"""
import glob, os, sys
import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "Resources", "Pets")

def keyboard_box(arr):
    """Bounding box (x0, x1, y1) of the dark grey keyboard in the lowest part of the frame, or None."""
    h, w = arr.shape[:2]
    a = arr[:, :, 3] > 200
    rgb = arr[:, :, :3].astype(int)
    mx, mn = rgb.max(axis=2), rgb.min(axis=2)
    dark = a & (mx < 115) & (mx - mn < 30)
    ys, xs = np.nonzero(a)
    if len(ys) == 0: return None
    floor = ys.max()
    band = np.zeros_like(dark); band[max(0, floor - 60):floor + 1, :] = True
    ys, xs = np.nonzero(dark & band)
    if len(xs) < 200: return None
    # the keyboard is the biggest dark blob in the band; drop strays by trimming extreme 2% columns
    x0, x1 = np.percentile(xs, [2, 98])
    return x0, x1, ys.max()

def feet_x(arr):
    """Mean x of the orange leg pixels in the lowest band (to report how well feet stay put)."""
    a = arr[:, :, 3] > 200
    ys, _ = np.nonzero(a)
    floor = ys.max()
    rgb = arr[:, :, :3].astype(int)
    orange = a & (rgb[:, :, 0] > 190) & (rgb[:, :, 1] > 110) & (rgb[:, :, 1] < 200) & (rgb[:, :, 2] < 90)
    orange[: floor - 70, :] = False
    ys, xs = np.nonzero(orange)
    return xs.mean() if len(xs) > 30 else None

def shift(img, dx, dy):
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.alpha_composite(img, (int(round(dx)), int(round(dy))))
    return out

def main():
    write = "--write" in sys.argv
    for set_dir in sorted(glob.glob(os.path.join(ROOT, "*", "*", "anim"))):
        files = sorted(glob.glob(os.path.join(set_dir, "type_*.png")), key=lambda p: int(os.path.basename(p)[5:-4]))
        if not files: continue
        imgs = [Image.open(f).convert("RGBA") for f in files]
        arrs = [np.array(i) for i in imgs]
        boxes = [keyboard_box(a) for a in arrs]
        name = "/".join(set_dir.split(os.sep)[-3:-1])
        if any(b is None for b in boxes):
            print(f"{name}: keyboard not found in every frame, skipped"); continue
        cx = [(b[0] + b[1]) / 2 for b in boxes]; by = [b[2] for b in boxes]
        rx, ry = float(np.median(cx)), float(np.median(by))
        fb = [feet_x(a) for a in arrs]
        out = []
        for img, c, y in zip(imgs, cx, by):
            out.append(shift(img, rx - c, ry - y))
        after = [keyboard_box(np.array(o)) for o in out]
        fa = [feet_x(np.array(o)) for o in out]
        rng = lambda v: max(v) - min(v)
        feet_before = rng([f for f in fb if f is not None]) if any(f is not None for f in fb) else float("nan")
        feet_after = rng([f for f in fa if f is not None]) if any(f is not None for f in fa) else float("nan")
        print(f"{name}: keyboard x range {rng(cx):.0f} -> {rng([(b[0]+b[1])/2 for b in after]):.0f}px, "
              f"bottom {rng(by):.0f} -> {rng([b[2] for b in after]):.0f}px, feet x range {feet_before:.0f} -> {feet_after:.0f}px")
        if write:
            for f, o in zip(files, out): o.save(f)

if __name__ == "__main__":
    main()
