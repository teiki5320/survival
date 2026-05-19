import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Slow-drifting dust motes filling the wagon interior. Procedural, no
/// assets — a fixed pool of particles with random spawn, slow horizontal
/// drift + slight downward gravity, fade-in / fade-out across their
/// lifespan, and seamless respawn. Stays IgnorePointer so it never
/// intercepts taps.
class DustParticles extends StatefulWidget {
  const DustParticles({
    super.key,
    this.enabled = true,
    this.particleCount = 60,
    this.color = const Color(0xFFFFE9C2),
    this.maxOpacity = 0.30,
  });

  final bool enabled;
  final int particleCount;
  final Color color;

  /// Cap on a single particle's opacity at its peak. Keep low; dust is
  /// supposed to be barely there.
  final double maxOpacity;

  @override
  State<DustParticles> createState() => _DustParticlesState();
}

class _DustParticlesState extends State<DustParticles>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final List<_Mote> _motes = [];
  Duration _lastTick = Duration.zero;
  Size _area = Size.zero;
  final math.Random _rng = math.Random(13);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    if (widget.enabled) _ticker.start();
  }

  @override
  void didUpdateWidget(covariant DustParticles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _ticker.start();
      } else {
        _ticker.stop();
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (_area == Size.zero || _motes.isEmpty) {
      _lastTick = elapsed;
      return;
    }
    final dt = math.min(
      0.05,
      (elapsed - _lastTick).inMilliseconds / 1000.0,
    );
    _lastTick = elapsed;
    for (final mote in _motes) {
      mote.update(dt, _rng, _area);
    }
    setState(() {});
  }

  void _ensureMotes(Size size) {
    if (_area == size) return;
    _area = size;
    if (_motes.isEmpty) {
      for (var i = 0; i < widget.particleCount; i++) {
        _motes.add(_Mote.spawn(size, _rng, initialAge: true));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _ensureMotes(constraints.biggest);
        return IgnorePointer(
          child: CustomPaint(
            painter: _DustPainter(
              motes: _motes,
              color: widget.color,
              maxOpacity: widget.maxOpacity,
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }
}

class _Mote {
  _Mote({
    required this.position,
    required this.velocity,
    required this.radius,
    required this.maxAge,
  });

  Offset position;
  Offset velocity;
  double radius;
  double maxAge;
  double age = 0;

  static _Mote spawn(Size size, math.Random rng, {bool initialAge = false}) {
    final maxAge = 5.0 + rng.nextDouble() * 8.0;
    final mote = _Mote(
      position: Offset(
        rng.nextDouble() * size.width,
        rng.nextDouble() * size.height,
      ),
      velocity: Offset(
        (rng.nextDouble() - 0.35) * 18,
        (rng.nextDouble() - 0.2) * 10 + 4,
      ),
      radius: 0.7 + rng.nextDouble() * 1.6,
      maxAge: maxAge,
    );
    mote.age = initialAge ? rng.nextDouble() * maxAge : 0;
    return mote;
  }

  void update(double dt, math.Random rng, Size area) {
    position += velocity * dt;
    age += dt;
    if (age >= maxAge ||
        position.dx < -12 ||
        position.dx > area.width + 12 ||
        position.dy < -12 ||
        position.dy > area.height + 12) {
      final fresh = _Mote.spawn(area, rng);
      position = fresh.position;
      velocity = fresh.velocity;
      radius = fresh.radius;
      maxAge = fresh.maxAge;
      age = 0;
    }
  }

  double get lifeOpacity {
    final t = age / maxAge;
    if (t < 0.18) return t / 0.18;
    if (t > 0.82) return (1 - t) / 0.18;
    return 1.0;
  }
}

class _DustPainter extends CustomPainter {
  _DustPainter({
    required this.motes,
    required this.color,
    required this.maxOpacity,
  });

  final List<_Mote> motes;
  final Color color;
  final double maxOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final mote in motes) {
      paint.color = color.withOpacity(mote.lifeOpacity * maxOpacity);
      canvas.drawCircle(mote.position, mote.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DustPainter old) => true;
}
