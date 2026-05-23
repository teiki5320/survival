import 'package:flame/cache.dart';
import 'package:flame/sprite.dart';
import 'package:flame/widgets.dart';
import 'package:flutter/material.dart';

/// Pré-charge et garde en mémoire les SpriteAnimation de toutes les
/// anims du perso. Chaque anim = N PNG individuels dans
/// assets/characters/<prefix>_<i>.png.
///
/// Pourquoi un singleton : Flame.images est un cache global, mais on
/// veut un cache custom (prefix = assets/characters/) et on veut éviter
/// de re-créer les SpriteAnimation à chaque rebuild.
class HeroSpriteCache {
  HeroSpriteCache._();
  static final HeroSpriteCache instance = HeroSpriteCache._();

  final Images _images = Images(prefix: 'assets/characters/');
  final Map<String, SpriteAnimation> _anims = {};

  /// Pré-charge toutes les anims au démarrage. Idempotent : safe à
  /// appeler plusieurs fois.
  Future<void> preload({
    required Map<String, _AnimSpec> animations,
  }) async {
    for (final entry in animations.entries) {
      if (_anims.containsKey(entry.key)) continue;
      await _loadAnim(entry.key, entry.value);
    }
  }

  Future<void> _loadAnim(String prefix, _AnimSpec spec) async {
    // Loads en parallèle pour ne pas serializer le décodage.
    final imagesFut = <Future>[
      for (int i = 1; i <= spec.frameCount; i++)
        _images.load('${prefix}_$i.png'),
    ];
    final loaded = await Future.wait(imagesFut);
    final sprites = [for (final img in loaded) Sprite(img)];
    _anims[prefix] = SpriteAnimation.spriteList(
      sprites,
      stepTime: spec.frameDurationMs / 1000.0,
      loop: spec.loop,
    );
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

/// Specs des 13 anims du perso. À appeler une fois au démarrage de l'app
/// (depuis main.dart) pour pré-charger en background.
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

/// Widget qui joue une animation du perso. Switch d'anim sans rebuild
/// du widget (juste un swap de la SpriteAnimation).
///
/// Le rendu est piloté par Flame (pas par le ticker Dart de la scène),
/// donc le changement de prefix ne coûte rien — l'anim suivante est
/// déjà décodée et prête.
class HeroSprite extends StatefulWidget {
  const HeroSprite({
    super.key,
    required this.prefix,
    this.mirror = false,
    this.onComplete,
  });

  /// Nom de l'anim à jouer (ex: 'walk_right', 'warm_hands').
  final String prefix;

  /// Mirror horizontal (pour gauche vs droite).
  final bool mirror;

  /// Appelé quand une anim one-shot (loop=false) termine sa lecture.
  final VoidCallback? onComplete;

  @override
  State<HeroSprite> createState() => _HeroSpriteState();
}

class _HeroSpriteState extends State<HeroSprite> {
  SpriteAnimationTicker? _ticker;

  @override
  void initState() {
    super.initState();
    _bindAnim();
  }

  @override
  void didUpdateWidget(covariant HeroSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.prefix != widget.prefix) {
      _bindAnim();
    }
  }

  void _bindAnim() {
    final anim = HeroSpriteCache.instance.get(widget.prefix);
    if (anim == null) return;
    // Rewind: cloner le ticker pour repartir frame 0 à chaque switch
    // d'anim (sinon il continue à la position précédente).
    _ticker = anim.createTicker();
    if (widget.onComplete != null) {
      _ticker!.onComplete = widget.onComplete;
    }
  }

  @override
  Widget build(BuildContext context) {
    final anim = HeroSpriteCache.instance.get(widget.prefix);
    if (anim == null || _ticker == null) {
      return const SizedBox.shrink();
    }
    final child = SpriteAnimationWidget(
      animation: anim,
      animationTicker: _ticker,
    );
    if (!widget.mirror) return child;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
      child: child,
    );
  }
}
