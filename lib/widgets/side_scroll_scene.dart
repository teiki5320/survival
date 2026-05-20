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
    this.night = false,
  });

  /// `true` shows the cleaned wagon; `false` the dirty initial-discovery state.
  final bool cleaned;

  /// When `false` all parallax + smoke animations freeze (the train stopped).
  /// The heroine can still walk — only the world stops moving.
  final bool running;

  /// `true` swaps in the night sky + horizon assets and applies a cool
  /// blue tint over the wagon and heroine so the whole scene reads as
  /// nighttime.
  final bool night;

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
  static const int _walkFrameMs = 50;
  static const int _idleFrameMs = 80;
  static const int _sleepFrameMs = 110;
  // The source sprite sheet walks toward the right; mirroring produces
  // the left-facing variant. Flip this if a future sheet faces left.
  static const bool _naturallyFacesRight = true;

  late final Ticker _heroTicker;
  double _heroX = 0.5;
  double? _heroTarget;
  bool _heroFacingRight = true;
  // She starts the game asleep on the floor; first tap wakes her and
  // sends her walking toward the tapped X.
  bool _heroSleeping = true;
  int _walkFrame = 0;
  int _idleFrame = 0;
  int _sleepFrame = 0;
  Duration _lastTick = Duration.zero;
  int _walkAccumMs = 0;
  int _idleAccumMs = 0;
  int _sleepAccumMs = 0;

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

  bool _precached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    // Decode and cache every walk + idle + sleep frame plus the background
    // variants before the user can interact. Without this, the first cycle
    // of any animation stutters while Flutter lazily decodes the PNGs.
    for (int i = 1; i <= _heroFrameCount; i++) {
      precacheImage(AssetImage('assets/characters/walk_right_$i.png'), context);
      precacheImage(AssetImage('assets/characters/idle_right_$i.png'), context);
      precacheImage(AssetImage('assets/characters/sleep_right_$i.png'), context);
    }
    for (final asset in const [
      'assets/background/sky.png',
      'assets/background/sky_night.png',
      'assets/background/horizon_a.png',
      'assets/background/horizon_night.png',
      'assets/background/wagon_clean.png',
      'assets/background/wagon_dirty.png',
      'assets/background/wagon_rails.png',
    ]) {
      precacheImage(AssetImage(asset), context);
    }
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
    if (dtMicros <= 0) return;
    final dt = dtMicros / 1e6;
    final dtMs = (dt * 1000).round();

    if (_heroSleeping) {
      setState(() {
        _sleepAccumMs += dtMs;
        while (_sleepAccumMs >= _sleepFrameMs) {
          _sleepAccumMs -= _sleepFrameMs;
          _sleepFrame = (_sleepFrame + 1) % _heroFrameCount;
        }
      });
      return;
    }

    final target = _heroTarget;
    if (target == null) {
      // Idle: advance the idle cycle so she breathes / shifts weight even
      // when standing still.
      setState(() {
        _idleAccumMs += dtMs;
        while (_idleAccumMs >= _idleFrameMs) {
          _idleAccumMs -= _idleFrameMs;
          _idleFrame = (_idleFrame + 1) % _heroFrameCount;
        }
      });
      return;
    }

    final delta = target - _heroX;
    final step = _heroSpeed * dt;
    if (delta.abs() <= step) {
      setState(() {
        _heroX = target;
        _heroTarget = null;
        _walkFrame = 0;
        _walkAccumMs = 0;
      });
      return;
    }

    final dir = delta > 0 ? 1.0 : -1.0;
    final newFacingRight = dir > 0;
    setState(() {
      _heroX += step * dir;
      _heroFacingRight = newFacingRight;
      _walkAccumMs += dtMs;
      while (_walkAccumMs >= _walkFrameMs) {
        _walkAccumMs -= _walkFrameMs;
        _walkFrame = (_walkFrame + 1) % _heroFrameCount;
      }
    });
  }

  void _walkTo(double normalizedX) {
    final clamped = normalizedX.clamp(_heroXMin, _heroXMax);
    setState(() {
      // First tap wakes her up; the same tap also queues her next move.
      _heroSleeping = false;
      _heroTarget = clamped;
    });
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
                        asset: widget.night
                            ? 'assets/background/sky_night.png'
                            : 'assets/background/sky.png',
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
                          asset: widget.night
                              ? 'assets/background/horizon_night.png'
                              : 'assets/background/horizon_a.png',
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
                      // 3. Wagon — fixed in the centre, with keyed-out
                      //    window panes letting the horizon parallax show
                      //    through. Tinted cool-blue at night.
                      Positioned.fill(
                        child: _nightTint(
                          Image.asset(
                            widget.cleaned
                                ? 'assets/background/wagon_clean.png'
                                : 'assets/background/wagon_dirty.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      // 4. Heroine — walks on the wagon floor, behind the
                      //    moving rails strip so she sits INSIDE the wagon.
                      _buildHeroine(w, h),
                      // 5. Wagon rails strip — the bottom 7% of the wagon
                      //    image (railway sleepers + ballast) extracted into
                      //    its own asset and scrolled horizontally as a
                      //    parallax layer. The wagon image's matching band
                      //    has been cut to transparent so we never draw the
                      //    rails twice. Visually 100% consistent with the
                      //    wagon since the strip IS the wagon's own rails.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: h * 0.07,
                        child: IgnorePointer(
                          child: _nightTint(
                            _ParallaxLayer(
                              controller: _foreground,
                              asset: 'assets/background/wagon_rails.png',
                              fit: BoxFit.fill,
                              alignment: Alignment.center,
                            ),
                          ),
                        ),
                      ),
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
    // Wagon's interior floor sits roughly here.
    final feetY = h * 0.79;

    if (_heroSleeping) {
      // Lying on the floor. Sprite is wide-horizontal (366x103 ≈ 3.55:1).
      // Body length matches her standing height; the sprite's bottom edge
      // sits on the parquet so she really lies on the floor, not above it.
      final bodyLen = h * 0.36;
      final bodyThick = bodyLen / (366 / 103);
      final asset = 'assets/characters/sleep_right_${_sleepFrame + 1}.png';
      return Positioned(
        left: _heroX * w - bodyLen / 2,
        top: feetY - bodyThick,
        width: bodyLen,
        height: bodyThick,
        child: IgnorePointer(
          child: _nightTint(Image.asset(asset, fit: BoxFit.contain)),
        ),
      );
    }

    // Standing / walking. Walk sprite aspect 163/375, idle aspect 91/372.
    final isMoving = _heroTarget != null;
    final heroHeight = h * 0.36;
    final spriteAspect = isMoving ? (163 / 375) : (91 / 372);
    final heroWidth = heroHeight * spriteAspect;
    final left = _heroX * w - heroWidth / 2;
    final top = feetY - heroHeight;

    final frame = isMoving ? _walkFrame : _idleFrame;
    final prefix = isMoving ? 'walk_right' : 'idle_right';
    final asset = 'assets/characters/${prefix}_${frame + 1}.png';
    final isMirrored = _heroFacingRight != _naturallyFacesRight;

    return Positioned(
      left: left,
      top: top,
      width: heroWidth,
      height: heroHeight,
      child: IgnorePointer(
        child: _nightTint(
          Transform(
            alignment: Alignment.center,
            transform: isMirrored
                ? (Matrix4.identity()..scale(-1.0, 1.0, 1.0))
                : Matrix4.identity(),
            child: Image.asset(asset, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  /// Multiplies a child by a cool blue-grey when [widget.night] is on, so
  /// daylit assets read as nighttime without needing redrawn variants.
  Widget _nightTint(Widget child) {
    if (!widget.night) return child;
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(
        Color(0xFF4A5C82),
        BlendMode.modulate,
      ),
      child: child,
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

/// Soft dark smoke trail rising from the locomotive (off-frame at the
/// left) and drifting back across the top of the wagon. Each puff is a
/// cluster of 3 overlapping radial-gradient blobs (so the silhouette is
/// irregular, not a clean circle), drawn with a colour that lerps from
/// near-black at the source to dusty grey as the puff ages.
class _SmokePainter extends CustomPainter {
  _SmokePainter(this.t, {required this.running});
  final double t;
  final bool running;

  static const int _count = 12;
  static const int _subPuffs = 3;
  static final math.Random _rng = math.Random(11);
  static final List<double> _phase = List.generate(_count, (_) => _rng.nextDouble());
  static final List<double> _vertJitter = List.generate(_count, (_) => _rng.nextDouble() * 2 - 1);
  static final List<double> _sizeJitter = List.generate(_count, (_) => 0.75 + _rng.nextDouble() * 0.55);
  // Sub-puff angles + distances baked once per particle so the silhouette is stable per particle.
  static final List<double> _subAng = List.generate(_count * _subPuffs, (_) => _rng.nextDouble() * math.pi * 2);
  static final List<double> _subDist = List.generate(_count * _subPuffs, (_) => 0.3 + _rng.nextDouble() * 0.5);

  static const Color _young = Color(0xFF1B1410);
  static const Color _old = Color(0xFF6F665C);

  @override
  void paint(Canvas canvas, Size size) {
    // Smokestack at the top of the off-frame locomotive.
    final originX = -size.width * 0.015;
    final originY = size.height * 0.10;

    for (int i = 0; i < _count; i++) {
      final life = (t + _phase[i]) % 1.0;
      // Trail path: drifts up-right, slows in Y as the puff ages.
      final x = originX + life * size.width * 0.95;
      final y = originY - math.pow(life, 0.7).toDouble() * size.height * 0.10 +
          _vertJitter[i] * 10;
      // Fade in fast, fade out gradually.
      final alpha = life < 0.06
          ? life / 0.06
          : (life > 0.55 ? (1.0 - (life - 0.55) / 0.45) : 1.0);
      final clamped = alpha.clamp(0.0, 1.0);
      final baseRadius = (10 + life * 40) * _sizeJitter[i];
      // Puff colour darker at source, lighter as it dissipates.
      final puffColor = Color.lerp(_young, _old, life)!;

      for (int s = 0; s < _subPuffs; s++) {
        final ang = _subAng[i * _subPuffs + s];
        final dist = _subDist[i * _subPuffs + s] * baseRadius;
        final cx = x + math.cos(ang) * dist;
        final cy = y + math.sin(ang) * dist * 0.6; // squash vertically — smoke spreads laterally
        final r = baseRadius * (0.85 + (s * 0.10));
        final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
        final shader = RadialGradient(
          colors: [
            puffColor.withOpacity(0.55 * clamped),
            puffColor.withOpacity(0.18 * clamped),
            puffColor.withOpacity(0.0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(rect);
        final paint = Paint()..shader = shader;
        canvas.drawCircle(Offset(cx, cy), r, paint);
      }
    }
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
