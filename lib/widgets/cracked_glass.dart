import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Live state of a window crack — fed into [CrackedGlass]. Bumping [seed]
/// or changing [impactPoint] retriggers the reveal animation; raising
/// [intensity] adds more cracks without resetting the existing ones.
class CrackState {
  const CrackState({
    required this.intensity,
    required this.impactPoint,
    required this.seed,
  });

  final double intensity;
  final Offset impactPoint;
  final int seed;

  CrackState copyWith({double? intensity, Offset? impactPoint, int? seed}) {
    return CrackState(
      intensity: intensity ?? this.intensity,
      impactPoint: impactPoint ?? this.impactPoint,
      seed: seed ?? this.seed,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CrackState &&
      other.intensity == intensity &&
      other.impactPoint == impactPoint &&
      other.seed == seed;

  @override
  int get hashCode => Object.hash(intensity, impactPoint, seed);
}

/// Procedural shattered-glass overlay. Draws a fractal-ish crack pattern
/// radiating from [CrackState.impactPoint] and animates the reveal in
/// under a second so an impact reads instantly. No assets — everything is
/// drawn each frame by a CustomPainter from a seeded RNG so the pattern
/// is reproducible and intensity-tunable.
class CrackedGlass extends StatefulWidget {
  const CrackedGlass({
    super.key,
    required this.state,
    this.color = const Color(0xFFFFFFFF),
    this.animationDuration = const Duration(milliseconds: 700),
  });

  final CrackState state;
  final Color color;
  final Duration animationDuration;

  @override
  State<CrackedGlass> createState() => _CrackedGlassState();
}

class _CrackedGlassState extends State<CrackedGlass>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
      value: 1.0, // existing cracks render fully drawn
    );
  }

  @override
  void didUpdateWidget(covariant CrackedGlass oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isNewImpact = oldWidget.state.seed != widget.state.seed ||
        oldWidget.state.impactPoint != widget.state.impactPoint;
    if (isNewImpact) {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _CrackPainter(
              state: widget.state,
              progress: _controller.value,
              color: widget.color,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _CrackSegment {
  const _CrackSegment({
    required this.from,
    required this.to,
    required this.startDistance,
    required this.endDistance,
    required this.opacity,
  });

  final Offset from;
  final Offset to;
  final double startDistance;
  final double endDistance;
  final double opacity;
}

class _CrackPainter extends CustomPainter {
  _CrackPainter({
    required this.state,
    required this.progress,
    required this.color,
  });

  final CrackState state;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (state.intensity <= 0) return;

    final origin = Offset(
      state.impactPoint.dx * size.width,
      state.impactPoint.dy * size.height,
    );
    final rng = math.Random(state.seed);

    final segments = <_CrackSegment>[];
    final scale = math.min(size.width, size.height);

    // Main radial cracks
    final mainCount = (4 + state.intensity * 10).toInt();
    for (var i = 0; i < mainCount; i++) {
      final angle = (i / mainCount) * 2 * math.pi +
          (rng.nextDouble() - 0.5) * 0.6;
      final length = scale * (0.18 + rng.nextDouble() * 0.45) *
          (0.5 + state.intensity * 0.5);
      _walkCrack(
        segments: segments,
        rng: rng,
        from: origin,
        startDistance: 0,
        angle: angle,
        remainingLength: length,
        depth: 0,
        opacity: 0.75 + rng.nextDouble() * 0.2,
      );
    }

    if (segments.isEmpty) return;

    final maxDistance = segments.fold<double>(
      0,
      (max, s) => s.endDistance > max ? s.endDistance : max,
    );
    final shown = progress * maxDistance;

    // Bright impact dot grows in over the first 30% of the animation
    final dotProgress = (progress / 0.3).clamp(0.0, 1.0);
    final dotRadius = (2.5 + state.intensity * 4) * dotProgress;
    if (dotRadius > 0) {
      canvas.drawCircle(
        origin,
        dotRadius,
        Paint()..color = color.withOpacity(0.95),
      );
      // Halo
      canvas.drawCircle(
        origin,
        dotRadius * 2.5,
        Paint()..color = color.withOpacity(0.15 * dotProgress),
      );
    }

    final baseStroke = (size.shortestSide / 600).clamp(0.8, 2.2);

    for (final seg in segments) {
      if (seg.startDistance > shown) continue;
      Offset endPoint;
      if (seg.endDistance <= shown) {
        endPoint = seg.to;
      } else {
        final t = (shown - seg.startDistance) /
            (seg.endDistance - seg.startDistance);
        endPoint = Offset.lerp(seg.from, seg.to, t)!;
      }
      final paint = Paint()
        ..color = color.withOpacity(seg.opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = baseStroke
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(seg.from, endPoint, paint);
    }
  }

  void _walkCrack({
    required List<_CrackSegment> segments,
    required math.Random rng,
    required Offset from,
    required double startDistance,
    required double angle,
    required double remainingLength,
    required int depth,
    required double opacity,
  }) {
    if (remainingLength <= 0 || depth > 3) return;
    final endDist = startDistance + remainingLength;
    var current = from;
    var dist = startDistance;
    var currentAngle = angle;

    while (dist < endDist) {
      final stepLen = 8 + rng.nextDouble() * 14;
      final nextDist = math.min(dist + stepLen, endDist);
      currentAngle += (rng.nextDouble() - 0.5) * 0.35;
      final next = current +
          Offset(math.cos(currentAngle), math.sin(currentAngle)) *
              (nextDist - dist);
      segments.add(_CrackSegment(
        from: current,
        to: next,
        startDistance: dist,
        endDistance: nextDist,
        opacity: opacity * (1 - depth * 0.2).clamp(0.3, 1.0),
      ));

      // Sub-branch
      if (depth < 2 && rng.nextDouble() < (0.18 - depth * 0.05) &&
          (endDist - nextDist) > 18) {
        final branchAngle = currentAngle +
            (rng.nextBool() ? 0.5 : -0.5) +
            (rng.nextDouble() - 0.5) * 0.4;
        final branchLength =
            (endDist - nextDist) * (0.25 + rng.nextDouble() * 0.5);
        _walkCrack(
          segments: segments,
          rng: rng,
          from: next,
          startDistance: nextDist,
          angle: branchAngle,
          remainingLength: branchLength,
          depth: depth + 1,
          opacity: opacity * 0.75,
        );
      }

      current = next;
      dist = nextDist;
    }
  }

  @override
  bool shouldRepaint(covariant _CrackPainter old) =>
      old.progress != progress || old.state != state;
}
