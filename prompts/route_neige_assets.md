# Prompts — Assets route circulaire + zone neige

Référence esthétique : **Studio Ghibli + lofi anime**, hand-painted,
**Lexploratrice2025** (YouTube wallpaper).

Palette tempérée (existante) : warm honey browns, cream, soft amber.
Palette froide (nouvelle) : pale blue-grey, white, cold silver, muted
teal, hints of warm amber depuis les fenêtres du wagon.

Les backgrounds existants (horizon_a/b/c, sky, foreground_band) font
référence pour le style, les proportions et le format.

---

## 1. Horizons neige (×3 variantes)

Remplacent horizon_a/b/c quand le train est en zone froide (40 % du
parcours). Scrollent en parallax derrière le wagon, même vitesse et
même bande verticale que les horizons actuels.

**Fichiers cibles** : `assets/background/horizon_snow_a.png`,
`horizon_snow_b.png`, `horizon_snow_c.png`.

### Prompt horizon_snow_a — Plaine enneigée

```
Wide panoramic landscape strip, post-apocalyptic winter wasteland,
vast snowy plain stretching to the horizon, scattered dead trees
with snow-laden branches, abandoned utility poles half-buried in
snow, distant ruined buildings barely visible through light snowfall,
overcast pale grey sky, cold blue-white color palette with muted
teal shadows, anime illustration style, Studio Ghibli inspired,
hand-painted texture, lofi cozy aesthetic, seamless horizontal tile,
no text, no letters, no watermark, no characters, no train, no rails
```
Ratio : **32:9** (ultra-wide, pour tiling parallax).
Négatif : `no text, no characters, no train, no rails, no close
foreground`.

### Prompt horizon_snow_b — Forêt de sapins

```
Wide panoramic landscape strip, post-apocalyptic frozen forest,
dense snow-covered pine trees and bare birch trunks, soft fog
between trees, abandoned cabin roof visible behind tree line,
frozen stream bed in middle distance, heavy snow on branches,
pale grey-blue sky with low clouds, cold silver and muted teal
palette, anime illustration style, Studio Ghibli inspired,
hand-painted texture, lofi cozy aesthetic, seamless horizontal tile,
no text, no letters, no watermark, no characters, no train, no rails
```
Ratio : **32:9**.

### Prompt horizon_snow_c — Montagnes lointaines

```
Wide panoramic landscape strip, post-apocalyptic mountain range
in deep winter, jagged snow-capped peaks in background, frozen
lake in mid-ground reflecting pale sky, collapsed bridge pillars
on the shore, scattered snowdrifts and ice formations, low sun
behind clouds casting cold diffused light, pale blue-grey and
white palette with hints of dusty rose on the peaks, anime
illustration style, Studio Ghibli inspired, hand-painted texture,
lofi cozy aesthetic, seamless horizontal tile,
no text, no letters, no watermark, no characters, no train, no rails
```
Ratio : **32:9**.

---

## 2. Horizon nuit neige (×1)

**Fichier cible** : `assets/background/horizon_snow_night.png`.

```
Wide panoramic landscape strip, post-apocalyptic frozen wasteland at
night, deep blue-black sky with scattered stars and a pale crescent
moon, snow-covered ground glowing faintly under moonlight, dark
silhouettes of dead trees and distant ruins, northern lights hint
(subtle green-teal band low on the horizon), cold deep blue and
silver palette, anime illustration style, Studio Ghibli inspired,
hand-painted texture, lofi cozy aesthetic, seamless horizontal tile,
no text, no letters, no watermark, no characters, no train, no rails
```
Ratio : **32:9**.

---

## 3. Ciel neige jour (×1)

Remplace `sky.png` en zone froide. Couche de nuages parallax
au-dessus de l'horizon.

**Fichier cible** : `assets/background/sky_snow.png`.

```
Wide overcast winter sky, thick low clouds in layers, pale grey-white
with hints of cold blue, subtle snow flurries falling from cloud
base, diffused cold light, no sun visible, anime illustration style,
Studio Ghibli inspired, hand-painted texture, lofi cozy aesthetic,
seamless horizontal tile,
no text, no letters, no watermark, no ground, no landscape, no
characters
```
Ratio : **32:9**.

---

## 4. Ciel neige nuit (×1)

