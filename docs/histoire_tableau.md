# Train Cosy — Tableau de l'histoire

> Plan d'histoire éditable, généré depuis `lib/data/cards_data.dart` +
> `lib/models/reigns_engine.dart`. Le scénario = 14 segments. Chaque segment =
> les beats de GARE (jamais aléatoires) + un paquet de FILLERS piochés
> (`drawCount = 4`, 0 pour les gares 13 et 14).
>
> ⚠️ **Le Vieux a été SUPPRIMÉ** (perso non validé). Ignorer les lignes F2_vieux_feu / F3_vieux_fille / F4_vieux_carte / F6_vieux_reste / G2b si encore présentes.

## Légende

- **Persos / objets** : 🐕 chien · 👧 petite sœur · 👴 Le Vieux · 📻 radio · 🛏️ lit · 💧 filtre à eau · 🌱 hydroponie (serre)
- **Stats** : **S** soif · **F** faim · **B** bois · **M** moral. Notation compacte : `M+15`, `B-8, F-4`.
- **Combat** : `combatTierHigh/Mid/Low` posés par le combat de gare (score). `combatGood_N` si bon score à la gare N.
- **Mécaniques de fond appliquées à CHAQUE carte** (moteur, pas dans les tableaux) :
  - Effets : pertes ×1.7, **gains de moral ×0.6** (pertes de moral pleines).
  - 👧 à bord (`aLaSoeur`) : `F-1, S-1, M+1` par carte (2e bouche).
  - Zone froide (gare 8+) : `B-2` par carte (`kColdBoisDrainPerCard`).
  - `soeurProtegee` incrémente `cardSoin` (compteur pour la fin "famille").
- **Réappro bois auto** (`kWoodSupplyByGare`) : gare 3 → +5, gare 7 → +6, gare 10 → +4 (index 2/6/9, 0-based).
- **Tirage fillers** : oneshot vues une fois/run ; `requires` filtre selon flags ; `drawCount=4` par segment.

---

## Les 14 gares

### Gare 1 — Gare natale en ruines

| Carte (id) | Situation | Choix GAUCHE → effets / flags | Choix DROITE → effets / flags | 🎁 GAINS |
|---|---|---|---|---|
| G1 | Ville natale en flammes vue du wagon | "Regarder jusqu'au bout" : M-6, +`asset_bed` | "Fermer la porte" : M+3, +`asset_bed` | 🛏️ lit (`asset_bed`) — quel que soit le choix |
| G1b | Chiot tremblant sous un banc | "Le recueillir" : M+15, +`aLeChien` | "Tu ne pourras pas le nourrir" : M-5 | 🐕 chien (`aLeChien`) si gauche |
| G1c | Souvenir de la séparation de la famille | "Te jurer de les retrouver" : M+10 | "Te préparer au pire" : M-8, F+4 | — |

### Gare 2 — Dépôt de fret

| Carte (id) | Situation | Choix GAUCHE | Choix DROITE | 🎁 GAINS |
|---|---|---|---|---|
| G2 | Apprendre à nourrir la loco au bois | "Déchiffrer le manuel" : B+18, F-4 | "À l'instinct" : B+6, M-3 | — |
| G2b | Le Vieux cheminot demande à monter | "L'accueillir à bord" : B+10, F-3, +`leVieuxABord` | "Continuer seule" : M-5 | 👴 Le Vieux (`leVieuxABord`) si gauche |

### Gare 3 — Halte 47

| Carte (id) | Situation | Choix GAUCHE | Choix DROITE | 🎁 GAINS |
|---|---|---|---|---|
| G3 | Pillards dans le brouillard, loco pas encore vue | "Passer en fantôme" : B-6, M-4 | "Accélérer pour les semer" : B-10, M+3 | — |
| G3b | Foulard d'enfant (= celui de la sœur ?) | "Risquer pour l'attraper" : F-8, M+12, +`indiceSoeur` | "Ne pas risquer" : M-8 | `indiceSoeur` si gauche |
| G3win | **si bon combat** (`combatTierHigh`) — wagon intact | "Souffler" : M+8 | "Fouiller leur butin" : F+6, B+4 | — |
| G3lose | **si combat raté** (`combatTierLow`) — wagon endommagé | "Colmater" : B-6, M-3 | "Repartir" : F-5 | — |

### Gare 4 — Village fantôme

