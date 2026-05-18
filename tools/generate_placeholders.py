"""Generate placeholder PNGs for objects that don't yet have real art.

The wagon backgrounds and the bed are now real AI-generated assets; this
script only fills the gaps for lamp, plant, and plaid. Run it manually
when you reset those slots to fresh placeholders.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OBJ_DIR = ROOT / "assets" / "objects"

OBJECT_SIZE = (400, 400)


def _load_font(size: int) -> ImageFont.ImageFont:
    for candidate in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ):
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size)
    return ImageFont.load_default()


def make_object(name: str, color: tuple[int, int, int]) -> None:
    img = Image.new("RGBA", OBJECT_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    margin = 20
    draw.rounded_rectangle(
        [(margin, margin), (OBJECT_SIZE[0] - margin, OBJECT_SIZE[1] - margin)],
        radius=24,
        fill=color + (230,),
        outline=(20, 20, 20, 255),
        width=6,
    )
    font = _load_font(48)
    draw.text(
        (OBJECT_SIZE[0] // 2, OBJECT_SIZE[1] // 2),
        name,
        font=font,
        fill=(20, 20, 20, 255),
        anchor="mm",
    )
    OBJ_DIR.mkdir(parents=True, exist_ok=True)
    img.save(OBJ_DIR / f"{name}.png")


def main() -> None:
    make_object("lamp", (245, 220, 130))
    make_object("plant", (110, 170, 110))
    make_object("plaid", (170, 130, 90))
    print("Placeholders written to", OBJ_DIR)


if __name__ == "__main__":
    main()
