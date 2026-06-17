import 'package:flutter/material.dart';

import '../models/game_state.dart';

/// Plein écran "armoire" : la fille en grand au centre, idle qui boucle,
/// et une flèche de chaque côté pour cycler entre les tenues. Sélectionner
/// une tenue applique son bonus de chaleur (`outfitWarmth`) qui agit sur le
/// froid ressenti en jeu. Pour la voir VRAIMENT portée par le personnage
/// animé il faudra régénérer ses sheets d'anim avec la tenue (voir CLAUDE.md
/// / brief vêtements) ; ici on affiche le vêtement dans le placard.
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
      warmth: 0,
    ),
    _Outfit(
      name: 'Robe de lin',
      frontAsset: 'assets/objects/outfit_robe.png',
      warmth: 3,
    ),
    // Manteau d'hiver : le VRAI outil contre le froid du nord (warmth 8 ->
    // seuil de froid 12 - stage*2 - 8, géable avec le poêle). Sprite dédié à
    // venir ; en attendant on réutilise le rendu robe + l'écharpe peinte
    // (_ScarfPainter) qui s'affiche dès que outfitWarmth > 0.
    _Outfit(
      name: 'Manteau d\'hiver',
      frontAsset: 'assets/objects/outfit_robe.png',
      warmth: 6,
    ),
  ];

  int _outfitIndex = 0;

  @override
  void initState() {
    super.initState();
    // Reprend la tenue actuellement portée (selon le bonus chaleur stocké).
    final w = GameState.instance.outfitWarmth;
    final i = _outfits.indexWhere((o) => o.warmth == w);
    if (i >= 0) _outfitIndex = i;
  }

  // Sélectionner une tenue applique tout de suite son bonus de chaleur.
  void _select(int i) {
    setState(() => _outfitIndex = i);
    GameState.instance.outfitWarmth = _outfits[i].warmth;
    GameState.instance.save();
  }

  void _prev() =>
      _select((_outfitIndex - 1 + _outfits.length) % _outfits.length);

  void _next() => _select((_outfitIndex + 1) % _outfits.length);

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
                  // Bonus de chaleur de la tenue (0 = neutre).
                  Text(
                    _outfits[_outfitIndex].warmth > 0
                        ? '🔥 Chaleur +${_outfits[_outfitIndex].warmth}'
                        : 'Chaleur neutre',
                    style: const TextStyle(
                      color: Color(0xFFFFB066),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
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
  const _Outfit({
    required this.name,
    required this.frontAsset,
    this.warmth = 0,
  });
  final String name;
  final String frontAsset;
  // Bonus de chaleur appliqué à GameState.outfitWarmth quand portée.
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
