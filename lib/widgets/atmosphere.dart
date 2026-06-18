import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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
      ..shader = const RadialGradient(
        colors: [
          Color(0x66FFB347),
          Color(0x33C36428),
          Color(0x00000000),
        ],
        stops: [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r, paint);
  }

  @override
  bool shouldRepaint(_FireGlowPainter old) =>
      old.t != t || old.x != x || old.y != y || old.radius != radius;
}

/// Halo de LAMPE : un cœur brillant (la lampe brille elle-même), un halo
/// chaud autour, ET un cône de lumière qui descend jusqu'au sol.
class LampGlow extends StatelessWidget {
  const LampGlow({
    super.key,
    required this.animation,
    required this.x,
    required this.y,
    this.radius = 0.42,
    this.floorY = 0.92,
    this.halo = true,
  });
  final Animation<double> animation;
  final double x;
  final double y;
  final double radius;
  final double floorY;

  /// `true` (défaut) = halo lumineux autour de la lampe. Pour les lampes dont
  /// le sprite porte déjà sa propre lueur, mettre `false` : on ne garde que la
  /// LUMIÈRE PROJETÉE (cône + flaque au sol), plus large.
  final bool halo;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, __) => CustomPaint(
          painter: _LampGlowPainter(animation.value,
              x: x, y: y, radius: radius, floorY: floorY, halo: halo),
        ),
      ),
    );
  }
}

class _LampGlowPainter extends CustomPainter {
  _LampGlowPainter(this.t,
      {required this.x,
      required this.y,
      required this.radius,
      required this.floorY,
      this.halo = true});
  final double t;
  final double x;
  final double y;
  final double radius;
  final double floorY;
  final bool halo;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * x;
    final cy = size.height * y;
    final base = size.shortestSide * radius;
    final flicker =
        math.sin(t * 2 * math.pi * 1.6) * 0.04 + math.sin(t * 2 * math.pi * 9) * 0.02;
    final r = base * (1.0 + flicker);

