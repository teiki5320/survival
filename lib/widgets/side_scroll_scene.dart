import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'train_rocking.dart';

/// Side-scroller wagon scene.
///
/// Composition (back to front):
///   1. Sky        — fixed full-frame, drifts very slowly to suggest cloud motion
///   2. Horizon    — slow-scrolling parallax layer (distant ruins)
///   3. Wagon      — fixed in the centre, dirty or clean variant
///   4. Heroine    — tap-to-walk left/right on the wagon floor
///   5. Foreground — fast-scrolling parallax layer (grass / debris / rails)
///   6. Smoke      — procedural particle trail from the locomotive
///
/// Everything except the wagon and the heroine scrolls horizontally. When
/// the train stops (no fuel) all parallax + smoke freezes via [running].
class SideScrollScene extends StatefulWidget {
  const SideScrollScene({
    super.key,
    this.cleaned = false,
    this.running = true,
  });

  /// `true` shows the cleaned wagon; `false` the dirty initial-discovery state.
  final bool cleaned;

  /// When `false` all parallax + smoke animations freeze (the train stopped).
  /// The heroine can still walk — only the world stops moving.
  final bool running;

  @override
  State<SideScrollScene> createState() => _SideScrollSceneState();
}

class _SideScrollSceneState extends State<SideScrollScene>
    with TickerProviderStateMixin {
  // World-scroll controllers.
  late final AnimationController _horizon;
  late final AnimationController _foreground;
  late final AnimationController _smoke;
  late final AnimationController _sky;

  // Heroine state. Position is normalised to the scene width.
  static const int _heroFrameCount = 49;
  static const double _heroXMin = 0.12;
  static const double _heroXMax = 0.88;
  static const double _heroSpeed = 0.18; // normalised units / second
  static const int _heroFrameMs = 50;
  // The source sprite sheet walks toward the right; mirroring produces
  // the left-facing variant. Flip this if a future sheet faces left.
  static const bool _naturallyFacesRight = true;

  late final Ticker _heroTicker;
  double _heroX = 0.5;
  double? _heroTarget;
  bool _heroFacingRight = true;
  int _heroFrame = 0;
  Duration _lastTick = Duration.zero;
  int _frameAccumMs = 0;

  @override
  void initState() {
    super.initState();
    // Cycle durations tuned so motion is perceptible: sky reads as
    // slow drifting clouds (30s), horizon as a distant moving landscape
    // (28s), foreground as the close ground rushing by (5s).
    _sky = AnimationController(vsync: this, duration: const Duration(seconds: 30))..repeat();
    _horizon = AnimationController(vsync: this, duration: const Duration(seconds: 28))..repeat();
    _foreground = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
    _smoke = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _applyRunning();
    _heroTicker = createTicker(_onHeroTick)..start();
  }

  @override
  void didUpdateWidget(covariant SideScrollScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.running != widget.running) {
      _applyRunning();
    }
  }

  void _applyRunning() {
    final ctrls = [_horizon, _foreground, _smoke, _sky];
    if (widget.running) {
      for (final c in ctrls) {
        if (!c.isAnimating) c.repeat();
      }
    } else {
      for (final c in ctrls) {
        c.stop();
      }
    }
  }

  @override
  void dispose() {
    _heroTicker.dispose();
    _sky.dispose();
    _horizon.dispose();
    _foreground.dispose();
    _smoke.dispose();
    super.dispose();
  }

  void _onHeroTick(Duration elapsed) {
    final dtMicros = (elapsed - _lastTick).inMicroseconds;
    _lastTick = elapsed;
    final target = _heroTarget;
    if (target == null) return;

    final dt = dtMicros / 1e6;
    final delta = target - _heroX;
    final step = _heroSpeed * dt;
    if (delta.abs() <= step) {
      setState(() {
        _heroX = target;
        _heroTarget = null;
        _heroFrame = 0;
      });
      return;
    }

    final dir = delta > 0 ? 1.0 : -1.0;
    final newFacingRight = dir > 0;
    setState(() {
      _heroX += step * dir;
      _heroFacingRight = newFacingRight;
      _frameAccumMs += (dt * 1000).round();
      while (_frameAccumMs >= _heroFrameMs) {
        _frameAccumMs -= _heroFrameMs;
        _heroFrame = (_heroFrame + 1) % _heroFrameCount;
      }
    });
  }

  void _walkTo(double normalizedX) {
    final clamped = normalizedX.clamp(_heroXMin, _heroXMax);
    setState(() => _heroTarget = clamped);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            return ClipRect(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _walkTo(d.localPosition.dx / w),
                child: TrainRocking(
                  enabled: widget.running,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 1. Sky — drifting clouds, visible motion.
                      _ParallaxLayer(
                        controller: _sky,
                        asset: 'assets/background/sky.png',
                        fit: BoxFit.cover,
                      ),
                      // 2. Horizon — distant ruins. Sits behind the wagon
                      //    and is visible through the now-keyed window panes.
                      //    Anchored vertically so its skyline reads in the
                      //    wagon's window band (~y=0.30..0.55).
                      Positioned(
                        left: 0,
                        right: 0,
                        top: h * 0.18,
                        height: h * 0.42,
                        child: _ParallaxLayer(
                          controller: _horizon,
                          asset: 'assets/background/horizon_a.png',
                          fit: BoxFit.fitWidth,
                          alignment: Alignment.topCenter,
                        ),
                      ),
                      // 2b. Birds — occasional silhouettes drifting through
                      //    the upper sky band. Sits in front of the horizon
                      //    so they read as nearer than the ruins.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _sky,
                            builder: (_, __) => CustomPaint(
                              painter: _BirdsPainter(_sky.value),
                            ),
                          ),
                        ),
                      ),
                      // 3. Foreground — fast scroll. Sits BELOW the wagon
                      //    floor only, so it never occludes the heroine
                      //    inside the wagon. A dark band painted just above
                      //    its top edge sells the wagon's ground shadow,
                      //    scrolling at the same speed.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: h * 0.22,
                        child: IgnorePointer(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _ParallaxLayer(
                                controller: _foreground,
                                asset: 'assets/background/foreground.png',
                                fit: BoxFit.fitWidth,
                                alignment: Alignment.bottomCenter,
                              ),
                              // Wagon ground shadow — dark elongated band that
                              //   sits where the wagon meets the ground.
                              Positioned(
                                left: 0,
                                right: 0,
                                top: 0,
                                height: h * 0.05,
                                child: const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0x55000000),
                                        Color(0x00000000),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // 4. Wagon — fixed in the centre, with keyed-out
                      //    window panes letting the horizon parallax show
                      //    through.
                      Positioned.fill(
                        child: Image.asset(
                          widget.cleaned
                              ? 'assets/background/wagon_clean.png'
                              : 'assets/background/wagon_dirty.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      // 5. Heroine — walks on the wagon floor, on top of
                      //    everything so she is never occluded.
                      _buildHeroine(w, h),
                      // 6. Locomotive smoke — drifts over the top of the wagon.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _smoke,
                            builder: (_, __) => CustomPaint(
                              painter: _SmokePainter(_smoke.value, running: widget.running),
                            ),
                          ),
                        ),
                      ),
                      // 7. Speed lines — subtle motion blur streaks at the
                      //    upper and lower edges, visible only when running.
                      //    Driven off the foreground controller so they
                      //    pulse at the same tempo as the close parallax.
                      if (widget.running)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: AnimatedBuilder(
                              animation: _foreground,
                              builder: (_, __) => CustomPaint(
                                painter: _SpeedLinesPainter(_foreground.value),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeroine(double w, double h) {
    // Heroine sits on the wagon's interior floor. Tweak these constants if
    // the wagon asset changes. Sprite native aspect is 163x375 ≈ 0.435.
    final heroHeight = h * 0.46;
    final heroWidth = heroHeight * (163 / 375);
    final feetY = h * 0.86; // wagon's interior floor level
    final left = _heroX * w - heroWidth / 2;
    final top = feetY - heroHeight;

    final asset = 'assets/characters/walk_right_${_heroFrame + 1}.png';
    final isMirrored = _heroFacingRight != _naturallyFacesRight;

    return Positioned(
      left: left,
      top: top,
      width: heroWidth,
      height: heroHeight,
      child: IgnorePointer(
        child: Transform(
          alignment: Alignment.center,
          transform: isMirrored
              ? (Matrix4.identity()..scale(-1.0, 1.0, 1.0))
              : Matrix4.identity(),
          child: Image.asset(asset, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

/// Translates an asset horizontally to give the illusion of infinite scroll.
/// Renders two copies side-by-side and shifts both together; when one slides
/// fully off-screen left, its partner takes over without a visible jump.
class _ParallaxLayer extends StatelessWidget {
  const _ParallaxLayer({
    required this.controller,
    required this.asset,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });

  final AnimationController controller;
  final String asset;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final dx = -controller.value * w;
            return ClipRect(
              child: Stack(
                children: [
                  Positioned(
                    left: dx,
                    top: 0,
                    bottom: 0,
                    width: w,
                    child: Image.asset(asset, fit: fit, alignment: alignment),
                  ),
                  Positioned(
                    left: dx + w,
                    top: 0,
                    bottom: 0,
                    width: w,
                    child: Image.asset(asset, fit: fit, alignment: alignment),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Soft dark smoke trail rising from the locomotive (off-frame at the left)
/// and drifting back across the top of the wagon. Each puff is rendered as
/// three concentric circles (dark core → faint halo) so it reads as smoke
/// rather than a hard disc.
class _SmokePainter extends CustomPainter {
  _SmokePainter(this.t, {required this.running});
  final double t;
  final bool running;

  static const int _count = 10;
  static final math.Random _rng = math.Random(11);
  static final List<double> _phase = List.generate(_count, (_) => _rng.nextDouble());
  static final List<double> _vertJitter = List.generate(_count, (_) => _rng.nextDouble() * 2 - 1);
  static final List<double> _sizeJitter = List.generate(_count, (_) => 0.7 + _rng.nextDouble() * 0.6);

  @override
  void paint(Canvas canvas, Size size) {
    // Smokestack sits roughly at x=-2% (just off-frame) and y=12% (top of
    // the locomotive). Smoke drifts up-right across the wagon roof.
    final originX = -size.width * 0.02;
    final originY = size.height * 0.12;

    for (int i = 0; i < _count; i++) {
      final life = (t + _phase[i]) % 1.0;
      final x = originX + life * size.width * 0.95;
      final y = originY - life * size.height * 0.08 + _vertJitter[i] * 8;
      // Fade in over the first 8%, fade out from 55% onward.
      final alpha = life < 0.08
          ? life / 0.08
          : (life > 0.55 ? (1.0 - (life - 0.55) / 0.45) : 1.0);
      final clamped = alpha.clamp(0.0, 1.0);
      final baseRadius = (10 + life * 36) * _sizeJitter[i];
      // Three concentric layers: dark core, mid halo, faint outer.
      const core = Color(0xFF2A211B);
      _drawPuff(canvas, Offset(x, y), baseRadius * 0.55, core, 0.45 * clamped);
      _drawPuff(canvas, Offset(x, y), baseRadius * 0.85, core, 0.22 * clamped);
      _drawPuff(canvas, Offset(x, y), baseRadius * 1.20, core, 0.10 * clamped);
    }
  }

  void _drawPuff(Canvas canvas, Offset c, double r, Color color, double alpha) {
    final paint = Paint()..color = color.withOpacity(alpha);
    canvas.drawCircle(c, r, paint);
  }

  @override
  bool shouldRepaint(covariant _SmokePainter old) =>
      old.t != t || old.running != running;
}

/// Distant birds drifting across the sky band. Three flocks spaced along
/// the cycle so there is almost always one visible. Each flock is a small
/// V of three chevrons.
class _BirdsPainter extends CustomPainter {
  _BirdsPainter(this.t);
  final double t;

  static const int _flocks = 3;
  static final math.Random _rng = math.Random(23);
  static final List<double> _phase = List.generate(_flocks, (_) => _rng.nextDouble());
  static final List<double> _yFrac = List.generate(_flocks, (_) => 0.08 + _rng.nextDouble() * 0.18);
  static final List<double> _scale = List.generate(_flocks, (_) => 0.7 + _rng.nextDouble() * 0.6);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF20262C).withOpacity(0.55);
    for (int i = 0; i < _flocks; i++) {
      final life = (t + _phase[i]) % 1.0;
      // Birds drift left → right faster than the sky.
      final x = -size.width * 0.10 + life * size.width * 1.20;
      final y = size.height * _yFrac[i];
      final s = 6.0 * _scale[i];
      for (int b = 0; b < 3; b++) {
        final bx = x + b * (s * 2.8) + math.sin(life * math.pi * 2 + b) * 1.5;
        final by = y + math.sin(life * math.pi * 4 + b * 0.7) * 1.0;
        final path = Path()
          ..moveTo(bx - s, by + s * 0.3)
          ..lineTo(bx, by)
          ..lineTo(bx + s, by + s * 0.3);
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BirdsPainter old) => old.t != t;
}

/// Thin horizontal motion-blur streaks along the top and bottom edges to
/// reinforce the sense of speed. Streaks fade in/out and shift on every
/// pass so they don't read as a repeating pattern.
class _SpeedLinesPainter extends CustomPainter {
  _SpeedLinesPainter(this.t);
  final double t;

  static const int _count = 9;
  static final math.Random _rng = math.Random(91);
  static final List<double> _yFrac = List.generate(_count, (_) {
    // Streaks cluster at upper and lower edges only.
    final r = _rng.nextDouble();
    return r < 0.5 ? r * 0.18 : 0.82 + r * 0.16;
  });
  static final List<double> _phase = List.generate(_count, (_) => _rng.nextDouble());
  static final List<double> _len = List.generate(_count, (_) => 0.10 + _rng.nextDouble() * 0.18);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withOpacity(0.18);
    for (int i = 0; i < _count; i++) {
      final life = (t + _phase[i]) % 1.0;
      // Streaks travel right → left across the frame.
      final endX = size.width * (1.0 - life * 1.4);
      final startX = endX + size.width * _len[i];
      final y = size.height * _yFrac[i];
      final alpha = life < 0.15
          ? life / 0.15
          : (life > 0.70 ? (1.0 - (life - 0.70) / 0.30) : 1.0);
      paint.color = Colors.white.withOpacity(0.18 * alpha.clamp(0.0, 1.0));
      canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedLinesPainter old) => old.t != t;
}
