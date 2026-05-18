import 'package:flutter/material.dart';

import '../services/scene_state.dart';

/// Visual editor overlay for the rear-window rectangle.
///
/// Draws a dashed outline around the current [SceneState.effectiveWindowArea]
/// and four large draggable corner handles. Dragging a corner updates the
/// runtime override; the live JSON for `windowArea` is shown at the top
/// of the screen so the values can be copied back into scene.json once
/// the fit looks right.
class WindowCornerEditor extends StatelessWidget {
  const WindowCornerEditor({
    super.key,
    required this.state,
    required this.boxWidth,
    required this.boxHeight,
  });

  final SceneState state;
  final double boxWidth;
  final double boxHeight;

  static const double _handleRadius = 22;
  static const Color _handleColor = Color(0xFFFFD400);
  static const Color _outlineColor = Color(0xFFFFD400);

  @override
  Widget build(BuildContext context) {
    final rect = state.effectiveWindowArea;
    final leftPx = rect.left * boxWidth;
    final topPx = rect.top * boxHeight;
    final widthPx = rect.width * boxWidth;
    final heightPx = rect.height * boxHeight;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Dashed outline rectangle of the current window area.
        Positioned(
          left: leftPx,
          top: topPx,
          width: widthPx,
          height: heightPx,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: _outlineColor, width: 2),
              ),
            ),
          ),
        ),
        _cornerHandle(WindowCorner.topLeft, leftPx, topPx),
        _cornerHandle(WindowCorner.topRight, leftPx + widthPx, topPx),
        _cornerHandle(WindowCorner.bottomLeft, leftPx, topPx + heightPx),
        _cornerHandle(WindowCorner.bottomRight, leftPx + widthPx, topPx + heightPx),
        _coordReadout(rect),
      ],
    );
  }

  Widget _cornerHandle(WindowCorner corner, double cx, double cy) {
    return Positioned(
      left: cx - _handleRadius,
      top: cy - _handleRadius,
      width: _handleRadius * 2,
      height: _handleRadius * 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          final dx = details.delta.dx / boxWidth;
          final dy = details.delta.dy / boxHeight;
          state.dragWindowCorner(corner, dx, dy);
        },
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _handleColor.withOpacity(0.35),
            border: Border.all(color: _handleColor, width: 3),
          ),
        ),
      ),
    );
  }

  Widget _coordReadout(Rect rect) {
    final json = '"windowArea": { '
        '"x": ${rect.left.toStringAsFixed(3)}, '
        '"y": ${rect.top.toStringAsFixed(3)}, '
        '"width": ${rect.width.toStringAsFixed(3)}, '
        '"height": ${rect.height.toStringAsFixed(3)} '
        '}';
    return Positioned(
      left: 16,
      top: 16,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            json,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }
}
