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

**État actuel (2026-06-09, build 0.99.9+213)** : prototype riche + onboarding.
Wagon 1 vivant (Shen, + sœur/chien quand débloqués), **2e wagon (cellier)** à
gagner (gare 6), **moteur de cartes** (14 gares, cartes inter-gares FIXES) +
combat aux gares (`roof_defense_game.dart`, mode DUEL = le jeu). **Cinématique
d'ouverture + bulles de tuto**. **Mode debug** unifié (bouton bas-gauche) :
OFF = vrai jeu (wagon vide/abîmé, objets/persos débloqués au fil de l'histoire,
stats de départ basses), ON = tout affiché + outils. Map UNIQUEMENT via la loco,
cartes via « Continuer le voyage ». Thermomètre auto, musique réactivée.
Voir le bloc « GROSSE SESSION 2026-06-09 » plus bas pour le détail.

**✅ DIRECTION VALIDÉE (2026-05-31)** : gameplay **Reigns-like** + histoire
canon (Shen fuit la 3e GM, cherche sa famille, train → refuge nord). Le
**moteur de cartes existe** (`lib/widgets/cards_screen.dart`, données
`lib/data/cards_data.dart`, 4 stats soif/faim/bois/moral, fins). Reste à
écrire/équilibrer le contenu + relier la map au gameplay.

### Gros points faits cette session (2026-06-02→03)
- **Wagon 1 = 2 stages** (windowed/clean). Posé sur les rails via un
  `Transform.translate` qui descend tout le bloc intérieur (l'image était
  cadrée trop haut).
- **2e wagon (cellier)** : `SideScrollScene(secondWagon: true)`. Props posables
  (baignoire, panneau douche, pommeau, 2 lanternes) en **mode AJUSTER** (FAB
  crayon, cellier seulement) : 1 doigt = déplacer, **pincer = redimensionner**,
  HUD des coordonnées. Coords/persistées dans GameState. Lanternes = FireGlow
  la nuit. Mouvement de Shen bloqué près de la porte tant que le cellier est en
  désordre (stage 0).
- **Bain** : près de la baignoire → bouton → Shen se tourne (use_back court) →
  anim `bath_1..8` (boucle le câlin... non : entrée→détente, tient). **Douche**
  : près du panneau → tour → `shower_1..8` (shampoing long puis pose lavée),
  Shen sous le **pommeau**, eau qui coule (pommeau `showerhead_1..6`) seulement
  pendant la douche, + **vapeur** (`_SteamPainter`).
- **Sœur + chien MOBILES** : `_SisterCharacter` / `_DogCharacter` se baladent
  (sister_walk / dog_walk) vers une position aléatoire, sinon anim sur place ;
  position vivante rapportée (`_sisterX`/`_dogX` + callbacks `onSisterX`/
  `onDogX` vers main) pour que les actions suivent.
- **Duos sœur+Shen** : lecture (`readduo_1..10`) et câlin (`sister_hug_1..4`),
  déclenchés par proximité (auto) OU **bouton action** (test, alterne). Pendant
  le duo, les 2 solos disparaissent ; fin via `setState` (sinon le sprite
  figé restait + le solo réapparaissait par-dessus — bug corrigé).
- **Chien** : caresse = sprite `petdog_1..9` (Shen + husky, approche→câlin),
  remplace solo Shen + chien statique. (Ancien `pet_dog` chiot retiré.)
- **Froid/Thermomètre** : `cabinTemp` + `feltCold` (seuil `coldThreshold` =
  wagonStage + habits ; le **poêle réchauffe désormais `cabinTemp`**, plus le
  seuil). Froid **bloque le GAIN de moral**. Frissons (`cold`/`sister_cold`).
  **✅ AUTO (0.93.0)** : `computeAutoCabinTemp()` = zone map + météo + nuit +
  feu (poêle alimenté en bois). Recalculé sur changement de gare/météo/nuit/
  bois. Le **bouton test manuel** ne s'affiche plus qu'en **mode debug**.
- **Découpe sprites** : technique **traits rouges** — l'utilisateur trace des
  lignes rouges (#FF0000) entre les frames sur la sheet (fond vert), je coupe
  pile dessus + normalise (bottom-center). Outils : `tools/key_out_green.py`,
  `cut_bath_shower.py`, `cut_duos_cold.py`, `recut_clean.py`.
- Bruits de pas **retirés**. Écran de chargement refait (barre + train + n° de
  build affiché « build X.Y.Z »). Colonne de FAB **scrollable** (paysage).

### Gros points faits cette session (2026-06-04→05) — COMBAT + intégration

**🎯 NOUVEAU MINI-JEU DE COMBAT** : `lib/widgets/games/roof_defense_game.dart`
(~1900 l.). C'est LE gros morceau. Shen défend le train (vu à gauche, **vue de
loin**), les pillards arrivent par la droite, on **tire des pierres en arc**
(viser = maintenir le doigt → arc de cercle apparaît, relâcher → gravité).
- **Décor** : `assets/background/gare_shoot.png` (1584×672, vue de loin, quai
  long, train petit à gauche). `BoxFit.contain` + tout le gameplay ancré au
  décor en **« scene units »** (origine = coin haut-gauche du décor, 1 unit =
  hauteur affichée `_S`, x = fraction × `_imgA` où `_imgA = 1584/672`).
- **Géométrie clé** : `_trainEdgeX = 0.24` (bord du train = ligne de mêlée),
  pierres partent de la trappe arrière `_muzX=0.16 / _muzY=0.64`, sol
  `_groundY=0.865`. Pillards spawn à `_imgA+0.14` à droite, marchent vers
  la gauche, **disparaissent derrière le wagon** (clip `_wagonClipFrac`).
- **Tir** : `_g=1.9`, `_power=9.0`, `_maxSpeed=3.4`, `_reload=0.26`. Système
  rendu plus **sensible** + projectiles **réduits** (demandes user).
