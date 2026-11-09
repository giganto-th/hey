#!/usr/bin/env python3
"""Measure how steady each pet clip is, so registration problems (a bird or keyboard sliding between frames) show up as numbers.

    python3 docs/art-tools/clip_report.py                  # table for every species / stage / clip
    python3 docs/art-tools/clip_report.py --sheets DIR     # also write a contact sheet per clip with the anchors drawn
    python3 docs/art-tools/clip_report.py --clip walk --species heihei

Anchors (all in the art's 480 px canvas):
  contact  x of the rear foot (orange pixels in the lowest rows)    should be steady in calm clips
  torso    mean x of the body band (below the head, above the legs)  should be steady even when walking: the window moves the pet
  bottom   lowest opaque row                                        should be steady unless the bird leaves the ground
Each is reported as a range over the clip. `jitter` is the mean frame-to-frame step of the torso anchor: a high value with
a low range means it shakes in place, which reads as a wobble.
"""
import argparse, collections, glob, os, sys
import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "Resources", "Pets")

# What each clip is allowed to do. "calm": nothing should slide; "hop": may leave the ground; "walk": legs move, body should not;
# "free": moves on purpose.
KIND = {"idle": "calm", "sleep": "calm", "eat": "calm", "type": "calm", "hatch": "free",
        "happy": "hop", "dance": "hop", "startled": "hop", "flap": "hop", "fly": "free",
        "walk": "walk", "dizzy": "free", "carried": "free"}
# Clips already over their limit when the check was added (the sleeping clip hides the feet, so it cannot be judged by colour;
# the rest are small slides left for later). --check only fails for a clip that is over and not listed here.
BASELINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "clip_baseline.txt")

# Largest drift (px of 480) we accept per kind, judged by eye on contact sheets (a sliding foot starts to show above ~12 px). Used by --check.
LIMIT = {"calm": 12, "hop": 20, "walk": 14, "free": 1e9}

def load(path):
    return np.array(Image.open(path).convert("RGBA"))

def mask(path):
    return load(path)[:, :, 3] > 200

def foot_x(a, floor, near=None, reach=55):
    """x of the feet: orange pixels in the lowest rows. With `near` (where the feet stand in the idle clip) only pixels within
    `reach` px of it count, so a pecking beak or a food crumb in front of the feet is ignored."""
    rgb = a[:, :, :3].astype(int)
    band = np.zeros(a.shape[:2], bool); band[max(0, floor - 30):floor + 1, :] = True
    orange = (a[:, :, 3] > 200) & band & (rgb[:, :, 0] > 175) & (rgb[:, :, 1] > 80) & (rgb[:, :, 1] < 215) & (rgb[:, :, 2] < 110)
    xs = np.nonzero(orange)[1]
    if near is None:
        return float(np.percentile(xs, 25)) if len(xs) > 25 else np.nan
    xs = xs[np.abs(xs - near) <= reach]
    return float(xs.mean()) if len(xs) > 25 else np.nan

def band_rows(ref_mask):
    ys, _ = np.nonzero(ref_mask)
    top, bottom = ys.min(), ys.max()
    h = bottom - top
    return int(top + 0.45 * h), int(top + 0.80 * h)

def measure(files, band, near=None):
    contact, torso, bottom = [], [], []
    for f in files:
        a = load(f)
        m = a[:, :, 3] > 200
        ys, xs = np.nonzero(m)
        if len(ys) == 0: continue
        floor = ys.max()
        contact.append(foot_x(a, floor, near))
        rows = m[band[0]:band[1], :]
        tx = np.nonzero(rows)[1]
        torso.append(tx.mean() if len(tx) else np.nan)
        bottom.append(floor)
    return np.array(contact), np.array(torso), np.array(bottom)

