import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/game_state.dart';

/// Mini-jeu de PÊCHE — version 100 % DESSINÉE (CustomPaint, aucun sprite).
/// Cosy et indulgent : on lance la ligne, le flotteur dérive, puis « ça mord »
/// (fenêtre de ~1,3 s) → tap pour ferrer. Réussite = on remonte la prise et on
/// débloque la carte-souvenir « pêche » (récompense 100 % NARRATIVE, pas de
/// stat). Pas de punition à l'échec : on peut relancer autant qu'on veut.
class FishingGame extends StatefulWidget {
  const FishingGame({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<FishingGame> createState() => _FishingGameState();
}

enum _Phase { idle, waiting, biting, caught }

class _FishingGameState extends State<FishingGame>
    with TickerProviderStateMixin {
  late final AnimationController _surface; // ondulation continue de l'eau
  late final AnimationController _tug; // secousse du flotteur quand ça mord
  Timer? _biteTimer;
  Timer? _missTimer;
  final _rng = math.Random();

  _Phase _phase = _Phase.idle;
  String _hint = 'Lance la ligne dans l\'eau noire.';

  @override
  void initState() {
    super.initState();
    _surface = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))
      ..repeat();
    _tug = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260));
  }

  @override
  void dispose() {
    _biteTimer?.cancel();
    _missTimer?.cancel();
    _surface.dispose();
    _tug.dispose();
    super.dispose();
  }

  void _cast() {
    setState(() {
      _phase = _Phase.waiting;
      _hint = 'La ligne dérive… attends que ça morde.';
    });
    // Touche après un délai aléatoire (1,5 à 3,8 s).
    _biteTimer?.cancel();
    _biteTimer = Timer(
        Duration(milliseconds: 1500 + _rng.nextInt(2300)), _startBite);
  }

  void _startBite() {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.biting;
      _hint = 'ÇA MORD ! Tape pour ferrer !';
    });
    _tug.repeat(reverse: true);
    // Fenêtre de ferrage ~1,3 s, sinon le poisson file (sans punition).
    _missTimer?.cancel();
    _missTimer = Timer(const Duration(milliseconds: 1300), () {
      if (!mounted || _phase != _Phase.biting) return;
      _tug.stop();
      _tug.value = 0;
      setState(() {
        _phase = _Phase.idle;
        _hint = 'Raté — il a filé. Relance quand tu veux.';
      });
    });
  }

  void _tapWater() {
    switch (_phase) {
      case _Phase.idle:
      case _Phase.caught:
        break;
      case _Phase.waiting:
        // Ferrer trop tôt : on rate, mais c'est indulgent (on relance).
        _biteTimer?.cancel();
        setState(() {
          _phase = _Phase.idle;
          _hint = 'Trop tôt, tu as effrayé le poisson. Réessaie.';
        });
      case _Phase.biting:
        _missTimer?.cancel();
        _tug.stop();
        _tug.value = 0;
        // PRISE ! Débloque la carte-souvenir (narratif). Idempotent.
        GameState.instance.unlockSouvenir('peche');
        setState(() {
          _phase = _Phase.caught;
          _hint = '';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tapWater,
        child: Stack(
          children: [
            // Scène d'eau dessinée, plein écran.
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([_surface, _tug]),
                builder: (_, __) => CustomPaint(
                  painter: _PondPainter(
                    t: _surface.value,
                    biting: _phase == _Phase.biting,
                    tug: _tug.value,
                    lineDown: _phase != _Phase.caught,
                  ),
                ),
              ),
            ),
            // Bandeau haut : titre + fermer.
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: widget.onClose,
                    ),
                    const Spacer(),
                    const Text('Pêche',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1)),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
            // Zone basse : invite + bouton selon la phase.
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                child: _phase == _Phase.caught
                    ? _caughtPanel()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _hint,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _phase == _Phase.biting
                                  ? const Color(0xFFFFD27A)
                                  : Colors.white70,
                              fontSize: _phase == _Phase.biting ? 20 : 15,
                              fontWeight: _phase == _Phase.biting
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_phase == _Phase.idle)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE8B96B),
                                foregroundColor: const Color(0xFF2A2018),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 14),
                              ),
                              onPressed: _cast,
                              icon: const Icon(Icons.waves),
                              label: const Text('Lancer la ligne'),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _caughtPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xCC1C1813),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8B96B), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Quelque chose au bout de la ligne…',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Color(0xFFF0E6D2),
                fontSize: 16,
                fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tu la retrouveras dans tes cartes, au prochain trajet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE8B96B),
              foregroundColor: const Color(0xFF2A2018),
            ),
            onPressed: widget.onClose,
            child: const Text('Ranger la canne'),
          ),
        ],
      ),
    );
  }
}

