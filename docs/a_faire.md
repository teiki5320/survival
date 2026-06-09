# Train Cosy — Ce qu'il reste à faire (côté toi)

## 1. Tester sur TestFlight (build 0.99.6+)
- Installer **build 0.99.6** (numéro affiché en bas de l'écran de chargement).
  Tant que c'est inférieur = ancien code (délai Xcode Cloud, hors de mon contrôle).
- Vérifier : Nouvelle partie → cinématique d'ouverture → wagon vide → bulles de
  tuto ; chien absent au départ ; wagon 2 verrouillé ; pas de silhouettes de
  fond ; lampe loco absente ; bouton « debug » bas-gauche ; map via la loco ;
  cartes via « Continuer le voyage » sur la map ; anims de mort des pillards.

## 2. Décisions de design (me dire, je code derrière)
- **Géo de départ** : la « ville natale » = la gare 1 actuelle, ou un point
  séparé (départ = fin) AVANT la gare 1 ? (bloque l'implémentation de la géo)
- **Crédits de cartes** : les cartes sont fixes maintenant (~2× plus par run).
  Garder le rythme actuel / assouplir / retirer les crédits ?
- **Chien** : reste gare 1 (chiot pendant la fuite) ou déplacé gare 2-3 ?
- **Placement objets** : valider ma répartition (lampe g2, table g2, gamelle g1,
  carnet g3, commode g6, poêle+trousse g8, bain+douche+lanternes g10) ou ajuster.
- **Combat gare 1** : tuto sauté (actuel) ou vrai petit combat d'intro ?
- **Atelier (FAB sur la map)** : garder en jeu normal ou passer en debug ?

## 3. Assets / art (toi via OpenArt / AutoSprite)
- **`open_door` vs idle** : l'oreille ne raccorde pas (dehors vs sous les
  cheveux). Régénérer l'un pour matcher si tu veux un raccord parfait.
- **Cinématiques imagées** : l'ouverture et les entrées en gare sont en
  TEXTE pour l'instant. Fournir des images si tu veux mieux.
- **Anims de chute brute + boss** (comme le `Fall` du lanceur) si tu veux
  qu'ils aient leur vraie mort (sinon ils restent en ragdoll).
- **`gare_combat_*`** : décors de combat par gare déjà là (9/14), en ajouter
  si tu veux 14 ambiances distinctes.

## 4. Ce que JE peux encore coder (une fois tes décisions prises)
- Géo de départ sur la map (après ta décision).
- « S'occuper de Shen » version Tamagotchi : besoins qui décroissent avec le
  temps (faim/soif/sommeil/hygiène/jeu) remontés par les objets.
- Cinématiques d'entrée en gare (version texte, comme l'ouverture).
- Une idée de combat distincte par gare (14 angles).
- Boutique IAP (4,99 € = 500 ferraille, confort only, jamais bloquer l'histoire).
- Brancher plus de gares sur le score de combat (sœur malade, accueil refuge…).
