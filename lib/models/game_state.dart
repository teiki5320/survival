import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../constants.dart';

class GameState extends ChangeNotifier {
  GameState._() {
    _initWeatherCycle();
    load();
  }
  static final GameState instance = GameState._();

  // --- Persistence (pur dart:io, zéro plugin natif) ---
  static String? _savePath;

  static String _getSavePathSync() {
    if (_savePath != null) return _savePath!;
    // Sur iOS, le home directory pointe vers le sandbox de l'app.
    // Documents/ est persisté entre les sessions.
    final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
    final docs = Directory('$home/Documents');
    if (!docs.existsSync()) docs.createSync(recursive: true);
    _savePath = '${docs.path}/train_cosy_save.json';
    return _savePath!;
  }

  Future<void> save() async {
    try {
      final path = _getSavePathSync();
      final data = jsonEncode({
        'lampOn': _lampOn,
        'debugMode': debugMode,
        'seenTips': seenTips.toList(),
        'introCinematicSeen': introCinematicSeen,
        'items': _items,
        'flags': _flags.toList(),
        'unlocked': _unlocked.toList(),
        'wagonStage': wagonStage,
        'cabinTemp': cabinTemp,
        'stoveInstalled': stoveInstalled,
        'outfitWarmth': outfitWarmth,
        'shootWeaponLevel': shootWeaponLevel,
        'shootBestStars': shootBestStars,
        'shootBestScore': shootBestScore,
        'scrap': scrap,
        'shootUpgrades': shootUpgrades,
        'shootMuzX': shootMuzX, 'shootMuzY': shootMuzY,
        'shootGroundY': shootGroundY,
        'gareBestScore':
            gareBestScore.map((k, v) => MapEntry(k.toString(), v)),
        'dailyDay': _dailyDay,
        'dailyChestDay': dailyChestDay,
        'dailyKills': dailyKills,
        'dailyScrap': dailyScrap,
        'dailyGaresWon': dailyGaresWon,
        'dailyClaimed': dailyClaimed.toList(),
        'wagon2Stage': wagon2Stage,
        'wagon2LampAx': wagon2LampAx,
        'wagon2LampAy': wagon2LampAy,
        'wagon2LampBx': wagon2LampBx,
        'wagon2LampBy': wagon2LampBy,
        'wagon2LampAH': wagon2LampAH, 'wagon2LampBH': wagon2LampBH,
        'bathX': bathX, 'bathY': bathY, 'bathH': bathH,
        'showerPanelX': showerPanelX, 'showerPanelY': showerPanelY,
        'showerPanelH': showerPanelH,
        'showerHeadX': showerHeadX, 'showerHeadY': showerHeadY,
        'showerHeadH': showerHeadH,
        'wagon2CommodeX': wagon2CommodeX, 'wagon2CommodeY': wagon2CommodeY,
        'wagon2CommodeH': wagon2CommodeH,
        'locoMapCx': locoMapCx, 'locoMapCy': locoMapCy, 'locoMapW': locoMapW,
        'locoMapTurnY': locoMapTurnY, 'locoMapLeanZ': locoMapLeanZ,
        'waterTankGlasses': waterTankGlasses,
        'filterTier': filterTier,
        'hydroTier': hydroTier,
        'woodTier': woodTier,
        'cardsRun': _cardsRunToJson(),
      });
      await File(path).writeAsString(data);
    } catch (e) {
      debugPrint('GameState.save() a échoué: $e');
    }
  }