- **Types de pillards** (`_PillType`) : `basic` (1 hp), `lanceur` (lance des
  cailloux à distance `_throwRange=0.55` toutes `_throwPeriod=1.3`s, ne touche
  pas le train de près), `brute` (lent ×0.45, `_bruteHp=4` pierres pour tuer,
  coups de hache), `boss` (vague finale, -2 cœurs/coup). Sprites :
  `pillard1_walk/die`, `brute_walk/attack`, `lanceur_walk/throw`. **Les walk
  sont mirroitées** (sprites tournés vers la droite), **les die sont
  pré-flippées** (pas de miroir).
- **Mêlée** : un pillard qui atteint `_trainEdgeX` passe `melee=true` et frappe
  le train **-1 cœur toutes `_meleePeriod=1.1`s**. Train = **5 cœurs**
  (`_maxHp`, +1/+2 via upgrades/perks).
- **Machine à états** (`_Phase`) : `menu / atelier / playing / chest / perk /
  gameover`. **2 modes** (`_Mode`) : `campaign` (5 vagues, `_campaignWaves`) et
  `endless` (survie infinie, bouton « Entraînement (survie) », scrap ÷2).
- **Économie / méta-progression (addictif)** : chaque ennemi mort **lâche de
  la ferraille au sol** → **cliquer dessus dans les 3 s** pour la ramasser
  (`_Loot`, `_collectAt`). Ferraille → **atelier** (upgrades persistés dans
  `GameState.shootUpgrades` : cœurs, reload, etc.). Coffres (`chest`) + **perks
  à choisir** (`perk`) entre vagues (ricochet, autofire, split, +cœurs…).
  **Frénésie** : streak de kills → multiplicateur + bandeau « FRÉNÉSIE ! ».
- **Boucle addictive renforcée (2026-06-05, build 0.72.0)** :
  - **Évolution d'arme** : choisir **3× le même perk** dans une run le fait
    « évoluer » (bonus unique + callout « ✦ ÉVOLUTION ✦ »). `_perkLevels` /
    `_evolved` / `_applyEvolution`.
  - **Atelier — mécaniques (pas juste des %)** : `magnet` (aimant : butin
    auto-ramassé), `shield` (bouclier de wagon : encaisse 1 coup gratuit par
    vague, rechargé en début de vague), `bomb` (bombe écran, 1/vague, FAB 💣
    dans le HUD). Clés dans `shootUpgrades`, lues dans `_applyMeta`.
  - **Near-miss** : perdu sur la **dernière vague** → bandeau « Si près ! » +
    15 ferraille de consolation (`_nearMiss`).
  - **Pillard doré** : s'enfuit s'il atteint le train (jackpot **perdu** → tue-le
    vite), butin 35, spawn dès vague 1 (8 %).
  - **Étoiles par gare** : score → 0-3 ⭐ (`GameState.starsForScore`,
    `gareStars`, `totalGareStars` /42), affichées à l'écran de fin du combat
    de gare + **collection 14 gares** dans l'overlay « Quotidien & Gares ».
  - **Quotidien (rétention)** : `GameState` coffre du jour (`claimDailyChest`)
    + 3 missions journalières (`dailyMissions` : kills/perfect/scrap,
    `reportCombat` alimente, `claimDailyMission`), reset au changement de jour,
    persistés. Overlay `_Phase.progress` (bouton menu « Quotidien & Gares 🎁 »
    avec pastille verte si récompense dispo).
- **Difficulté calibrée par SIMULATION** (`/tmp/sim.py`, 2000 runs/profil de
  skill) : vagues campagne =
  `[(6,0.16,0.80),(10,0.23,0.64),(14,0.33,0.48),(18,0.45,0.38),(23,0.58,0.30)]`
  (count, vitesse, intervalle). Cible atteinte : joueur **correct perd ~70 %**
  (→ pousse à upgrader = boucle), **bon gagne ~90 %**, **expert toujours**. Le
  décor vue de loin allonge la distance → vitesses montées en conséquence.
- **Lancement** : flag `_inShootGame` dans `main.dart` + FAB `open_shoot`,
  rendu dans l'`AnimatedSwitcher`.

**⚠️ BUGS COMBAT RÉSOLUS (à ne pas refaire)** :
- **Écran BLEU / « train tombé en 10 s » sans erreur** : le `Stack` du combat
  (enfants tous `Positioned`) sous les **contraintes lâches** de
  l'`AnimatedSwitcher` s'effondrait en 0×0. **FIX : `fit: StackFit.expand`**
  sur le Stack principal. (Un test headless normal ne le voit PAS — il faut
  wrapper dans un AnimatedSwitcher pour le reproduire.)
- **Freeze (ConcurrentModificationError)** : le perk *split* faisait
  `_stones.add()` pendant `for (final s in _stones)`. **FIX** : itérer
  `List.of(_stones)`, collecter dans `frags`, `addAll` **après** la boucle.
  Gardes division-par-zéro dans ricochet/autofire.
