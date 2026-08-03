# Train Cosy — INFRA : fiche technique des services externes

> **Générée le 2026-08-03** par audit automatique du dépôt (dépendances,
> configs, scripts CI, code). Pour la mettre à jour : relancer le même prompt
> dans une session Claude Code (« Génère un fichier docs/INFRA.md… »).
>
> ⚠️ **AUCUN secret dans ce fichier** — uniquement des identifiants publics et
> l'emplacement où vivent les secrets.

---

## Vue d'ensemble

Train Cosy est une app **Flutter / iOS 100 % hors-ligne** : pas de backend,
pas de base de données distante, pas d'authentification, pas d'analytics, pas
de pub, pas de notifications. La sauvegarde est un JSON **local sur
l'appareil**. Les seuls services externes sont la chaîne de build/distribution
Apple, GitHub, et deux dépendances Flutter.

---

## 1. GitHub — hébergement du code

- **Rôle** : dépôt source unique. Un push sur `main` déclenche le build
  Xcode Cloud (voir §2). Les assets générés (OpenArt) sont livrés par push
  sur des branches `claude/*` depuis l'interface web GitHub.
- **Console** : https://github.com/teiki5320/survival
- **Identifiants publics** : dépôt `teiki5320/survival` (privé), compte
  propriétaire `teiki5320`.
- **Secrets** : aucun secret de projet stocké côté GitHub (pas de GitHub
  Actions, pas de repository secrets). L'accès = compte GitHub `teiki5320`
  (mot de passe + 2FA dans le gestionnaire de mots de passe du propriétaire).
- **Reprise** : être collaborateur du dépôt ou propriétaire du compte
  `teiki5320`. Les sessions Claude Code y accèdent via l'app GitHub de
  claude.ai (autorisation par le propriétaire).

## 2. Xcode Cloud — CI/CD

- **Rôle** : compile l'app iOS à chaque push sur `main` et téléverse
  l'archive vers App Store Connect / TestFlight. Aucun runner tiers : c'est
  le CI d'Apple, configuré dans App Store Connect / Xcode.
- **Console** : https://appstoreconnect.apple.com → App → Xcode Cloud
  (ou Xcode → Report Navigator → Cloud).
- **Identifiants publics (dans le code)** :
  - Script de build : `ios/ci_scripts/ci_post_clone.sh` — installe Flutter
    **épinglé 3.41.9** (clone GitHub `flutter/flutter`), patch arm64e,
    `flutter build ios --config-only`, épingle `FLUTTER_BUILD_NUMBER` sur
    `CI_BUILD_NUMBER` (numéro auto-incrémenté par Xcode Cloud).
  - Intégration plugins : Swift Package Manager (pas de Podfile).
- **Secrets** : la signature (certificats + profils) est **gérée par Apple**
  (cloud signing) — rien dans le dépôt. Pas de variable d'environnement
  secrète définie dans le workflow.
- **Reprise** : accès au compte Apple Developer du propriétaire (§3). Le
  workflow (déclencheur = branche `main`) se re-crée en quelques clics dans
  Xcode si besoin.

## 3. Apple Developer / App Store Connect / TestFlight

- **Rôle** : distribution de l'app (TestFlight pour les tests sur iPhone/iPad
  du propriétaire ; App Store à terme, avec IAP « confort » prévus).
- **Consoles** :
  - https://developer.apple.com/account (adhésion, certificats, Team)
  - https://appstoreconnect.apple.com (app, TestFlight, Xcode Cloud, futurs IAP)
- **Identifiants publics (dans le code)** :
  - Bundle ID : `com.teiki5320.trainCosy`
    (+ `com.teiki5320.trainCosy.RunnerTests`) —
    `ios/Runner.xcodeproj/project.pbxproj`
  - Team ID Apple : `K597U7X3FZ` — `ios/Runner.xcodeproj/project.pbxproj`
    (`DEVELOPMENT_TEAM`)
  - Nom affiché : « Train Cosy » — `ios/Runner/Info.plist`
- **Secrets** : identifiant Apple (email + mot de passe + 2FA) du compte
  propriétaire — dans le gestionnaire de mots de passe du propriétaire,
  jamais dans le dépôt. Les certificats de signature vivent chez Apple
  (cloud signing Xcode Cloud) et/ou dans le trousseau du Mac mini.
- **Reprise** : contrôle du compte Apple Developer (adhésion payante
  annuelle au nom du propriétaire). Sans lui : impossible de signer ni de
  publier — c'est LE compte critique du projet.

## 4. Google Fonts (via le paquet `google_fonts`)

- **Rôle** : polices « Lora » et « Cinzel » de l'écran cartes
  (`lib/widgets/cards_screen.dart`). Le paquet télécharge la police **à la
  volée depuis fonts.google.com au premier usage**, puis la met en cache sur
  l'appareil. C'est le seul appel réseau de l'app au runtime.
- **Console** : aucune (service public sans compte).
- **Identifiants publics** : `google_fonts: ^6.2.1` dans `pubspec.yaml` ;
  familles `GoogleFonts.lora(...)` / `GoogleFonts.cinzel(...)` dans
  `cards_screen.dart`.
- **Secrets** : aucun.
- **Reprise / note** : fonctionne sans réseau après le premier affichage
  (cache). Pour une app 100 % hors-ligne stricte, on peut embarquer les
  fichiers .ttf dans `assets/` et déclarer les polices dans `pubspec.yaml`
  (amélioration possible avant la sortie App Store).

