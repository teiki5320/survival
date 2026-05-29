import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/game_state.dart';

/// Tier 1 du potager hydroponique : 4 pots simples.
/// - Tap pot vide → menu graines (tomate, blé, herbe médicinale).
/// - Plant pousse en X secondes (compressé).
/// - Tap pot pousse + sec → arrose (consomme 1 eau du compteur).
/// - Tap pot mûr → récolte (+food au compteur).
class HydroGameTier1 extends StatefulWidget {
  const HydroGameTier1({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  State<HydroGameTier1> createState() => _HydroGameTier1State();
}

enum _PotState { empty, planted, ready, dead }

class _Pot {
  _PotState state = _PotState.empty;
  String? seed;
  double growth = 0; // 0..1
  double hydration = 1.0; // 0..1
}

class _Seed {
  const _Seed(this.id, this.label, this.icon, this.growSeconds, this.yield);
  final String id;
  final String label;
  final IconData icon;
  final double growSeconds;
  final int yield;
}

const _seeds = [
  _Seed('tomato', 'Tomate', Icons.lunch_dining, 30, 10),
  _Seed('wheat', 'Blé', Icons.grass, 60, 30),
  _Seed('herb', 'Herbe', Icons.local_florist, 20, 5),
];

class _HydroGameTier1State extends State<HydroGameTier1> {
  final List<_Pot> _pots = List.generate(4, (_) => _Pot());
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _tick();
    });
  }

  void _tick() {
    bool changed = false;
    for (final pot in _pots) {
      if (pot.state != _PotState.planted) continue;
      final seed = _seeds.firstWhere((s) => s.id == pot.seed,
          orElse: () => _seeds[0]);
      final dt = 0.5;
      // Hydration baisse de 0.05/s.
      pot.hydration -= 0.05 * dt;
      if (pot.hydration <= 0) {
        pot.state = _PotState.dead;
        changed = true;
        continue;
      }
      // Pousse seulement si hydraté > 0.3.
      if (pot.hydration > 0.3) {
        pot.growth += dt / seed.growSeconds;
        if (pot.growth >= 1.0) {
          pot.growth = 1.0;
          pot.state = _PotState.ready;
        }
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
  }

  void _plant(int idx, _Seed seed) {
    setState(() {
      _pots[idx].state = _PotState.planted;
      _pots[idx].seed = seed.id;
      _pots[idx].growth = 0;
      _pots[idx].hydration = 1.0;
    });
  }

  void _water(int idx) {
    if (!GameState.instance.consumeItem('water', 1)) return;
    setState(() => _pots[idx].hydration = 1.0);
  }

  void _harvest(int idx) {
    final pot = _pots[idx];
    if (pot.state != _PotState.ready) return;
    final seed =
        _seeds.firstWhere((s) => s.id == pot.seed, orElse: () => _seeds[0]);
    GameState.instance.grantItem('food', seed.yield);
    setState(() {
      pot.state = _PotState.empty;
      pot.seed = null;
      pot.growth = 0;
    });
  }

  void _clearDead(int idx) {
    setState(() {
      _pots[idx].state = _PotState.empty;
      _pots[idx].seed = null;
    });
  }

  Future<void> _showSeedMenu(int idx) async {
    final picked = await showModalBottomSheet<_Seed>(
      context: context,
      backgroundColor: const Color(0xFF1A1410),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Choisir une graine',
                  style: TextStyle(
                      color: Color(0xFFFFD9A0),
                      fontSize: 18,
                      fontWeight: FontWeight.w500)),
            ),
            for (final s in _seeds)
              ListTile(
                leading: Icon(s.icon, color: const Color(0xFFB8945C)),
                title: Text(s.label,
                    style: const TextStyle(color: Color(0xFFFFD9A0))),
                subtitle: Text(
                    '${s.growSeconds.round()}s — +${s.yield} food',
                    style: const TextStyle(color: Color(0xFF8B6F4E))),
                onTap: () => Navigator.pop(context, s),
              ),
          ],
        ),
      ),
    );
    if (picked != null) _plant(idx, picked);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
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
                      const Text('Potager — tier 1',
                          style: TextStyle(
                            color: Color(0xFFFFD9A0),
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                          )),
                      const Spacer(),
                      AnimatedBuilder(
                        animation: GameState.instance,
                        builder: (_, __) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _label(Icons.opacity,
                                GameState.instance.itemCount('water'),
                                const Color(0xFF6FAEDF)),
                            const SizedBox(width: 12),
                            _label(Icons.restaurant_menu,
                                GameState.instance.itemCount('food'),
                                const Color(0xFFE89B5C)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap pot vide → planter • Tap pot sec → arroser • Tap pot mûr → récolter',
                    style: TextStyle(color: Color(0xFF8B6F4E), fontSize: 11),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: 4,
                      itemBuilder: (_, i) => _potView(i),
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
                onPressed: widget.onClose,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _potView(int i) {
    final pot = _pots[i];
    String label;
    IconData icon;
    Color color;
    VoidCallback? onTap;
    switch (pot.state) {
      case _PotState.empty:
        label = 'Vide';
        icon = Icons.add_circle_outline;
        color = const Color(0xFF6A5A4A);
        onTap = () => _showSeedMenu(i);
      case _PotState.planted:
        final seed =
            _seeds.firstWhere((s) => s.id == pot.seed, orElse: () => _seeds[0]);
        label = '${seed.label} ${(pot.growth * 100).round()}%';
        icon = seed.icon;
        color = pot.hydration < 0.3
            ? const Color(0xFFE05A4D)
            : const Color(0xFF8FAF6C);
        onTap = pot.hydration < 0.8 ? () => _water(i) : null;
      case _PotState.ready:
        final seed =
            _seeds.firstWhere((s) => s.id == pot.seed, orElse: () => _seeds[0]);
        label = '${seed.label} (mûr +${seed.yield})';
        icon = seed.icon;
        color = const Color(0xFFB8945C);
        onTap = () => _harvest(i);
      case _PotState.dead:
        label = 'Mort';
        icon = Icons.delete_outline;
        color = const Color(0xFF3A2010);
        onTap = () => _clearDead(i);
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                )),
            if (pot.state == _PotState.planted) ...[
              const SizedBox(height: 8),
              Container(
                width: 80,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: pot.hydration.clamp(0.0, 1.0),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF6FAEDF),
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
