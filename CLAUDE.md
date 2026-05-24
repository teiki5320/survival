# Train Cosy — mémoire Claude

Ce fichier sert de **mémoire persistante** entre sessions. Lis-le au démarrage
de chaque nouvelle conversation avant d'agir sur ce repo.

---

## Le projet

**Train Cosy** est une app Flutter / iOS en cours de prototype : un jeu narratif
**cosy post-apocalyptique**. Une jeune femme (l'« habitante ») vit seule dans
le dernier wagon d'un train qui roule à travers un monde mort. Elle interagit
avec son environnement, le train tangue doucement, l'ambiance bascule jour /
nuit. Le jeu est désormais un **side-scroller** vue de coté (et plus une vue
intérieure 1-point perspective comme initialement) : le wagon est centré, le
paysage défile latéralement derrière, la locomotive est à gauche.

**Esthétique cible** : Studio Ghibli + lofi anime, hand-painted, palette warm
honey browns / cream / soft amber dedans, cold blue / pale fog dehors.

**État actuel** : prototype visuel solide + boucle CI/CD opérationnelle.
Animations 49-frames en place. Locomotive scène + carte du monde + events
narratifs câblés. Mécaniques de progression / sauvegarde à construire.

---

## Workflow technique

- **Repo** : `teiki5320/survival` (le nom historique, le projet s'appelle
  Train Cosy en interne).
- **Branche** : **`main` uniquement**. L'utilisateur a explicitement dit de
  bosser direct sur main, pas de branches Claude. **NE PAS** créer de branche
  `claude/<feature>`.
- **CI** : Xcode Cloud watchait `main` (build + upload TestFlight auto). À
  date l'utilisateur a **désactivé** la distribution auto sur xcloud pour
  économiser les quotas TestFlight (« j'ai enlevé sur xcloud pour qsue ça
  build pas sur testflight »).
- **Xcode Cloud "Archive - iOS" en rouge** : ouvrir l'onglet **Erreur**
  pour voir le message. Si c'est **"Preparing build for App Store
  Connect failed"** → c'est l'étape d'upload TestFlight qui rejette
  (version déjà présente). Fix : **bump `version:` dans `pubspec.yaml`**
  (incrémenter le `+N` au minimum, ex `0.11.0+1` → `0.11.1+2`) puis
  re-push. Les .ipa sont quand même générés (artefacts dispos) mais
  l'app n'apparaît pas sur TestFlight sans bump.
- Si pas de "Preparing build" failure et que les artefacts sont là, le
  build est OK et l'app est dispo sur TestFlight — pas besoin de
  retrigger.
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

## Règles de commit / push

- **Commit + push à chaque modification** sans attendre validation explicite.
  L'utilisateur a explicitement levé (2026-05-23) la restriction qui était
  en place avant (« tu commits seulement quand je te le dis »). Retour au
  mode normal : tu prépares un fix → tu commits → tu push, dans la foulée.
- Si t'enchaînes plusieurs petits fixes liés sur le même sujet, tu peux
  les empiler dans un seul commit pour garder l'historique propre.
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
   vers le chemin canonique (`assets/objects/`, `assets/characters/`,
   `assets/background/`, `assets/icon/`).

OpenArt **n'exporte pas vraiment en transparence** — fond noir baked-in.
Toujours demander **fond noir pur** dans le prompt, je keye derrière.

Process AutoSprite (anims 49-frame) :
1. L'utilisateur génère une sheet ou un dossier de 49 PNGs depuis AutoSprite.
2. Drop dans `assets/characters/<anim_name>_<i>.png` (i = 1..49).
3. Je l'intègre dans `side_scroll_scene.dart` ou `locomotive_scene.dart`
   (state machine + précache + bbox/feetRatio).

**Règles AutoSprite (décidées le 2026-05-23)** :
- **Ne JAMAIS faire de preview** (`generate_asset_preview`). L'utilisateur
  préfère dépenser 5 crédits sur une anim choisie au lieu de 1 cred sur
  4 previews dont 3 ne serviront pas. Génère directement la version
  finale.
- **Toujours valider le coût AVANT toute dépense**. Annoncer le nombre
  de crédits utilisés et attendre OK avant de lancer. Exceptions sans
  besoin de valider : `create_asset` (save d'une URL = 0 cred),
  `remove_asset_background` (gratuit aussi sur asset déjà saved).
- Tarif référence : `animate_asset` legendary 49 frames = 5 cred,
  `regenerate_spritesheet` ≈ 5 cred par anim.
- **Pour les assets statiques nouveaux** : AutoSprite n'a PAS de
  "génération directe" — uniquement `generate_asset_preview` (1 cred
  obligatoirement = 4 variantes turbo). Donc pour un sprite statique
  nouveau, le workflow est : l'utilisateur le génère sur **OpenArt**
  (Nano Banana 2) puis drop le PNG dans le repo. Je donne le prompt,
  il génère, je key + intègre. Pas d'exception sauf accord explicite.

**MCP AutoSprite** : l'utilisateur a ajouté `https://www.autosprite.io/api/mcp`
(Bearer token) sur le **Claude Code CLI du Mac mini** uniquement
(`/Users/jeanperraudeau/.claude.json`). Une session **Claude Code on the web**
(comme la mienne quand je tourne dans la sandbox cloud) **n'y a pas accès** :
les MCPs sont figés au boot du container et ne sont pas synchronisés avec
l'UI Connecteurs de claude.ai. Donc si je tourne côté web, je ne peux pas
générer/régénérer des sprites moi-même — l'utilisateur lance les générations
depuis le Claude local du Mac, puis push, et je récupère côté web pour
intégrer. Ne pas reproposer 50 fois l'install MCP côté web, ça l'agace.

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

- `lib/main.dart` — App + `WagonScreen` qui héberge tout (state machine entre
  wagon / locomotive / map, FABs droite pour toggles + actions).
- `lib/widgets/side_scroll_scene.dart` — Scène wagon (parallax sky/horizon/
  rails, wagon image, héroïne avec state machine, bed adjust mode, horizon
  adjust mode).
- `lib/widgets/locomotive_scene.dart` — Cabine locomotive avec script de
  ramassage de bûches (idle → walk to woodpile → pickup → carry → throw →
  warm_hands près du feu).
- `lib/widgets/map_screen.dart` — Carte du monde, énergie + inventaire HUD,
  pins location avec disponibilité.
- `lib/widgets/location_event_screen.dart` — Dialog full-screen avec
  question + choices + outcome.
- `lib/widgets/atmosphere.dart` — DustParticles, Fireflies, FireGlow,
  HangingVines, CharacterHalo, DistantZombie, FootstepDust, WindowRain,
  ThoughtBubble, FireboxFlames (tous procéduraux, CustomPaint).
- `lib/widgets/train_rocking.dart` — Roulis subtil de toute la scène.
- `lib/models/game_state.dart` — Singleton `ChangeNotifier` (énergie max 5,
  refill +1/min, items map, flags set, unlocked locations set).
- `lib/services/audio_service.dart` — Singleton audio. Wrappers `_safe()` qui
  swallow les exceptions sur asset manquant. `playSfx` enregistre le listener
  `onPlayerComplete.first` **après** `play()` succès, avec `.catchError(_){}`
  pour pas crasher quand un player jeté disparaît.
- `lib/data/world.dart` — 3 Locations (station_abandonnee unlocked par
  défaut, depot_ferroviaire, village_fantome). Question/Choice models.

### Précisions side-scroll

- Heroine bounds : `heroXMin = 0.20`, `heroXMax = 0.82`.
- Bed dialé : `_bedLeft = 0.194`, `_bedTop = 0.448`, `_bedWidth = 0.280`.
  **NE PAS toucher**, l'utilisateur a réglé ça via l'adjust mode.
- Horizon adjust mode actif (FAB landscape) avec drag handles top + bottom
  + HUD numérique. Défauts bakés : `_horizonTop = 0.0`,
  `_horizonBottom = 0.179` (horizon s'arrête juste au-dessus des rails).
- **Bande blanche statique** sous les rails (`top: h*0.92, bottom: 0`,
  `ColoredBox(Colors.white)`) — c'est un placeholder à remplacer par un
  vrai asset sol (cf. pending).
- 49 frames par anim, 13 anims différentes (`walk_right`, `idle_right`,
  `sleep_right`, `dance`, `pickup`, `yawn`, `stretch`, `look_window`,
  `read`, `wake_up`, `door_push`, `warm_hands`, `carry_walk`).
- `newSquareSprites` (yawn/stretch/look_window/read/wake_up/door_push/
  warm_hands/carry_walk) sont 512x512 avec `feetRatio = 0.86` (bbox bottom
  à 86% de la hauteur sprite, pas 100%).
- `sourceFacesLeft = {'warm_hands'}` en locomotive : ces sprites face déjà
  à gauche, ne PAS mirror.
- door_push en wagon est rendu sans mirror (sprite déjà tourné vers la porte
  gauche).

### Locomotive

- Background `assets/background/locomotive.png` hard-mask keyé : seuls le
  rectangle de la porte (x=0.42..0.58, y=0.30..0.85) et le hublot rond
  (ellipse cx=0.51, cy=0.147, r=0.06W) sont transparents. Le reste est
  opaque pour éviter le bleed du wagon en dessous.
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

---

## État du contenu

**Animations 49-frames en place** : walk_right, idle_right, sleep_right,
dance, pickup, yawn, stretch, look_window, read, wake_up, door_push,
warm_hands, carry_walk.

**Backgrounds** : wagons jour (dirty / swept / windowed / clean), wagon
nuit, locomotive (cab vue de côté), 3 horizons (a / b / c) qui rotate
toutes les 45 s avec crossfade 2 s, horizon_night, sky / sky_night,
wagon_rails (strip de rails clean).

**Objets** : bed, stove, garden.

**Placeholders rectangles colorés** (à remplacer) : lamp, plaid, plant.

**Audio** : zéro fichier. Code no-op silencieusement. Drop quand prêts :
`ambient_train.mp3`, `music_day.mp3`, `music_night.mp3`, `sfx_<id>.mp3`
(door_open, door_close, clean, footstep, pickup, log_throw, fire_crackle,
etc.).

---

## Pending / en cours (fin de session 2026-05-22)

1. **Horizon clipping** — `_horizonBottom = 0.179` baked (commit `4101ef9`).
   Horizon s'arrête juste au-dessus de la rails strip. Adjust mode toujours
   accessible via le FAB landscape pour ajuster live.
2. **Bande blanche sous les rails** — ajoutée (commit `3e9f142`) en
   placeholder. `ColoredBox(Colors.white)` à y=0.92..1.0. **À remplacer**
   par un vrai asset « sol » que l'utilisateur génère via OpenArt. Prompt
   fourni : strip horizontal post-apo, dirt + ballast stones + dry grass
   + small rusty debris, sans rails, fond noir top 60% pour keying, 16:9.
   Drop dans `assets/background/foreground_band.png` (ou
   `ground_band.png`), je key et intègre.
3. **Transparence locomotive sur wagon_swept.png** — sur le wagon « sale mais
   sol propre » (stage 1 = swept), l'arrière de la locomotive a des zones
   transparentes qui laissent voir l'horizon à travers. Asset à fixer (soit
   regenérer côté OpenArt, soit repeindre opaque côté Python). Pas regardé
   en détail.
4. **Close-ground parallax abandonné** — j'avais ajouté une 4e couche
   parallax procédurale rapide sous les rails (`_CloseGroundPainter`),
   l'utilisateur a dit « n'importe quoi, reviens à celui d'avant » et j'ai
   reverté. Ne PAS le ramener.
5. **Audio bug fixé** (commit `7482e98`) : `playSfx` enregistre maintenant
   `onPlayerComplete.first` après play() succès avec catchError swallow.

---

## Roadmap après ces fixes

Phase contenu :
- Lamp + plaid en assets réels (prompts prêts).
- Drop des audio files.
- Plus d'objets (mini-jardin sur table, jarres de germination, bocaux,
  carnet, radio à manivelle, sac à dos, etc.).

Phase mécaniques de jeu :
- **Sauvegarde d'état** (SharedPreferences).
- **Cycle jour / nuit automatique** sur ~5-10 min réelles.
- **Mécanique vêtements** : couches débloquables.
- **Système de déblocage** progressif.
- **Schedule d'actions narratives** auto (réveil matin, coucher soir).

Phase narrative :
- **Journal / monologue intérieur** : bulles courtes.
- **Événements aléatoires nuit** : zombie → `crackWindow()`, etc.
- **Plus de Locations** dans `world.dart` + plus de chains de Questions.

---

## Communication avec l'utilisateur

- **Langue** : français, ton décontracté direct.
- **Style** : cash, pas de blabla, pas de flatterie. Quand quelque chose ne
  va pas, lui dire. Quand quelque chose est cool, lui dire aussi.
- **TOUJOURS NUMÉROTER les listes / propositions / options** (1, 2, 3...).
  L'utilisateur répond par numéros (« 1, 5, 8 ») au lieu de retaper les
  noms. Bullets `-` à proscrire pour les listes de choix. Aussi valable
  pour les sous-listes : 1.1, 1.2, etc.
- **Analyse visuelle** : ne pas survoler (proportions, intégration, échelle).
  Vraiment regarder l'image qu'il envoie.
- **Délégations explicites** :
  - Commit : OUI à chaque modification. Voir « Règles de commit ».
  - Décisions UX / esthétiques : NON, toujours lui proposer.
  - Génération d'assets via OpenArt / AutoSprite : c'est LUI qui génère,
    je fournis les prompts.
  - Drop de fichiers dans le repo : lui (Mac terminal ou iPad GitHub web).
- **Outils interdits** : pas de Xcode Cloud manipulation (pas d'API), pas
  de modifications iOS hors `Info.plist` / `project.pbxproj` standards
  Flutter.
- **Pas d'estimations de temps** : il a explicitement dit que tout ce que
  je dis sur les délais est faux, donc je n'en donne plus.

---

## Références d'inspiration

- **Lexploratrice2025** (YouTube wallpaper) — la réf clé.
- **Studio Ghibli** — Voyage de Chihiro (train), Château Ambulant
  (intérieurs cosy), Princesse Mononoke (palette).
- **Genre cosy post-apo** — Stardew Valley (rythme), Spiritfarer (ton
  mélancolique-doux), Disco Elysium (monologue intérieur).