  Future<void> load() async {
    try {
      final path = _getSavePathSync();
      final file = File(path);
      if (!file.existsSync()) return;
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _lampOn = data['lampOn'] as bool? ?? true;
      debugMode = data['debugMode'] as bool? ?? false;
      seenTips.clear();
      if (data['seenTips'] is List) {
        seenTips.addAll((data['seenTips'] as List).cast<String>());
      }
      introCinematicSeen = data['introCinematicSeen'] as bool? ?? false;
      _items.clear();
      if (data['items'] is Map) {
        (data['items'] as Map).forEach((k, v) {
          _items[k as String] = (v as num).toInt();
        });
      }
      _flags.clear();
      if (data['flags'] is List) {
        _flags.addAll((data['flags'] as List).cast<String>());
      }
      _unlocked.clear();
      _unlocked.add('station_abandonnee');
      if (data['unlocked'] is List) {
        _unlocked.addAll((data['unlocked'] as List).cast<String>());
      }
      // 2 stages désormais (windowed/clean) : clamp pour vieilles sauvegardes.
      wagonStage = ((data['wagonStage'] as num?)?.toInt() ?? 0).clamp(0, 1);
      cabinTemp = (data['cabinTemp'] as num?)?.toDouble() ?? cabinTemp;
      stoveInstalled = (data['stoveInstalled'] as bool?) ?? stoveInstalled;
      outfitWarmth = (data['outfitWarmth'] as num?)?.toInt() ?? outfitWarmth;
      shootWeaponLevel =
          (data['shootWeaponLevel'] as num?)?.toInt() ?? shootWeaponLevel;
      shootBestStars =
          (data['shootBestStars'] as num?)?.toInt() ?? shootBestStars;
      shootBestScore =
          (data['shootBestScore'] as num?)?.toInt() ?? shootBestScore;
      scrap = (data['scrap'] as num?)?.toInt() ?? scrap;
      if (data['shootUpgrades'] is Map) {
        shootUpgrades = (data['shootUpgrades'] as Map).map(
            (k, v) => MapEntry(k as String, (v as num).toInt()));
      }
      shootMuzX = (data['shootMuzX'] as num?)?.toDouble() ?? shootMuzX;
      shootMuzY = (data['shootMuzY'] as num?)?.toDouble() ?? shootMuzY;
      shootGroundY = (data['shootGroundY'] as num?)?.toDouble() ?? shootGroundY;
      // Migration : anciennes valeurs (décor "vue de loin" 0.865, ou 1er jet du
      // décor en couches 0.80) -> calage actuel.
      if (shootGroundY > 0.84 || (shootGroundY - 0.80).abs() < 0.005) {
        shootMuzX = 0.11;
        shootMuzY = 0.83;
        shootGroundY = 0.83;
      }
      if (data['gareBestScore'] is Map) {
        gareBestScore = (data['gareBestScore'] as Map).map(
            (k, v) => MapEntry(int.parse(k as String), (v as num).toInt()));
      }
      _dailyDay = (data['dailyDay'] as num?)?.toInt() ?? 0;
      dailyChestDay = (data['dailyChestDay'] as num?)?.toInt() ?? -1;
      dailyKills = (data['dailyKills'] as num?)?.toInt() ?? 0;
      dailyScrap = (data['dailyScrap'] as num?)?.toInt() ?? 0;
      dailyGaresWon = (data['dailyGaresWon'] as num?)?.toInt() ?? 0;
      if (data['dailyClaimed'] is List) {
        dailyClaimed = (data['dailyClaimed'] as List).cast<String>().toSet();
      }
      wagon2Stage = ((data['wagon2Stage'] as num?)?.toInt() ?? 0).clamp(0, 1);
      wagon2LampAx = (data['wagon2LampAx'] as num?)?.toDouble() ?? wagon2LampAx;
      wagon2LampAy = (data['wagon2LampAy'] as num?)?.toDouble() ?? wagon2LampAy;
      wagon2LampBx = (data['wagon2LampBx'] as num?)?.toDouble() ?? wagon2LampBx;
      wagon2LampBy = (data['wagon2LampBy'] as num?)?.toDouble() ?? wagon2LampBy;
      wagon2LampAH = (data['wagon2LampAH'] as num?)?.toDouble() ?? wagon2LampAH;
      wagon2LampBH = (data['wagon2LampBH'] as num?)?.toDouble() ?? wagon2LampBH;
      bathX = (data['bathX'] as num?)?.toDouble() ?? bathX;
      bathY = (data['bathY'] as num?)?.toDouble() ?? bathY;
      bathH = (data['bathH'] as num?)?.toDouble() ?? bathH;
      showerPanelX = (data['showerPanelX'] as num?)?.toDouble() ?? showerPanelX;
      showerPanelY = (data['showerPanelY'] as num?)?.toDouble() ?? showerPanelY;
      showerPanelH = (data['showerPanelH'] as num?)?.toDouble() ?? showerPanelH;
      showerHeadX = (data['showerHeadX'] as num?)?.toDouble() ?? showerHeadX;
      showerHeadY = (data['showerHeadY'] as num?)?.toDouble() ?? showerHeadY;
      showerHeadH = (data['showerHeadH'] as num?)?.toDouble() ?? showerHeadH;
      wagon2CommodeX = (data['wagon2CommodeX'] as num?)?.toDouble() ?? wagon2CommodeX;
      wagon2CommodeY = (data['wagon2CommodeY'] as num?)?.toDouble() ?? wagon2CommodeY;
      wagon2CommodeH = (data['wagon2CommodeH'] as num?)?.toDouble() ?? wagon2CommodeH;
      locoMapCx = (data['locoMapCx'] as num?)?.toDouble() ?? locoMapCx;
      locoMapCy = (data['locoMapCy'] as num?)?.toDouble() ?? locoMapCy;
      locoMapW = (data['locoMapW'] as num?)?.toDouble() ?? locoMapW;
      locoMapTurnY = (data['locoMapTurnY'] as num?)?.toDouble() ?? locoMapTurnY;
      locoMapLeanZ = (data['locoMapLeanZ'] as num?)?.toDouble() ?? locoMapLeanZ;
      waterTankGlasses =
          ((data['waterTankGlasses'] as num?)?.toInt() ?? 0)
              .clamp(0, waterTankMax);
      filterTier = (data['filterTier'] as num?)?.toInt() ?? 1;
      hydroTier = (data['hydroTier'] as num?)?.toInt() ?? 1;
      woodTier = (data['woodTier'] as num?)?.toInt() ?? 1;
      _loadCardsRun(data['cardsRun']);
      notifyListeners();
    } catch (e, st) {
      // Sauvegarde illisible (JSON corrompu, droits, disque plein...) : on
      // démarre sur une partie vierge plutôt que de crasher, mais on LOG (en
      // debug) pour ne pas perdre l'info silencieusement.
      debugPrint('GameState.load() a échoué, partie vierge utilisée: $e\n$st');
    }
  }

  // --- Mode debug (outils de test cachés du vrai jeu) ---
  // Un seul interrupteur révèle tous les outils de dev (thermomètre test,
  // FAB d'ajustement des props, affichage de TOUS les objets du wagon, et le
  // mode "duel" du combat). Debug OFF = le vrai jeu (objets progressifs,
  // température auto, campagne de combat complète). Persisté.
  bool debugMode = false;
  void setDebugMode(bool v) {
    if (debugMode == v) return;
    debugMode = v;
    if (!v) _recomputeAutoTemp(); // repasse en température auto en sortant
    notifyListeners();
    save();
  }

