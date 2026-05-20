import 'package:flutter/material.dart';

import 'character_walker.dart';

/// 8-direction D-pad that emits the held direction. The host listens to
/// [onChanged] and feeds the value into [CharacterWalker.direction].
///
/// Layout is a 3x3 grid: cardinals on the edges, diagonals on the
/// corners, and a dead centre. Each cell is a press-and-hold button —
/// release returns to [WalkDir.none].
class Dpad extends StatefulWidget {
  const Dpad({
    super.key,
    required this.onChanged,
    this.diameter = 160,
    this.color = const Color(0xFFEED9B5),
  });

  final ValueChanged<WalkDir> onChanged;
  final double diameter;
  final Color color;

  @override
  State<Dpad> createState() => _DpadState();
}

class _DpadState extends State<Dpad> {
  WalkDir _active = WalkDir.none;

  void _set(WalkDir d) {
    if (_active == d) return;
    _active = d;
    widget.onChanged(d);
  }

  Widget _cell(WalkDir dir, IconData? icon) {
    final isActive = _active == dir;
    return Listener(
      onPointerDown: (_) => _set(dir),
      onPointerUp: (_) => _set(WalkDir.none),
      onPointerCancel: (_) => _set(WalkDir.none),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: dir == WalkDir.none
              ? Colors.transparent
              : (isActive
                  ? widget.color.withOpacity(0.85)
                  : widget.color.withOpacity(0.30)),
          borderRadius: BorderRadius.circular(8),
          border: dir == WalkDir.none
              ? null
              : Border.all(color: widget.color.withOpacity(0.55), width: 1),
        ),
        alignment: Alignment.center,
        child: icon == null
            ? null
            : Icon(
                icon,
                size: widget.diameter / 6,
                color: isActive ? Colors.black87 : widget.color,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cellSize = widget.diameter / 3;
    return SizedBox(
      width: widget.diameter,
      height: widget.diameter,
      child: Column(
        children: [
          Row(children: [
            SizedBox(width: cellSize, height: cellSize, child: _cell(WalkDir.upLeft, Icons.north_west)),
            SizedBox(width: cellSize, height: cellSize, child: _cell(WalkDir.up, Icons.north)),
            SizedBox(width: cellSize, height: cellSize, child: _cell(WalkDir.upRight, Icons.north_east)),
          ]),
          Row(children: [
            SizedBox(width: cellSize, height: cellSize, child: _cell(WalkDir.left, Icons.west)),
            SizedBox(width: cellSize, height: cellSize, child: _cell(WalkDir.none, null)),
            SizedBox(width: cellSize, height: cellSize, child: _cell(WalkDir.right, Icons.east)),
          ]),
          Row(children: [
            SizedBox(width: cellSize, height: cellSize, child: _cell(WalkDir.downLeft, Icons.south_west)),
            SizedBox(width: cellSize, height: cellSize, child: _cell(WalkDir.down, Icons.south)),
            SizedBox(width: cellSize, height: cellSize, child: _cell(WalkDir.downRight, Icons.south_east)),
          ]),
        ],
      ),
    );
  }
}
