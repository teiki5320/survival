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
  Set<String> _unlocked = {'station_abandonnee'};
  Set<String> get unlockedLocations => Set.unmodifiable(_unlocked);

  void unlockLocation(String id) {
    if (_unlocked.add(id)) notifyListeners();
  }

  bool isLocationUnlocked(String id) => _unlocked.contains(id);

  @override
  void dispose() {
    _refillTimer?.cancel();
    super.dispose();
  }
}