## 5. pub.dev — dépendances Flutter

- **Rôle** : registre des paquets Dart au build (`flutter pub get`).
- **Dépendances directes** (`pubspec.yaml`) :
  - `audioplayers ^6.1.0` — lecture audio locale (musiques + SFX embarqués
    dans `assets/audio/`, aucun appel réseau) ;
  - `google_fonts ^6.2.1` — voir §4 ;
  - `flutter_lints ^4.0.0` (dev).
- **Secrets** : aucun.
- **Reprise** : rien à faire, paquets publics.

## 6. Outillage de production d'assets (hors app)

Ces services ne sont PAS dans le code : ils font partie du **pipeline de
création** des sprites/décors (générer → pousser le PNG sur GitHub → découpe
par les outils `tools/*.py`).

- **OpenArt** (génération d'images, modèle « Nano Banana 2 ») —
  https://openart.ai — compte personnel du propriétaire (secrets : son
  gestionnaire de mots de passe). Consignes de génération : voir
  `CLAUDE.md` § « Workflow assets » et les planches de référence de
  `docs/anim_planches/`.
- **AutoSprite** (génération de spritesheets, accessible aussi en MCP depuis
  le Mac du propriétaire) — compte personnel du propriétaire. Règle projet :
  valider le coût AVANT toute génération.
- **Suno (ou équivalent)** — génération des musiques (prompts fournis dans
  l'historique du projet) — compte personnel du propriétaire.

## 7. Claude Code (sessions distantes)

- **Rôle** : développement assisté ; la VM cloud n'a PAS Flutter (réseau
  verrouillé au dépôt) → `flutter analyze`/`run` se font **manuellement sur
  le Mac mini** du propriétaire (`/Users/jeanperraudeau/survival`).
- **Console** : https://claude.ai (compte du propriétaire).
- **Secrets** : aucun dans le dépôt ; l'accès GitHub passe par
  l'intégration claude.ai autorisée par le propriétaire.

---

## À vérifier / pas encore branché

| Élément | État |
|---|---|
| **In-App Purchases** (`in_app_purchase`) | PAS dans `pubspec.yaml`. La boutique (`lib/widgets/shop_screen.dart`) est une maquette : `_purchase` accorde gratuitement en debug. À brancher : dépendance + produits dans App Store Connect. |
| **`prompts/`** (dossier à la racine) | Notes de génération d'assets — aucun service branché. |
| **Android / Web / macOS** | Aucune cible configurée (dossier `ios/` uniquement). Rien chez Google Play. |

---

## Récapitulatif — où vit chaque secret

| Secret | Où il vit | Dans le dépôt ? |
|---|---|---|
| Compte Apple Developer (email + mdp + 2FA) | Gestionnaire de mots de passe du propriétaire | ❌ jamais |
| Certificats / profils de signature iOS | Cloud signing Apple (Xcode Cloud) + trousseau du Mac mini | ❌ jamais |
| Compte GitHub `teiki5320` (mdp + 2FA) | Gestionnaire de mots de passe du propriétaire | ❌ jamais |
| Comptes OpenArt / AutoSprite / musique | Gestionnaire de mots de passe du propriétaire | ❌ jamais |
| Compte claude.ai | Gestionnaire de mots de passe du propriétaire | ❌ jamais |
| Variables d'environnement / API keys applicatives | **Il n'y en a aucune** (app hors-ligne) | — |

## Valeurs publiques par design (aucun risque à les voir dans le code)

- Bundle ID `com.teiki5320.trainCosy` (+ `.RunnerTests`) — public dans tout
  binaire iOS.
- Team ID Apple `K597U7X3FZ` — public dans la signature de tout binaire.
- Nom d'app « Train Cosy », version/numéro de build (`pubspec.yaml`,
  `lib/widgets/loading_screen.dart`).
- Dépôt `teiki5320/survival`, versions de dépendances (`pubspec.yaml`),
  version Flutter épinglée `3.41.9` (`ios/ci_scripts/ci_post_clone.sh`).
- Familles de polices Google Fonts (Lora, Cinzel).

## Checklist — reprise du projet sur une machine neuve (Mac)

1. **Cloner** : `git clone https://github.com/teiki5320/survival.git`
   (accès au dépôt requis — compte GitHub).
2. **Installer Flutter** (stable récent, ou `3.41.9` comme le CI) +
   Xcode à jour ; `flutter doctor` pour vérifier.
3. **Dépendances** : `flutter pub get` (rien d'autre — pas de `.env`, pas de
   clé à créer).
4. **Lancer** : brancher un iPhone/iPad → `flutter run --release`
   (⚠️ règle projet : toujours `--release`, le debug crashe sur iOS beta).
   `flutter analyze lib/` doit rendre 0 issue.
5. **Signer/builder en local (optionnel)** : ouvrir
   `ios/Runner.xcworkspace` dans Xcode, se connecter au compte Apple
   (Team `K597U7X3FZ`), la signature automatique fait le reste.
6. **Distribution** : pousser sur `main` → Xcode Cloud construit et livre
   sur TestFlight tout seul (vérifier le n° de build sur l'écran de
   chargement de l'app).
7. **Administrer** : App Store Connect (app, TestFlight, futurs IAP,
   Xcode Cloud) + GitHub (code). C'est tout — il n'y a **aucun autre
   service** à reprendre.
