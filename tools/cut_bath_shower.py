#!/usr/bin/env python3
"""Découpe les sprite sheets bain/douche/pommeau + détoure le vert."""
import numpy as np
from PIL import Image
import os

os.makedirs("assets/characters", exist_ok=True)
os.makedirs("assets/objects", exist_ok=True)


def key_green(rgb, t_low=34.0, t_high=115.0):
    """rgb uint8 HxWx3 -> rgba uint8 (vert -> transparent + despill)."""
    arr = rgb.astype(np.int16)
    r, g, b = arr[..., 0], arr[..., 1], arr[..., 2]
    greenness = g - np.maximum(r, b)
    alpha = np.clip(1.0 - (greenness - t_low) / (t_high - t_low), 0.0, 1.0)
    out = arr.copy()
    out[..., 1] = np.minimum(g, np.maximum(r, b))  # despill
    return np.dstack([
        out[..., 0].astype(np.uint8),
        out[..., 1].astype(np.uint8),
        out[..., 2].astype(np.uint8),
        (alpha * 255).astype(np.uint8),
    ])


def cells(path, cols, rows):
    im = np.asarray(Image.open(path).convert("RGB"))
    H, W = im.shape[:2]
    cw, ch = W // cols, H // rows
    out = []
    for r in range(rows):
        for c in range(cols):
            out.append(im[r*ch:(r+1)*ch, c*cw:(c+1)*cw])
    return out


def save(rgba, path):
    Image.fromarray(rgba, "RGBA").save(path)
    print(path)


# Pommeau eau : 6 frames horizontales
for i, cell in enumerate(cells("IMG_4946.jpeg", 6, 1), 1):
    save(key_green(cell), f"assets/objects/showerhead_{i}.png")

# Douche Shen : 8 frames horizontales
for i, cell in enumerate(cells("IMG_4950.png", 8, 1), 1):
    save(key_green(cell), f"assets/characters/shower_{i}.png")

# Bain Shen : grille 4x2 = 8 frames (row-major : entrée puis détente)
for i, cell in enumerate(cells("IMG_4949.png", 4, 2), 1):
    save(key_green(cell), f"assets/characters/bath_{i}.png")

# Stills
for src, dst in [("IMG_4947.jpeg", "assets/objects/shower_panel.png"),
                 ("IMG_4948.png",  "assets/objects/bathtub.png")]:
    im = np.asarray(Image.open(src).convert("RGB"))
    save(key_green(im), dst)

print("OK")
