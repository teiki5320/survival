#!/usr/bin/env python3
"""Traite les assets de la petite soeur :
- Dance/ et Walk/ : deja detoures -> copie/renomme en sister_dance_N / sister_walk_N
- IMG_4934/35/36/37 : sheets 4x2 (8 frames), fond blanc -> decoupe + detourage
  par flood-fill depuis les bords (preserve le pyjama clair), pad carre, 512.
"""
import os, glob
from collections import deque
from PIL import Image

OUT = "assets/characters"
os.makedirs(OUT, exist_ok=True)

# --- 1. Dance / Walk : deja detoures, juste renommer en 1-indexe non-padde ---
def copy_seq(src_dir, anim):
    files = sorted(glob.glob(f"{src_dir}/[0-9]*.png"))
    for i, fn in enumerate(files, start=1):
        im = Image.open(fn).convert("RGBA")
        im.save(f"{OUT}/sister_{anim}_{i}.png")
    print(f"{anim}: {len(files)} frames")

copy_seq("Dance", "dance")
copy_seq("Walk", "walk")

# --- 2. Sheets fond blanc : flood-fill bg -> transparent ---
def flood_remove_white(im, thr=238):
    """Rend transparent le fond blanc CONNECTE aux bords (BFS)."""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    seen = bytearray(w * h)
    dq = deque()
    def is_bg(x, y):
        r, g, b, a = px[x, y]
        return min(r, g, b) >= thr
    # graines : tout le pourtour
    for x in range(w):
        for y in (0, h - 1):
            if not seen[y * w + x] and is_bg(x, y):
                seen[y * w + x] = 1; dq.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if not seen[y * w + x] and is_bg(x, y):
                seen[y * w + x] = 1; dq.append((x, y))
    while dq:
        x, y = dq.popleft()
        px[x, y] = (255, 255, 255, 0)
        for nx, ny in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
            if 0 <= nx < w and 0 <= ny < h and not seen[ny*w+nx] and is_bg(nx, ny):
                seen[ny*w+nx] = 1; dq.append((nx, ny))
    return im

def to_square(im, side=512):
    """Pad transparent en carre, contenu centre horizontalement et colle en bas."""
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    w, h = im.size
    s = max(w, h)
    canvas = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    # centre horizontal, bas aligne (pieds en bas) avec une petite marge
    margin = int(s * 0.04)
    x = (s - w) // 2
    y = s - h - margin
    canvas.paste(im, (x, max(0, y)))
    return canvas.resize((side, side), Image.LANCZOS)

def cut_sheet(path, anim, cols=4, rows=2):
    sheet = Image.open(path).convert("RGBA")
    W, H = sheet.size
    cw, ch = W // cols, H // rows
    n = 0
    for r in range(rows):
        for c in range(cols):
            n += 1
            cell = sheet.crop((c*cw, r*ch, (c+1)*cw, (r+1)*ch))
            cell = flood_remove_white(cell)
            cell = to_square(cell, 512)
            cell.save(f"{OUT}/sister_{anim}_{n}.png")
    print(f"{anim}: {n} frames depuis {os.path.basename(path)}")

cut_sheet("IMG_4934.png", "pet_dog")   # soeur caresse le chien
cut_sheet("IMG_4936.png", "hug_dog")   # soeur caline le chien
cut_sheet("IMG_4935.png", "read")      # Shen + soeur lisent
cut_sheet("IMG_4937.png", "hug")       # Shen + soeur s'enlacent
print("OK")
