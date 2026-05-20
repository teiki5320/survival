import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/scene_config.dart';

/// Wraps a child with a looping animation. Older entries (`breathing`,
/// `flickering`, `swaying`) only transform the child itself. Newer entries
/// (`fireGlow`, `lampGlow`, `bubbling`) overlay procedurally-painted
/// effects (glow halos, embers, bubbles) around or in front of the child
/// so the object reads as actively *doing something* rather than just
/// pulsing in opacity.
class AnimatedObject extends StatefulWidget {
  const AnimatedObject({
    super.key,
    required this.animation,
    required this.child,
  });

  final WagonAnimation animation;
  final Widget child;

  @override
  State<AnimatedObject> createState() => _AnimatedObjectState();
}

class _AnimatedObjectState extends State<AnimatedObject>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  @override
  void didUpdateWidget(covariant AnimatedObject oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      _controller?.dispose();
      _controller = null;
      _setupController();
    }
  }

  void _setupController() {
    if (widget.animation == WagonAnimation.none) return;
    _controller = AnimationController(
      vsync: this,
      // A long base duration is fine — each animation drives multiple
      // sub-effects at different frequencies derived from `t`.
      duration: switch (widget.animation) {
        WagonAnimation.breathing => const Duration(milliseconds: 3200),
        WagonAnimation.flickering => const Duration(milliseconds: 1800),
        WagonAnimation.swaying => const Duration(milliseconds: 4200),
        WagonAnimation.fireGlow => const Duration(milliseconds: 2400),
        WagonAnimation.lampGlow => const Duration(milliseconds: 3000),
        WagonAnimation.bubbling => const Duration(milliseconds: 5000),
        WagonAnimation.none => const Duration(seconds: 1),
      },
    )..repeat();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return widget.child;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = controller.value;
        switch (widget.animation) {
          case WagonAnimation.breathing:
            final scale = 1.0 + 0.03 * math.sin(t * 2 * math.pi);
            return Transform.scale(scale: scale, child: child);
          case WagonAnimation.flickering:
            final base = 0.89 + 0.11 * math.sin(t * 2 * math.pi);
            final jitter = 0.04 * math.sin(t * 2 * math.pi * 5);
            return Opacity(opacity: (base + jitter).clamp(0.0, 1.0), child: child);
          case WagonAnimation.swaying:
            final dx = 6 * math.sin(t * 2 * math.pi);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          case WagonAnimation.fireGlow:
            return _withOverlay(
              behind: _FireGlowPainter(t: t),
              child: child!,
              front: _EmberPainter(t: t),
            );
          case WagonAnimation.lampGlow:
            return _withOverlay(
              behind: _LampGlowPainter(t: t),
              child: child!,
            );
          case WagonAnimation.bubbling:
            return _withOverlay(
              child: child!,
              front: _BubblePainter(t: t),
            );
          case WagonAnimation.none:
            return child!;
        }
      },
      child: widget.child,
    );
  }

  Widget _withOverlay({
    CustomPainter? behind,
    required Widget child,
    CustomPainter? front,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (behind != null)
          Positioned.fill(child: CustomPaint(painter: behind)),
        child,
        if (front != null)
          Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: front))),
      ],
    );
  }
}

/// Warm orange halo that pulses behind the stove, brightest near the
/// firebox door (lower-center of the bounding box).
class _FireGlowPainter extends CustomPainter {
  _FireGlowPainter({required this.t});
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // Two beats: slow pulse + tiny rapid jitter so the fire never sits still.
    final pulse = 0.6 + 0.25 * math.sin(t * 2 * math.pi);
    final jitter = 0.05 * math.sin(t * 2 * math.pi * 7);
    final intensity = (pulse + jitter).clamp(0.0, 1.0);

    // The firebox sits near the bottom-center of the stove sprite.
    final center = Offset(size.width * 0.5, size.height * 0.62);
    final maxRadius = math.max(size.width, size.height) * 0.75;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFC067).withOpacity(0.55 * intensity),
          const Color(0xFFFF8A2A).withOpacity(0.30 * intensity),
          const Color(0xFFFF6A1F).withOpacity(0.10 * intensity),
          const Color(0x00000000),
        ],
        stops: const [0.0, 0.35, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));
    canvas.drawCircle(center, maxRadius, paint);
  }

  @override
  bool shouldRepaint(covariant _FireGlowPainter old) => old.t != t;
}