  void toggleDebug() => setDebugMode(!debugMode);

  // --- Tutoriel & cinématique d'ouverture ---
  // `seenTips` : ids des bulles d'aide déjà vues (1re utilisation). Persisté.
  // `introCinematicSeen` : la cinématique d'ouverture a déjà été jouée.
  final Set<String> seenTips = {};
  bool introCinematicSeen = false;
  bool tipSeen(String id) => seenTips.contains(id);
  void markTipSeen(String id) {
    if (seenTips.add(id)) save();
  }

  void markIntroCinematicSeen() {
    if (!introCinematicSeen) {
      introCinematicSeen = true;
      save();
    }
  }

  // ===========================================================
  // SOURCE UNIQUE de déblocage des objets/compagnons.
  // Lue À LA FOIS pour la VISIBILITÉ (side_scroll_scene) ET pour
  // l'INTERACTIVITÉ (boutons d'action dans main.dart). Un élément non
  // débloqué est donc invisible ET non cliquable.
  // En mode debug, tout est débloqué (pour tester les anims/rendu).
  // ===========================================================
  bool propUnlocked(String key) =>
      debugMode || cardFlags.contains('asset_$key');
  bool get dogShown => debugMode || cardFlags.contains('aLeChien');
  bool get sisterShown => debugMode || cardFlags.contains('aLaSoeur');

  // --- Energy (RETIRÉ) ---
  // L'énergie était décorative (jamais dépensée). Shims neutres conservés
  // pour ne rien casser ; ne fait plus rien.
  @Deprecated('Système d\'énergie retiré ; shim conservé pour compat sauvegarde')
  int get energy => 5;
  @Deprecated('Le train ne se quitte plus ; toujours true')
  bool get canLeaveTrain => true;
  @Deprecated('No-op ; énergie retirée')
  void spendEnergy([int amount = 1]) {}
  @Deprecated('No-op ; énergie retirée')
  void grantEnergy(int amount) {}

  // --- Jauges de survie : FUSIONNÉES avec les 4 stats du mode cartes ---
  // hunger/thirst/fatigue n'existent plus comme système temps réel séparé.
  // Le HUD du wagon lit désormais les VRAIES jauges (cardFaim/Soif/Moral)
  // normalisées 0..1. fatigue est mappée sur le moral (faute de mieux), en
  // attendant un éventuel 5e axe. Les restoreX nudgent les vraies jauges.
  double get hunger => cardFaim / 100.0;
  double get thirst => cardSoif / 100.0;
  double get fatigue => cardMoral / 100.0;

  void restoreHunger(double amount) {
    nudgeCardStat('faim', (amount * 100).round());
  }

  void restoreThirst(double amount) {
    nudgeCardStat('soif', (amount * 100).round());
  }

  void restoreFatigue(double amount) {
    nudgeCardStat('moral', (amount * 100).round());
  }

  // --- Wagon state ---
  bool _lampOn = true;
  bool get lampOn => _lampOn;
  void toggleLamp() {
    _lampOn = !_lampOn;
    notifyListeners();
    save();
  }

  int wagonStage = 0;

  // --- Température cabine (thermomètre) ---
  // [cabinTemp] = température ressentie dans le wagon (°C). Calculée AUTO en
  // jeu normal (zone de la map + météo + nuit + feu/bois). En mode debug, le
  // bouton de test la pilote à la main.
  double cabinTemp = 18.0;
  bool isNight = false; // reporté depuis l'écran wagon (jour/nuit)
  // Protection contre le froid : meilleur wagon + habits chauds -> Shen
  // supporte des températures plus basses (seuil plus bas). Le poêle, lui,
  // RÉCHAUFFE la cabine (entre dans cabinTemp via le feu, pas ici).
  bool stoveInstalled = true; // le poêle "à remettre dans le wagon"
  int outfitWarmth = 0; // bonus tenue (0 = tenue de base)

  /// Température cible calculée depuis l'environnement : zone traversée +
  /// météo + nuit + chaleur du feu (poêle alimenté en bois). C'est la mécanique
  /// cosy : garder du bois = garder la cabine chaude.
  double computeAutoCabinTemp() {
    double t;
    switch (trainZone) {
      case TrainZone.warm:
        t = 17;
        break;
      case TrainZone.transitionToWarm:
        t = 12;
        break;
      case TrainZone.transitionToCold:
        t = 5;
        break;
      case TrainZone.cold:
        t = -4;
        break;
    }
    switch (weather) {
      case Weather.snowy:
        t -= 4;
        break;
      case Weather.foggy:
        t -= 2;
        break;
      case Weather.rainy:
        t -= 2;
        break;
      case Weather.cloudy:
        t -= 1;
        break;
      case Weather.clear:
        break;
    }
    if (isNight) t -= 3;
    // Le poêle bien alimenté rend la cabine COSY même au nord (fantaisie "près
    // du feu") : un feu plein vainc le froid de jour, mais nuit/tempête restent
    // précaires -> il faut entretenir le bois.
    if (stoveInstalled) {
      if (cardBois >= 40) {
        t += 14;
      } else if (cardBois >= 12) {
        t += 7;
      }
    }
    return t.clamp(-15.0, 28.0);
  }

