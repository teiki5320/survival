import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Floating dust motes inside the wagon — slow drift, gentle bob.
/// Renders nothing when `running` is false (train stopped = air still).
class DustParticles extends StatelessWidget {
  const DustParticles({
    super.key,
    required this.animation,
    this.count = 24,
    this.opacity = 0.45,
  });

  final Animation<double> animation;
  final int count;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, __) => CustomPaint(
          painter: _DustPainter(animation.value, count: count, opacity: opacity),
        ),
      ),
    );
  }
}

class _DustPainter extends CustomPainter {
  _DustPainter(this.t, {required this.count, required this.opacity});
  final double t;
  final int count;
  final double opacity;

  static final _rng = math.Random(73);
  static final List<double> _phaseX = List.generate(64, (_) => _rng.nextDouble());
  static final List<double> _phaseY = List.generate(64, (_) => _rng.nextDouble());
  static final List<double> _seedY = List.generate(64, (_) => _rng.nextDouble());
  static final List<double> _size = List.generate(64, (_) => 0.6 + _rng.nextDouble() * 1.6);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Color.fromRGBO(255, 224, 168, opacity);
    for (int i = 0; i < count; i++) {
      final ix = i % 64;
      // Slow horizontal drift to the right, wraps around.
      final dx = ((t + _phaseX[ix]) % 1.0) * size.width;
      // Bobbing vertical sine + small per-particle Y baseline.
      final by = _seedY[ix] * size.height * 0.7 + size.height * 0.15;
      final dy = by + math.sin((t + _phaseY[ix]) * 2 * math.pi) * 12;
      canvas.drawCircle(Offset(dx, dy), _size[ix], paint);
    }
  }

  @override
  bool shouldRepaint(_DustPainter old) => old.t != t;
}

/// Lucioles — drifting glowing dots, night-only. Each one wobbles in a
/// small loop and pulses its brightness.
class Fireflies extends StatelessWidget {
  const Fireflies({
    super.key,
    required this.animation,
    this.count = 6,
  });

  final Animation<double> animation;
  final int count;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, __) => CustomPaint(
          painter: _FirefliesPainter(animation.value, count: count),
        ),
      ),
    );
  }
}

class _FirefliesPainter extends CustomPainter {
  _FirefliesPainter(this.t, {required this.count});
  final double t;
  final int count;

  static final _rng = math.Random(91);
  static final List<double> _cx = List.generate(16, (_) => 0.15 + _rng.nextDouble() * 0.7);
  static final List<double> _cy = List.generate(16, (_) => 0.30 + _rng.nextDouble() * 0.45);
  static final List<double> _rx = List.generate(16, (_) => 0.04 + _rng.nextDouble() * 0.06);
  static final List<double> _ry = List.generate(16, (_) => 0.03 + _rng.nextDouble() * 0.05);
  static final List<double> _phase = List.generate(16, (_) => _rng.nextDouble());
  static final List<double> _phasePulse = List.generate(16, (_) => _rng.nextDouble());
  static final List<double> _speed = List.generate(16, (_) => 0.6 + _rng.nextDouble() * 0.7);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < count; i++) {
      final ix = i % 16;
      final ang = (t * _speed[ix] + _phase[ix]) * 2 * math.pi;
      final x = (_cx[ix] + _rx[ix] * math.cos(ang)) * size.width;
      final y = (_cy[ix] + _ry[ix] * math.sin(ang)) * size.height;
      final pulse = 0.5 + 0.5 * math.sin((t + _phasePulse[ix]) * 4 * math.pi);
      final glow = Paint()
        ..color = Color.fromRGBO(255, 234, 130, pulse * 0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(x, y), 4, glow);
      final core = Paint()..color = Color.fromRGBO(255, 252, 200, pulse);
      canvas.drawCircle(Offset(x, y), 1.6, core);
    }
  }

  @override
  bool shouldRepaint(_FirefliesPainter old) => old.t != t;
}

/// Soft amber halo overlay anchored to a normalised (x,y) point — used
/// for the firebox glow in the locomotive cab. Brightness flickers
/// gently so the fire reads as alive.
class FireGlow extends StatelessWidget {
  const FireGlow({
    super.key,
    required this.animation,
    required this.x,
    required this.y,
    this.radius = 0.45,
  });

  final Animation<double> animation;
  final double x;
  final double y;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, __) => CustomPaint(
          painter: _FireGlowPainter(animation.value, x: x, y: y, radius: radius),
        ),
      ),
    );
  }
}

class _FireGlowPainter extends CustomPainter {
  _FireGlowPainter(this.t, {required this.x, required this.y, required this.radius});
  final double t;
  final double x;
  final double y;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * x;
    final cy = size.height * y;
    final base = size.shortestSide * radius;
    // Two overlapping flickers (slow + fast) so the pulse feels organic.
    final flickerSlow = math.sin(t * 2 * math.pi * 1.3) * 0.05;
    final flickerFast = math.sin(t * 2 * math.pi * 7.0) * 0.025;
    final r = base * (1.0 + flickerSlow + flickerFast);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: const [
          Color(0x66FFB347),
          Color(0x33C36428),
          Color(0x00000000),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r, paint);
  }

  @override
  bool shouldRepaint(_FireGlowPainter old) =>
      old.t != t || old.x != x || old.y != y || old.radius != radius;
}