- **Crash OOM iOS** : 1650 PNG / ~198 Mo, cache à 1,5 Go + precache-all.
  **FIX** : cache image `450 Mo / 800 entrées` (`main.dart`), precache
  **whitelist** (`loading_screen._essential` : backgrounds/objects +
  characters `idle_right_/walk_right_/heroine_front/sister_idle_/sister_walk_`),
  `cacheWidth: 256` sur les sprites combat. + `ErrorWidget.builder` visible
  (panneau rouge sombre affichant l'exception).

**Autres points session** :
- **Nouveaux sprites petite sœur** 49 frames : `sister_walk` (profil propre,
  l'ancien était un turn-around qui partait à l'envers), `sister_idle`,
  `sister_sleep` **sur le lit** (miroitée vers l'oreiller, taille réduite
  `bedWidth*0.66`). Ménage des doublons fait. Idle quand elle ne bouge pas.
- **Nuages** au-dessus du wagon **retirés** (coupés). **Bulles de pensée** de
  Shen descendues (`heroTopY` 0.46, étaient trop hautes).
- **Gating progressif des objets** : `side_scroll_scene._propUnlocked` +
  `_bedUnlocked` peuvent masquer lit/filtre/hydro tant que l'histoire ne les a
  pas débloqués (flags `asset_bed`/`asset_filter`/`asset_hydro` posés dans
  `cards_data.dart` : gare 1 = lit, gare 4 = filtre, gare 10 = hydro/serre).
  **✅ REBRANCHÉ (0.93.0)** : `_showAllProps` = `GameState.debugMode` (getter).
  En jeu normal les objets apparaissent au fil de l'histoire ; en mode debug
  tout s'affiche pour vérifier le rendu.

---

## 🐞 Mode debug (0.93.x) — ⚠️ RÈGLE D'OR

**Mode JEU (debug OFF) = LE VRAI JEU** : train **abîmé + VIDE** à l'arrivée
(aucun objet), **AUCUN outil de réglage/perso visible**, Shen **seule** (pas de
sœur ni chien tant que l'histoire ne les amène pas). **Mode DEBUG (🐞) = TOUT
remis** : tous les objets + sœur + chien (pour tester les anims) + tous les
outils de réglage. Un **seul interrupteur** (`GameState.debugMode`, persisté),
bouton 🐞 discret **bas-gauche** de l'écran wagon (vert si actif).

Ce que le debug gate (et qui DOIT rester invisible en jeu) :
- FAB wagon : démarrer/arrêter train, nettoyer (wagonStage), jour/nuit,
  température (test), danser, ajuster props cellier (`w2_adjust`).
- `side_scroll_scene._showAllProps` → en jeu, `_propUnlocked(key)` = flag
  `asset_<key>` (wagon VIDE par défaut). `_dogShown`=`aLeChien`,
  `_sisterShown`=`aLaSoeur`.
- Ajustement carte gares (`map_screen.map_adjust`), canon combat
  (`roof_defense.shoot_adjust`), cups hydro, carte loco (`loco_map_adjust`).
- En jeu normal : température **auto**, objets/compagnons **progressifs**.

**⚠️ COMBAT = DUEL, PAS la campagne.** `_duelTest` est **`true` en permanence**
(le duel réglé au feeling EST le jeu). Le debug NE change PAS la mécanique de
combat. Ne JAMAIS rebrancher `_duelTest` sur `debugMode` (ça avait fait revenir
l'ancienne campagne = régression).

**🎯 DIRECTION COMBAT (à terme)** : **10 sessions de duel par gare**, en
escalade. Ex. gare 1 : duel 1 = 1 pillard proche ; duel 2 = 1 pillard plus
loin ; duel 3 = 2 pillards ; … ; **duel 10 = boss**. Chaque gare a sa propre
courbe de 10 duels.

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
- **Version actuelle** : `0.99.9+213` dans `pubspec.yaml`. Le **n° de build**
  s'affiche en bas de l'écran de chargement (`build X.Y.Z`, hardcodé dans
  `loading_screen.dart` — à bumper avec la version) pour vérifier quelle build
  TestFlight tourne (il y a un délai Xcode Cloud → TestFlight).
- **Flutter dispo dans l'env web** : non par défaut, mais on peut télécharger
  le SDK Dart + cloner Flutter 3.41.9 dans `/tmp` pour lancer `flutter analyze`
  avant push (fait régulièrement → 0 erreur avant chaque commit).
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

**RÈGLE PROMPTS AVEC RÉFÉRENCE** : quand une image est mise en référence, NE
PAS redécrire son contenu (style, perspective, proportions, couleurs…). Le
prompt ne décrit QUE les différences / ce qui change par rapport à la réf.

**Règles AutoSprite** :
- **Jamais de preview**. Générer direct la version finale.
- **Valider le coût AVANT** toute dépense. Annoncer crédits.
- Tarif : `animate_asset` legendary 49 frames = 5 cred.

**MCP AutoSprite** : uniquement sur le Mac mini, pas sur le web.

---

## Architecture côté code

- `lib/main.dart` — App + `WagonScreen`. État global : night, _heroSpawnX,
  flags (`_inLocomotive`, `_inWagon2`, `_onMap`, `_inHydroGame`, `_inWardrobe`,
  `_inCards`, `_doorPushing`), HUD (StatRingsBar + **thermomètre**), bouton
  action **contextuel** selon position + tokens (`_bathToken`, `_showerToken`,
  `_petDogToken`, `_duoToken`...), colonne de FAB **scrollable**.
  - **Navigation portes** : wagon 1 porte gauche → loco, porte droite → wagon
    2 ; wagon 2 porte gauche → wagon 1. `_pendingDoor` route le `_onDoorPushDone`.
    La **carte** et les **cartes** sont sur leurs propres FAB.
  - **Positions vivantes** : `_sisterLiveX`/`_dogLiveX` (màj via callbacks
    `onSisterX`/`onDogX`) → `_atSister`/`_atDog` suivent leur déplacement.
  - **Thermomètre** : `_thermometer()` (HUD haut-gauche) + FAB test qui cycle
    chaud/frais/gel (`GameState.setCabinTemp`).
- `lib/widgets/title_screen.dart` — Page d'accueil avec fond ville glacée
  `title_bg.png`, titre, sous-titre, "Continuer" / "Nouvelle partie".
- `lib/widgets/side_scroll_scene.dart` (~2400 l.) — Scène wagon : 4 parallax
  (sky 80s / horizon 20s / mid 10s / foreground 8s), wagon image, héroïne +
  chien, props (hydro/lamp/stove/filter/notebook/firstaid/bowl),
  silhouettes humaines + foreground life, animations atmosphère. **Filtre =
  asset tank dynamique** selon `waterTankGlasses` (6 frames 0→5).
  - **Wagon = 2 stages** (windowed/clean) ; dirty+swept retirés.
  - **`secondWagon: true`** = **cellier** : background `wagon2_messy`/`_clean`,
    props wagon1 masqués. Props posables : **baignoire, panneau douche,
    pommeau, 2 lanternes** (`_buildWagon2Props`, drag+pincer en `wagon2Adjust`,
    coords dans GameState). feetY plus bas (sol dessiné plus bas).
  - **Autonomie Shen** : `_autonomyTick` (~14s) lit les jauges (boit si soif…)
    — cosmétique. Frissonne si `feltCold`.
  - **Sœur/chien MOBILES** : `_SisterCharacter`/`_DogCharacter` se baladent
    (2 controllers : frames + déplacement), rapportent leur x via `onSettled`.
  - **Duos** (`_duoActive`, `_duoAnim` = readduo/sister_hug), **bain**
    (`_bathing`), **douche** (`_showering`), **caresse chien** (`_petDog`) :
    states qui masquent les solos + jouent un sprite dédié, **fin via
    setState** (sinon sprite figé qui reste). Tokens depuis main.
  - `_SteamPainter` = vapeur (bain/douche). FireGlow lanternes la nuit.
- **Anims persos** (`assets/characters/`) : héroïne (walk_right, idle_right,
  drink, read, dance, warm_hands, carry_walk, yawn, stretch, pickup,
  sleep_right, use_back, door_push, open_door, crouch, wake_up, **cold**) ;
  **bath_1..8, shower_1..8, petdog_1..9, readduo_1..10, sister_hug_1..4,
  cold_1..8, sister_cold_1..8, sister_dance/walk**. **Retirés** : cook,
  garden_tend, look_window, sister_read, pet_dog (chiot), hugduo,
  sister_hug_dog, sister_pet_dog.
- `lib/widgets/cards_screen.dart` + `lib/data/cards_data.dart` — **moteur de
  cartes Reigns** (swipe, 2 choix, effets stats, flags, fins). `tools/
  sim_game.py` rejoue 4000 runs pour équilibrer.
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
- `lib/models/game_state.dart` — Singleton ChangeNotifier. Sauvegarde JSON.
  State : 4 jauges cartes (cardSoif/Faim/Bois/Moral + `nudgeCardStat`),
  items, flags, wagonStage (0/1), wagon2Stage, `waterTankGlasses` (0-5),
  **coords props cellier** (bathX/Y/H, showerPanelX/Y/H, showerHeadX/Y/H,
  wagon2LampA/B x/y/H), **thermomètre** (`cabinTemp`, `stoveInstalled`,
  `outfitWarmth` → `coldThreshold`/`feltCold`/`coldness`, `setCabinTemp`).
  `nudgeCardStat('moral', +n)` est **bloqué si `feltCold`** (froid = pas de
  gain de moral). **Combat** : `scrap` (ferraille), `shootUpgrades`
  (Map<String,int> upgrades atelier persistés), `shootWeaponLevel`,
  `shootBestStars`, `shootBestScore`. **Flags histoire** : `cardFlags`
  (Set<String> persisté, contient les `asset_bed/filter/hydro`). Anciens
  hydroSlots/waterJars à nettoyer.
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
- **Props actifs wagon 1** : hydro, lamp, stove, filter (= tank dynamique),
  notebook, firstaid, bowl, dog statique. (table biscuits RETIRÉE ;
  **armoire/commode DÉPLACÉE dans le wagon 2/cellier**, placeable via
  `w2_adjust`, tap = garde-robe — coords `GameState.wagon2Commode*`.)
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

### Mini-jeu de combat aux gares (`roof_defense_game.dart`)

Voir le bloc de session 2026-06-04→05 ci-dessus pour les détails complets
(types de pillards, géométrie scene-units, économie ferraille, bugs résolus).
Résumé : tower-defense en arc, Shen défend le train, 5 vagues campagne ou
survie infinie, atelier d'upgrades payé en ferraille, perks/coffres entre
vagues, frénésie. Décor `gare_shoot.png` vue de loin.

**🎯 VISION D'INTÉGRATION (validée, PAS encore câblée)** — le combat doit se
brancher sur l'histoire :
1. Entre chaque gare : **~10 cartes narratives** (Reigns) qui font avancer
   l'histoire ET **débloquent des objets** dans le wagon (lit → filtre → hydro,
   sentiment de progression). Flags `asset_*` déjà posés dans `cards_data`.
2. À **chaque gare = un combat**. Le **score /100** du combat :
   - donne des **ressources** (bois / eau / nourriture) injectées dans les
     stats Reigns,
   - **branche l'histoire** (ex. bon score gare 5 → on sauve la sœur).
3. **~20 parties** pour atteindre 100 % de score sur une gare (rejouabilité).
4. **Chaque gare doit avoir SA propre idée** de combat (14 gares = 14 angles).
5. **Ferraille** = monnaie de jeu (atelier). **Boutique IAP** prévue
   (4,99 € = 500 ferraille). **ÉTHIQUE : l'argent réel ne doit JAMAIS bloquer
   l'histoire** — seulement accélérer le confort de combat.

**✅ CÂBLAGE COMBAT↔GARE↔SCORE FAIT (2026-06-05, build 0.71.0)** :
- `RoofDefenseGame` **mode gare** : si `onResult` fourni → démarre direct en
  campagne (pas de menu), calcule `_score100` (gagné = 70..100 selon cœurs
  restants ; perdu = 0..65 selon vagues+kills), écran de fin **« Récolter et
  continuer »** (→ `onResult(score100)`) / **« Réessayer »**, bouton abandon
  (= défense perdue). Le lancement standalone (FAB `open_shoot` dans main) reste
  en **mode menu** (pas d'`onResult`).
- `GameState.applyCombatRewards(gareIndex, score100)` : score → **ressources**
  (bois/eau/faim/moral, loot réel non atténué) + **flags de tier** sur
  `cardFlags` (`combatTierHigh/Mid/Low` reset à chaque combat, `combatGood_N`
  si ≥70, `combatDone_N`) + **`gareBestScore`** (Map index→/100, persisté =
  méta « 100 % en ~20 parties »).
- `ReignsEngine` : getter `current` + `rebuildGareCards()` (re-résout la
  variante de gare avec les flags de tier APRÈS le combat).
- `CardsScreen` : `_presentCurrentCard()` lance le **combat plein écran**
  (`Positioned.fill` → contraintes tight, pas de piège AnimatedSwitcher) à
  l'arrivée d'une gare **non encore défendue** (sauf **gare tuto idx 0**),
  puis `_onCombatResult` applique les récompenses, rebuild, révèle la carte.
- **Exemple de branche** : gare 3 (Halte 47, pillards) a un beat réactif —
  `combatTierHigh` = wagon intact + butin, `combatTierLow` = dégâts à colmater.

**Reste à faire côté intégration** : boutique IAP (4,99 €=500 ferraille,
confort seulement), une **idée de combat distincte par gare**, et rebrancher
`_showAllProps=false`.

**✅ CONTENU CARTES ÉTOFFÉ (2026-06-05, build 0.76.0)** — `cards_data.dart` :
- **~10 fillers par segment** (123 au total, contre 71 avant) -> bien plus de
  variété entre runs. drawCount reste à 4 (balance simulée préservée).
- **Arcs persos câblés via `requires`/flags** : **chien** (`aLeChien` : garde,
  réconfort, trouvailles), **Le Vieux** (`leVieuxABord` → enseigne la loco,
  raconte sa fille, puis descend au camp gare 6 = `vieuxParti`), **radio**
  (`aLaRadio` trouvée gare 4 → chaîne `radio1`(g5)/`radio2`(g7)/`radio3`(g9),
  la voix se révèle être maman), **sœur** (`aLaSoeur` : cabane, billes, fleur,
  promesses).
- **Gares 5 et 11 branchées sur le combat** (comme gare 3) : `combatTierHigh`
  /`combatTierLow` changent l'état où on retrouve la sœur (g5) et l'issue du
  barrage (g11).
- **5e fin = SECRÈTE `secret`** ("La voix retrouvée") : déclenchée si
  `aLaSoeur` + `cardSoin>=2` + moral>=65 + **`radio3`** (avoir suivi la radio
  jusqu'au bout). Sinon `famille` / `ensemble` / `abandon` / `mort` comme avant.

**✅ LA MAP EST LE MENU (2026-06-05, build 0.74.0)** :
- **Taper une gare sur la map lance son combat** (`MapScreen.onGareSelected` →
  `main` met `_shootFromGare=true` + `_shootGareIndex` → `RoofDefenseGame` en
  mode gare → `applyCombatRewards` au retour → retour map). FAB `open_shoot`
  **retiré**.
- **Carte murale wagon 1** : prop `wallmap` dans `side_scroll_scene`
  (`onOpenMap`), tap → ouvre la map. Asset attendu `assets/objects/wallmap.png`
  (placeholder dessiné en attendant). FAB `open_map` gardé en secours pour
  l'instant (à retirer quand la carte murale est validée).
- **Atelier + Quotidien + Collection étoiles** rapatriés hors du menu combat
  (devenu inaccessible) dans **`WorkshopScreen`** (`lib/widgets/workshop_screen.
  dart`), ouvert par un FAB sur la map (pastille verte si coffre/mission dispo).
  Défs d'atelier + achat centralisés dans `GameState.shootShopDefs` /
  `buyShootUpgrade` (partagés combat ↔ workshop).

**✅ DÉCORS PAR GARE + CARTE DANS LA LOCO (2026-06-05, build 0.75.0)** :
- **9 décors de combat** `assets/background/gare_combat_1..9.png` (1584×672,
  vue de loin, ambiances tempéré→froid). Branchés par gare via la liste
  `RoofDefenseGame._gareDecor` (14 index → 9 décors) + `gareIndex` passé depuis
  `main`. **Exclus du precache** (`loading_screen._essential` skippe
  `/gare_combat_`) → décodés à la volée au lancement (OOM). `gare_shoot.png`
  n'est plus référencé.
- **Carte du voyage déplacée du wagon → LOCOMOTIVE** : `MiniRouteMap` encadrée,
  position+taille persistées (`GameState.locoMapCx/Cy/W` + `setLocoMap`), **mode
  ajuster** (FAB crayon dans la loco : 1 doigt déplace, **pincer**
  redimensionne, HUD coords). Tap (hors ajuster) = ouvre la map. La carte
  murale du wagon est masquée (`onOpenMap` null côté wagon).
- ⚠️ Les 9 PNG avaient été uploadés par erreur sur la branche
  `claude/train-wagon-app-1mqKe` (divergente) ; récupérés et committés sur main.

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
- **Musique RÉACTIVÉE** (`_musicEnabled=true`) : 3 morceaux mappés day/night/
  cold → `paper-lantern-ruins.mp3` / `moonlit-static.mp3` / `zone-froide.mp3`
  (volume 0.3, loop). L'ancien « à refaire » est PÉRIMÉ.
- `fire_crackle.mp3` (loop, actif en loco)
- 9 SFX : door_open/close (désactivés), footstep, pickup, log_throw,
  drink, lamp_toggle, dog_bark, dog_pant

---

## 🎯 BOUCLE DE JEU CIBLE (validée 2026-06-08) — `docs/boucle_jeu.png`

Structure macro du jeu, à construire :
1. **Cinématique d'ouverture** : la nuit de la fuite (explosions, famille
   séparée, Shen monte dans le train).
2. **On apparaît dans le train VIDE + abîmé** (seule, stats au plus bas, froid).
3. **Bulles de TUTO** : résument ce qui vient de se passer, PUIS s'affichent à
   **chaque 1re utilisation** d'un élément.
4. Puis **LA BOUCLE**, répétée à chaque gare jusqu'au nord :
   - **a) ~10 cartes** (Reigns) : choix qui font avancer l'histoire ET
     **débloquent des objets** (filtre, hydro…), parfois éclairent le passé.
   - **b) Cinématique** : le train entre en gare et s'arrête.
   - **c) Gare = COMBAT** : un évènement qui fait avancer l'histoire OU fait
     gagner un **élément clé**, joué pendant un combat.
   - **d) S'occuper de Shen** entre les phases : **comme les Sims / un
     Tamagotchi** (manger, boire, dormir, se laver, jouer avec le chien…).

