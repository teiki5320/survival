# Train Cosy — mémoire Claude

Ce fichier sert de **mémoire persistante** entre sessions. Lis-le au démarrage
de chaque nouvelle conversation avant d'agir sur ce repo.

---

## Le projet

**Train Cosy** est une app Flutter / iOS en cours de prototype : un jeu narratif
**cosy post-apocalyptique**. Une jeune femme (l'« habitante ») vit seule dans
le dernier wagon d'un train qui roule à travers un monde mort. Elle interagit
avec son environnement, le train tangue doucement, l'ambiance bascule jour /
nuit. Le jeu est un **side-scroller** vue de côté : le wagon est centré, le
paysage défile latéralement derrière, la locomotive est à gauche.

**Esthétique cible** : Studio Ghibli + lofi anime, hand-painted, palette warm
honey browns / cream / soft amber dedans, cold blue / pale fog dehors.

**État actuel** : prototype visuel solide + boucle CI/CD opérationnelle.
Animations 49-frames en place (18 héroïne + 8 chien). Locomotive scène + carte
du monde + events narratifs câblés. HUD survie (hunger/thirst/fatigue) + cycle
météo auto. Mécaniques de progression / sauvegarde à construire.

---

## Workflow technique

- **Repo** : `teiki5320/survival` (le nom historique, le projet s'appelle
  Train Cosy en interne).
- **Branche** : **`main` uniquement**. L'utilisateur a explicitement dit de
  bosser direct sur main, pas de branches Claude. **NE PAS** créer de branche
  `claude/<feature>`.
- **CI** : Xcode Cloud watchait `main` (build + upload TestFlight auto). À
  date l'utilisateur a **désactivé** la distribution auto sur xcloud pour
  économiser les quotas TestFlight.
- **Xcode Cloud "Archive - iOS" en rouge** : ouvrir l'onglet **Erreur**
  pour voir le message. Si c'est **"Preparing build for App Store
  Connect failed"** → c'est l'étape d'upload TestFlight qui rejette
  (version déjà présente). Fix : **bump `version:` dans `pubspec.yaml`**
  (incrémenter le `+N` au minimum, ex `0.11.10+11` → `0.11.11+12`) puis
  re-push.
- **Bundle ID iOS** : `com.teiki5320.trainCosy`.
- **App Store Connect** : app créée, TestFlight Internal Testing actif.
- **Flutter** : projet scaffold via `flutter create`, dossier `ios/` committé.
  ci_scripts dans `ios/ci_scripts/ci_post_clone.sh`.
- **Dev local** : l'utilisateur build par cable depuis son Mac mini
  (`/Users/jeanperraudeau/survival`), iPhone 16 Plus « Jean »
  (UDID `00008140-00113D122E8B001C`). iOS 26.5 beta + Xcode 26.5.
- **iOS 26 beta + debug mode** : crash `EXC_BAD_ACCESS` au launch (JIT). La
  parade c'est **toujours `flutter run --release`**. Le release mode AOT
  fonctionne sans souci.
- **Version actuelle** : `0.11.10+11` dans `pubspec.yaml`.
- **Dépendances** : `audioplayers: ^6.1.0`, `cupertino_icons: ^1.0.6`.

## Règles de commit / push

- **Commit + push à chaque modification** sans attendre validation explicite.
  L'utilisateur a explicitement levé (2026-05-23) la restriction qui était
  en place avant. Retour au mode normal : fix → commit → push, dans la foulée.
- Si t'enchaînes plusieurs petits fixes liés sur le même sujet, empile dans
  un seul commit.
- Push direct sur `main` (`git push -u origin main`), pas de PR à créer.

---

## Workflow assets

L'utilisateur génère les images via **OpenArt** (Nano Banana 2 le plus
souvent) ou les sprites d'animation via **AutoSprite** (49 frames par anim).

