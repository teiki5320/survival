"""Crop the leftover divider strip from each character panel.

The 3-pose sprite sheet has thin grey dividers between panels. The original
split happened at the cell boundaries, so panels touching a divider kept a
3-6 px strip of grey along that edge — visible as a faint white outline
once the character is rendered in the wagon. This pass simply crops a
margin off the divider side(s) of each panel.

Run once after split_character_sheet.py; rerunning is safe but lossy.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
CHAR_DIR = ROOT / "assets" / "characters"

TRIM_PX = 10

# Per-file: which edges to trim (the side that touched a divider in the sheet).
# Panels 0 had divider on right; panel 1 on both; panel 2 on left.
EDGES: dict[str, tuple[bool, bool]] = {
    # (trim_left, trim_right)
    "standing_idle.png":    (False, True),
    "standing_turned.png":  (True, True),
    "standing_stretch.png": (True, False),
    "sitting_cross.png":    (False, True),
    "sitting_hugged.png":   (True, True),
    "sitting_side.png":     (True, False),
}


def main() -> None:
    for name, (trim_left, trim_right) in EDGES.items():
        path = CHAR_DIR / name
        img = Image.open(path)
        w, h = img.size
        left = TRIM_PX if trim_left else 0
        right = w - TRIM_PX if trim_right else w
        cropped = img.crop((left, 0, right, h))
        cropped.save(path, format="PNG", optimize=True)
        print(f"  {name}: cropped to {cropped.size[0]}x{cropped.size[1]} "
              f"(trim L={trim_left} R={trim_right})")


if __name__ == "__main__":
    main()