**Géo** : au départ le train est **entre la ville natale** (point de départ =
là où le jeu se TERMINE) **et la 1re gare**.

**Exemple gare 1** : les ~10 cartes font gagner **filtre à eau + tour hydro** ;
à ce stade train abîmé + froid + stats ~0 → cinématique : entrée en gare,
**un chiot sur le quai**, on sort, on se fait attaquer → bien jouer = **sauver
le chiot**.

**⚠️ Sprites** : `open_door` et `idle` ne sont pas raccord (oreille dehors vs
sous les cheveux) → différence d'ART (pas un bug code). À régénérer pour
matcher si on veut un raccord parfait.

## 🎯 Direction Reigns — VALIDÉE (2026-05-31)

Concept Reigns **acté**. Reste à trancher en impl : hybride (wagon
side-scroller vivant en fond des cartes) vs full Reigns visuel — penché
hybride, à confirmer au moment du code.

**Format** : cartes événements swipe gauche/droite, 2 choix par carte,
sessions courtes, hautement rejouable, fins multiples.

### Les 4 stats (mort si une touche 0 ; on NE garde PAS le 100%)

1. **Soif** → eau (filtre, neige fondue, pluie).
2. **Faim** → nourriture (hydroponie, troc, chasse).
3. **Bois** → carburant loco. À 0 = train s'arrête en terrain hostile = mort.
4. **Moral / Espoir** → foi de retrouver la famille. À 0 = elle abandonne,
   descend du train.

