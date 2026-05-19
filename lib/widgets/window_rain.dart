import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Procedural rain streaks falling diagonally inside the window glass.
/// Two layers: fast thin streaks ("rain falling") and slower droplets
/// that slide down the inside of the glass ("water clinging"). All
/// drawn with a CustomPainter on top of the scrolling landscape, clipped
/// to the window ClipRRect by the parent. Always IgnorePointer.
class WindowRain extends StatefulWidget {
  const WindowRain({
    super.key,
    this.enabled = true,
    this.streakCount = 40,
    this.dropletCount = 18,
  });

  final bool enabled;
  final int streakCount;
  final int dropletCount;

  @override
  State<WindowRain> createState() => _WindowRainState();
}

class _WindowRainState extends State<WindowRain>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final List<_Streak> _streaks = [];
  final List<_Droplet> _droplets = [];
  Duration _lastTick = Duration.zero;
  Size _area = Size.zero;
  final math.Random _rng = math.Random(29);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    if (widget.enabled) _ticker.start();
  }

  @override
  void didUpdateWidget(covariant WindowRain oldWidget) {
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
    if (_area == Size.zero) {
      _lastTick = elapsed;
      return;
    }
    final dt = math.min(0.05, (elapsed - _lastTick).inMilliseconds / 1000.0);
    _lastTick = elapsed;
    for (final s in _streaks) {
      s.update(dt, _rng, _area);
    }
    for (final d in _droplets) {
      d.update(dt, _rng, _area);
    }
    setState(() {});
  }

  void _ensureParticles(Size size) {
    if (_area == size) return;
    _area = size;
    if (_streaks.isEmpty) {
      for (var i = 0; i < widget.streakCount; i++) {
        _streaks.add(_Streak.spawn(size, _rng, initial: true));
      }
    }
    if (_droplets.isEmpty) {
      for (var i = 0; i < widget.dropletCount; i++) {
        _droplets.add(_Droplet.spawn(size, _rng, initial: true));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _ensureParticles(constraints.biggest);
        return IgnorePointer(
          child: CustomPaint(
            painter: _RainPainter(
              streaks: _streaks,
              droplets: _droplets,
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }
}

/// Fast diagonal rain streaks falling outside the glass.
class _Streak {
  _Streak({
    required this.position,
    required this.length,
    required this.speed,
    required this.angle,
    required this.opacity,
  });

  Offset position;
  double length;
  double speed; // px / second
  double angle; // radians from vertical, slight tilt
  double opacity;

  static _Streak spawn(Size size, math.Random rng, {bool initial = false}) {
    return _Streak(
      position: Offset(
        rng.nextDouble() * size.width * 1.4 - size.width * 0.2,
        initial
            ? rng.nextDouble() * size.height
            : -10 - rng.nextDouble() * size.height * 0.3,
      ),
      length: 8 + rng.nextDouble() * 16,
      speed: 240 + rng.nextDouble() * 220,
      angle: 0.18 + rng.nextDouble() * 0.10,
      opacity: 0.22 + rng.nextDouble() * 0.22,
    );
  }

  void update(double dt, math.Random rng, Size area) {
    final dx = math.sin(angle) * speed * dt;
    final dy = math.cos(angle) * speed * dt;
    position = Offset(position.dx + dx, position.dy + dy);
    if (position.dy > area.height + length) {
      final fresh = _Streak.spawn(area, rng);
      position = fresh.position;
      length = fresh.length;
      speed = fresh.speed;
      angle = fresh.angle;
      opacity = fresh.opacity;
    }
  }
}

/// Slow droplets clinging to the inside of the glass — appear, sit, slide.
class _Droplet {
  _Droplet({
    required this.position,
    required this.radius,
    required this.maxAge,
    required this.slideSpeed,
  });

  Offset position;
  double radius;
  double maxAge;
  double age = 0;
  double slideSpeed;

  static _Droplet spawn(Size size, math.Random rng, {bool initial = false}) {
    final maxAge = 4.0 + rng.nextDouble() * 6.0;
    return _Droplet(
      position: Offset(
        rng.nextDouble() * size.width,
        rng.nextDouble() * size.height * 0.85,
      ),
      radius: 1.4 + rng.nextDouble() * 2.0,
      maxAge: maxAge,
      slideSpeed: 6 + rng.nextDouble() * 18,
    )..age = initial ? rng.nextDouble() * maxAge : 0;
  }

  void update(double dt, math.Random rng, Size area) {
    age += dt;
    final t = age / maxAge;
    // Sit still for the first ~40% of life, then slide down.
    if (t > 0.4) {
      position = Offset(position.dx, position.dy + slideSpeed * dt);
    }
    if (age >= maxAge || position.dy > area.height + 6) {
      final fresh = _Droplet.spawn(area, rng);
      position = fresh.position;
      radius = fresh.radius;
      maxAge = fresh.maxAge;
      slideSpeed = fresh.slideSpeed;
      age = 0;
    }
  }

  double get opacity {
    final t = age / maxAge;
    if (t < 0.1) return (t / 0.1) * 0.45;
    if (t > 0.85) return ((1 - t) / 0.15) * 0.45;
    return 0.45;
  }
}

class _RainPainter extends CustomPainter {
  _RainPainter({required this.streaks, required this.droplets});

  final List<_Streak> streaks;
  final List<_Droplet> droplets;

  static const _streakColor = Color(0xFFDFEAF6);
  static const _dropletColor = Color(0xFFCEDDEE);

  @override
  void paint(Canvas canvas, Size size) {
    final streakPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.0;
    for (final s in streaks) {
      streakPaint.color = _streakColor.withOpacity(s.opacity);
      final tip = Offset(
        s.position.dx + math.sin(s.angle) * s.length,
        s.position.dy + math.cos(s.angle) * s.length,
      );
      canvas.drawLine(s.position, tip, streakPaint);
    }
    final dropletPaint = Paint()..style = PaintingStyle.fill;
    for (final d in droplets) {
      dropletPaint.color = _dropletColor.withOpacity(d.opacity);
      canvas.drawCircle(d.position, d.radius, dropletPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RainPainter old) => true;
}
