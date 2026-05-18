import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/scene_config.dart';

/// Tracks scene runtime state: which objects are visible, which day/night
/// background is active, and for each character which pose / action is
/// currently active (with auto-cycling between idle poses or scripted
/// action sequences).
class SceneState extends ChangeNotifier {
  SceneState(this.config) : _time = config.defaultTime;

  final SceneConfig config;

  final Set<String> _visible = <String>{};
  WagonTime _time;

  final Set<String> _visibleCharacters = <String>{};
  final Map<String, int> _characterPoseIndex = {};
  final Map<String, int?> _characterManualPose = {};
  final Map<String, Timer> _characterTimers = {};

  // Action playback state.
  final Map<String, CharacterAction> _activeActions = {};
  final Map<String, int> _activeActionFrame = {};
  final Map<String, Timer> _actionTimers = {};

  bool _rocking = true;
  bool _parallax = true;

  // Time of day
  WagonTime get time => _time;
  bool get isNight => _time == WagonTime.night;

  // Train rocking
  bool get isRocking => _rocking;
  void setRocking(bool rocking) {
    if (_rocking == rocking) return;
    _rocking = rocking;
    notifyListeners();
  }

  // Window parallax
  bool get isParallax => _parallax;
  void setParallax(bool parallax) {
    if (_parallax == parallax) return;
    _parallax = parallax;
    notifyListeners();
  }

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
        _stopCycleTimer(id);
        _stopAction(id);
      }
      _visibleCharacters.clear();
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Player tapped an object in the wagon. If the object has an interaction
  /// defined, route it to the first available character: a pose interaction
  /// pins the character to that pose, an action interaction plays the
  /// scripted sequence. The character is auto-shown if hidden so the tap
  /// always produces a visible response.
  void interactWith(WagonObject object) {
    final interaction = object.interaction;
    if (interaction == null) return;
    if (config.characters.isEmpty) return;
    final char = config.characters.first;

    if (!isCharacterVisible(char.id)) {
      setCharacterVisible(char.id, true);
    }

    switch (interaction.kind) {
      case InteractionKind.action:
        playAction(char.id, interaction.target);
      case InteractionKind.pose:
        final poseIndex =
            char.poses.indexWhere((p) => p.id == interaction.target);
        if (poseIndex >= 0) setManualPose(char.id, poseIndex);
    }
  }

  // Characters
  bool isCharacterVisible(String id) => _visibleCharacters.contains(id);

  bool isPoseManuallyPinned(String charId) =>
      _characterManualPose[charId] != null;

  int currentPoseIndex(String charId) =>
      _characterManualPose[charId] ?? _characterPoseIndex[charId] ?? 0;

  /// Pose currently being rendered for the character: the active action
  /// frame's pose if an action is playing, the manual pin if any, otherwise
  /// the auto-cycle's current pose.
  CharacterPose currentPose(CharacterConfig char) {
    final action = _activeActions[char.id];
    if (action != null) {
      final frameIndex = _activeActionFrame[char.id] ?? 0;
      final poseId = action.frames[frameIndex].poseId;
      return char.poseById(poseId);
    }
    final index = currentPoseIndex(char.id) % char.poses.length;
    return char.poses[index];
  }

  bool isActionPlaying(String charId) => _activeActions.containsKey(charId);
  CharacterAction? activeAction(String charId) => _activeActions[charId];
  int activeActionFrame(String charId) => _activeActionFrame[charId] ?? 0;

  void setCharacterVisible(String id, bool visible) {
    if (visible) {
      if (!_visibleCharacters.add(id)) return;
      _characterPoseIndex.putIfAbsent(id, () => 0);
      _startCycleTimer(id);
    } else {
      if (!_visibleCharacters.remove(id)) return;
      _stopCycleTimer(id);
      _stopAction(id);
    }
    notifyListeners();
  }

  /// Pin the character to a specific pose (auto-cycle and any active action
  /// are interrupted), or pass null to resume auto-cycling.
  void setManualPose(String charId, int? poseIndex) {
    _stopAction(charId);
    _characterManualPose[charId] = poseIndex;
    if (poseIndex != null) {
      _characterPoseIndex[charId] = poseIndex;
      _stopCycleTimer(charId);
    } else if (_visibleCharacters.contains(charId)) {
      _startCycleTimer(charId);
    }
    notifyListeners();
  }

  void playAction(String charId, String actionId) {
    if (!_visibleCharacters.contains(charId)) {
      setCharacterVisible(charId, true);
    }
    final char = config.characters.firstWhere((c) => c.id == charId);
    final action = char.actions.firstWhere((a) => a.id == actionId);
    _characterManualPose.remove(charId);
    _stopCycleTimer(charId);
    _stopActionTimer(charId);
    _activeActions[charId] = action;
    _activeActionFrame[charId] = 0;
    _scheduleNextActionFrame(charId);
    notifyListeners();
  }

  void stopAction(String charId) {
    if (!_activeActions.containsKey(charId)) return;
    final char = config.characters.firstWhere((c) => c.id == charId);
    final lastFrame = _activeActionFrame[charId] ?? 0;
    final lastPoseId = _activeActions[charId]!.frames[lastFrame].poseId;
    _stopAction(charId);
    // Snap the auto-cycle index to whichever pose she finished on so the
    // resume doesn't feel like a hard cut back.
    final resumeIndex =
        char.poses.indexWhere((p) => p.id == lastPoseId).clamp(0, char.poses.length - 1);
    _characterPoseIndex[charId] = resumeIndex;
    if (_visibleCharacters.contains(charId) &&
        _characterManualPose[charId] == null) {
      _startCycleTimer(charId);
    }
    notifyListeners();
  }

  void _scheduleNextActionFrame(String charId) {
    final action = _activeActions[charId];
    if (action == null) return;
    final index = _activeActionFrame[charId] ?? 0;
    final frame = action.frames[index];
    _actionTimers[charId] = Timer(Duration(milliseconds: frame.durationMs), () {
      final next = index + 1;
      if (next < action.frames.length) {
        _activeActionFrame[charId] = next;
        _scheduleNextActionFrame(charId);
        notifyListeners();
      } else if (action.loop) {
        _activeActionFrame[charId] = 0;
        _scheduleNextActionFrame(charId);
        notifyListeners();
      } else {
        // Natural end: stop the action and resume cycling.
        stopAction(charId);
      }
    });
  }

  void _stopAction(String charId) {
    _activeActions.remove(charId);
    _activeActionFrame.remove(charId);
    _stopActionTimer(charId);
  }

  void _stopActionTimer(String charId) {
    _actionTimers.remove(charId)?.cancel();
  }

  void _startCycleTimer(String charId) {
    _stopCycleTimer(charId);
    if (_characterManualPose[charId] != null) return;
    if (_activeActions.containsKey(charId)) return;
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

  void _stopCycleTimer(String charId) {
    _characterTimers.remove(charId)?.cancel();
  }

  @override
  void dispose() {
    for (final timer in _characterTimers.values) {
      timer.cancel();
    }
    for (final timer in _actionTimers.values) {
      timer.cancel();
    }
    _characterTimers.clear();
    _actionTimers.clear();
    super.dispose();
  }
}
