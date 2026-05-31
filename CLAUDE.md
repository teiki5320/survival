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

**État actuel (2026-05-30)** : prototype solide avec page d'accueil + 16 anims
héroïne + 8 anims chien + 4 parallax + silhouettes humaines + foreground life +
audio branché (sans musique) + carte avec spline 14 gares. **Mini-jeu hydro
(6 cups, sprites peints, mode ajuster)** + **filtre eau inline (tank animé)**.
Wood game retiré.

**🚨 GROSSE DÉCISION EN COURS** : direction gameplay. L'utilisateur s'inspire
de **Reigns** (mobile, swipe gauche/droite, choix narratifs courts, 4 stats à
équilibrer, runs courtes). Voir section "Direction Reigns" plus bas.

---

## Workflow technique

- **Repo** : `teiki5320/survival`. Branche : **`main` uniquement**.
- **CI** : Xcode Cloud watch `main`. Distribution TestFlight auto désactivée.
- **Xcode Cloud rouge** : ouvrir Erreur. Si "Preparing build for App Store"
  → bump `version:` dans pubspec. Si "PhaseScriptExecution failed" → Dart.
- **Bundle ID iOS** : `com.teiki5320.trainCosy`.
- **Flutter** : scaffold via `flutter create`, dossier `ios/` committé.
  ci_scripts dans `ios/ci_scripts/ci_post_clone.sh`.
- **Dev local** : Mac mini (`/Users/jeanperraudeau/survival`), iPhone 16 Plus.
- **iOS 26 beta + debug** : crash `EXC_BAD_ACCESS`. Parade : **toujours
  `flutter run --release`**.
- **Version actuelle** : `0.13.0+48` dans `pubspec.yaml`.
- **Dépendances** : `audioplayers: ^6.1.0`, `cupertino_icons: ^1.0.6`.

## Règles de commit / push

- **Commit + push à chaque modification** sans attendre validation.
- Push direct sur `main`, pas de PR.
- **Toujours bumper la version** à chaque push (au moins `+N`).

---

## Workflow assets

User génère via **OpenArt** (Nano Banana 2) ou **AutoSprite**.

Process classique image :
1. Génère dans OpenArt.
2. Drop le PNG dans le repo.
3. Dit « poussé ».
4. Je récupère, key out le fond, déplace vers `assets/`.

