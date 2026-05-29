import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/game_state.dart';

/// Tier 1 du bois : grille 5×4 de forêt.
/// - Énergie 10 par visite.
/// - Cases avec branche (+2 bois, 1 énergie), bûche (+5, 2 énergie),
///   arbre mort (+10, 5 énergie).
/// - Quitter à tout moment, ramène le bois récolté.
class WoodGameTier1 extends StatefulWidget {
  const WoodGameTier1({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  State<WoodGameTier1> createState() => _WoodGameTier1State();
}

enum _CellType { empty, branch, log, deadTree }

class _Cell {
  _Cell(this.type);
  _CellType type;
}

class _WoodGameTier1State extends State<WoodGameTier1> {
  static const _cols = 5;
  static const _rows = 4;
  late final List<_Cell> _grid;
  int _energy = 10;
  int _collected = 0;
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _grid = List.generate(_cols * _rows, (_) {
      final r = _rng.nextDouble();
      if (r < 0.35) return _Cell(_CellType.branch);
      if (r < 0.55) return _Cell(_CellType.log);
      if (r < 0.62) return _Cell(_CellType.deadTree);
      return _Cell(_CellType.empty);
    });
  }

  int _costFor(_CellType t) {
    switch (t) {
      case _CellType.branch:
        return 1;
      case _CellType.log:
        return 2;
      case _CellType.deadTree:
        return 5;
      case _CellType.empty:
        return 0;
    }
  }

  int _yieldFor(_CellType t) {
    switch (t) {
      case _CellType.branch:
        return 2;
      case _CellType.log:
        return 5;
      case _CellType.deadTree:
        return 10;
      case _CellType.empty:
        return 0;
    }
  }

  void _gather(int i) {
    final cell = _grid[i];
    if (cell.type == _CellType.empty) return;
    final cost = _costFor(cell.type);
    if (_energy < cost) return;
    setState(() {
      _energy -= cost;
      _collected += _yieldFor(cell.type);
      cell.type = _CellType.empty;
    });
  }

  void _leave() {
    if (_collected > 0) {
      GameState.instance.grantItem('wood', _collected);
    }
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xCC0A120A),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text('Forêt — tier 1',
                          style: TextStyle(
                            color: Color(0xFFFFD9A0),
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                          )),
                      const Spacer(),
                      _label(Icons.bolt, _energy,
                          const Color(0xFFE89B5C)),
                      const SizedBox(width: 12),
                      _label(Icons.local_fire_department, _collected,
                          const Color(0xFFD4884A)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap case → ramasser (1-5 énergie). "Repartir" pour ramener le bois.',
                    style: TextStyle(color: Color(0xFF8B6F4E), fontSize: 11),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _cols,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: _grid.length,
                      itemBuilder: (_, i) => _cellView(i),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _leave,
                    icon: const Icon(Icons.exit_to_app),
                    label: Text(_collected > 0
                        ? 'Repartir avec $_collected bois'
                        : 'Repartir'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFB85522),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: IconButton(
                icon: const Icon(Icons.close,
                    color: Color(0xFFFFD9A0), size: 28),
                onPressed: _leave,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cellView(int i) {
    final cell = _grid[i];
    IconData icon;
    Color color;
    String label = '';
    switch (cell.type) {
      case _CellType.empty:
        icon = Icons.grass;
        color = const Color(0xFF2E3A1F);
      case _CellType.branch:
        icon = Icons.spa;
        color = const Color(0xFF8FAF6C);
        label = '+2';
      case _CellType.log:
        icon = Icons.view_in_ar;
        color = const Color(0xFFB8945C);
        label = '+5';
      case _CellType.deadTree:
        icon = Icons.park;
        color = const Color(0xFF6B4226);
        label = '+10';
    }
    final cost = _costFor(cell.type);
    final canAfford = _energy >= cost && cell.type != _CellType.empty;
    return GestureDetector(
      onTap: canAfford ? () => _gather(i) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: canAfford ? color : color.withValues(alpha: 0.3),
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: canAfford ? color : color.withValues(alpha: 0.3),
                size: 28),
            if (label.isNotEmpty)
              Text(label,
                  style: TextStyle(
                    color: canAfford ? color : color.withValues(alpha: 0.3),
                    fontSize: 11,
                    fontFamily: 'Courier',
                  )),
            if (cost > 0)
              Text('-$cost⚡',
                  style: TextStyle(
                    color: const Color(0xFFE89B5C)
                        .withValues(alpha: canAfford ? 0.8 : 0.3),
                    fontSize: 9,
                  )),
          ],
        ),
      ),
    );
  }

  Widget _label(IconData icon, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text('$count',
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontFamily: 'Courier',
              fontWeight: FontWeight.w600,
            )),
      ],
    );
  }
}
