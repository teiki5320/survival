"""Mesure les bounding boxes réelles (alpha > seuil) des sprites de chaque
animation et imprime la hauteur moyenne du perso dans le sprite, sa
largeur moyenne, et la position du "bas" du perso dans le sprite.

Utilisé pour calibrer le scaling de _buildHeroine dans
side_scroll_scene.dart et locomotive_scene.dart.
"""

from __future__ import annotations

import os
from collections import defaultdict
from PIL import Image

ASSETS = os.path.join(os.path.dirname(__file__), "..", "assets", "characters")
ALPHA_THRESHOLD = 16  # px à alpha < ce seuil = considérés transparents


def bbox(img: Image.Image) -> tuple[int, int, int, int] | None:
    """Retourne (l, t, r, b) du contenu non-transparent."""
    if img.mode != "RGBA":
        img = img.convert("RGBA")
    a = img.split()[-1]
    # binarise à ALPHA_THRESHOLD
    mask = a.point(lambda v: 255 if v >= ALPHA_THRESHOLD else 0)
    return mask.getbbox()


def main() -> None:
    # group files by animation prefix
    by_anim: dict[str, list[str]] = defaultdict(list)
    for name in os.listdir(ASSETS):
        if not name.endswith(".png"):
            continue
        # strip "_NN.png"
        base, _, idx = name.rpartition("_")
        if not idx.replace(".png", "").isdigit():
            continue
        by_anim[base].append(os.path.join(ASSETS, name))

    print(
        f"{'anim':<14} {'sheet WxH':<12} {'h_ratio':<8} {'w_ratio':<8} "
        f"{'feet_y_ratio':<12} {'top_y_ratio':<12}"
    )
    print("-" * 80)

    results: dict[str, dict] = {}
    for anim, paths in sorted(by_anim.items()):
        # sample ~5 frames spread across the anim to avoid loading all 49
        paths.sort()
        n = len(paths)
        sample_idx = [0, n // 4, n // 2, (3 * n) // 4, n - 1]
        sample_paths = [paths[i] for i in sample_idx]

        sheet_w = sheet_h = 0
        h_ratios = []
        w_ratios = []
        feet_ratios = []
        top_ratios = []
        for p in sample_paths:
            img = Image.open(p)
            sheet_w, sheet_h = img.size
            b = bbox(img)
            if b is None:
                continue
            l, t, r, btm = b
            char_h = btm - t
            char_w = r - l
            h_ratios.append(char_h / sheet_h)
            w_ratios.append(char_w / sheet_w)
            feet_ratios.append(btm / sheet_h)
            top_ratios.append(t / sheet_h)

        if not h_ratios:
            continue
        h_avg = sum(h_ratios) / len(h_ratios)
        w_avg = sum(w_ratios) / len(w_ratios)
        feet_avg = sum(feet_ratios) / len(feet_ratios)
        top_avg = sum(top_ratios) / len(top_ratios)
        results[anim] = {
            "sheet_w": sheet_w,
            "sheet_h": sheet_h,
            "h_ratio": h_avg,
            "w_ratio": w_avg,
            "feet_ratio": feet_avg,
            "top_ratio": top_avg,
        }
        print(
            f"{anim:<14} {sheet_w}x{sheet_h:<6} "
            f"{h_avg:<8.3f} {w_avg:<8.3f} "
            f"{feet_avg:<12.3f} {top_avg:<12.3f}"
        )

    print("\n# Suggested Flutter ratios (target: perso fait TARGET_H * h à l'écran)")
    # Take walk_right comme référence: si h*0.44 donne le perso à 0.44 de la
    # scène pour walk_right (qui occupe ~h_ratio_walk de son sprite), alors
    # pour une autre anim qui occupe h_ratio_X de son sprite, on veut
    # heroHeight tel que heroHeight * h_ratio_X = h*0.44 * h_ratio_walk
    # → heroHeight = h*0.44 * (h_ratio_walk / h_ratio_X)
    ref = results.get("walk_right") or results.get("idle_right")
    if not ref:
        print("# (pas de référence walk_right/idle_right)")
        return
    ref_h_ratio = ref["h_ratio"]
    print(f"# Référence: walk_right h_ratio={ref_h_ratio:.3f}")
    print("# Pour viser perso = h*0.44 à l'écran (= taille walk_right actuelle):")
    for anim, d in sorted(results.items()):
        scale_mul = ref_h_ratio / d["h_ratio"]
        feet_y = d["feet_ratio"]
        sheet_aspect = d["sheet_w"] / d["sheet_h"]
        print(
            f"#   {anim:<14}: heroHeight = h * 0.44 * {scale_mul:.3f} "
            f"= h * {0.44 * scale_mul:.3f},  "
            f"feetRatio = {feet_y:.3f},  "
            f"width/height (sheet) = {sheet_aspect:.3f}"
        )


if __name__ == "__main__":
    main()