### L'HISTOIRE (validée, canon)

**Prémisse** : mix **fuit + cherche**. Thème profond = **espoir contre
acceptation** (croire qu'ils sont vivants, ou apprendre à vivre sinon).

- **Monde** : après la 3e Guerre mondiale, effondrement total, lente
  extinction. États morts, villes vides, survivants en poches le long des
  voies ferrées. Ciel bas, cendre comme neige sale, silence.
- **Shen** : ex-étudiante rentrée dans sa ville natale (parents + petite
  sœur), ville longtemps épargnée.
- **La nuit de la fuite** : explosions, parents la réveillent, fuite dans
  le chaos, famille séparée. Shen seule, portée par la foule jusqu'à la
  gare. Trains bondés. Au bout du quai, des silhouettes rallument une
  vieille **loco de fret à bois**. Elle monte, se cache dans l'unique
  wagon. Le convoi part au moment où la gare brûle, les autres trains
  explosent, des tirs tuent les rares passagers montés avec elle.
- **Le périple** : seule, une loco à bois + un wagon, la voie file vers le
  **nord** (zone froide = refuge où des familles se regroupent, le froid
  tient les pillards à distance). Et si les siens étaient montés dans un
  autre train ? S'ils l'attendaient là-haut ?
- **Cœur du jeu** : survivre de corps ET d'âme assez longtemps pour le
  découvrir.

### Trame principale — 14 gares (tempéré → transition → neige nord)

| # | Gare | Beat |
|---|------|------|
| 1 | Gare natale en ruines | Tuto. Choix : retourner en ville (risque) ou fuir. **Trouve le chien**. |
| 2 | Dépôt de fret | Apprend à nourrir la loco au bois. **Le Vieux** (cheminot) monte. |
| 3 | Halte 47 | Premiers **pillards** dans le brouillard. Choix moral. |
| 4 | Village fantôme | **Trouve la radio à manivelle.** 1er fragment de message du nord. |
| 5 | Pont sur le fleuve | Décision ressources : ralentir (eau/pêche) ou foncer (sécurité). |
| 6 | Camp-refuge | Survivants, rumeur du Nord précisée. Le Vieux reste ou continue (flag). |
| 7 | Halte 12 | Souvenir d'enfance jouable : la **petite sœur**. Enjeu émotionnel. |
| 8 | Entrée zone froide | Le froid menace, loco boit plus. **Trouve un enfant seul**. |
| 9 | Plaine enneigée / ruines | Tempête. Survie pure. L'enfant tombe malade. |
| 10 | Oasis perdue (serre) | Répit cosy. Hydroponie, lien avec l'enfant. |
| 11 | Halte 31 | Climax inter : pillards rattrapent OU message radio clair (voix familière ?). |
| 12 | Tour de guet | Vue sur le **refuge nord**. Espoir concret. Décision lourde. |
| 13 | Col gelé / Halte 6 | Dernière épreuve, loco menace de lâcher. **Sacrifice**. |
| 14 | Tunnel nord / Refuge | **Climax.** Selon flags : retrouvailles / vérité / autre. |

Chaque gare = scène 2 choix avec 2-3 variantes selon flags accumulés.

### Cartes de remplissage

**~10 cartes entre CHAQUE gare** → 13 inter-gares × ~10 = **~130 cartes**.
Pool large, ~10 vues par segment, varié à chaque run. Rôle : ambiance
(météo, paysage, ennui), tactique (ressources, soigner Shen), lore
(souvenirs, objets trouvés).

### Personnages récurrents (3-4 apparitions chacun)

1. **Le chien** — gare 1. Témoin silencieux, ancre du moral.
2. **Le Vieux** (cheminot) — gares 2→6. Mentor du train. Peut rester/mourir.
3. **L'enfant** — gare 8. Miroir de la petite sœur. Plus gros levier émotionnel.
4. **Les pillards** — antagoniste diffus (gares 3, 11, 13).
5. **La voix radio** — fil d'espoir (gares 4→14). Refuge ? La sœur ? Réservé fin.

### Fins (3-5)

1. **Retrouvailles** — bonne gestion + bons choix → retrouve tout/partie famille.
2. **Le deuil et la vie** — ils sont morts, mais elle choisit de vivre.
3. **Mort** — une stat à 0 (gelée, affamée, loco éteinte, pillards).
4. **L'abandon** — moral à 0, descend à une gare au hasard.
5. **Fin secrète** — toutes cartes vues + flags positifs + radio suivie → la voix était sa sœur.

### Volume de contenu cible

~14 cartes de gare (+ variantes) + ~130 cartes de remplissage + scènes
secondaires des persos récurrents. **Noms en placeholders** (Le Vieux /
l'enfant / la sœur), à nommer plus tard.

---

## Ce qui reste à faire

### ✅ DÉJÀ FAIT (ne pas re-coder)
Thermomètre AUTO ; `_showAllProps`→debug + objets placés par gare ; combat lancé
à chaque gare + **conséquence vert/rouge à chaque gare** ; cinématique
d'ouverture + bulles de tuto ; Nouvelle partie = vrai reset ; source unique de
déblocage (visible=cliquable) ; cartes inter-gares FIXES ; map via loco + cartes
via « Continuer le voyage » ; anims de mort pillards ; stats de départ basses.

### 🚨 Priorité — boucle de jeu (vision `docs/boucle_jeu.png`)
0a. **Géo de départ** (décision user en attente) : renommer la ville de départ
    (= fin), décider s'il faut un nœud « ville natale » AVANT la gare 1 sur la
    map, positionner le train juste après. Fichier : `lib/widgets/map_screen.dart`
    + `kGarePositions`/`_stations` dans `lib/constants.dart`.
0b. **1er combat = TUTO** (décision 5) : aujourd'hui combat sauté à idx 0
    (`cards_screen._presentCurrentCard`, `idx >= 1`). En faire un combat guidé,
    et y rattacher le **sauvetage du chiot** (vision). Lié au placement du chien
    (déplacer `aLeChien` g1→g2-3, décision 3).
0c. **Tamagotchi** : besoins de Shen (faim/soif/sommeil/hygiène/jeu) qui
    descendent avec le temps, remontés par les objets (manger/boire/dormir/
    laver/jouer). Les actions existent déjà ; reste la décroissance temporelle.
0d. **Cinématiques d'entrée en gare** (version texte comme l'ouverture).
0e. **Une idée de combat distincte par gare** (14 angles). `_duelTest=true`.
0f. **Brancher plus de gares sur le tier** combat (sœur malade, accueil refuge…)
    via `combatTier*`/`combatGood_N` dans `gareCards(flags)`.
0g. **Boutique IAP** (4,99 €=500 ferraille) — confort seulement.

### Priorité — froid / confort (en partie fait)
1. ✅ Thermomètre auto (zone+météo+nuit+feu). Reste à **équilibrer** (le nord
   doit rester gérable : froid bloque le gain de moral).
2. **Poêle interactif** : `stoveInstalled` en vrai objet à installer.
3. **Habits chauds** : outfits avec `outfitWarmth` (wardrobe a 1 outfit).
4. **Crédits de cartes** : à reconsidérer (cartes fixes = runs ~2× plus longues).

### Priorité — vie des wagons (idées validées en discussion)
5. **Interactions émergentes** : chien/sœur suivent ou rejoignent Shen ;
   regroupement la nuit (dodo : Shen lit, sœur, chien panier).
6. **Fix nuit sœur** : la nuit elle bouge presque plus (le check froid mange
   la tranche walk) — rééquilibrer.
7. **Activités cellier** : faire fondre la neige (→soif), étendoir, etc.
   (cf. liste d'idées d'anims).

### Priorité moyenne
8. **Refaire les musiques** (supprimées car « rock pas adapté »).
9. **Brancher les 3 autres plantes** (tomato/eggplant/lettuce) dans hydro_game.
10. **Auto-consume** : stats basses → Shen mange/boit auto.
11. **Nettoyer** `hydroSlots`/`waterJars` morts + warnings (`_cookToken`,
    `_horizonNightAsset`, `_nearWindow`…).

### Priorité basse — polish & contenu
12. **Objets absents** : radio à manivelle (gare 4), sac à dos, jarres.
13. **Prompts d'anims en attente** : douche en planches (panneau+pommeau déjà
    là), activités cellier, persos qui ont froid en duo.

