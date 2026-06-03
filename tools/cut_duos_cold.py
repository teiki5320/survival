#!/usr/bin/env python3
"""Découpe les nouvelles sheets (duos sœur, chien, froid) + détoure le vert."""
import numpy as np
from PIL import Image
import os

os.makedirs("assets/characters", exist_ok=True)


def key_green(rgb, t_low=34.0, t_high=115.0):
    arr = rgb.astype(np.int16)
    r, g, b = arr[..., 0], arr[..., 1], arr[..., 2]
    greenness = g - np.maximum(r, b)
    alpha = np.clip(1.0 - (greenness - t_low) / (t_high - t_low), 0.0, 1.0)
    out = arr.copy()
    out[..., 1] = np.minimum(g, np.maximum(r, b))  # despill
    return np.dstack([out[..., 0].astype(np.uint8), out[..., 1].astype(np.uint8),
                      out[..., 2].astype(np.uint8), (alpha * 255).astype(np.uint8)])


def cut(path, cols, rows, prefix):
    im = np.asarray(Image.open(path).convert("RGB"))
    H, W = im.shape[:2]
    cw, ch = W // cols, H // rows
    i = 0
    for r in range(rows):
        for c in range(cols):
            i += 1
            cell = im[r*ch:(r+1)*ch, c*cw:(c+1)*cw]
            out = f"assets/characters/{prefix}_{i}.png"
            Image.fromarray(key_green(cell), "RGBA").save(out)
            print(out)


cut("IMG_4951.png", 6, 1, "hugduo")        # câlin Shen+sœur
cut("IMG_4952.png", 5, 2, "readduo")       # lecture Shen+sœur
cut("IMG_4953.jpeg", 4, 2, "petdog")       # Shen + husky
cut("IMG_4954.png", 8, 1, "sister_cold")   # sœur a froid
cut("IMG_4955.png", 8, 1, "cold")          # Shen a froid
print("OK")