OpenArt **n'exporte pas vraiment en transparence** — fond blanc/noir baked-in.
Toujours demander fond solide blanc (#FFFFFF) ou noir (#000000), je keye.

**Règles AutoSprite** :
- **Jamais de preview**. Générer direct la version finale.
- **Valider le coût AVANT** toute dépense. Annoncer crédits.
- Tarif : `animate_asset` legendary 49 frames = 5 cred.

**MCP AutoSprite** : uniquement sur le Mac mini, pas sur le web.

---

## Architecture côté code

- `lib/main.dart` — App + `WagonScreen`. État global : night, _heroSpawnX,
  flags (_inLocomotive, _onMap, _inHydroGame, _inWardrobe, _doorPushing),
  HUD survie (hunger/thirst/fatigue + chips bois/eau/food), bouton action
  contextuel selon position. Routing : title → wagon/loco/map/wardrobe/hydro.
- `lib/widgets/title_screen.dart` — Page d'accueil avec fond ville glacée
  `title_bg.png`, titre, sous-titre, "Continuer" / "Nouvelle partie".
- `lib/widgets/side_scroll_scene.dart` (~2400 l.) — Scène wagon : 4 parallax
  (sky 80s / horizon 20s / mid 10s / foreground 8s), wagon image, héroïne +
  chien, props (hydro/lamp/stove/filter/table/notebook/firstaid/commode/bowl),
  silhouettes humaines + foreground life, animations atmosphère. **Filtre =
  asset tank dynamique** selon `waterTankGlasses` (6 frames 0→5).
- `lib/widgets/locomotive_scene.dart` — Cabine loco avec ramassage bûches.
- `lib/widgets/map_screen.dart` — Carte 14 gares, spline Catmull-Rom,
  train procédural. Plus de wood points (retirés).
- `lib/widgets/atmosphere.dart` (~1800 l.) — Tous les widgets atmo (24
  classes différentes).
- `lib/widgets/wardrobe_screen.dart` — 1 outfit pour l'instant.
- `lib/widgets/location_event_screen.dart` — Dialog event narratif.
- `lib/widgets/games/hydro_game.dart` — **MINI-JEU ACTUEL UNIQUE**. Tour
  hydroponique vue dessus (background `hydro_tank.png`). 6 cups, 4 stades
  (small/medium/large/huge) + ripe pour animation récolte. Boutons : Semer
  carotte + Passer un step. Tap plante mûre → harvest. **Mode ajuster
  intégré** (icône crayon top right) avec HUD coordonnées des 6 _Slot
  (x, y, size).
- `lib/models/game_state.dart` — Singleton ChangeNotifier. Sauvegarde JSON
  `dart:io`. State : énergie, hunger/thirst/fatigue, items, flags,
  unlocked, wagonStage, **waterTankGlasses (0-5)**. Anciens hydroSlots et
  waterJars + advanceFarm() inutilisés à présent (à nettoyer).
- `lib/services/audio_service.dart` — Singleton audio. setMusic désactivé
  (musique pas à refaire). startAmbientTrain/Fire + 9 playSfx.
- `lib/data/world.dart` — 3 Locations narratives initiales (à étoffer).
- `lib/data/anim_metrics.dart` — Métriques sprites perso.

### Précisions side-scroll

- Heroine bounds : `heroXMin = 0.22`, `heroXMax = 0.86`.
- 49 frames par anim. **16 anims héroïne câblées** : walk_right,
  idle_right, sleep_right, dance, pickup, yawn, stretch, look_window,
  read, wake_up, door_push, warm_hands, carry_walk, cook, drink,
  garden_tend, + open_door (20fr), crouch (49fr), use_back (49fr de dos),
  pet_dog (49fr).
- Métriques actuelles `crouch` scale 1.10, `pet_dog` scale 0.70
  (réduits plusieurs fois suite à demandes user).
- **Props actifs wagon** : hydro, lamp, stove, filter (= tank dynamique),
  table, notebook, firstaid, commode, bowl, dog statique.
- **Chien statique** + bouton action alterne pet_dog / crouch+wag_tail.
- **Spawn perso au retour** : sortie loco → heroXMin, sortie map → heroXMax.

### Locomotive

- Background `assets/background/locomotive.png` hard-mask keyé.
- Heroine height : `h * 0.44`.
- Woodpile à x=0.70, firebox à x=0.34.
- Pickup utilise `open_door` (14 frames clamp), throw = reverse + mirror.

### Mini-jeu hydro (TIER 1)

- Background : `assets/background/hydro_tank.png` (cuve hydro vue dessus,
  6 net cups vides, 3 cols × 2 rangs).
- Sprites peints : `assets/plants/{plant}_{stage}.png`.
  - **4 plantes** : tomato, carrot, eggplant, lettuce
  - **6 stades** : sprout, small, medium, large, huge, ripe
  - Cuts propres (depuis IMG_4917, gap detection auto)
- État local : 6 `_Pot` avec stage (null ou 0..3), showingRipe.
- 4 stades **visibles en croissance** : small, medium, large, huge.
- **Sprout retiré** (ressemblait trop à small).
- **Ripe** = sprite affiché brièvement (1.2s) au tap récolte.
- **2 boutons** : Semer carotte + Passer un step.
- **Tap sur plante mûre** → récolte (+15 food).
- **Mode ajuster** intégré : icône crayon top right, drag pour bouger,
  tap pour sélectionner, +/- pour taille, HUD coords affiché.
- Coordonnées finales bakées :
  - Pot 1: (0.295, 0.383) size=0.210
  - Pot 2: (0.500, 0.383) size=0.210
  - Pot 3: (0.704, 0.384) size=0.210
  - Pot 4: (0.292, 0.676) size=0.200
  - Pot 5: (0.498, 0.674) size=0.210
  - Pot 6: (0.706, 0.678) size=0.210
- `stageMult` retiré (slot.size contrôle direct la taille).
- Carotte uniquement câblée pour l'instant (les 3 autres plantes ont
  les sprites mais pas d'action de seed).

### Filtre eau (PAS de mini-jeu — interaction inline)

- L'asset filter dans le wagon = `assets/objects/tank_0..5.png`
  (6 frames, empty→full). Recut depuis la rangée du bas de IMG_4918.
- État `GameState.waterTankGlasses` (0-5).
- Bouton action au filtre :
  - tank vide → fill (anim 1.8s, monte de 0 à 5 frames, 5 verres
    stockés)
  - tank ≥ 1 → drink (anim use_back + drink, -1 verre, restoreThirst)
- Anim de niveau via `_filterDisplayLevel` interpolé entre changements.

### Carte du monde

- 14 gares en placement libre (x,y normalisés), spline Catmull-Rom
  arc-length param, rails marron, traverses procédurales.
- Silhouettes ombres animées : zombies froide, loups/rats chaude, corbeaux.
- Train procédural détaillé : loco + 2 wagons attachés, smoke trail.
- HUD : zone + prochaine gare + ETA.
- **Pas de wood points** (retirés avec le wood game).

### Page d'accueil

- `title_bg.png` : ville glacée post-apo avec train + 2 wagons + aurore.
- Fade-in 1.5s, "Train Cosy" + "Un voyage dans le monde mort".
- Boutons Continuer/Nouvelle partie.

---

## Outils Python (`tools/`)

- `key_out_black.py` — chroma-key noir → transparence.
- `split_character_sheet.py` — découpe sheet horizontale en N PNGs.
- `trim_character_dividers.py` — retire bandes grises.
- `generate_app_icons.py` — 15 tailles iOS.
- `measure_sprite_bboxes.py` — bbox / feetRatio.

---

## État du contenu

**Animations héroïne 49-frames — 16 câblées** : walk_right, idle_right,
sleep_right, dance, pickup, yawn, stretch, look_window, read, wake_up,
door_push, warm_hands, carry_walk, cook, drink, garden_tend, wake_up_clean
(precache seul), + open_door (20fr), crouch (49fr), use_back (49fr de dos),
pet_dog (49fr).

**Animations chien (8)** : bark, eat, head_tilt, lay_down, sleep,
stretch_yawn, wag_tail, walk. + idle statique.

**Silhouettes humaines** : 13 PNG `assets/characters/silhouette_*.png`.

**Plantes** : 24 PNG `assets/plants/{tomato,carrot,eggplant,lettuce}_*.png`
× 6 stades. Cuts propres.

**Tank eau** : 6 PNG `assets/objects/tank_*.png` empty→full.

**Backgrounds** : wagon variants (dirty/swept/windowed/clean), sky variants,
horizon variants (a-g warm/cold/transition), locomotive, foreground variants,
map_route, **hydro_tank**, **title_bg**.

**Audio** : tous présents dans `assets/audio/` :
- `ambient_train.mp3` (loop, actif)
- `music_day/night/cold.mp3` (musique **désactivée**, à refaire)
- `fire_crackle.mp3` (loop, actif en loco)
- 9 SFX : door_open/close (désactivés), footstep, pickup, log_throw,
  drink, lamp_toggle, dog_bark, dog_pant

---

## 🎯 Direction Reigns — décision en cours

L'utilisateur veut s'inspirer de **Reigns** (mobile, ~2016). Caractéristiques :
- Swipe gauche/droite (binaire) sur des **cartes événements**
- 4 stats à équilibrer, mort si une atteint 0 ou 100%
- Sessions courtes (5-15 min par "règne")
- Multi-personnages récurrents avec mini-arcs
- Hautement rejouable, plusieurs fins

### Adaptation Train Cosy proposée

**Boucle** :
- Train roule. Cartes événements apparaissent toutes les 30s-1min.
- 2 choix par carte (gauche/droite).
- 4 stats à équilibrer : **Faim**, **Soif**, **Bois loco**, **Moral**.
- Si un stat à 0 (ou 100%) → fin du voyage (mort/abandon/incendie).
- Mort = restart, persistance partielle (cartes vues, gares déverrouillées).

**Trame** :
- 14 gares = 14 grandes étapes narratives obligatoires (déjà sur la map)
- Entre 2 gares : ~10 cartes événements aléatoires (météo, passagers,
  loco, souvenirs)
- À chaque gare : carte spéciale (2 ou 3 choix narratifs lourds)

**Prémisse à choisir** (cœur émotionnel du jeu) :
1. Shen **fuit** un passé (faute, perte)
2. Shen **cherche** quelqu'un (famille, mentor, amour)
3. Shen **livre** quelque chose (message, objet sacré, enfant)
4. Shen a **oublié** (amnésie post-traumatique)
5. Shen **attend** une fin (acceptation, dernière promenade)

**Décision attendue** :
- L'utilisateur n'a PAS encore choisi la prémisse.
- L'utilisateur n'a PAS encore décidé si on garde le side-scroller wagon
  en background des cartes, ou si on bascule full Reigns visuel.
- L'utilisateur n'a PAS encore validé le concept Reigns définitivement.

### Structure narrative à construire (si Reigns validé)

À écrire avec l'utilisateur (la narrative est explicitement reportée
mais le squelette doit être prêt) :
- 14 scènes principales (1 par gare)
- 3-5 personnages récurrents avec leurs arcs (3-4 apparitions chacun)
- 3-5 fins selon bilan global
- ~100 cartes de remplissage (entre-gares, événements ambient/tactiques)

