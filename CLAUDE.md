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

**État actuel (2026-05-29)** : prototype solide avec **page d'accueil**, 16
anims héroïne, 8 anims chien, 4 parallax (sky/horizon/mid/foreground),
silhouettes humaines + foreground life sur l'horizon, audio branché (ambient
train + 10 SFX, musique désactivée temporairement), carte avec spline + 14
gares + 5 wood points cliquables. **Mini-jeux de gestion en cours** : hydro
(potager 6 cups vue dessus avec sprites peints), bois (forêt 5×4), filtre eau
(animation niveau inline, plus de mini-jeu modal).

---

## Workflow technique

- **Repo** : `teiki5320/survival` (le nom historique, le projet s'appelle
  Train Cosy en interne).
- **Branche** : **`main` uniquement**. L'utilisateur a explicitement dit de
  bosser direct sur main, pas de branches Claude. **NE PAS** créer de branche
  `claude/<feature>`.
- **CI** : Xcode Cloud watch `main` (build auto à chaque push). La
  distribution TestFlight auto est **désactivée** pour économiser les quotas.
- **Xcode Cloud "Archive - iOS" en rouge** : ouvrir l'onglet **Erreur**
  pour voir le message. Si "Preparing build for App Store Connect failed"
  → bump `version:` dans `pubspec.yaml`. Si "Command PhaseScriptExecution
  failed" → erreur Dart, voir les Journaux.
- **Bundle ID iOS** : `com.teiki5320.trainCosy`.
- **Flutter** : projet scaffold via `flutter create`, dossier `ios/` committé.
  ci_scripts dans `ios/ci_scripts/ci_post_clone.sh`.
- **Dev local** : l'utilisateur build par cable depuis son Mac mini
  (`/Users/jeanperraudeau/survival`), iPhone 16 Plus « Jean ».
- **iOS 26 beta + debug mode** : crash `EXC_BAD_ACCESS` au launch (JIT). La
  parade c'est **toujours `flutter run --release`**.
- **Version actuelle** : `0.13.0+48` dans `pubspec.yaml`.
- **Dépendances** : `audioplayers: ^6.1.0`, `cupertino_icons: ^1.0.6`.

## Règles de commit / push

- **Commit + push à chaque modification** sans attendre validation explicite.
- Push direct sur `main` (`git push -u origin main`), pas de PR à créer.
- **Toujours bumper la version** (`+N` au minimum) à chaque push pour éviter
  les rejets Xcode Cloud.

---

## Workflow assets

L'utilisateur génère les images via **OpenArt** (Nano Banana 2) ou les
sprites d'animation via **AutoSprite** (49 frames par anim).

