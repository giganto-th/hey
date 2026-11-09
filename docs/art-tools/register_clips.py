#!/usr/bin/env python3
"""Pin the part of the bird that should stay put in a clip, by translating each frame.

    python3 docs/art-tools/register_clips.py walk eat            # report what would change
    python3 docs/art-tools/register_clips.py walk eat --write    # rewrite the PNGs
    python3 docs/art-tools/register_clips.py eat --species fluff --stage teen --sheets /tmp/after

walk  holds the torso still, where it sits in the idle clip (the window carries the pet across the screen, so a body that drifts inside its frame reads as sliding).
eat   holds the feet still, where they stand in the idle clip (the bird leans in to peck; its feet stay where they are).
Frames are never cropped: a shift that would push opaque pixels off the canvas is limited to what fits.
"""
import argparse, collections, glob, importlib.util, os, sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("clip_report", os.path.join(HERE, "clip_report.py"))
cr = importlib.util.module_from_spec(spec); spec.loader.exec_module(cr)

def room(a, dx):
    """Limit a horizontal shift so no opaque pixel leaves the canvas."""
    xs = np.nonzero((a[:, :, 3] > 8).any(axis=0))[0]
    if len(xs) == 0: return 0
    lo, hi = -xs.min(), (a.shape[1] - 1) - xs.max()
    return int(max(lo, min(hi, dx)))

def shifted(img, dx):
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.alpha_composite(img, (int(dx), 0))
    return out

def idle_refs(d, band):
    """Where the torso and feet sit in the idle clip: the other clips line up with it so switching between them does not pop."""
    torso, feet = [], []
    for f in sorted(glob.glob(os.path.join(d, "idle_*.png"))):
        a = cr.load(f)
        tx = np.nonzero(a[band[0]:band[1], :, 3] > 200)[1]
        torso.append(tx.mean())
        feet.append(cr.foot_x(a, np.nonzero(a[:, :, 3] > 200)[0].max()))
    return float(np.nanmedian(torso)), float(np.nanmedian(feet))

def plan(clip, files, band, near, ref):
    arrs = [cr.load(f) for f in files]
    if clip == "walk":
        anchor = []
        for a in arrs:
            tx = np.nonzero(a[band[0]:band[1], :, 3] > 200)[1]
            anchor.append(tx.mean() if len(tx) else np.nan)
    else:  # eat
        anchor = []
        for a in arrs:
            ys, _ = np.nonzero(a[:, :, 3] > 200)
            anchor.append(cr.foot_x(a, ys.max(), near) if len(ys) else np.nan)
    anchor = np.array(anchor)
    if np.sum(~np.isnan(anchor)) < 6: return None
    shifts = ref - anchor
    # frames where the anchor cannot be seen (feet off the ground, hidden by the body) borrow the nearest seen frame's shift
    for i in range(len(shifts)):
        if np.isnan(shifts[i]):
            seen = [j for j in range(len(shifts)) if not np.isnan(shifts[j])]
            shifts[i] = shifts[min(seen, key=lambda j: min(abs(i - j), len(shifts) - abs(i - j)))]
    return arrs, anchor, [room(a, int(round(s))) for a, s in zip(arrs, shifts)]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("clips", nargs="+", choices=["walk", "eat"])
    ap.add_argument("--species"); ap.add_argument("--stage")
    ap.add_argument("--write", action="store_true"); ap.add_argument("--sheets")
    args = ap.parse_args()
    for d in sorted(glob.glob(os.path.join(cr.ROOT, "*", "*", "anim"))):
        sp, st = d.split(os.sep)[-3:-1]
        if (args.species and sp != args.species) or (args.stage and st != args.stage): continue
        idle = sorted(glob.glob(os.path.join(d, "idle_*.png")))
        band = cr.band_rows(cr.mask(idle[0]))
        torso_ref, feet_ref = idle_refs(d, band)
        near = feet_ref
        for clip in args.clips:
            files = sorted(glob.glob(os.path.join(d, f"{clip}_*.png")), key=lambda p: int(p.rsplit("_", 1)[1][:-4]))
            if not files: continue
            result = plan(clip, files, band, near, torso_ref if clip == "walk" else feet_ref)
            if result is None:
                print(f"{sp}/{st} {clip}: anchor not found, skipped"); continue
            arrs, anchor, dxs = result
            after = [a if dx == 0 else np.array(shifted(Image.fromarray(a), dx)) for a, dx in zip(arrs, dxs)]
            if clip == "walk":
                new = [np.nonzero(a[band[0]:band[1], :, 3] > 200)[1].mean() for a in after]
            else:
                new = [cr.foot_x(a, np.nonzero(a[:, :, 3] > 200)[0].max(), near) for a in after]
            rng = lambda v: float(np.nanmax(v) - np.nanmin(v))
            print(f"{sp}/{st:10s} {clip:5s} anchor range {rng(anchor):5.1f} -> {rng(new):5.1f}px   max shift {max(abs(x) for x in dxs):3d}px")
            if args.sheets:
                os.makedirs(args.sheets, exist_ok=True)
                W = 160
                sheet = Image.new("RGB", (W * len(after), W), (235, 235, 235))
                for i, a in enumerate(after):
                    im = Image.fromarray(a).resize((W, W)); bg = Image.new("RGBA", im.size, (235, 235, 235, 255)); bg.alpha_composite(im)
                    sheet.paste(bg.convert("RGB"), (i * W, 0))
                sheet.save(os.path.join(args.sheets, f"{sp}_{st}_{clip}.png"))
            if args.write:
                for f, a in zip(files, after): Image.fromarray(a).save(f)

if __name__ == "__main__":
    main()