Process classique image :
1. Génère dans OpenArt (prompt qu'on a calibré).
2. Drop le PNG dans le repo (drag-and-drop GitHub web depuis l'iPad, ou
   `cp + git add + push` depuis le Mac).
3. Me dit « poussé ».
4. Je récupère, key out le fond noir (`tools/key_out_black.py`), déplace
   vers le chemin canonique.

OpenArt **n'exporte pas vraiment en transparence** — fond noir baked-in.
Toujours demander **fond noir pur** dans le prompt, je keye derrière.

Process AutoSprite (anims 49-frame) :
1. L'utilisateur génère une sheet ou un dossier de 49 PNGs depuis AutoSprite.
2. Drop dans `assets/characters/<anim_name>_<i>.png` (i = 1..49).
3. J'intègre dans `side_scroll_scene.dart` ou `locomotive_scene.dart`
   (state machine + précache + bbox/feetRatio).

**Règles AutoSprite (décidées le 2026-05-23)** :
- **Ne JAMAIS faire de preview** (`generate_asset_preview`). Générer
  directement la version finale.
- **Toujours valider le coût AVANT toute dépense**. Annoncer le nombre
  de crédits et attendre OK.
- Tarif : `animate_asset` legendary 49 frames = 5 cred,
  `regenerate_spritesheet` ≈ 5 cred par anim.
- Pour assets statiques : l'utilisateur génère sur **OpenArt**, je donne
  le prompt, il génère, je key + intègre.

**MCP AutoSprite** : disponible uniquement sur le **Claude Code CLI du Mac
mini** (`/Users/jeanperraudeau/.claude.json`). Une session **Claude Code on
the web** n'y a pas accès. Ne pas reproposer l'install MCP côté web.

---

## Checklist prompt OpenArt

1. **Sens / vue** — angle précis en degrés.
2. **Fond** — `solid black background (#000000)`, `no shadow on ground`,
   `no surface under`, `no walls`.
3. **Cadrage** — `full body / object visible with comfortable margin all
   around`.
4. **Éclairage** — `warm honey golden lighting from the upper left`.
5. **Style** — `anime illustration style, Studio Ghibli inspired,
   hand-painted texture, lofi cozy aesthetic`.
6. **Ratio** — adapté au contenu, OpenArt cap à 16:9.
7. **Négatif explicite** — `no text, no letters, no watermark, no characters,
   no scene around`.
8. **Cohérence interne** — palette warm honey browns + cream + soft amber +
   hint of dusty rose.

---

## Architecture côté code

- `lib/main.dart` (586 l.) — App + `WagonScreen` qui héberge tout (state
  machine entre wagon / locomotive / map, FABs droite pour toggles + actions,
  HUD survie hunger/thirst/fatigue).
- `lib/widgets/side_scroll_scene.dart` (1958 l.) — Scène wagon (parallax
  sky/horizon/rails, wagon image, héroïne + chien avec state machine, bed
  adjust mode, horizon adjust mode, action buttons contextuels).
- `lib/widgets/locomotive_scene.dart` (575 l.) — Cabine locomotive avec
  script de ramassage de bûches (idle → walk to woodpile → pickup → carry →
  throw → warm_hands près du feu).
- `lib/widgets/map_screen.dart` (50 l.) — Carte du monde, ultra-minimal
  (image + close button).
- `lib/widgets/location_event_screen.dart` (363 l.) — Dialog full-screen
  avec question + choices + outcome.
- `lib/widgets/atmosphere.dart` (848 l.) — DustParticles, Fireflies,
  FireGlow, HangingVines, CharacterHalo, DistantZombie, FootstepDust,
  WindowRain, ThoughtBubble, FireboxFlames (tous procéduraux, CustomPaint).
- `lib/widgets/train_rocking.dart` (122 l.) — Roulis subtil de toute la
  scène.
- `lib/widgets/wardrobe_screen.dart` (195 l.) — Sélection de tenues.
  Framework prêt, 1 outfit actif (chemise blanche). Structure pensée pour
  49 frames par tenue.
- `lib/models/game_state.dart` (182 l.) — Singleton `ChangeNotifier` :
  énergie (max 5, refill +1/min), barres survie (hunger vide en 30 min,
  thirst 20 min, fatigue 45 min), météo auto (cycle 30 s), lampe toggle,
  inventaire map, flags set, unlocked locations set.
- `lib/services/audio_service.dart` (129 l.) — Singleton audio. Wrappers
  `_safe()` qui swallow les exceptions sur asset manquant. Fonctionnel
  quand les fichiers audio sont présents, silencieux sinon.
- `lib/data/world.dart` (261 l.) — 3 Locations (station_abandonnee débloquée
  par défaut, depot_ferroviaire, village_fantome). 5 Location objects total
  (dont 2 non visibles dans les grep). Question/Choice/Location models.

### Précisions side-scroll

- Heroine bounds : `heroXMin = 0.20`, `heroXMax = 0.82`.
- Bed dialé : `_bedLeft = 0.194`, `_bedTop = 0.448`, `_bedWidth = 0.280`.
  **NE PAS toucher**, réglé via l'adjust mode.
- Horizon adjust mode accessible via FAB landscape. Défauts bakés :
  `_horizonTop = 0.0`, `_horizonBottom = 0.179`.
- 49 frames par anim, **18 anims héroïne** : walk_right, idle_right,
  sleep_right, dance, pickup, yawn, stretch, look_window, read, wake_up,
  wake_up_clean, door_push, warm_hands, carry_walk, cook, drink,
  garden_tend, pet_dog.
- `newSquareSprites` (yawn/stretch/look_window/read/wake_up/door_push/
  warm_hands/carry_walk) sont 512x512 avec `feetRatio = 0.86`.
- `sourceFacesLeft = {'warm_hands'}` en locomotive : ces sprites face déjà
  à gauche, ne PAS mirror.
- door_push en wagon est rendu sans mirror.
- **Chien** : 8 anims (bark, eat, head_tilt, idle, lay_down, sleep,
  stretch_yawn, wag_tail, walk). Frames dans `assets/objects/dog_*.png`.

### Locomotive

- Background `assets/background/locomotive.png` hard-mask keyé.
- Heroine height : `h * 0.44`.
- Woodpile à x=0.70, firebox à x=0.30.
- `FireboxFlames + FireGlow` à `(0.17, 0.66)` puis `(0.17, 0.72)`.

---

## Outils Python (`tools/`)

- `key_out_black.py` — chroma-key fond noir → transparence. Tolérance douce
  (brightness < 18 → 0, > 60 → 255, interpolation entre les deux).
- `split_character_sheet.py` — découpe une sheet horizontale en N PNGs +
  key_out chaque cellule.
- `trim_character_dividers.py` — retire les bandes grises (1-2 px) entre
  panneaux.
- `generate_app_icons.py` — redimensionne `app_icon.png` aux 15 tailles iOS.
- `generate_placeholders.py` — placeholders rectangles colorés.
- `measure_sprite_bboxes.py` — calcul bbox / feetRatio pour les sprites.

---

## État du contenu

**Animations héroïne 49-frames (18)** : walk_right, idle_right, sleep_right,
dance, pickup, yawn, stretch, look_window, read, wake_up, wake_up_clean,
door_push, warm_hands, carry_walk, cook, drink, garden_tend, pet_dog.

**Animations chien (8)** : bark (25 fr), eat (25 fr), head_tilt (25 fr),
lay_down (25 fr), sleep (25 fr), stretch_yawn (25 fr), wag_tail (25 fr),
walk (49 fr). + idle statique.

**Backgrounds** : wagon variants (dirty / swept / windowed / clean), sky /
sky_night, horizon_a / horizon_b / horizon_c / horizon_night (rotate toutes
les 45 s avec crossfade 2 s), locomotive (cab vue de côté), wagon_rails,
foreground_band, map.

**Objets statiques** : bed, bowl_empty, bowl_full, commode, dog_idle,
firstaid, garden, notebook, plaid, plant, rug, table.

**Objets animés (49 frames)** : filter, hydro, lamp, lights, stove.

**Icon** : `assets/icon/app_icon.png` (+ tailles générées).

**Audio** : **zéro fichier**. Code fonctionnel mais silencieux. À dropper :
`ambient_train.mp3`, `music_day.mp3`, `music_night.mp3`, `sfx_<id>.mp3`
(door_open, door_close, footstep, pickup, log_throw, fire_crackle, etc.).

---

## Ce qui reste à faire

### Priorité haute — mécaniques core

1. **Sauvegarde d'état (SharedPreferences)**. `GameState` est 100% en mémoire.
   Tout reset à chaque lancement. Implémenter `save()` / `load()` avec
   sérialisation JSON.
2. **Cycle jour/nuit narratif**. Le cycle météo actuel (30 s) est un
   placeholder dev. Passer à un vrai rythme jour/nuit (5-10 min réelles)
   avec transition visuelle sky/sky_night + comportements héroïne liés.
3. **Audio assets**. Dropper les fichiers dans `assets/audio/`. Le code est
   prêt, il attend juste les mp3.

### Priorité moyenne — gameplay loop

4. **Système de déblocage progressif**. Mécanisme structuré pour gater
   objets/locations/tenues derrière des flags/items.
5. **Schedule d'actions narratives auto**. Héroïne suit un planning (réveil →
   stretch → idle → cuisine → etc.) plutôt que de rester figée.
