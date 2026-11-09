#!/usr/bin/env python3
"""Print the Swift table of how much to shrink each sleeping pose so a pet lying down is not wider than a standing one.

A lying pet is drawn wider than tall; at the same canvas scale it reads as bigger. The factor makes the sleep clip's width at most
1.15x the idle clip's width (never above 1, never below 0.7). Re-run after changing sleep or idle art and paste into SpritePet.swift.
"""
import glob, os, sys
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def width(files):
    ws = []
    for f in files[:10]:
        a = np.array(Image.open(f).convert('RGBA'))[:, :, 3] > 20
        xs = np.where(a.any(axis=0))[0]
        ws.append(xs.max() - xs.min())
    return float(np.mean(ws))

for species in sorted(os.listdir(f'{ROOT}/Resources/Pets')):
    for stage in ('hatchling', 'child', 'teen', 'adult'):
        d = f'{ROOT}/Resources/Pets/{species}/{stage}/anim'
        idle, sleep = sorted(glob.glob(f'{d}/idle_*.png')), sorted(glob.glob(f'{d}/sleep_*.png'))
        if not idle or not sleep: continue
        factor = max(0.7, min(1.0, 1.15 * width(idle) / width(sleep)))
        print(f'        "{species}/{stage}": {factor:.2f},')