def sheet(files, torso, contact, out):
    W = 160
    n = len(files)
    img = Image.new("RGB", (W * n, W), (235, 235, 235))
    for i, f in enumerate(files):
        im = Image.open(f).convert("RGBA").resize((W, W))
        bg = Image.new("RGBA", im.size, (235, 235, 235, 255)); bg.alpha_composite(im)
        img.paste(bg.convert("RGB"), (i * W, 0))
        d = ImageDraw.Draw(img)
        d.line([(i * W + torso[i] * W / 480, 0), (i * W + torso[i] * W / 480, W)], fill=(220, 30, 30), width=1)
        d.line([(i * W + contact[i] * W / 480 - 3, W - 4), (i * W + contact[i] * W / 480 + 3, W - 4)], fill=(30, 90, 220), width=3)
    img.save(out)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--clip"); ap.add_argument("--species"); ap.add_argument("--stage")
    ap.add_argument("--write-baseline", action="store_true", help="record the clips that are over their limit now as accepted")
    ap.add_argument("--sheets"); ap.add_argument("--check", action="store_true", help="exit 1 if a clip not in the baseline drifts more than its limit")
    args = ap.parse_args()
    rows, bad = [], 0
    for d in sorted(glob.glob(os.path.join(ROOT, "*", "*", "anim"))):
        sp, st = d.split(os.sep)[-3:-1]
        if args.species and sp != args.species: continue
        if args.stage and st != args.stage: continue
        idle = sorted(glob.glob(os.path.join(d, "idle_*.png")))
        if not idle: continue
        band = band_rows(mask(idle[0]))
        ia = load(idle[0]); iys, _ = np.nonzero(ia[:, :, 3] > 200)
        near = foot_x(ia, iys.max())
        clips = collections.defaultdict(list)
        for f in glob.glob(os.path.join(d, "*.png")):
            clips[os.path.basename(f).rsplit("_", 1)[0]].append(f)
        for c, fs in sorted(clips.items()):
            if args.clip and c != args.clip: continue
            fs.sort(key=lambda p: int(p.rsplit("_", 1)[1][:-4]))
            contact, torso, bottom = measure(fs, band, near)
            if len(torso) < 2: continue
            rng = lambda v: float(np.nanmax(v) - np.nanmin(v)) if np.sum(~np.isnan(v)) >= 2 else 0.0
            jitter = float(np.nanmean(np.abs(np.diff(torso))))
            kind = KIND.get(c, "free")
            drift = rng(torso) if kind in ("walk", "hop") else (float(np.nanmax(contact) - np.nanmin(contact)) if np.sum(~np.isnan(contact)) >= 3 else 0.0)
            rows.append((sp, st, c, kind, rng(contact), rng(torso), rng(bottom), jitter, drift))
            if drift > LIMIT[kind]: bad += 1
            if args.sheets:
                os.makedirs(args.sheets, exist_ok=True)
                sheet(fs, torso, contact, os.path.join(args.sheets, f"{sp}_{st}_{c}.png"))
    print(f"{'set':18s}{'clip':9s}{'kind':6s}{'contact':>8s}{'torso':>7s}{'bottom':>7s}{'jitter':>7s}  flag")
    for sp, st, c, kind, ct, tr, bt, jt, drift in sorted(rows, key=lambda r: -(r[8] / LIMIT[r[3]] if LIMIT[r[3]] < 1e8 else 0)):
        flag = "OVER" if drift > LIMIT[kind] else ""
        print(f"{sp+'/'+st:18s}{c:9s}{kind:6s}{ct:8.0f}{tr:7.0f}{bt:7.0f}{jt:7.1f}  {flag}")
    by = collections.defaultdict(list)
    for r in rows: by[r[2]].append(r[8])
    print("\nclip      kind   mean drift   sets over limit")
    for c in sorted(by, key=lambda c: -np.mean(by[c])):
        k = KIND.get(c, "free")
        print(f"{c:9s} {k:6s} {np.mean(by[c]):9.1f}   {sum(1 for v in by[c] if v > LIMIT[k])}/{len(by[c])}")
    over = sorted(f"{sp}/{st}/{c}" for sp, st, c, kind, ct, tr, bt, jt, drift in rows if drift > LIMIT[kind])
    known = set(open(BASELINE).read().split()) if os.path.exists(BASELINE) else set()
    new = [o for o in over if o not in known]
    print(f"\n{len(over)} of {len(rows)} clips over their limit, {len(new)} not in the baseline")
    if args.write_baseline:
        open(BASELINE, "w").write("\n".join(over) + "\n"); print("baseline written")
    if args.check and new:
        print("NEW:", *new, sep="\n  "); sys.exit(1)

if __name__ == "__main__":
    main()
