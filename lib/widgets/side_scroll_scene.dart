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
                      // 3. Foreground — fast scroll. Sits BELOW the wagon
                      //    floor only, so it never occludes the heroine
                      //    inside the wagon.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: h * 0.22,
                        child: IgnorePointer(
                          child: _ParallaxLayer(
                            controller: _foreground,
                            asset: 'assets/background/foreground.png',
                            fit: BoxFit.fitWidth,
                            alignment: Alignment.bottomCenter,
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
/// and drifting back across the top of the wagon.
class _SmokePainter extends CustomPainter {
  _SmokePainter(this.t, {required this.running});
  final double t;
  final bool running;

  static const int _count = 8;
  static final math.Random _rng = math.Random(11);
  static final List<double> _phase = List.generate(_count, (_) => _rng.nextDouble());
  static final List<double> _vertJitter = List.generate(_count, (_) => _rng.nextDouble() * 2 - 1);
  static final List<double> _sizeJitter = List.generate(_count, (_) => 0.7 + _rng.nextDouble() * 0.6);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final originX = -size.width * 0.05;
    final originY = size.height * 0.20;
    for (int i = 0; i < _count; i++) {
      final life = (t + _phase[i]) % 1.0;
      final x = originX + life * size.width * 0.85;
      final y = originY - life * size.height * 0.10 + _vertJitter[i] * 6;
      final alpha = life < 0.10
          ? life / 0.10
          : (life > 0.60 ? (1.0 - (life - 0.60) / 0.40) : 1.0);
      final clamped = alpha.clamp(0.0, 1.0);
      final radius = (12 + life * 28) * _sizeJitter[i];
      paint.color = const Color(0xFF3A2E26).withOpacity(0.45 * clamped);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SmokePainter old) =>
      old.t != t || old.running != running;
}
