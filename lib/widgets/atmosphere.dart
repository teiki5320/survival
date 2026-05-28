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

/// Hanging vines drawn procedurally over the scene — a few rope-like
/// strands dangling from the top edge, swaying gently. Adds life to the
/// otherwise static wagon/cab walls without needing baked-in animation
/// in the source PNG.
class HangingVines extends StatelessWidget {
  const HangingVines({
    super.key,
    required this.animation,
    this.strands = const [0.06, 0.18, 0.34, 0.62, 0.78, 0.93],
    this.opacity = 0.45,
  });

  final Animation<double> animation;
  final List<double> strands;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, __) => CustomPaint(
          painter: _VinePainter(animation.value, strands: strands, opacity: opacity),
        ),
      ),
    );
  }
}

class _VinePainter extends CustomPainter {
  _VinePainter(this.t, {required this.strands, required this.opacity});
  final double t;
  final List<double> strands;
  final double opacity;

  static final _rng = math.Random(57);
  static final List<double> _phase = List.generate(16, (_) => _rng.nextDouble());
  static final List<double> _length = List.generate(16, (_) => 0.18 + _rng.nextDouble() * 0.22);
  static final List<double> _amp = List.generate(16, (_) => 8 + _rng.nextDouble() * 14);

  @override
  void paint(Canvas canvas, Size size) {
    final stem = Paint()
      ..color = Color.fromRGBO(58, 90, 42, opacity)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final leaf = Paint()..color = Color.fromRGBO(96, 142, 64, opacity);

    for (int i = 0; i < strands.length; i++) {
      final xn = strands[i];
      final lifeT = (t + _phase[i]) * 2 * math.pi;
      final ampX = _amp[i % 16];
      final len = size.height * _length[i % 16];
      final baseX = size.width * xn;
      final topY = 0.0;
      final path = Path()..moveTo(baseX, topY);
      const segs = 14;
      for (int s = 1; s <= segs; s++) {
        final t01 = s / segs;
        final y = topY + len * t01;
        // Sway amplitude grows with how far down the strand you are
        // (top is anchored, tip waves the most).
        final wx = math.sin(lifeT + t01 * 1.6) * ampX * t01;
        path.lineTo(baseX + wx, y);
      }
      canvas.drawPath(path, stem);
      // Tip leaf
      final tipT = lifeT + 1.6;
      final tipX = baseX + math.sin(tipT) * ampX;
      final tipY = topY + len;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(tipX, tipY + 4), width: 10, height: 6),
        leaf,
      );
    }
  }

  @override
  bool shouldRepaint(_VinePainter old) => old.t != t;
}

/// Warm-amber halo anchored on a sprite (heroine) — used when she's
/// close to a light source like the firebox or a lamp. Brightness
/// decays with distance from the source so the effect fades naturally
/// as she walks away.
class CharacterHalo extends StatelessWidget {
  const CharacterHalo({
    super.key,
    required this.heroX,
    required this.heroY,
    required this.intensity,
  });

  /// Normalised X position of the heroine.
  final double heroX;

  /// Normalised Y position (her vertical centre, roughly).
  final double heroY;

  /// 0..1, multiplies the halo opacity.
  final double intensity;

  @override
  Widget build(BuildContext context) {
    if (intensity <= 0.02) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        painter: _HaloPainter(heroX: heroX, heroY: heroY, intensity: intensity),
      ),
    );
  }
}

class _HaloPainter extends CustomPainter {
  _HaloPainter({required this.heroX, required this.heroY, required this.intensity});
  final double heroX;
  final double heroY;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * heroX;
    final cy = size.height * heroY;
    final r = size.shortestSide * 0.30;
    final i = intensity.clamp(0.0, 1.0);
    final shader = RadialGradient(
      colors: [
        Color.fromRGBO(255, 197, 120, 0.45 * i),
        Color.fromRGBO(255, 167, 90, 0.18 * i),
        const Color(0x00000000),
      ],
      stops: const [0.0, 0.40, 1.0],
    ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_HaloPainter old) =>
      old.heroX != heroX || old.heroY != heroY || old.intensity != intensity;
}

