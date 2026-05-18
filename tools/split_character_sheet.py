"""Split a horizontal character sheet into N panels and key out the black background.

OpenArt delivers our 3-pose sheets at 1376x768 with the panels split equally
in 3 horizontal cells, separated only by thin neutral lines. This script
cuts each cell, keys out the black background (same brightness threshold the
bed uses), and writes one RGBA PNG per pose.

Usage:
    python3 tools/split_character_sheet.py <input.png> <out_dir> <pose1,pose2,pose3>
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image


# Same chroma-key thresholds as tools/key_out_black.py — characters and the
# bed share the same warm palette so the same cut-off works.
HARD = 18
SOFT = 60


def key_out_black(img: Image.Image) -> Image.Image:
    img = img.convert("RGB")
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
    return out


def split_sheet(sheet_path: Path, out_dir: Path, names: list[str]) -> None:
    sheet = Image.open(sheet_path)
    w, h = sheet.size
    n = len(names)
    cell_w = w // n
    out_dir.mkdir(parents=True, exist_ok=True)
    for i, name in enumerate(names):
        left = i * cell_w
        right = left + cell_w if i < n - 1 else w
        cell = sheet.crop((left, 0, right, h))
        keyed = key_out_black(cell)
        out = out_dir / f"{name}.png"
        keyed.save(out, format="PNG", optimize=True)
        print(f"  wrote {out} ({cell.size[0]}x{cell.size[1]})")


def main(argv: list[str]) -> None:
    if len(argv) != 4:
        print(
            "usage: split_character_sheet.py <input.png> <out_dir> <pose1,pose2,pose3>",
            file=sys.stderr,
        )
        raise SystemExit(2)
    sheet_path = Path(argv[1])
    out_dir = Path(argv[2])
    names = argv[3].split(",")
    split_sheet(sheet_path, out_dir, names)


if __name__ == "__main__":
    main(sys.argv)