    // 1) Cône de lumière qui tombe vers le sol — LARGE (lumière projetée).
    final fy = size.height * floorY;
    if (fy > cy) {
      final spread = base * (halo ? 0.85 : 1.35);
      final cone = Path()
        ..moveTo(cx - spread * 0.18, cy)
        ..lineTo(cx + spread * 0.18, cy)
        ..lineTo(cx + spread, fy)
        ..lineTo(cx - spread, fy)
        ..close();
      final conePaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x3AFFCB6E), Color(0x14FFCB6E), Color(0x00000000)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(Rect.fromLTRB(cx - spread, cy, cx + spread, fy))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawPath(cone, conePaint);
      // tache de lumière au sol
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx, fy), width: spread * 2.0, height: spread * 0.35),
        Paint()
          ..color = const Color(0x22FFCB6E)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }

    // 2+3) Halo + cœur brillant AUTOUR de la lampe — seulement si [halo].
    //      Les nouvelles lampes portent déjà leur lueur dans le sprite -> on
    //      coupe le halo (sinon double lueur) et on ne garde que la lumière
    //      projetée (le cône large ci-dessus).
    if (halo) {
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = const RadialGradient(
            colors: [
              Color(0x33FFE6AE),
              Color(0x14FFD98A),
              Color(0x00000000),
            ],
            stops: [0.0, 0.4, 1.0],
          ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
      );
      final coreR = base * 0.20;
      canvas.drawCircle(
        Offset(cx, cy),
        coreR,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = const RadialGradient(
            colors: [
              Color(0xFFFFF6D8),
              Color(0xCCFFE2A0),
              Color(0x00FFD98A),
            ],
            stops: [0.0, 0.5, 1.0],
          ).createShader(
              Rect.fromCircle(center: Offset(cx, cy), radius: coreR)),
      );
    }
  }

  @override
  bool shouldRepaint(_LampGlowPainter old) =>
      old.t != t || old.x != x || old.y != y;
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
      ..color = const Color.fromRGBO(20, 25, 30, 0.55)
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
                  child: const _Dot(diameter: 5),
                ),
                Positioned(
                  left: x + 6,
                  top: y - 30,
                  child: const _Dot(diameter: 7),
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
      final speed = 0.06 + (seed * 0.13 % 0.03);
      final baseX = 1.2 - ((seed * 0.31 + t * speed) % 1.6);
      final baseY = 0.20 + (seed * 0.17 % 0.40);
      final count = 3 + (group % 2);

      for (int b = 0; b < count; b++) {
        final bSeed = b * 53.0 + seed;
        final ox = baseX + (bSeed * 0.07 % 0.05) - 0.025;
        final oy = baseY + (bSeed * 0.11 % 0.06) - 0.03;
        final x = ox * size.width;
        final y = oy * size.height;
        final wing = math.sin(t * 8 + bSeed) * 2.2;
        final opacity = 0.45 + (bSeed * 0.07 % 0.20);

        final path = Path()
          ..moveTo(x - 4, y + wing)
          ..lineTo(x, y)
          ..lineTo(x + 4, y + wing);
        canvas.drawPath(
          path,
          Paint()
            ..color = Color.fromRGBO(15, 15, 25, opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DaytimeBirdsPainter old) => old.t != t;
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
    const speed = 0.025;
    final x = 1.1 - ((t * speed) % 1.4);
    const y = 0.55;
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
  bool shouldRepaint(_DistantAnimalPainter old) => old.t != t;
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
  bool shouldRepaint(_GrassPainter old) => old.t != t;
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
  bool shouldRepaint(_RailSparksPainter old) => old.t != t;
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
  bool shouldRepaint(_DoorSteamPainter old) => old.t != t;
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
  bool shouldRepaint(_FlyingEmbersPainter old) => old.t != t || old.intensity != intensity;
}


// ---------------------------------------------------------------------------
// Foreground life — debris, critters, and decay on/near the rails
// ---------------------------------------------------------------------------

class ForegroundLife extends StatefulWidget {
  const ForegroundLife({super.key, this.animation, this.running = true});
  final Animation<double>? animation;
  final bool running;

  @override
  State<ForegroundLife> createState() => _ForegroundLifeState();
}

class _ForegroundLifeState extends State<ForegroundLife>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker((d) {
      setState(() => _t = d.inMicroseconds / 1e6);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ForegroundLifePainter(_t, widget.running),
      ),
    );
  }
}

class _ForegroundLifePainter extends CustomPainter {
  _ForegroundLifePainter(this.t, this.running);
  final double t;
  final bool running;

  @override
  void paint(Canvas canvas, Size size) {
    // 3 cycling slots for moving things, plus static-ish background bits.
    for (int slot = 0; slot < 3; slot++) {
      final seed = slot * 113.0;
      final cycle = (t * 0.30 + seed * 0.27) % 10.0;
      final type = cycle.floor();
      final localT = cycle - type;
      _drawByType(canvas, size, type, seed, localT);
    }
    // Always-on static layer (bones, flowers, footprints).
    _drawStaticDecay(canvas, size);
  }

  void _drawByType(Canvas canvas, Size size, int type, double seed, double lt) {
    if (!running && type < 7) return;
    switch (type) {
      case 0: _drawTumbleweed(canvas, size, seed, lt); break;
      case 1: _drawPaperDebris(canvas, size, seed, lt); break;
      case 2: _drawDustDevil(canvas, size, seed, lt); break;
      // Animaux qui traversaient sous les rails retirés (pas réaliste) :
      // renard / serpent / lézard désactivés -> seulement débris + vent.
      case 3: break;
      case 4: break;
      case 5: break;
      case 6: _drawRollingBottle(canvas, size, seed, lt); break;
      case 7: _drawFootprintTrail(canvas, size, seed, lt); break;
      case 8: break; // bones handled in static
      case 9: break; // flowers handled in static
    }
  }

