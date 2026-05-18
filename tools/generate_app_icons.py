"""Resize assets/icon/app_icon.png into every iOS AppIcon.appiconset slot.

Replaces flutter_launcher_icons for this project — Apple's strict size list
is small and stable, and shelling out to a Flutter tool from CI is more
moving parts than it's worth. Re-run after dropping a new 1024x1024 source.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "icon" / "app_icon.png"
APPICON_DIR = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"

# Filename → pixel side length. iOS rejects icons with alpha, so the source
# must be RGB (we verify below).
TARGETS: dict[str, int] = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}


def main() -> None:
    if not SOURCE.exists():
        raise SystemExit(f"Source icon missing: {SOURCE}")

    img = Image.open(SOURCE)
    if img.mode != "RGB":
        # Flatten alpha onto black if needed — iOS rejects any alpha channel.
        background = Image.new("RGB", img.size, (0, 0, 0))
        if img.mode == "RGBA":
            background.paste(img, mask=img.split()[3])
        else:
            background.paste(img.convert("RGB"))
        img = background

    if img.size != (1024, 1024):
        # Square out non-1024 sources first, then everything resizes cleanly.
        img = img.resize((1024, 1024), Image.LANCZOS)

    APPICON_DIR.mkdir(parents=True, exist_ok=True)
    for filename, size in TARGETS.items():
        resized = img.resize((size, size), Image.LANCZOS)
        out = APPICON_DIR / filename
        resized.save(out, format="PNG", optimize=True)
        print(f"  wrote {filename} ({size}x{size})")


if __name__ == "__main__":
    main()
