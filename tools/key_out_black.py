"""Make a solid black background transparent.

OpenArt sometimes exports objects on pure black instead of true transparency.
We assume the foreground subject has no near-black pixels (Train Cosy objects
are warm browns / creams), so we can safely key out everything below a
brightness threshold and softly fade pixels near it for clean edges.

Usage:
    python3 tools/key_out_black.py assets/objects/bed.png
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image


# Pixels darker than HARD are fully transparent.
# Pixels brighter than SOFT keep full alpha.
# Between the two we linearly interpolate alpha for anti-aliased edges.
HARD = 18
SOFT = 60


def key_out(path: Path) -> None:
    img = Image.open(path).convert("RGB")
    w, h = img.size
    rgb = img.load()

    out = Image.new("RGBA", (w, h))
    out_pixels = out.load()

    for y in range(h):
        for x in range(w):
            r, g, b = rgb[x, y]
            brightness = max(r, g, b)
            if brightness <= HARD:
                out_pixels[x, y] = (0, 0, 0, 0)
            elif brightness >= SOFT:
                out_pixels[x, y] = (r, g, b, 255)
            else:
                alpha = int(255 * (brightness - HARD) / (SOFT - HARD))
                out_pixels[x, y] = (r, g, b, alpha)

    out.save(path, format="PNG", optimize=True)
    print(f"  {path.name}: keyed out black background")


def main(argv: list[str]) -> None:
    if len(argv) < 2:
        print("usage: key_out_black.py <png> [<png> ...]", file=sys.stderr)
        raise SystemExit(2)
    for raw in argv[1:]:
        key_out(Path(raw))


if __name__ == "__main__":
    main(sys.argv)