  // 0. Tumbleweed bouncing across.
  void _drawTumbleweed(Canvas canvas, Size size, double seed, double lt) {
    final x = (1.1 - lt * 1.3) * size.width;
    final baseY = 0.65 * size.height;
    final bounce = (math.sin(lt * 12) * 0.5 + 0.5) * 8;
    final y = baseY - bounce;
    final rot = lt * 30;
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(rot);
    final p = Paint()
      ..color = const Color.fromRGBO(120, 95, 50, 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (int i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      canvas.drawLine(
        Offset(math.cos(a) * 2, math.sin(a) * 2),
        Offset(math.cos(a) * 8, math.sin(a) * 8),
        p,
      );
    }
    canvas.drawCircle(Offset.zero, 6, p..strokeWidth = 0.8);
    canvas.restore();
  }

  // 1. Paper / plastic debris flying past.
  void _drawPaperDebris(Canvas canvas, Size size, double seed, double lt) {
    for (int i = 0; i < 3; i++) {
      final iSeed = seed + i * 23;
      final x = (1.1 - lt * 1.6 - i * 0.04) * size.width;
      final y = (0.45 + (iSeed * 0.07 % 0.30)) * size.height +
          math.sin(t * 3 + iSeed) * 6;
      final flap = math.sin(t * 5 + iSeed);
      final path = Path()
        ..moveTo(x - 4, y)
        ..lineTo(x, y - 2 + flap)
        ..lineTo(x + 4, y)
        ..lineTo(x + 2, y + 3);
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color.fromRGBO(220, 215, 200, 0.55)
          ..style = PaintingStyle.fill,
      );
    }
  }

  // 2. Small dust devil.
  void _drawDustDevil(Canvas canvas, Size size, double seed, double lt) {
    final fade = math.sin(lt * math.pi).clamp(0.0, 1.0);
    final x = (0.2 + (seed * 0.13 % 0.6)) * size.width;
    final baseY = 0.75 * size.height;
    for (int i = 0; i < 10; i++) {
      final h = i / 10.0;
      final spinR = (1.0 - h) * 6 + 2;
      final ang = t * 8 + h * 6;
      final px = x + math.cos(ang) * spinR;
      final py = baseY - h * 30;
      canvas.drawCircle(
        Offset(px, py),
        2 + h * 1.5,
        Paint()
          ..color = Color.fromRGBO(180, 150, 110, (1 - h) * 0.5 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  // 3-5. Renard / serpent / lézard retirés (animaux sous les rails pas
  // réalistes). Les cases 3/4/5 de _drawByType sont désormais des no-op.

  // 6. Rolling bottle.
  void _drawRollingBottle(Canvas canvas, Size size, double seed, double lt) {
    final x = (1.1 - lt * 1.4) * size.width;
    final y = (0.78 + (seed * 0.05 % 0.04)) * size.height;
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(lt * 20);
    final p = Paint()
      ..color = const Color.fromRGBO(70, 110, 90, 0.65);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-5, -1.5, 10, 3),
        const Radius.circular(1.5),
      ),
      p,
    );
    canvas.drawRect(
      const Rect.fromLTWH(4, -0.8, 2, 1.6),
      p,
    );
    canvas.restore();
  }

  // 7. Footprint trail fading.
  void _drawFootprintTrail(Canvas canvas, Size size, double seed, double lt) {
    final y = (0.78 + (seed * 0.05 % 0.05)) * size.height;
    for (int i = 0; i < 8; i++) {
      final age = (lt * 2 - i * 0.12).clamp(0.0, 1.0);
      if (age >= 1.0) continue;
      final x = (1.0 - i * 0.09 - lt * 0.5) * size.width;
      final opacity = (1.0 - age) * 0.4;
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(x, y + (i.isEven ? -3 : 3)),
            width: 5, height: 3),
        Paint()
          ..color = Color.fromRGBO(40, 30, 20, opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8),
      );
    }
  }

  // 8 + 9 baked into static layer: bones half-buried + wildflowers.
  void _drawStaticDecay(Canvas canvas, Size size) {
    // Bones (skull silhouette, 1 fixed-ish spot).
    const boneSeed = 71.0;
    final bx = (0.18 + (boneSeed * 0.07 % 0.5)) * size.width;
    final by = (0.82 + (boneSeed * 0.05 % 0.05)) * size.height;
    final bp = Paint()
      ..color = const Color.fromRGBO(220, 210, 190, 0.55);
    canvas.drawCircle(Offset(bx, by), 3, bp);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bx + 4, by), width: 6, height: 2),
      bp,
    );
    // Dark eye sockets.
    final eye = Paint()..color = const Color.fromRGBO(20, 15, 10, 0.7);
    canvas.drawCircle(Offset(bx - 1, by - 0.5), 0.7, eye);
    canvas.drawCircle(Offset(bx + 1, by - 0.5), 0.7, eye);

    // Wildflowers — small yellow/pink touches.
    for (int i = 0; i < 8; i++) {
      final seed = i * 41.0 + 200;
      final fx = (seed * 0.071 % 1.0) * size.width;
      final fy = (0.55 + (seed * 0.13 % 0.30)) * size.height;
      final sway = math.sin(t * 1.5 + seed) * 1.5;
      final color = (i.isEven)
          ? const Color.fromRGBO(240, 200, 80, 0.7)
          : const Color.fromRGBO(220, 140, 160, 0.7);
      // Stem.
      canvas.drawLine(
        Offset(fx, fy),
        Offset(fx + sway, fy - 5),
        Paint()
          ..color = const Color.fromRGBO(50, 70, 30, 0.6)
          ..strokeWidth = 0.8,
      );
      // Flower head.
      canvas.drawCircle(
        Offset(fx + sway, fy - 5),
        1.6,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_ForegroundLifePainter old) => old.t != t || old.running != running;
}

