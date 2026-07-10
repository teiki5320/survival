import 'package:flutter/material.dart';

import '../models/game_state.dart';

/// Plein écran "armoire", en DEUX temps : on choisit d'abord le PERSONNAGE
/// (Shen / petite sœur si elle est à bord), puis on feuillette SES tenues
/// avec les flèches et on VALIDE pour la porter (bouton — le feuilletage ne
/// change plus la tenue tout seul).
///  - Shen : `shenOutfit` (sprites) + bonus de chaleur `outfitWarmth` ;
///  - sœur : `sisterOutfit` (0 pyjama / 1 laine), sprites `<anim>_wool_N`.
/// Seules les tenues avec de VRAIS sprites sont proposées.
class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  // --- Tenues de SHEN (uniquement celles qui existent en sprites).
  static const List<_Outfit> _shenOutfits = [
    _Outfit(
      name: 'Chemise blanche',
      // Aperçus RECADRÉS AU PIXEL (pieds = bord bas) -> le bas aligné et
      // figureScale = hauteur de corps EXACTE, sans marge fantôme.
      frontAsset: 'assets/objects/preview_shen_chemise.png',
      warmth: 0,
      figureScale: 1.0,
    ),
    // Pyjama lapin rose : jeu complet de sprites (`<anim>_lapin_N.png`).
    // Bien chaud (kigurumi polaire) -> LA tenue anti-froid du jeu.
    _Outfit(
      name: 'Pyjama lapin 🐰',
      frontAsset: 'assets/characters/heroine_front_lapin.png',
      warmth: 6,
      spriteOutfit: 1,
      figureScale: 1.0, // recadré serré, comme la chemise
    ),
  ];

  // --- Tenues de la PETITE SŒUR (sisterOutfit 0/1).
  static const List<_Outfit> _sisterOutfits = [
    _Outfit(
      name: 'Pyjama',
      // Vue de FACE haute résolution (recadrage serré du frisson classique).
      frontAsset: 'assets/objects/preview_sister_pyjama.png',
      // 0.74 = proportion réaliste d'une enfant de 7 ans face à Shen.
      figureScale: 0.74,
    ),
    _Outfit(
      name: 'Pyjama de laine 🐻',
      frontAsset: 'assets/characters/sister_front_wool.png',
      figureScale: 0.74, // même hauteur que le pyjama (recadrés serrés)
    ),
  ];

  int _character = 0; // 0 = Shen, 1 = sœur
  int _shenIndex = 0;
  int _sisterIndex = 0;

  bool get _sisterAvailable => GameState.instance.sisterShown;

  List<_Outfit> get _outfits =>
      _character == 0 ? _shenOutfits : _sisterOutfits;

  int get _index => _character == 0 ? _shenIndex : _sisterIndex;

  set _index(int v) {
    if (_character == 0) {
      _shenIndex = v;
    } else {
      _sisterIndex = v;
    }
  }

  /// Index de la tenue actuellement PORTÉE par le perso affiché.
  int get _wornIndex {
    if (_character == 0) {
      return GameState.instance.shenOutfit == 1
          ? _shenOutfits.indexWhere((o) => o.spriteOutfit == 1)
          : 0;
    }
    return GameState.instance.sisterOutfit.clamp(0, 1);
  }

  @override
  void initState() {
    super.initState();
    // Ouvre sur les tenues actuellement portées.
    _shenIndex = GameState.instance.shenOutfit == 1
        ? _shenOutfits.indexWhere((o) => o.spriteOutfit == 1)
        : 0;
    if (_shenIndex < 0) _shenIndex = 0;
    _sisterIndex = GameState.instance.sisterOutfit.clamp(0, 1);
  }

  // Les flèches ne font que FEUILLETER — la tenue n'est appliquée qu'au
  // bouton Valider.
  void _prev() =>
      setState(() => _index = (_index - 1 + _outfits.length) % _outfits.length);

  void _next() => setState(() => _index = (_index + 1) % _outfits.length);

  void _apply() {
    setState(() {
      if (_character == 0) {
        GameState.instance.outfitWarmth = _shenOutfits[_shenIndex].warmth;
        GameState.instance.setShenOutfit(_shenOutfits[_shenIndex].spriteOutfit);
      } else {
        GameState.instance.setSisterOutfit(_sisterIndex);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final figureH = size.height * 0.68;
    final outfit = _outfits[_index];
    final worn = _index == _wornIndex;

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
            // Personnage centré, en grand, dans la tenue feuilletée.
            // Bas des personnages ALIGNÉ (et hauteur de corps homogène via
            // figureScale) pour que le changement de tenue/perso ne saute pas.
            Positioned(
              left: 0,
              right: 0,
              bottom: size.height * 0.16,
              child: Center(
                child: SizedBox(
                  height: figureH * outfit.figureScale,
                  child: Image.asset(
                    outfit.frontAsset,
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
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
            // Nom + effet + bouton VALIDER en bas.
            Positioned(
              left: 0,
              right: 0,
              bottom: 32,
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
                  const SizedBox(height: 4),
                  Text(
                    '${_index + 1} / ${_outfits.length}',
                    style: TextStyle(
                      color: const Color(0xFFFFD9A0).withValues(alpha: 0.6),
                      fontSize: 13,
                      fontFamily: 'Courier',
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Bouton Valider : applique la tenue feuilletée. Devient
                  // « Portée ✓ » (inactif) quand c'est déjà celle du perso.
                  ElevatedButton(
                    onPressed: worn ? null : _apply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB85522),
                      disabledBackgroundColor:
                          const Color(0xFF4A3A28).withValues(alpha: 0.8),
                      foregroundColor: Colors.white,
                      disabledForegroundColor: const Color(0xFFFFD9A0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 34, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(
                      worn ? 'Portée ✓' : 'Valider',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
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
    this.spriteOutfit = 0,
    this.figureScale = 1.0,
  });
  final String name;
  final String frontAsset;
  // Bonus de chaleur appliqué à GameState.outfitWarmth quand portée (Shen).
  final int warmth;
  // Valeur GameState.shenOutfit (0 = sprites de base, 1 = sprites lapin).
  final int spriteOutfit;
  // Échelle d'affichage : compense la fraction de contenu de chaque asset
  // (portrait serré vs canvas 512 avec marges) -> corps de même hauteur.
  final double figureScale;
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