Total estimé : **80-100 scènes courtes** pour avoir un jeu Reigns
complet et profond.

---

## Ce qui reste à faire

### 🚨 Priorité absolue — décision direction gameplay

1. **Choisir : Reigns-like ou autre direction ?** L'utilisateur a montré
   intérêt pour Reigns mais rien validé. Reprendre la discussion :
   prémisse, branches, personnages récurrents, fins.

### Priorité haute — feedback utilisateur récent

2. **Refaire les musiques** — supprimées car « rock pas adapté ».
3. **Brancher les 3 autres plantes** (tomato, eggplant, lettuce) dans
   hydro_game (sprites prêts, juste UI à ajouter).
4. **Mécaniques narratives** à designer (Reigns ou autre).

### Priorité moyenne — qualité de vie

5. **Nettoyer `hydroSlots` et `waterJars`** non utilisés dans game_state.dart.
6. **Auto-consume** : si stats trop basses, Shen mange/boit auto depuis
   les compteurs.
7. **Cycle jour/nuit narratif** lié à un vrai rythme (à designer selon
   direction gameplay).
8. **Schedule autonomous** : Shen suit un planning si on part en routine.

### Priorité basse — polish & contenu

9. **Tier 2-4 pour hydro / filtre** : système de progression via blueprints.
10. **Plus de Locations + chaînes Questions** (les 14 gares).
11. **Sauvegarde positions props** (stove, etc.).
12. **Mécanique vêtements** : outfits supplémentaires.
13. **Transparence locomotive sur wagon_swept.png**.
14. **Objets encore absents** : radio à manivelle, sac à dos, jarres, bocaux.

