#!/usr/bin/env python3
"""Re-découpe propre des sheets IA qui dérivent : par cellule, détoure le vert,
supprime les fragments de bleed (composantes connexes), recadre sur le contenu
et recolle bottom-center dans un canevas uniforme (anti-jitter)."""
import numpy as np
from PIL import Image
from scipy import ndimage


def key_green(rgb, t_low=34.0, t_high=115.0):
    arr = rgb.astype(np.int16)
    r, g, b = arr[..., 0], arr[..., 1], arr[..., 2]
    greenness = g - np.maximum(r, b)
    alpha = np.clip(1.0 - (greenness - t_low) / (t_high - t_low), 0.0, 1.0)
    out = arr.copy()
    out[..., 1] = np.minimum(g, np.maximum(r, b))
    return np.dstack([out[..., 0].astype(np.uint8), out[..., 1].astype(np.uint8),
                      out[..., 2].astype(np.uint8), (alpha * 255).astype(np.uint8)])


def clean(cell_rgb, keep_frac=0.18):
    """rgba avec fragments de bleed supprimés ; renvoie (rgba, bbox)."""
    rgba = key_green(cell_rgb)
    a = rgba[..., 3] > 60
    lbl, n = ndimage.label(a)
    if n == 0:
        return rgba, None
    sizes = ndimage.sum(np.ones_like(lbl), lbl, range(1, n + 1))
    mx = sizes.max()
    keep = {i + 1 for i, s in enumerate(sizes) if s >= keep_frac * mx}
    mask = np.isin(lbl, list(keep))
    rgba[..., 3] = (rgba[..., 3] * mask).astype(np.uint8)
    ys, xs = np.where(mask)
    return rgba, (xs.min(), xs.max(), ys.min(), ys.max())


def process(path, cols, rows, prefix, rows_keep=None, keep_frac=0.18):
    im = np.asarray(Image.open(path).convert("RGB"))
    H, W = im.shape[:2]
    cw, ch = W // cols, H // rows
    frames, bboxes = [], []
    rngrows = rows_keep if rows_keep is not None else range(rows)
    for r in rngrows:
        for c in range(cols):
            cell = im[r*ch:(r+1)*ch, c*cw:(c+1)*cw]
            rgba, bb = clean(cell, keep_frac)
            frames.append((rgba, bb))
            if bb:
                bboxes.append(bb)
    # canevas uniforme = max largeur/hauteur de contenu + marge
    maxw = max(b[1]-b[0] for b in bboxes) + 12
    maxh = max(b[3]-b[2] for b in bboxes) + 12
    i = 0
    for rgba, bb in frames:
        i += 1
        canvas = np.zeros((maxh, maxw, 4), np.uint8)
        if bb:
            x0, x1, y0, y1 = bb
            crop = rgba[y0:y1+1, x0:x1+1]
            ch_, cw_ = crop.shape[:2]
            ox = (maxw - cw_) // 2          # centré horizontalement
            oy = maxh - ch_                  # collé en bas
            canvas[oy:oy+ch_, ox:ox+cw_] = crop
        Image.fromarray(canvas, "RGBA").save(f"assets/characters/{prefix}_{i}.png")
    print(f"{prefix}: {i} frames, canevas {maxw}x{maxh} (aspect {maxw/maxh:.3f})")


process("IMG_4951.png", 6, 1, "hugduo")              # câlin sœur (6)
process("IMG_4952.png", 5, 2, "readduo")             # lecture sœur (10)
# husky : câlin stable (rangée bas) ; persos collés -> garde la plus grosse
# composante pour virer le fragment du voisin.
process("IMG_4953.jpeg", 4, 2, "petdog", rows_keep=[1], keep_frac=0.6)
print("OK")