/// Subtle ambient brightness pulse synced to the train rocking — every
/// roll cycle the scene gets a barely-perceptible breath of light, so
/// the rolling motion feels physical without overdoing it.
class AmbientPulse extends StatelessWidget {
  const AmbientPulse({super.key, required this.animation, this.amplitude = 0.05});
  final Animation<double> animation;
  final double amplitude;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, __) {
          final pulse = (math.sin(animation.value * 2 * math.pi) * 0.5 + 0.5) * amplitude;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: Color.fromRGBO(255, 232, 180, pulse),
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

/// Rare zombie silhouette walking across the distant background at
/// night. Triggers every ~45..90 s with a fresh random Y, then walks
/// from off-frame right to off-frame left over a few seconds. Reuses
/// the scene's existing horizon animation as a clock.
class DistantZombie extends StatefulWidget {
  const DistantZombie({super.key, required this.enabled});
  final bool enabled;

  @override
  State<DistantZombie> createState() => _DistantZombieState();
}

class _DistantZombieState extends State<DistantZombie>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _rng = math.Random();
  double _walkY = 0.6;
  double _scale = 0.7;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) {
          // Wait a random idle period then schedule the next walk.
          final wait = Duration(seconds: 45 + _rng.nextInt(60));
          Future.delayed(wait, () {
            if (!mounted || !widget.enabled) return;
            _walkY = 0.50 + _rng.nextDouble() * 0.15;
            _scale = 0.55 + _rng.nextDouble() * 0.30;
            _ctrl.forward(from: 0);
          });
        }
      });
    // Start the first walk after a short initial delay so the night
    // doesn't open with a zombie crossing immediately.
    Future.delayed(const Duration(seconds: 20), () {
      if (mounted && widget.enabled) _ctrl.forward(from: 0);
    });
  }

  @override
  void didUpdateWidget(covariant DistantZombie oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          if (_ctrl.value == 0 || !_ctrl.isAnimating) {
            return const SizedBox.shrink();
          }
          return CustomPaint(
            painter: _ZombiePainter(t: _ctrl.value, walkY: _walkY, scale: _scale),
          );
        },
      ),
    );
  }
}

class _ZombiePainter extends CustomPainter {
  _ZombiePainter({required this.t, required this.walkY, required this.scale});
  final double t;
  final double walkY;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    // Walks right → left.
    final x = (1.05 - t * 1.10) * size.width;
    final y = walkY * size.height;
    final h = 36.0 * scale;
    final paint = Paint()
      ..color = Color.fromRGBO(20, 25, 30, 0.55)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    // Head
    canvas.drawCircle(Offset(x, y), 3.5 * scale, paint);
    // Body
    canvas.drawLine(Offset(x, y + 3 * scale), Offset(x, y + h * 0.55), paint);
    // Arms (limp, swing slightly)
    final armSwing = math.sin(t * 18) * 4 * scale;
    canvas.drawLine(
      Offset(x, y + h * 0.20),
      Offset(x - 6 * scale - armSwing, y + h * 0.45),
      paint,
    );
    canvas.drawLine(
      Offset(x, y + h * 0.20),
      Offset(x + 5 * scale + armSwing, y + h * 0.50),
      paint,
    );
    // Legs (alternating step)
    final step = math.sin(t * 22) * 4 * scale;
    canvas.drawLine(
      Offset(x, y + h * 0.55),
      Offset(x - 3 * scale + step, y + h),
      paint,
    );
    canvas.drawLine(
      Offset(x, y + h * 0.55),
      Offset(x + 3 * scale - step, y + h),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ZombiePainter old) =>
      old.t != t || old.walkY != walkY || old.scale != scale;
}

/// Quick burst of dust under the heroine's feet whenever she takes a
/// step. The parent feeds a stepToken (incremented on each foot-down
/// frame); each token triggers a 400 ms puff that fades out.
class FootstepDust extends StatefulWidget {
  const FootstepDust({
    super.key,
    required this.heroX,
    required this.feetY,
    required this.stepToken,
    this.enabled = true,
  });

  final double heroX;
  final double feetY;
  final int stepToken;
  final bool enabled;

  @override
  State<FootstepDust> createState() => _FootstepDustState();
}

class _FootstepDustState extends State<FootstepDust>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  double _puffX = 0.5;
  double _puffY = 0.9;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
  }

  @override
  void didUpdateWidget(covariant FootstepDust old) {
    super.didUpdateWidget(old);
    if (widget.enabled && widget.stepToken != old.stepToken) {
      _puffX = widget.heroX;
      _puffY = widget.feetY;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          if (_ctrl.value == 0) return const SizedBox.shrink();
          return CustomPaint(
            painter: _PuffPainter(t: _ctrl.value, x: _puffX, y: _puffY),
          );
        },
      ),
    );
  }
}