// ---------------------------------------------------------------------------
// Animated curtains — gentle sway over wagon windows
// ---------------------------------------------------------------------------

class AnimatedCurtains extends StatefulWidget {
  const AnimatedCurtains({super.key, this.intensity = 1.0});
  final double intensity;

  @override
  State<AnimatedCurtains> createState() => _AnimatedCurtainsState();
}

class _AnimatedCurtainsState extends State<AnimatedCurtains>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker((d) {
      setState(() => _t = d.inMicroseconds / 1e6);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _CurtainsPainter(_t, widget.intensity),
      ),
    );
  }
}

class _CurtainsPainter extends CustomPainter {
  _CurtainsPainter(this.t, this.intensity);
  final double t;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    // 6 curtain panels (3 windows × 2 sides).
    const curtainXs = [0.265, 0.305, 0.465, 0.505, 0.665, 0.705];
    for (int i = 0; i < curtainXs.length; i++) {
      final cx = curtainXs[i] * size.width;
      final topY = size.height * 0.40;
      final bottomY = size.height * 0.58;
      final sway = math.sin(t * 1.2 + i * 0.7) * 3 * intensity;
      const width = 14.0;
      final path = Path()
        ..moveTo(cx - width / 2, topY)
        ..quadraticBezierTo(
          cx - width / 2 + sway * 0.5, (topY + bottomY) / 2,
          cx - width / 2 + sway, bottomY,
        )
        ..lineTo(cx + width / 2 + sway, bottomY)
        ..quadraticBezierTo(
          cx + width / 2 + sway * 0.5, (topY + bottomY) / 2,
          cx + width / 2, topY,
        )
        ..close();
      // Inkfold lines for texture.
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0x33000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }
  }

  @override
  bool shouldRepaint(_CurtainsPainter old) => old.t != t || old.intensity != intensity;
}

// ---------------------------------------------------------------------------
// Window frost — ice crystals on the glass when cold
// ---------------------------------------------------------------------------

class WindowFrost extends StatelessWidget {
  const WindowFrost({super.key, this.intensity = 1.0});
  final double intensity;

  @override
  Widget build(BuildContext context) {
    if (intensity <= 0) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        painter: _WindowFrostPainter(intensity),
      ),
    );
  }
}

