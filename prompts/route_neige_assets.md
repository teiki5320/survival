# Prompts — Décors parallax zone neige + carte

Tous les assets ci-dessous sont des **décors parallax side-scroller**
(sauf la carte et le givre). Ils scrollent horizontalement derrière le
wagon, en boucle. Ils doivent être **tileable horizontalement**.

**Références** : `horizon_a.png`, `horizon_b.png`, `horizon_c.png`,
`sky.png`, `foreground_band.png` (les décors tempérés existants).
Même style, même format, même logique de couches.

**Style commun** : `anime illustration, Studio Ghibli inspired,
hand-painted texture, lofi cozy aesthetic`.

**Négatif commun** : `no text, no letters, no watermark, no characters,
no train, no rails`.

---

## 1. Horizons neige (×3) — décor parallax lointain

Remplacent `horizon_a/b/c.png` en zone froide. Même bande verticale
(haut de l'écran, ~30 % de la hauteur). Scrollent lentement.

**Ratio** : 32:9. **Fond** : ciel intégré dans l'image (pas de keying).

**Fichiers** : `horizon_snow_a.png`, `horizon_snow_b.png`,
`horizon_snow_c.png`.

### 1.1 — Plaine enneigée + ruines urbaines

```
Seamless horizontal parallax background, side-scrolling game,
extreme wide shot, very far away perspective, vast snowy plain
with a dense ruined city skyline on the far horizon, dozens of
crumbling skyscrapers and collapsed towers silhouetted against
the sky, broken highway overpasses, fallen cranes, antenna masts,
smoke rising from scattered points in the ruins, snow covering
everything, atmospheric haze softening the details with distance,
huge overcast pale grey sky taking most of the image, cold
blue-white palette, depth through aerial perspective,
anime illustration, Studio Ghibli inspired, hand-painted texture,
no text, no watermark, no characters, no train, no rails,
no foreground elements
```

### 1.2 — Forêt de sapins

```
Seamless horizontal parallax background, side-scrolling game,
extreme wide shot, very far away perspective, vast frozen forest
seen from great distance, tiny snow-covered pines forming a
dense tree line far on the horizon, soft fog and atmospheric
haze between layers, huge pale grey-blue sky with low clouds,
cold silver palette, everything small and distant, depth through
aerial perspective, anime illustration, Studio Ghibli inspired,
hand-painted texture,
no text, no watermark, no characters, no train, no rails,
no close-up details, no foreground elements
```

### 1.3 — Montagnes lointaines

```
Seamless horizontal parallax background, side-scrolling game,
extreme wide shot, very far away perspective, vast snowy mountain
range far on the horizon, tiny jagged peaks fading into haze,
frozen lake as a small pale shape in the far distance, enormous
sky with low sun behind clouds casting cold diffused light,
pale blue-grey and white palette with hints of dusty rose on
distant peaks, strong atmospheric perspective, anime illustration,
Studio Ghibli inspired, hand-painted texture,
no text, no watermark, no characters, no train, no rails,
no close-up details, no foreground elements
```

---

## 2. Horizon nuit neige (×1) — décor parallax lointain

**Ratio** : 32:9. **Fichier** : `horizon_snow_night.png`.

```
Seamless horizontal parallax background, side-scrolling game,
extreme wide shot, very far away perspective, vast frozen
wasteland at night seen from great distance, deep blue-black
sky with stars and crescent moon taking most of the image,
snow-covered land glowing faintly under moonlight far below,
tiny dark silhouettes of ruins on the far horizon, subtle
northern lights (green-teal band low), cold deep blue and silver
palette, strong atmospheric perspective, anime illustration,
Studio Ghibli inspired, hand-painted texture,
no text, no watermark, no characters, no train, no rails,
no close-up details, no foreground elements
```

---

## 3. Ciels neige (×2) — couche parallax haute

Couche de nuages qui scrolle au-dessus de l'horizon (opacité 0.18–0.30).
Remplacent `sky.png` / `sky_night.png` en zone froide.

**Ratio** : 32:9. **Fichiers** : `sky_snow.png`, `sky_snow_night.png`.

### 3.1 — Ciel jour

```
Seamless horizontal parallax background, overcast winter sky only,
thick low clouds in layers, pale grey-white with cold blue hints,
subtle snow flurries from cloud base, diffused cold light,
anime illustration, Studio Ghibli inspired, hand-painted texture,
no ground, no landscape, no characters, no text, no watermark
```

### 3.2 — Ciel nuit

```
Seamless horizontal parallax background, winter night sky only,
deep navy blue with bright stars, thin wispy clouds catching
moonlight, subtle aurora borealis glow (green-teal) near bottom,
anime illustration, Studio Ghibli inspired, hand-painted texture,
no ground, no landscape, no characters, no text, no watermark
```

---

## 4. Sol neige (×1) — décor parallax premier plan

Remplace `foreground_band.png` en zone froide. Bande sous les rails
(y=0.92→1.0), scrolle au même rythme.

**Ratio** : 16:9. **Fond noir** top 60 % pour keying.
**Fichier** : `foreground_snow.png`.

```
Seamless horizontal parallax foreground strip, side-scrolling game,
snowy ground seen from the side, fresh snow on old ballast stones,
patches of ice, frozen dry grass poking through, cold blue-white
palette, solid black background (#000000) on top 60%,
anime illustration, Studio Ghibli inspired, hand-painted texture,
no text, no watermark, no characters, no rails
```

---

## 5. Horizons de transition (×2) — décor parallax lointain

Affichés pendant le passage entre zone tempérée et zone froide.

**Ratio** : 32:9. **Fichiers** : `horizon_transition_a.png`,
`horizon_transition_b.png`.

### 6.1 — Entrée dans le froid

```
Seamless horizontal parallax background, side-scrolling game,
extreme wide shot, very far away perspective, vast post-apocalyptic
landscape seen from great distance transitioning from autumn to
winter, left side warm brown earth fading into haze, right side
white snow covering the far horizon, enormous overcast sky getting
colder rightward, muted amber blending into pale blue-grey,
strong atmospheric perspective, anime illustration, Studio Ghibli
inspired, hand-painted texture,
no text, no watermark, no characters, no train, no rails,
no close-up details, no foreground elements
```

### 6.2 — Sortie du froid

```
Seamless horizontal parallax background, side-scrolling game,
extreme wide shot, very far away perspective, vast post-apocalyptic
landscape seen from great distance transitioning from winter to
spring, left side white snow fading into haze, right side warm
brown-green earth returning on the far horizon, enormous sky
clearing from grey to warm light, cold silver blending into warm
honey, strong atmospheric perspective, anime illustration, Studio
Ghibli inspired, hand-painted texture,
no text, no watermark, no characters, no train, no rails,
no close-up details, no foreground elements
```

---

## 6. Carte du monde (×1)

Image fixe scrollable, vue du dessus, parcours **ovale**.

**Ratio** : 3:4 (portrait). **Résolution** : 2048×2732 minimum.
**Fichier** : `map_route.png`.

```
Top-down bird's eye view map, looking straight down,
post-apocalyptic terrain, oval railway track running through
the landscape, top 40% covered in snow and ice, bottom 60%
dry brown earth, ruined cities along the tracks,
hand-drawn cartography style, Studio Ghibli inspired,
parchment paper texture, no text, no labels, no watermark
```

---

## 7. Givre sur vitre (×1)

Overlay plaqué sur les fenêtres du wagon en zone froide. Le code
contrôle l'opacité (0 → 1 progressivement).

**Ratio** : 2:3 (portrait, comme le wagon). **Fond noir** pour keying.
**Fichier** : `frost_overlay.png`.

```
Frost pattern on glass, ice crystals forming from edges inward,
delicate fern-like frost formations, center mostly clear, frost
thickening toward edges, cold blue-white ice crystals,
solid black background (#000000),
anime illustration, Studio Ghibli inspired, hand-painted texture,
no text, no watermark, no characters
```

---

## 8. Animations personnage — zone froide

49 frames chacune, **AutoSprite** (5 cred / anim). Style identique
aux 13 anims existantes. Vue de profil, face à droite.

### 9.1 `shiver` — Grelotter

```
Young woman in cozy post-apocalyptic clothing, standing, shivering,
rubbing her arms, side view right-facing, warm honey brown hair,
solid black background (#000000), anime illustration, Studio Ghibli
inspired, hand-painted texture, no text, no watermark
```

### 9.2 `blow_hands` — Souffler dans ses mains

```
Young woman in cozy post-apocalyptic clothing, standing, cupping
hands near mouth blowing warm breath, side view right-facing,
warm honey brown hair, solid black background (#000000),
anime illustration, Studio Ghibli inspired, hand-painted texture,
no text, no watermark
```

### 9.3 `look_window_snow` — Regarder la neige

```
Young woman in cozy post-apocalyptic clothing, standing at window,
looking out at falling snow, one hand on frosted glass, wistful
expression, side view right-facing, warm honey brown hair,
solid black background (#000000), anime illustration, Studio Ghibli
inspired, hand-painted texture, no text, no watermark
```

---

## Récap

| # | Fichier | Type | Statut |
|---|---------|------|--------|
| 1 | `horizon_snow_a.png` | parallax lointain | DONE |
| 2 | `horizon_snow_b.png` | parallax lointain | DONE |
| 3 | `horizon_snow_c.png` | parallax lointain | DONE |
| 4 | `horizon_snow_d/e/f/g.png` | parallax lointain (variantes) | DONE |
| 5 | `horizon_snow_night.png` + `_b` | parallax lointain nuit | DONE |
| 6 | `sky_snow.png` + `_b` | parallax haut jour | DONE |
| 7 | `sky_snow_night.png` + `_b` | parallax haut nuit | DONE |
| 8 | `foreground_snow.png` + `_b` | parallax premier plan | DONE |
| 9 | `horizon_transition_a/b/c/d.png` | parallax transition | DONE |
| 10 | `frost_overlay.png` + `_round` | overlay vitre | DONE (keyé) |
| 11 | `map_route.png` | carte scrollable | À FAIRE |
| 12 | `shiver` (49 fr) | anim personnage | À FAIRE (5 cred) |
| 13 | `blow_hands` (49 fr) | anim personnage | À FAIRE (5 cred) |
| 14 | `look_window_snow` (49 fr) | anim personnage | À FAIRE (5 cred) |

**Rails** : on garde les rails actuels (`wagon_rails.png`), pas de variante neige.

**Fait** : 21 images triées (10 backgrounds + 11 variantes + 2 frost overlays).
**Reste** : 1 carte + 3 anims AutoSprite (15 cred).
