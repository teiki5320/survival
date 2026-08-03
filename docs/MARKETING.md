# Train Cosy — Plan marketing & rémunération

> **Généré le 2026-08-03** par audit du dépôt. Existant repéré : boutique IAP
> maquettée (3 produits avec `storeId`, paiement non branché,
> `lib/widgets/shop_screen.dart`) ; système de crédits temps réel (1 carte =
> 1 crédit, +1/5 min) ; **aucun** partage in-app, lien social, analytics,
> newsletter ou fiche store publiée. Tout ce qui n'existe pas est proposé
> en ⬜. Aucun secret dans ce fichier. Pour le mettre à jour : relancer ce
> prompt.

---

## 1. Positionnement

**L'angle** : *le jeu qui fait du bien dans un monde qui finit.* Un
side-scroller narratif **cosy post-apocalyptique** — tu conduis un train à
bois vers le nord avec ta petite sœur, un chiot et une radio qui grésille de
l'espoir. Esthétique Ghibli/lofi peinte main, boucle courte (1 carte = 1
crédit), émotions vraies (14 gares, 5 fins dont une secrète).

**Une phrase (pitch store)** : « Un train, ta petite sœur, un monde éteint.
Survis de corps et d'âme jusqu'au refuge du nord. »

**Différenciation** : croisement rare **Reigns × Tamagotchi × Spiritfarer** ;
la concurrence cosy est massive mais le post-apo tendre, quasi vide.

**Publics cibles** :
1. **Joueuses/joueurs cosy** (Stardew, Spiritfarer, Unpacking) — cœur de
   cible, très actifs sur TikTok/Instagram.
2. **Amateurs de narratif à choix** (Reigns, 80 Days) — sensibles aux fins
   multiples et à la fin secrète.
3. **Public lofi/esthétique** (wallpapers, streams « study with me ») — le
   train sous la neige EST un fond d'écran vivant.
4. Francophones d'abord (textes FR), anglais à prévoir pour l'échelle.

---

## 2. Rémunération — par phases

Principe non négociable (déjà dans le code) : **confort only, l'histoire n'est
jamais bloquée par le paiement.**

| Phase | Levier | Détail | Statut |
|---|---|---|---|
| 0 — TestFlight | Aucun revenu | Jeu complet gratuit pour les testeurs | ✅ en cours |
| 1 — Lancement | **App premium à petit prix** OU gratuit + IAP (à trancher) | Reco : gratuit + IAP confort (aligne avec les crédits) | ⬜ décision |
| 1 — Lancement | IAP « Colis de réconfort » 0,99 € (`comfort_pack`) | Repos + hygiène + moral — maquette prête | ⬜ à brancher (`in_app_purchase` + produits ASC) |
| 1 — Lancement | IAP « Plaid chaud » 1,99 € (`warm_plaid`) | Chaleur 8 durable — maquette prête | ⬜ à brancher |
| 1 — Lancement | IAP « Café au dev » 2,99 € (`tip_jar`) | Pourboire pur — maquette prête | ⬜ à brancher |
| 2 — Post-lancement | IAP tenues cosmétiques | Pipeline tenues DÉJÀ industrialisé (lapin/laine livrées ; prompts sexy-cosy prêts) → pack de tenues 1,99-2,99 € | ⬜ |
| 2 — Post-lancement | Recharge de crédits (petite, optionnelle) | À manier avec soin : ne pas casser le rythme cosy voulu | ⬜ à évaluer |
| 3 — Échelle | Localisation EN puis portage Android | Double le marché adressable | ⬜ |
| Écarté | Publicité | Contraire à l'expérience cosy — **non** | 🚫 |

---

## 3. ASO (App Store)

**Nom proposé** : `Train Cosy — voyage narratif` (le nom seul est trop
générique pour la recherche).

**Mots-clés FR** : jeu cosy, narratif, histoire, train, survie douce, choix,
post-apocalyptique, hivernal, lofi, ghibli-like, sœur, chien, tamagotchi.
**Mots-clés EN (phase 3)** : cozy game, narrative, story rich, train,
wholesome, post-apocalyptic, choices matter, slice of life.

**Sous-titre store** : « Survis de corps et d'âme » — reprend le cœur du jeu
(4 jauges dont le moral/espoir).

**Captures (ordre conseillé)** :
1. Le wagon salon chaleureux (nuit, lanternes, chien + sœur) — l'argument cosy.
2. Une carte à choix forte (dilemme pillards) — l'argument narratif.
3. La carte du voyage (14 gares, spline) — l'argument aventure.
4. La loco + corvée de bûches sous la neige — l'argument survie.
5. L'armoire (tenues lapin/laine) — l'argument collection.
6. Bandeau « 5 fins — laquelle vivras-tu ? ».

