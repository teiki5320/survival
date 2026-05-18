"""Punch the rear-window glass area out of the wagon backgrounds.

OpenArt baked zombies + fog into the window of each wagon. To get a real
scrolling landscape behind the wagon, we need the window area to be
transparent in the PNG so the layer behind shows through.

This script reads the windowArea defined in assets/config/scene.json,
applies it (with rounded corners + a feathered alpha gradient on the
edges so the cut blends into the wagon's window frame), and rewrites
wagon_day.png / wagon_night.png in-place.

Re-running is safe — the operation is idempotent on already-cut areas.
"""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
SCENE = ROOT / "assets" / "config" / "scene.json"
BG_DIR = ROOT / "assets" / "background"

# Inset and feather amount in pixels — relative to the cut rectangle.
# Inset shrinks the hole slightly inward so we don't bite into the frame.
INSET_PX = 6
FEATHER_PX = 14
CORNER_RADIUS_PX = 28


def punch_window(image_path: Path, rect_normalized: dict[str, float]) -> None:
    img = Image.open(image_path).convert("RGBA")
    w, h = img.size

    left = int(rect_normalized["x"] * w) + INSET_PX
    top = int(rect_normalized["y"] * h) + INSET_PX
    right = int((rect_normalized["x"] + rect_normalized["width"]) * w) - INSET_PX
    bottom = int((rect_normalized["y"] + rect_normalized["height"]) * h) - INSET_PX

    # Build a soft mask: white inside the window (= keep removing alpha),
    # black outside, with feathered edges.
    mask = Image.new("L", img.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle(
        [(left, top), (right, bottom)],
        radius=CORNER_RADIUS_PX,
        fill=255,
    )
    mask = mask.filter(ImageFilter.GaussianBlur(radius=FEATHER_PX))

    # Apply: subtract mask from existing alpha so we only ever REDUCE opacity.
    r, g, b, a = img.split()
    new_alpha_pixels = a.load()
    mask_pixels = mask.load()
    for y in range(h):
        for x in range(w):
            current = new_alpha_pixels[x, y]
            remove = mask_pixels[x, y]
            new_alpha_pixels[x, y] = max(0, current - remove)
    img.putalpha(a)
    img.save(image_path, format="PNG", optimize=True)
    print(f"  punched {image_path.name}")


def main() -> None:
    scene = json.loads(SCENE.read_text())
    rect = scene["windowArea"]
    for name in ("wagon_day.png", "wagon_night.png"):
        punch_window(BG_DIR / name, rect)


if __name__ == "__main__":
    main()
