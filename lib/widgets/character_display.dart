import 'package:flutter/material.dart';

import '../models/scene_config.dart';

/// Renders a character at its current pose's slot, smoothly sliding between
/// slots when the pose changes (so cycling looks like "she walked over"
/// rather than "she teleported"). Adds a soft warm halo at both endpoints
/// of the transition to anchor the eye.
class CharacterDisplay extends StatefulWidget {
  const CharacterDisplay({
    super.key,
    required this.character,
    required this.currentPose,
    required this.resolveSlot,
    required this.boxWidth,
    required this.boxHeight,
    this.transitionDuration = const Duration(milliseconds: 1400),
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
      value: 1.0, // start "fully arrived" at the current pose
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
        final t = Curves.easeInOutCubic.transform(_transition.value);

        // Position lerp: from the previous slot's pixel center to the new
        // slot's pixel center.
        final fromX = (fromSlot ?? toSlot).x * widget.boxWidth;
        final fromY = (fromSlot ?? toSlot).y * widget.boxHeight;
        final toX = toSlot.x * widget.boxWidth;
        final toY = toSlot.y * widget.boxHeight;
        final cx = fromX + (toX - fromX) * t;
        final cy = fromY + (toY - fromY) * t;

        // Size lerp: poses can have very different bounding boxes (standing
        // vs sitting); animate width/height too so the silhouette feels
        // continuous as she moves and changes pose.
        final fromW = (fromSlot ?? toSlot).width * widget.boxWidth;
        final fromH = (fromSlot ?? toSlot).height * widget.boxHeight;
        final toW = toSlot.width * widget.boxWidth;
        final toH = toSlot.height * widget.boxHeight;
        final w = fromW + (toW - fromW) * t;
        final h = fromH + (toH - fromH) * t;

        // Halo intensity: peaks at midpoint of the transition, almost zero
        // at rest. Two halos — one fading out at origin, one fading in at
        // destination — visually trace the path.
        final inTransition =
            _fromPose != null && _transition.value > 0 && _transition.value < 1;
        final haloPulse = inTransition
            ? (1 - (2 * _transition.value - 1).abs())
            : 0.0;

        return Stack(
          children: [
            if (inTransition && fromSlot != null) ...[
              _halo(
                cx: fromX,
                cy: fromY,
                size: (fromW + fromH) * 0.55,
                opacity: 0.45 * (1 - _transition.value),
              ),
              _halo(
                cx: toX,
                cy: toY,
                size: (toW + toH) * 0.55,
                opacity: 0.45 * _transition.value,
              ),
              _halo(
                cx: cx,
                cy: cy,
                size: (w + h) * 0.45,
                opacity: 0.55 * haloPulse,
              ),
            ],
            Positioned(
              left: cx - w / 2,
              top: cy - h / 2,
              width: w,
              height: h,
              child: _CrossfadingPose(pose: _toPose),
            ),
          ],
        );
      },
    );
  }

  Widget _halo({
    required double cx,
    required double cy,
    required double size,
    required double opacity,
  }) {
    if (opacity <= 0.001) return const SizedBox.shrink();
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
                  widget.haloColor.withOpacity(0.55),
                  widget.haloColor.withOpacity(0.15),
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

/// Soft cross-fade between successive pose images at the SAME size, so the
/// silhouette changes are continuous and we don't get a hard image swap.
class _CrossfadingPose extends StatelessWidget {
  const _CrossfadingPose({required this.pose});

  final CharacterPose pose;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 700),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: Image.asset(
        pose.asset,
        key: ValueKey(pose.id),
        fit: BoxFit.contain,
      ),
    );
  }
}
