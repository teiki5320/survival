import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../constants.dart';

class GameState extends ChangeNotifier {
  GameState._() {
    _initWeatherCycle();
    _initTrainRoute();
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
        'trainPosition': _trainPosition,
        'items': _items,
        'flags': _flags.toList(),
        'unlocked': _unlocked.toList(),
        'wagonStage': wagonStage,
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
      _trainPosition = (data['trainPosition'] as num?)?.toDouble() ?? kTrainStartPosition;
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
      wagonStage = (data['wagonStage'] as num?)?.toInt() ?? 0;
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

  void _initWeatherCycle() {
    _weatherTimer ??= Timer.periodic(kWeatherPeriod, (_) {
      final zone = trainZone;
      List<Weather> pool;
      if (zone == TrainZone.cold || zone == TrainZone.transitionToCold) {
        pool = [Weather.clear, Weather.cloudy, Weather.foggy, Weather.snowy];
      } else {
        pool = [Weather.clear, Weather.clear, Weather.cloudy, Weather.rainy];
      }
      pool.removeWhere((w) => w == _weather);
      _weather = pool[DateTime.now().millisecondsSinceEpoch % pool.length];
      notifyListeners();
    });
  }

  // --- Train route ---
  double _trainPosition = kTrainStartPosition;
  double get trainPosition => _trainPosition;
  Timer? _trainTimer;
  DateTime _lastTrainTick = DateTime.now();

  TrainZone get trainZone {
    final p = _trainPosition;
    if (p >= kColdZoneStart + kTransitionWidth && p < kColdZoneEnd - kTransitionWidth) {
      return TrainZone.cold;
    }
    if (p >= 1.0 - kTransitionWidth || p < kColdZoneStart + kTransitionWidth) {
      return TrainZone.transitionToCold;
    }
    if (p >= kColdZoneEnd - kTransitionWidth && p < kColdZoneEnd + kTransitionWidth) {
      return TrainZone.transitionToWarm;
    }
    return TrainZone.warm;
  }

  bool get inColdZone =>
      trainZone == TrainZone.cold || trainZone == TrainZone.transitionToCold;

  void _initTrainRoute() {
    _trainTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tickTrain();
    });
  }

  void _tickTrain() {
    final now = DateTime.now();
    final dt = now.difference(_lastTrainTick).inMilliseconds / 1000.0;
    if (dt <= 0) return;
    _lastTrainTick = now;
    final advance = dt / kLoopDurationSeconds;
    final old = _trainPosition;
    _trainPosition = (_trainPosition + advance) % 1.0;
    final oldZone = _zoneFor(old);
    final newZone = trainZone;
    if (oldZone != newZone || (_trainPosition - old).abs() > 0.001) {
      notifyListeners();
    }
  }

  TrainZone _zoneFor(double p) {
    if (p >= kColdZoneStart + kTransitionWidth && p < kColdZoneEnd - kTransitionWidth) {
      return TrainZone.cold;
    }
    if (p >= 1.0 - kTransitionWidth || p < kColdZoneStart + kTransitionWidth) {
      return TrainZone.transitionToCold;
    }
    if (p >= kColdZoneEnd - kTransitionWidth && p < kColdZoneEnd + kTransitionWidth) {
      return TrainZone.transitionToWarm;
    }
    return TrainZone.warm;
  }

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
    _trainTimer?.cancel();
    super.dispose();
  }
}

enum Weather { clear, cloudy, rainy, foggy, snowy }

enum TrainZone { cold, warm, transitionToCold, transitionToWarm }