class _WindowFrostPainter extends CustomPainter {
  _WindowFrostPainter(this.intensity);
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    // 3 windows in the wagon back wall.
    const windows = [
      [0.235, 0.395, 0.105, 0.180], // x, y, w, h (normalised)
      [0.435, 0.395, 0.105, 0.180],
      [0.635, 0.395, 0.105, 0.180],
    ];
    for (final w in windows) {
      final rect = Rect.fromLTWH(
        w[0] * size.width,
        w[1] * size.height,
        w[2] * size.width,
        w[3] * size.height,
      );
      // White gradient at the edges of each window pane.
      canvas.save();
      canvas.clipRect(rect);
      // Top/bottom frost.
      for (int edge = 0; edge < 4; edge++) {
        final isVertical = edge < 2;
        final p = Paint()
          ..shader = ui.Gradient.linear(
            isVertical
                ? Offset(rect.center.dx,
                    edge == 0 ? rect.top : rect.bottom)
                : Offset(edge == 2 ? rect.left : rect.right, rect.center.dy),
            isVertical
                ? Offset(rect.center.dx,
                    edge == 0
                        ? rect.top + rect.height * 0.4
                        : rect.bottom - rect.height * 0.4)
                : Offset(
                    edge == 2
                        ? rect.left + rect.width * 0.4
                        : rect.right - rect.width * 0.4,
                    rect.center.dy),
            [
              Color.fromRGBO(230, 240, 250, 0.55 * intensity),
              const Color.fromRGBO(230, 240, 250, 0.0),
            ],
          );
        canvas.drawRect(rect, p);
      }
      // Sparse ice crystals.
      for (int i = 0; i < 8; i++) {
        final cx = rect.left +
            (i * 41 % 1000) / 1000.0 * rect.width;
        final cy = rect.top +
            (i * 73 % 1000) / 1000.0 * rect.height;
        canvas.drawCircle(
          Offset(cx, cy),
          0.6,
          Paint()..color = Color.fromRGBO(255, 255, 255, 0.5 * intensity),
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_WindowFrostPainter old) =>
      old.intensity != intensity;
}

// ---------------------------------------------------------------------------
// Cobwebs — animated spider webs in the corners
// ---------------------------------------------------------------------------

class Cobwebs extends StatefulWidget {
  const Cobwebs({super.key});

  @override
  State<Cobwebs> createState() => _CobwebsState();
}

class _CobwebsState extends State<Cobwebs>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker((d) {
      setState(() => _t = d.inMicroseconds / 1e6);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _CobwebsPainter(_t)),
    );
  }
}

class _CobwebsPainter extends CustomPainter {
  _CobwebsPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // 4 corners: top-left, top-right, low-left, low-right inside wagon.
    final corners = <Offset>[
      Offset(size.width * 0.15, size.height * 0.36),
      Offset(size.width * 0.83, size.height * 0.36),
      Offset(size.width * 0.20, size.height * 0.62),
      Offset(size.width * 0.80, size.height * 0.62),
    ];
    final p = Paint()
      ..color = const Color(0x66E0E0E0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    for (int c = 0; c < corners.length; c++) {
      final corner = corners[c];
      final dirX = c.isEven ? 1.0 : -1.0;
      final dirY = c < 2 ? 1.0 : -1.0;
      final sway = math.sin(t * 0.8 + c) * 1.2;
      // Radial threads.
      const radial = 4;
      for (int i = 0; i < radial; i++) {
        final ang = (i + 1) * (math.pi / 2 / (radial + 1));
        final dx = math.cos(ang) * 18 * dirX;
        final dy = math.sin(ang) * 18 * dirY;
        canvas.drawLine(corner, Offset(corner.dx + dx, corner.dy + dy + sway), p);
      }
      // Spiral threads.
      for (int s = 1; s <= 3; s++) {
        final r = s * 5.0;
        final path = Path();
        for (int i = 0; i <= radial; i++) {
          final ang = i * (math.pi / 2 / radial);
          final px = corner.dx + math.cos(ang) * r * dirX;
          final py = corner.dy + math.sin(ang) * r * dirY + sway * 0.5;
          if (i == 0) {
            path.moveTo(px, py);
          } else {
            path.lineTo(px, py);
          }
        }
        canvas.drawPath(path, p);
      }
    }
  }

  @override
  bool shouldRepaint(_CobwebsPainter old) => old.t != t;
}

// ---------------------------------------------------------------------------
// Animated gauges — needles that wobble based on running state
// ---------------------------------------------------------------------------

