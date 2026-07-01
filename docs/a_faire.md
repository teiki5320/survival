# Train Cosy — Ce qu'il reste à faire (côté toi)

> Direction : **jeu 100% narratif (cartes Reigns)**. Aucun combat, aucun
> mini-jeu (menace de gare = une carte à choix → conséquence directe).
> La roadmap complète et à jour vit dans **`CLAUDE.md` → « Ce qui reste à
> faire »**. Ce fichier ne liste que ce qui dépend de TOI (art, décisions,
> tests). Les décisions ci-dessous sont **déjà tranchées** — gardées ici pour
> mémoire.

## 1. Tester sur TestFlight
- Installer la **dernière build** (numéro en bas de l'écran de chargement ;
  inférieur = ancien code, délai Xcode Cloud).
- Vérifier : Nouvelle partie → cinématique d'ouverture → wagon vide → bulles de
  tuto ; chien absent au départ (arrive gare 2) ; sœur absente (gare 5) ;
  wagon-cellier verrouillé (gare 6) ; map via la loco ; cartes via « Débuter /
  Continuer le voyage » ; à chaque gare une carte d'épreuve résolue par un choix ;
  ravitaillement d'arrivée appliqué à chaque gare ; cinématique de gare qui
  force la sortie des cartes.

## 2. Décisions de design — TRANCHÉES (mémo)
- **Géo de départ** ✅ Kogarashi (ville natale) = la gare 1 ; le train la fuit
  en flammes, 1re halte à sa gare en ruines. Wagons traversables dès le départ.
- **Crédits de cartes** ✅ ACTIFS (refonte rythme 2026-06-22) : tirer une carte
  coûte 1 crédit, recharge +1/5 min en temps réel (`creditsEnabled = true`).
  L'ancien système d'ÉLAN est désactivé (`elanEnabled = false`), code inerte.
- **Chien** ✅ gare 2 (Kurogane, 1er vrai arrêt), pas gare 1.
- **Placement objets** ✅ étalé sur les 14 gares + front-load : filtre g2,
  poêle+cuisinière g4 (voir CLAUDE.md pour la liste exacte à jour).

## 3. Assets / art (toi via OpenArt / AutoSprite)
- **Tenue d'hiver** : sprite dédié (warmth 8) encore à faire (écharpe peinte
  en attendant). Reporté à la toute fin.
- **`open_door` vs idle** : l'oreille ne raccorde pas (dehors vs sous les
  cheveux). Régénérer l'un pour un raccord parfait si tu veux.
- **Cinématiques d'entrée en gare** : en TEXTE (`kGareIntros`). Fournir des
  images si tu veux les imager comme l'ouverture.

## 4. Ce que JE peux encore coder
- **Étoffer le contenu des cartes** directement dans `cards_data.dart` :
  nouveaux fillers, gares 12-14 (climax), contenu des cartes-souvenirs.
- **Boutique IAP** (confort only, jamais bloquer l'histoire) — brancher le
  vrai paiement.
- **Tap qui suit le drag** + **baker les positions** des objets une fois tes
  placements validés (voir CLAUDE.md).
