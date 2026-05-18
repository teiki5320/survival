import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Wraps a child with a continuous gentle motion that reads as "a train
/// carriage rolling on rails": a slow vertical sway, a slightly faster
/// micro-rotation (offset phase so the motion doesn't feel mechanically
/// looped), and a tiny horizontal jitter for the rail click.
///
/// The child is scaled up by a hair so the rotation doesn't reveal the
/// black corners of its bounding box.
class TrainRocking extends StatefulWidget {
  const TrainRocking({
    super.key,
    required this.child,
    this.enabled = true,
    this.swayPixels = 4.0,
    this.swayPeriodMs = 2400,
    this.rotationRadians = 0.006,
    this.rotationPeriodMs = 1700,
    this.jitterPixels = 0.6,
    this.jitterPeriodMs = 420,
    this.scaleCompensation = 1.03,
  });

  final Widget child;
  final bool enabled;
  final double swayPixels;
  final int swayPeriodMs;
  final double rotationRadians;
  final int rotationPeriodMs;
  final double jitterPixels;
  final int jitterPeriodMs;
  final double scaleCompensation;

  @override
  State<TrainRocking> createState() => _TrainRockingState();
}

class _TrainRockingState extends State<TrainRocking>
    with TickerProviderStateMixin {
  AnimationController? _sway;
  AnimationController? _rotation;
  AnimationController? _jitter;

  @override
  void initState() {
    super.initState();
    _maybeStart();
  }

  @override
  void didUpdateWidget(covariant TrainRocking oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.swayPeriodMs != widget.swayPeriodMs ||
        oldWidget.rotationPeriodMs != widget.rotationPeriodMs ||
        oldWidget.jitterPeriodMs != widget.jitterPeriodMs) {
      _disposeControllers();
      _maybeStart();
    }
  }

  void _maybeStart() {
    if (!widget.enabled) return;
    _sway = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.swayPeriodMs),
    )..repeat();
    _rotation = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.rotationPeriodMs),
    )..repeat();
    _jitter = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.jitterPeriodMs),
    )..repeat();
  }

  void _disposeControllers() {
    _sway?.dispose();
    _rotation?.dispose();
    _jitter?.dispose();
    _sway = null;
    _rotation = null;
    _jitter = null;
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || _sway == null) return widget.child;

    return AnimatedBuilder(
      animation: Listenable.merge([_sway, _rotation, _jitter]),
      builder: (context, child) {
        final dy = widget.swayPixels *
            math.sin(_sway!.value * 2 * math.pi);
        final dx = widget.jitterPixels *
            math.sin(_jitter!.value * 2 * math.pi);
        final angle = widget.rotationRadians *
            math.sin(_rotation!.value * 2 * math.pi);
        return Transform.scale(
          scale: widget.scaleCompensation,
          child: Transform.rotate(
            angle: angle,
            child: Transform.translate(
              offset: Offset(dx, dy),
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
