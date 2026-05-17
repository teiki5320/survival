import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/scene_config.dart';

/// Wraps a child with a discreet looping animation.
///
/// The animation is purely decorative: a slow scale (breathing), a gentle
/// opacity wave (flickering), or a small lateral sway (swaying). With
/// [WagonAnimation.none] the child is returned unchanged.
class AnimatedObject extends StatefulWidget {
  const AnimatedObject({
    super.key,
    required this.animation,
    required this.child,
  });

  final WagonAnimation animation;
  final Widget child;

  @override
  State<AnimatedObject> createState() => _AnimatedObjectState();
}

class _AnimatedObjectState extends State<AnimatedObject>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  @override
  void didUpdateWidget(covariant AnimatedObject oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      _controller?.dispose();
      _controller = null;
      _setupController();
    }
  }

  void _setupController() {
    if (widget.animation == WagonAnimation.none) return;
    _controller = AnimationController(
      vsync: this,
      duration: switch (widget.animation) {
        WagonAnimation.breathing => const Duration(milliseconds: 3200),
        WagonAnimation.flickering => const Duration(milliseconds: 1800),
        WagonAnimation.swaying => const Duration(milliseconds: 4200),
        WagonAnimation.none => const Duration(seconds: 1),
      },
    )..repeat();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return widget.child;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = controller.value;
        switch (widget.animation) {
          case WagonAnimation.breathing:
            // Smooth 1.0 -> 1.03 -> 1.0
            final scale = 1.0 + 0.03 * math.sin(t * 2 * math.pi);
            return Transform.scale(scale: scale, child: child);
          case WagonAnimation.flickering:
            // 0.78 -> 1.0 -> 0.78 with a hint of a secondary jitter.
            final base = 0.89 + 0.11 * math.sin(t * 2 * math.pi);
            final jitter = 0.04 * math.sin(t * 2 * math.pi * 5);
            return Opacity(opacity: (base + jitter).clamp(0.0, 1.0), child: child);
          case WagonAnimation.swaying:
            final dx = 6 * math.sin(t * 2 * math.pi);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          case WagonAnimation.none:
            return child!;
        }
      },
      child: widget.child,
    );
  }
}