Process classique image :
1. Génère dans OpenArt.
2. Drop le PNG dans le repo (drag-and-drop GitHub web depuis l'iPad).
3. Me dit « poussé ».
4. Je récupère, key out le fond blanc/noir, déplace vers `assets/`.

OpenArt **n'exporte pas vraiment en transparence** — fond blanc/noir baked-in.
Toujours demander fond solide blanc (#FFFFFF) ou noir (#000000), je keye.

**Règles AutoSprite** :
- **Ne JAMAIS faire de preview**. Générer directement la version finale.
- **Toujours valider le coût AVANT toute dépense**. Annoncer crédits et
  attendre OK.
- Tarif : `animate_asset` legendary 49 frames = 5 cred.

**MCP AutoSprite** : disponible uniquement sur le **Claude Code CLI du Mac
mini**. Une session **Claude Code on the web** n'y a pas accès.

---

## Architecture côté code

- `lib/main.dart` — App + `WagonScreen`. État global : night, _heroSpawnX,
  flags (_inLocomotive, _onMap, _inHydroGame, _inWoodGame, _inWardrobe,
  _doorPushing), HUD survie (hunger/thirst/fatigue + chips bois/eau/food),
  bouton action contextuel selon position du perso.
- `lib/widgets/title_screen.dart` — Page d'accueil avec fond ville glacée
  `title_bg.png`, titre, sous-titre, boutons "Continuer" (si save) /
  "Nouvelle partie". Fade-in 1.5s, transition 800ms vers le wagon.
- `lib/widgets/side_scroll_scene.dart` (~2300 l.) — Scène wagon : 4 parallax
  (sky 80s / horizon 20s / mid 10s / foreground 8s), wagon image, héroïne +
  chien, props (hydro/lamp/stove/filter/table/notebook/firstaid/commode/bowl),
  silhouettes humaines + foreground life sur horizon, animations atmosphère.
  Le filtre est maintenant un asset **tank** dynamique selon `waterTankGlasses`
  (12 frames 0→11 selon niveau).
- `lib/widgets/locomotive_scene.dart` — Cabine locomotive avec ramassage
  bûches (idle → walk → open_door [pickup] → carry → open_door reverse
  mirroré [throw] → warm_hands).
- `lib/widgets/map_screen.dart` — Carte 14 gares + 5 wood points (orange
  park icon) entre villes. Spline Catmull-Rom arc-length param. Train
  procédural détaillé (loco + 2 wagons). Tap point bois → callback ouvre
  WoodGameTier1.
- `lib/widgets/atmosphere.dart` (~1800 l.) — Tous les widgets atmo :
  DustParticles, Fireflies, FireGlow, HangingVines, CharacterHalo,
  DistantZombie, FootstepDust, WindowRain, ThoughtBubble, FireboxFlames,
  + DaytimeBirds, DistantAnimal, AnimatedGrass, ScurryingAnimal,
  DoorSteam, FlyingEmbers, AnimatedCurtains, WindowFrost, Cobwebs,
  AnimatedGauges, FloatingAshes, PipeSteam, MidgroundParallax,
  HorizonFigures, ForegroundLife.
- `lib/widgets/train_rocking.dart` — Roulis subtil.
- `lib/widgets/wardrobe_screen.dart` — Sélection de tenues (1 outfit
  pour l'instant).
- `lib/widgets/location_event_screen.dart` — Dialog full-screen avec
  question + choices + outcome.
- `lib/widgets/games/hydro_game.dart` — Mini-jeu hydro tier 1. Vue de
  dessus avec background `hydro_tank.png` (cuve 6 cups). 6 emplacements
  actifs, 2 pots actuellement utilisés. Sprites peints
  (`assets/plants/{plant}_{stage}.png`). Boutons : Semer carotte /
  Arroser / Récolter / Passer un step. 5 stages de croissance + ripe
  affiché brièvement à la récolte.
- `lib/widgets/games/wood_game.dart` — Mini-jeu bois tier 1. Grille
  5×4 forêt. Énergie 10. Branches (+2/1pt), bûches (+5/2pt), arbres
  morts (+10/5pt). Quitter ramène le bois récolté au compteur.
- `lib/models/game_state.dart` — Singleton ChangeNotifier. Sauvegarde
  JSON `dart:io` (~150s auto). State : énergie (max 5), hunger/thirst/
  fatigue (vide en 30/20/45 min), météo auto zonée, train position (boucle
  60 min), lampe, inventaire, flags, unlocked locations, **waterTankGlasses
  0-5**, **filterTier/hydroTier/woodTier (1-4 prévu)**, hydroSlots[8] et
  waterJars[5] avec advanceFarm() offline/online.
- `lib/services/audio_service.dart` — Singleton audio. setMusic('day'/
  'night'/'cold') currently disabled. startAmbientTrain/Fire +
  playSfx('door_open/close/footstep/pickup/log_throw/fire_crackle/
  lamp_toggle/drink/dog_bark/dog_pant').
- `lib/data/world.dart` — 3 Locations narratives (station_abandonnee,
  depot_ferroviaire, village_fantome).
- `lib/data/anim_metrics.dart` — Métriques sprites perso (scale, aspect,
  feet, noMirror).

### Précisions side-scroll

- Heroine bounds : `heroXMin = 0.22`, `heroXMax = 0.86`.
- Bed dialé : `_bedLeft = 0.194`, `_bedTop = 0.448`, `_bedWidth = 0.280`.
- Stove : `_PropPos(0.629, 0.445, 0.263)` square 49 frames.
- 49 frames par anim. **16 anims héroïne câblées** : walk_right,
  idle_right, sleep_right, dance, pickup, yawn, stretch, look_window,
  read, wake_up, door_push, warm_hands, carry_walk, cook, drink,
  open_door (20fr), crouch (49fr), use_back (49fr de dos), pet_dog (49fr).
- **Props actifs dans le wagon** : hydro, lamp, stove, filter (=tank
  dynamique), table, notebook, firstaid, commode, bowl. **Pas dans
  scène** : plant, lights, rug.
- **Chien** : 8 anims (bark, eat, head_tilt, idle, lay_down, sleep,
  stretch_yawn, wag_tail, walk). Maintenant chien statique (`dog_idle.png`)
  + bouton action alterne pet_dog / crouch+wag_tail.
- **Spawn perso au retour** : sortie loco → heroXMin, sortie map →
  heroXMax.

### Locomotive

- Background `assets/background/locomotive.png` hard-mask keyé.
- Heroine height : `h * 0.44`.
- Woodpile à x=0.70, firebox à x=0.34.
- Pickup utilise `open_door` (20fr) au lieu de `pickup` (49fr).
- Throw = open_door reverse + mirror.

### Mini-jeu hydro

- Background : `assets/background/hydro_tank.png` (cuve hydroponique vue
  dessus, 6 net cups vides).
- Sprites peints : `assets/plants/{plant}_{stage}.png`. 4 plantes
  (tomato, carrot, eggplant, lettuce) × 6 stades (sprout, small, medium,
  large, huge, ripe). Style cartoon illustration avec ink lines.
- État : 6 _Pot avec stage (null ou 0..4), watered, dryCounter, showingRipe.
- 3 boutons auto-targeting + Passer.
- Tier 1 actuel. Tier 2-4 = potager plus grand, semi-auto, auto.

### Mini-jeu bois

- Grille 5×4 procédurale, énergie 10, ramène le bois récolté au compteur.
- Tier 1 actuel. Tier 2-4 = hachette, hache+scie, charrette.

### Filtre eau (PAS de mini-jeu — interaction inline)

- L'asset filter dans le wagon = `tank_0..11.png` (12 frames empty→full).
- État `GameState.waterTankGlasses` (0-5).
- Bouton action au filtre :
  - tank vide → fill (anim 1.8s, monte de 0 à 11 frames, 5 verres
    stockés)
  - tank ≥ 1 → drink (anim use_back + drink, -1 verre, restoreThirst)
- Anim de niveau via `_filterDisplayLevel` interpolé entre changements.

### Carte du monde (map_screen.dart)

- 14 gares en placement libre (x,y normalisés), spline Catmull-Rom
  arc-length param, rails marron, traverses procédurales.
- 5 **wood points** (orange park icon) entre villes, cliquables → ouvre
  WoodGameTier1.
- Silhouettes ombres animées : zombies zone froide, loups/rats zone
  chaude, corbeaux ciel.
- Train procédural détaillé : loco + 2 wagons attachés, smoke trail.
- HUD : zone (froide/chaude/transition) + prochaine gare + ETA.

### Page d'accueil

- `title_bg.png` : ville glacée post-apo avec train + 2 wagons + aurore
  boréale + ruines colossales gelées.
- Fade-in 1.5s, titre "Train Cosy" + sous-titre "Un voyage dans le monde
  mort", boutons Continuer/Nouvelle partie.
- Transition 800ms vers le wagon au tap.

---

## Outils Python (`tools/`)

- `key_out_black.py` — chroma-key fond noir → transparence.
- `split_character_sheet.py` — découpe une sheet horizontale en N PNGs.
- `trim_character_dividers.py` — retire les bandes grises.
- `generate_app_icons.py` — redimensionne `app_icon.png` aux 15 tailles iOS.
- `measure_sprite_bboxes.py` — calcul bbox / feetRatio pour les sprites.

---

## État du contenu

**Animations héroïne 49-frames — 16 câblées** : walk_right, idle_right,
sleep_right, dance, pickup, yawn, stretch, look_window, read, wake_up,
door_push, warm_hands, carry_walk, cook, drink, garden_tend, wake_up_clean
(precache seul), + open_door (20fr), crouch (49fr), use_back (49fr de dos),
pet_dog (49fr).

**Animations chien (8)** : bark, eat, head_tilt, lay_down, sleep,
stretch_yawn, wag_tail, walk. + idle statique.

**Silhouettes humaines** : 13 PNG `assets/characters/silhouette_*.png`
découpées d'un sprite sheet généré (wanderer, backpack, mère+enfant,
fermier chapeau, pillard, marcheur canne, pousseur charrette, couple,
soldat, guetteur, agenouillé, agitant bras, vieux 2 cannes).

**Plantes** : 24 PNG `assets/plants/{tomato,carrot,eggplant,lettuce}_*.png`
× 6 stades (sprout/small/medium/large/huge/ripe).

**Tank eau** : 12 PNG `assets/objects/tank_*.png` empty→full.

**Backgrounds** : wagon variants (dirty/swept/windowed/clean), sky variants
(jour/nuit/snow/night), horizon variants (a-g warm/cold/transition),
locomotive, foreground variants, map_route, **hydro_tank**, **title_bg**.

**Objets statiques** : bed, bowl_empty, bowl_full, commode, dog_idle,
firstaid, garden, notebook, table.

**Objets animés** : hydro (49fr), lamp (49fr), stove (49fr).

**Audio** : tous présents dans `assets/audio/` :
- `ambient_train.mp3` (loop, actif)
- `music_day/night/cold.mp3` (musique **désactivée**, à refaire)
- `fire_crackle.mp3` (loop, actif en loco)
- 9 SFX : door_open/close (désactivés), footstep, pickup, log_throw,
  drink, lamp_toggle, dog_bark, dog_pant

---

## Ce qui reste à faire

### Priorité haute — feedback utilisateur récent

1. **Refaire les musiques** — supprimées car « rock pas adapté ». Reprendre
   les prompts Suno (déjà fournis dans une session précédente).
2. **Mini-jeu hydro v2** — actuellement 6 cups mais 2 actifs pour proto.
   L'utilisateur a validé le concept (Semer/Arroser/Récolter/Passer),
   reste à étoffer (multiples graines disponibles, mécanique d'eau qui
   se vide en arrosant, déblocage de plantes via story).
3. **Background filtre tier 2-4** — tier 1 = tank visible inline. Tier
   suivants à designer.
4. **Tank levels au plus juste** — vérifier que l'anim 1.8s rend bien.

### Priorité haute — mécaniques core

5. **Cycle jour/nuit narratif** lié à un vrai rythme (5-10 min réelles)
   avec transition visuelle sky/sky_night + comportements héroïne.
6. **Auto-consume** : quand stat trop basse, perso boit/mange auto depuis
   les compteurs (à designer avec user).
7. **Schedule autonomous** : perso suit un planning selon ses besoins
   (réveil, mange, lit, bois, dort) — user a demandé ça.

### Priorité moyenne — gameplay loop

8. **Tier 2-4 pour hydro / bois / filtre** : système de progression avec
   blueprints + crafting items rares trouvés en location.
9. **Système de déblocage progressif** : flags/items gating objets,
   locations, tenues.
10. **Mécanique vêtements** : ajouter outfits supplémentaires (assets
    + déblocage).
11. **Plus de Locations + chaînes Questions** : 11 gares vides à
    écrire + 5 nouvelles ajoutées (oasis, tour de guet, tunnel nord,
    camp refuge, pont suspendu).

### Priorité basse — polish & contenu

12. **Sauvegarde positions props** (stove adjust, etc.).
13. **Journal / monologue intérieur** lié au contexte.
14. **Événements aléatoires nuit** : crackWindow, etc.
15. **Transparence locomotive sur wagon_swept.png**.
16. **Objets encore absents** : radio à manivelle, sac à dos, jarres,
    bocaux.

---

## Communication avec l'utilisateur

- **Langue** : français, ton décontracté direct.
- **Style** : cash, pas de blabla, pas de flatterie.
- **TOUJOURS NUMÉROTER les listes / propositions / options** (1, 2, 3...).
- **Délégations explicites** :
  - Commit : OUI à chaque modification.
  - Décisions UX / esthétiques : NON, toujours proposer.
  - Génération d'assets via OpenArt / AutoSprite : c'est LUI qui génère,
    je fournis les prompts.
  - Drop de fichiers dans le repo : lui (Mac terminal ou iPad GitHub web).
- **Pas d'estimations de temps**.
- **Pas de mini-jeux modaux** pour eau (l'utilisateur n'aime pas).
  Préférer interaction inline avec l'asset (tap sur prop = action).

---

## Références d'inspiration

- **Plant Tycoon** — vue tableau de pots + drag graines (réf pour hydro).
- **Hay Day / Stardew Valley** — culture timer-based + indicateurs.
- **Spiritfarer** — cosy management hand-painted (réf esthétique).
- **Studio Ghibli** — Voyage de Chihiro (train), Château Ambulant,
  Princesse Mononoke (palette).
- **Lexploratrice2025** (YouTube wallpaper) — la réf historique clé.
