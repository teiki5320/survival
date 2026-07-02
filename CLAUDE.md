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
  le chaos. Shen se cache seule dans les wagons d'une vieille loco de fret à
  bois (3 wagons traversables dès le départ) ; par peur des explosions, les
  autres sautent du train. Le convoi part
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
| 1 | Kogarashi (**ville natale** = départ) | **Fuite** de la ville en flammes (on NE s'y arrête PAS) + perte de la famille + paillasse. PAS de chien ici. |
| 2 | Kurogane (dépôt fret) | **1er vrai arrêt** : on y trouve le chiot (**épreuve → `aLeChien`**) + apprend à nourrir la loco (manuel → lampe). |
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
1. **Le chien** — gagné à l'épreuve de la **gare 2** (Kurogane, 1er arrêt ; PAS à Kogarashi qu'on fuit). Ancre du moral.
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
- **CARTES-SOUVENIRS (« cartes personnalisées », 2026-06-22)** : `kSouvenirCards`
  (`cards_data`) = cartes **100 % NARRATIVES** (aucun gain de stat) débloquées par
  les ACTIVITÉS du wagon. `GameState.unlockSouvenir(key)` pose `souvenir_<key>` →
  la carte (oneshot, `requires: f.contains('souvenir_<key>')`) s'injecte au
  prochain segment (`_withSouv` les ajoute à tous les paquets). Sources câblées :
  **bain/douche** (`restoreHygiene` → `souvenir_bain`), **sommeil** (`restoreSleep`
  → `souvenir_reve`). Prêtes mais à câbler : `souvenir_peche` (mini-jeu pêche),
  `souvenir_carnet`. But : « tu fabriques ta propre histoire en t'occupant du
  train » ; le contenu (petites histoires) s'étoffera. N'affecte PAS le sim.
- **Cartes vivantes** (depuis 2026-06-18) : `CardChoice.reaction` (réplique d'un
  perso sœur/chien/radio sous la conséquence — ne mettre une réaction sœur QUE
  post-gare 5), `StoryCard.art` (enum `CardArt` : portraits réutilisant les
  sprites Shen/sœur/chien, sinon emblème dessiné radio/cold/fire/water/food/
  refuge/pillards/memory/hope ; `none` = carte texte), `StoryCard.hiddenStakes`
  (carte-pari, preview des deltas masqué « ??? »). Helpers : `_c(..., reaction:)`,
  `_filler(..., art:, hidden:)`, `_epreuve(..., art:)`.
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
- **RYTHME (refonte 2026-06-22, demande user) = CRÉDITS + CINÉMATIQUE DE GARE** :
  - **Crédits** (`creditsEnabled = true`, `cardCreditsMax = 5`,
    `creditRefillInterval = 5 min`) : tirer une carte coûte **1 crédit**
    (`spendCardCredit`), recharge **+1 / 5 min en TEMPS RÉEL** (timestamps, régen
    hors-ligne). À sec, le swipe est bloqué (flash rouge `_noCreditFlash`).
    Pastille en haut-droite de l'écran cartes (`_creditsChip` : 5 jetons +
    compte à rebours). Le temps d'attente se meuble dans le wagon.
  - **Cinématique de gare** : à CHAQUE nouvelle gare atteinte,
    `EngineState.halt` passe à true (`GameState.gareCineBlocking(idx)` =
    `!cardGareCineSeen.contains(idx)`) → `cards_screen._buildGareCinematic()`
    affiche le nom de la gare + `kGareIntros[idx]` et **OBLIGE à sortir des
    cartes** (bouton → `onClose`, marque `cardGareCineSeen.add(idx)` + save).
    Gare 0 (départ) marquée vue d'office (l'ouverture la couvre). Persisté.
  - **ÉLAN SUPPRIMÉ** (2026-07-01) : l'ancienne mécanique d'engagement
    (`cardElan`/`consumeLeg`/`rechargeElan`/`elanGateBlocking`) a été retirée du
    code — le rythme est porté par les crédits temps réel. NE PAS la ré-introduire.

