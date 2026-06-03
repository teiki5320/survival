#!/usr/bin/env python3
"""Chroma-key green (#00FF00) -> transparence.

Usage: python3 tools/key_out_green.py in.png out.png [t_low] [t_high]

"Greenness" = g - max(r, b). Les pixels très verts (fenêtres + extérieur)
deviennent transparents ; bord adouci entre t_low et t_high. Despill léger
pour retirer le halo vert sur les contours.
"""
import sys
import numpy as np
from PIL import Image


def main():
    src, dst = sys.argv[1], sys.argv[2]
    t_low = float(sys.argv[3]) if len(sys.argv) > 3 else 30.0
    t_high = float(sys.argv[4]) if len(sys.argv) > 4 else 110.0

    img = Image.open(src).convert("RGB")
    arr = img.numpy() if hasattr(img, "numpy") else np.asarray(img)
    arr = arr.astype(np.int16)
    r, g, b = arr[..., 0], arr[..., 1], arr[..., 2]

    greenness = g - np.maximum(r, b)
    # alpha : 1 si peu vert (<=t_low), 0 si très vert (>=t_high), lin. entre.
    alpha = 1.0 - (greenness - t_low) / (t_high - t_low)
    alpha = np.clip(alpha, 0.0, 1.0)

    # Despill : sur les pixels gardés, clamp g a max(r,b) pour tuer le halo.
    out = arr.copy()
    g_clamped = np.minimum(g, np.maximum(r, b))
    out[..., 1] = g_clamped

    rgba = np.dstack([
        out[..., 0].astype(np.uint8),
        out[..., 1].astype(np.uint8),
        out[..., 2].astype(np.uint8),
        (alpha * 255).astype(np.uint8),
    ])
    Image.fromarray(rgba, "RGBA").save(dst)
    kept = (alpha > 0.5).sum()
    print(f"{dst}: {arr.shape[1]}x{arr.shape[0]}, {kept} px opaques "
          f"({100*kept/alpha.size:.0f}%)")


if __name__ == "__main__":
    main()