  /// Recale [cabinTemp] sur l'environnement (sauf en mode debug = manuel).
  void _recomputeAutoTemp() {
    if (debugMode) return; // en debug, le bouton test pilote la température
    final t = computeAutoCabinTemp();
    if ((t - cabinTemp).abs() > 0.05) {
      cabinTemp = t;
      notifyListeners();
    }
  }

  /// Reporte l'état jour/nuit (depuis l'écran wagon) et recale la température.
  void setNight(bool n) {
    if (isNight == n) return;
    isNight = n;
    _recomputeAutoTemp();
  }
  // Mini-jeu de défense de gare : niveau d'arme débloqué (0=fronde, 1=arc,
  // 2=arbalète, 3=cocktail) + meilleur score d'étoiles obtenu.
  int shootWeaponLevel = 0;
  int shootBestStars = 0;
  int shootBestScore = 0; // record en mode survie
  int scrap = 0; // ferraille (monnaie du mini-jeu)
  Map<String, int> shootUpgrades = {}; // niveaux des améliorations d'atelier
  // Position du canon (trappe/fenêtre du train) + ligne de sol, en unités de
  // scène du combat. Réglables via le mode ajuster du combat, persistées.
  // Calé sur le décor en couches (train en bas-gauche, quai ~0.83).
  double shootMuzX = 0.11, shootMuzY = 0.83, shootGroundY = 0.83;
  void setShootMuzzle(double mx, double my, double groundY) {
    shootMuzX = mx.clamp(0.0, 2.5);
    shootMuzY = my.clamp(0.0, 1.0);
    shootGroundY = groundY.clamp(0.4, 1.0);
    notifyListeners();
    save();
  }

  // Définitions de l'atelier (clé -> (libellé, desc, coûts par niveau)).
  // Partagé entre le combat et l'écran Atelier ouvert depuis la map.
  static const Map<String, (String, String, List<int>)> shootShopDefs = {
    'dmg': ('Cailloux plus durs', 'Dégâts de base +1', [40, 80, 140, 220]),
    'hearts': ('Blindage du train', 'Cœur de départ +1', [50, 100, 170, 260]),
    'range': ('Meilleure fronde', 'Portée/vitesse +8%', [35, 70, 120]),
    'stones': ('Double charge', 'Démarre avec +1 pierre', [120, 260]),
    'choices': ('Plus de choix', '4 cartes de renfort', [150]),
    'magnet': ('Aimant à ferraille', 'Ramasse le butin tout seul', [120]),
    'shield': ('Bouclier de wagon', 'Encaisse 1 coup gratuit/vague', [160, 300]),
    'bomb': ('Bombe de secours', 'Frappe TOUT l\'écran (1/vague)', [200]),
  };

  /// Achète une amélioration d'atelier (paie en ferraille). Renvoie true si OK.
  bool buyShootUpgrade(String key) {
    final def = shootShopDefs[key];
    if (def == null) return false;
    final lvl = shootUpgrades[key] ?? 0;
    if (lvl >= def.$3.length) return false; // déjà au max
    final cost = def.$3[lvl];
    if (scrap < cost) return false;
    scrap -= cost;
    shootUpgrades[key] = lvl + 1;
    notifyListeners();
    save();
    return true;
  }
  // Meilleur score de combat (/100) par gare (index 0-based) : méta-progression
  // "atteindre 100% sur chaque gare en ~20 parties".
  Map<int, int> gareBestScore = {};

  /// Conversion score /100 -> étoiles (0..3) pour la collection des gares.
  static int starsForScore(int s) =>
      s >= 90 ? 3 : (s >= 70 ? 2 : (s >= 50 ? 1 : 0));

  /// Étoiles obtenues sur une gare (depuis le meilleur score enregistré).
  int gareStars(int gareIndex) => starsForScore(gareBestScore[gareIndex] ?? 0);

  /// Total d'étoiles récoltées sur les 14 gares (sur 14×3 = 42).
  int get totalGareStars =>
      gareBestScore.values.fold(0, (a, s) => a + starsForScore(s));

  // --- Rendez-vous quotidiens (rétention "reviens demain") ---
  // Coffre gratuit 1×/jour + 3 missions journalières qui rapportent de la
  // ferraille. Tout se réinitialise au changement de jour calendaire.
  int _dailyDay = 0; // numéro de jour (epoch days) du jour en cours
  int dailyChestDay = -1; // jour où le coffre a été ouvert (-1 = jamais)
  int dailyKills = 0; // pillards tués aujourd'hui
  int dailyScrap = 0; // ferraille récoltée en combat aujourd'hui
  int dailyGaresWon = 0; // gares défendues sans perdre de cœur aujourd'hui
  Set<String> dailyClaimed = {}; // missions déjà réclamées aujourd'hui

  static int get _todayNum =>
      DateTime.now().millisecondsSinceEpoch ~/ 86400000;

  /// Missions du jour : id -> (libellé, cible, récompense ferraille).
  static const Map<String, (String, int, int)> dailyMissions = {
    'kills': ('Abattre 60 pillards', 60, 40),
    'perfect': ('Défendre 1 gare sans perte', 1, 60),
    'scrap': ('Récolter 100 ferraille', 100, 30),
  };