**Fichier cible** : `assets/background/sky_snow_night.png`.

```
Wide winter night sky, deep navy blue with scattered bright stars,
thin wispy clouds catching faint moonlight, subtle aurora borealis
glow (green-teal) near the horizon line, cold deep blue palette,
anime illustration style, Studio Ghibli inspired, hand-painted
texture, lofi cozy aesthetic, seamless horizontal tile,
no text, no letters, no watermark, no ground, no landscape, no
characters
```
Ratio : **32:9**.

---

## 5. Foreground band neige (×1)

Sol enneigé sous les rails. Remplace `foreground_band.png` en zone
froide. Même bande y=0.92→1.0, scrolle au même rythme.

**Fichier cible** : `assets/background/foreground_snow.png`.

```
Horizontal strip of snowy ground seen from the side, fresh snow
covering old ballast stones, patches of ice, frozen dry grass
poking through snow, small icicles on debris, cold blue-white
palette, solid black background on top 60% for keying,
anime illustration style, Studio Ghibli inspired, hand-painted
texture, lofi cozy aesthetic,
no text, no letters, no watermark, no characters, no rails
```
Ratio : **16:9**. Fond noir en haut (top 60 %) pour chroma-key.

---

## 6. Rails neige (×1)

Variante enneigée de `wagon_rails.png`.

**Fichier cible** : `assets/background/wagon_rails_snow.png`.

```
Horizontal strip of old railway tracks seen from the side, rusty
rails on wooden sleepers, snow accumulated between sleepers and on
the rail edges, ice patches on metal, cold blue-white tones,
solid black background on top and bottom for keying,
anime illustration style, Studio Ghibli inspired, hand-painted
texture, lofi cozy aesthetic,
no text, no letters, no watermark, no characters, no train
```
Ratio : **16:9**. Fond noir pour keying.

---

## 7. Horizons de transition (×2)

Pour le passage entre zone tempérée et zone froide.

**Fichier cible** : `assets/background/horizon_transition_a.png`,
`horizon_transition_b.png`.

### Prompt transition_a — Entrée dans le froid

```
Wide panoramic landscape strip, post-apocalyptic landscape
transitioning from autumn to winter, left side has dry brown grass
and bare trees with last orange leaves, right side has patches of
snow and frosted ground, overcast sky getting colder toward the
right, muted amber blending into pale blue-grey, anime illustration
style, Studio Ghibli inspired, hand-painted texture, lofi cozy
aesthetic, seamless horizontal tile,
no text, no letters, no watermark, no characters, no train, no rails
```
Ratio : **32:9**.

### Prompt transition_b — Sortie du froid

```
Wide panoramic landscape strip, post-apocalyptic landscape
transitioning from winter to spring, left side has melting snow
and mud puddles, right side has green-brown grass returning and
budding trees, sky clearing from grey to warmer tones, cold silver
blending into warm honey light, anime illustration style, Studio
Ghibli inspired, hand-painted texture, lofi cozy aesthetic,
seamless horizontal tile,
no text, no letters, no watermark, no characters, no train, no rails
```
Ratio : **32:9**.

---

## 8. Carte du monde (×1)

Grande carte scrollable montrant le parcours circulaire du train.
Plus grande que l'écran (le joueur drag pour explorer). Le train,
les gares et la zone froide sont dessinés par le code par-dessus.

**Fichier cible** : `assets/background/map_route.png`.