class AnimatedGauges extends StatefulWidget {
  const AnimatedGauges({super.key, this.active = true});
  final bool active;

  @override
  State<AnimatedGauges> createState() => _AnimatedGaugesState();
}

class _AnimatedGaugesState extends State<AnimatedGauges>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker((d) {
      setState(() => _t = d.inMicroseconds / 1e6);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _GaugesPainter(_t, widget.active)),
    );
  }
}

class _GaugesPainter extends CustomPainter {
  _GaugesPainter(this.t, this.active);
  final double t;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    // 2 gauges on left wall of the locomotive cabin.
    const gauges = [
      [0.123, 0.265, 0.85], // x, y, baseAngle (radians of needle)
      [0.165, 0.310, 0.65],
    ];
    for (final g in gauges) {
      final cx = g[0] * size.width;
      final cy = g[1] * size.height;
      const r = 16.0;
      final wobble = active ? math.sin(t * 3 + g[2] * 7) * 0.15 : 0.0;
      final needleAngle = g[2] + wobble;
      final p = Paint()
        ..color = const Color(0xFFE85518)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + math.cos(needleAngle) * r * 0.7,
            cy + math.sin(needleAngle) * r * 0.7),
        p,
      );
      canvas.drawCircle(Offset(cx, cy), 1.5, Paint()..color = const Color(0xFF3A2010));
    }
  }

  @override
  bool shouldRepaint(_GaugesPainter old) => old.t != t || old.active != active;
}

// ---------------------------------------------------------------------------
// Floating ashes — soft grey particles drifting near the firebox
// ---------------------------------------------------------------------------

class FloatingAshes extends StatefulWidget {
  const FloatingAshes({super.key, this.active = true});
  final bool active;

  @override
  State<FloatingAshes> createState() => _FloatingAshesState();
}

class _FloatingAshesState extends State<FloatingAshes>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker((d) {
      setState(() => _t = d.inMicroseconds / 1e6);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(painter: _AshesPainter(_t)),
    );
  }
}

class _AshesPainter extends CustomPainter {
  _AshesPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 14; i++) {
      final seed = i * 47.0;
      final cycle = (t * 0.2 + seed * 0.13) % 1.0;
      final x = (0.12 + (seed * 0.07 % 0.15)) * size.width +
          math.sin(t * 0.8 + seed) * 8;
      final y = (0.85 - cycle * 0.30) * size.height;
      final opacity = (1.0 - cycle) * 0.5;
      canvas.drawCircle(
        Offset(x, y),
        1.5,
        Paint()
          ..color = Color.fromRGBO(180, 170, 160, opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0),
      );
    }
  }

  @override
  bool shouldRepaint(_AshesPainter old) => old.t != t;
}

// ---------------------------------------------------------------------------
// Pipe steam — wisps from valves / joints in the locomotive
// ---------------------------------------------------------------------------

class PipeSteam extends StatefulWidget {
  const PipeSteam({super.key, this.intensity = 1.0});
  final double intensity;

  @override
  State<PipeSteam> createState() => _PipeSteamState();
}

class _PipeSteamState extends State<PipeSteam>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker((d) {
      setState(() => _t = d.inMicroseconds / 1e6);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.intensity <= 0) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(painter: _PipeSteamPainter(_t, widget.intensity)),
    );
  }
}

class _PipeSteamPainter extends CustomPainter {
  _PipeSteamPainter(this.t, this.intensity);
  final double t;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    // 2 pipe vents on the left side near gauges.
    const vents = [
      [0.075, 0.35],
      [0.110, 0.42],
    ];
    for (final v in vents) {
      final vx = v[0] * size.width;
      final vy = v[1] * size.height;
      for (int i = 0; i < 5; i++) {
        final cycle = (t * 0.6 + i * 0.2) % 1.0;
        final r = 3.0 + cycle * 10;
        final x = vx + math.sin(cycle * 3 + i) * 4;
        final y = vy - cycle * 25;
        final opacity = (1.0 - cycle) * 0.35 * intensity;
        canvas.drawCircle(
          Offset(x, y),
          r,
          Paint()
            ..color = Color.fromRGBO(200, 200, 210, opacity)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.7),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PipeSteamPainter old) => old.t != t || old.intensity != intensity;
}

// ---------------------------------------------------------------------------
// Mid-ground parallax — telephone poles + dead trees that scroll faster
// than the horizon, creating a layered depth effect.
// ---------------------------------------------------------------------------

class MidgroundParallax extends StatefulWidget {
  const MidgroundParallax({super.key, required this.animation});
  final Animation<double> animation;