### Équilibrage (`tools/sim_current.py`)
Parse les vraies cartes (regex, `requires` modélisé) et rejoue 4000 runs/profil.
**Cible (2026-06-22, DÉPART QUASI À ZÉRO demande user)** : **careless ~1% /
casual ~24% / smart ~99% / caring ~99%**. **Stats de départ = `kStartStat = 6`**
(anneaux ~10-15 % à l'ouverture, presque vides) → l'histoire commence **au bord
du gouffre**, à remonter en jouant.
**Le bois est le CARBURANT qui brûle à CHAQUE carte** (`kBaseBoisDrainPerCard
= 1`, toutes zones ; +`kColdBoisDrainPerCard` dans le froid) → réalimenter la
loco (corvée de bûches), 0 bois = mort. **1re cause de mort**. Ravitaillement
d'arrivée : **+9 bois / +5 soif / +7 faim / +4 moral** par gare (gare 0 incluse,
petit ravito de survie). Causes de mort = **mix bois (dominant) / moral / faim**.
**Dilemmes réels (FAIT, ~95 cartes)** : tout gain de moral se paie en survie et
inversement — plus AUCUNE option « gratuitement bonne ». Template = chien g2
`G2ev_chien`. Pertes ×**1.20** (ramené de ×1.48 : le départ quasi à 0 + les
coûts des dilemmes suffisent à la tension). Seule G14 garde un gain moral pur. Les recharges « wagon » du sim
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
flags `asset_*` sont posés par les cartes (`cards_data`) au fil des gares
(état RÉEL, front-load appliqué 2026-07-01) : paillasse g1 /
gamelle+lampe+**filtre** g2 / atelier+carillon+carnet g3 / fauteuil+**poêle**
(cuisinière+poêle à bois) g4 / vrai lit g5 / console+douche+tourne-disque+
cellier(wagon2) g6 / commode+table de jeu g7 / trousse+lanterne+panier g9 /
bain+hydro g10. Chien=`aLeChien` (g2),
sœur=`aLaSoeur` (g5), radio=`aLaRadio` (g4). radio+bouquet(`deco_fleurs`) à
l'atelier, gatés par `aLaRadio` / `souvenir_fenetre` (pas des `asset_*`).

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
  `resetForNewGame`, `kStartStat = 6` (départ quasi à zéro).
- `lib/models/reigns_engine.dart` — voir section moteur de cartes.
- `lib/services/audio_service.dart` — Singleton audio. `ambient_train`,
  `fire_crackle`, musique réactivée (3 morceaux day/night/cold), 9 SFX.
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
- **⚠️ FLUTTER ANALYZE = MANUEL (session distante)** : les sessions Claude Code
  de ce projet tournent dans une **VM Linux cloud SANS Flutter** (réseau
  verrouillé au repo → impossible à installer). Je NE PEUX PAS lancer
  `flutter analyze`/`run`/build ici. NE PAS prétendre le contraire, NE PAS dire
  « pas sur cette session » (ça sous-entend un ailleurs que je ne peux pas
  garantir). **Workflow convenu (user 2026-07-01)** : quand une vérif Flutter est
  nécessaire, je **donne la commande** à l'user, il la lance sur son Mac et me
  colle la sortie :
  `cd /Users/jeanperraudeau/survival && git pull origin main && flutter analyze lib/`
  (cible : 0 issue). Vérif côté VM = à la main (grep de refs pendantes) + sim Python.
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
- `recut_clean.py` — découpe/normalisation de sheets (bottom-center).
- `make_shen_sheet.py` — assemblage d'une sheet Shen ; `process_sister.py` —
  traitement des sprites de la sœur.
- `cut_bath_shower.py`, `cut_duos_cold.py`, `cut_new_props.py` — découpe des
  lots d'anims/props (bain/douche, duos & froid, nouveaux objets).
- `reduce_frames.py` — réduction/restauration de frames Shen.
- `generate_app_icons.py`, `measure_sprite_bboxes.py`.
- `story_viz/` — générateurs des visuels de design dans `docs/`.

---

## Ce qui reste à faire

### 🚨 Priorité — développer le contenu narratif
- **Étoffer les cartes** : écrire de NOUVEAUX fillers directement dans
  `cards_data.dart` (source de vérité du contenu). `docs/train_cosy_arc.twee`
  reste une référence de l'ARC (14 gares + fins) mais PAS des fillers — ne pas
  le traiter comme la source des cartes. Rendre chaque gare / chaque menace plus
  riche, distincte, mémorable. Écrire le contenu des cartes-souvenirs (placeholders).
