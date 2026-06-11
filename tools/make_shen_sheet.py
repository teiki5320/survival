#!/usr/bin/env python3
"""Planche-contact de toutes les frames des animations de Shen UTILISEES.
Chaque animation = un bloc (titre + grille de frames qui s'enroule).
Sortie : docs/shen_anims.png
"""
import glob
import os
import re
from PIL import Image, ImageDraw, ImageFont

CHAR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'characters')
OUT = os.path.join(os.path.dirname(__file__), '..', 'docs', 'shen_anims.png')

# Animations de Shen reellement cablees (solo + duo + portrait).
ANIMS = [
    'idle_right', 'walk_right', 'carry_walk', 'sleep_right', 'wake_up',
    'yawn', 'stretch', 'dance', 'pickup', 'read', 'drink', 'eat',
    'warm_hands', 'cold', 'use_back', 'open_door', 'bath', 'shower',
    'petdog', 'readduo', 'heroine_front',
]

CELL_W = 96           # largeur d'une cellule
CELL_H = 92           # hauteur d'une cellule (= hauteur frame)
PER_ROW = 24          # frames par ligne avant retour
HEADER_H = 40         # bandeau titre par animation
PAD = 16              # marge autour d'un bloc
MARGIN = 24           # marge globale
BG = (26, 30, 38)
HEAD_BG = (44, 50, 62)
TXT = (255, 217, 160)
SUB = (160, 148, 126)


def frames_for(name):
    if name == 'heroine_front':
        p = os.path.join(CHAR, 'heroine_front.png')
        return [p] if os.path.exists(p) else []
    fs = glob.glob(os.path.join(CHAR, f'{name}_*.png'))
    def num(p):
        m = re.search(rf'{name}_(\d+)\.png$', p)
        return int(m.group(1)) if m else 0
    return sorted(fs, key=num)


def load_font(size, bold=True):
    names = ['DejaVuSans-Bold.ttf'] if bold else ['DejaVuSans.ttf']
    for nm in names:
        fp = f'/usr/share/fonts/truetype/dejavu/{nm}'
        if os.path.exists(fp):
            return ImageFont.truetype(fp, size)
    return ImageFont.load_default()


def main():
    blocks = []
    for name in ANIMS:
        fs = frames_for(name)
        if not fs:
            print('skip:', name)
            continue
        thumbs = []
        for f in fs:
            im = Image.open(f).convert('RGBA')
            w = max(1, int(im.width * CELL_H / im.height))
            w = min(w, CELL_W)
            thumbs.append(im.resize((w, int(im.height * w / im.width)),
                                    Image.LANCZOS))
        blocks.append((name, thumbs))

    grid_w = PER_ROW * CELL_W
    block_w = grid_w + PAD * 2
    sheet_w = block_w + MARGIN * 2

    # hauteur totale
    total_h = MARGIN
    for name, thumbs in blocks:
        n_rows = (len(thumbs) + PER_ROW - 1) // PER_ROW
        total_h += HEADER_H + n_rows * CELL_H + PAD * 2 + MARGIN

    sheet = Image.new('RGBA', (sheet_w, total_h), BG + (255,))
    draw = ImageDraw.Draw(sheet)
    f_title = load_font(24)
    f_sub = load_font(16, bold=False)
    f_idx = load_font(11, bold=False)

    y = MARGIN
    for name, thumbs in blocks:
        n = len(thumbs)
        n_rows = (n + PER_ROW - 1) // PER_ROW
        bh = HEADER_H + n_rows * CELL_H + PAD * 2
        # bandeau titre
        draw.rectangle([MARGIN, y, MARGIN + block_w, y + HEADER_H],
                       fill=HEAD_BG + (255,))
        draw.text((MARGIN + 14, y + 8), name, font=f_title, fill=TXT)
        tw = draw.textlength(f'{n} frames', font=f_sub)
        draw.text((MARGIN + block_w - tw - 14, y + 12), f'{n} frames',
                  font=f_sub, fill=SUB)
        # grille
        gx0 = MARGIN + PAD
        gy0 = y + HEADER_H + PAD
        for i, t in enumerate(thumbs):
            r, c = divmod(i, PER_ROW)
            cx = gx0 + c * CELL_W
            cy = gy0 + r * CELL_H
            # bottom-center dans la cellule
            px = cx + (CELL_W - t.width) // 2
            py = cy + (CELL_H - t.height)
            sheet.alpha_composite(t, (px, max(cy, py)))
            draw.text((cx + 2, cy + 1), str(i + 1), font=f_idx,
                      fill=(110, 120, 135))
        y += bh + MARGIN

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sheet.convert('RGB').save(OUT, 'PNG')
    print('OK ->', OUT, sheet.size, f'({len(blocks)} animations)')


if __name__ == '__main__':
    main()
