import 'package:flutter/material.dart';

/// Renders a panoramic landscape behind the wagon, scrolling horizontally on
/// a slow infinite loop. Placed behind the wagon's cut-out window so it
/// reads as "the world rolling past at speed".
///
/// Loops seamlessly by rendering two consecutive copies of the same asset:
/// at any moment one is sliding off-screen left while the next is sliding
/// in from the right. Real seamless panoramas (left edge matches right
/// edge) hide the wrap point entirely; otherwise the wrap is the only
/// "jump" the eye can catch, but at a slow speed it's barely noticeable.
class ScrollingLandscape extends StatefulWidget {
  const ScrollingLandscape({
    super.key,
    required this.assetPath,
    this.cycleSeconds = 32,
    this.landscapeAspect = 4096.0 / 1000.0,
    this.enabled = true,
  });

  final String assetPath;

  /// Seconds for one full scroll cycle (one image-width worth of travel).
  final int cycleSeconds;

  /// Width / height of the landscape source image. The placeholders are
  /// 4096×1000; override if you ship a different ratio.
  final double landscapeAspect;

  /// Pauses the scroll while keeping the landscape visible. Useful when the
  /// debug toggle is flipped off.
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

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final landscapeWidth = h * widget.landscapeAspect;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final dx = -_controller.value * landscapeWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < 2; i++)
                    Positioned(
                      left: dx + i * landscapeWidth,
                      top: 0,
                      width: landscapeWidth,
                      height: h,
                      child: Image.asset(
                        widget.assetPath,
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
