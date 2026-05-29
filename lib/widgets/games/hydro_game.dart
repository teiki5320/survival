import 'package:flutter/material.dart';

import '../../models/game_state.dart';

/// Prototype hydro tier 1 — installation hydroponique vue du dessus
/// avec 6 emplacements (3×2). 5 stades de croissance via sprites
/// pixel art carrot_*.png.
///
/// Boutons:
/// - Semer carotte → premier pot vide
/// - Arroser → premier pot assoiffé
/// - Récolter → premier pot mûr (+15 food)
/// - Passer → avance tous les pots arrosés d'un step
class HydroGameTier1 extends StatefulWidget {
  const HydroGameTier1({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  State<HydroGameTier1> createState() => _HydroGameTier1State();
}

class _Pot {
  int? stage; // null = vide, 0..4 = sprout → huge
  bool watered = true;
  int dryCounter = 0;
  bool showingRipe = false;
}

const _stages = ['sprout', 'small', 'medium', 'large', 'huge'];

// Positions normalisées des 6 cups dans l'image hydro_tank.png (1376×768).
// 3 colonnes × 2 rangées.
const _cupPositions = [
  Offset(0.27, 0.36), Offset(0.50, 0.36), Offset(0.73, 0.36), // front
  Offset(0.27, 0.63), Offset(0.50, 0.63), Offset(0.73, 0.63), // back
];

class _HydroGameTier1State extends State<HydroGameTier1> {
  final List<_Pot> _pots = List.generate(6, (_) => _Pot());

  bool get _canSeed => _pots.any((p) => p.stage == null && !p.showingRipe);
  bool get _canWater => _pots.any((p) => p.stage != null && !p.watered);
  bool get _canHarvest =>
      _pots.any((p) => p.stage == 4 && !p.showingRipe);

  void _seed() {
    final p = _pots.firstWhere(
        (p) => p.stage == null && !p.showingRipe,
        orElse: () => _pots.first);
    if (p.stage != null) return;
    setState(() {
      p.stage = 0;
      p.watered = true;
      p.dryCounter = 0;
    });
  }

  void _water() {
    final p = _pots.firstWhere(
        (p) => p.stage != null && !p.watered,
        orElse: () => _pots.first);
    if (p.stage == null || p.watered) return;
    setState(() {
      p.watered = true;
      p.dryCounter = 0;
    });
  }

  void _harvest() {
    final p = _pots.firstWhere(
        (p) => p.stage == 4 && !p.showingRipe,
        orElse: () => _pots.first);
    if (p.stage != 4) return;
    setState(() {
      p.showingRipe = true;
    });
    GameState.instance.grantItem('food', 15);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        p.stage = null;
        p.watered = true;
        p.dryCounter = 0;
        p.showingRipe = false;
      });
    });
  }

  void _passStep() {
    setState(() {
      for (final p in _pots) {
        if (p.stage == null) continue;
        if (p.showingRipe) continue;
        if (!p.watered) continue;
        if (p.stage! < 4) {
          p.stage = p.stage! + 1;
        }
        p.dryCounter++;
        if (p.dryCounter >= 2) p.watered = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8DDC0),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: GameState.instance,
          builder: (_, __) => Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Potager hydroponique',
                          style: TextStyle(
                            color: Color(0xFF3A2E1F),
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        _chip(Icons.restaurant_menu,
                            GameState.instance.itemCount('food'),
                            const Color(0xFFB85522)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(child: _tankView()),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _actionButton(
                          label: 'Semer carotte',
                          icon: Icons.spa,
                          enabled: _canSeed,
                          onTap: _seed,
                        ),
                        _actionButton(
                          label: 'Arroser',
                          icon: Icons.water_drop,
                          enabled: _canWater,
                          onTap: _water,
                        ),
                        _actionButton(
                          label: 'Récolter',
                          icon: Icons.agriculture,
                          enabled: _canHarvest,
                          onTap: _harvest,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: SizedBox(
                        width: 200,
                        child: FilledButton.icon(
                          onPressed: _passStep,
                          icon: const Icon(Icons.skip_next),
                          label: const Text('Passer un step'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF6B4226),
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            textStyle: const TextStyle(fontSize: 16),
                          ),
                        ),
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
                      color: Color(0xFF3A2E1F), size: 28),
                  onPressed: widget.onClose,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tankView() {
    return Center(
      child: AspectRatio(
        aspectRatio: 1376 / 768,
        child: LayoutBuilder(
          builder: (_, c) {
            final w = c.maxWidth;
            final h = c.maxHeight;
            return Stack(
              children: [
                // Background : la cuve hydroponique vue du dessus.
                Positioned.fill(
                  child: Image.asset(
                    'assets/background/hydro_tank.png',
                    fit: BoxFit.contain,
                  ),
                ),
                // 6 plantes superposées sur les cups.
                for (int i = 0; i < _pots.length; i++)
                  _plantOverlay(i, _pots[i], w, h),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _plantOverlay(int i, _Pot p, double w, double h) {
    final pos = _cupPositions[i];
    String? spriteAsset;
    if (p.showingRipe) {
      spriteAsset = 'assets/plants/carrot_ripe.png';
    } else if (p.stage != null) {
      spriteAsset = 'assets/plants/carrot_${_stages[p.stage!]}.png';
    }
    final size = h * 0.50;
    return Positioned(
      left: pos.dx * w - size / 2,
      top: pos.dy * h - size * 0.75, // décale vers le haut pour pousser hors du cup
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (spriteAsset != null)
            Positioned.fill(
              child: Image.asset(
                spriteAsset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none, // pixel art net
              ),
            ),
          // Indicateur soif au-dessus du cup.
          if (p.stage != null && !p.watered && !p.showingRipe)
            Positioned(
              top: -8,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Color(0xFFE05A4D),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber,
                    color: Colors.white, size: 14),
              ),
            ),
          // Indicateur mûr.
          if (p.stage == 4 && !p.showingRipe)
            Positioned(
              top: -8,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Color(0xFFB85522),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check,
                    color: Colors.white, size: 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 140,
      child: FilledButton.icon(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 18),
        label: Text(label,
            style: const TextStyle(fontSize: 12, letterSpacing: 0)),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFB85522),
          disabledBackgroundColor:
              const Color(0xFF8B6F4E).withValues(alpha: 0.4),
          foregroundColor: Colors.white,
          padding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text('$count',
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }
}