/// Peint l'étang nocturne : dégradé froid, reflet de lune, ondulations
/// sinusoïdales, la ligne + le flotteur (qui plonge quand ça mord).
class _PondPainter extends CustomPainter {
  _PondPainter({
    required this.t,
    required this.biting,
    required this.tug,
    required this.lineDown,
  });

  final double t; // 0..1 phase continue
  final bool biting;
  final double tug; // 0..1 secousse
  final bool lineDown;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Fond : ciel froid en haut, eau noire en bas.
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1B2A38), Color(0xFF0C1420), Color(0xFF060A12)],
        stops: [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bg);

    final surfaceY = h * 0.34;

    // Lune + halo.
    final moonC = Offset(w * 0.78, h * 0.16);
    canvas.drawCircle(
        moonC,
        h * 0.16,
        Paint()
          ..color = const Color(0x33CFE3F2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40));
    canvas.drawCircle(moonC, h * 0.06, Paint()..color = const Color(0xFFE8F0F6));

    // Reflet de lune sur l'eau (traits ondulés).
    final reflectPaint = Paint()
      ..color = const Color(0x33CFE3F2)
      ..strokeWidth = 2;
    for (int i = 0; i < 7; i++) {
      final ry = surfaceY + i * (h * 0.07);
      final wob = math.sin(t * 2 * math.pi + i) * (4 + i * 1.5);
      canvas.drawLine(Offset(w * 0.78 - 26 + wob, ry),
          Offset(w * 0.78 + 26 - wob, ry), reflectPaint);
    }

    // Ondulations de surface (plusieurs sinusoïdes douces).
    final wavePaint = Paint()
      ..color = const Color(0x224F7894)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (int row = 0; row < 5; row++) {
      final baseY = surfaceY + row * (h * 0.11);
      final path = Path();
      for (double x = 0; x <= w; x += 8) {
        final y = baseY +
            math.sin((x / w * 4 * math.pi) + t * 2 * math.pi + row) * 4;
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, wavePaint);
    }

    // Ligne + flotteur.
    final floatX = w * 0.42;
    // bob doux en attente ; plongée nette quand ça mord (tug).
    final bob = math.sin(t * 2 * math.pi) * 3;
    final dip = biting ? tug * 26 : 0.0;
    final floatY = surfaceY + 18 + bob + dip;

    if (lineDown) {
      canvas.drawLine(
          Offset(floatX, 0),
          Offset(floatX, floatY),
          Paint()
            ..color = const Color(0x88FFFFFF)
            ..strokeWidth = 1.2);

      // Flotteur (bouchon rouge/blanc).
      canvas.drawCircle(
          Offset(floatX, floatY), 9, Paint()..color = const Color(0xFFE0533F));
      canvas.drawCircle(Offset(floatX, floatY - 3), 5,
          Paint()..color = const Color(0xFFF3EDE2));

      // Ronds dans l'eau quand ça mord.
      if (biting) {
        final ring = Paint()
          ..color = Color.fromRGBO(255, 210, 122, (1 - tug) * 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawCircle(Offset(floatX, floatY + 6), 10 + tug * 22, ring);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PondPainter old) =>
      old.t != t || old.biting != biting || old.tug != tug ||
      old.lineDown != lineDown;
}