class _PuffPainter extends CustomPainter {
  _PuffPainter({required this.t, required this.x, required this.y});
  final double t;
  final double x;
  final double y;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * x;
    final cy = size.height * y;
    final fade = (1.0 - t).clamp(0.0, 1.0);
    final r = 6 + t * 18;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.fromRGBO(190, 165, 130, 0.55 * fade),
          const Color(0x00000000),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r, paint);
  }

  @override
  bool shouldRepaint(_PuffPainter old) =>
      old.t != t || old.x != x || old.y != y;
}

/// Rain drops falling and streaking down the wagon window band.
/// Drops are confined to a normalised vertical range so they don't
/// fall across the whole scene — they read as drops *on the glass*.
class WindowRain extends StatelessWidget {
  const WindowRain({
    super.key,
    required this.animation,
    this.topY = 0.18,
    this.bottomY = 0.60,
    this.density = 30,
  });

  final Animation<double> animation;
  final double topY;
  final double bottomY;
  final int density;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, __) => CustomPaint(
          painter: _RainPainter(
            animation.value,
            topY: topY,
            bottomY: bottomY,
            count: density,
          ),
        ),
      ),
    );
  }
}

class _RainPainter extends CustomPainter {
  _RainPainter(this.t,
      {required this.topY, required this.bottomY, required this.count});
  final double t;
  final double topY;
  final double bottomY;
  final int count;

  static final _rng = math.Random(33);
  static final List<double> _xn = List.generate(64, (_) => _rng.nextDouble());
  static final List<double> _phase = List.generate(64, (_) => _rng.nextDouble());
  static final List<double> _len = List.generate(64, (_) => 8 + _rng.nextDouble() * 12);
  static final List<double> _speed = List.generate(64, (_) => 0.6 + _rng.nextDouble() * 1.1);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x88BFD5E8)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final top = size.height * topY;
    final bottom = size.height * bottomY;
    final band = bottom - top;
    for (int i = 0; i < count; i++) {
      final ix = i % 64;
      final life = ((t * _speed[ix]) + _phase[ix]) % 1.0;
      final x = size.width * _xn[ix];
      final y = top + life * band;
      canvas.drawLine(Offset(x, y), Offset(x + 0.5, y + _len[ix]), paint);
    }
  }

  @override
  bool shouldRepaint(_RainPainter old) => old.t != t;
}

/// Small thought-bubble shown above the heroine for a few seconds.
/// Renders an emoji (☕, 💤, 🌧, etc.) inside a soft white bubble with
/// the classic three trailing dots.
class ThoughtBubble extends StatelessWidget {
  const ThoughtBubble({
    super.key,
    required this.heroX,
    required this.heroTopY,
    required this.emoji,
    this.opacity = 1.0,
  });

  final double heroX;