  void _ensureDailyDay() {
    final t = _todayNum;
    if (_dailyDay != t) {
      _dailyDay = t;
      dailyKills = 0;
      dailyScrap = 0;
      dailyGaresWon = 0;
      dailyClaimed = {};
    }
  }

  bool get dailyChestAvailable {
    _ensureDailyDay();
    return dailyChestDay != _dailyDay;
  }

  /// Ouvre le coffre quotidien (si dispo) et renvoie la ferraille gagnée.
  int claimDailyChest() {
    if (!dailyChestAvailable) return 0;
    final reward = 25 + (totalGareStars * 2); // récompense qui grandit
    scrap += reward;
    dailyChestDay = _dailyDay;
    notifyListeners();
    save();
    return reward;
  }

  int dailyProgress(String id) {
    _ensureDailyDay();
    switch (id) {
      case 'kills':
        return dailyKills;
      case 'perfect':
        return dailyGaresWon;
      case 'scrap':
        return dailyScrap;
    }
    return 0;
  }

  bool dailyDone(String id) =>
      dailyProgress(id) >= (dailyMissions[id]?.$2 ?? 1 << 30);
  bool dailyReady(String id) =>
      dailyDone(id) && !dailyClaimed.contains(id);

  /// Réclame la récompense d'une mission accomplie. Renvoie la ferraille.
  int claimDailyMission(String id) {
    if (!dailyReady(id)) return 0;
    final reward = dailyMissions[id]?.$3 ?? 0;
    scrap += reward;
    dailyClaimed.add(id);
    notifyListeners();
    save();
    return reward;
  }

  /// Bilan d'un combat (appelé à la fin d'une run) : alimente les compteurs
  /// des missions du jour.
  void reportCombat(
      {required int kills, required int scrapCollected, required bool perfect}) {
    _ensureDailyDay();
    dailyKills += kills;
    dailyScrap += scrapCollected;
    if (perfect) dailyGaresWon += 1;
    notifyListeners();
    save();
  }

  /// Récompenses du combat de gare : convertit le score /100 en ressources
  /// (bois/eau/nourriture/moral) injectées dans les jauges Reigns, et pose des
  /// flags de "tier" + de réussite que les cartes de gare lisent pour brancher
  /// l'histoire. Garde le meilleur score de la gare.
  void applyCombatRewards(int gareIndex, int score100) {
    final s = score100.clamp(0, 100);
    // Un bon score ravitaille vraiment le train (loot réel, non atténué).
    applyCardDeltas({
      'bois': (s / 100 * 20).round(),
      'soif': (s / 100 * 12).round(),
      'faim': (s / 100 * 12).round(),
      'moral': (s / 100 * 10).round(),
    });
    // Tier (on nettoie l'ancien avant de reposer) + flag de réussite par gare.
    cardFlags.removeWhere((f) => f.startsWith('combatTier'));
    cardFlags.add(s >= 80
        ? 'combatTierHigh'
        : s >= 50
            ? 'combatTierMid'
            : 'combatTierLow');
    if (s >= 70) cardFlags.add('combatGood_$gareIndex');
    cardFlags.add('combatDone_$gareIndex');
    if (s > (gareBestScore[gareIndex] ?? 0)) gareBestScore[gareIndex] = s;
    notifyListeners();
    save();
  }
  double get coldThreshold => 12.0 - wagonStage * 2 - outfitWarmth;
  // Vrai si Shen (et la sœur) ont froid -> frissons + blocage gain moral.
  bool get feltCold => cabinTemp < coldThreshold;
  // 0 (juste à la limite) .. ~20 (gel) : pilote la fréquence des frissons.
  double get coldness => (coldThreshold - cabinTemp).clamp(0.0, 20.0);
  void setCabinTemp(double t) {
    cabinTemp = t.clamp(-15.0, 28.0);
    notifyListeners();
    save();
  }

  /// 2e wagon (cellier) : 0 = en désordre (état initial), 1 = aménagé/propre.
  int wagon2Stage = 0;

  /// Position des 2 lanternes du cellier (fraction w pour x, h pour y).
  /// Déplaçables au doigt dans le wagon 2 ; sauvegardées.
  double wagon2LampAx = 0.25, wagon2LampAy = 0.24, wagon2LampAH = 0.12;
  double wagon2LampBx = 0.53, wagon2LampBy = 0.26, wagon2LampBH = 0.12;

  /// Props positionnables du cellier (x=fraction w du centre, y=fraction h du
  /// haut, h=fraction h de la hauteur). Déplaçables + redimensionnables,
  /// sauvegardés. Valeurs par défaut calées en jeu (mode ajuster).
  double bathX = 0.48, bathY = 0.48, bathH = 0.31;
  double showerPanelX = 0.72, showerPanelY = 0.47, showerPanelH = 0.32;
  double showerHeadX = 0.75, showerHeadY = 0.22, showerHeadH = 0.32;
  // Armoire à vêtements (commode) déplacée dans le cellier : tap = ouvre la
  // garde-robe, déplaçable/redimensionnable en mode ajuster.
  double wagon2CommodeX = 0.30, wagon2CommodeY = 0.55, wagon2CommodeH = 0.22;

