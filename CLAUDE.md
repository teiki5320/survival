# Train Cosy — mémoire Claude

## Projet

Jeu narratif **cosy post-apo** en Flutter/iOS. Une jeune femme (avec son
chien **Plume**, husky chiot) vit dans le dernier wagon d'un train qui
roule à travers un monde mort. Side-scroller vue de côté, locomotive à
gauche, paysage qui défile. Train tangue, jour/nuit, météo dynamique.

**Esthétique** : Studio Ghibli + lofi anime, hand-painted. Palette warm
honey browns / cream / amber dedans, cold blue / pale fog dehors.

## Workflow technique

- Repo `teiki5320/survival`. Branche **`main` uniquement**, push direct
  (pas de PR, pas de branche `claude/*`).
- **Commit + push à chaque modification** sans demander validation.
- Bundle iOS `com.teiki5320.trainCosy`. Xcode Cloud watch `main`.
- **Bump `version:` dans `pubspec.yaml`** à chaque push. Sinon
  l'archive fail avec "Preparing build for App Store Connect failed".
- **Toujours `flutter analyze`** avant de push pour vérifier qu'il n'y
  a pas d'erreur de compilation (exit-code 65 sur xcloud sinon).
- Dev local : Mac mini `/Users/jeanperraudeau/survival`, iPhone 16 Plus,
  iOS 26.5 beta + Xcode 26.5. **Toujours `flutter run --release`**.
- Hook stop : si je laisse uncommitted, le hook me force à push.

## Workflow assets

**OpenArt (Nano Banana 2)** = l'utilisateur génère sur OpenArt, drop le
PNG dans le repo. Fond noir baked-in → je key avec
`tools/key_out_black.py`.

**Chroma key vert/bleu** = pour la locomotive, l'utilisateur génère le
PNG avec fond vert (= paysage visible) et fond bleu (= feu animé).
Je key les deux couleurs → alpha=0. Le PNG gère tout le masking, pas
de ClipPath runtime.

**AutoSprite (anims)** = l'utilisateur lance depuis le Mac CLI. Règles :

- **JAMAIS de preview** (`generate_asset_preview`). Toujours direct.
- **Valider le coût AVANT** chaque dépense.
- **Asset statique nouveau** = l'utilisateur génère sur OpenArt.
- **Prompt AutoSprite** : NE PAS décrire le personnage. Juste l'action
  et la vue. Ex: `Back view, right arm stirring, subtle shoulder
  movement. Solid black background.`
- MCP AutoSprite installé sur le Mac CLI uniquement (pas sur web).

### Pattern prompt OpenArt

1. Vue / angle précis
2. Fond `solid black background (#000000)`, no shadow, no walls
3. Cadrage : full body/object visible avec marge
4. Lumière `warm honey golden lighting from upper left`
5. Style `anime illustration style, Studio Ghibli inspired,
   hand-painted texture, lofi cozy aesthetic`
6. Négatif `no text, no letters, no watermark, no characters around`

## Architecture code

- `lib/main.dart` — `WagonScreen` + routing wagon/locomotive/map/
  wardrobe. HUD top-left (heroX live + barres + météo). FAB action
  contextuel rond (lit / portes / lampe / lire / boire / cuisiner
  selon zone). Cycle jour/nuit auto 6 min.
- `lib/data/anim_metrics.dart` — **Table unifiée** `kAnimMetrics` des
  métriques de rendu héroïne (scale/aspect/feet/noMirror) partagée
  entre wagon et loco. Calibrée via `tools/measure_sprite_bboxes.py`.
  Pour ajuster une anim : modifier scale/feet dans cette table.
- `lib/widgets/side_scroll_scene.dart` — Scène wagon. State machine
  héroïne (idle/walk/sleep/dance/cook/drink/read/...). Props animés
  via `_AnimatedSprite` (ResizeImage 256). Chien `_DogActor`. Système
  anim spéciale via `specialAnim` + token (drink) ou `cookToken`
  (walk-to-stove + cook). Mode adjust gazinière (long-press).
- `lib/widgets/locomotive_scene.dart` — Cabine loco. PNG avec chroma
  key (vert=paysage, bleu=feu). `FireboxFlames` DERRIÈRE le PNG
  (visible à travers le trou du poêle). Fond braises (gradient ambré)
  bloque le paysage derrière le poêle. Script bûches intact.
- `lib/widgets/map_screen.dart` — Map ultra-minimaliste.
- `lib/widgets/wardrobe_screen.dart` — Outfit picker plein écran.
- `lib/widgets/atmosphere.dart` — DustParticles, Fireflies, FireGlow,
  CharacterHalo, DistantZombie, FootstepDust, ThoughtBubble,
  FireboxFlames (flammes 30× plus rapides que le cycle sky).
- `lib/models/game_state.dart` — Singleton ChangeNotifier. Énergie,
  hunger/thirst/fatigue, inventaire, flags, locations, lampOn, weather.
