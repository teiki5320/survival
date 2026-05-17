import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// How an object should subtly animate while visible.
enum WagonAnimation { none, breathing, flickering, swaying }

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
    required this.background,
    required this.aspectRatio,
    required this.slots,
    required this.objects,
  });

  factory SceneConfig.fromJson(Map<String, dynamic> json) {
    final ratio = json['aspectRatio'] as List<dynamic>?;
    final w = ratio != null && ratio.length == 2 ? (ratio[0] as num).toDouble() : 2.0;
    final h = ratio != null && ratio.length == 2 ? (ratio[1] as num).toDouble() : 3.0;

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

    return SceneConfig(
      background: json['background'] as String,
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

  final String background;
  final double aspectRatio;
  final Map<String, SlotConfig> slots;
  final List<WagonObject> objects;

  SlotConfig slotFor(WagonObject object) => slots[object.slotId]!;
}
