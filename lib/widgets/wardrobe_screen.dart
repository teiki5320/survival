import 'package:flutter/material.dart';

/// Plein écran "armoire" : la fille en grand au centre, idle qui boucle,
/// et une flèche de chaque côté pour cycler entre les tenues. Pour
/// l'instant une seule tenue est dispo ; la structure est prête pour
/// en ajouter (chaque tenue aura son propre dossier de 49 frames pour
/// chaque anim — voir CLAUDE.md / brief vêtements).
class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  // Une entry par tenue. `frontAsset` = chemin du sprite STATIQUE de
  // face affiché au centre (pour qu'on voie la tenue, pas un profil).
  // L'animation idle reviendra quand on aura plus d'1 tenue + une vue
  // de face animée par tenue.
  static const List<_Outfit> _outfits = [
    _Outfit(
      name: 'Chemise blanche',
      frontAsset: 'assets/characters/heroine_front.png',
    ),
  ];

  int _outfitIndex = 0;

  void _prev() {
    setState(() {
      _outfitIndex = (_outfitIndex - 1 + _outfits.length) % _outfits.length;
    });
  }

  void _next() {
    setState(() {
      _outfitIndex = (_outfitIndex + 1) % _outfits.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final figureH = size.height * 0.80;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1410),
      body: SafeArea(
        child: Stack(
          children: [
            // Texture warm sur fond — léger gradient honey.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.1,
                    colors: [
                      const Color(0xFF3A2A1C),
                      const Color(0xFF1A1410),
                    ],
                  ),
                ),
              ),
            ),
            // Fille centrée, en grand.
            Center(
              child: SizedBox(
                height: figureH,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.asset(
                    _outfits[_outfitIndex].frontAsset,
                    fit: BoxFit.contain,
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
            // Nom de la tenue + indicateur "X / N" en bas.
            Positioned(
              left: 0,
              right: 0,
              bottom: 40,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _outfits[_outfitIndex].name,
                    style: const TextStyle(
                      color: Color(0xFFFFD9A0),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_outfitIndex + 1} / ${_outfits.length}',
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
}

class _Outfit {
  const _Outfit({required this.name, required this.frontAsset});
  final String name;
  final String frontAsset;
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
