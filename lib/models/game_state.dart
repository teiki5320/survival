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
        'items': _items,
        'flags': _flags.toList(),
        'unlocked': _unlocked.toList(),
        'wagonStage': wagonStage,
        'wagon2Stage': wagon2Stage,
        'wagon2LampAx': wagon2LampAx,
        'wagon2LampAy': wagon2LampAy,
        'wagon2LampBx': wagon2LampBx,
        'wagon2LampBy': wagon2LampBy,
        'bathX': bathX, 'bathY': bathY, 'bathH': bathH,
        'showerPanelX': showerPanelX, 'showerPanelY': showerPanelY,
        'showerPanelH': showerPanelH,
        'showerHeadX': showerHeadX, 'showerHeadY': showerHeadY,
        'showerHeadH': showerHeadH,
        'waterTankGlasses': waterTankGlasses,
        'filterTier': filterTier,
        'hydroTier': hydroTier,
        'woodTier': woodTier,
        'cardsRun': _cardsRunToJson(),
      });
      await File(path).writeAsString(data);
    } catch (_) {}
  }

  Future<void> load() async {
    try {
      final path = _getSavePathSync();
      final file = File(path);
      if (!file.existsSync()) return;
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _lampOn = data['lampOn'] as bool? ?? true;
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
      wagon2Stage = ((data['wagon2Stage'] as num?)?.toInt() ?? 0).clamp(0, 1);
      wagon2LampAx = (data['wagon2LampAx'] as num?)?.toDouble() ?? wagon2LampAx;
      wagon2LampAy = (data['wagon2LampAy'] as num?)?.toDouble() ?? wagon2LampAy;
      wagon2LampBx = (data['wagon2LampBx'] as num?)?.toDouble() ?? wagon2LampBx;
      wagon2LampBy = (data['wagon2LampBy'] as num?)?.toDouble() ?? wagon2LampBy;
      bathX = (data['bathX'] as num?)?.toDouble() ?? bathX;
      bathY = (data['bathY'] as num?)?.toDouble() ?? bathY;
      bathH = (data['bathH'] as num?)?.toDouble() ?? bathH;
      showerPanelX = (data['showerPanelX'] as num?)?.toDouble() ?? showerPanelX;
      showerPanelY = (data['showerPanelY'] as num?)?.toDouble() ?? showerPanelY;
      showerPanelH = (data['showerPanelH'] as num?)?.toDouble() ?? showerPanelH;
      showerHeadX = (data['showerHeadX'] as num?)?.toDouble() ?? showerHeadX;
      showerHeadY = (data['showerHeadY'] as num?)?.toDouble() ?? showerHeadY;
      showerHeadH = (data['showerHeadH'] as num?)?.toDouble() ?? showerHeadH;
      waterTankGlasses =
          ((data['waterTankGlasses'] as num?)?.toInt() ?? 0)
              .clamp(0, waterTankMax);
      filterTier = (data['filterTier'] as num?)?.toInt() ?? 1;
      hydroTier = (data['hydroTier'] as num?)?.toInt() ?? 1;
      woodTier = (data['woodTier'] as num?)?.toInt() ?? 1;
      _loadCardsRun(data['cardsRun']);
      notifyListeners();
    } catch (_) {}
  }

  // --- Energy (RETIRÉ) ---
  // L'énergie était décorative (jamais dépensée). Shims neutres conservés
  // pour ne rien casser ; ne fait plus rien.
  int get energy => 5;
  bool get canLeaveTrain => true;
  void spendEnergy([int amount = 1]) {}
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

  /// 2e wagon (cellier) : 0 = en désordre (état initial), 1 = aménagé/propre.
  int wagon2Stage = 0;

  /// Position des 2 lanternes du cellier (fraction w pour x, h pour y).
  /// Déplaçables au doigt dans le wagon 2 ; sauvegardées.
  double wagon2LampAx = 0.30, wagon2LampAy = 0.27;
  double wagon2LampBx = 0.70, wagon2LampBy = 0.27;

  /// Props positionnables du cellier (x=fraction w du centre, y=fraction h du
  /// haut, h=fraction h de la hauteur). Déplaçables au doigt, sauvegardés.
  double bathX = 0.60, bathY = 0.52, bathH = 0.30;
  double showerPanelX = 0.85, showerPanelY = 0.54, showerPanelH = 0.24;
  double showerHeadX = 0.85, showerHeadY = 0.14, showerHeadH = 0.32;

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
  void refreshCredits() {
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

  /// Démarre une nouvelle run : remet jauges, flags, progression à zéro.
  void startCardRun() {
    cardSoif = 70;
    cardFaim = 70;
    cardBois = 70;
    cardMoral = 70;
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
