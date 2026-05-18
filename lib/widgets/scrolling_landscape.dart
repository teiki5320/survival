import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Rear-view recede effect: the landscape continuously shrinks toward the
/// center of the window, like the world receding as the train leaves it
/// behind. Two phase-offset layers cross-fade through the cycle so the
/// motion never visibly resets — at any moment at least one layer is at a
/// natural opacity while another is fading in or out at the cycle edges.
///
/// Despite the file name (kept for git history), this is no longer a
/// lateral scroll — it's a center-anchored zoom-out.
class ScrollingLandscape extends StatefulWidget {
  const ScrollingLandscape({
    super.key,
    required this.assetPath,
    this.cycleSeconds = 10,
    this.startScale = 1.55,
    this.endScale = 1.0,
    this.enabled = true,
  });

  final String assetPath;
  final int cycleSeconds;

  /// Scale of the layer when it appears (closest to camera, just left
  /// behind by the moving train).
  final double startScale;

  /// Scale of the layer when it fades out (furthest from camera, vanished
  /// into the horizon).
  final double endScale;

  final bool enabled;

  @override
  State<ScrollingLandscape> createState() => _ScrollingLandscapeState();
}

class _ScrollingLandscapeState extends State<ScrollingLandscape>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.cycleSeconds),
    );
    if (widget.enabled) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant ScrollingLandscape oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cycleSeconds != widget.cycleSeconds) {
      _controller.duration = Duration(seconds: widget.cycleSeconds);
      if (_controller.isAnimating) _controller.repeat();
    }
    if (oldWidget.enabled != widget.enabled) {
      if (widget.enabled) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Scale at progress [layerT] in [0, 1]. Starts close (startScale), ends
  /// far (endScale).
  double _scaleFor(double layerT) {
    return widget.startScale +
        (widget.endScale - widget.startScale) * layerT;
  }

  /// Opacity curve over a layer's lifecycle: 0 at the extremes, ~1 in the
  /// middle. Half-sine gives a smooth fade-in / fade-out at the edges.
  double _opacityFor(double layerT) {
    return math.sin(layerT * math.pi);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      // Static, no animation — easier to compare and useful for screenshots.
      return Image.asset(
        widget.assetPath,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }

    return ClipRect(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final tB = (t + 0.5) % 1.0;
          return Stack(
            fit: StackFit.expand,
            children: [
              _layer(t),
              _layer(tB),
            ],
          );
        },
      ),
    );
  }

  Widget _layer(double layerT) {
    return IgnorePointer(
      child: Opacity(
        opacity: _opacityFor(layerT),
        child: Transform.scale(
          scale: _scaleFor(layerT),
          alignment: Alignment.center,
          child: Image.asset(
            widget.assetPath,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}