  /// Carte du voyage accrochée dans la LOCOMOTIVE : centre (cx,cy en fractions
  /// de la scène) + largeur (fraction de la largeur). Déplaçable + pinçable en
  /// mode ajuster, persistée.
  double locoMapCx = 0.94, locoMapCy = 0.33, locoMapW = 0.23;
  // Rotation 3/4 (axe vertical) + penché (axe écran), réglables à la main.
  double locoMapTurnY = 1.15; // tour 3/4 pour épouser le mur de droite
  double locoMapLeanZ = -0.08; // penché léger vers la gauche
  void setLocoMap(double cx, double cy, double w) {
    locoMapCx = cx.clamp(0.04, 0.96);
    locoMapCy = cy.clamp(0.04, 0.96);
    locoMapW = w.clamp(0.08, 0.95);
    notifyListeners();
    save();
  }

  void nudgeLocoMapRot(double dTurn, double dLean) {
    locoMapTurnY = (locoMapTurnY + dTurn).clamp(-1.4, 1.4);
    locoMapLeanZ = (locoMapLeanZ + dLean).clamp(-0.6, 0.6);
    notifyListeners();
    save();
  }

  // --- Water tank (filter prop) — 0..5 verres stockés ---
  int waterTankGlasses = 0;
  static const int waterTankMax = 5;
  static const int waterTankFrames = 6;

  void setWaterTankGlasses(int n) {
    waterTankGlasses = n.clamp(0, waterTankMax);
    notifyListeners();
    save();
  }

  // --- Equipment tiers (1-4) ---
  int filterTier = 1;
  int hydroTier = 1;
  int woodTier = 1;

  void upgradeTier(String which) {
    switch (which) {
      case 'filter':
        if (filterTier < 4) filterTier++;
      case 'hydro':
        if (hydroTier < 4) hydroTier++;
      case 'wood':
        if (woodTier < 4) woodTier++;
    }
    notifyListeners();
    save();
  }

  // --- Météo (liée à la zone) ---
  Weather _weather = Weather.clear;
  Weather get weather => _weather;
  Timer? _weatherTimer;

  /// Palette météo cohérente avec la zone traversée. Le grand nord est
  /// majoritairement neigeux/brumeux ; la zone tempérée n'a JAMAIS de neige.
  List<Weather> _weatherPoolForZone(TrainZone zone) {
    switch (zone) {
      case TrainZone.cold:
        return [Weather.snowy, Weather.snowy, Weather.foggy, Weather.cloudy];
      case TrainZone.transitionToCold:
        return [Weather.foggy, Weather.cloudy, Weather.snowy, Weather.clear];
      case TrainZone.transitionToWarm:
        return [Weather.cloudy, Weather.clear, Weather.foggy, Weather.rainy];
      case TrainZone.warm:
        return [Weather.clear, Weather.clear, Weather.cloudy, Weather.rainy,
          Weather.foggy];
    }
  }

  void _pickWeather() {
    final pool = _weatherPoolForZone(trainZone)
      ..removeWhere((w) => w == _weather);
    if (pool.isEmpty) return;
    _weather = pool[DateTime.now().millisecondsSinceEpoch % pool.length];
    _recomputeAutoTemp(); // météo/zone changent -> température recalculée
    notifyListeners();
  }

  /// Force un rafraîchissement météo cohérent avec la zone courante. Appelé
  /// quand on change de gare (donc potentiellement de zone) : entrer dans le
  /// nord fait tomber la neige tout de suite, sans attendre le timer.
  void refreshWeatherForZone() => _pickWeather();

  void _initWeatherCycle() {
    // Variation d'ambiance DANS une zone (le changement de zone, lui, est
    // déclenché par refreshWeatherForZone à l'avance de gare).
    _weatherTimer ??= Timer.periodic(kWeatherPeriod, (_) => _pickWeather());
  }

  // --- Train route ---
  // Progression DANS le segment courant (0..1) : 0 = on vient d'arriver à la
  // gare, 1 = dernière carte du segment jouée. Mise à jour par le moteur de
  // cartes ; sert à faire glisser le train entre deux gares sur la carte.
  double cardSegmentProgress = 0.0;

  /// Position du train sur la spline de la carte (0..1). Dérivée de la
  /// progression de la run : gare courante + fraction du segment. Plus
  /// d'horloge — la carte suit l'histoire. Hors run, on est à la gare 1.
  double get trainPosition {
    if (!hasCardRun) return kGarePositions.first;
    final i = (cardGareIndex ?? 0).clamp(0, kGarePositions.length - 1);
    final t0 = kGarePositions[i];
    if (i >= kGarePositions.length - 1) return t0;
    final t1 = kGarePositions[i + 1];
    var forward = (t1 - t0) % 1.0; // distance vers l'avant (gère le wrap 1→0)
    if (forward < 0) forward += 1.0;
    final p = t0 + cardSegmentProgress.clamp(0.0, 1.0) * forward;
    return p % 1.0;
  }

  /// Indice de gare effectif pour les effets de zone (clampé).
  int get _effectiveGareIndex =>
      (cardGareIndex ?? 0).clamp(0, kGarePositions.length - 1);

  TrainZone get trainZone {
    if (!hasCardRun) return TrainZone.warm;
    final i = _effectiveGareIndex;
    if (i >= kColdGareIndex) return TrainZone.cold;
    if (i == kColdGareIndex - 1) return TrainZone.transitionToCold;
    return TrainZone.warm;
  }

  bool get inColdZone =>
      trainZone == TrainZone.cold || trainZone == TrainZone.transitionToCold;