| Carte (id) | Situation | Choix GAUCHE | Choix DROITE | 🎁 GAINS |
|---|---|---|---|---|
| G4 | Mur de disparus + message d'enfant "JE VAIS AU NORD" | "Y croire, foncer" : M+14, B-8, +`indiceSoeur`, +`asset_filter` | "Rester méfiante" : M-4, +`asset_filter` | 💧 filtre (`asset_filter`) — quel que soit le choix ; `indiceSoeur` si gauche |

### Gare 5 — Pont sur le fleuve (RETROUVAILLES SŒUR)

| Carte (id) | Situation | Choix GAUCHE | Choix DROITE | 🎁 GAINS |
|---|---|---|---|---|
| G5 | La petite sœur, vivante, barre la route | "Courir la serrer" : M+40, +`aLaSoeur` | (idem) : M+40, +`aLaSoeur` | 👧 sœur (`aLaSoeur`) — quel que soit le choix |
| G5b | La sœur révèle le cap : parents partis au nord | "Lui promettre" : M+12, +`capParents` | "Rester prudente" : M+4, +`capParents` | `capParents` — quel que soit le choix |
| G5win | **si bon combat** — sœur indemne | "La serrer encore" : M+10 | "Filer vite" : B+4, M+5 | — |
| G5lose | **si combat raté** — la sœur a vu l'horreur | "La consoler" : M-3, F-4, +`soeurProtegee` | "Lui apprendre à être forte" : M+4 | `soeurProtegee` (cardSoin++) si gauche |

### Gare 6 — Camp-refuge

| Carte (id) | Situation | Choix GAUCHE | Choix DROITE | 🎁 GAINS |
|---|---|---|---|---|
| G6 | Camp louche, on lorgne la sœur | "Troquer vite et partir" : F+12, S+8, M-6 | "Ne pas t'attarder" : M+6, F-5 | — |

### Gare 7 — Halte 12 (souvenir d'enfance)

| Carte (id) | Situation | Choix GAUCHE | Choix DROITE | 🎁 GAINS |
|---|---|---|---|---|
| G7 | Halte d'enfance, la sœur sourit | "Lui raconter le souvenir" : M+16, B-5 | "Garder le cap" : M+4 | — |

### Gare 8 — Entrée zone froide

| Carte (id) | Situation | Choix GAUCHE | Choix DROITE | 🎁 GAINS |
|---|---|---|---|---|
| G8 | La sœur grelotte, pas de manteau | "Lui donner le tien" : M+14, S-6, +`soeurProtegee` | "Pousser le feu" : B-16, M+6 | `soeurProtegee` (cardSoin++) si gauche |

### Gare 9 — Plaine enneigée

| Carte (id) | Situation | Choix GAUCHE | Choix DROITE | 🎁 GAINS |
|---|---|---|---|---|
| G9 | Sœur fiévreuse, blizzard | "La veiller" : F-10, M+12, +`soeurProtegee` | "Braver la tempête (remèdes)" : S-12, M+8, +`soeurProtegee` | `soeurProtegee` (cardSoin++) — quel que soit le choix |

### Gare 10 — Oasis perdue (serre)

| Carte (id) | Situation | Choix GAUCHE | Choix DROITE | 🎁 GAINS |
|---|---|---|---|---|
| G10 | Serre chaude, répit | "Vrai repos" : F+20, S+16, M+18, +`asset_hydro` | "Plein et repartir" : F+12, S+10, B+12, M-4, +`asset_hydro` | 🌱 hydroponie (`asset_hydro`) — quel que soit le choix |

### Gare 11 — Halte 31 (barrage de pillards)

| Carte (id) | Situation | Choix GAUCHE | Choix DROITE | 🎁 GAINS |
|---|---|---|---|---|
| G11 | Barrage de pillards sur la voie | "Foncer dans le barrage" : B-18, M-6 | "Négocier (vivres)" : F-16, S-10, M+4 | — |
| G11win | **si bon combat** — pillards en déroute | "Rafler leur butin" : F+10, B+8 | "Passer sans t'attarder" : M+8 | — |
| G11lose | **si combat raté** — assaut repoussé au prix fort | "Panser les dégâts" : F-8, M-4 | "Fuir" : B-8, M+3 | — |

### Gare 12 — Tour de guet

| Carte (id) | Situation | Choix GAUCHE | Choix DROITE | 🎁 GAINS |
|---|---|---|---|---|
| G12 | Vue sur le refuge nord + pancarte familles | "Lui jurer qu'ils sont là" : M+18 | "Tempérer son espoir" : M+6 | — |