### ⚠️ Pièges connus / conventions
- **Découpe sprites IA** : si une sheet se découpe mal (frames qui dérivent,
  largeurs inégales), demander à l'utilisateur de tracer des **traits rouges
  #FF0000** entre les frames (fond vert), puis couper aux traits + normaliser
  (cf. `recut_clean.py`). Le fond doit être **vert #00FF00** (pas blanc : halo).
- **Anims qui se figent + solo qui réapparait** : toute anim "state" (bain,
  douche, duo, petdog) DOIT finir via `setState` (pas `_animSet`), sinon le
  sprite figé reste affiché ET le solo réapparait par-dessus.
- **Toujours `flutter analyze` avant push** (SDK récupérable dans /tmp).
- **Toujours afficher/bumper le n° de build** dans `loading_screen.dart`.
- **Combat sous AnimatedSwitcher** : garder `StackFit.expand` sur le Stack
  principal (sinon écran bleu/0×0 silencieux).
- **Combat — listes pendant itération** : ne jamais `_stones.add()` pendant
  `for (final s in _stones)` (ConcurrentModification → freeze). Itérer
  `List.of(...)` + `addAll` après.
- **OOM iOS** : ne PAS re-precache tous les PNG ni regonfler le cache image
  (whitelist `loading_screen._essential` + cache 450 Mo à respecter).
