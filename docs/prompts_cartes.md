# Prompts d'illustrations — moments-clés des cartes

Audit des **moments de choix qui méritent une vraie image** (le reste reste en
emblème SVG / portrait sprite). Format demandé pour chaque image :

- **Style** : Studio Ghibli + lofi anime, hand-painted, peinture douce, grain
  léger. Pas de texte, pas de cadre, pas d'UI dans l'image.
- **Palette** : intérieur wagon = warm honey browns / cream / soft amber ;
  extérieur / monde mort = cold blue / pale fog / cendre.
- **Cadrage** : illustration **carrée 1:1** (elle s'affiche dans la carte, en
  haut). Sujet centré, lisible en petit.
- **Canon perso** : **Shen = jeune FEMME de 20 ans**, cheveux noirs longs,
  chemise blanche, pieds nus — JAMAIS une enfant. **La sœur = 7 ans**, pyjama,
  couettes, bien plus petite. **Le chien** = petit chien errant. Les **pillards**
  ne sont jamais montrés en gros plan (silhouettes lointaines, menace diffuse).
- **Fond** : illustration pleine (PAS besoin de keying) — fond peint intégré.
  → dépose le PNG, je le redimensionne et le câble dans le slot `CardArt`.

Nommage cible : `assets/cards/<id>.png`. Le slot `art:` de la carte sera basculé
d'un emblème générique vers l'image dédiée.

---

## 1. La fuite de Kogarashi — `card_kogarashi_fuite.png`
**Gare 1 (Kogarashi), carte G1 — `art: CardArt.fire`**

> A young woman with long black hair and a white shirt, barefoot, clutching the
> doorframe of a moving freight wagon, looking back over her shoulder. Behind
> her, her hometown burns on the horizon — orange glow, columns of smoke rising
> into a low ash-grey sky, falling embers like dirty snow. The train pulls away
> into cold blue dusk. Painterly Ghibli + lofi anime style, hand-painted, warm
> firelight on her face against cold blue night. Square composition, no text.

## 2. Le chiot sous le wagon — `card_kurogane_chiot.png`
**Gare 2 (Kurogane), carte G2ev_chien — `art: CardArt.dog`**

> A small frightened stray dog huddled under the rusted chassis of an abandoned
> freight wagon, in a foggy derelict train depot at dawn. A young woman's bare
> feet and hand reaching gently toward it. Cold blue pale fog, rust browns,
> hopeful warm light breaking through. Ghibli + lofi anime, hand-painted, tender
> mood. Square composition, no text.

## 3. Retrouvailles avec la petite sœur — `card_tsukibashi_soeur.png`
**Gare 5 (Tsukibashi), carte G5 — `art: CardArt.sister`**

> On an old steel railway bridge over a misty ravine, a young woman with long
> black hair and white shirt kneels to embrace a small 7-year-old girl in pyjamas
> with twin pigtails. Emotional reunion, the child running into her arms. Pale
> cold fog around them, a single warm shaft of light on the embrace. Ghibli +
> lofi anime, hand-painted, deeply emotional but restrained. Square, no text.

## 4. La voix radio — `card_radio_voix.png`
**Gares 4→14, chaîne radio — `art: CardArt.radio`** (réutilisable)

> Close-up of a hand-crank radio glowing faintly on a wooden wagon table at
> night, warm amber dial light, a soft halo of static. Through the frosted window
> behind it, cold blue darkness and faint snow. A sense of a distant voice
> reaching through the dead world. Ghibli + lofi anime, hand-painted, intimate
> and hopeful. Square composition, no text.

## 5. La sœur malade — `card_shizuhara_fievre.png`
**Gare 9 (Shizuhara), carte G9 — `art: CardArt.sister`**

> A small 7-year-old girl in pyjamas lying feverish under a blanket on a wagon
> bench, cheeks flushed, a young woman with long black hair pressing a cloth to
> her forehead, worried. Outside the frosted window, a raging blue-white
> blizzard. Warm amber interior light fighting the cold. Ghibli + lofi anime,
> hand-painted, tense and tender. Square composition, no text.

## 6. Le dilemme du mourant — `card_mourant.png`
**Filler F11_mourant — `art: CardArt.pillards` (ou emblème dédié)**

> A gaunt stranger huddled in a tattered coat by the side of frozen railway
> tracks at dusk, reaching weakly toward a passing train. Ambiguous — could be a
> trap, could be genuine. Cold blue fog, ash, a single dim lantern. Ghibli + lofi
> anime, hand-painted, morally heavy and uneasy mood. No faces in detail, distant
> and somber. Square composition, no text.

## 7. Le col gelé / sacrifice — `card_fubuki_col.png`
**Gare 13 (Fubuki), carte G13 — `art: CardArt.fire`**

> An old steam freight locomotive struggling up a steep frozen mountain pass in a
> blizzard, firebox glowing hot orange against the white-blue storm, smoke torn
> by wind. A sense of the engine barely holding on. Ghibli + lofi anime,
> hand-painted, dramatic but cosy-warm firelight core against the cold. Square
> composition, no text.

