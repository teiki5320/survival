import 'dart:async';

import 'package:flutter/material.dart';

/// Cardinal and intercardinal directions the heroine can walk in. `none`
/// means she is standing still.
enum WalkDir {
  none,
  left,
  right,
  up,
  down,
  upLeft,
  upRight,
  downLeft,
  downRight,
}

/// Lets the player drive the heroine around the wagon. Holds her position
/// (normalised 0..1 inside the wagon box), her current facing direction,
/// and animates a sprite-sheet walk cycle while she is moving.
///
/// For the MVP only the left-profile sprite sheet exists (25 frames). The
/// right-facing sheet is produced by horizontally flipping the same
/// frames at render time. Up / down / diagonal directions reuse the
/// profile sheet too — they will be swapped to dedicated sheets once
/// those are generated.
class CharacterWalker extends StatefulWidget {
  const CharacterWalker({
    super.key,
    required this.boxWidth,
    required this.boxHeight,
    required this.direction,
    this.initialPosition = const Offset(0.5, 0.78),
    this.heightFraction = 0.62,
    this.walkSpeed = 0.18,
    this.frameDurationMs = 60,
  });

  final double boxWidth;
  final double boxHeight;

  /// Direction the player is currently holding on the D-pad. `WalkDir.none`
  /// means no input — she stops and shows the idle frame.
  final WalkDir direction;

  /// Position when first mounted, in normalised wagon coordinates (centre
  /// of the sprite).
  final Offset initialPosition;

  /// Height of the rendered sprite as a fraction of the wagon box height
  /// (matches the existing character pose slots which were around 0.62).
  final double heightFraction;

  /// Movement speed in normalised box units per second.
  final double walkSpeed;

  /// How long each walk-cycle frame is displayed (ms). Lower = faster
  /// stride. 60ms × 25 frames = 1.5s per full cycle, which reads as a
  /// natural walking pace.
  final int frameDurationMs;

  @override
  State<CharacterWalker> createState() => _CharacterWalkerState();
}

class _CharacterWalkerState extends State<CharacterWalker> {
  // 25 walk frames live in assets/characters/walk_left_1..25.png. They
  // were extracted from an autosprite sheet so they are perfectly
  // consistent frame-to-frame.
  static const int _frameCount = 25;

  late Offset _pos;
  int _frame = 0;
  Timer? _frameTimer;
  DateTime _lastTick = DateTime.now();
  Timer? _moveTimer;

  @override
  void initState() {
    super.initState();
    _pos = widget.initialPosition;
    if (widget.direction != WalkDir.none) {
      _startMoving();
    }
  }

  @override
  void didUpdateWidget(covariant CharacterWalker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasMoving = oldWidget.direction != WalkDir.none;
    final isMoving = widget.direction != WalkDir.none;
    if (!wasMoving && isMoving) {
      _startMoving();
    } else if (wasMoving && !isMoving) {
      _stopMoving();
    }
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _moveTimer?.cancel();
    super.dispose();
  }

  void _startMoving() {
    _lastTick = DateTime.now();
    _frameTimer = Timer.periodic(
      Duration(milliseconds: widget.frameDurationMs),
      (_) => setState(() => _frame = (_frame + 1) % _frameCount),
    );
    // Move at ~60 Hz for a smooth glide rather than ticking once per frame.
    _moveTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final now = DateTime.now();
      final dt = now.difference(_lastTick).inMicroseconds / 1e6;
      _lastTick = now;
      final v = _vectorFor(widget.direction) * widget.walkSpeed * dt;
      setState(() {
        _pos = Offset(
          (_pos.dx + v.dx).clamp(0.05, 0.95),
          (_pos.dy + v.dy).clamp(0.35, 0.95),
        );
      });
    });
  }

  void _stopMoving() {
    _frameTimer?.cancel();
    _frameTimer = null;
    _moveTimer?.cancel();
    _moveTimer = null;
    // Land on a stable contact frame for the idle pose.
    setState(() => _frame = 0);
  }

  Offset _vectorFor(WalkDir dir) {
    const inv = 0.7071; // 1/sqrt(2) for normalised diagonals
    return switch (dir) {
      WalkDir.none => Offset.zero,
      WalkDir.left => const Offset(-1, 0),
      WalkDir.right => const Offset(1, 0),
      WalkDir.up => const Offset(0, -1),
      WalkDir.down => const Offset(0, 1),
      WalkDir.upLeft => const Offset(-inv, -inv),
      WalkDir.upRight => const Offset(inv, -inv),
      WalkDir.downLeft => const Offset(-inv, inv),
      WalkDir.downRight => const Offset(inv, inv),
    };
  }

  bool _facingRight(WalkDir dir) {
    return dir == WalkDir.right || dir == WalkDir.upRight || dir == WalkDir.downRight;
  }

  @override
  Widget build(BuildContext context) {
    final spriteHeight = widget.heightFraction * widget.boxHeight;
    // Sprite aspect from the autosprite frames is roughly 1:2.4 (40x96
    // bounded). Width follows the same proportion so she stays in scale.
    final spriteWidth = spriteHeight * 0.42;

    final cx = _pos.dx * widget.boxWidth;
    final cy = _pos.dy * widget.boxHeight;
    // Anchor sprite by feet rather than centre — feels more natural
    // when she walks toward the bottom of the wagon.
    final left = cx - spriteWidth / 2;
    final top = cy - spriteHeight * 0.92;

    final isMoving = widget.direction != WalkDir.none;
    final frameIndex = isMoving ? _frame : 0;
    final frameAsset = 'assets/characters/walk_left_${frameIndex + 1}.png';

    // The sheet faces left. Flip horizontally when she walks rightward
    // (the warm-from-upper-left lighting will be inverted in that case
    // but it reads acceptably while we don't have a dedicated right sheet).
    final facingRight = _facingRight(widget.direction);

    return Positioned(
      left: left,
      top: top,
      width: spriteWidth,
      height: spriteHeight,
      child: Transform(
        alignment: Alignment.center,
        transform: facingRight ? (Matrix4.identity()..scale(-1.0, 1.0, 1.0)) : Matrix4.identity(),
        child: Image.asset(frameAsset, fit: BoxFit.contain),
      ),
    );
  }
}
