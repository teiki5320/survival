import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../constants.dart';

class GameState extends ChangeNotifier {
  GameState._() {
    _refillTimer = Timer.periodic(
      Duration(seconds: kEnergyRefillSeconds),
      (_) => _tickRefill(),
    );
    _drainTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _tickDrain(),
    );
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
        'energy': _energy,
        'hunger': _hunger,
        'thirst': _thirst,
        'fatigue': _fatigue,
        'lampOn': _lampOn,
        'trainPosition': _trainPosition,
        'items': _items,
        'flags': _flags.toList(),
        'unlocked': _unlocked.toList(),
        'wagonStage': wagonStage,
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
      _energy = (data['energy'] as num?)?.toInt() ?? kMaxEnergy;
      _hunger = (data['hunger'] as num?)?.toDouble() ?? 1.0;
      _thirst = (data['thirst'] as num?)?.toDouble() ?? 1.0;
      _fatigue = (data['fatigue'] as num?)?.toDouble() ?? 1.0;
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
      notifyListeners();
    } catch (_) {}
  }

  int _saveCounter = 0;
  void _autoSave() {
    _saveCounter++;
    if (_saveCounter % 30 == 0) save();
  }

  // --- Energy ---
  int _energy = kMaxEnergy;
  int get energy => _energy;
  bool get canLeaveTrain => _energy > 0;

  DateTime _lastRefillTick = DateTime.now();
  Timer? _refillTimer;

  void _tickRefill() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastRefillTick).inSeconds;
    final gained = elapsed ~/ kEnergyRefillSeconds;
    if (gained <= 0) return;
    _lastRefillTick = now;
    final before = _energy;
    _energy = (_energy + gained).clamp(0, kMaxEnergy);
    if (_energy != before) notifyListeners();
  }

  void spendEnergy([int amount = 1]) {
    _energy = (_energy - amount).clamp(0, kMaxEnergy);
    notifyListeners();
    save();
  }

  void grantEnergy(int amount) {
    _energy = (_energy + amount).clamp(0, kMaxEnergy);
    notifyListeners();
  }

  // --- Survival bars ---
  double _hunger = 1.0;
  double _thirst = 1.0;
  double _fatigue = 1.0;
  double get hunger => _hunger;
  double get thirst => _thirst;
  double get fatigue => _fatigue;

  static final double _hungerDrainPerSec = 1.0 / kHungerFullDrainSeconds;
  static final double _thirstDrainPerSec = 1.0 / kThirstFullDrainSeconds;
  static final double _fatigueDrainPerSec = 1.0 / kFatigueFullDrainSeconds;

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
      _autoSave();
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

  // --- Wagon state ---
  bool _lampOn = true;
  bool get lampOn => _lampOn;
  void toggleLamp() {
    _lampOn = !_lampOn;
    notifyListeners();
    save();
  }

  int wagonStage = 0;

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
    if (_hunger < 0.2) return '🍖';
    if (_thirst < 0.2) return '💧';
    if (_fatigue < 0.15) return '💤';
    if (inColdZone) return '❄️';
    const neutral = ['☕', '💭', '🌿', '📖', '🎵'];
    return neutral[DateTime.now().second % neutral.length];
  }

  // --- Inventory ---
  final Map<String, int> _items = {};
  Map<String, int> get items => Map.unmodifiable(_items);

  void grantItem(String id, [int qty = 1]) {
    _items[id] = (_items[id] ?? 0) + qty;
    notifyListeners();
    save();
  }

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
    _refillTimer?.cancel();
    _drainTimer?.cancel();
    _weatherTimer?.cancel();
    _trainTimer?.cancel();
    super.dispose();
  }
}

enum Weather { clear, cloudy, rainy, foggy, snowy }

enum TrainZone { cold, warm, transitionToCold, transitionToWarm }
