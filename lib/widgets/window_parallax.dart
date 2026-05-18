import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Procedural parallax inside the rear-window area of the wagon.
///
/// Two layers of vertical dark silhouettes (close + far) scroll right-to-left
/// at different speeds, looping seamlessly. Suggests "the world outside is
/// passing by" without requiring a separate landscape asset. Sits between
/// the wagon background (which already shows static zombies / fog) and the
/// objects/character layer, so it reads as midground motion blur rather
/// than specific objects you can identify.
class WindowParallax extends StatefulWidget {
  const WindowParallax({
    super.key,
    required this.windowRect,
    this.enabled = true,
  });

  /// Window glass area in normalized 0..1 coordinates of the wagon box.
  final Rect windowRect;
  final bool enabled;

  @override
  State<WindowParallax> createState() => _WindowParallaxState();
}

class _WindowParallaxState extends State<WindowParallax>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Streak> _streaks;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _streaks = _buildStreaks();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Two depth layers — closer streaks move faster, are taller and more
  /// opaque; far streaks are thin, slow, and faint. Phases are spread out
  /// across [0, 1) so the screen always has streaks at different positions.
  List<_Streak> _buildStreaks() {
    final rng = math.Random(42);
    final streaks = <_Streak>[];

    // Close layer: 8 fast tall streaks.
    for (var i = 0; i < 8; i++) {
      streaks.add(_Streak(
        phase: i / 8 + rng.nextDouble() * 0.05,
        heightFraction: 0.55 + rng.nextDouble() * 0.40,
        verticalAnchor: 0.55 + rng.nextDouble() * 0.40,
        widthPx: 3 + rng.nextDouble() * 5,
        speed: 0.18 + rng.nextDouble() * 0.10,
        opacity: 0.20 + rng.nextDouble() * 0.20,
        tiltRadians: (rng.nextDouble() - 0.5) * 0.10,
      ));
    }
    // Far layer: 12 thin slow streaks.
    for (var i = 0; i < 12; i++) {
      streaks.add(_Streak(
        phase: i / 12 + rng.nextDouble() * 0.05,
        heightFraction: 0.20 + rng.nextDouble() * 0.40,
        verticalAnchor: 0.30 + rng.nextDouble() * 0.45,
        widthPx: 1.2 + rng.nextDouble() * 2.0,
        speed: 0.06 + rng.nextDouble() * 0.05,
        opacity: 0.08 + rng.nextDouble() * 0.10,
        tiltRadians: (rng.nextDouble() - 0.5) * 0.06,
      ));
    }
    return streaks;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final left = widget.windowRect.left * w;
        final top = widget.windowRect.top * h;
        final width = widget.windowRect.width * w;
        final height = widget.windowRect.height * h;
        return Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: IgnorePointer(
            child: ClipRect(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _StreaksPainter(
                      streaks: _streaks,
                      time: _controller.value,
                    ),
                    size: Size(width, height),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Streak {
  const _Streak({
    required this.phase,
    required this.heightFraction,
    required this.verticalAnchor,
    required this.widthPx,
    required this.speed,
    required this.opacity,
    required this.tiltRadians,
  });

  /// Initial position offset in [0, 1) — combined with [speed] and time to
  /// place the streak each frame.
  final double phase;

  /// Streak height as a fraction of the window height.
  final double heightFraction;

  /// Vertical anchor in [0, 1] — where the bottom of the streak sits within
  /// the window box.
  final double verticalAnchor;

  /// Streak width in pixels.
  final double widthPx;

  /// Horizontal speed expressed in screen-widths per second of the
  /// controller's normalized time. Higher = faster scroll.
  final double speed;

  final double opacity;

  /// Subtle lean to break the perfect-vertical look.
  final double tiltRadians;
}

class _StreaksPainter extends CustomPainter {
  _StreaksPainter({required this.streaks, required this.time});

  final List<_Streak> streaks;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in streaks) {
      // Scroll right-to-left: total travel covers 1.4x the window width
      // (off-screen-right -> off-screen-left), so streaks fade in and
      // out at the edges naturally with the ClipRect.
      final travel = size.width * 1.4;
      final position =
          ((s.phase + time * s.speed * 6.0) % 1.0) * travel - size.width * 0.2;
      final x = size.width - position;

      final streakHeight = s.heightFraction * size.height;
      final yBottom = s.verticalAnchor * size.height;
      final yTop = yBottom - streakHeight;

      final paint = Paint()
        ..color = Colors.black.withOpacity(s.opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, yBottom);
      canvas.rotate(s.tiltRadians);
      final rect = Rect.fromLTWH(
        -s.widthPx / 2,
        -streakHeight,
        s.widthPx,
        streakHeight,
      );
      canvas.drawRect(rect, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _StreaksPainter old) =>
      old.time != time || old.streaks != streaks;
}
