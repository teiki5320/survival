import 'package:flutter/material.dart';

/// Cinématique d'ouverture SANS art (panneaux de texte + fondus). Raconte la
/// nuit de la fuite avant l'arrivée dans le wagon. Jouée une fois en début de
/// partie (puis `GameState.markIntroCinematicSeen`). On peut passer (Skip).
///
/// Volontairement « simple » : on remplacera par de vraies images plus tard,
/// mais ça pose la scène dès maintenant, sans dépendre d'assets.
class OpeningCinematic extends StatefulWidget {
  const OpeningCinematic({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<OpeningCinematic> createState() => _OpeningCinematicState();
}

class _OpeningCinematicState extends State<OpeningCinematic>
    with SingleTickerProviderStateMixin {
  // Chaque panneau : une ligne de récit. Fondu in -> tenue -> fondu out.
  static const List<String> _panels = [
    'Avant, il y avait une ville. Des parents. Une petite sœur.',
    'Puis la nuit a pris feu. Les sirènes, la foule, les mains arrachées.',
    'On t\'a poussée vers le quai. Le dernier train chauffait déjà.',
    'Tu t\'es glissée dans le dernier wagon, seule, le cœur en cendres.',
    'Le convoi s\'est arraché à la ville qui brûlait. Direction : le nord.',
    'Quelque part là-haut, peut-être, les tiens t\'attendent.',
  ];

  late final AnimationController _c;
  int _i = 0;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) _next();
      });
    _c.forward();
  }

  void _next() {
    if (!mounted) return;
    if (_i >= _panels.length - 1) {
      widget.onDone();
      return;
    }
    setState(() => _i++);
    _c.forward(from: 0);
  }

  void _skip() => widget.onDone();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Opacité : fondu in (0->0.2), tenue (0.2->0.8), fondu out (0.8->1).
    double opacityFor(double t) {
      if (t < 0.18) return (t / 0.18).clamp(0.0, 1.0);
      if (t > 0.82) return (1 - (t - 0.82) / 0.18).clamp(0.0, 1.0);
      return 1.0;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _next, // tap = panneau suivant
      child: Material(
        color: Colors.black,
        child: Stack(
          children: [
            // Léger dégradé braise en bas (la ville qui brûle), sans image.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF05060A),
                      Color(0xFF0B0805),
                      Color(0xFF2A1206),
                    ],
                    stops: [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (_, __) => Opacity(
                    opacity: opacityFor(_c.value),
                    child: Text(
                      _panels[_i],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFEAD8B6),
                        fontSize: 22,
                        height: 1.5,
                        letterSpacing: 0.4,
                        shadows: [
                          Shadow(color: Color(0xAA000000), blurRadius: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Bouton passer (discret, bas-droite).
            Positioned(
              right: 18,
              bottom: 14,
              child: SafeArea(
                child: TextButton(
                  onPressed: _skip,
                  child: const Text('Passer ▸',
                      style: TextStyle(color: Color(0xFF9A8A6E))),
                ),
              ),
            ),
            // Progression (petits points).
            Positioned(
              left: 0,
              right: 0,
              bottom: 22,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int k = 0; k < _panels.length; k++)
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: k <= _i
                            ? const Color(0xFFD9A05B)
                            : const Color(0x55D9A05B),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