  /// Normalised Y of the heroine's head — the bubble sits above this.
  final double heroTopY;
  final String emoji;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, c) {
          final x = c.maxWidth * heroX;
          final y = c.maxHeight * heroTopY;
          return Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Stack(
              children: [
                // Two trailing dots between heroine head and bubble.
                Positioned(
                  left: x - 3,
                  top: y - 18,
                  child: _Dot(diameter: 5),
                ),
                Positioned(
                  left: x + 6,
                  top: y - 30,
                  child: _Dot(diameter: 7),
                ),
                // Bubble.
                Positioned(
                  left: x - 22,
                  top: y - 70,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x40000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(emoji, style: const TextStyle(fontSize: 22)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Animated firebox flames — overlapping triangular tongues that rise,
/// flicker, and shrink. Anchored on the cab's firebox position; the
/// caller draws this OVER the painted-static fire in the locomotive
/// sprite to make it look alive.
class FireboxFlames extends StatelessWidget {
  const FireboxFlames({
    super.key,
    required this.animation,
    required this.x,
    required this.y,
    this.width = 0.10,
    this.height = 0.07,
  });

  final Animation<double> animation;

  /// Normalised position of the firebox centre (top-edge inside the
  /// open door).
  final double x;
  final double y;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, __) => CustomPaint(
          painter: _FlamePainter(
            t: animation.value,
            x: x,
            y: y,
            w: width,
            h: height,
          ),
        ),
      ),
    );
  }
}

class _FlamePainter extends CustomPainter {
  _FlamePainter({
    required this.t,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });
  final double t;
  final double x;
  final double y;
  final double w;
  final double h;

  static final _rng = math.Random(47);
  static final List<double> _phase = List.generate(7, (_) => _rng.nextDouble());
  static final List<double> _speed = List.generate(7, (_) => 0.7 + _rng.nextDouble() * 0.6);
  static final List<double> _xOff = List.generate(7, (_) => -0.4 + _rng.nextDouble() * 0.8);
  static final List<double> _scale = List.generate(7, (_) => 0.6 + _rng.nextDouble() * 0.6);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * x;
    final cy = size.height * y;
    final wpx = size.width * w;
    final hpx = size.height * h;

    for (int i = 0; i < _phase.length; i++) {
      final wave = math.sin((t * 30 * _speed[i] + _phase[i]) * 2 * math.pi);
      final scale = _scale[i] * (0.85 + 0.15 * wave);
      final fx = cx + _xOff[i] * wpx * 0.5;
      final flameH = hpx * scale;
      final flameW = wpx * 0.45 * scale;

      // Three colour layers stacked outer→inner for a soft fire shape.
      final layers = [
        const Color(0x99FF6A20), // outer red-orange
        const Color(0xCCFFA040), // mid amber
        const Color(0xFFFFE0A0), // inner cream
      ];
      final scales = [1.0, 0.65, 0.32];
      for (int l = 0; l < layers.length; l++) {
        final path = Path();
        path.moveTo(fx - flameW * scales[l] / 2, cy);
        path.quadraticBezierTo(
          fx - flameW * scales[l] * 0.25,
          cy - flameH * scales[l] * 0.45,
          fx,
          cy - flameH * scales[l],
        );
        path.quadraticBezierTo(
          fx + flameW * scales[l] * 0.25,
          cy - flameH * scales[l] * 0.45,
          fx + flameW * scales[l] / 2,
          cy,
        );
        path.close();
        canvas.drawPath(
          path,
          Paint()
            ..color = layers[l]
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, l == 0 ? 4 : 1),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_FlamePainter old) => old.t != t;
}

class _Dot extends StatelessWidget {
  const _Dot({required this.diameter});
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        shape: BoxShape.circle,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Daytime birds — silhouettes crossing the window band (right to left)
// ---------------------------------------------------------------------------

class DaytimeBirds extends StatelessWidget {
  const DaytimeBirds({super.key, required this.animation, this.enabled = true});
  final Animation<double> animation;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, __) => CustomPaint(
          painter: _DaytimeBirdsPainter(animation.value),
        ),
      ),
    );
  }
}

class _DaytimeBirdsPainter extends CustomPainter {
  _DaytimeBirdsPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (int group = 0; group < 4; group++) {
      final seed = group * 197.0;
      final speed = 0.15 + (seed * 0.13 % 0.05);
      final baseX = 1.2 - ((seed * 0.31 + t * speed) % 1.6);
      final baseY = 0.15 + (seed * 0.17 % 0.55);
      final count = 3 + (group % 2);

      for (int b = 0; b < count; b++) {
        final bSeed = b * 53.0 + seed;
        final ox = baseX + (bSeed * 0.07 % 0.05) - 0.025;
        final oy = baseY + (bSeed * 0.11 % 0.06) - 0.03;
        final x = ox * size.width;
        final y = oy * size.height;
        final wing = math.sin(t * 8 + bSeed) * 5;
        final opacity = 0.55 + (bSeed * 0.07 % 0.25);

        final path = Path()
          ..moveTo(x - 9, y + wing)
          ..lineTo(x, y)
          ..lineTo(x + 9, y + wing);
        canvas.drawPath(
          path,
          Paint()
            ..color = Color.fromRGBO(15, 15, 25, opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DaytimeBirdsPainter old) => true;
}

// ---------------------------------------------------------------------------
// Distant animal — rare silhouette crossing slowly (day only)
// ---------------------------------------------------------------------------

class DistantAnimal extends StatelessWidget {
  const DistantAnimal({super.key, required this.animation, this.enabled = true});
  final Animation<double> animation;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, __) => CustomPaint(
          painter: _DistantAnimalPainter(animation.value),
        ),
      ),
    );
  }
}

