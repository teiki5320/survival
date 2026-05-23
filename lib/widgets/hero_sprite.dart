import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/sprite.dart';
import 'package:flame/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pré-charge et garde en mémoire les SpriteAnimation de toutes les
/// anims du perso. Les images sont décodées via rootBundle (Flutter
/// natif) pour éviter toute dépendance sur l'API Images de Flame.
class HeroSpriteCache {
  HeroSpriteCache._();
  static final HeroSpriteCache instance = HeroSpriteCache._();

  final Map<String, SpriteAnimation> _anims = {};

  Future<void> preload({
    required Map<String, _AnimSpec> animations,
  }) async {
    for (final entry in animations.entries) {
      if (_anims.containsKey(entry.key)) continue;
      await _loadAnim(entry.key, entry.value);
    }
  }

  Future<void> _loadAnim(String prefix, _AnimSpec spec) async {
    final futures = <Future<ui.Image>>[
      for (int i = 1; i <= spec.frameCount; i++)
        _loadAsset('assets/characters/${prefix}_$i.png'),
    ];
    final images = await Future.wait(futures);
    final sprites = [for (final img in images) Sprite(img)];
    _anims[prefix] = SpriteAnimation.spriteList(
      sprites,
      stepTime: spec.frameDurationMs / 1000.0,
      loop: spec.loop,
    );
  }

  Future<ui.Image> _loadAsset(String path) async {
    final ByteData data = await rootBundle.load(path);
    final Uint8List bytes = data.buffer.asUint8List();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    return frame.image;
  }

  SpriteAnimation? get(String prefix) => _anims[prefix];
}

class _AnimSpec {
  const _AnimSpec({
    required this.frameCount,
    required this.frameDurationMs,
    this.loop = true,
  });
  final int frameCount;
  final double frameDurationMs;
  final bool loop;
}

Map<String, _AnimSpec> defaultHeroAnimSpecs() => const {
      'walk_right':  _AnimSpec(frameCount: 49, frameDurationMs: 50),
      'idle_right':  _AnimSpec(frameCount: 49, frameDurationMs: 80),
      'sleep_right': _AnimSpec(frameCount: 49, frameDurationMs: 110),
      'dance':       _AnimSpec(frameCount: 49, frameDurationMs: 55),
      'pickup':      _AnimSpec(frameCount: 49, frameDurationMs: 60, loop: false),
      'yawn':        _AnimSpec(frameCount: 49, frameDurationMs: 65, loop: false),
      'stretch':     _AnimSpec(frameCount: 49, frameDurationMs: 55, loop: false),
      'look_window': _AnimSpec(frameCount: 49, frameDurationMs: 65, loop: false),
      'read':        _AnimSpec(frameCount: 49, frameDurationMs: 80),
      'wake_up':     _AnimSpec(frameCount: 49, frameDurationMs: 55, loop: false),
      'door_push':   _AnimSpec(frameCount: 49, frameDurationMs: 40, loop: false),
      'warm_hands':  _AnimSpec(frameCount: 49, frameDurationMs: 80),
      'carry_walk':  _AnimSpec(frameCount: 49, frameDurationMs: 50),
    };

Future<void> preloadHeroSprites() =>
    HeroSpriteCache.instance.preload(animations: defaultHeroAnimSpecs());

/// Widget qui joue une animation du perso. Si l'anim n'est pas encore
/// chargée, rend un SizedBox vide (le preload est lancé depuis main).
///
/// La key sur SpriteAnimationWidget force la recréation du ticker
/// interne quand prefix change → l'anim repart frame 0.
class HeroSprite extends StatelessWidget {
  const HeroSprite({
    super.key,
    required this.prefix,
    this.mirror = false,
  });

  final String prefix;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    final anim = HeroSpriteCache.instance.get(prefix);
    if (anim == null) return const SizedBox.shrink();
    Widget child = SpriteAnimationWidget(
      animation: anim,
      key: ValueKey(prefix),
    );
    if (mirror) {
      child = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
        child: child,
      );
    }
    return child;
  }
}
