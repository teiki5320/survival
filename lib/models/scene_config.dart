import 'dart:convert';
import 'dart:ui' show Rect;

import 'package:flutter/services.dart' show rootBundle;

/// How an object should subtly animate while visible.
enum WagonAnimation { none, breathing, flickering, swaying }

/// Time-of-day variants the wagon background can render. Day and night are
/// loaded from distinct asset paths; SceneState toggles between them.
enum WagonTime { day, night }

WagonAnimation _parseAnimation(String? raw) {
  switch (raw) {
    case 'breathing':
      return WagonAnimation.breathing;
    case 'flickering':
      return WagonAnimation.flickering;
    case 'swaying':
      return WagonAnimation.swaying;
    case null:
    case '':
    case 'none':
      return WagonAnimation.none;
    default:
      throw FormatException('Unknown animation type: $raw');
  }
}

WagonTime _parseTime(String? raw) {
  switch (raw) {
    case 'night':
      return WagonTime.night;
    case null:
    case '':
    case 'day':
      return WagonTime.day;
    default:
      throw FormatException('Unknown time of day: $raw');
  }
}

/// A named anchor on the wagon image where a single asset can be placed.
///
/// Coordinates are normalized to the wagon's bounding box (0..1). [x] and [y]
/// describe the slot's center; [width] and [height] describe the rendered
/// asset's size relative to the wagon.
class SlotConfig {
  const SlotConfig({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory SlotConfig.fromJson(Map<String, dynamic> json) {
    return SlotConfig(
      id: json['id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
    );
  }

  final String id;
  final double x;
  final double y;
  final double width;
  final double height;
}

/// What happens when the player taps a wagon object: either snap the
/// character into a specific pose, or kick off a scripted action.
enum InteractionKind { pose, action }

class ObjectInteraction {
  const ObjectInteraction({required this.kind, required this.target});

  factory ObjectInteraction.fromJson(Map<String, dynamic> json) {
    final raw = (json['kind'] as String?) ?? 'pose';
    final kind = raw == 'action' ? InteractionKind.action : InteractionKind.pose;
    return ObjectInteraction(
      kind: kind,
      target: json['target'] as String,
    );
  }

  final InteractionKind kind;
  final String target;
}

class WagonObject {
  const WagonObject({
    required this.id,
    required this.label,
    required this.slotId,
    required this.asset,
    required this.animation,
    required this.interaction,
  });

  factory WagonObject.fromJson(Map<String, dynamic> json) {
    final rawInteraction = json['interaction'] as Map<String, dynamic>?;
    return WagonObject(
      id: json['id'] as String,
      label: (json['label'] as String?) ?? json['id'] as String,
      slotId: json['slot'] as String,
      asset: json['asset'] as String,
      animation: _parseAnimation(json['animation'] as String?),
      interaction:
          rawInteraction == null ? null : ObjectInteraction.fromJson(rawInteraction),
    );
  }

  final String id;
  final String label;
  final String slotId;
  final String asset;
  final WagonAnimation animation;
  final ObjectInteraction? interaction;
}

/// One frame of a character: an asset rendered at a specific slot in the
/// wagon. Cycling the active pose makes the character "move" between spots.
class CharacterPose {
  const CharacterPose({
    required this.id,
    required this.label,
    required this.asset,
    required this.slotId,
  });

  factory CharacterPose.fromJson(Map<String, dynamic> json) {
    return CharacterPose(
      id: json['id'] as String,
      label: (json['label'] as String?) ?? json['id'] as String,
      asset: json['asset'] as String,
      slotId: json['slot'] as String,
    );
  }

  final String id;
  final String label;
  final String asset;
  final String slotId;
}

/// One step of a scripted action: hold a specific pose for [durationMs] ms,
/// then move on to the next frame. The slide between frames is handled by
/// CharacterDisplay so each frame just declares which pose to stop at.
class ActionFrame {
  const ActionFrame({required this.poseId, required this.durationMs});

  factory ActionFrame.fromJson(Map<String, dynamic> json) {
    return ActionFrame(
      poseId: json['poseId'] as String,
      durationMs: (json['durationMs'] as num).toInt(),
    );
  }

  final String poseId;
  final int durationMs;
}

/// A named scripted sequence of poses — "go look outside", "wake up and
/// stretch", etc. Actions interrupt the auto-cycle and resume it when done
/// (unless [loop] is true).
class CharacterAction {
  const CharacterAction({
    required this.id,
    required this.label,
    required this.frames,
    required this.loop,
  });

  factory CharacterAction.fromJson(Map<String, dynamic> json) {
    final frames = (json['frames'] as List<dynamic>)
        .map((f) => ActionFrame.fromJson(f as Map<String, dynamic>))
        .toList(growable: false);
    if (frames.isEmpty) {
      throw FormatException('Action "${json['id']}" must declare at least one frame.');
    }
    return CharacterAction(
      id: json['id'] as String,
      label: (json['label'] as String?) ?? json['id'] as String,
      frames: frames,
      loop: (json['loop'] as bool?) ?? false,
    );
  }

  final String id;
  final String label;
  final List<ActionFrame> frames;
  final bool loop;
}

class CharacterConfig {
  const CharacterConfig({
    required this.id,
    required this.label,
    required this.cycleSeconds,
    required this.poses,
    required this.actions,
  });

  factory CharacterConfig.fromJson(Map<String, dynamic> json) {
    final poses = (json['poses'] as List<dynamic>)
        .map((p) => CharacterPose.fromJson(p as Map<String, dynamic>))
        .toList(growable: false);
    if (poses.isEmpty) {
      throw FormatException('Character "${json['id']}" must define at least one pose.');
    }
    final poseIds = {for (final p in poses) p.id};

    final actions = ((json['actions'] as List<dynamic>?) ?? const [])
        .map((a) => CharacterAction.fromJson(a as Map<String, dynamic>))
        .toList(growable: false);
    for (final action in actions) {
      for (final frame in action.frames) {
        if (!poseIds.contains(frame.poseId)) {
          throw FormatException(
            'Action "${action.id}" references unknown pose "${frame.poseId}".',
          );
        }
      }
    }

    return CharacterConfig(
      id: json['id'] as String,
      label: (json['label'] as String?) ?? json['id'] as String,
      cycleSeconds: (json['cycleSeconds'] as num?)?.toInt() ?? 8,
      poses: poses,
      actions: actions,
    );
  }

  final String id;
  final String label;
  final int cycleSeconds;
  final List<CharacterPose> poses;
  final List<CharacterAction> actions;

  CharacterPose poseById(String poseId) =>
      poses.firstWhere((p) => p.id == poseId);
}

class SceneConfig {
  SceneConfig({
    required this.backgrounds,
    required this.landscapes,
    required this.defaultTime,
    required this.aspectRatio,
    required this.slots,
    required this.objects,
    required this.characters,
    required this.windowArea,
    required this.windowCornerRadius,
  });

  factory SceneConfig.fromJson(Map<String, dynamic> json) {
    final ratio = json['aspectRatio'] as List<dynamic>?;
    final w = ratio != null && ratio.length == 2 ? (ratio[0] as num).toDouble() : 16.0;
    final h = ratio != null && ratio.length == 2 ? (ratio[1] as num).toDouble() : 9.0;

    final slots = (json['slots'] as List<dynamic>)
        .map((s) => SlotConfig.fromJson(s as Map<String, dynamic>))
        .toList(growable: false);
    final slotsById = {for (final s in slots) s.id: s};

    final objects = (json['objects'] as List<dynamic>)
        .map((o) => WagonObject.fromJson(o as Map<String, dynamic>))
        .toList(growable: false);
    for (final o in objects) {
      if (!slotsById.containsKey(o.slotId)) {
        throw FormatException(
          'Object "${o.id}" references unknown slot "${o.slotId}".',
        );
      }
    }

    final characters = ((json['characters'] as List<dynamic>?) ?? const [])
        .map((c) => CharacterConfig.fromJson(c as Map<String, dynamic>))
        .toList(growable: false);
    for (final char in characters) {
      for (final pose in char.poses) {
        if (!slotsById.containsKey(pose.slotId)) {
          throw FormatException(
            'Character "${char.id}" pose "${pose.id}" references unknown slot "${pose.slotId}".',
          );
        }
      }
    }

    final rawBackgrounds = json['backgrounds'] as Map<String, dynamic>?;
    if (rawBackgrounds == null) {
      throw const FormatException(
        'scene.json must define a "backgrounds" map with "day" and "night" keys.',
      );
    }
    final backgrounds = <WagonTime, String>{};
    for (final entry in rawBackgrounds.entries) {
      backgrounds[_parseTime(entry.key)] = entry.value as String;
    }
    if (!backgrounds.containsKey(WagonTime.day) ||
        !backgrounds.containsKey(WagonTime.night)) {
      throw const FormatException(
        'scene.json backgrounds must define both "day" and "night".',
      );
    }

    final rawLandscapes = json['landscapes'] as Map<String, dynamic>?;
    final landscapes = <WagonTime, String>{};
    if (rawLandscapes != null) {
      for (final entry in rawLandscapes.entries) {
        landscapes[_parseTime(entry.key)] = entry.value as String;
      }
    }

    Rect parsedWindowArea =
        const Rect.fromLTWH(0.41, 0.20, 0.18, 0.35);
    double parsedCornerRadius = 0.0;
    final rawWindow = json['windowArea'] as Map<String, dynamic>?;
    if (rawWindow != null) {
      parsedWindowArea = Rect.fromLTWH(
        (rawWindow['x'] as num).toDouble(),
        (rawWindow['y'] as num).toDouble(),
        (rawWindow['width'] as num).toDouble(),
        (rawWindow['height'] as num).toDouble(),
      );
      parsedCornerRadius =
          (rawWindow['cornerRadius'] as num?)?.toDouble() ?? 0.0;
    }

    return SceneConfig(
      backgrounds: backgrounds,
      landscapes: landscapes,
      defaultTime: _parseTime(json['defaultTimeOfDay'] as String?),
      aspectRatio: w / h,
      slots: slotsById,
      objects: objects,
      characters: characters,
      windowArea: parsedWindowArea,
      windowCornerRadius: parsedCornerRadius,
    );
  }

  static Future<SceneConfig> load(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return SceneConfig.fromJson(decoded);
  }

  final Map<WagonTime, String> backgrounds;

  /// Optional scrolling landscape per time-of-day, rendered behind the
  /// wagon's cut-out rear window. Empty map disables the landscape layer.
  final Map<WagonTime, String> landscapes;

  final WagonTime defaultTime;
  final double aspectRatio;
  final Map<String, SlotConfig> slots;
  final List<WagonObject> objects;
  final List<CharacterConfig> characters;

  /// Rear-window glass area in normalized 0..1 coordinates, used by the
  /// parallax overlay to know where to draw scrolling silhouettes.
  final Rect windowArea;

  /// Corner radius applied to the rear-window area, normalized to the
  /// wagon's smaller side. Use a small value (e.g. 0.015–0.025) to round
  /// the corners just enough to match the real window curve.
  final double windowCornerRadius;

  String? landscapeFor(WagonTime time) => landscapes[time];

  String backgroundFor(WagonTime time) => backgrounds[time]!;

  SlotConfig slotFor(WagonObject object) => slots[object.slotId]!;
  SlotConfig slotForPose(CharacterPose pose) => slots[pose.slotId]!;
}
