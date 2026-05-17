"""Generate placeholder PNG assets for the Train Cosy app.

The app expects a 2:3 portrait wagon background and a handful of transparent
PNG objects. These placeholders let the project run end-to-end before real art
is dropped in — replace the files in assets/background and assets/objects
without touching the code.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
BG_DIR = ROOT / "assets" / "background"
OBJ_DIR = ROOT / "assets" / "objects"

WAGON_SIZE = (1000, 1500)  # 2:3 portrait
OBJECT_SIZE = (400, 400)


def _load_font(size: int) -> ImageFont.ImageFont:
    for candidate in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ):
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size)
    return ImageFont.load_default()


def make_wagon_background() -> None:
    img = Image.new("RGBA", WAGON_SIZE, (40, 32, 28, 255))
    draw = ImageDraw.Draw(img)

    # Floor
    floor_top = int(WAGON_SIZE[1] * 0.72)
    draw.rectangle(
        [(0, floor_top), (WAGON_SIZE[0], WAGON_SIZE[1])],
        fill=(90, 60, 40, 255),
    )
    # Floor planks
    for x in range(0, WAGON_SIZE[0], 80):
        draw.line(
            [(x, floor_top), (x, WAGON_SIZE[1])],
            fill=(60, 40, 28, 255),
            width=2,
        )

    # Back wall window
    win_top = int(WAGON_SIZE[1] * 0.15)
    win_bot = int(WAGON_SIZE[1] * 0.55)
    win_left = int(WAGON_SIZE[0] * 0.15)
    win_right = int(WAGON_SIZE[0] * 0.85)
    draw.rectangle(
        [(win_left, win_top), (win_right, win_bot)],
        fill=(120, 150, 180, 255),
        outline=(30, 25, 20, 255),
        width=6,
    )
    # Window cross
    mid_x = (win_left + win_right) // 2
    mid_y = (win_top + win_bot) // 2
    draw.line([(mid_x, win_top), (mid_x, win_bot)], fill=(30, 25, 20, 255), width=6)
    draw.line([(win_left, mid_y), (win_right, mid_y)], fill=(30, 25, 20, 255), width=6)

    # Side wall hint
    draw.line(
        [(0, floor_top), (WAGON_SIZE[0], floor_top)],
        fill=(20, 15, 12, 255),
        width=4,
    )

    font = _load_font(36)
    draw.text(
        (WAGON_SIZE[0] // 2, WAGON_SIZE[1] - 60),
        "PLACEHOLDER WAGON",
        font=font,
        fill=(220, 220, 220, 200),
        anchor="mm",
    )

    BG_DIR.mkdir(parents=True, exist_ok=True)
    img.save(BG_DIR / "wagon.png")


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
    make_wagon_background()
    make_object("bed", (180, 120, 140))
    make_object("lamp", (245, 220, 130))
    make_object("plant", (110, 170, 110))
    make_object("plaid", (170, 130, 90))
    print("Placeholders written to", BG_DIR, "and", OBJ_DIR)


if __name__ == "__main__":
    main()