| Élément ASO | Statut |
|---|---|
| Fiche App Store (textes FR ci-dessus) | ⬜ |
| Jeu de 6 captures (iPhone + iPad) | ⬜ |
| App preview vidéo 20 s (le train roule, une carte se swipe, la sœur rit) | ⬜ |
| Icône (test A/B : train vs Shen+sœur) | ⬜ |
| Incitation à noter (in-app, `SKStoreReviewController`, après une fin atteinte) | ⬜ |

---

## 4. Canaux d'acquisition

| Canal | Détail | Statut |
|---|---|---|
| TikTok / Reels / Shorts | LE canal cosy. Clips 15-30 s : le wagon la nuit, la sœur qui rit, les pyjamas assortis, « ce jeu m'a fait pleurer » ; devlogs FR | ⬜ compte à créer |
| Instagram | Carrousels d'art peint (gares, tenues), stories de dev | ⬜ |
| YouTube | Devlog long + trailer ; cibler les chaînes « cozy games » (listes de sortie) | ⬜ |
| Reddit | r/CozyGamers, r/iosgaming, r/IndieGaming — posts « I made this » avec GIF | ⬜ |
| Presse indé | TouchArcade, Pocket Gamer, Gamekult/jvc (FR) — kit presse | ⬜ kit presse à faire |
| Featuring Apple | Pitch éditorial App Store (formulaire « promote ») — le jeu coche les cases du featuring (esthétique, pas de pub, IAP éthiques) | ⬜ |
| Partage in-app | Bouton « partager ma fin » (image générée : fin obtenue + stats du voyage) — viralité organique | ⬜ à coder |
| Discord communautaire | Seulement si traction (coût d'animation élevé) | ⬜ plus tard |
| Newsletter | Page + formulaire (itch.io ou carrd) pour la liste de lancement | ⬜ |

---

## 5. Calendrier saisonnier

Le jeu est **hivernal par nature** (neige, froid, plaid, fête cosy) : le
calendrier doit en profiter.

| Période | Action |
|---|---|
| Sept.–oct. | Beta TestFlight élargie, montée du compte TikTok (devlogs) |
| **Nov.–déc.** | **LANCEMENT** — pic « cozy season » + cadeaux de Noël ; pitch featuring Apple « jeux d'hiver » | 
| Janvier | MàJ contenu (tenues, cartes) — surfe sur les résolutions « slow gaming » |
| Février | Événement « pyjamas assortis » (la carte-moment existe déjà) pour la Saint-Valentin famille/fratrie |
| Été | Creux assumé — préparer la version EN/Android |

---

## 6. KPIs à suivre

| KPI | Outil | Cible v1 |
|---|---|---|
| Téléchargements / impressions fiche | App Store Connect (App Analytics, natif, sans SDK) | 1 000 le 1er mois |
| Conversion fiche → install | App Store Connect | > 30 % |
| Rétention J1 / J7 | App Store Connect | 35 % / 12 % |
| % de runs finis (une fin atteinte) | ⬜ à instrumenter (compteur local + éventuel ping opt-in) | > 25 % |
| Répartition des 5 fins (la secrète est-elle trouvée ?) | ⬜ même instrument | secrète 2-5 % |
| Revenu / DL (ARPDAU IAP) | App Store Connect | > 0,05 € |
| Note moyenne | App Store | ≥ 4,5 |

Note : le jeu n'a **aucun SDK analytics** (choix cohérent avec le
positionnement — à garder ; App Analytics d'Apple suffit, opt-in par design).

---

## 7. Prochaines actions (ordre conseillé)

1. ⬜ Trancher le modèle (reco : **gratuit + IAP confort**) — décision
   propriétaire.
2. ⬜ Brancher `in_app_purchase` + créer les 3 produits sur App Store Connect
   (les `storeId` sont déjà dans le code).
3. ⬜ Rédiger la fiche App Store (textes §3) + produire les 6 captures et la
   vidéo de 20 s.
4. ⬜ Coder le « partager ma fin » (image + share sheet) et l'incitation à
   noter après une fin.
5. ⬜ Créer le compte TikTok et publier 2 clips/semaine dès la beta élargie.
6. ⬜ Préparer le kit presse (GIFs, captures, pitch, contact) + formulaire
   de featuring Apple.
7. ⬜ Caler la sortie sur **novembre-décembre** (§5).
8. ⬜ Après traction : pack de tenues cosmétiques (pipeline prêt), puis EN.
