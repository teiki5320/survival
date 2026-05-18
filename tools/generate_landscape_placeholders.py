"""Generate panoramic placeholder landscapes for the scrolling-window effect.

Two images, both 4×1 ratio (≈ wagon width × 4), wide enough to scroll for
~30 s before the loop point shows. Day = warm golden fog with bare-tree
silhouettes and a few distant zombie figures; Night = cold blue-black with
a moon and closer zombie silhouettes.

These are deliberately rough — drop a real AI panoramic landscape into
assets/background/landscape_day.png / landscape_night.png to replace them
without code changes.
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
BG_DIR = ROOT / "assets" / "background"

# 4× wider than the wagon's natural aspect (16:9) — leaves room for scrolling.
SIZE = (4096, 1000)


def _gradient_sky(palette_top: tuple[int, int, int],
                  palette_bottom: tuple[int, int, int]) -> Image.Image:
    img = Image.new("RGB", SIZE)
    pixels = img.load()
    for y in range(SIZE[1]):
        t = y / SIZE[1]
        r = int(palette_top[0] * (1 - t) + palette_bottom[0] * t)
        g = int(palette_top[1] * (1 - t) + palette_bottom[1] * t)
        b = int(palette_top[2] * (1 - t) + palette_bottom[2] * t)
        for x in range(SIZE[0]):
            pixels[x, y] = (r, g, b)
    return img


def _draw_silhouette_tree(draw: ImageDraw.ImageDraw, x: int, base_y: int,
                          height: int, color: tuple[int, int, int]) -> None:
    # Trunk
    trunk_w = max(2, height // 35)
    draw.rectangle(
        [(x - trunk_w // 2, base_y - height), (x + trunk_w // 2, base_y)],
        fill=color,
    )
    # A handful of angular branches
    rng = random.Random(x * 31 + height)
    for _ in range(4 + rng.randint(0, 3)):
        from_y = base_y - rng.randint(height // 2, height)
        dx = rng.randint(-height // 3, height // 3)
        dy = -rng.randint(height // 5, height // 2)
        draw.line(
            [(x, from_y), (x + dx, from_y + dy)],
            fill=color,
            width=max(1, trunk_w // 2),
        )


def _draw_zombie_silhouette(draw: ImageDraw.ImageDraw, x: int, base_y: int,
                            height: int, color: tuple[int, int, int]) -> None:
    head = height // 5
    body_w = head
    # Head
    draw.ellipse(
        [(x - head // 2, base_y - height),
         (x + head // 2, base_y - height + head)],
        fill=color,
    )
    # Body (slightly hunched)
    draw.rectangle(
        [(x - body_w // 2, base_y - height + head),
         (x + body_w // 2, base_y - height // 3)],
        fill=color,
    )
    # Legs
    draw.line(
        [(x - body_w // 3, base_y - height // 3), (x - body_w // 2, base_y)],
        fill=color, width=max(2, body_w // 3),
    )
    draw.line(
        [(x + body_w // 3, base_y - height // 3), (x + body_w // 4, base_y)],
        fill=color, width=max(2, body_w // 3),
    )
    # One arm raised slightly
    draw.line(
        [(x - body_w // 4, base_y - height + head),
         (x - body_w, base_y - height // 2)],
        fill=color, width=max(2, body_w // 4),
    )


def _draw_ruined_skyline(img: Image.Image,
                         baseline: int,
                         color: tuple[int, int, int]) -> None:
    rng = random.Random(7)
    draw = ImageDraw.Draw(img)
    x = 0
    while x < SIZE[0]:
        building_w = rng.randint(60, 220)
        building_h = rng.randint(40, 180)
        # Occasionally a "ruin" (jagged top)
        top = baseline - building_h
        draw.rectangle([(x, top), (x + building_w, baseline)], fill=color)
        if rng.random() < 0.5:
            jag = rng.randint(building_w // 6, building_w // 3)
            draw.polygon([
                (x + building_w // 2 - jag // 2, top),
                (x + building_w // 2 + jag // 2, top),
                (x + building_w // 2, top - rng.randint(10, 40)),
            ], fill=color)
        x += building_w + rng.randint(40, 160)


def _add_fog(img: Image.Image, color: tuple[int, int, int, int]) -> Image.Image:
    fog = Image.new("RGBA", img.size, color)
    img = img.convert("RGBA")
    return Image.alpha_composite(img, fog).convert("RGB")


def generate_day() -> None:
    img = _gradient_sky((221, 198, 168), (181, 165, 145))
    # Far ruined skyline
    _draw_ruined_skyline(img, baseline=int(SIZE[1] * 0.55),
                         color=(140, 130, 118))
    # Distant zombies (small)
    draw = ImageDraw.Draw(img)
    rng = random.Random(11)
    for _ in range(8):
        x = rng.randint(0, SIZE[0])
        base_y = int(SIZE[1] * 0.58) + rng.randint(-10, 10)
        h = rng.randint(40, 70)
        _draw_zombie_silhouette(draw, x, base_y, h, (120, 110, 100))
    # Midground dead trees
    for _ in range(20):
        x = rng.randint(0, SIZE[0])
        base_y = int(SIZE[1] * 0.85) + rng.randint(-20, 20)
        h = rng.randint(180, 320)
        _draw_silhouette_tree(draw, x, base_y, h, (60, 50, 45))
    # Foreground silhouette band (very dark)
    draw.rectangle([(0, int(SIZE[1] * 0.95)), (SIZE[0], SIZE[1])],
                   fill=(30, 25, 22))
    # Soft fog wash
    img = _add_fog(img, (220, 200, 175, 70))
    # Slight blur to soften everything
    img = img.filter(ImageFilter.GaussianBlur(radius=1.5))
    img.save(BG_DIR / "landscape_day.png", optimize=True)
    print("  wrote landscape_day.png")


def generate_night() -> None:
    img = _gradient_sky((22, 30, 55), (12, 18, 35))
    # Moon
    draw = ImageDraw.Draw(img)
    rng = random.Random(13)
    moon_x = SIZE[0] // 3
    moon_y = SIZE[1] // 4
    moon_r = 80
    draw.ellipse(
        [(moon_x - moon_r, moon_y - moon_r),
         (moon_x + moon_r, moon_y + moon_r)],
        fill=(220, 220, 235),
    )
    # Stars
    for _ in range(120):
        x = rng.randint(0, SIZE[0])
        y = rng.randint(0, int(SIZE[1] * 0.45))
        draw.ellipse([(x, y), (x + 2, y + 2)], fill=(220, 220, 240))
    # Far ruined skyline (darker)
    _draw_ruined_skyline(img, baseline=int(SIZE[1] * 0.58),
                         color=(15, 20, 35))
    # Closer zombies (bigger)
    for _ in range(14):
        x = rng.randint(0, SIZE[0])
        base_y = int(SIZE[1] * 0.85) + rng.randint(-20, 20)
        h = rng.randint(120, 200)
        _draw_zombie_silhouette(draw, x, base_y, h, (8, 12, 22))
    # Dead trees foreground
    for _ in range(15):
        x = rng.randint(0, SIZE[0])
        base_y = int(SIZE[1] * 0.92) + rng.randint(-15, 15)
        h = rng.randint(220, 380)
        _draw_silhouette_tree(draw, x, base_y, h, (5, 8, 18))
    draw.rectangle([(0, int(SIZE[1] * 0.96)), (SIZE[0], SIZE[1])],
                   fill=(2, 4, 10))
    # Cold fog
    img = _add_fog(img, (40, 60, 100, 50))
    img = img.filter(ImageFilter.GaussianBlur(radius=1.5))
    img.save(BG_DIR / "landscape_night.png", optimize=True)
    print("  wrote landscape_night.png")


def main() -> None:
    BG_DIR.mkdir(parents=True, exist_ok=True)
    generate_day()
    generate_night()


if __name__ == "__main__":
    main()