### Gare 13 — Col gelé (sacrifice) — *segment sans fillers*

| Carte (id) | Situation | Choix GAUCHE | Choix DROITE | 🎁 GAINS |
|---|---|---|---|---|
| G13 | Loco à court de bois dans la dernière montée | "Brûler le mobilier" : B+28, M-8 | "Descendre pousser ensemble" : F-14, S-10, M+10 | — |

### Gare 14 — Refuge du nord (climax) — *segment sans fillers*

| Carte (id) | Situation | Choix GAUCHE | Choix DROITE | 🎁 GAINS |
|---|---|---|---|---|
| G14 | Arrivée en gare du refuge, foule des familles | "Chercher vos parents" : (aucun effet) | (idem) | — → déclenche la résolution de fin |

---

## Cartes entre les gares (fillers)

> `oneshot` = vue une seule fois par run (lore/émotion fort) ; sinon repeatable.
> Condition vide = "—". GAINS = tout flag/objet/perso d'arc débloqué.

### Segment 1→2 (`_fill1`, 10 fillers)

| Filler (id) | Condition | Situation | Choix G | Choix D | 🎁 GAINS |
|---|---|---|---|---|---|
| F1_homme (oneshot) | — | Homme qui court après le train | B-10, M+6 | M-8 | — |
| F1_valise (oneshot) | — | Valise d'un passager mort | F+8, M-5 | M+7 (juste la photo) | — |
| F1_chat | — | Chat errant affamé | F-6, M+9 | M-4 | — |
| F1_gare | — | Gare à fouiller (train à l'arrêt = bois) | B-8, F+12 | M+2 | — |
| F1_blessure | — | Main entaillée | B-5, M+4 (cautériser) | F-6, M-3 | — |
| F1_orage | — | Toit qui fuit | S+12, M-3 (récolter l'eau) | M+6, S-4 | — |
| F1_chien_nuit | `aLeChien` | Le chiot tremble la nuit | M+8 | M-3 | — |
| F1_marchand (oneshot) | — | Marchand au passage à niveau | F+10, B-4 | M-2 | — |
| F1_pancarte | — | "NORD — 1400 km / TROP LOIN" | M+6, B-4 | M-5 | — |
| F1_linceul (oneshot) | — | Affaires de passagers tués | F+8, M-6 | M+7, F-3 | — |

### Segment 2→3 (`_fill2`, 10 fillers)

| Filler (id) | Condition | Situation | Choix G | Choix D | 🎁 GAINS |
|---|---|---|---|---|---|
| F2_graffiti (oneshot) | — | "ILS MENTENT SUR LE NORD" | M-6, F+8 | M+5, B-6 | — |
| F2_journal (oneshot) | — | Journal de conducteur (ou brûlable) | M-4, B+8 | B+5, M-5 | — |
| F2_aiguillage | — | Raccourci inconnu vs voie sûre | B+12, M-5 | M+4, F-4 | — |
| F2_silhouettes | — | Silhouettes dans le brouillard | F+10, M-4 | B-8, M+3 | — |
| F2_tunnel | — | Tunnel noir, lampe = huile | B-4, M+5 | M-7 | — |
| F2_sifflet | — | Siffler = se faire repérer | F+10, M+4 | M-3 | — |
| F2_vieux_feu | `leVieuxABord` | Le Vieux apprend à écouter la chaudière | B+12 | M-3, B+3 | — |
| F2_huile | — | Bidon d'huile (graisser vs brûler) | B+8 | B+6, M-2 | — |
| F2_famille_quai (oneshot) | — | Famille qui supplie d'emporter leur fille | M-9 (refuser) | F-8, M+9 | — |
| F2_citerne | — | Wagon-citerne d'eau | S+14, F-4 | M+2 | — |

### Segment 3→4 (`_fill3`, 10 fillers)

| Filler (id) | Condition | Situation | Choix G | Choix D | 🎁 GAINS |
|---|---|---|---|---|---|
| F3_piano (oneshot) | — | Piano sur un quai (le son porte) | M+10, B-6 | M-3 | — |
| F3_livre | — | Livre d'images (lu à la sœur) | M+8, F-3 | B+4, M-6 | — |
| F3_vivres | — | Épicerie, reste en hauteur | F+14, S-5 | F+5 | — |
| F3_arcenciel | — | Arc-en-ciel pâle | M+9, B-7 | M-2 | — |
| F3_pont | — | Vieux pont qui craque | F-4, M-3 | B-10, M+5 | — |
| F3_potager | — | Potager sauvage | F+12, M-4 | F+5, M+3 | — |
| F3_vieux_fille | `leVieuxABord` | Le Vieux parle de sa fille | M+8, F-3 | M-2 | — |
| F3_chien_garde | `aLeChien` | Le chien flaire un danger | B-5, M+6 (éboulis évité) | M-6 | — |
| F3_blesses | — | Deux pillards blessés (piège ?) | F-6, M+7 | M-3 | — |
| F3_fumee | — | Colonne de fumée droit devant | B-8, M+3 | F-5, M-2 | — |

### Segment 4→5 (`_fill4`, 10 fillers)

| Filler (id) | Condition | Situation | Choix G | Choix D | 🎁 GAINS |
|---|---|---|---|---|---|
| F4_chanson (oneshot) | `aLaRadio` | Vieille chanson d'amour à la radio | M+10, F-4 | M-5 | — |
| F4_maria (oneshot) | — | Mur de messages (ajouter son nom) | M+8, S-4 | M-4 | — |
| F4_cerfs | — | Cerfs efflanqués (chasse vs épargne) | F+16, M-7 | B-8, M+8 | — |
| F4_ville | — | Ville intacte, trop calme | F+14, B+8, M-8 | M+3 | — |
| F4_reflet | — | Reflet maigre, méconnaissable | M+7, F-3 | M-5 | — |
| F4_puits | — | Château d'eau, échelle rouillée | S+18, M-4 | M+2, S-5 | — |
| **F4_radio_trouvee (oneshot)** | — | Radio à manivelle dans une poste | M+8, F-3, **+`aLaRadio`** | M-4 | 📻 radio (`aLaRadio`) si gauche |
| F4_vieux_carte | `leVieuxABord` | Le Vieux trace une route vers le col | B+10 | M-3 | — |
| F4_dessin_soeur (oneshot) | — | Dessin "MA GRANDE SŒUR VIENDRA" | M+10, F-4 | M-5 | — |
| F4_chien_cache | `aLeChien` | Le chien déterre une réserve | F+12, M+5 (récompenser) | F+14, M-2 | — |
| F4_fonts | — | Fonts baptismaux d'eau de pluie | S+16 | M+5, S-3 | — |

> Note : `_fill4` contient **11 fillers** (F4_chanson, F4_maria, F4_cerfs, F4_ville, F4_reflet, F4_puits, F4_radio_trouvee, F4_vieux_carte, F4_dessin_soeur, F4_chien_cache, F4_fonts).

### Segment 5→6 (`_fill5`, 10 fillers)

| Filler (id) | Condition | Situation | Choix G | Choix D | 🎁 GAINS |
|---|---|---|---|---|---|
| F5_trainvide (oneshot) | — | Train vide aux portes ouvertes | B+12, F+8, M-6 | M-3 | — |
| F5_carnet (oneshot) | — | Carnet de croquis (dessiner les siens) | M+9, F-3 | B+4, M-4 | — |
| F5_peche | — | Lac, pêche à l'arrêt | F+15, B-6, M-3 | M+3 | — |
| F5_graines | — | Sachet de graines viables | F+6, M+3 | M+8, F-2 | — |
| F5_malade | — | Réveil fiévreux | B-10, M+6 | F-8, M-4 | — |
| F5_doute | — | "Et si le nord n'existait pas ?" | M+7, B-6 | M-8, F+5 | — |
| **F5_radio_premier (oneshot)** | `aLaRadio` & !`radio1` | 1er message radio (voix de femme) | M+9, F-3, **+`radio1`** | M+2, **+`radio1`** | 📻 chaîne `radio1` — quel que soit le choix |
| F5_soeur_cabane | `aLaSoeur` | La sœur transforme le wagon en cabane | M+11, F-4 | M-4 | — |
| F5_radeau | — | Sac scellé sur un radeau de débris | F+12, M-3 | M+2 | — |
| F5_brume | — | Brume sur le pont | B-6, M+4 | F-5 | — |

### Segment 6→7 (`_fill6`, 10 fillers)

| Filler (id) | Condition | Situation | Choix G | Choix D | 🎁 GAINS |
|---|---|---|---|---|---|
| F6_berceuse (oneshot) | — | Souvenir de berceuse à la sœur | M+11, F-3 | M-5 | — |
| F6_village | — | Village de montagne habité | F+12, M-6 | M+2, F-4 | — |
| F6_loups | — | Meute de loups la nuit | B-8, M+4 | M-6 | — |
| F6_manteau | — | Manteau de laine moisi | M+7, F-4 | B+5, M-3 | — |
| F6_eboulement | — | Éboulement à moitié sur la voie | F-8, M+4 (déblayer) | B-10, M-2 | — |
| F6_givre | — | Premières fougères de givre | B-8, M+5 | M-5, F-3 | — |
| **F6_vieux_reste (oneshot)** | `leVieuxABord` & !`vieuxParti` | Le Vieux descend au camp (donne ses gants) | M+6, B+6, **+`vieuxParti`** | M-6, **+`vieuxParti`** | 👴 départ du Vieux (`vieuxParti`) — quel que soit le choix |
| F6_poupee | `aLaSoeur` | Poupée de chiffon pour la sœur | F-8, M+12 | M-3 | — |
| F6_rumeurs | — | Rumeurs contradictoires sur le refuge | B+6, M-4 | M+5 | — |
| F6_guerisseur | — | "Guérisseur" contre du bois | B-8, M+8 | M-2 | — |

### Segment 7→8 (`_fill7`, 11 fillers)

| Filler (id) | Condition | Situation | Choix G | Choix D | 🎁 GAINS |
|---|---|---|---|---|---|
| F7_corps (oneshot) | — | Corps gelé avec manteau + sac | F+10, M-8 | M+7, F-3 | — |
| F7_refuge (oneshot) | — | Refuge de montagne (dormir = nuit perdue) | M+10, B-5 | F+8, M-3 | — |
| F7_rennes | — | Rennes paisibles (gibier vs vie) | F+16, M-6 | M+8, F-4 | — |
| F7_glace | — | Voie verglacée | B-10, M+4 | M-7 | — |
| F7_voix | — | Silence : ne plus entendre sa voix | M+8, S-4 | M-6 | — |
| F7_traces | — | Traces de pas vers une cache | F+10, B-5, M-3 | M+3 | — |
| **F7_radio_voix (oneshot)** | `radio1` & !`radio2` | Voix radio plus nette, familière | M+10, **+`radio2`** | M+3, **+`radio2`** | 📻 chaîne `radio2` — quel que soit le choix |
| F7_soeur_billes | `aLaSoeur` | Cachette de billes d'enfance | M+12, F-3 | M-3 | — |
| F7_train_jouet | — | Petit train miniature en vitrine | M+8, B-3 | M+3 | — |
| F7_car_scolaire | — | Car scolaire renversé | F+10, M-8 | M+5, F-3 | — |
| F7_neige_premiere | — | Premiers flocons (stocker du bois) | B+12, F-5 | M+6, B-4 | — |

### Segment 8→9 (`_fill8`, 10 fillers)

| Filler (id) | Condition | Situation | Choix G | Choix D | 🎁 GAINS |
|---|---|---|---|---|---|
| F8_dirigeable (oneshot) | — | Carcasse de dirigeable | F+12, B+8, M-5 | M+2 | — |
| F8_boite (oneshot) | — | Boîte à musique | M+7, F-3 | M-4 | — |
| F8_rivet | — | Rivet éclaté, courant d'air | F-6, M+5 | B-10, M-2 | — |
| F8_lunaire | — | Plaine blanche sans repère | B-6, M+4 | M-5, F-4 | — |
| F8_tempete | — | Tempête qui fond sur le train | B-6, S+6, M-2 | B-12, M+4 | — |
| F8_chien_froid | `aLeChien` | Le chien givré claque des dents | M+9, S-4 | B-6 | — |
| F8_soeur_cache | `aLaSoeur` | La sœur cache qu'elle a froid | M+10, F-3, +`soeurProtegee` | M+4 | `soeurProtegee` (cardSoin++) si gauche |
| F8_loup_blanc | — | Loup arctique qui accompagne | M+8 | M-3, F+4 | — |
| F8_geyser | — | Geyser d'eau chaude | S+16, B+4 | M+2 | — |
| F8_borne | — | Borne -30 plus haut | M+6, F-4 | M-3 | — |

### Segment 9→10 (`_fill9`, 10 fillers)

| Filler (id) | Condition | Situation | Choix G | Choix D | 🎁 GAINS |
|---|---|---|---|---|---|
| F9_cristal (oneshot) | — | Forêt figée en cristal de givre | M+10, B-7 | M-2 | — |
| F9_traineau | — | Traîneau + harnais (plan B) | B-4, M+6 | M-2 | — |
| F9_ours | — | Empreintes d'ours blanc (carcasse) | F+14, M-7 | B-6, M+3 | — |
| F9_lac | — | Lac gelé en raccourci | B+10, M-8 | B-8, M+4 | — |
| F9_aurore | — | Aurore boréale | M+12, B-6 | M+5 | — |
| **F9_radio_maman (oneshot)** | `radio2` & !`radio3` | La voix radio = **maman** | M+14, F-4, **+`radio3`** | M+4, **+`radio3`** | 📻 chaîne `radio3` (révélation maman) — quel que soit le choix |
| F9_soeur_doute | `aLaSoeur` | La sœur doute tout haut | M+8, F-3 | M+5, +`soeurProtegee` | `soeurProtegee` (cardSoin++) si droite |
| F9_congere | — | Congère plus haute que le wagon | B-12, M+4 | F-10, S-6 | — |
| F9_foyer_eteint | — | Foyer éteint dans la nuit | B+14, M-5 | F-8, M+3 | — |
| F9_repere | — | Blizzard a tout effacé | M-4, B-5 | F-6 | — |

### Segment 10→11 (`_fill10`, 10 fillers)

| Filler (id) | Condition | Situation | Choix G | Choix D | 🎁 GAINS |
|---|---|---|---|---|---|
| F10_bain (oneshot) | — | Source chaude, bain | M+12, B-5 | M+5 | — |
| F10_lettre (oneshot) | — | Lettre jamais envoyée | M-6, F+4 | M+5 | — |
| F10_fruits | — | Serre croulant de fruits | F+14, M+6, S+6 | F+8, M-2 | — |
| F10_occupant | — | Chambre d'un occupant disparu | F+8, S+6, M-5 | M+7 | — |
| F10_etoiles | — | Dernière nuit calme (veiller) | M+9, F-3 | M+4, F+4 | — |
| F10_soeur_fleur | `aLaSoeur` | La sœur lui glisse une fleur | M+12 | M+9, F+3 | — |
| F10_chien_herbe | `aLeChien` | Le chien se roule dans l'herbe tiède | M+10, F-3 | M+6 | — |
| F10_graines_rares | — | Semences rares étiquetées | F+6, M+6 | M+9, F-2 | — |
| F10_bassin | — | Bassin d'irrigation tiède | M+11, S+6, B-4 | S+12 | — |
| F10_rester | — | Tentation de vivre ici | M+6, F-4 (tenir le cap) | M-3, F+8 | — |

### Segment 11→12 (`_fill11`, 10 fillers)

| Filler (id) | Condition | Situation | Choix G | Choix D | 🎁 GAINS |
|---|---|---|---|---|---|
| F11_englouti (oneshot) | — | Ville engloutie sous la glace | M-7, F+5 | B-8, M+3 | — |
| F11_draisine | — | Draisine à bras (assurance-vie) | B-5, M+5 | M-3 | — |
| F11_statue | — | Statue ensevelie, bras vers le nord | B+8, M+5 | M-2, F-3 | — |
| F11_froid | — | Froid absolu, givre intérieur | B-12, M+6 | F-8, M-4 | — |
| F11_provisions | — | Vivres trop justes : rationner ? | F-6, M-4 | F+8, M+3 | — |
| F11_radio_muette | `radio3` | Fréquence de maman muette | M-4, S-3 | M+5 | — |
| F11_soeur_pierre | `aLaSoeur` | La sœur veut apprendre à se battre | M+9, F-3 | M+3 | — |
| F11_pont_coupe | — | Pont à moitié effondré (sauter) | B-14, M-6 | F-8, B-6 | — |
| F11_feu_lointain | — | Grand feu au loin (amis ou appât ?) | F+10, M-6 | M+3, F-3 | — |
| F11_rodeurs | — | Traces : on a tenté de forcer le wagon | M-4, F-3 | B-8, M+3 | — |

### Segment 12→13 (`_fill12`, 10 fillers)

| Filler (id) | Condition | Situation | Choix G | Choix D | 🎁 GAINS |
|---|---|---|---|---|---|
| F12_autel (oneshot) | — | Autel de voyageurs | M+9 (déposer la photo) | M-3 | — |
| F12_carcasses (oneshot) | — | Carcasses de trains dans le col | B+14, M-7 | M+5, B-4 | — |
| F12_loco | — | Cœur de la loco irrégulier | B-6, F-4, M+5 | M-5 | — |
| F12_croix | — | Croix fleurie fraîche (vivants proches) | F+10, B-6, M+4 | M+2 | — |
| F12_vivres_finales | — | Alléger pour grimper le col ? | B-10, F+6 | B+8, F-8 | — |
| F12_phare | — | Lampe sur un pylône (signal ?) | F-7, M+13 (voit les fumées) | M-3 | — |
| F12_gel | — | Aiguillage soudé par le gel | S-16, M+4 | B-6, M-8 | — |
| F12_silence | — | Silence absolu, irréel | M+7, S-3 | M-9 | — |
| F12_radio_derniere | `radio3` | "...je les vois... c'est elle..." | M+13, B-3 | M+8, B-5 | — |
| F12_soeur_promesse | `aLaSoeur` | "Quand on les aura retrouvés, on reste ?" | M+12 | M+5 | — |

> **Segments 13→14 et 14→fin : pas de fillers** (gares 13 et 14, `fillerPool: []`, `drawCount: 0`).

---

## Carte des déblocages (récapitulatif)

| Élément | Où c'est débloqué actuellement | Flag |
|---|---|---|
| 🐕 Chien | Gare 1, carte G1b (choix gauche "Le recueillir") | `aLeChien` |
| 👧 Petite sœur | Gare 5, carte G5 (les deux choix) | `aLaSoeur` |
| 👧 Indice sœur (foulard/message) | Gare 3 G3b (gauche) et Gare 4 G4 (gauche) | `indiceSoeur` |
| Cap parents fixé | Gare 5, carte G5b (les deux choix) | `capParents` |
| Soin de la sœur (compteur fin) | G5lose-g, G8-g, G9 (les 2), F8_soeur_cache-g, F9_soeur_doute-d | `soeurProtegee` → `cardSoin++` |
| 📻 Radio (objet) | Segment 4→5, filler F4_radio_trouvee (oneshot, gauche) | `aLaRadio` |
| 📻 Radio chaîne 1 | Segment 5→6, F5_radio_premier (oneshot, requires `aLaRadio`) | `radio1` |
| 📻 Radio chaîne 2 | Segment 7→8, F7_radio_voix (oneshot, requires `radio1`) | `radio2` |
| 📻 Radio chaîne 3 (= maman) | Segment 9→10, F9_radio_maman (oneshot, requires `radio2`) | `radio3` |
| 🛏️ Lit | Gare 1, carte G1 (les deux choix) | `asset_bed` |
| 💧 Filtre à eau | Gare 4, carte G4 (les deux choix) | `asset_filter` |
| 🌱 Hydroponie (serre) | Gare 10, carte G10 (les deux choix) | `asset_hydro` |
| Tier de combat (par gare) | Posé par le combat de gare avant les beats G3/G5/G11 | `combatTierHigh/Mid/Low`, `combatGood_N` |

---

## Les fins

> Résolution dans `resolveTrainCosyEnding(stats, flags)` + mort immédiate (moteur) si une jauge ≤ 0.
> `soin` = `GameState.instance.cardSoin` (compteur de `soeurProtegee`). `moral` = stat finale.

| Fin (id) | Titre | Condition |
|---|---|---|
| `secret` | La voix retrouvée | `aLaSoeur` **et** `soin ≥ 2` **et** `moral ≥ 65` **et** `radio3` |
| `famille` | Réunis | `aLaSoeur` **et** `soin ≥ 2` **et** `moral ≥ 65` (sans `radio3`) |
| `ensemble` | Toutes les deux | `aLaSoeur` **et** `moral ≥ 30` (mais conditions de `famille` non remplies) |
| `abandon` | L'abandon | aucune des conditions ci-dessus (fin par défaut) **ou** moral tombé à 0 en cours de run |
| `mort` | Le voyage s'arrête | une jauge (soif/faim/bois) tombe à 0 en cours de run (mort immédiate, moteur) |

> Détail moteur : si une jauge ≤ 0 pendant la run, fin immédiate = `abandon` si c'est le moral, sinon `mort`. Les fins `secret/famille/ensemble/abandon` "propres" ne se résolvent qu'à l'arrivée gare 14.
