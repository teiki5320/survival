import 'package:flutter/material.dart';

/// Cinématique d'ouverture « La nuit de la fuite » : 5 plans peints + textes,
/// fondu in/out sur chaque plan. Jouée une fois en début de partie (puis
/// `GameState.markIntroCinematicSeen`). Tap = plan suivant, bouton Passer.
class OpeningCinematic extends StatefulWidget {
  const OpeningCinematic({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<OpeningCinematic> createState() => _OpeningCinematicState();
}

class _Beat {
  const _Beat(this.image, this.lines);
  final String? image; // null = écran noir (dernier beat)
  final List<String> lines; // texte(s) du plan
}

class _OpeningCinematicState extends State<OpeningCinematic>
    with SingleTickerProviderStateMixin {
  // Script câblé sur les plans peints (« La nuit de la fuite »).
  static const List<_Beat> _beats = [
    _Beat('assets/cinematic/cine_open_1.png', [
      'Cette nuit-là, le ciel s\'est embrasé.',
      'Ses parents l\'ont réveillée.',
    ]),
    _Beat('assets/cinematic/cine_open_fuite.png', [
      'Il fallait fuir. Vite, dans le couloir en flammes.',
    ]),
    _Beat('assets/cinematic/cine_open_separation.png', [
      'Dehors, la foule les a emportés. Ils ont été séparés.',
    ]),
    _Beat('assets/cinematic/cine_open_3.jpg', [
      'Au bout du quai, une vieille locomotive à bois chauffait déjà.',
    ]),
    _Beat('assets/cinematic/cine_open_4.jpg', [
      'Elle est montée. Elle s\'est cachée dans le dernier wagon.',
    ]),
    _Beat('assets/cinematic/cine_open_5.png', [
      'Le train est parti. La gare a brûlé derrière elle.',
    ]),
    _Beat(null, [
      'Seule. Dans le dernier wagon d\'un monde mort.',
    ]),
  ];

  late final AnimationController _c;
  int _i = 0; // index du beat
  int _line = 0; // index de la ligne dans le beat courant

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) _advance();
      });
    _c.forward();
    _precacheNext();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheNext();
  }

  // Précharge l'image du beat courant + suivant pour éviter un flash gris.
  void _precacheNext() {
    for (final j in [_i, _i + 1]) {
      if (j < _beats.length && _beats[j].image != null) {
        precacheImage(AssetImage(_beats[j].image!), context);
      }
    }
  }

  // Avance : d'abord ligne par ligne dans le beat, puis beat suivant.
  void _advance() {
    if (!mounted) return;
    final beat = _beats[_i];
    if (_line < beat.lines.length - 1) {
      setState(() => _line++);
      _c.forward(from: 0);
      return;
    }
    if (_i >= _beats.length - 1) {
      widget.onDone();
      return;
    }
    setState(() {
      _i++;
      _line = 0;
    });
    _precacheNext();
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
    // Opacité texte : fondu in (0->0.18), tenue, fondu out (0.82->1).
    double textOpacity(double t) {
      if (t < 0.18) return (t / 0.18).clamp(0.0, 1.0);
      if (t > 0.82) return (1 - (t - 0.82) / 0.18).clamp(0.0, 1.0);
      return 1.0;
    }

    final beat = _beats[_i];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _advance,
      child: Material(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Plan peint (fondu doux au changement de beat).
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 700),
              child: beat.image == null
                  ? const DecoratedBox(
                      key: ValueKey('black'),
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
                    )
                  : Image.asset(
                      beat.image!,
                      key: ValueKey(beat.image),
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
            ),
            // Voile sombre pour lisibilité du texte (plus dense en bas).
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xC0000000)],
                  ),
                ),
              ),
            ),
            // Texte du récit (bas-centre).
            Positioned(
              left: 32,
              right: 32,
              bottom: 70,
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, __) => Opacity(
                  opacity: textOpacity(_c.value),
                  child: Text(
                    beat.lines[_line],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFEAD8B6),
                      fontSize: 22,
                      height: 1.5,
                      letterSpacing: 0.4,
                      shadows: [
                        Shadow(color: Color(0xDD000000), blurRadius: 14),
                        Shadow(color: Color(0x88000000), blurRadius: 28),
                      ],
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
                      style: TextStyle(color: Color(0xFFCDB892))),
                ),
              ),
            ),
            // Progression (un point par beat).
            Positioned(
              left: 0,
              right: 0,
              bottom: 22,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int k = 0; k < _beats.length; k++)
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