6. **Mécanique vêtements**. Wardrobe screen existe (1 tenue). Ajouter les
   assets de tenues supplémentaires (chaque = 49 frames × N anims) + logique
   de déblocage.
7. **Plus de Locations + chaînes de Questions**. 3 locations actuelles, la
   roadmap en vise bien plus. Écrire le contenu narratif.

### Priorité basse — polish & contenu

8. **Journal / monologue intérieur**. Bulles narratives contextuelles liées
   au temps / événements / état.
9. **Événements aléatoires nuit**. Zombie → `crackWindow()`, bruits
   suspects, etc. Mécanique procédurale nocturne.
10. **Transparence locomotive sur wagon_swept.png**. Zones transparentes à
    l'arrière de la locomotive qui laissent voir l'horizon. Asset à fixer.
11. **Objets encore absents de la roadmap**. Radio à manivelle, sac à dos,
    jarres de germination, bocaux.
12. **Close-ground parallax** — **abandonné définitivement**, ne PAS ramener.

---

## Communication avec l'utilisateur

- **Langue** : français, ton décontracté direct.
- **Style** : cash, pas de blabla, pas de flatterie. Quand quelque chose ne
  va pas, lui dire. Quand quelque chose est cool, lui dire aussi.
- **TOUJOURS NUMÉROTER les listes / propositions / options** (1, 2, 3...).
  L'utilisateur répond par numéros. Bullets `-` à proscrire pour les listes
  de choix. Aussi valable pour les sous-listes : 1.1, 1.2, etc.
- **Analyse visuelle** : ne pas survoler (proportions, intégration, échelle).
  Vraiment regarder l'image qu'il envoie.
- **Délégations explicites** :
  - Commit : OUI à chaque modification.
  - Décisions UX / esthétiques : NON, toujours proposer.
  - Génération d'assets via OpenArt / AutoSprite : c'est LUI qui génère,
    je fournis les prompts.
  - Drop de fichiers dans le repo : lui (Mac terminal ou iPad GitHub web).
- **Outils interdits** : pas de Xcode Cloud manipulation (pas d'API), pas
  de modifications iOS hors `Info.plist` / `project.pbxproj` standards
  Flutter.
- **Pas d'estimations de temps** : l'utilisateur a dit que tout ce que je dis
  sur les délais est faux, donc je n'en donne plus.

---

## Références d'inspiration

- **Lexploratrice2025** (YouTube wallpaper) — la réf clé.
- **Studio Ghibli** — Voyage de Chihiro (train), Château Ambulant
  (intérieurs cosy), Princesse Mononoke (palette).
- **Genre cosy post-apo** — Stardew Valley (rythme), Spiritfarer (ton
  mélancolique-doux), Disco Elysium (monologue intérieur).
