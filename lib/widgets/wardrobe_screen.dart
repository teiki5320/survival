import 'package:flutter/material.dart';

import '../models/game_state.dart';

/// Plein écran "armoire", en DEUX temps : on choisit d'abord le PERSONNAGE
/// (Shen / petite sœur si elle est à bord), puis on feuillette SES tenues
/// avec les flèches. Sélectionner une tenue l'applique tout de suite :
///  - Shen : bonus de chaleur `outfitWarmth` (agit sur le froid ressenti) ;
///  - sœur : `sisterOutfit` (0 pyjama / 1 laine), sprites `<anim>_wool_N`.
class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  // --- Tenues de SHEN. `frontAsset` = sprite statique de face (pour voir la
  // tenue, pas un profil). Pour la voir portée par le personnage animé il
  // faudra régénérer ses sheets (voir CLAUDE.md / brief vêtements).
  static const List<_Outfit> _shenOutfits = [
    _Outfit(
      name: 'Chemise blanche',
      frontAsset: 'assets/characters/heroine_front.png',
      warmth: 0,
    ),
    _Outfit(
      name: 'Robe de lin',
      frontAsset: 'assets/objects/outfit_robe.png',
      warmth: 3,
    ),
    // Manteau d'hiver : le VRAI outil contre le froid du nord. Sprite dédié à
    // venir ; en attendant on réutilise le rendu robe + l'écharpe peinte.
    _Outfit(
      name: 'Manteau d\'hiver',
      frontAsset: 'assets/objects/outfit_robe.png',
      warmth: 6,
    ),
  ];

  // --- Tenues de la PETITE SŒUR (sisterOutfit 0/1).
  static const List<_Outfit> _sisterOutfits = [
    _Outfit(
      name: 'Pyjama',
      frontAsset: 'assets/characters/sister_idle_1.png',
    ),
    _Outfit(
      name: 'Pyjama de laine 🐻',
      frontAsset: 'assets/characters/sister_front_wool.png',
    ),
  ];

  int _character = 0; // 0 = Shen, 1 = sœur
  int _shenIndex = 0;
  int _sisterIndex = 0;

  bool get _sisterAvailable => GameState.instance.sisterShown;

  List<_Outfit> get _outfits =>
      _character == 0 ? _shenOutfits : _sisterOutfits;

  int get _index => _character == 0 ? _shenIndex : _sisterIndex;

  @override
  void initState() {
    super.initState();
    // Reprend les tenues actuellement portées.
    final w = GameState.instance.outfitWarmth;
    final i = _shenOutfits.indexWhere((o) => o.warmth == w);
    if (i >= 0) _shenIndex = i;
    _sisterIndex = GameState.instance.sisterOutfit.clamp(0, 1);
  }

  // Sélectionner une tenue applique tout de suite son effet.
  void _select(int i) {
    setState(() {
      if (_character == 0) {
        _shenIndex = i;
        GameState.instance.outfitWarmth = _shenOutfits[i].warmth;
        GameState.instance.save();
      } else {
        _sisterIndex = i;
        GameState.instance.setSisterOutfit(i);
      }
    });
  }

  void _prev() => _select((_index - 1 + _outfits.length) % _outfits.length);

  void _next() => _select((_index + 1) % _outfits.length);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final figureH = size.height * 0.72;
    final outfit = _outfits[_index];

    return Scaffold(
      backgroundColor: const Color(0xFF1A1410),
      body: SafeArea(
        child: Stack(
          children: [
            // Texture warm sur fond — léger gradient honey.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.1,
                    colors: [
                      Color(0xFF3A2A1C),
                      Color(0xFF1A1410),
                    ],
                  ),
                ),
              ),
            ),
            // Personnage centré, en grand, dans la tenue sélectionnée.
            Center(
              child: SizedBox(
                height: figureH,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.asset(
                    outfit.frontAsset,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            // Sélecteur de PERSONNAGE en haut (étape 1).
            Positioned(
              top: 14,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(24),
                    border:
                        Border.all(color: const Color(0x66FFD9A0), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _characterChip('Shen', 0),
                      if (_sisterAvailable) ...[
                        const SizedBox(width: 4),
                        _characterChip('Petite sœur', 1),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Flèche gauche.
            Positioned(
              left: 24,
              top: 0,
              bottom: 0,
              child: Center(
                child: _ArrowButton(
                  icon: Icons.arrow_back_ios_new,
                  onTap: _outfits.length > 1 ? _prev : null,
                ),
              ),
            ),
            // Flèche droite.
            Positioned(
              right: 24,
              top: 0,
              bottom: 0,
              child: Center(
                child: _ArrowButton(
                  icon: Icons.arrow_forward_ios,
                  onTap: _outfits.length > 1 ? _next : null,
                ),
              ),
            ),
            // Nom de la tenue + effet + indicateur "X / N" en bas.
            Positioned(
              left: 0,
              right: 0,
              bottom: 40,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    outfit.name,
                    style: const TextStyle(
                      color: Color(0xFFFFD9A0),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Effet de la tenue (chaleur pour Shen, cosy pour la sœur).
                  Text(
                    _character == 0
                        ? (outfit.warmth > 0
                            ? '🔥 Chaleur +${outfit.warmth}'
                            : 'Chaleur neutre')
                        : (_index == 1 ? '🧸 Bien au chaud' : 'Tenue de nuit'),
                    style: const TextStyle(
                      color: Color(0xFFFFB066),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_index + 1} / ${_outfits.length}',
                    style: TextStyle(
                      color: const Color(0xFFFFD9A0).withValues(alpha: 0.6),
                      fontSize: 13,
                      fontFamily: 'Courier',
                    ),
                  ),
                ],
              ),
            ),
            // Bouton fermer.
            Positioned(
              top: 16,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'wardrobe_close',
                onPressed: widget.onClose,
                backgroundColor: const Color(0xFFB85522),
                foregroundColor: Colors.white,
                child: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Puce du sélecteur de personnage (bord doré si sélectionné).
  Widget _characterChip(String label, int value) {
    final selected = _character == value;
    return GestureDetector(
      onTap: () => setState(() => _character = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0x33FFD9A0) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFFFFD9A0) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFFFFD9A0) : Colors.white70,
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _Outfit {
  const _Outfit({
    required this.name,
    required this.frontAsset,
    this.warmth = 0,
  });
  final String name;
  final String frontAsset;
  // Bonus de chaleur appliqué à GameState.outfitWarmth quand portée (Shen).
  final int warmth;
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: Colors.transparent,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.black.withValues(
              alpha: disabled ? 0.25 : 0.55,
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFFFD9A0)
                  .withValues(alpha: disabled ? 0.2 : 0.6),
              width: 1.5,
            ),
          ),
          child: Icon(
            icon,
            color: const Color(0xFFFFD9A0)
                .withValues(alpha: disabled ? 0.3 : 1.0),
            size: 22,
          ),
        ),
      ),
    );
  }
}
