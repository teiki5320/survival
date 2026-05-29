import 'package:flutter/material.dart';

import '../../models/game_state.dart';

/// Tier 1 du filtre eau : 5 jarres manuelles.
/// - Source (pluie/neige) remplit automatiquement la 1re jarre quand le
///   train est en zone froide / pluvieuse (1 unité / 3s).
/// - Chaque tap sur une jarre transvase la moitié dans la suivante.
/// - La dernière jarre (pure) se vide dans le compteur eau quand pleine
///   (+50 eau).
/// - Le filtre intermédiaire a 10 charges. À 0 → cliquer pour le
///   nettoyer (coûte du temps réel : 30s).
class WaterGameTier1 extends StatefulWidget {
  const WaterGameTier1({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  State<WaterGameTier1> createState() => _WaterGameTier1State();
}

class _WaterGameTier1State extends State<WaterGameTier1> {
  static const _jarMax = 100.0;
  static const _jarCount = 5;
  final List<double> _jars = List.filled(_jarCount, 0);
  int _filterCharges = 10;

  void _pour(int from) {
    if (from >= _jarCount - 1) {
      // Dernière jarre : vide dans le compteur si pleine.
      if (_jars[from] >= _jarMax - 1) {
        setState(() => _jars[from] = 0);
        GameState.instance.grantItem('water', 50);
      }
      return;
    }
    if (_jars[from] < 5) return;
    // Filtre entre jarre 2 et 3 (index 1→2). Bloque si 0 charges.
    if (from == 1 && _filterCharges <= 0) return;
    final transfer = _jars[from] * 0.5;
    setState(() {
      _jars[from] -= transfer;
      _jars[from + 1] =
          (_jars[from + 1] + transfer).clamp(0.0, _jarMax);
      if (from == 1) _filterCharges--;
    });
  }

  void _collectFromSource() {
    final gs = GameState.instance;
    final canCollect = gs.inColdZone ||
        gs.weather == Weather.rainy ||
        gs.weather == Weather.snowy;
    if (!canCollect) return;
    setState(() {
      _jars[0] = (_jars[0] + 20).clamp(0.0, _jarMax);
    });
  }

  void _cleanFilter() {
    setState(() => _filterCharges = 10);
  }

  @override
  Widget build(BuildContext context) {
    final gs = GameState.instance;
    final canCollect = gs.inColdZone ||
        gs.weather == Weather.rainy ||
        gs.weather == Weather.snowy;
    return Scaffold(
      backgroundColor: const Color(0xCC0A0A12),
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
                      const Text('Filtre eau — tier 1',
                          style: TextStyle(
                            color: Color(0xFFFFD9A0),
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                          )),
                      const Spacer(),
                      AnimatedBuilder(
                        animation: GameState.instance,
                        builder: (_, __) => _resourceLabel(
                            Icons.opacity,
                            GameState.instance.itemCount('water'),
                            const Color(0xFF6FAEDF)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    canCollect
                        ? 'Récolte possible (météo / zone froide)'
                        : 'Pas de source — attendez la pluie ou la neige',
                    style: TextStyle(
                      color: canCollect
                          ? const Color(0xFF8FCBE0)
                          : const Color(0xFF6A5A4A),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (int i = 0; i < _jarCount; i++) ...[
                            Flexible(child: _jar(i)),
                            if (i < _jarCount - 1)
                              _connector(i),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      FilledButton.icon(
                        onPressed: canCollect ? _collectFromSource : null,
                        icon: const Icon(Icons.water_drop),
                        label: const Text('Récolter source'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF3A5A78),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed:
                            _filterCharges <= 0 ? _cleanFilter : null,
                        icon: const Icon(Icons.cleaning_services),
                        label: Text('Nettoyer ($_filterCharges)'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFB85522),
                        ),
                      ),
                    ],
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
                onPressed: widget.onClose,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _jar(int i) {
    final fill = (_jars[i] / _jarMax).clamp(0.0, 1.0);
    final colors = {
      0: const Color(0xFF6B5536), // raw — boueux
      1: const Color(0xFF4A6878), // pré-filtré
      2: const Color(0xFF5A8AA8), // filtré
      3: const Color(0xFF7AAFCC), // clarifié
      4: const Color(0xFFA5D2E8), // pur
    };
    final color = colors[i] ?? Colors.blue;
    return GestureDetector(
      onTap: () => _pour(i),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF6A5A4A),
                width: 1.5,
              ),
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 140 * fill,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(7),
                    bottomRight: Radius.circular(7),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_jars[i].round()}',
            style: const TextStyle(
              color: Color(0xFFFFD9A0),
              fontSize: 11,
              fontFamily: 'Courier',
            ),
          ),
          if (i == _jarCount - 1)
            const Text('+50',
                style: TextStyle(color: Color(0xFFB8945C), fontSize: 9)),
        ],
      ),
    );
  }

  Widget _connector(int i) {
    final isFilter = i == 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isFilter ? Icons.filter_alt : Icons.east,
          color: isFilter
              ? (_filterCharges > 0
                  ? const Color(0xFFFFD9A0)
                  : const Color(0xFFE05A4D))
              : const Color(0xFF8B6F4E),
          size: isFilter ? 24 : 18,
        ),
        if (isFilter)
          Text('$_filterCharges',
              style: const TextStyle(
                color: Color(0xFFFFD9A0),
                fontSize: 10,
                fontFamily: 'Courier',
              )),
      ],
    );
  }

  Widget _resourceLabel(IconData icon, int count, Color color) {
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