class _DistantAnimalPainter extends CustomPainter {
  _DistantAnimalPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final speed = 0.025;
    final x = 1.1 - ((t * speed) % 1.4);
    final y = 0.55;
    final px = x * size.width;
    final py = y * size.height;
    const opacity = 0.50;
    final legPhase = math.sin(t * 3.0) * 3;

    final paint = Paint()
      ..color = const Color.fromRGBO(20, 15, 10, opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.translate(px, py);
    canvas.drawLine(const Offset(-14, 0), const Offset(14, -3), paint);
    canvas.drawCircle(const Offset(16, -8), 4, paint);
    canvas.drawLine(const Offset(15, -8), const Offset(13, -14), paint..strokeWidth = 1.8);
    canvas.drawLine(const Offset(18, -8), const Offset(20, -14), paint);
    paint.strokeWidth = 2.2;
    canvas.drawLine(const Offset(-7, 0), Offset(-7 + legPhase, 10), paint);
    canvas.drawLine(const Offset(-10, 0), Offset(-10 - legPhase, 10), paint);
    canvas.drawLine(const Offset(7, -2), Offset(7 + legPhase * 0.8, 8), paint);
    canvas.drawLine(const Offset(10, -2), Offset(10 - legPhase * 0.8, 8), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DistantAnimalPainter old) => true;
}

// ---------------------------------------------------------------------------
// Animated grass tufts on the foreground rail band
// ---------------------------------------------------------------------------

class AnimatedGrass extends StatelessWidget {
  const AnimatedGrass({super.key, required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, __) => CustomPaint(
          painter: _GrassPainter(animation.value),
        ),
      ),
    );
  }
}

class _GrassPainter extends CustomPainter {
  _GrassPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 18; i++) {
      final seed = i * 89.0;
      final bx = (seed * 0.071) % 1.0;
      final by = 0.3 + (seed * 0.13 % 0.5);
      final x = bx * size.width;
      final y = by * size.height;
      final sway = math.sin(t * 2.0 + seed) * 3;
      final h = 6.0 + (seed % 6);
      final opacity = 0.25 + (seed * 0.03 % 0.15);

      paint.color = Color.fromRGBO(50, 65, 30, opacity);
      canvas.drawLine(Offset(x, y), Offset(x + sway, y - h), paint);
      canvas.drawLine(Offset(x + 2, y), Offset(x + 2 + sway * 0.7, y - h * 0.8), paint);
    }
  }

  @override
  bool shouldRepaint(_GrassPainter old) => true;
}

// ---------------------------------------------------------------------------
// Rail sparks — occasional orange particles from the rails
// ---------------------------------------------------------------------------

class RailSparks extends StatelessWidget {
  const RailSparks({super.key, required this.animation, this.running = true});
  final Animation<double> animation;
  final bool running;

  @override
  Widget build(BuildContext context) {
    if (!running) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, __) => CustomPaint(
          painter: _RailSparksPainter(animation.value),
        ),
      ),
    );
  }
}

class _RailSparksPainter extends CustomPainter {
  _RailSparksPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 14; i++) {
      final seed = i * 137.0;
      final cycle = (t * 4.0 + seed) % 3.0;
      if (cycle > 1.5) continue;

      final x = (0.15 + (seed * 0.11 % 0.7)) * size.width;
      final baseY = 0.4 * size.height;
      final lifeT = (cycle / 1.5).clamp(0.0, 1.0);
      final sparkY = baseY - lifeT * 30;
      final sparkX = x + (lifeT * 14 * (i.isEven ? 1 : -1));
      final opacity = (1.0 - lifeT) * 1.0;
      final r = 1.6 + (1.0 - lifeT) * 2.8;

      // Glow halo.
      canvas.drawCircle(
        Offset(sparkX, sparkY),
        r * 2.2,
        Paint()
          ..color = Color.fromRGBO(255, 130, 30, opacity * 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.5),
      );
      // Core.
      canvas.drawCircle(
        Offset(sparkX, sparkY),
        r,
        Paint()..color = Color.fromRGBO(255, 200, 80, opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_RailSparksPainter old) => true;
}

// ---------------------------------------------------------------------------
// Scurrying animal — small critter crossing the rail band fast
// ---------------------------------------------------------------------------

class ScurryingAnimal extends StatelessWidget {
  const ScurryingAnimal({super.key, required this.animation, this.running = true});
  final Animation<double> animation;
  final bool running;

  @override
  Widget build(BuildContext context) {
    if (!running) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, __) => CustomPaint(
          painter: _ScurryingAnimalPainter(animation.value),
        ),
      ),
    );
  }
}

