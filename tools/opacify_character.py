"""Force character PNG pixels to fully opaque or fully transparent.

After `key_out_black.py`, the heroine's PNG keeps a non-trivial fraction
of pixels at partial alpha (the brightness anti-aliasing band 18-60). On
top of a busy wagon background this reads as the character being
*translucent* — you can see the bed and lantern through her body and hair.

This script binarises alpha around a threshold: any pixel with
alpha > THRESHOLD becomes fully opaque, anything below becomes fully
transparent. Edges lose a bit of softness but the heroine reads as a
solid presence in the wagon, not a ghost.

Usage:
    python3 tools/opacify_character.py assets/characters/*.png
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image


THRESHOLD = 64  # pixels with alpha > 64 become fully opaque


def opacify(path: Path) -> None:
    img = Image.open(path).convert("RGBA")
    pixels = img.load()
    w, h = img.size
    changed = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if a == 0 or a == 255:
                continue
            new_a = 255 if a > THRESHOLD else 0
            pixels[x, y] = (r, g, b, new_a)
            changed += 1
    img.save(path, format="PNG", optimize=True)
    print(f"  {path.name}: hardened {changed} semi-transparent pixels")


def main(argv: list[str]) -> None:
    if len(argv) < 2:
        print("usage: opacify_character.py <png> [<png> ...]", file=sys.stderr)
        raise SystemExit(2)
    for raw in argv[1:]:
        opacify(Path(raw))


if __name__ == "__main__":
    main(sys.argv)