- **Difficulté combat** : calibrer par simulation (`/tmp/sim.py`) avant de
  toucher la table des vagues — le user trouve vite « trop facile ».

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
- **Ne JAMAIS dramatiser la charge de travail** : pas de « beaucoup à faire »,
  « gros morceau », « c'est conséquent », etc. C'est une IA, le travail est
  facile/rapide. On fait, point. (Demande explicite de l'utilisateur 2026-06.)
- **Pas de mini-jeux modaux** pour eau (l'utilisateur n'aime pas).
  Préférer interaction inline avec l'asset (tap sur prop = action).
- **L'utilisateur préfère les itérations rapides** : commit même quand
  c'est imparfait, on ajuste après.
- **L'utilisateur se frustre vite** si on fait des allers-retours sur
  des choses déjà faites. Mieux vaut proposer une solution complète que
  redemander des infos.

---

## Notes pour la prochaine session

**GROSSE SESSION 2026-06-09 (builds 0.92 → 0.99.8)** — UX, onboarding, nettoyage,
contenu. Ce qui a changé (TOUT est dans le code, vérifié) :

- **Mode debug unifié** (`GameState.debugMode`, bouton « debug »/« DEBUG ON »
  bas-gauche du wagon). OFF = vrai jeu, ON = tous les outils + tout affiché.
- **SOURCE UNIQUE de déblocage** (`GameState.propUnlocked(key)` / `dogShown` /
  `sisterShown`) lue À LA FOIS par la visibilité (side_scroll) ET l'interaction
  (main `_at*`). Un objet non débloqué est **invisible ET non cliquable**.
- **Tout placé par gare** (flags `asset_*` dans `cards_data`) : lit+gamelle g1,
  lampe g2, carnet g3, filtre g4, commode (armoire, dans le cellier) g6,
  poêle+trousse g8, hydro+bain+douche+lanternes g10. (`asset_table` reste posé
  g2 mais la table n'a plus de prop — retirée.) **Wagon 2 (cellier) =
  asset_wagon2 (gare 6)**
  (porte droite verrouillée avant). Chien=`aLeChien` (g1), sœur=`aLaSoeur` (g5).
- **Cartes inter-gares FIXES** : `_drawFillers` joue TOUTES les cartes éligibles
  dans l'ordre (plus de tirage aléatoire / shuffle ; `drawCount` ignoré).
- **Conséquence de COMBAT à CHAQUE gare** : helper `_combat()` dans cards_data
  (vert = High|Mid, rouge = Low). `_duelTest = true` (duel = LE jeu, NE PAS
  rebrancher sur debug).
- **Anims de mort pillards** : `lanceur_die` (depuis le `Fall/` user, miroité) +
  `pillard1_die` jouées ; knockback d'origine conservé (brute/boss = ragdoll).
- **Cinématique d'ouverture** (`opening_cinematic.dart`, texte+fondu, sans art)
  + **bulles de tuto** (`tutorial_overlay.dart` : intro + hint 1re utilisation).
  Persistés : `seenTips`, `introCinematicSeen` (reset en Nouvelle partie).
- **Nouvelle partie = vrai reset** (`GameState.resetForNewGame()` : vide flags,
  jauges, objets, tips). Avant, `aLeChien` restait en mémoire (chien fantôme).
- **Stats de départ BASSES** (`GameState.kStartStat = 25`) : on commence « au
  mini ».
- **Température AUTO** (zone+météo+nuit+feu), **musique réactivée**, **perf**
  (précache statique, `shouldRepaint` ciblés, OOM), **~340 l. de code mort
  retirées** (Le Vieux supprimé, `_DogActor`, cookToken…). `flutter analyze`=0.
- **UI épurée** : en jeu, map UNIQUEMENT via la carte de la LOCO ; les cartes
  s'ouvrent via **« Continuer le voyage »** (bouton centré sur la map) ; map
  redessinée (close+atelier ronds) ; atelier réservé au **debug**. Halo lampe
  wagon+loco gatés ; silhouettes de fond retirées. **Porte** : fondu noir
  RAPIDE dès le clic (`easeOutCubic` 420 ms) → plus de saut de sprite.
- **Visuels de design** dans `docs/` (régénérables via `tools/story_viz/`) :
  `plan_global.png` (tout), `histoire_schema/complet.png`, `objets_placement.png`,
  `boucle_jeu.png`, `histoire_tableau.md`, + `docs/a_faire.md`.

**DÉCISIONS DU USER (2026-06-09) — appliquées sauf mention** :
1. **Géo** : commencer APRÈS une ville de départ À RENOMMER (propositions
   données en chat ; à câbler sur la map). ⏳ EN ATTENTE du nom + structure.
2. **Crédits** : gardés pour l'instant ; mais stats de départ basses → FAIT.
3. **Chien plus tard (gare 2-3)** : ⏳ à câbler (déplacer `aLeChien` g1→g2),
   MAIS attention au lien avec la vision « 1er combat = sauver le chiot ».
4. **Placement objets** : « on verra en testant » → laissé tel quel.
5. **1er combat = TUTO** : ⏳ à faire (combat sauté à idx 0 ; `idx>=1` dans
   `cards_screen._presentCurrentCard`). Dépend de la géo/structure.
6. **Atelier réservé au debug** → FAIT.

**À reprendre (suggéré)** : (a) trancher la **géo de départ** (nom de la ville +
faut-il un nœud « ville natale » avant la gare 1 sur la map) ; (b) **1er combat
tuto** + placement du chien (liés) ; (c) **Tamagotchi** : besoins de Shen qui
descendent avec le temps, remontés par les objets ; (d) cinématiques d'entrée
en gare (version texte) ; (e) une idée de combat par gare ; (f) boutique IAP.

**À ne PAS faire / refaire** :
- Reproposer des mini-jeux modaux (hydro OK, filtre inline OK, wood retiré).
  (Le combat est plein écran, c'est voulu/validé.)
- Re-découper bain/douche/duos/petdog sans les **traits rouges** + fond vert.
- Oublier `flutter analyze` + le bump du **n° de build** dans loading_screen.
- Remettre les bruits de pas (retirés exprès).
- Remettre cook/garden_tend/look_window/sister_read/hugduo (anims retirées).
- **Combat** : enlever `StackFit.expand`, regonfler le cache image / precache
  tout (OOM), ou `_stones.add()` en pleine itération (freeze).
- Tenter d'habiller Shen avec la robe sans sprites régénérés (abandonné).

**Persos à l'écran** : Shen (jeune femme, chemise blanche pieds nus — voulu),
la **petite sœur** (pyjama, couettes — bien plus petite que Shen), le **husky**.
Le câlin debout sœur (`hugduo`) était mal généré → on utilise `sister_hug`
(sœur petite + Shen accroupie).

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