  // --- Thought bubble context ---
  String get contextualThought {
    if (hunger < 0.2) return '🍖';
    if (thirst < 0.2) return '💧';
    if (fatigue < 0.15) return '💤';
    if (inColdZone) return '❄️';
    const neutral = ['☕', '💭', '🌿', '📖', '🎵'];
    return neutral[DateTime.now().second % neutral.length];
  }

  // --- Inventory ---
  final Map<String, int> _items = {};
  Map<String, int> get items => Map.unmodifiable(_items);

  void grantItem(String id, [int qty = 1]) {
    _items[id] = (_items[id] ?? 0) + qty;
    if ((_items[id] ?? 0) > 1000) _items[id] = 1000;
    notifyListeners();
    save();
  }

  /// Returns true if the consumption succeeded (had enough).
  bool consumeItem(String id, [int qty = 1]) {
    final have = _items[id] ?? 0;
    if (have < qty) return false;
    _items[id] = have - qty;
    notifyListeners();
    save();
    return true;
  }

  int itemCount(String id) => _items[id] ?? 0;

  // --- Story flags ---
  final Set<String> _flags = {};
  Set<String> get flags => Set.unmodifiable(_flags);

  void setFlag(String flag) {
    if (_flags.add(flag)) {
      notifyListeners();
      save();
    }
  }

  bool hasFlag(String flag) => _flags.contains(flag);

  // ===========================================================
  // MODE CARTES (Reigns) — source de vérité unique des 4 jauges
  // soif/faim/bois/moral (0-100) + état d'une run en cours.
  // Le wagon (manger/boire/mettre du bois) nudge ces jauges ; le
  // moteur de cartes les lit et les modifie. Tout est persisté.
  // ===========================================================
  static const int statMax = 100;
  int cardSoif = 70;
  int cardFaim = 70;
  int cardBois = 70;
  int cardMoral = 70;

  // Progression de la run en cours (null = pas de run / terminée).
  int? cardGareIndex; // segment courant (0-based)
  final Set<String> cardFlags = {}; // flags narratifs de la run
  final Set<String> cardSeenOneshot = {}; // fillers oneshot déjà vus
  int cardSoin = 0; // nb de fois où Shen a vraiment protégé sa sœur

  bool get hasCardRun => cardGareIndex != null;

  // --- Crédits de tirage de cartes ---
  // Répondre à une carte (= la tirer) coûte 1 crédit. On en a
  // [cardCreditsMax] et ils se rechargent lentement EN TEMPS RÉEL (1 toutes
  // les [creditRefillInterval]). C'est CE rythme qui ralentit l'avancée de
  // l'histoire : on joue quelques cartes d'affilée, puis on laisse le temps
  // passer avant de continuer. (Remplace l'ancien budget de ravitaillement.)
  static const int cardCreditsMax = 3;
  static const Duration creditRefillInterval = Duration(minutes: 8);
  int cardCredits = cardCreditsMax;
  // Timestamp (ms epoch) où le PROCHAIN crédit sera rendu. 0 = pile pleine.
  int cardCreditNextMs = 0;

  /// Recalcule les crédits gagnés avec le temps écoulé (régen même hors-ligne).
  /// À appeler à l'ouverture de l'écran cartes et périodiquement.
  bool _refreshingCredits = false;
  void refreshCredits() {
    if (_refreshingCredits) return; // anti-réentrance (timer + ouverture écran)
    _refreshingCredits = true;
    try {
      _refreshCreditsInner();
    } finally {
      _refreshingCredits = false;
    }
  }

  void _refreshCreditsInner() {
    if (cardCredits >= cardCreditsMax) {
      cardCreditNextMs = 0;
      return;
    }
    final intervalMs = creditRefillInterval.inMilliseconds;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (cardCreditNextMs == 0) {
      // Aucune minuterie en cours : on en démarre une.
      cardCreditNextMs = now + intervalMs;
      save();
      return;
    }
    var changed = false;
    while (cardCredits < cardCreditsMax && now >= cardCreditNextMs) {
      cardCredits++;
      cardCreditNextMs += intervalMs;
      changed = true;
    }
    if (cardCredits >= cardCreditsMax) cardCreditNextMs = 0;
    if (changed) {
      notifyListeners();
      save();
    }
  }

  /// Millisecondes avant le prochain crédit (0 si pile pleine).
  int get msToNextCredit {
    if (cardCredits >= cardCreditsMax || cardCreditNextMs == 0) return 0;
    final d = cardCreditNextMs - DateTime.now().millisecondsSinceEpoch;
    return d < 0 ? 0 : d;
  }

  /// Dépense 1 crédit pour tirer une carte. Retourne false si à sec (l'écran
  /// bloque alors le swipe et invite à attendre la recharge).
  bool spendCardCredit() {
    refreshCredits();
    if (cardCredits <= 0) return false;
    final wasFull = cardCredits >= cardCreditsMax;
    cardCredits--;
    if (wasFull) {
      // On était plein : démarre le minuteur de recharge du 1er crédit manquant.
      cardCreditNextMs =
          DateTime.now().millisecondsSinceEpoch + creditRefillInterval.inMilliseconds;
    }
    notifyListeners();
    save();
    return true;
  }

  // Stat de départ VOLONTAIREMENT BASSE : on commence l'aventure « au mini »
  // (train abîmé, froid, à bout). À remonter en jouant. (Ajustable.)
  static const int kStartStat = 25;

