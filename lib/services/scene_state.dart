import 'dart:async';
import 'dart:ui' show Offset, Rect;

import 'package:flutter/foundation.dart';

import '../models/scene_config.dart';
import '../widgets/cracked_glass.dart';
import 'audio_service.dart';

/// Identifier for one corner of the window editor.
enum WindowCorner { topLeft, topRight, bottomLeft, bottomRight }

/// Tracks scene runtime state: which objects are visible, which day/night
/// background is active, and for each character which pose / action is
/// currently active (with auto-cycling between idle poses or scripted
/// action sequences).
class SceneState extends ChangeNotifier {
  SceneState(this.config, {AudioService? audio})
      : _audio = audio,
        _time = config.defaultTime;

  final SceneConfig config;
  final AudioService? _audio;

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
  bool _editingWindow = false;
  Rect? _windowAreaOverride;
  CrackState? _windowCrack;
  int _nextCrackSeed = 1;
  bool _dust = true;
  bool _rain = false;

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

  // Dust particles drifting through the wagon.
  bool get isDustEnabled => _dust;
  void setDustEnabled(bool v) {
    if (_dust == v) return;
    _dust = v;
    notifyListeners();
  }

  // Rain on the window glass.
  bool get isRainEnabled => _rain;
  void setRainEnabled(bool v) {
    if (_rain == v) return;
    _rain = v;
    notifyListeners();
  }

  // Window area — overridable at runtime via the corner editor.
  /// Window rectangle currently in use. Either the runtime override (set by
  /// dragging corners) or the one declared in scene.json.
  Rect get effectiveWindowArea => _windowAreaOverride ?? config.windowArea;

  bool get isEditingWindow => _editingWindow;
  void setEditingWindow(bool editing) {
    if (_editingWindow == editing) return;
    _editingWindow = editing;
    if (editing) _windowAreaOverride ??= config.windowArea;
    notifyListeners();
  }

  /// Reset the override to whatever scene.json declares.
  void resetWindowArea() {
    if (_windowAreaOverride == null) return;
    _windowAreaOverride = null;
    notifyListeners();
  }

  // Cracked rear window.
  CrackState? get windowCrack => _windowCrack;

  /// Add or amplify cracks on the rear window. If [impactPoint] is null,
  /// uses the previous impact point or the center of the window. Each
  /// call bumps the seed so the reveal animation replays.
  void crackWindow({Offset? impactPoint, double intensity = 0.7}) {
    final point = impactPoint ??
        _windowCrack?.impactPoint ??
        const Offset(0.5, 0.45);
    _windowCrack = CrackState(
      intensity: intensity.clamp(0.0, 1.0),
      impactPoint: point,
      seed: _nextCrackSeed++,
    );
    notifyListeners();
  }

  /// Wipe all cracks on the rear window.
  void clearCracks() {
    if (_windowCrack == null) return;
    _windowCrack = null;
    notifyListeners();
  }

  /// Drag one corner by a normalized delta (relative to the wagon box).
  /// Width and height are clamped to a minimum of 5% so the rect can't
  /// collapse, and coordinates are clamped to [0, 1].
  void dragWindowCorner(WindowCorner corner, double dxNorm, double dyNorm) {
    final rect = effectiveWindowArea;
    double left = rect.left;
    double top = rect.top;
    double right = rect.right;
    double bottom = rect.bottom;

    switch (corner) {
      case WindowCorner.topLeft:
        left = (left + dxNorm).clamp(0.0, right - 0.05);
        top = (top + dyNorm).clamp(0.0, bottom - 0.05);
      case WindowCorner.topRight:
        right = (right + dxNorm).clamp(left + 0.05, 1.0);
        top = (top + dyNorm).clamp(0.0, bottom - 0.05);
      case WindowCorner.bottomLeft:
        left = (left + dxNorm).clamp(0.0, right - 0.05);
        bottom = (bottom + dyNorm).clamp(top + 0.05, 1.0);
      case WindowCorner.bottomRight:
        right = (right + dxNorm).clamp(left + 0.05, 1.0);
        bottom = (bottom + dyNorm).clamp(top + 0.05, 1.0);
    }

    _windowAreaOverride = Rect.fromLTRB(left, top, right, bottom);
    notifyListeners();
  }

  void setTime(WagonTime time) {
    if (_time == time) return;
    _time = time;
    _audio?.playMusicFor(time);
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

    _audio?.playSfxForObject(object.id);

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
