import 'dart:async';

import 'package:flutter/foundation.dart';

/// Centralised game state: energy, inventory, story flags, and which
/// world locations the player has unlocked. Single source of truth so
/// every screen reads from the same place via [ChangeNotifier].
///
/// Energy mechanics:
///   - Max 5 "energy points" — one is spent per location event.
///   - Refills slowly: +1 every [energyRefillSeconds]. Internal timer
///     wakes the notifier when a point comes back.
///   - At 0 energy the wagon door action is blocked (the player has to
///     wait it out).
class GameState extends ChangeNotifier {
  GameState._() {
    _refillTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _tickRefill(),
    );
    _drainTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _tickDrain(),
    );
    _initWeatherCycle();
    _initTrainRoute();
  }
  static final GameState instance = GameState._();

  // --- Energy ---
  static const int maxEnergy = 5;
  // For dev iteration: 1 point per minute. Bump up to 300 s (5 min)
  // for production.
  static const int energyRefillSeconds = 60;
  int _energy = maxEnergy;
  int get energy => _energy;
  bool get canLeaveTrain => _energy > 0;

  DateTime _lastRefillTick = DateTime.now();
  Timer? _refillTimer;

  void _tickRefill() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastRefillTick).inSeconds;
    final gained = elapsed ~/ energyRefillSeconds;
    if (gained <= 0) return;
    _lastRefillTick = now;
    final before = _energy;
    _energy = (_energy + gained).clamp(0, maxEnergy);
    if (_energy != before) notifyListeners();
  }

  void spendEnergy([int amount = 1]) {
    _energy = (_energy - amount).clamp(0, maxEnergy);
    notifyListeners();
  }

  void grantEnergy(int amount) {
    _energy = (_energy + amount).clamp(0, maxEnergy);
    notifyListeners();
  }

  // --- Survival bars (faim / soif / fatigue) ---
  // Toutes de 0.0 (vide / épuisé) à 1.0 (rassasié / reposé). Décroissent
  // lentement avec le temps ; restored par interactions (eat → +faim,
  // drink → +soif, sleep dans le lit → +fatigue).
  double _hunger = 1.0;
  double _thirst = 1.0;
  double _fatigue = 1.0;
  double get hunger => _hunger;
  double get thirst => _thirst;
  double get fatigue => _fatigue;

  // Décroissance par seconde réelle.
  static const double _hungerDrainPerSec = 1.0 / (60 * 30); // vide en 30 min
  static const double _thirstDrainPerSec = 1.0 / (60 * 20); // 20 min
  static const double _fatigueDrainPerSec = 1.0 / (60 * 45); // 45 min

  Timer? _drainTimer;
  DateTime _lastDrainTick = DateTime.now();

  void _tickDrain() {
    final now = DateTime.now();
    final dt = now.difference(_lastDrainTick).inSeconds.toDouble();
    if (dt <= 0) return;
    _lastDrainTick = now;
    final h0 = _hunger, t0 = _thirst, f0 = _fatigue;
    _hunger = (_hunger - _hungerDrainPerSec * dt).clamp(0.0, 1.0);
    _thirst = (_thirst - _thirstDrainPerSec * dt).clamp(0.0, 1.0);
    _fatigue = (_fatigue - _fatigueDrainPerSec * dt).clamp(0.0, 1.0);
    if (_hunger != h0 || _thirst != t0 || _fatigue != f0) {
      notifyListeners();
    }
  }

  void restoreHunger(double amount) {
    _hunger = (_hunger + amount).clamp(0.0, 1.0);
    notifyListeners();
  }

  void restoreThirst(double amount) {
    _thirst = (_thirst + amount).clamp(0.0, 1.0);
    notifyListeners();
  }

  void restoreFatigue(double amount) {
    _fatigue = (_fatigue + amount).clamp(0.0, 1.0);
    notifyListeners();
  }

  // --- Wagon ambient state ---
  bool _lampOn = true;
  bool get lampOn => _lampOn;
  void toggleLamp() {
    _lampOn = !_lampOn;
    notifyListeners();
  }

  // --- Météo --- (cycle automatique).
  Weather _weather = Weather.clear;
  Weather get weather => _weather;
  // Toutes les 30s pour l'instant (visualiser vite). Passer à plusieurs
  // minutes en prod pour un rythme atmosphérique plus calme.
  static const Duration _weatherPeriod = Duration(seconds: 30);
  Timer? _weatherTimer;
  void _initWeatherCycle() {
    _weatherTimer ??= Timer.periodic(_weatherPeriod, (_) {
      // Pick au hasard mais évite de répéter le même.
      final pool =
          Weather.values.where((w) => w != _weather).toList();
      _weather = pool[DateTime.now().millisecondsSinceEpoch % pool.length];
      notifyListeners();
    });
  }

  // --- Train route ---
  // Le train parcourt un circuit ovale en boucle. Position 0→1 qui
  // avance en continu. Zone froide = 0.00→0.40, tempérée = 0.45→0.95,
  // transitions entre les deux.
  static const int loopDurationSeconds = 3600; // 60 min pour un tour
  static const double _coldStart = 0.0;
  static const double _coldEnd = 0.40;
  static const double _transitionWidth = 0.05;

  double _trainPosition = 0.10; // départ en zone froide
  double get trainPosition => _trainPosition;
  Timer? _trainTimer;
  DateTime _lastTrainTick = DateTime.now();

  TrainZone get trainZone {
    final p = _trainPosition;
    // Zone froide pure
    if (p >= _coldStart + _transitionWidth && p < _coldEnd - _transitionWidth) {
      return TrainZone.cold;
    }
    // Transition entrée froid (chaud → froid)
    if (p >= 1.0 - _transitionWidth || p < _coldStart + _transitionWidth) {
      return TrainZone.transitionToCold;
    }
    // Transition sortie froid (froid → chaud)
    if (p >= _coldEnd - _transitionWidth && p < _coldEnd + _transitionWidth) {
      return TrainZone.transitionToWarm;
    }
    // Zone tempérée
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
    final advance = dt / loopDurationSeconds;
    final old = _trainPosition;
    _trainPosition = (_trainPosition + advance) % 1.0;
    final oldZone = _zoneFor(old);
    final newZone = trainZone;
    if (oldZone != newZone || (_trainPosition - old).abs() > 0.001) {
      notifyListeners();
    }
  }

  TrainZone _zoneFor(double p) {
    if (p >= _coldStart + _transitionWidth && p < _coldEnd - _transitionWidth) {
      return TrainZone.cold;
    }
    if (p >= 1.0 - _transitionWidth || p < _coldStart + _transitionWidth) {
      return TrainZone.transitionToCold;
    }
    if (p >= _coldEnd - _transitionWidth && p < _coldEnd + _transitionWidth) {
      return TrainZone.transitionToWarm;
    }
    return TrainZone.warm;
  }

  // --- Inventory ---
  // Loose typed: item id → count. Items granted by choices accumulate.
  final Map<String, int> _items = {};
  Map<String, int> get items => Map.unmodifiable(_items);

  void grantItem(String id, [int qty = 1]) {
    _items[id] = (_items[id] ?? 0) + qty;
    notifyListeners();
  }

  // --- Story flags ---
  // Choices set named flags that gate later content (unlock locations,
  // open new questions, change dialogue, etc.).
  final Set<String> _flags = {};
  Set<String> get flags => Set.unmodifiable(_flags);

  void setFlag(String flag) {
    if (_flags.add(flag)) notifyListeners();
  }

  bool hasFlag(String flag) => _flags.contains(flag);

  // --- Locations ---
  // Which world locations the player has unlocked. Maps to IDs from
  // [data/world.dart]. The first one is open by default.
  final Set<String> _unlocked = {'station_abandonnee'};
  Set<String> get unlockedLocations => Set.unmodifiable(_unlocked);

  void unlockLocation(String id) {
    if (_unlocked.add(id)) notifyListeners();
  }

  bool isLocationUnlocked(String id) => _unlocked.contains(id);

  @override
  void dispose() {
    _refillTimer?.cancel();
    _drainTimer?.cancel();
    _weatherTimer?.cancel();
    _trainTimer?.cancel();
    super.dispose();
  }
}

enum Weather { clear, cloudy, rainy, foggy }

enum TrainZone { cold, warm, transitionToCold, transitionToWarm }