## 8. L'arrivée au refuge nord — `card_hokuto_refuge.png`
**Gare 14 (Hokuto), carte G14 / fins — `art: CardArt.refuge`**

> A small warm settlement of wooden cabins and lit windows nestled in a snowy
> northern valley, smoke rising softly, lanterns glowing amber in the blue snow
> dusk. A train arriving along the tracks toward it. A feeling of arrival, safety,
> hope after a long journey. Ghibli + lofi anime, hand-painted, the warmest image
> of the game. Square composition, no text.

## 9. Le barrage de pillards — `card_yukihara_barrage.png`
**Gare 11 (Yukihara), carte G11 — `art: CardArt.pillards`**

> A makeshift barricade of scrap metal and old cars blocking the railway tracks
> in a frozen wasteland at dusk, distant shadowy figures standing on it — never
> shown in detail, only menacing silhouettes against cold fog. The train slowing
> on approach. Ghibli + lofi anime, hand-painted, tense and ominous, cold blue
> palette. Square composition, no text.

## 10. L'oasis / serre — `card_hidamari_serre.png`
**Gare 10 (Hidamari), carte G10 — `art: CardArt.hope`**

> A lush green hydroponic greenhouse glowing warm inside an old station, plants
> and soft grow-light against the dead frozen world outside the glass. A rare
> moment of life and warmth. A young woman and a small girl resting inside.
> Ghibli + lofi anime, hand-painted, cosy and restorative, warm green-amber glow.
> Square composition, no text.

## 11. Le carnet brûlé — `card_carnet_brule.png`
**Filler souvenir (gares 3/7) — `art: CardArt.memory`**

> A handwritten notebook / journal open on a wooden wagon table, its edges
> singed and charred, a faded family photograph tucked inside. Warm amber lamp
> light, a pang of memory and loss. Ghibli + lofi anime, hand-painted, intimate
> and bittersweet. Square composition, no text.

---

## Récap — où chaque image se branche

| # | Image | Gare / carte | Slot `art` actuel |
|---|-------|--------------|-------------------|
| 1 | fuite Kogarashi | G1 Kogarashi | fire |
| 2 | chiot | G2ev_chien Kurogane | dog |
| 3 | retrouvailles sœur | G5 Tsukibashi | sister |
| 4 | voix radio | chaîne radio g4→14 | radio |
| 5 | sœur malade | G9 Shizuhara | sister |
| 6 | mourant | F11_mourant | pillards |
| 7 | col gelé | G13 Fubuki | fire |
| 8 | refuge nord | G14 Hokuto / fins | refuge |
| 9 | barrage | G11 Yukihara | pillards |
| 10 | oasis serre | G10 Hidamari | hope |
| 11 | carnet brûlé | filler mémoire | memory |

Quand tu déposes une image, je remplace l'emblème SVG par l'illustration dédiée
dans le slot correspondant (sans casser le fallback pour les cartes sans image).

---

# Props wagon à générer — cohérence d'évolution

Problème : au départ, dans le wagon, tu ne peux **ni filtrer l'eau** (filtre =
gare 4) **ni cultiver** (hydroponie = gare 10). Solution = des **objets de
fortune** dispo dès le début, qui seront ensuite **upgradés** par les vrais
objets. Chaque prop ci-dessous = un **sprite de prop posable** dans le wagon
(fond solide pour keying — **vert #00FF00**, comme les sprites perso).

| Besoin | Début (fortune) | Upgrade | Gare upgrade |
|--------|-----------------|---------|--------------|
| Eau | **bassine de pluie** | filtre à eau (tank) | g4 |
| Faim | **ligne de pêche** (par la fenêtre) | bac hydroponique | g10 |
| Sommeil | **paillasse** | (reste, devient confortable) | — |
| Hygiène | rien | bain / douche | g10 |
| Moral | chien (g2) → carnet (g3) → sœur (g5) → bain (g10) | — | — |

### A. Bassine de pluie — `assets/objects/rainbasin.png`
> A weathered metal basin / bucket catching rainwater, placed on the wooden floor
> of a cosy train wagon by the window, a little rope and funnel rigged above it to
> channel drips. Hand-painted Ghibli + lofi anime style, warm honey-brown wood
> tones, soft amber light. Object only, isolated on a solid bright green #00FF00
> background for cutout. No character, no text.

### B. Ligne de pêche — `assets/objects/fishline.png`
> A simple makeshift fishing line / rod rigged out of a train wagon window — a
> bent stick, a coil of string, a tin hook — resting against the windowsill. Hand-
> painted Ghibli + lofi anime style, warm wood tones, weathered survival
> improvisation. Object only, isolated on a solid bright green #00FF00 background
> for cutout. No character, no text.

> La **paillasse** (couchage de départ) : si tu veux un sprite dédié au lieu de
> réutiliser le lit, demande-le aussi — sinon je réutilise l'asset lit existant
> rendu plus « pauvre ». Dis-moi.