/// Small ascending golden embers in front of the stove. Six particles
/// share a single timeline, staggered so a new one appears every ~0.16s.
class _EmberPainter extends CustomPainter {
  _EmberPainter({required this.t});
  final double t;
  static const int _count = 6;
  static final math.Random _seedrand = math.Random(42);
  // Per-particle horizontal offset noise, baked once.
  static final List<double> _xJitter =
      List.generate(_count, (_) => _seedrand.nextDouble() * 2 - 1);
  static final List<double> _drift =
      List.generate(_count, (_) => _seedrand.nextDouble() * 2 - 1);

  @override
  void paint(Canvas canvas, Size size) {
    final originX = size.width * 0.5;
    final originY = size.height * 0.65;
    final paint = Paint();
    for (int i = 0; i < _count; i++) {
      // Each particle's life cycle is offset so they don't all spawn together.
      final life = (t + i / _count) % 1.0;
      final dx = _xJitter[i] * size.width * 0.06 +
          _drift[i] * 4 * math.sin(life * math.pi * 2);
      final dy = -life * size.height * 0.55;
      // Fade in for the first 15%, fade out after 70%.
      final alpha = life < 0.15
          ? life / 0.15
          : (life > 0.70 ? (1.0 - (life - 0.70) / 0.30) : 1.0);
      paint.color = Color.lerp(
        const Color(0xFFFFD27A),
        const Color(0xFFFF7A1F),
        life,
      )!.withOpacity(alpha.clamp(0.0, 1.0) * 0.85);
      final radius = 1.6 + 1.2 * (1.0 - life);
      canvas.drawCircle(Offset(originX + dx, originY + dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EmberPainter old) => old.t != t;
}

/// Soft amber halo around a lantern. Smaller and more steady than the
/// stove glow; no embers.
class _LampGlowPainter extends CustomPainter {
  _LampGlowPainter({required this.t});
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final breathe = 0.85 + 0.15 * math.sin(t * 2 * math.pi);
    final jitter = 0.04 * math.sin(t * 2 * math.pi * 11);
    final intensity = (breathe + jitter).clamp(0.0, 1.0);

    // Lantern glass sits roughly at vertical center of the sprite.
    final center = Offset(size.width * 0.5, size.height * 0.55);
    final radius = math.max(size.width, size.height) * 0.55;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFE3A0).withOpacity(0.40 * intensity),
          const Color(0xFFFFB851).withOpacity(0.18 * intensity),
          const Color(0x00000000),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _LampGlowPainter old) => old.t != t;
}

/// Small bubbles rising through the hydroponic tower. Particles spawn
/// from the bottom reservoir and float upward through the cylinder; they
/// fade in then out so they don't blink in/out of existence.
class _BubblePainter extends CustomPainter {
  _BubblePainter({required this.t});
  final double t;
  static const int _count = 9;
  static final math.Random _seedrand = math.Random(7);
  static final List<double> _xPos =
      List.generate(_count, (_) => _seedrand.nextDouble());
  static final List<double> _radius =
      List.generate(_count, (_) => 1.2 + _seedrand.nextDouble() * 1.8);
  static final List<double> _phase =
      List.generate(_count, (_) => _seedrand.nextDouble());

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFE6F6FF).withOpacity(0.6);
    for (int i = 0; i < _count; i++) {
      final life = (t + _phase[i]) % 1.0;
      // Bubbles travel from y=0.95 (bottom reservoir) up to y=0.18 (top).
      final yFrac = 0.95 - life * 0.77;
      // Centered horizontally in the cylinder ±25% of width.
      final xFrac = 0.30 + 0.40 * _xPos[i] +
          0.015 * math.sin(life * math.pi * 4 + _phase[i] * 6);
      final alpha = life < 0.12
          ? life / 0.12
          : (life > 0.85 ? (1.0 - (life - 0.85) / 0.15) : 1.0);
      paint.color = const Color(0xFFE6F6FF).withOpacity(0.7 * alpha);
      canvas.drawCircle(
        Offset(size.width * xFrac, size.height * yFrac),
        _radius[i],
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BubblePainter old) => old.t != t;
}
