# Train Cosy — mémoire Claude

Ce fichier sert de **mémoire persistante** entre sessions. Lis-le au démarrage
de chaque nouvelle conversation avant d'agir sur ce repo.

---

## Le projet

**Train Cosy** est une app Flutter / iOS en cours de prototype : un jeu narratif
**cosy post-apocalyptique**. Une jeune femme (l'« habitante ») vit seule dans
le dernier wagon d'un train qui roule à travers un monde mort. Elle interagit
avec son environnement (lit, poêle, jardin hydroponique, lampe, plaid), le
train tangue doucement, le paysage défile à l'envers par la fenêtre arrière
(rails fuyantes vers l'horizon, silhouettes de zombies au loin), et l'ambiance
bascule jour / nuit.

**Esthétique cible** : Studio Ghibli + lofi anime, hand-painted, palette warm
honey browns / cream / soft amber dedans, cold blue / pale fog dehors.

**État actuel** : prototype visuel solide + boucle CI/CD opérationnelle.
Mécaniques de jeu (sauvegarde, progression, narratif) à construire.

---

## Workflow technique

- **Repo** : `teiki5320/survival` (le nom historique, le projet s'appelle
  Train Cosy en interne).
- **Branche principale** : `main`. Tout autre travail sur `claude/<feature>`.
- **PR → main, merge automatique** : c'est Claude qui crée et merge la PR via
  les tools MCP GitHub. L'utilisateur a explicitement délégué la merge.
- **CI** : Xcode Cloud watch `main`. À chaque push, build + upload TestFlight
  + auto-distribution au groupe interne **Dev**. ~20 min entre merge et notif
  iPhone.
- **Bundle ID iOS** : `com.teiki5320.trainCosy`.
- **App Store Connect** : app créée, TestFlight Internal Testing actif.
- **Flutter** : projet scaffold via `flutter create`, dossier `ios/` committé.
  ci_scripts dans `ios/ci_scripts/ci_post_clone.sh` (installe Flutter sur
  Xcode Cloud, pin du build number à `CI_BUILD_NUMBER`).

## Workflow assets

L'utilisateur génère les images via **OpenArt** (modèle Nano Banana 2 le plus
souvent), depuis son Mac ou iPad. Process :

1. Génère dans OpenArt avec un prompt qu'on a calibré.
2. Drop le PNG dans `assets/_incoming/` (drag-and-drop GitHub web depuis
   l'iPad fonctionne, sinon `cp + git add + push` depuis le Mac).
3. Me dit « poussé » dans le chat.
4. Je récupère, key out le fond noir (`tools/key_out_black.py`), déplace vers
   le chemin canonique (`assets/objects/`, `assets/characters/`,
   `assets/background/`, `assets/icon/`), met à jour `scene.json` (slot +
   interaction), PR, merge.

OpenArt **n'exporte pas vraiment en transparence** — ça sort soit avec un
damier baked-in soit avec un fond noir. Toujours demander **fond noir pur**
dans le prompt, je keyerai derrière.

---

## Checklist prompt OpenArt

Voir aussi `lib/widgets/...` pour le contexte. Chaque prompt passe par cette
grille avant proposition :

1. **Sens / vue** — angle précis en degrés (« 3/4 front-quarter angle, about
   25 degrees off front from the right »). Le wagon est en perspective
   frontale → objets en 3/4 cohérent.
2. **Fond** — `solid black background (#000000)`, `no shadow on ground`, `no
   surface under`, `no walls`.
3. **Cadrage** — `full body / object visible with comfortable margin all
   around`, jamais coupé aux bords.
4. **Éclairage** — `warm honey golden lighting from the upper left` (signature
   de Train Cosy).
5. **Style** — `anime illustration style, Studio Ghibli inspired, hand-painted
   texture, lofi cozy aesthetic`.
6. **Ratio** — adapté au contenu : 1:1 (objet compact), 2:3 portrait (objet
   haut / perso), 3:2 ou 16:9 (objet large / paysage). OpenArt cap à 16:9.
7. **Négatif explicite** — `no text, no letters, no watermark, no characters,
   no scene around`. L'IA respecte mieux le négatif explicite que les
   omissions.
8. **Cohérence interne** — palette warm honey browns + cream + soft amber +
   hint of dusty rose.

Pour des sheets multi-poses : `character sheet of the same young woman in N
distinct poses arranged horizontally side by side`, plus `absolutely
identical character across all panels: same face, same long flowing black
hair, same worn faded oversized white holey t-shirt, same bare legs and feet`,
plus pose par pose en colonne. L'IA dérive sur 6+ frames, garde 3 par sheet
max.

---

## Design choices verrouillés

- **Ratio app** : 16:9, **landscape locked** (Info.plist
  `UISupportedInterfaceOrientations` ne contient que `LandscapeLeft` et
  `LandscapeRight`, plus `UIRequiresFullScreen=true` sinon iPad rejette
  l'upload App Store Connect).
- **Wagon view** : one-point perspective looking toward la fenêtre arrière.
  Le perso (l'« habitante ») est dans ce wagon, on la voit depuis l'« avant »
  intérieur. La locomotive est conceptuellement DERRIÈRE elle ; à travers la
  fenêtre arrière elle (et nous) voit le monde qu'on laisse derrière, qui
  défile EN S'ÉLOIGNANT (effet recede = zoom-out de l'image landscape).
- **Train rocking** : roulis subtil de toute la scène (±4 px vertical / 2.4 s
  + ±0.006 rad rotation / 1.7 s + ±0.6 px jitter / 0.42 s). Trois phases
  désynchronisées exprès. `TrainRocking` widget enveloppe le tout.
- **Slots system** : coordonnées normalisées `0..1`, **centre + dimensions**
  (x, y = centre ; width, height = taille). Tous les slots dans
  `assets/config/scene.json`. **Re-rescaler les slots, c'est juste éditer le
  JSON** — pas besoin de toucher au code.
- **Window area** : `windowArea` dans scene.json (avec optional
  `cornerRadius`). Le paysage est rendu **en overlay POSÉ par-dessus** le
  wagon (pas de découpe). Si la zone n'est pas alignée, c'est juste 4
  chiffres dans le JSON.
- **Heroine taille** : ~60% hauteur écran debout. Lit ~50% largeur. Tout doit
  être à l'échelle humaine, **pas dollhouse**.

---

## Mécaniques en place

- **Day / night ambience** : 2 wagons (jour, nuit) + 2 paysages avec swap
  cross-fade quand on toggle. Manual pour l'instant (toggle dans debug menu).
- **Recede landscape** : 2 layers cross-fade avec scale 1.55 → 1.0 sur cycle
  10 s. Effet « rear-view, le monde s'éloigne ». Toggle « Paysage qui
  défile ».
- **Character poses + actions** : 6 poses (3 standing, 3 sitting) + 6 actions
  scriptées (sequences de poses avec durées). Auto-cycle entre poses idles
  (configurable `cycleSeconds`), interrompu par actions ou pose pin manuelle.
- **Halo-only transitions** : quand la pose change, perso fade out au point A,
  un halo chaud ambre voyage en arc vers le point B, perso fade in. PAS de
  slide visible. Durée 1.8 s.
- **Tap-to-interact** : chaque objet peut déclarer une `interaction`
  (`kind: "pose" | "action"`, `target: <id>`). Tap → si perso cachée, elle
  apparaît, puis exécute la réaction.
- **Cracked glass** : `state.crackWindow(impactPoint, intensity)` dessine un
  patron de fissures procédural avec reveal 700 ms. Prêt pour événements type
  « zombie tape la vitre ».
- **Atmosphère** : dust particles (procédural, ON par défaut) +
  optionally pluie sur la vitre (procédural, OFF par défaut).
- **Audio** : `AudioService` + `audioplayers` ^6.1.0. Boucle ambient train,
  music day/night cross-faded, SFX par objet (`sfx_<id>.mp3`). Silent tant
  qu'on n'a pas drop les fichiers dans `assets/audio/`.
- **Slot editor visuel** (debug) : toggle « Placer les objets (slots) »
  → top chip row liste tous les slots → tap pour sélectionner → drag 4 coins
  + poignée centrale → JSON readout en haut → copier-coller dans scene.json.

---

## Outils Python (`tools/`)

- `key_out_black.py` — chroma-key le fond noir → vraie transparence. Tolérance
  douce (brightness < 18 → 0, > 60 → 255, interpolation entre les deux pour
  un edge anti-aliasé). Use case principal : objets et persos exportés par
  OpenArt.
- `split_character_sheet.py` — découpe une sheet horizontale 3-poses en 3
  PNGs individuels et applique `key_out_black` à chaque cellule.
- `trim_character_dividers.py` — retire les bandes grises (1-2 px) laissées
  par les dividers entre les panneaux de la sheet. Fixe les contours blancs.
- `generate_app_icons.py` — redimensionne `assets/icon/app_icon.png` dans les
  15 tailles iOS attendues. Re-run après chaque drop d'une nouvelle icône.
- `generate_placeholders.py` — placeholders rectangles colorés pour les objets
  qui n'ont pas encore d'asset réel (lamp, plant, plaid pour l'instant).
- `generate_landscape_placeholders.py` — placeholders panoramiques (gradient
  + silhouettes). **Plus utilisé**, les paysages sont maintenant les vrais
  assets AI.
- `punch_wagon_window.py` — **DEPRECATED**. Détourait la zone fenêtre du
  wagon. Remplacé par l'overlay landscape (on n'altère plus le wagon).

---

## État du contenu

**Assets réels en place** :
- Wagons jour + nuit (perspective intérieure vers fenêtre arrière)
- Paysages jour + nuit (rear-view rails fuyantes + zombies + arbres morts)
- Personnage : 6 poses (standing_idle, standing_turned, standing_stretch,
  sitting_cross, sitting_hugged, sitting_side). Tirées de 2 sheets horizontales.
- Lit (bed.png) — Studio Ghibli, vue 3/4
- Poêle à bois (stove.png) — front view, fire glowing, firewood bottom
- Jardin hydroponique (garden.png) — horizontal, racines visibles dans l'eau
- Icône d'app

**Placeholders rectangles colorés** (à remplacer en priorité) :
- `assets/objects/lamp.png` — prompt prêt (lanterne vintage 2:3 portrait)
- `assets/objects/plaid.png` — prompt prêt (couverture pliée 3:2 landscape)
- `assets/objects/plant.png` — pas vraiment urgent, mais peut être upgrade

**Pas encore générés** (idées validées) :
- Mini-jardin sur table (prompt prêt)
- Jarres de germination (prompt prêt)
- Bocaux de conserves maison
- Carnet ouvert avec croquis
- Radio à manivelle
- Kit de couture déplié
- Sac à dos, boîtes de conserve, etc. — toute la liste survie post-apo

**Audio** : zéro fichier pour l'instant. Le code Flutter no-op silencieusement
sur les fichiers manquants. Drop les .mp3 dans `assets/audio/` selon ces
noms :
- `ambient_train.mp3` (boucle continue, 15-30 s)
- `music_day.mp3` / `music_night.mp3`
- `sfx_<object_id>.mp3` pour chaque objet (bed, lamp, plant, plaid, stove,
  garden)

---

## Roadmap à venir

Phase imminente :
- Générer lampe + plaid en assets réels (prompts prêts dans l'historique).
- Drop les audio files.
- Ajuster les placements via le slot editor visuel et figer les coords dans
  `scene.json`.

Phase suivante (mécaniques de jeu) :
- **Sauvegarde d'état** (SharedPreferences) — objets visibles, pose
  manuelle, ambiance, slot overrides persistés entre relances.
- **Cycle jour / nuit automatique** sur ~5-10 min réelles.
- **Mécanique vêtements** : la perso démarre en t-shirt troué (cassé pour la
  narrative). Débloquer des couches de vêtements (pull, manteau, plaid sur
  épaules) = sprites superposés. Lié au froid de la nuit.
- **Système de déblocage** : début wagon vide, objets se débloquent au fil
  des sessions ou par events.
- **Schedule d'actions narratives** : « se réveiller » au matin, « aller au
  lit » au soir. Auto-triggered par l'heure du jeu.

Phase narrative :
- **Journal / monologue intérieur** : bulles de texte courtes sur les actions
  / interactions / changements de moment.
- **Événements aléatoires nuit** : bruit suspect, zombie qui frappe à la
  vitre (déclenche `crackWindow()`), lumière qui s'éteint.
- **Choix simples** : « aller voir / se cacher / ignorer ». Stats peur /
  courage. Mini-moteur narratif.

Phase contenu :
- Plus de poses (dormir, manger, lire, regarder par fenêtre latérale).
- Plus d'objets (cf. liste survie ci-dessus).
- Plusieurs wagons (swipe gauche / droite) — chaque wagon a sa propre déco,
  potentiellement un autre survivant.

---

## Communication avec l'utilisateur

- **Langue** : français, ton décontracté direct.
- **Style** : cash, pas de blabla, pas de flatterie. Quand quelque chose ne
  va pas, lui dire. Quand quelque chose est cool, lui dire aussi.
- **Hier on a appris** : ne pas survoler l'analyse visuelle (proportions,
  intégration, échelle). Vraiment regarder l'image qu'il envoie et identifier
  les problèmes concrets. Il pousse à la rigueur, c'est sain.
- **Délégations explicites** :
  - Merge des PRs : OUI, sans demander.
  - Décisions UX / esthétiques : NON, toujours lui proposer.
  - Génération d'assets via OpenArt : c'est LUI qui génère, je fournis les
    prompts.
  - Drop de fichiers dans le repo : c'est lui (Mac terminal ou iPad GitHub
    web).
- **Outils interdits** : pas de Xcode Cloud manipulation (pas d'API utilisable
  dans cette config), pas de modifications iOS hors `Info.plist` /
  `project.pbxproj` standards Flutter.

---

## Références d'inspiration

- **Lexploratrice2025** (YouTube wallpaper) — la réf clé. Vue intérieure de
  wagon, perso qui dort sur lit, fenêtre arrière, zombies dans le brouillard
  derrière. C'est l'esthétique exacte qu'on poursuit.
- **Studio Ghibli** — Le Voyage de Chihiro (train sur l'eau), Le Château
  Ambulant (intérieurs cosy chaleureux), Princesse Mononoke (palette).
- **Genre cosy post-apo** — Stardew Valley pour le rythme contemplatif,
  Spiritfarer pour le ton mélancolique-doux, Disco Elysium pour le monologue
  intérieur (future feature).
