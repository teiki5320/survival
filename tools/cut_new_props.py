#!/usr/bin/env python3
"""Découpe + détourage des nouveaux objets/anims (carillon, tourne-disque,
panier-chien, jeu-soeur, fauteuil). Sources dans IN, sorties dans assets/."""
import os
import numpy as np
from PIL import Image, ImageDraw

IN = os.environ["IN"]
os.makedirs("assets/objects", exist_ok=True)
os.makedirs("assets/characters", exist_ok=True)


# ---------- key-out vert (repris de cut_duos_cold) ----------
def key_green(rgb, t_low=34.0, t_high=115.0):
    arr = rgb.astype(np.int16)
    r, g, b = arr[..., 0], arr[..., 1], arr[..., 2]
    greenness = g - np.maximum(r, b)
    alpha = np.clip(1.0 - (greenness - t_low) / (t_high - t_low), 0.0, 1.0)
    out = arr.copy()
    out[..., 1] = np.minimum(g, np.maximum(r, b))  # despill
    return np.dstack([out[..., 0].astype(np.uint8), out[..., 1].astype(np.uint8),
                      out[..., 2].astype(np.uint8), (alpha * 255).astype(np.uint8)])


def trim(rgba):
    a = rgba[..., 3] > 16
    if not a.any():
        return rgba
    ys, xs = np.where(a)
    return rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


# ---------- key-out blanc (floodfill depuis les coins) ----------
def key_white(path, thresh=42):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    for c in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        ImageDraw.floodfill(im, c, (255, 0, 255), thresh=thresh)
    arr = np.asarray(im)
    bg = (arr[..., 0] == 255) & (arr[..., 1] == 0) & (arr[..., 2] == 255)
    rgba = np.dstack([arr[..., 0], arr[..., 1], arr[..., 2],
                      np.where(bg, 0, 255).astype(np.uint8)])
    return trim(rgba)


def save(rgba, path):
    Image.fromarray(rgba, "RGBA").save(path)
    print(f"  {path}  {rgba.shape[1]}x{rgba.shape[0]}")


# ---------- découpe grille verte, inset pour virer les lignes rouges ----------
def cut_green(path, cols, rows, prefix, dst="characters",
              crop_bottom=0.0, keep=None, inset=6):
    im = np.asarray(Image.open(path).convert("RGB"))
    H, W = im.shape[:2]
    cw, ch = W // cols, H // rows
    idx = 0
    out_i = 0
    for r in range(rows):
        for c in range(cols):
            idx += 1
            if keep is not None and idx not in keep:
                continue
            out_i += 1
            y0, y1 = r * ch + inset, (r + 1) * ch - inset
            x0, x1 = c * cw + inset, (c + 1) * cw - inset
            cell = im[y0:y1, x0:x1]
            if crop_bottom > 0:  # vire la bande de texte sous la frame
                cell = cell[:int(cell.shape[0] * (1 - crop_bottom))]
            rgba = trim(key_green(cell))
            save(rgba, f"assets/{dst}/{prefix}_{out_i}.png")
    return out_i


# ---------- carillon : sheet AutoSprite transparente, grille auto ----------
def cut_carillon(path, prefix="carillon"):
    im = np.asarray(Image.open(path).convert("RGBA"))
    a = im[..., 3] > 24
    col_on = a.any(axis=0)
    row_on = a.any(axis=1)

    def runs(mask):
        out, s = [], None
        for i, v in enumerate(mask):
            if v and s is None:
                s = i
            elif not v and s is not None:
                out.append((s, i)); s = None
        if s is not None:
            out.append((s, len(mask)))
        return [(a, b) for a, b in out if b - a > 12]  # ignore le bruit

    cbands = runs(col_on)
    rbands = runs(row_on)
    print(f"  carillon: {len(rbands)} rangées x {len(cbands)} colonnes detectees")
    frames = []
    for (y0, y1) in rbands:
        for (x0, x1) in cbands:
            sub = im[y0:y1, x0:x1]
            if (sub[..., 3] > 24).sum() > 200:
                frames.append(trim(sub))
    # canvas uniforme, ancré HAUT-centre (objet suspendu)
    mw = max(f.shape[1] for f in frames)
    mh = max(f.shape[0] for f in frames)
    for i, f in enumerate(frames, 1):
        canvas = np.zeros((mh, mw, 4), np.uint8)
        x = (mw - f.shape[1]) // 2
        canvas[0:f.shape[0], x:x + f.shape[1]] = f  # haut-centre
        save(canvas, f"assets/objects/{prefix}_{i}.png")
    return len(frames)


print("== statiques (key blanc) ==")
save(key_white(f"{IN}/openart-image_1782725356495_aef25de2_1782725356544_a3597ec0.png"),
     "assets/objects/tourne_disque.png")
save(key_white(f"{IN}/openart-image_1782725404462_ad7b0007_1782725404508_1888b596.png"),
     "assets/objects/carillon_static.png")

print("== jeu duo soeur (2x5 = 10) ==")
n = cut_green(f"{IN}/openart-image_1782726274800_580e41fe_1782726274943_0669d196.png",
              5, 2, "playduo")
print(f"  -> {n} frames")

print("== panier chien (2x4 = 8, crop labels texte) ==")
n = cut_green(f"{IN}/openart-image_1782726158558_0e80639a_1782726158785_ce37e171.png",
              4, 2, "dog_basket", crop_bottom=0.26)
print(f"  -> {n} frames")

print("== fauteuil (3x6 = 18, garde la rangee 1 = cadrage constant) ==")
n = cut_green(f"{IN}/openart-image_1782726571219_b1825329_1782726571333_e11bcd29.png",
              6, 3, "chair_read", keep={1, 2, 3, 4, 5, 6})
print(f"  -> {n} frames")

print("== carillon anime ==")
n = cut_carillon(f"{IN}/Carillon-spritesheet.png")
print(f"  -> {n} frames")
print("OK")
