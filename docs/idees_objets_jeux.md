# Idées — jeux cosy & interactions par objet (meubler l'attente des crédits)

**Cadre** : on a retiré les COMBATS (pas raccord, trop lourds), mais les **jeux
cosy courts** sont permis. Règle : simple, satisfaisant, jamais punitif, inline
de préférence (tap sur un objet du wagon), durée 5–30 s. Le temps passé hors des
cartes laisse les **crédits** se recharger (+1 / 5 min), donc chaque activité
doit donner envie de rester un moment dans le train.

Validé par l'user (à développer) : **lire (seul/sœur)**, **corvée de bois**,
**activités qui donnent un crédit bonus**.

---

## 1) Liste de jeux / mini-activités cosy possibles

| # | Jeu | Geste | Récompense | Note |
|---|-----|-------|-----------|------|
| 1 | **Pêche à la fenêtre** | lancer la ligne, tap quand ça mord (timing simple) | +faim | nécessite le prop "ligne de pêche" |
| 2 | **Cuisine** | assembler / ne pas laisser brûler (timing) | +faim, +moral | cuisinière déjà là |
| 3 | **Jardinage hydro** | semer → arroser → récolter (timer RÉEL) | +faim | timer = lié à l'attente crédits |
| 4 | **Corvée de bois** (loco) | enfourner les bûches au bon rythme | +bois | ✅ validé (C11) |
| 5 | **Filtrer l'eau** | verser / doser (petit timing) | +soif | filtre déjà là |
| 6 | **Radio à manivelle** | tourner + caler une fréquence (slider) | fragment d'histoire (arc maman) | narratif |
| 7 | **Lecture** | seul ou avec la sœur, tourner les pages | +moral | ✅ validé (B8), histoires plus tard |
| 8 | **Baballe / caresse au chien** | lancer, le chien rapporte | +moral | anim mignonne |
| 9 | **Rangement du cellier** | placer les objets (mini "where") | wagon + beau | satisfaction visuelle |
| 10 | **Bain / respiration** | moment zen, rythme lent | +moral, +hygiène | déjà la vapeur |
| 11 | **Couture d'une tenue chaude** | petit craft | +outfitWarmth | utile pour le nord |

→ **Twist (E15)** : certaines de ces activités donnent un **crédit bonus** (pas
juste des stats) → l'attente devient un choix actif, pas une punition.

---

## 2) Par OBJET du train : interaction + cinématique/jeu (catégorie A)

> Chaque tap déclenche une mini-scène satisfaisante (anim + son) puis l'effet.

### Salon (wagon 1)
- **Paillasse / lit** — *Dormir* : fondu nuit → matin, Shen s'allonge, étoiles
  qui défilent. → +sommeil, **+1 crédit bonus** (le repos relance le voyage).
- **Lampe** — *Allumer/éteindre* : halo chaud, l'ambiance du wagon bascule.
- **Fenêtre** — *Contempler* : plan parallax du paysage qui défile, lumière qui
  change. → +moral léger. (L'attente *devient* le voyage.)

### Atelier (milieu)
- **Cuisinière** — *Cuisiner* : Shen coupe, le feu prend, l'assiette fume → elle
  mange au sol. (mini-jeu timing optionnel) → +faim.
- **Poêle à bois** — *Allumer* : gros plan flammes, le givre fond sur la vitre,
  la cabine se réchauffe. → chaleur (anti-froid).
- **Bac de culture** — *Semer / arroser / récolter* : la plante pousse en temps
  réel (Plant Tycoon). → +faim. Lien naturel avec l'attente.
- **Filtre à eau** — *Filtrer* : l'eau goutte, se clarifie, le verre se remplit
  (tank_0..5). → +soif.
- **Carnet** — *Écrire / relire* : pages manuscrites, une photo de famille
  glissée dedans → souvenirs & indices sur les parents. (narratif)
- **Trousse de secours** — *Se soigner* : panser une coupure (cf. cartes
  blessure) → stoppe un drain.

### Cellier (wagon 2)
- **Baignoire** — *Prendre un bain* : vapeur, détente, soupir. → +hygiène,
  +moral.
- **Douche** — *Se doucher* : pommeau, vapeur (_SteamPainter). → +hygiène.
- **Commode / armoire** — *Garde-robe* : essayer une tenue (mannequin), l'écharpe
  chaude. → +outfitWarmth, +moral.
- **Lanternes** — *Allumer* : FireGlow la nuit, ambiance chaude.

### Locomotive
- **Foyer / tas de bûches** — *Corvée de bois* (✅ C11) : ramasser et enfourner
  les bûches au bon rythme → +bois. Rendre le feu plus juteux (étincelles, ronfle).
- **Mini-carte de route** — *Regarder la carte* : la progression du voyage,
  la prochaine gare. → orientation + envie de continuer.
- **Radio à manivelle** — *Manivelle* (✅ #6) : caler une fréquence → bribes de
  voix (l'arc maman, gares 4→14). Récompense narrative pendant le temps mort.

### Compagnons
- **Le chien** — *Caresser / jouer à la baballe* (✅ #8) : anim + jappement →
  +moral. Le chien suit Shen, réagit.
- **La petite sœur** (dès gare 5) — *Parler / lire ensemble* (✅ B8) : une bulle
  de dialogue (pool qui évolue selon les flags/gares), ou lecture duo. → +moral.
  Lui donne une VRAIE présence entre les cartes. Histoires écrites plus tard.

---

## Priorités suggérées (pour commencer)
1. **E15 — crédit bonus** sur dormir / bien s'occuper de Shen : transforme
   l'attente en jeu. (petit, gros impact ressenti)
2. **Sœur qui parle** (B8) + **chien baballe** : présence vivante, +moral.
3. **Fenêtre contemplative** : l'attente = le voyage qui défile.
4. **Jardinage temps réel** : se cale pile sur l'attente des crédits.
5. **Corvée de bois** (C11) plus satisfaisante (le bois est devenu vital).
