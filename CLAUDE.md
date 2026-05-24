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
- **Bump `version:` dans `pubspec.yaml`** à chaque push si build a déjà
  uploadé une version (ex `0.11.0+1` → `0.11.1+2`). Sinon l'archive
  fail avec "Preparing build for App Store Connect failed". Les .ipa
  sont quand même générés (artefacts dispos).
- Dev local : Mac mini `/Users/jeanperraudeau/survival`, iPhone 16 Plus,
  iOS 26.5 beta + Xcode 26.5. **Toujours `flutter run --release`** (debug
  crash JIT sur iOS 26 beta).
- Hook stop : si je laisse uncommitted, le hook me force à push.

## Workflow assets

**OpenArt (Nano Banana 2)** = l'utilisateur génère sur OpenArt, drop le
PNG dans le repo. Fond noir baked-in → je key avec
`tools/key_out_black.py`.

**AutoSprite (anims 49-frame)** = je peux lancer via HTTPS (`curl -k
-H 'Authorization: Bearer vspk_...'`) depuis la sandbox web. Règles :

- **JAMAIS de preview** (`generate_asset_preview`). Toujours direct.
- **Valider le coût AVANT** chaque dépense. `animate_asset` /
  `regenerate_spritesheet` legendary 49 frames = 5 cred. `create_asset`
  + `remove_asset_background` = gratuit.
- **Asset statique nouveau** = pas faisable sans preview sur AutoSprite.
  L'utilisateur génère sur OpenArt à la place. Je donne le prompt.
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
  contextuel rond (lit / portes / lampe / lire / boire selon zone).
  Cycle jour/nuit auto 6 min.
- `lib/widgets/side_scroll_scene.dart` — Scène wagon. State machine
  héroïne (idle/walk/sleep/dance/...). Props animés via
  `_AnimatedSprite` (ResizeImage 256 pour économiser mémoire). Chien
  `_DogActor` (state machine autonome idle/walk/sleep/lay_down/wagTail/
  bark/headTilt/eat avec position de la gamelle). Système anim spéciale
  via param `specialAnim` + token (drink/read câblés).
- `lib/widgets/locomotive_scene.dart` — Cabine loco. Script bûches
  (walk woodpile → pickup → carry → throw). Mode adjust live des 3
  trous (porte + 2 fenêtres) via ClipPath+HoleClipper (FAB
  `crop_free`).
- `lib/widgets/map_screen.dart` — Map ultra-minimaliste actuellement
  (image plein écran + bouton close). Pins + HUD énergie à
  rebrancher.
- `lib/widgets/wardrobe_screen.dart` — Plein écran perso de face
  (`heroine_front.png`) + flèches G/D pour cycler les tenues.
- `lib/widgets/atmosphere.dart` — DustParticles, Fireflies, FireGlow,
  CharacterHalo, DistantZombie, FootstepDust, ThoughtBubble,
  FireboxFlames (procéduraux). HangingVines + WindowRain retirés du
  wagon.
- `lib/models/game_state.dart` — Singleton ChangeNotifier. Énergie
  (5 max, +1/min), hunger/thirst/fatigue (drain 30/20/45 min,
  restore via interactions), inventaire, flags, locations,
  `lampOn`, `weather` (cycle 30s clear/cloudy/rainy/foggy).
- `lib/services/audio_service.dart` — Wrappers safe. Pas de fichier
  audio committé pour l'instant, code no-op.
- `lib/data/world.dart` — 3 Locations + Question/Choice models.

### Constantes critiques (déjà bakées)

- Hero bounds : `heroXMin = 0.22`, `heroXMax = 0.86`.
- Bed : `_bedLeft = 0.194`, `_bedTop = 0.448`, `_bedWidth = 0.280`.
  Centre baked → `bedCenterX = 0.334`.
- Horizon clip : `_horizonBottom = 0.179`.
- Props bakés dans `_propPos` (hydro 0.805/0.412/0.326,
  bowl 0.481/0.669/0.080, etc.).
- Chien : `_dogXMin=0.35`, `_dogXMax=0.70`, taille via slider HUD.
- Loco woodpile x=0.70, firebox x=0.30. Hero h*0.44 (carry_walk
  scale=1.55, pickup scale=1.30 feet=0.92).

### Plume — 9 anims (folder `assets/objects/dog_*`)

`dog_idle.png` (statique 1 img) + `dog_walk` (49) + `dog_sleep` /
`dog_lay_down` / `dog_wag_tail` / `dog_bark` / `dog_stretch_yawn` /
`dog_head_tilt` / `dog_eat` (25 chacune).

### Héroïne — anims

13 anims originales 49 frames : `walk_right`, `idle_right`, `sleep`,
`dance`, `pickup`, `yawn`, `stretch`, `look_window`, `read`, `wake_up`,
`door_push`, `warm_hands`, `carry_walk`. + 5 nouvelles 25 frames :
`drink` (clean) + `cook` / `pet_dog` / `garden_tend` / `wake_up_clean`
(artefacts visibles dans les sprites, regen à valider).

`heroine_front.png` = pose statique de face (utilisée par wardrobe).

## Audio à drop quand prêts

`ambient_train.mp3`, `music_day.mp3`, `music_night.mp3`, `sfx_<id>.mp3`
(door_open/close, clean, footstep, pickup, log_throw, fire_crackle...).

## Communication

- **Langue** : français, ton décontracté direct.
- **Style** : cash, pas de blabla, pas de flatterie.
- **TOUJOURS NUMÉROTER les listes/propositions** (1, 2, 3...) pour que
  l'utilisateur réponde par numéros. Sous-listes 1.1, 1.2 etc.
- **Analyse visuelle** : vraiment regarder l'image (proportions,
  intégration, échelle). Pas survoler.
- **Décisions UX/esthétiques** : toujours proposer plusieurs options
  numérotées, ne jamais décider seul.
- **Pas d'estimations de temps**.
- **Outils interdits** : pas de modif iOS hors `Info.plist`/
  `project.pbxproj` Flutter standards. Pas de manipulation Xcode Cloud
  (pas d'API).

## Inspirations

Lexploratrice2025 (réf clé). Studio Ghibli (Chihiro, Château Ambulant,
Mononoke). Stardew Valley, Spiritfarer, Disco Elysium.
