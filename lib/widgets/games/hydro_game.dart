import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/game_state.dart';

/// Tour hydroponique (tier 1) — vue de côté, 8 emplacements visuels
/// répartis sur 4 étages. Les plantes poussent en temps réel persistant
/// (même quand le jeu est fermé). Tap = action courte (semer, arroser,
/// récolter). C'est de la gestion : tu reviens entre les sessions.
class HydroGameTier1 extends StatefulWidget {
  const HydroGameTier1({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  State<HydroGameTier1> createState() => _HydroGameTier1State();
}

class _Seed {
  const _Seed(this.id, this.label, this.icon, this.color);
  final String id;
  final String label;
  final IconData icon;
  final Color color;
}

const _seeds = [
  _Seed('herb', 'Herbe', Icons.local_florist, Color(0xFF8FAF6C)),
  _Seed('tomato', 'Tomate', Icons.lunch_dining, Color(0xFFD45A4D)),
  _Seed('beans', 'Haricots', Icons.spa, Color(0xFF7AAFCC)),
  _Seed('wheat', 'Blé', Icons.grass, Color(0xFFD4A55A)),
];

class _HydroGameTier1State extends State<HydroGameTier1> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Tick toutes les secondes pour update visuel pendant la session.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      GameState.instance.advanceFarm();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<_Seed?> _pickSeed() {
    return showModalBottomSheet<_Seed>(
      context: context,
      backgroundColor: const Color(0xFF1A1410),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Semer une graine',
                style: TextStyle(
                    color: Color(0xFFFFD9A0),
                    fontSize: 18,
                    fontWeight: FontWeight.w500),
              ),
            ),
            for (final s in _seeds)
              ListTile(
                leading: Icon(s.icon, color: s.color),
                title: Text(s.label,
                    style: const TextStyle(color: Color(0xFFFFD9A0))),
                subtitle: Text(
                  '${(GameState.hydroGrowSeconds(s.id) / 60).toStringAsFixed(0)} min — +${GameState.hydroYield(s.id)} food',
                  style: const TextStyle(color: Color(0xFF8B6F4E)),
                ),
                onTap: () => Navigator.pop(context, s),
              ),
          ],
        ),
      ),
    );
  }

  void _onSlotTap(int idx) async {
    final gs = GameState.instance;
    final slot = gs.hydroSlots[idx];
    if (slot['seed'] == null) {
      final s = await _pickSeed();
      if (s != null) gs.plantSeed(idx, s.id);
      return;
    }
    final growth = slot['growth'] as double;
    final hydration = slot['hydration'] as double;
    if (growth >= 1.0) {
      gs.harvestSlot(idx);
      return;
    }
    if (hydration < 0.5) {
      gs.waterSlot(idx);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1410),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: GameState.instance,
          builder: (_, __) => Stack(
            children: [
              // Fond paysage du wagon (parchemin sombre).
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [Color(0xFF1A2018), Color(0xFF0A0E0A)],
                      radius: 1.4,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Tour hydroponique',
                          style: TextStyle(
                            color: Color(0xFFFFD9A0),
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        _label(Icons.opacity,
                            GameState.instance.itemCount('water'),
                            const Color(0xFF6FAEDF)),
                        const SizedBox(width: 12),
                        _label(Icons.restaurant_menu,
                            GameState.instance.itemCount('food'),
                            const Color(0xFFE89B5C)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Vide → semer • Pousse sèche → arroser • Mûre → récolter',
                      style:
                          TextStyle(color: Color(0xFF8B6F4E), fontSize: 11),
                    ),
                    const SizedBox(height: 20),
                    Expanded(child: _buildTower()),
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
      ),
    );
  }

  Widget _buildTower() {
    // Tour vue de côté : 4 étages, 2 plants par étage (gauche/droite).
    final slots = GameState.instance.hydroSlots;
    return Center(
      child: LayoutBuilder(
        builder: (_, c) {
          final towerW = c.maxWidth * 0.6;
          final towerH = c.maxHeight;
          return SizedBox(
            width: towerW,
            height: towerH,
            child: Stack(
              children: [
                // Trunk central (la colonne de la tour).
                Center(
                  child: Container(
                    width: towerW * 0.18,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF8B4A1A),
                          Color(0xFF6B3818),
                          Color(0xFF4A2810),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: const [
                        BoxShadow(color: Color(0x66000000), blurRadius: 12),
                      ],
                    ),
                  ),
                ),
                // Réservoir d'eau en bas.
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  height: towerH * 0.10,
                  child: Center(
                    child: Container(
                      width: towerW * 0.85,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A5A7A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFF1A4060), width: 2),
                      ),
                    ),
                  ),
                ),
                // 8 emplacements (4 étages × 2).
                for (int i = 0; i < 8; i++) _slotWidget(
                  i, slots[i], towerW, towerH,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _slotWidget(int i, Map<String, dynamic> slot, double w, double h) {
    final floor = i ~/ 2; // 0..3
    final side = i % 2; // 0 left, 1 right
    final floorY = h * (0.12 + floor * 0.20);
    final sideX = side == 0
        ? w * 0.05
        : w * 0.95 - w * 0.30;
    return Positioned(
      left: sideX,
      top: floorY,
      width: w * 0.30,
      height: h * 0.18,
      child: GestureDetector(
        onTap: () => _onSlotTap(i),
        child: _plantVisual(slot),
      ),
    );
  }

  Widget _plantVisual(Map<String, dynamic> slot) {
    final seedId = slot['seed'] as String?;
    final growth = (slot['growth'] as double?) ?? 0.0;
    final hydration = (slot['hydration'] as double?) ?? 1.0;

    if (seedId == null) {
      return Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF6A5A4A).withValues(alpha: 0.5),
            style: BorderStyle.solid,
            width: 1,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.add_circle_outline,
            color: Color(0xFF6A5A4A),
            size: 24,
          ),
        ),
      );
    }

    final seed = _seeds.firstWhere((s) => s.id == seedId,
        orElse: () => _seeds[0]);
    final ready = growth >= 1.0;
    final dry = hydration < 0.5;
    final dead = hydration <= 0.0;

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: dead
              ? const Color(0xFF3A2010)
              : ready
                  ? const Color(0xFFFFD9A0)
                  : dry
                      ? const Color(0xFFE05A4D)
                      : seed.color,
          width: ready ? 2 : 1,
        ),
      ),
      child: Stack(
        children: [
          // Pot (en bas).
          Positioned(
            left: 0, right: 0, bottom: 0,
            height: 14,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF6B4226),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(7),
                  bottomRight: Radius.circular(7),
                ),
                border: Border.all(
                  color: const Color(0xFF4A2810),
                  width: 0.6,
                ),
              ),
            ),
          ),
          // Plante (animation par taille de l'icône).
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AnimatedScale(
                scale: 0.3 + growth * 0.9,
                duration: const Duration(milliseconds: 600),
                child: Icon(
                  seed.icon,
                  color: dead
                      ? const Color(0xFF3A2010)
                      : seed.color.withValues(alpha: hydration.clamp(0.4, 1.0)),
                  size: 36,
                ),
              ),
            ),
          ),
          // Indicateur "mûr".
          if (ready)
            const Positioned(
              top: 4,
              right: 4,
              child: Icon(Icons.check_circle,
                  color: Color(0xFFFFD9A0), size: 16),
            ),
          // Indicateur "sec".
          if (dry && !ready)
            const Positioned(
              top: 4,
              right: 4,
              child: Icon(Icons.water_drop_outlined,
                  color: Color(0xFFE05A4D), size: 16),
            ),
          // Barre de croissance discrète.
          if (!ready)
            Positioned(
              left: 4, right: 4, bottom: 0,
              height: 2,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: growth.clamp(0.0, 1.0),
                child: Container(
                  color: const Color(0xFFFFD9A0).withValues(alpha: 0.8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _label(IconData icon, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontFamily: 'Courier',
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
