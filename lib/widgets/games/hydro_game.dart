import 'package:flutter/material.dart';

import '../../models/game_state.dart';

/// Prototype hydro tier 1 — 2 pots + 4 boutons.
/// 7 stades de croissance (planted → ripe) via sprites pixel art.
/// Passer = avance d'un step (uniquement les pots arrosés).
/// Arroser nécessaire après 2 Passer (sinon stagnation).
class HydroGameTier1 extends StatefulWidget {
  const HydroGameTier1({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  State<HydroGameTier1> createState() => _HydroGameTier1State();
}

class _Pot {
  int? stage; // null = vide, 0..6 = planted..ripe
  bool watered = true;
  int dryCounter = 0;
}

const _stages = [
  'planted', 'sprout', 'small', 'medium', 'large', 'huge', 'ripe'
];

class _HydroGameTier1State extends State<HydroGameTier1> {
  final List<_Pot> _pots = [_Pot(), _Pot()];

  bool get _canSeed => _pots.any((p) => p.stage == null);
  bool get _canWater => _pots.any((p) => p.stage != null && !p.watered);
  bool get _canHarvest => _pots.any((p) => p.stage == 6);

  void _seed() {
    final p = _pots.firstWhere((p) => p.stage == null,
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
    final p = _pots.firstWhere((p) => p.stage == 6,
        orElse: () => _pots.first);
    if (p.stage != 6) return;
    setState(() {
      p.stage = null;
      p.watered = true;
    });
    GameState.instance.grantItem('food', 15);
  }

  void _passStep() {
    setState(() {
      for (final p in _pots) {
        if (p.stage == null) continue;
        if (!p.watered) continue;
        if (p.stage! < 6) {
          p.stage = p.stage! + 1;
        }
        p.dryCounter++;
        if (p.dryCounter >= 2) {
          p.watered = false;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8D8B0),
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
                          'Potager (proto)',
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
                    const SizedBox(height: 32),
                    // Les 2 pots.
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (final p in _pots) _potView(p),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // 3 boutons d'action.
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
                    const SizedBox(height: 16),
                    // Bouton Passer.
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
                            textStyle:
                                const TextStyle(fontSize: 16),
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

  Widget _potView(_Pot p) {
    final stage = p.stage;
    final spriteAsset = stage != null
        ? 'assets/plants/carrot_${_stages[stage]}.png'
        : null;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Plante au-dessus du pot.
        SizedBox(
          width: 160,
          height: 160,
          child: spriteAsset != null
              ? Image.asset(
                  spriteAsset,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none, // pixel art = nearest
                )
              : Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0x33000000),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    width: 140,
                    height: 140,
                    child: const Center(
                      child: Icon(Icons.circle_outlined,
                          color: Color(0x88000000), size: 48),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 4),
        // Pot (juste un rectangle stylisé en attendant un vrai asset).
        Container(
          width: 110,
          height: 60,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF8B4A1A), Color(0xFF4A2810)],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(14),
            ),
            border: Border.all(color: const Color(0xFF2A1A0E), width: 1.6),
          ),
        ),
        const SizedBox(height: 8),
        // Indicateur thirsty / OK.
        if (p.stage != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                p.watered ? Icons.water_drop : Icons.warning_amber,
                color: p.watered
                    ? const Color(0xFF3A78AE)
                    : const Color(0xFFE05A4D),
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                p.stage == 6
                    ? 'Mûr !'
                    : p.watered
                        ? '${_stages[p.stage!]}'
                        : 'A soif',
                style: TextStyle(
                  color: p.stage == 6
                      ? const Color(0xFFB85522)
                      : p.watered
                          ? const Color(0xFF3A2E1F)
                          : const Color(0xFFE05A4D),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 130,
      child: FilledButton.icon(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 18),
        label: Text(label,
            style: const TextStyle(fontSize: 12, letterSpacing: 0)),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFB85522),
          disabledBackgroundColor: const Color(0xFF8B6F4E)
              .withValues(alpha: 0.4),
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
