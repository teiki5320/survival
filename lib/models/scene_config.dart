import 'dart:convert';

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

/// A named anchor on the wagon image where a single object can be placed.
///
/// Coordinates are normalized to the wagon's bounding box (0..1). [x] and [y]
/// describe the slot's center; [width] and [height] describe the rendered
/// object's size relative to the wagon.
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

class WagonObject {
  const WagonObject({
    required this.id,
    required this.label,
    required this.slotId,
    required this.asset,
    required this.animation,
  });

  factory WagonObject.fromJson(Map<String, dynamic> json) {
    return WagonObject(
      id: json['id'] as String,
      label: (json['label'] as String?) ?? json['id'] as String,
      slotId: json['slot'] as String,
      asset: json['asset'] as String,
      animation: _parseAnimation(json['animation'] as String?),
    );
  }

  final String id;
  final String label;
  final String slotId;
  final String asset;
  final WagonAnimation animation;
}

class SceneConfig {
  SceneConfig({
    required this.backgrounds,
    required this.defaultTime,
    required this.aspectRatio,
    required this.slots,
    required this.objects,
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

    return SceneConfig(
      backgrounds: backgrounds,
      defaultTime: _parseTime(json['defaultTimeOfDay'] as String?),
      aspectRatio: w / h,
      slots: slotsById,
      objects: objects,
    );
  }

  static Future<SceneConfig> load(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return SceneConfig.fromJson(decoded);
  }

  final Map<WagonTime, String> backgrounds;
  final WagonTime defaultTime;
  final double aspectRatio;
  final Map<String, SlotConfig> slots;
  final List<WagonObject> objects;

  String backgroundFor(WagonTime time) => backgrounds[time]!;

  SlotConfig slotFor(WagonObject object) => slots[object.slotId]!;
}