- **Géo de départ** ✅ tranchée : **Kogarashi = la ville natale = la gare 1**
  (pas de nœud séparé ; le train fuit Kogarashi en flammes, 1re halte à sa gare
  en ruines). Wagons traversables dès le départ (option a, décision user).
- **Cinématiques d'entrée en gare** ✅ version texte (`kGareIntros`).
- **Tamagotchi** : ✅ décroissance faim/soif + besoins confort sommeil/hygiène
  (faite). Reste éventuellement un axe « jeu » (s'occuper du chien/sœur) si on
  veut pousser. Pas de jauge HUD dédiée pour le confort (bulle de pensée only) —
  à décider si on veut les rendre plus visibles.
- **Boutique IAP** — confort only, ne JAMAIS bloquer l'histoire.

### Priorité moyenne
- Crédits de cartes : **ACTIFS** (`creditsEnabled = true`, confirmé user
  2026-07-01) — c'est le système de rythme en place (tirer 1 carte = 1 crédit,
  recharge +1/5 min temps réel ; cf. section RYTHME). L'ancien ÉLAN a été
  **supprimé** (voir plus bas).
- Refaire les musiques si besoin.
- Vraie tenue d'hiver (sprites) — REPORTÉ à la toute fin (décision user).
  (Poêle interactif ✅ déjà fait ; bac hydro semer/récolter ✅ déjà fait.)

### Repris du handoff (session 2026-07-01, ex-ETAT_SESSION.md)
- **Répartition des objets par wagon** ✅ (décisions user 2026-07-02) :
  SALON = carnet, gamelle, **table de jeu** (`jeu`, échangée avec le
  tourne-disque), carillon, fauteuil, panier, déco-souvenirs photo/peluche.
  ATELIER = gazinière, lampe, bac, filtre, poêle, radio, console,
  **tourne-disque** (posé sur la console). CELLIER = bain/douche, lanternes,
  commode, trousse, **bouquet** (`deco_fleurs`, champs `wagon2Fleurs*`).
  Positions BAKÉES dans les défauts (`salonProps`/`wagon1Props`, captures user).
- **Tap suit le drag** ✅ : les zones de tap (notebook/carillon/fauteuil/jeu/
  tourne-disque) lisent la position RÉELLE (`slx()`/`w1x()`), plus de consts
  figées. Seul `bedCenterX` reste fixe (lit non déplaçable).
- **Sœur autorisée à l'atelier** (de JOUR ; la nuit elle dort au salon).
  `playduo` se déclenche à la table de jeu du SALON (`_atJeu` = `_inLiving &&
  !night`) ; le tap sur la sœur ne cycle que lecture↔câlin.
- **HUD d'ajuster** ✅ hors de TrainRocking (sinon rognés par le scale ×1.03) +
  pad tap-ligne : sélection d'un objet dans la liste puis ◀▶▲▼ (pos) / −＋
  (taille) — remplace le pincer pour les petits objets.
- **Répartition des déblocages** étalée sur les 14 gares (1-2 objets/gare) +
  `asset_atelier` g3. **6 objets câblés** : tourne-disque, carillon 13f, fauteuil
  lecture, panier chien, table de jeu, console. **firstaid** déplacé au cellier.
- **Bouton debug** = pastille 🐞 bas-gauche (1 tap, plus de triple-tap).
- Reste à faire (repris du handoff) :
  1. **Front-load des gains** ✅ FAIT (2026-07-01) : filtre g4→g2,
     poêle+cuisinière g8→g4, textes des cartes G2/G4/G8 réécrits. NB : le sim
     n'en voit rien (il abstrait la date de déblocage en « recharges wagon »).
  2. **Tap qui suit le drag** ✅ FAIT (2026-07-02) : zones de tap liées aux
     positions réelles (`slx()`/`w1x()`).
  3. **Baker les positions par défaut** ✅ FAIT (2026-07-02, captures user) :
     coords figées dans `salonProps`/`wagon1Props` + `applyBakedLayout`.
  4. Étoffer les cartes des **gares 12-14** (climax — g13 renforcée ✅).
     Boutique IAP confort-only.

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