class _ScurryingAnimalPainter extends CustomPainter {
  _ScurryingAnimalPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 3; i++) {
      final seed = i * 311.0;
      final speed = 0.25 + (seed * 0.07 % 0.08);
      final x = ((seed * 0.41 + t * speed) % 2.0) - 0.5;
      if (x < -0.1 || x > 1.1) continue;
      final y = 0.4 + (seed * 0.19 % 0.4);
      final px = x * size.width;
      final py = y * size.height;
      const opacity = 0.75;
      final legPhase = math.sin(t * 14 + seed) * 4;

      final paint = Paint()
        ..color = const Color.fromRGBO(15, 12, 8, opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.5);

      canvas.drawOval(
        Rect.fromCenter(center: Offset(px, py), width: 16, height: 8),
        paint,
      );
      final tailWag = math.sin(t * 10 + seed) * 3;
      canvas.drawLine(
        Offset(px + 8, py),
        Offset(px + 18, py - 2 + tailWag),
        paint..strokeWidth = 1.8,
      );
      canvas.drawLine(Offset(px - 4, py + 3), Offset(px - 4 + legPhase, py + 10),
          paint..strokeWidth = 1.6);
      canvas.drawLine(Offset(px + 4, py + 3), Offset(px + 4 - legPhase, py + 10),
          paint);
    }
  }

  @override
  bool shouldRepaint(_ScurryingAnimalPainter old) => true;
}

// ---------------------------------------------------------------------------
// Door steam — vapour wisps drifting in through the locomotive door
// ---------------------------------------------------------------------------

class DoorSteam extends StatelessWidget {
  const DoorSteam({super.key, required this.animation, this.running = true});
  final Animation<double> animation;
  final bool running;

  @override
  Widget build(BuildContext context) {
    if (!running) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, __) => CustomPaint(
          painter: _DoorSteamPainter(animation.value),
        ),
      ),
    );
  }
}

class _DoorSteamPainter extends CustomPainter {
  _DoorSteamPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 6; i++) {
      final seed = i * 71.0;
      final cycle = (t * 0.5 + seed * 0.3) % 3.0;
      final life = (cycle / 3.0).clamp(0.0, 1.0);
      final x = size.width * (0.3 + life * 0.5);
      final y = size.height * (0.3 + (seed * 0.11 % 0.3)) - life * size.height * 0.1;
      final r = 4.0 + life * 12;
      final opacity = (1.0 - life) * 0.12;

      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = Color.fromRGBO(200, 200, 210, opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(_DoorSteamPainter old) => true;
}

// ---------------------------------------------------------------------------
// Flying embers — orange sparks flying out from the firebox
// ---------------------------------------------------------------------------

class FlyingEmbers extends StatelessWidget {
  const FlyingEmbers({super.key, required this.animation, this.intensity = 0.5});
  final Animation<double> animation;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    if (intensity <= 0) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, __) => CustomPaint(
          painter: _FlyingEmbersPainter(animation.value, intensity),
        ),
      ),
    );
  }
}

class _FlyingEmbersPainter extends CustomPainter {
  _FlyingEmbersPainter(this.t, this.intensity);
  final double t;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final count = (10 * intensity).round().clamp(5, 14);
    for (int i = 0; i < count; i++) {
      final seed = i * 97.0;
      final cycle = (t * 1.8 + seed * 0.4) % 2.5;
      final life = (cycle / 2.5).clamp(0.0, 1.0);
      final startX = size.width * 0.35;
      final startY = size.height * 0.55;
      final dx = life * size.width * 0.45;
      final dy = -life * size.height * 0.35 + math.sin(t * 3 + seed) * 12;
      final x = startX + dx;
      final y = startY + dy;
      final opacity = (1.0 - life) * 1.0;
      final r = 1.8 + (1.0 - life) * 2.5;

      // Glow halo.
      canvas.drawCircle(
        Offset(x, y),
        r * 2.5,
        Paint()
          ..color = Color.fromRGBO(255, 100, 20, opacity * 0.3)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.8),
      );
      // Core.
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = Color.fromRGBO(255, 190, 60, opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_FlyingEmbersPainter old) => true;
}