  /// Démarre une nouvelle run : remet jauges (basses), flags, progression à 0.
  void startCardRun() {
    cardSoif = kStartStat;
    cardFaim = kStartStat;
    cardBois = kStartStat;
    cardMoral = kStartStat;
    cardGareIndex = 0;
    cardFlags.clear();
    cardSeenOneshot.clear();
    cardSoin = 0;
    cardCredits = cardCreditsMax;
    cardCreditNextMs = 0;
    cardSegmentProgress = 0.0;
    // Réserve de bois de départ (bûches dans le wagon).
    _items['wood'] = kWoodStartReserve;
    // Météo de départ cohérente avec la zone tempérée du début.
    _pickWeather();
    save();
    notifyListeners();
  }

  /// NOUVELLE PARTIE : remet TOUT à zéro (flags, jauges, objets débloqués,
  /// compagnons, état du wagon). Sans ça, « Nouvelle partie » gardait les flags
  /// (asset_*, aLeChien, aLaSoeur...) de la sauvegarde -> chien/objets restaient
  /// présents. Le mode debug, lui, est conservé (préférence de dev).
  void resetForNewGame() {
    waterTankGlasses = 0;
    wagonStage = 0;
    wagon2Stage = 0;
    filterTier = 1;
    hydroTier = 1;
    woodTier = 1;
    _items.clear();
    _flags.clear(); // anciens flags d'histoire (sécurité)
    seenTips.clear(); // le tuto rejoue
    introCinematicSeen = false; // la cinématique d'ouverture rejoue
    _lampOn = true;
    isNight = false;
    startCardRun(); // remet jauges + cardGareIndex=0 + VIDE cardFlags/oneshot/soin
    _recomputeAutoTemp();
  }

  /// Termine la run (atteinte d'une fin) : on efface la progression mais on
  /// garde les jauges figées pour l'écran de fin.
  void endCardRun() {
    cardGareIndex = null;
    save();
  }

  /// Applique des deltas aux 4 jauges, clampe 0-100, persiste.
  void applyCardDeltas(Map<String, int> deltas) {
    cardSoif = (cardSoif + (deltas['soif'] ?? 0)).clamp(0, statMax);
    cardFaim = (cardFaim + (deltas['faim'] ?? 0)).clamp(0, statMax);
    cardBois = (cardBois + (deltas['bois'] ?? 0)).clamp(0, statMax);
    cardMoral = (cardMoral + (deltas['moral'] ?? 0)).clamp(0, statMax);
    _recomputeAutoTemp(); // le bois alimente le feu -> impacte la température
    notifyListeners();
    save();
  }

  /// Nudge ponctuel d'une jauge depuis le wagon (manger, boire, bois).
  void nudgeCardStat(String stat, int delta) {
    switch (stat) {
      case 'soif':
        cardSoif = (cardSoif + delta).clamp(0, statMax);
      case 'faim':
        cardFaim = (cardFaim + delta).clamp(0, statMax);
      case 'bois':
        cardBois = (cardBois + delta).clamp(0, statMax);
      case 'moral':
        // Le froid empêche de GAGNER du moral (on peut encore en perdre).
        if (delta > 0 && feltCold) delta = 0;
        cardMoral = (cardMoral + delta).clamp(0, statMax);
    }
    notifyListeners();
    save();
  }

  Map<String, dynamic> _cardsRunToJson() => {
        'soif': cardSoif,
        'faim': cardFaim,
        'bois': cardBois,
        'moral': cardMoral,
        'gareIndex': cardGareIndex,
        'flags': cardFlags.toList(),
        'seenOneshot': cardSeenOneshot.toList(),
        'soin': cardSoin,
        'credits': cardCredits,
        'creditNextMs': cardCreditNextMs,
        'segProgress': cardSegmentProgress,
      };

  void _loadCardsRun(dynamic raw) {
    if (raw is! Map) return;
    final m = raw.cast<String, dynamic>();
    cardSoif = (m['soif'] as num?)?.toInt() ?? 70;
    cardFaim = (m['faim'] as num?)?.toInt() ?? 70;
    cardBois = (m['bois'] as num?)?.toInt() ?? 70;
    cardMoral = (m['moral'] as num?)?.toInt() ?? 70;
    cardGareIndex = (m['gareIndex'] as num?)?.toInt();
    cardFlags
      ..clear()
      ..addAll(((m['flags'] as List?) ?? const []).cast<String>());
    cardSeenOneshot
      ..clear()
      ..addAll(((m['seenOneshot'] as List?) ?? const []).cast<String>());
    cardSoin = (m['soin'] as num?)?.toInt() ?? 0;
    cardCredits = ((m['credits'] as num?)?.toInt() ?? cardCreditsMax)
        .clamp(0, cardCreditsMax);
    cardCreditNextMs = (m['creditNextMs'] as num?)?.toInt() ?? 0;
    cardSegmentProgress =
        ((m['segProgress'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);
  }

  // --- Locations ---
  final Set<String> _unlocked = {'station_abandonnee'};
  Set<String> get unlockedLocations => Set.unmodifiable(_unlocked);

  void unlockLocation(String id) {
    if (_unlocked.add(id)) {
      notifyListeners();
      save();
    }
  }

  bool isLocationUnlocked(String id) => _unlocked.contains(id);

  @override
  void dispose() {
    _weatherTimer?.cancel();
    super.dispose();
  }
}

enum Weather { clear, cloudy, rainy, foggy, snowy }

enum TrainZone { cold, warm, transitionToCold, transitionToWarm }