- `lib/services/audio_service.dart` — Wrappers safe, code no-op.
- `lib/data/world.dart` — 3 Locations + Question/Choice models.

### Système de taille du perso

Toutes les anims utilisent `lib/data/anim_metrics.dart` :
- `heroHeight = h * kHeroBaseHeight * m.scale` (wagon base = 0.36)
- `heroWidth = heroHeight * m.aspect`
- `top = feetY - heroHeight * m.feet`
- Loco utilise `_kLocoHeroBase = 0.572` au lieu de `kHeroBaseHeight`.
- Anims avec mobilier (read, pet_dog, cook) → scale capé plus bas
  car la bbox englobe le meuble.
- `noMirror = true` pour les anims à composition fixe (read, dance,
  sleep, cook, warm_hands, etc.).
- Pour recalibrer : `python3 tools/measure_sprite_bboxes.py`, puis
  `scale = 0.974 / h_ratio`.

### Constantes critiques

- Hero bounds : `heroXMin = 0.22`, `heroXMax = 0.86`.
- Bed : `_bedLeft = 0.194`, `_bedTop = 0.448`, `_bedWidth = 0.280`.
- Horizon clip : `_horizonBottom = 0.179`.
- Stove prop : `left=0.640, top=0.590, height=0.200` (réglable via
  long-press en jeu).
- Chien : `_dogXMin=0.35`, `_dogXMax=0.70`.
- Loco : woodpile x=0.70, firebox x=0.30.
- Door push : 15 frames × 33ms = ~0.5s (raccourci).
- FAB lit : marche vers le lit + dort dessus (pas de sleep par terre).
- FAB cook : marche vers le poêle + anim cook (25 frames).
  Le prop gazinière est masqué pendant l'anim cook.

### Outils Python (`tools/`)

- `key_out_black.py` — chroma-key fond noir → transparence.
- `generate_app_icons.py` — redimensionne app_icon.png aux 15 tailles.
- `measure_sprite_bboxes.py` — mesure les bboxes des sprites héroïne,
  sort les scale/feet/aspect recommandés pour `anim_metrics.dart`.

### Plume — 9 anims (`assets/objects/dog_*`)

`dog_idle.png` (1 img) + `dog_walk` (49) + `dog_sleep` / `dog_lay_down`
/ `dog_wag_tail` / `dog_bark` / `dog_stretch_yawn` / `dog_head_tilt` /
`dog_eat` (25 chacune).

### Héroïne — anims

13 anims 49 frames : `walk_right`, `idle_right`, `sleep_right`,
`dance`, `pickup`, `yawn`, `stretch`, `look_window`, `read`, `wake_up`,
`door_push`, `warm_hands`, `carry_walk`.
5 anims 25 frames : `drink` (clean), `cook` (nouveau, avec gazinière
bakée), `pet_dog`, `garden_tend`, `wake_up_clean`.
`look_window` retiré des idle-breaks (seul `yawn` reste).

### Gazinière animée

Prop `stove` = 25 frames (`assets/objects/stove_1..25.png`), vapeur
qui monte en boucle. Splittée depuis `cook-spritesheet.png`.
Pendant l'anim `cook` du perso, le prop est masqué (la gazinière est
bakée dans le sprite du perso).

## Audio à drop quand prêts

`ambient_train.mp3`, `music_day.mp3`, `music_night.mp3`, `sfx_<id>.mp3`
(door_open/close, clean, footstep, pickup, log_throw, fire_crackle...).

## Communication

- **Langue** : français, ton décontracté direct.
- **Style** : cash, pas de blabla, pas de flatterie.
- **TOUJOURS NUMÉROTER les listes/propositions** (1, 2, 3...).
- **Analyse visuelle** : vraiment regarder l'image. Pas survoler.
- **Décisions UX/esthétiques** : toujours proposer, ne jamais décider.
- **Pas d'estimations de temps**.
- **Outils interdits** : pas de modif iOS hors `Info.plist`/
  `project.pbxproj`. Pas de manipulation Xcode Cloud.

## En cours (session 2026-05-25)

- Build TestFlight actuel : `0.11.40+41`.
- **Gazinière** : mode adjust live ajouté (long-press sur le prop).
  À dialer en jeu puis bake les valeurs dans `_propPos`.
- **Read** : scale baissé à 0.90 (était trop grande). À valider.
- **Cook** : nouvelle anim 25 frames (fille 3/4 dos + gazinière bakée).
  Walk-to-stove câblé via `cookToken`. Prop masqué pendant l'anim.
- **Locomotive** : chroma key vert/bleu dans le PNG. Plus de ClipPath.
  FireboxFlames animé 30× plus rapide, derrière le PNG. Fond braises
  gradient ambré dans le poêle.
- **Taille du perso** : table `kAnimMetrics` recalibrée pour les 18
  anims. Toujours à affiner certaines (read, pet_dog).

## Inspirations

Lexploratrice2025 (réf clé). Studio Ghibli (Chihiro, Château Ambulant,
Mononoke). Stardew Valley, Spiritfarer, Disco Elysium.
