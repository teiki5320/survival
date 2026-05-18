import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/scene_config.dart';

/// Tracks scene runtime state: which objects are visible, which day/night
/// background is active, and for each character which pose is currently
/// rendered (with optional auto-cycling).
class SceneState extends ChangeNotifier {
  SceneState(this.config) : _time = config.defaultTime;

  final SceneConfig config;

  final Set<String> _visible = <String>{};
  WagonTime _time;

  final Set<String> _visibleCharacters = <String>{};
  final Map<String, int> _characterPoseIndex = {};
  final Map<String, int?> _characterManualPose = {};
  final Map<String, Timer> _characterTimers = {};

  // Time of day
  WagonTime get time => _time;
  bool get isNight => _time == WagonTime.night;

  void setTime(WagonTime time) {
    if (_time == time) return;
    _time = time;
    notifyListeners();
  }

  void toggleTime() =>
      setTime(_time == WagonTime.day ? WagonTime.night : WagonTime.day);

  // Objects
  bool isVisible(String objectId) => _visible.contains(objectId);

  void setVisible(String objectId, bool visible) {
    final changed = visible ? _visible.add(objectId) : _visible.remove(objectId);
    if (changed) notifyListeners();
  }

  void toggle(String objectId) => setVisible(objectId, !isVisible(objectId));

  void hideAll() {
    var changed = _visible.isNotEmpty;
    _visible.clear();
    if (_visibleCharacters.isNotEmpty) {
      for (final id in _visibleCharacters.toList()) {
        _stopTimer(id);
      }
      _visibleCharacters.clear();
      changed = true;
    }
    if (changed) notifyListeners();
  }

  // Characters
  bool isCharacterVisible(String id) => _visibleCharacters.contains(id);

  /// Whether the user has pinned the character to a specific pose
  /// (auto-cycle disabled).
  bool isPoseManuallyPinned(String charId) =>
      _characterManualPose[charId] != null;

  /// Index of the pose currently being rendered for the given character —
  /// manual pin if any, otherwise the auto-cycle position.
  int currentPoseIndex(String charId) =>
      _characterManualPose[charId] ?? _characterPoseIndex[charId] ?? 0;

  CharacterPose currentPose(CharacterConfig char) {
    final index = currentPoseIndex(char.id) % char.poses.length;
    return char.poses[index];
  }

  void setCharacterVisible(String id, bool visible) {
    if (visible) {
      if (!_visibleCharacters.add(id)) return;
      _characterPoseIndex.putIfAbsent(id, () => 0);
      _startTimer(id);
    } else {
      if (!_visibleCharacters.remove(id)) return;
      _stopTimer(id);
    }
    notifyListeners();
  }

  /// Pin the character to a specific pose (auto-cycle off), or pass null to
  /// resume auto-cycling.
  void setManualPose(String charId, int? poseIndex) {
    _characterManualPose[charId] = poseIndex;
    if (poseIndex != null) {
      _characterPoseIndex[charId] = poseIndex;
      _stopTimer(charId);
    } else if (_visibleCharacters.contains(charId)) {
      _startTimer(charId);
    }
    notifyListeners();
  }

  void _startTimer(String charId) {
    _stopTimer(charId);
    if (_characterManualPose[charId] != null) return;
    final char = config.characters.firstWhere((c) => c.id == charId);
    _characterTimers[charId] = Timer.periodic(
      Duration(seconds: char.cycleSeconds),
      (_) {
        final current = _characterPoseIndex[charId] ?? 0;
        _characterPoseIndex[charId] = (current + 1) % char.poses.length;
        notifyListeners();
      },
    );
  }

  void _stopTimer(String charId) {
    _characterTimers.remove(charId)?.cancel();
  }

  @override
  void dispose() {
    for (final timer in _characterTimers.values) {
      timer.cancel();
    }
    _characterTimers.clear();
    super.dispose();
  }
}