---

## Communication avec l'utilisateur

- **Langue** : français, ton décontracté direct.
- **Style** : cash, pas de blabla, pas de flatterie.
- **TOUJOURS NUMÉROTER** les listes / propositions / options (1, 2, 3...).
- **Délégations explicites** :
  - Commit : OUI à chaque modification.
  - Décisions UX / esthétiques : NON, toujours proposer plusieurs options.
  - Génération d'assets via OpenArt / AutoSprite : LUI génère, je fournis
    les prompts.
  - Drop de fichiers dans le repo : lui (Mac terminal ou iPad GitHub web).
- **Pas d'estimations de temps**.
- **Pas de mini-jeux modaux** pour eau (l'utilisateur n'aime pas).
  Préférer interaction inline avec l'asset (tap sur prop = action).
- **L'utilisateur préfère les itérations rapides** : commit même quand
  c'est imparfait, on ajuste après.
- **L'utilisateur se frustre vite** si on fait des allers-retours sur
  des choses déjà faites. Mieux vaut proposer une solution complète que
  redemander des infos.

---

## Notes pour la prochaine session

**Dernier sujet abordé** : direction gameplay inspirée de **Reigns**. La
discussion porte sur :
- Le concept de cartes événements swipe gauche/droite
- 4 stats à équilibrer (faim, soif, bois, moral)
- 5 prémisses possibles pour Shen
- Structure narrative avec 14 gares + cartes de remplissage + personnages
  récurrents + fins multiples

**À reprendre** : continuer la discussion sur la prémisse à choisir, puis
décider si on commit Reigns ou pas, puis si oui commencer à structurer la
trame narrative (mais l'utilisateur dit "narration plus tard").

**À ne PAS faire** :
- Recommencer à proposer des mini-jeux variés (hydro/water/wood). Le hydro
  est OK, le filtre eau OK inline, le wood retiré. C'est figé.
- Recommencer à discuter du temps dans le jeu en termes abstraits. Le
  user a choisi de penser en termes "Reigns-like sessions courtes".
- Refaire la découpe des sprites plantes ou tank (cuts propres confirmés).

---

## Références d'inspiration

- **Reigns** — swipe + cartes + équilibrage stats (réf MAJEURE actuelle).
- **Plant Tycoon** — vue tableau de pots + drag graines (réf pour hydro).
- **Hay Day / Stardew Valley** — culture timer-based + indicateurs.
- **Spiritfarer** — cosy management hand-painted (réf esthétique).
- **80 Days** — voyage + cartes narratives + choix.
- **Studio Ghibli** — Voyage de Chihiro (train), Château Ambulant,
  Princesse Mononoke (palette).
- **Lexploratrice2025** (YouTube wallpaper) — la réf historique clé.
