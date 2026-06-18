# Train Cosy — mémoire Claude

Ce fichier sert de **mémoire persistante** entre sessions. Lis-le au démarrage
de chaque nouvelle conversation avant d'agir sur ce repo.

---

## Le projet

**Train Cosy** est une app Flutter / iOS en cours de prototype : un jeu narratif
**cosy post-apocalyptique**. Une jeune femme (Shen, l'« habitante ») vit seule
dans le wagon d'un train qui roule à travers un monde mort. Elle interagit avec
son environnement, le train tangue doucement, l'ambiance bascule jour / nuit.
La scène est un **side-scroller** vue de côté : le wagon est centré, le paysage
défile latéralement derrière, la locomotive est à gauche.

**Esthétique cible** : Studio Ghibli + lofi anime, hand-painted, palette warm
honey browns / cream / soft amber dedans, cold blue / pale fog dehors.

### ⚙️ Nature du jeu (DIRECTION ACTUELLE — 2026-06-17)

Train Cosy est un **jeu 100% narratif** : un **moteur de cartes Reigns-like**
(`lib/widgets/cards_screen.dart`, données `lib/data/cards_data.dart`) déroule le
voyage en 14 GARES + cartes inter-gares, sur **4 jauges** (soif/faim/bois/moral)
avec **fins multiples**. Entre les cartes, on **s'occupe de Shen dans les wagons**
(manger, boire, dormir, se laver, jouer avec le chien…) comme un Sims/Tamagotchi.

> 🚫 **LES COMBATS ONT ÉTÉ RETIRÉS** (décision user 2026-06-17). Plus AUCUN
> mini-jeu. Quand une gare présente une menace (pillards, barrage, brouillard…),
> elle se résout désormais en **une carte à choix** dont chaque option mène
> **directement** à sa conséquence (option A : pur Reigns, pas de stat-check
> caché, pas de mini-jeu). Les « pillards » restent l'**antagoniste narratif
> diffus** dans le texte des cartes — c'est la seule trace qu'on garde. Le code
> de combat (`roof_defense_game.dart`, `workshop_screen.dart`, dossier
> `lib/widgets/games/`), les assets (`combat_*`, `gare_combat_*`, sprites
> `pillard*/brute*/lanceur*`) et l'économie ferraille/atelier ont été
> **supprimés**. NE PAS les ré-introduire.

---

## L'HISTOIRE (canon validé)

**Prémisse** : mix **fuir + chercher**. Thème profond = **espoir contre
acceptation** (croire que sa famille est vivante, ou apprendre à vivre sinon).

- **Monde** : après la 3e Guerre mondiale, effondrement total, lente extinction.
  Villes vides, survivants en poches le long des voies ferrées. Ciel bas,
  cendre comme neige sale, silence.
- **Shen** : ex-étudiante rentrée dans sa ville natale (parents + petite sœur),
  longtemps épargnée. **Jeune femme de 20 ANS, adulte — JAMAIS une enfant**
  (cheveux noirs longs, chemise blanche, pieds nus — voulu).
- **La nuit de la fuite** : explosions proches du train, la famille séparée dans
  le chaos. Shen se cache seule dans l'unique wagon d'une vieille loco de fret à
  bois ; par peur des explosions, les autres sautent du train. Le convoi part
  vers le **nord** (zone froide = refuge où des familles se regroupent, le froid
  tient les pillards à distance).
- **Cœur du jeu** : survivre de corps ET d'âme assez longtemps pour découvrir si
  les siens ont survécu / l'attendent au nord.

### Les 4 stats (mort si une touche 0)
1. **Soif** → eau (filtre, neige fondue, pluie).
2. **Faim** → nourriture (hydroponie, troc, chasse).
3. **Bois** → carburant loco. À 0 = train s'arrête en terrain hostile = mort.
   (Jauge `cardBois`. Fusionnée avec la corvée de bûches à la loco : chaque
   bûche jetée au foyer = +10 `cardBois`, `gareWoodLeft` bûches/gare.)
4. **Moral / Espoir** → foi de retrouver la famille. À 0 = elle abandonne.

### Trame — 14 gares (tempéré → transition → neige nord)

| # | Gare | Beat |
|---|------|------|
| 1 | Kogarashi (1er arrêt) | Tuto + **épreuve = défendre le chiot** (carte de choix → `aLeChien`). |
| 2 | Kurogane (dépôt fret) | Apprend à nourrir la loco au bois (manuel → lampe). |
| 3 | Karasuno (brouillard) | Premiers **pillards** dans le brouillard. Choix moral. |
| 4 | Mayoidani (village fantôme) | **Trouve la radio à manivelle.** 1er fragment du nord. |
| 5 | Tsukibashi (pont) | **Retrouve la petite sœur** (`aLaSoeur`) + choix engagement parents (`capParents`). |
| 6 | Yasuragi (camp-refuge) | Rumeur du Nord précisée, on gagne le cellier (wagon 2). |
| 7 | Hoshikage (souvenir) | Souvenir d'enfance avec la sœur (déjà à bord). |
| 8 | Kiribe (entrée zone froide) | Le froid menace, la loco boit plus (drain bois/carte). |
| 9 | Shizuhara (blizzard) | Tempête. **La sœur tombe malade** (fièvre). |
| 10 | Hidamari (oasis/serre) | Répit cosy. Hydroponie, bain/douche, lien avec la sœur. |
| 11 | Yukihara (barrage) | Climax inter : barrage de pillards OU message radio clair. |
| 12 | Miharashi (tour de guet) | Vue sur le **refuge nord**. Espoir concret. Décision lourde. |
| 13 | Fubuki (col gelé) | Dernière épreuve, loco menace de lâcher. **Sacrifice**. |
| 14 | Hokuto (refuge nord) | **Climax.** Selon flags : retrouvailles / vérité / autre. |

Chaque gare = carte(s) à 2 choix avec variantes selon les flags accumulés.
(Ordre des noms = thématique : chaque nom colle à sa scène. `cards_data._gareN`,
`map_screen._stations` et `constants.kGarePositions` DOIVENT rester synchro.)

### Personnages récurrents (CANON À JOUR)
1. **Le chien** — gagné à l'épreuve de la gare 1. Ancre du moral.
2. **La petite sœur** — 7 ans, pyjama, couettes (bien plus petite que Shen).
   Retrouvée gare 5, à bord ensuite (malade gare 9, climax des fins). C'est ELLE
   le levier émotionnel (l'« enfant » du canon).
3. **Les pillards** — antagoniste narratif diffus (menaces de gares, en cartes).
4. **La voix radio** — fil d'espoir (gares 4→14), se révèle être maman (fin secrète).

> ⚠️ Le **« Vieux » (cheminot mentor)** et **« l'enfant trouvé »** du canon
> d'origine sont **SUPPRIMÉS DÉFINITIVEMENT** (2026-06-11). Le code n'en a jamais
> eu. Pas de mentor, pas d'enfant tiers : la sœur est le cœur émotionnel.

### Fins (résolveur `resolveTrainCosyEnding`, `cards_data.dart`)
1. **Retrouvailles (`famille`)** — `aLaSoeur` + `capParents` + `cardSoin≥2` + moral≥65.
2. **Ensemble** — arriver avec la sœur sans l'engagement parents = acceptation
   (incarne le thème). Fin dominante d'un bon run « cosy ».
3. **Fin secrète (`secret`)** — conditions de `famille` + avoir suivi la radio
   jusqu'au bout (`radio3`) → la voix était maman.
4. **Abandon** — moral à 0 (descend du train) OU arriver seule.
5. **Mort** — soif/faim/bois à 0.

---

## 🃏 Moteur de cartes (architecture)

- `lib/models/reigns_engine.dart` — déroule gare → fillers → gare → ... → fin.
  GameState est la **source de vérité** (jauges `cardSoif/Faim/Bois/Moral`,
  flags `cardFlags`, oneshots vus, segment courant `cardGareIndex`). Effets :
  **pertes ×1.7**, **gains de moral ×0.6** (calé par simu). Mécanique sœur
  (faim/soif -1, moral +1 par carte après gare 5). Zone froide (gare 8+) : drain
  bois/carte. **Ravitaillement d'arrivée par gare** (`grantGareSupply`) une fois
  par gare (garde `woodpile_$idx`).
- `lib/data/cards_data.dart` — contenu : 14 `_gareN`, paquets `_fillN`, helper
  `_epreuve(...)` (carte de menace à 2 choix), `_c(...)`, `_filler(...)`,
  `resolveTrainCosyEnding`. Flags : `aLeChien`, `aLaSoeur`, `soeurProtegee`
  (compte `cardSoin`), `capParents`, `indiceSoeur`, `aLaRadio`/`radio1/2/3`,
  `asset_*` (déblocage d'objets).
- `lib/widgets/cards_screen.dart` — UI swipe, présente la carte, applique le
  choix, annonce les gares. Cartes inter-gares **SEMI-ALÉATOIRES**
  (`_drawFillers`) : les cartes de PROGRESSION (avec `requires` OU qui posent un
  flag : chaîne radio, beats sœur/chien) sont TOUJOURS jouées si éligibles ;
  l'AMBIANCE pure (stats only) est tirée au hasard, dans la limite de
  `drawCount` (les pinned comptent dedans → nb de cartes/segment stable). Variété
  inter-run sans casser les arcs. `requires` évalué À L'ÉMISSION (`_skipDeadHead`,
  pas au chargement) → une carte conditionnée par la carte de gare du même
  segment reste jouable.
- **Arc radio délibéré** : seul le choix « y croire » fait avancer
  `radio1→2→3` ; le côté sceptique ne pose pas le flag. La **fin secrète** (la
  voix = maman) récompense ceux qui gardent la foi jusqu'au bout.
- **Noms de gares** : `cards_data._gareN` (speaker) et `map_screen._stations`
  DOIVENT rester synchro (ordre thématique : chaque nom colle à sa scène). Idem
  `constants.kGarePositions`/`kWoodSupplyByGare` (bonus bois dépôt idx1 / camp
  idx5 / oasis idx9).
- **Système de crédits** : présent mais **DÉSACTIVÉ** (`spendCardCredit` renvoie
  `true`). Conservé si on veut réactiver un rythme.

### Équilibrage (`tools/sim_current.py`)
Parse les vraies cartes (regex) et rejoue 4000 runs/profil. **Cible atteinte** :
**careless ~11% / casual ~62% / smart 100% / caring 100%** (famille route
validée). Stats de départ **25** (`kStartStat`). Ravitaillement d'arrivée
calibré : **+9 bois / +6 soif / +6 faim / +5 moral** par gare. Le **bois est la
cause de mort dominante** (rareté volontaire). Les recharges « wagon » du sim
sont liées à l'engagement (un joueur négligent néglige aussi le wagon) → c'est
ce qui crée le spread de difficulté. Lancer : `python3 tools/sim_current.py`
(option `--wood` = sweep réserve de bois).

---

## 🏠 Vie des wagons (Tamagotchi / Sims)

**3 WAGONS** : salon (wagon 1) → atelier (milieu) → cellier (wagon 2).
Navigation `_wagon` 0/1/2, portes `_wagonDoor(±1)`. Wagon 1 porte gauche → loco,
porte droite → wagon 2 ; wagon 2 porte gauche → wagon 1. Map via la **loco** ;
cartes via « **Débuter / Continuer le voyage** » sur la map.

- **Shen est IDLE** : aucune autonomie, tout est déclenché par le joueur (anim
  `idle_right` au repos, frissonne si `feltCold`).
- **Besoins (Tamagotchi)** : faim/soif (jauges cartes) décroissent −1/24 s dans
  le wagon (PAS en cartes ni sur la map). + 2 besoins de **CONFORT non létaux** :
  `sleepNeed` (décroît dès g1, remonté en dormant au lit) et `hygieneNeed` (ne
  décroît qu'une fois bain/douche débloqués g10, remonté en se lavant). <20 →
  grignotent le moral. Bulle de pensée 💤/🛁 (`contextualThought`).
- **Objets atelier interactifs** : cuisinière (tap → se tourne → feu animé →
  **se retourne → mange** au sol ; **déplacement bloqué pendant la cuisson**
  `_cooking`) ; poêle à bois (ON/OFF, chauffe la cabine, bois -1/9 s, s'éteint à
  0 bois) ; bac de culture (semer → pousse 20 s → récolter +faim) ; filtre eau
  (= asset `tank_0..5`, fill/drink inline, `waterTankGlasses` 0-5). Le mini-jeu
  hydro modal et le filtre-mini-jeu ont été **supprimés** (interactions inline).
- **Cellier (wagon 2)** : bain (`bath_1..8`), douche (`shower_1..8` + pommeau +
  vapeur `_SteamPainter`), armoire/commode (garde-robe), 2 lanternes (FireGlow
  la nuit). Props posables en **mode AJUSTER** (debug, drag + pincer, coords
  persistées dans GameState).
- **Sœur + chien** : `_SisterCharacter`/`_DogCharacter` se baladent quand
  débloqués (sister_walk/dog_walk), dorment la nuit. Duos : lecture
  (`readduo_1..10`), câlin (`sister_hug_1..4`), caresse chien (`petdog_1..9`).
  ⚠️ Toute anim « state » (bain/douche/duo/petdog) DOIT finir via `setState`
  (sinon sprite figé + solo qui réapparaît).
- **Moral de confort** : `_comfortMoral` (main.dart) avec cooldown (lire/chien/
  sœur donnent du moral, throttlé).

### Température / froid (règle précise)
Cabine = zone map (17/12/5/-4) + météo (0/-1/-2/-4) + nuit (-3) + poêle ALLUMÉ
(+12, +18 si bois≥30). Froid si < seuil (12 - wagonStage×2 - `outfitWarmth`) →
givre fenêtres, **gains de moral bloqués**, drain moral. **AUTO** en jeu
(`computeAutoCabinTemp`), recalculé sur changement gare/météo/nuit/bois ; bouton
test manuel seulement en debug. `outfitWarmth` : tenues chaudes (manteau warmth
8 → le nord devient gérable ; sprite dédié à faire, écharpe peinte en attendant).

---

## 🐞 Mode debug — ⚠️ RÈGLE D'OR

**Mode JEU (debug OFF) = LE VRAI JEU** : train **abîmé + VIDE** à l'arrivée
(aucun objet), **AUCUN outil de réglage visible**, Shen **seule** (pas de sœur
ni chien tant que l'histoire ne les amène pas). **Mode DEBUG (🐞) = TOUT remis** :
tous les objets + sœur + chien + tous les outils de réglage. Un **seul
interrupteur** (`GameState.debugMode`, persisté), bouton discret **bas-gauche**
de l'écran wagon (triple-tap coin pour l'activer).

**SOURCE UNIQUE de déblocage** (`GameState.propUnlocked(key)` / `dogShown` /
`sisterShown`) lue À LA FOIS par la visibilité (side_scroll) ET l'interaction
(main `_at*`). Un objet non débloqué est **invisible ET non cliquable**. Les
flags `asset_*` sont posés par les cartes (`cards_data`) au fil des gares :
lit+gamelle g1, lampe g2, carnet g3, filtre g4, commode/cellier g6, poêle+trousse
g8, hydro+bain+douche+lanternes g10. Chien=`aLeChien` (g1), sœur=`aLaSoeur` (g5).

---

## Architecture côté code

- `lib/main.dart` — App + `WagonScreen`. État global (night, flags de nav
  `_inLocomotive`/`_inWagon2`/`_onMap`/`_inCards`/`_doorPushing`), HUD
  (StatRingsBar + thermomètre), bouton action **contextuel** + tokens
  (`_bathToken`, `_showerToken`, `_petDogToken`, `_duoToken`…), colonne de FAB
  scrollable. Navigation portes via `_pendingDoor`. Positions vivantes
  `_sisterLiveX`/`_dogLiveX` (callbacks `onSisterX`/`onDogX`). `_comfortMoral`,
  `_checkUnlocks` + bannière, `_poeleTimer`, timer besoins (~24 s).
- `lib/widgets/title_screen.dart` — Écran-titre (`title_bg.png`), « Nouvelle
  partie » TOUJOURS visible (vrai reset) + « Continuer » si sauvegarde.
- `lib/widgets/side_scroll_scene.dart` (~2400 l.) — Scène wagon : 4 parallax
  (sky/horizon/mid/foreground), wagon (2 stages windowed/clean), héroïne + chien,
  props (hydro/lamp/stove/filter/notebook/firstaid/bowl). `secondWagon: true` =
  cellier. `_showAllProps = GameState.debugMode`. `_SteamPainter`, FireGlow.
- `lib/widgets/cards_screen.dart` + `lib/data/cards_data.dart` — moteur de cartes.
  `cards_data` expose aussi `kGareIntros` (mini-cinématique texte par gare,
  affichée sous le bandeau d'annonce) et `endingText(id)` (fins ENRICHIES
  dynamiquement : chien/soin/sœur selon les flags).
- `lib/widgets/shop_screen.dart` — Boutique IAP **confort-only** (jamais bloquer
  l'histoire). Le vrai paiement (`in_app_purchase` + produits App Store) reste à
  brancher dans `_purchase` ; en debug, achat accordé gratuitement pour tester.
- `lib/widgets/locomotive_scene.dart` — cabine loco, ramassage bûches,
  `MiniRouteMap` encadrée (tap → map ; ajustable en debug).
- `lib/widgets/map_screen.dart` — carte 14 gares (spline Catmull-Rom, train
  procédural). Bouton central « Débuter / Continuer le voyage » (→ cartes).
  Pas d'animations/silhouettes (retirées). Départ Kogarashi.
- `lib/widgets/atmosphere.dart` (~2500 l.) — widgets atmo (parallax, météo, etc.).
- `lib/widgets/opening_cinematic.dart` — cinématique d'ouverture imagée (plans
  `cine_open_*` dans `assets/cinematic/`, 1re personne, sentimental ; fallback
  fond sombre si image manque).
- `lib/widgets/tutorial_overlay.dart` — bulles de tuto (intro + 1re utilisation).
- `lib/widgets/wardrobe_screen.dart` — tenues (`outfitWarmth`).
- `lib/models/game_state.dart` — Singleton ChangeNotifier, sauvegarde JSON
  (autosave **débouncé 1,2 s**, gardé par `_loaded`/`_loading`). 4 jauges cartes
  + `nudgeCardStat` (bloqué si `feltCold` pour le moral), items, `cardFlags`
  (Set persisté), wagonStage, wagon2Stage, `waterTankGlasses`, coords props
  cellier, thermomètre (`cabinTemp`/`outfitWarmth`/`coldThreshold`/`feltCold`/
  `coldness`), `grantGareSupply`, `unlockNames`/`pendingUnlocks`,
  `resetForNewGame`, `kStartStat = 25`.
- `lib/models/reigns_engine.dart` — voir section moteur de cartes.
- `lib/services/audio_service.dart` — Singleton audio. `ambient_train`,
  `fire_crackle`, musique réactivée (3 morceaux day/night/cold), 9 SFX.
- `lib/data/world.dart` — Locations narratives (à étoffer).
- `lib/data/anim_metrics.dart` — métriques sprites perso.
- `lib/constants.dart` — `kGarePositions`/`_stations`, `kWoodSupplyByGare`,
  `kColdBoisDrainPerCard`, seuils.

### Précisions side-scroll
- Heroine bounds : `heroXMin = 0.22`, `heroXMax = 0.86`. Spawn retour loco →
  heroXMin, retour map → heroXMax.
- Sprites Shen **réduits à 25 frames** (idle/walk/sleep/dance/wake_up/read/eat/
  stretch ; use_back 24 ; carry_walk/warm_hands 25). `_heroFrameCount = 25`.
  Backup `frames_backup_49/` (gitignored) + `tools/reduce_frames.py --restore`.
- Anims câblées : walk_right, idle_right, sleep_right, dance, pickup, yawn,
  stretch, read, wake_up, door_push, warm_hands, carry_walk, drink, eat,
  open_door (clamp), crouch, use_back (de dos), + bath/shower/petdog/readduo/
  sister_hug/cold/sister_cold. **Retirés** : cook, garden_tend, look_window,
  sister_read, hugduo, pet_dog (chiot).

---

## Workflow technique

- **Repo** : `teiki5320/survival`. Branche de dev de session :
  `claude/sharp-turing-351885` (push aussi sur `main`).
- **CI** : Xcode Cloud watch `main`. Bundle ID `com.teiki5320.trainCosy`.
- **Version actuelle** : voir `pubspec.yaml` (`version:`). Le **n° de build**
  s'affiche en bas de l'écran de chargement (`build X.Y.Z`, hardcodé dans
  `loading_screen.dart`). **TOUJOURS bumper version + build à chaque push.**
- **Dev local** : Mac mini (`/Users/jeanperraudeau/survival`), iPhone 16 Plus.
  iOS beta + debug → crash `EXC_BAD_ACCESS` : **toujours `flutter run --release`**.
- **Flutter dans l'env web** : SDK dans `/tmp/flutter/bin/flutter`. **Toujours
  `flutter analyze lib/` avant push** (cible : 0 issue).
- **Dépendances** : `audioplayers: ^6.1.0`, `cupertino_icons: ^1.0.6`.

### Règles de commit / push
- **Commit + push à chaque modification** sans attendre validation.
- Toujours bumper la version (au moins `+N`).
- Pas de PR sauf demande explicite.

---

## Workflow assets

User génère via **OpenArt** (Nano Banana 2) ou **AutoSprite**. Process : il
génère → drop le PNG dans le repo → dit « poussé » → je key out le fond, déplace
vers `assets/`. OpenArt n'exporte pas en transparence : demander fond solide
**blanc #FFFFFF** ou **noir #000000**, je keye.

**RÈGLE PROMPTS AVEC RÉFÉRENCE** : quand une image est en référence, NE PAS
redécrire son contenu (style, perspective, proportions, couleurs). Le prompt ne
décrit QUE les différences / ce qui change.

**Découpe sprites** : technique **traits rouges** — l'user trace des lignes
rouges (#FF0000) entre les frames sur la sheet (**fond vert #00FF00**, pas blanc),
je coupe pile dessus + normalise (bottom-center). Outils : `tools/key_out_*.py`,
`recut_clean.py`.

**AutoSprite** : jamais de preview, valider le coût AVANT, MCP uniquement sur Mac.

---

## Outils Python (`tools/`)
- `sim_current.py` — simulation d'équilibrage des cartes (voir + haut).
- `key_out_black.py` / `key_out_green.py` — chroma-key → transparence.
- `split_character_sheet.py`, `trim_character_dividers.py`, `recut_clean.py` —
  découpe de sheets.
- `reduce_frames.py` — réduction/restauration de frames Shen.
- `generate_app_icons.py`, `measure_sprite_bboxes.py`.
- `story_viz/` — générateurs des visuels de design dans `docs/`.

---

## Ce qui reste à faire

### 🚨 Priorité — développer le contenu narratif
- **Étoffer les cartes** : porter plus de fillers depuis
  `docs/train_cosy_trame.twee` (357 fillers ; **ignorer ~92 passages de l'ancien
  canon** Vieux/enfant supprimé) pour varier les runs. Rendre chaque gare /
  chaque menace plus riche, distincte, mémorable.
- **Géo de départ** (décision user en attente) : nommer la ville de départ
  (= fin), décider s'il faut un nœud « ville natale » AVANT la gare 1 sur la map.
- **Cinématiques d'entrée en gare** (version texte comme l'ouverture).
- **Tamagotchi** : ✅ décroissance faim/soif + besoins confort sommeil/hygiène
  (faite). Reste éventuellement un axe « jeu » (s'occuper du chien/sœur) si on
  veut pousser. Pas de jauge HUD dédiée pour le confort (bulle de pensée only) —
  à décider si on veut les rendre plus visibles.
- **Boutique IAP** — confort only, ne JAMAIS bloquer l'histoire.

### Priorité moyenne
- Crédits de cartes : **garder désactivé** (décision user) — conservé tel quel.
- Refaire les musiques si besoin. Brancher les 3 autres plantes hydro.
- Vraie tenue d'hiver (sprites). Poêle interactif à installer.

### ⚠️ Pièges connus / conventions
- **Golden rule** (voir section Communication) : VÉRIFIER le code/les assets
  avant de répondre.
- **Anims state** (bain/douche/duo/petdog) : finir via `setState`, jamais
  `_animSet` (sinon sprite figé + solo qui revient).
- **OOM iOS** : ne PAS re-precache tous les PNG ni regonfler le cache image
  (whitelist `loading_screen._essential`, cache 450 Mo). `cacheWidth` sur les
  sprites.
- **Découpe IA** : traits rouges #FF0000 + fond vert #00FF00.
- **Toujours** `flutter analyze` + bump du n° de build avant push.
- **NE PAS** remettre : les combats / mini-jeux modaux, les bruits de pas, les
  anims retirées (cook/garden_tend/…), « Le Vieux » / l'enfant, habiller Shen
  sans sprites régénérés.

---

## Communication avec l'utilisateur

- **⚠️ GOLDEN RULE — TOUJOURS VÉRIFIER AVANT DE RÉPONDRE** : lire le **code**,
  les **images/assets**, le **CLAUDE.md** et la **roadmap/docs** AVANT de
  répondre — surtout pour les specs techniques (formats, couches parallaxe,
  géométrie, prompts d'images). Ne JAMAIS répondre de mémoire : ça a déjà produit
  des specs fausses. On vérifie, puis on répond.
- **Langue** : français, ton décontracté **cash**, pas de blabla, pas de flatterie.
- **TOUJOURS NUMÉROTER** les listes / propositions / options (1, 2, 3...).
- **RÉCAP DE FIN OBLIGATOIRE** : terminer chaque demande par un **tableau récap**
  `| # | Demande | État |` avec **✅** (fait) / **❌** (+ pourquoi).
- **Délégations** : commit OUI à chaque modif ; décisions UX/esthétiques NON
  (proposer des options) ; génération d'assets = LUI (je fournis les prompts) ;
  drop de fichiers = LUI.
- **Pas d'estimations de temps. Ne JAMAIS dramatiser la charge** (« gros morceau »,
  « conséquent »…) : on fait, point.
- **Pas de mini-jeux modaux.** Préférer l'interaction inline (tap sur prop).
- **Itérations rapides** : commit même imparfait, on ajuste après. L'user se
  frustre vite sur les allers-retours / le re-déjà-fait → proposer une solution
  complète plutôt que redemander.

---

## Références d'inspiration
- **Reigns** — swipe + cartes + équilibrage stats (réf MAJEURE).
- **80 Days** — voyage + cartes narratives + choix.
- **Plant Tycoon / Stardew / Hay Day** — culture timer-based (réf hydro).
- **Spiritfarer** — cosy management hand-painted (réf esthétique).
- **Studio Ghibli** — Chihiro (train), Château Ambulant, Mononoke (palette).
- **Lexploratrice2025** (YouTube wallpaper) — réf historique clé.
