import 'package:flutter/material.dart';

import '../../models/game_state.dart';

/// Prototype hydro tier 1 — installation hydroponique vue du dessus
/// avec 6 emplacements (3×2). 4 stades de croissance + ripe pour
/// l'animation de récolte (sprites carrot_*.png).
///
/// Boutons:
/// - Semer carotte → premier pot vide
/// - Passer → avance tous les pots d'un step
/// Tap sur une plante mûre → récolte (+15 food)
class HydroGameTier1 extends StatefulWidget {
  const HydroGameTier1({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  State<HydroGameTier1> createState() => _HydroGameTier1State();
}

class _Pot {
  int? stage; // null = vide, 0..3 = small → huge
  bool showingRipe = false;
}

// 4 stades distincts (skip sprout qui ressemblait trop à small).
const _stages = ['small', 'medium', 'large', 'huge'];

/// Position normalisée + taille (fraction de h) de chaque cup. Modifiable
/// in-app via le mode ajuster, puis bakable dans le code.
class _Slot {
  _Slot(this.x, this.y, this.size);
  double x;
  double y;
  double size; // exprimé en fraction de la hauteur du tank
}

final List<_Slot> _cupSlots = [
  _Slot(0.27, 0.36, 0.32),
  _Slot(0.50, 0.36, 0.32),
  _Slot(0.73, 0.36, 0.32),
  _Slot(0.27, 0.63, 0.32),
  _Slot(0.50, 0.63, 0.32),
  _Slot(0.73, 0.63, 0.32),
];

class _HydroGameTier1State extends State<HydroGameTier1> {
  final List<_Pot> _pots = List.generate(6, (_) => _Pot());
  bool _adjustMode = false;
  int? _selectedSlot;

  bool get _canSeed =>
      _pots.any((p) => p.stage == null && !p.showingRipe);

  void _seed() {
    final p = _pots.firstWhere(
        (p) => p.stage == null && !p.showingRipe,
        orElse: () => _pots.first);
    if (p.stage != null) return;
    setState(() {
      p.stage = 0;
    });
  }

  void _harvestAt(int idx) {
    final p = _pots[idx];
    if (p.stage != 3 || p.showingRipe) return;
    setState(() {
      p.showingRipe = true;
    });
    GameState.instance.grantItem('food', 15);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        p.stage = null;
        p.showingRipe = false;
      });
    });
  }

  void _passStep() {
    setState(() {
      for (final p in _pots) {
        if (p.stage == null || p.showingRipe) continue;
        if (p.stage! < 3) p.stage = p.stage! + 1;
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
                    const SizedBox(height: 12),
                    const Text(
                      'Sème → Passe les steps → Tap sur la plante mûre pour récolter',
                      style: TextStyle(
                          color: Color(0xFF8B6F4E), fontSize: 12),
                    ),
                    const SizedBox(height: 12),
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
                          label: 'Passer un step',
                          icon: Icons.skip_next,
                          enabled: true,
                          onTap: _passStep,
                          color: const Color(0xFF6B4226),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Color(0xFF3A2E1F), size: 28),
                      onPressed: widget.onClose,
                    ),
                    const SizedBox(height: 4),
                    IconButton(
                      icon: Icon(
                        _adjustMode ? Icons.check : Icons.edit_location_alt,
                        color: _adjustMode
                            ? const Color(0xFFFF6B00)
                            : const Color(0xFF3A2E1F),
                        size: 26,
                      ),
                      onPressed: () => setState(() {
                        _adjustMode = !_adjustMode;
                        if (!_adjustMode) _selectedSlot = null;
                      }),
                    ),
                  ],
                ),
              ),
              if (_adjustMode) _adjustHud(),
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
                Positioned.fill(
                  child: Image.asset(
                    'assets/background/hydro_tank.png',
                    fit: BoxFit.contain,
                  ),
                ),
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
    final slot = _cupSlots[i];
    String? spriteAsset;
    if (p.showingRipe) {
      spriteAsset = 'assets/plants/carrot_ripe.png';
    } else if (p.stage != null) {
      spriteAsset = 'assets/plants/carrot_${_stages[p.stage!]}.png';
    }
    // En mode ajuster on force un sprite visible (huge) pour pouvoir
    // caler sur le rendu d'une plante adulte.
    final assetForAdjust = spriteAsset ?? 'assets/plants/carrot_huge.png';
    final size = h * slot.size;
    final isSelected = _adjustMode && _selectedSlot == i;
    return Positioned(
      left: slot.x * w - size / 2,
      top: slot.y * h - size * 0.70,
      width: size,
      height: size,
      child: GestureDetector(
        onTap: _adjustMode
            ? () => setState(() => _selectedSlot = i)
            : (p.stage == 3 && !p.showingRipe ? () => _harvestAt(i) : null),
        onPanUpdate: _adjustMode
            ? (d) {
                setState(() {
                  _selectedSlot = i;
                  slot.x = (slot.x + d.delta.dx / w).clamp(0.02, 0.98);
                  slot.y = (slot.y + d.delta.dy / h).clamp(0.02, 0.98);
                });
              }
            : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Sprite: rendu uniquement si plante OU mode ajuster (avec
            // carrot_huge en placeholder 40% transparent).
            if (spriteAsset != null)
              Positioned.fill(
                child: Image.asset(
                  spriteAsset,
                  fit: BoxFit.contain,
                ),
              )
            else if (_adjustMode)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.4,
                  child: Image.asset(
                    assetForAdjust,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            if (isSelected)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFFF6B00),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            if (p.stage == 3 && !p.showingRipe && !_adjustMode)
              Positioned(
                top: -8,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFB85522),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.touch_app,
                      color: Colors.white, size: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
    Color color = const Color(0xFFB85522),
  }) {
    return SizedBox(
      width: 180,
      child: FilledButton.icon(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 18),
        label: Text(label,
            style: const TextStyle(fontSize: 14, letterSpacing: 0)),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor:
              const Color(0xFF8B6F4E).withValues(alpha: 0.4),
          foregroundColor: Colors.white,
          padding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _adjustHud() {
    return Positioned(
      left: 12,
      top: 12,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Placement pots',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            for (int i = 0; i < _cupSlots.length; i++)
              Text(
                'Pot ${i + 1}: '
                '(${_cupSlots[i].x.toStringAsFixed(3)}, '
                '${_cupSlots[i].y.toStringAsFixed(3)}) '
                'size=${_cupSlots[i].size.toStringAsFixed(3)}',
                style: TextStyle(
                  color: _selectedSlot == i
                      ? const Color(0xFFFF6B00)
                      : const Color(0xFFFFD9A0),
                  fontSize: 11,
                  fontFamily: 'Courier',
                  fontWeight: _selectedSlot == i
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            if (_selectedSlot != null) ...[
              const SizedBox(height: 8),
              Text(
                'Pot ${_selectedSlot! + 1} sélectionné',
                style: const TextStyle(
                  color: Color(0xFFFF6B00),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text('Taille:',
                      style: TextStyle(
                          color: Color(0xFFFFD9A0), fontSize: 11)),
                  const SizedBox(width: 8),
                  _sizeBtn(Icons.remove, () => _resize(-0.01)),
                  const SizedBox(width: 4),
                  _sizeBtn(Icons.add, () => _resize(0.01)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _resize(double delta) {
    final i = _selectedSlot;
    if (i == null) return;
    setState(() {
      _cupSlots[i].size =
          (_cupSlots[i].size + delta).clamp(0.10, 0.80);
    });
  }

  Widget _sizeBtn(IconData icon, VoidCallback onTap) {
    return InkResponse(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: Color(0xFFB85522),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 14),
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