  @override
  State<MidgroundParallax> createState() => _MidgroundParallaxState();
}

class _MidgroundParallaxState extends State<MidgroundParallax> {
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: widget.animation,
        builder: (_, __) => CustomPaint(
          painter: _MidgroundPainter(widget.animation.value),
        ),
      ),
    );
  }
}

class _MidgroundPainter extends CustomPainter {
  _MidgroundPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // Distribute 8 elements (poles + trees) across 2× the screen width,
    // scrolling continuously.
    const slots = 8;
    for (int i = 0; i < slots; i++) {
      final seed = i * 137.0;
      final isPole = (i % 3) != 0; // 2/3 poles, 1/3 trees
      final xOffset = (seed * 0.31) % 2.0; // 0..2
      final x = ((xOffset - t * 2.0) % 2.0 - 0.5) * size.width;
      // Skip if too far off-screen
      if (x < -80 || x > size.width + 80) continue;

      final yBase = size.height * 0.75;
      final scaleVar = 0.85 + (seed * 0.07 % 0.30);

      if (isPole) {
        _drawTelephonePole(canvas, x, yBase, scaleVar);
      } else {
        _drawDeadTree(canvas, x, yBase, scaleVar, seed);
      }
    }
  }

  void _drawTelephonePole(Canvas canvas, double x, double yBase, double s) {
    final p = Paint()
      ..color = const Color.fromRGBO(20, 18, 16, 0.65)
      ..strokeWidth = 1.8 * s
      ..strokeCap = StrokeCap.round;
    final h = 64.0 * s;
    // Vertical pole.
    canvas.drawLine(Offset(x, yBase), Offset(x, yBase - h), p);
    // Top crossbar.
    canvas.drawLine(
      Offset(x - 8 * s, yBase - h + 4 * s),
      Offset(x + 8 * s, yBase - h + 4 * s),
      p..strokeWidth = 1.4 * s,
    );
    // Insulators.
    canvas.drawCircle(
        Offset(x - 8 * s, yBase - h + 2 * s), 0.8 * s, Paint()..color = const Color(0xFF1A1410));
    canvas.drawCircle(
        Offset(x + 8 * s, yBase - h + 2 * s), 0.8 * s, Paint()..color = const Color(0xFF1A1410));
  }

  void _drawDeadTree(Canvas canvas, double x, double yBase, double s, double seed) {
    final p = Paint()
      ..color = const Color.fromRGBO(25, 20, 18, 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * s
      ..strokeCap = StrokeCap.round;
    final h = 50.0 * s;
    // Trunk.
    canvas.drawLine(Offset(x, yBase), Offset(x + 2 * s, yBase - h), p);
    // 4 branches asymmetric.
    p.strokeWidth = 1.4 * s;
    canvas.drawLine(
      Offset(x + 2 * s, yBase - h * 0.7),
      Offset(x - 8 * s, yBase - h * 1.1),
      p,
    );
    canvas.drawLine(
      Offset(x + 2 * s, yBase - h * 0.6),
      Offset(x + 10 * s, yBase - h * 0.95),
      p,
    );
    canvas.drawLine(
      Offset(x - 1 * s, yBase - h * 0.5),
      Offset(x - 7 * s, yBase - h * 0.75),
      p..strokeWidth = 1.0 * s,
    );
    canvas.drawLine(
      Offset(x + 3 * s, yBase - h * 0.4),
      Offset(x + 8 * s, yBase - h * 0.6),
      p,
    );
  }

  @override
  bool shouldRepaint(_MidgroundPainter old) => old.t != t;
}

