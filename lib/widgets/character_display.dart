import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/scene_config.dart';

/// Renders a character at its current pose's slot. When the pose changes,
/// the character does NOT visibly walk between positions — instead:
///
///   1. She fades out at the old slot (first ~25% of the transition).
///   2. A warm halo travels in a soft arc from the old slot to the new slot,
///      brightest at the midpoint.
///   3. She fades back in at the new slot (last ~25% of the transition).
///
/// The effect reads as "her presence moves" rather than "she walks there",
/// which is more mystical and avoids the awkwardness of seeing a static
/// pose slide across the floor.
class CharacterDisplay extends StatefulWidget {
  const CharacterDisplay({
    super.key,
    required this.character,
    required this.currentPose,
    required this.resolveSlot,
    required this.boxWidth,
    required this.boxHeight,
    this.transitionDuration = const Duration(milliseconds: 1800),
    this.haloColor = const Color(0xFFFFD79A),
  });

  final CharacterConfig character;
  final CharacterPose currentPose;
  final SlotConfig Function(CharacterPose pose) resolveSlot;
  final double boxWidth;
  final double boxHeight;
  final Duration transitionDuration;
  final Color haloColor;

  @override
  State<CharacterDisplay> createState() => _CharacterDisplayState();
}

class _CharacterDisplayState extends State<CharacterDisplay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _transition;
  CharacterPose? _fromPose;
  late CharacterPose _toPose;

  @override
  void initState() {
    super.initState();
    _toPose = widget.currentPose;
    _transition = AnimationController(
      vsync: this,
      duration: widget.transitionDuration,
      value: 1.0, // start "fully arrived"
    );
  }

  @override
  void didUpdateWidget(covariant CharacterDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transitionDuration != widget.transitionDuration) {
      _transition.duration = widget.transitionDuration;
    }
    if (oldWidget.currentPose.id != widget.currentPose.id) {
      _fromPose = oldWidget.currentPose;
      _toPose = widget.currentPose;
      _transition
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _transition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fromSlot =
        _fromPose != null ? widget.resolveSlot(_fromPose!) : null;
    final toSlot = widget.resolveSlot(_toPose);

    return AnimatedBuilder(
      animation: _transition,
      builder: (context, _) {
        final t = _transition.value;
        final isTransitioning = _fromPose != null && t < 1.0;

        // Phase split: 0..0.25 = fade out at A, 0.25..0.75 = halo travels,
        // 0.75..1.0 = fade in at B.
        const fadeOutEnd = 0.25;
        const fadeInStart = 0.75;

        final fromOpacity = isTransitioning && t < fadeOutEnd
            ? 1.0 - (t / fadeOutEnd)
            : 0.0;
        final toOpacity = isTransitioning
            ? (t < fadeInStart
                ? 0.0
                : ((t - fadeInStart) / (1.0 - fadeInStart)).clamp(0.0, 1.0))
            : 1.0;

        // Pixel coordinates of both endpoints.
        final boxW = widget.boxWidth;
        final boxH = widget.boxHeight;
        final fromX = (fromSlot ?? toSlot).x * boxW;
        final fromY = (fromSlot ?? toSlot).y * boxH;
        final toX = toSlot.x * boxW;
        final toY = toSlot.y * boxH;

        // Halo position: lerp with eased curve and a slight upward arc so
        // her "spirit" lifts off the floor briefly while crossing.
        final tEase = Curves.easeInOut.transform(t);
        final cx = fromX + (toX - fromX) * tEase;
        final straightY = fromY + (toY - fromY) * tEase;
        // Arc height in pixels relative to the travel distance.
        final dist = math.sqrt(
          math.pow(toX - fromX, 2).toDouble() +
              math.pow(toY - fromY, 2).toDouble(),
        );
        final arcLift = math.sin(tEase * math.pi) * dist * 0.10;
        final cy = straightY - arcLift;

        // Halo intensity: sin curve, peaks at the midpoint.
        final haloPulse = isTransitioning ? math.sin(t * math.pi) : 0.0;
        final haloSize = isTransitioning
            ? _haloSizeFor(fromSlot ?? toSlot, toSlot, t, boxW, boxH)
            : 0.0;

        return Stack(
          children: [
            if (isTransitioning) ...[
              _halo(cx, cy, haloSize, 0.65 * haloPulse),
              // Smaller secondary glow ahead of the main halo, for the
              // "shooting star" feel.
              if (t > 0.15 && t < 0.85)
                _halo(
                  cx + (toX - fromX) * 0.08,
                  cy + (toY - fromY) * 0.08 - arcLift * 0.5,
                  haloSize * 0.55,
                  0.35 * haloPulse,
                ),
            ],
            // Character at OLD position, fading out.
            if (fromSlot != null && fromOpacity > 0)
              _positionedPose(
                pose: _fromPose!,
                slot: fromSlot,
                opacity: fromOpacity,
              ),
            // Character at NEW position, fading in (or fully visible at rest).
            if (toOpacity > 0)
              _positionedPose(
                pose: _toPose,
                slot: toSlot,
                opacity: toOpacity,
              ),
          ],
        );
      },
    );
  }

  double _haloSizeFor(
    SlotConfig fromSlot,
    SlotConfig toSlot,
    double t,
    double boxW,
    double boxH,
  ) {
    // Halo grows to match the larger of the two pose bounding boxes at the
    // midpoint, then shrinks back.
    final fromDiag = fromSlot.width * boxW + fromSlot.height * boxH;
    final toDiag = toSlot.width * boxW + toSlot.height * boxH;
    final maxDiag = math.max(fromDiag, toDiag);
    final base = maxDiag * 0.45;
    // Larger at midpoint.
    final scale = 0.7 + 0.6 * math.sin(t * math.pi);
    return base * scale;
  }

  Widget _positionedPose({
    required CharacterPose pose,
    required SlotConfig slot,
    required double opacity,
  }) {
    final width = slot.width * widget.boxWidth;
    final height = slot.height * widget.boxHeight;
    final left = slot.x * widget.boxWidth - width / 2;
    final top = slot.y * widget.boxHeight - height / 2;
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Opacity(
        opacity: opacity,
        child: Image.asset(pose.asset, fit: BoxFit.contain),
      ),
    );
  }

  Widget _halo(double cx, double cy, double size, double opacity) {
    if (opacity <= 0.001 || size <= 0) return const SizedBox.shrink();
    return Positioned(
      left: cx - size / 2,
      top: cy - size / 2,
      width: size,
      height: size,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  widget.haloColor.withOpacity(0.65),
                  widget.haloColor.withOpacity(0.20),
                  widget.haloColor.withOpacity(0.0),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