```
Top-down illustrated map of a post-apocalyptic landscape, circular
railway route visible as a worn iron track loop, northern section
covered in snow and ice (40% of the loop), southern section has
dry brown earth and sparse vegetation, ruined city clusters along
the route (3 large, 5 small), rivers and dried lakes, cracked
highways leading nowhere, warm parchment paper texture overall,
hand-drawn cartography style, anime illustration, Studio Ghibli
map aesthetic like Howl's Moving Castle or Nausicaa maps,
muted earth tones with cold blue-white in the snow zone,
no text, no letters, no labels, no markers, no watermark
```
Ratio : **3:4** (portrait, plus haute que large, pour une carte
qu'on scrolle verticalement surtout). Résolution haute : 2048×2732
ou plus.

---

## 9. Givre sur vitre (×1)

Overlay semi-transparent qui se superpose aux fenêtres du wagon en
zone froide. Le code gère l'opacité (apparition progressive).

**Fichier cible** : `assets/objects/frost_overlay.png`.

```
Frost pattern on glass window, ice crystals forming from the edges
inward, delicate fern-like frost formations, center mostly clear
with frost thickening toward edges, transparent background (PNG),
cold blue-white ice crystals, anime illustration style, Studio
Ghibli inspired, hand-painted texture,
no text, no letters, no watermark, no characters
```
Ratio : **2:3** (portrait, comme le wagon). Fond transparent réel
si possible, sinon fond noir pur pour keying.

---

## 10. Animations personnage — zone froide

Nouvelles anims 49 frames à générer via **AutoSprite** (5 cred
chacune). Référence de style : les 13 anims existantes.

### 10.1 `shiver` — Grelotter

```
Young woman in cozy post-apocalyptic clothing, standing, shivering
from cold, rubbing her arms with her hands, breath visible as small
vapor cloud, seen from the side (right-facing), warm honey brown
hair, anime illustration style, Studio Ghibli inspired, hand-painted
texture, lofi cozy aesthetic, solid black background (#000000),
no text, no watermark
```

### 10.2 `blow_hands` — Souffler dans ses mains

```
Young woman in cozy post-apocalyptic clothing, standing, cupping
her hands near her mouth and blowing warm breath into them, small
vapor cloud visible, seen from the side (right-facing), warm honey
brown hair, anime illustration style, Studio Ghibli inspired,
hand-painted texture, lofi cozy aesthetic, solid black background
(#000000), no text, no watermark
```

### 10.3 `look_window_snow` — Regarder la neige

```
Young woman in cozy post-apocalyptic clothing, standing at a window,
looking out at falling snow with a wistful expression, one hand
touching the frosted glass, seen from the side (right-facing), warm
honey brown hair, anime illustration style, Studio Ghibli inspired,
hand-painted texture, lofi cozy aesthetic, solid black background
(#000000), no text, no watermark
```

---

## Récap fichiers à produire

| # | Fichier | Outil | Coût |
|---|---------|-------|------|
| 1 | `horizon_snow_a.png` | OpenArt | 0 |
| 2 | `horizon_snow_b.png` | OpenArt | 0 |
| 3 | `horizon_snow_c.png` | OpenArt | 0 |
| 4 | `horizon_snow_night.png` | OpenArt | 0 |
| 5 | `sky_snow.png` | OpenArt | 0 |
| 6 | `sky_snow_night.png` | OpenArt | 0 |
| 7 | `foreground_snow.png` | OpenArt | 0 |
| 8 | `wagon_rails_snow.png` | OpenArt | 0 |
| 9 | `horizon_transition_a.png` | OpenArt | 0 |
| 10 | `horizon_transition_b.png` | OpenArt | 0 |
| 11 | `map_route.png` | OpenArt | 0 |
| 12 | `frost_overlay.png` | OpenArt | 0 |
| 13 | `shiver` (49 fr) | AutoSprite | 5 cred |
| 14 | `blow_hands` (49 fr) | AutoSprite | 5 cred |
| 15 | `look_window_snow` (49 fr) | AutoSprite | 5 cred |

**Total AutoSprite** : 15 crédits (3 anims).
**Total OpenArt** : 12 images, gratuit.

---

## Ce que je fais côté code (sans assets)

Tout le reste est du code pur que je peux implémenter seul :

1. Système de position du train (`trainPosition` 0→1, avance en continu)
2. Détection zone froide/tempérée/transition
3. Swap automatique des horizons/sky/foreground selon la zone
4. Carte scrollable (drag pan, plus grande que l'écran)
5. Icône train qui bouge sur la carte
6. Marqueurs de gares (verrouillé/déverrouillé)
7. Overlay givre sur vitres (opacité progressive, procédural)
8. Particules de neige extérieure (CustomPaint, comme WindowRain)
9. Buée de respiration héroïne (procédural)
10. Shift couleur intérieur froid (ColorFilter bleuté)
11. Arrêts aux gares (notification + timer)
12. Mécanique froid/bois/poêle dans GameState
13. HUD prochain arrêt + ETA
14. Intégration des nouvelles anims dans la state machine
