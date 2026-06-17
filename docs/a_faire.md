# Train Cosy — Ce qu'il reste à faire (côté toi)

> Direction actuelle : **jeu 100% narratif (cartes Reigns)**. Les combats ont
> été **retirés** (option A : la menace d'une gare se résout en une carte à
> choix dont chaque option mène directement à sa conséquence). Aucun mini-jeu.

## 1. Tester sur TestFlight
- Installer la **dernière build** (numéro affiché en bas de l'écran de
  chargement). Tant que c'est inférieur = ancien code (délai Xcode Cloud).
- Vérifier : Nouvelle partie → cinématique d'ouverture → wagon vide → bulles de
  tuto ; chien absent au départ ; wagon 2 verrouillé ; map via la loco ; cartes
  via « Débuter / Continuer le voyage » sur la map ; à chaque gare une **carte
  d'épreuve** (chiot g1, brouillard g3, sœur au pont g5…) résolue par un choix ;
  ravitaillement d'arrivée appliqué à chaque gare.

## 2. Décisions de design (me dire, je code derrière)
- **Géo de départ** : la « ville natale » = la gare 1 actuelle, ou un point
  séparé (départ = fin) AVANT la gare 1 ? (bloque l'implémentation de la géo)
- **Crédits de cartes** : système désactivé (cartes fixes). Garder désactivé /
  réactiver un rythme / retirer complètement ?
- **Chien** : reste gare 1 (chiot pendant la fuite) ou déplacé gare 2-3 ?
- **Placement objets** : valider ma répartition (lampe g2, gamelle g1, carnet
  g3, filtre g4, commode g6, poêle+trousse g8, bain+douche+hydro+lanternes g10)
  ou ajuster.

## 3. Assets / art (toi via OpenArt / AutoSprite)
- **`open_door` vs idle** : l'oreille ne raccorde pas (dehors vs sous les
  cheveux). Régénérer l'un pour matcher si tu veux un raccord parfait.
- **Cinématiques imagées** : l'ouverture est imagée ; les entrées en gare sont
  en TEXTE. Fournir des images si tu veux les imager aussi.
- **Tenue d'hiver** : sprite dédié (warmth 8) encore à faire (écharpe peinte
  en attendant).

## 4. Ce que JE peux encore coder (une fois tes décisions prises)
- Géo de départ sur la map (après ta décision).
- « S'occuper de Shen » version Tamagotchi : besoins qui décroissent avec le
  temps (faim/soif/sommeil/hygiène/jeu) remontés par les objets.
- Cinématiques d'entrée en gare (version texte, comme l'ouverture).
- **Développer le contenu des cartes** : porter plus de fillers depuis
  `docs/train_cosy_trame.twee` (en ignorant l'ancien canon Vieux/enfant
  supprimé) pour étoffer chaque segment.
- Boutique IAP (confort only, jamais bloquer l'histoire).
