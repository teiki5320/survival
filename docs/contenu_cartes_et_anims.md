# Contenu — assets, déclinaisons & animations (BROUILLON à valider)

But : arrêter les listes avant de générer les assets et de coder les systèmes.
Statut : **brouillon** — à valider / compléter avec l'utilisateur.

---

## 1. Animations personnages

### Shen (héroïne) — EXISTANTES (49 frames sauf indiqué)
walk_right, idle_right, sleep_right, dance, pickup, yawn, stretch,
look_window, read, wake_up, open_door (20fr), door_push, warm_hands,
carry_walk, cook, drink, garden_tend, crouch, use_back, pet_dog.

→ Couvre déjà presque toute l'autonomie (boire/manger/dormir/lire/se
chauffer/jardiner/caresser le chien/danser). **Manque éventuel** :
- `eat` dédié (sinon `cook` fait l'affaire)
- `sit_relax` (pose assise détente)

### Petite sœur — EXISTANTES
dance, walk, pet_dog, hug_dog, read (+Shen), hug (+Shen).

→ Pour une autonomie solo crédible, **à générer** :
- `idle` (debout, respire) — base de repos
- `sleep` (dort)
- `eat` (mange)
- `sit` (assise / joue par terre)

### Chien — EXISTANTES
idle, walk, bark, eat, head_tilt, lay_down, sleep, stretch_yawn, wag_tail.

→ **Suffisant** pour l'autonomie (errer/dormir/manger/aboyer/s'étirer).

---

## 2. Assets & déclinaisons (effet dans les cartes)

Principe : un objet possède des **tiers**. Le tier équipé applique un
**multiplicateur** au gain de la stat correspondante dans les cartes
(et/ou débloque des choix).

### Eau (stat Soif) — filtre
| Tier | Asset | Effet carte |
|------|-------|-------------|
| 1 | Filtre chiffon | x1 eau |
| 2 | Filtre charbon | x1.5 eau |
| 3 | Filtre céramique | x2 eau |
| 4 | Filtre UV / solaire | x3 eau |

### Bois (stat Bois) — outil de coupe
| Tier | Asset | Effet carte |
|------|-------|-------------|
| 1 | Mains nues | x1 bois |
| 2 | Hachette | x1.5 bois |
| 3 | Hache | x2 bois |
| 4 | Scie / passe-partout | x2.5 bois |

### Nourriture (stat Faim) — hydroponie / culture
| Tier | Asset | Effet carte |
|------|-------|-------------|
| 1 | Pots simples (carotte) | x1 food |
| 2 | + tomate / laitue | x1.5 food |
| 3 | Serre fermée | x2 food |
| 4 | Serre + lampe de croissance | x3 food |

### Moral / chaud — confort
| Tier | Asset | Effet carte |
|------|-------|-------------|
| 1 | Plaid | +moral léger |
| 2 | Poêle réglé | +moral, anti-froid |
| 3 | Lampe + déco | +moral fort |

### Objets lore (flags one-shot, pas de tier)
radio à manivelle, photo de famille, foulard de la sœur, peluche,
carnet, sac à dos, jarres/bocaux.

---

## 3. À intégrer dans les cartes

- Chaque tier d'objet = des **cartes dédiées** + un **modificateur global**
  sur les gains de la stat liée.
- Les objets lore = **flags** qui débloquent des variantes de cartes
  (déjà géré par le moteur via `flags requis`).
- 2ᵉ wagon en désordre = source de cartes "aménagement" (ranger / réparer
  → débloque tiers d'objets).

---

## 4. Systèmes à construire (gros morceaux)

1. **Autonomie Sims** (Shen + sœur + chien) : chaque perso choisit
   périodiquement une action pondérée par ses besoins (Shen = les 4 stats ;
   sœur/chien = humeur simple). Joue l'anim correspondante puis revient au
   repos.
2. **2ᵉ wagon** : nouvelle scène (désordre au départ), accessible par une
   porte ; aménageable plus tard (lié aux tiers d'objets).
3. **Fusion cartes + map** : retirer le bouton cartes ; tirer les cartes
   DEPUIS la map ; chaque carte fait **avancer le train** sur la route.
