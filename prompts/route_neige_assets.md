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

### 1.1 — Plaine enneigée

```
Seamless horizontal parallax background, side-scrolling game,
post-apocalyptic snowy plain, dead trees with snow, abandoned
utility poles half-buried, distant ruined buildings in light
snowfall, overcast pale grey sky, cold blue-white palette,
anime illustration, Studio Ghibli inspired, hand-painted texture,
no text, no watermark, no characters, no train, no rails
```

### 1.2 — Forêt de sapins

```
Seamless horizontal parallax background, side-scrolling game,
post-apocalyptic frozen forest, snow-covered pines and bare
birch trunks, fog between trees, abandoned cabin roof behind
tree line, pale grey-blue sky with low clouds, cold silver
palette, anime illustration, Studio Ghibli inspired,
hand-painted texture,
no text, no watermark, no characters, no train, no rails
```

### 1.3 — Montagnes lointaines

```
Seamless horizontal parallax background, side-scrolling game,
post-apocalyptic snowy mountain range, jagged peaks in
background, frozen lake mid-ground, collapsed bridge pillars,
low sun behind clouds, pale blue-grey and white palette with
hints of dusty rose, anime illustration, Studio Ghibli inspired,
hand-painted texture,
no text, no watermark, no characters, no train, no rails
```

---

## 2. Horizon nuit neige (×1) — décor parallax lointain

**Ratio** : 32:9. **Fichier** : `horizon_snow_night.png`.

```
Seamless horizontal parallax background, side-scrolling game,
post-apocalyptic frozen wasteland at night, deep blue-black sky
with stars and crescent moon, snow glowing under moonlight,
dark silhouettes of dead trees and ruins, subtle northern lights
(green-teal band low), cold deep blue and silver palette,
anime illustration, Studio Ghibli inspired, hand-painted texture,
no text, no watermark, no characters, no train, no rails
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

## 4. Rails neige (×1) — décor parallax premier plan

Variante enneigée de `wagon_rails.png`. Scrolle vite (même vitesse
que les rails actuels). Bande étroite sous le wagon (y=0.83→0.92).

**Ratio** : 16:9. **Fond noir** pour keying.
**Fichier** : `wagon_rails_snow.png`.

```
Seamless horizontal parallax foreground strip, side-scrolling game,
old railway tracks seen from the side, rusty rails on wooden
sleepers, snow between sleepers, ice on rail edges, cold blue-white
tones, solid black background (#000000) on top and bottom,
anime illustration, Studio Ghibli inspired, hand-painted texture,
no text, no watermark, no characters, no train
```

---

## 5. Sol neige (×1) — décor parallax premier plan

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

## 6. Horizons de transition (×2) — décor parallax lointain

Affichés pendant le passage entre zone tempérée et zone froide.

**Ratio** : 32:9. **Fichiers** : `horizon_transition_a.png`,
`horizon_transition_b.png`.

### 6.1 — Entrée dans le froid

```
Seamless horizontal parallax background, side-scrolling game,
post-apocalyptic landscape transitioning from autumn to winter,
left side dry brown grass and bare trees with last orange leaves,
right side patches of snow and frosted ground, overcast sky
getting colder rightward, muted amber blending into pale blue-grey,
anime illustration, Studio Ghibli inspired, hand-painted texture,
no text, no watermark, no characters, no train, no rails
```

### 6.2 — Sortie du froid

```
Seamless horizontal parallax background, side-scrolling game,
post-apocalyptic landscape transitioning from winter to spring,
left side melting snow and mud puddles, right side green-brown
grass returning and budding trees, sky clearing from grey to warm,
cold silver blending into warm honey light,
anime illustration, Studio Ghibli inspired, hand-painted texture,
no text, no watermark, no characters, no train, no rails
```

---

## 7. Carte du monde (×1)

Pas du parallax — image fixe scrollable (plus grande que l'écran).
Le code dessine par-dessus : tracé du parcours, icône train, gares.

**Ratio** : 3:4 (portrait). **Résolution** : 2048×2732 minimum.
**Fichier** : `map_route.png`.

```
Top-down illustrated map, post-apocalyptic landscape, circular
railway route as worn iron track loop, northern 40% covered in
snow and ice, southern 60% dry brown earth and sparse vegetation,
ruined city clusters (3 large, 5 small) along the route, rivers,
dried lakes, cracked highways, warm parchment paper texture,
hand-drawn cartography style, Studio Ghibli map aesthetic
(Nausicaa / Howl's Moving Castle maps),
no text, no letters, no labels, no markers, no watermark
```

---

## 8. Givre sur vitre (×1)

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

## 9. Animations personnage — zone froide

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

| # | Fichier | Type | Outil | Coût |
|---|---------|------|-------|------|
| 1 | `horizon_snow_a.png` | parallax lointain | OpenArt | 0 |
| 2 | `horizon_snow_b.png` | parallax lointain | OpenArt | 0 |
| 3 | `horizon_snow_c.png` | parallax lointain | OpenArt | 0 |
| 4 | `horizon_snow_night.png` | parallax lointain | OpenArt | 0 |
| 5 | `sky_snow.png` | parallax haut | OpenArt | 0 |
| 6 | `sky_snow_night.png` | parallax haut | OpenArt | 0 |
| 7 | `wagon_rails_snow.png` | parallax premier plan | OpenArt | 0 |
| 8 | `foreground_snow.png` | parallax premier plan | OpenArt | 0 |
| 9 | `horizon_transition_a.png` | parallax lointain | OpenArt | 0 |
| 10 | `horizon_transition_b.png` | parallax lointain | OpenArt | 0 |
| 11 | `map_route.png` | carte scrollable | OpenArt | 0 |
| 12 | `frost_overlay.png` | overlay vitre | OpenArt | 0 |
| 13 | `shiver` (49 fr) | anim personnage | AutoSprite | 5 |
| 14 | `blow_hands` (49 fr) | anim personnage | AutoSprite | 5 |
| 15 | `look_window_snow` (49 fr) | anim personnage | AutoSprite | 5 |

**Total** : 12 images OpenArt (gratuit) + 3 anims AutoSprite (15 cred).
