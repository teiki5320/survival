# État de session — 2026-07-01 (HANDOFF)

> À lire en premier dans la nouvelle conversation, puis **fusionner dans
> CLAUDE.md** (section « Ce qui reste à faire ») et supprimer ce fichier.

**Build actuel : 0.99.153+357.** Branche dev `claude/sharp-turing-351885`,
poussée aussi sur `main` (déclenche Xcode Cloud → TestFlight). Le contexte de la
session précédente était saturé (« requête trop volumineuse ») → reprise en
conversation neuve.

## Fait cette session
- **Répartition des déblocages étalée sur les 14 gares** (1-2 objets/gare) +
  atelier rangé (`asset_atelier`, g3).
- **6 nouveaux objets câblés** : tourne-disque (statique), **carillon animé 13f**,
  **fauteuil lecture** (`chair_read`, tap → Shen lit), **panier chien**
  (`dog_basket`, la nuit le chien y dort), **table de jeu** (`jeu.png`, tap +
  sœur → anim `playduo`), **console** (poser des objets dessus). Anims
  `chair_read`/`dog_basket`/`playduo` **uniformisées** (frames même taille).
- **firstaid déplacé** salon → cellier (sur la commode, champs `wagon2Firstaid*`).
- **Fix taille objets salon** : largeur dérivée de l'**aspect réel de l'image**
  (map `_salonAspect` dans `side_scroll_scene.dart`) → la boîte d'ajuster colle
  pile à l'objet, **identique en normal et en mode modifier**, sur tout écran.
- **Bouton debug VISIBLE** (pastille 🐞 bas-gauche, 1 tap) au lieu du triple-tap.
- **Rails de l'atelier** réaffichés (offset vertical = 0 comme le cellier).
- **Mode ajuster salon complet** : tous les objets déplaçables (déco/radio),
  HUD coords 2 colonnes, persistance (save au ✓).
- **+22 fillers** (gares 1-11, dilemmes moral↔survie). Total ~189.
- **Cartes-souvenirs** : déjà écrites (plus des placeholders).
- **Assets orphelins supprimés** : table/mirador/carillon_static/rug/plant/plaid/
  garden + tout `assets/plants/` (24 sprites, vieux mini-jeu hydro) + entrée
  pubspec.
- **Équilibrage re-simulé OK** : careless ~1% / casual ~22% / smart ~99% /
  caring ~99%.

## ⚠️ EN COURS (WIP — À FINIR EN PRIORITÉ)
**Bascule radio + bouquet (`deco_fleurs`) + console + table de jeu du salon vers
l'ATELIER** (`_buildWagon1Adjustable` + `wagon1Props`). Ajoutés à l'atelier,
retirés du salon (remplacés par `SizedBox.shrink`). **Reste à faire :**
1. Supprimer la méthode `_buildRadio` du salon, devenue **inutilisée** (lint
   `unused_element`) — et nettoyer les entrées `salonProps`/`_salonAspect`
   `radio`/`deco_fleurs`/`console`/`jeu` qui ne servent plus au salon.
2. Le tap `playduo` de la table de jeu **ne se déclenche plus** (la sœur vit au
   salon, la table est à l'atelier) → **trancher** : soit la table reste pure
   déco à l'atelier, soit garder le jeu au salon, soit permettre la sœur ailleurs.
3. `flutter analyze lib/` doit repasser à **0 issue**, puis tester.

## À FAIRE ENSUITE (priorités)
1. **Front-load des gains** (validé, PAS appliqué) : filtre g4→**g2**, poêle+
   cuisinière g8→**g4** + réécrire les textes concernés (cohérence).
2. **Tap qui suit le drag** : les zones de tap (`tourneDisqueCenterX`, etc.) sont
   des constantes figées → lier la proximité à la position réelle (`salonProps`)
   pour que taper un objet marche là où on l'a déplacé.
3. **Baker les positions par défaut** : quand l'user aura placé les objets (mode
   ajuster ✏️ + capture du HUD), figer les coords dans `salonProps`/`wagon1Props`.
4. Étoffer les cartes des **gares 12-14** (climax). Boutique IAP confort-only.
   Vraie tenue d'hiver (sprites) — ou via l'objet « tricot » (#17).

## Rappels techniques
- **`flutter analyze lib/` avant chaque push** (cible 0 issue). SDK web dans
  `/tmp/flutter/bin/flutter`.
- **Toujours bumper version + build** (`pubspec.yaml` + `loading_screen.dart`).
- **Aperçus d'images** : sauver en **petit JPEG basse qualité** (~15 Ko) sinon
  l'API rejette (« request too large »).
- Assets générés par l'user (fond blanc #FFFFFF, je key-out) ; anims AutoSprite
  ou traits rouges/fond vert.
