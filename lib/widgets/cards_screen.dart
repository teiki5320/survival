// Écran du mode cartes "Reigns-like".
//
// Design : une carte centrale qu'on swipe à gauche ou à droite. La carte
// s'incline et glisse dans le sens du drag ; un bandeau de choix apparaît
// du côté visé. Au lâcher au-delà d'un seuil, le choix est validé, une
// courte conséquence s'affiche, puis la carte suivante entre. Les 4 jauges
// (soif/faim/bois/moral) sont en haut, la progression des gares en dessous.
//
// Palette : warm honey/cream/amber dedans, cold blue dehors — cohérent avec
// l'esthétique Ghibli/lofi du jeu.

import 'dart:math';

import 'package:flutter/material.dart';

import '../data/cards_data.dart';
import '../models/reigns_engine.dart';

class CardsScreen extends StatefulWidget {
  const CardsScreen({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen>
    with TickerProviderStateMixin {
  late final ReignsEngine _engine;
  late EngineState _state;

  // Position de drag horizontale (px) de la carte courante.
  double _drag = 0;
  // Conséquence courte affichée après un choix.
  String? _flash;

  late final AnimationController _flyCtrl; // sortie de carte
  late final AnimationController _enterCtrl; // entrée de carte
  Animation<Offset>? _flyAnim;

  static const double _threshold = 110; // px pour valider un swipe

  @override
  void initState() {
    super.initState();
    _engine = ReignsEngine(
      segments: trainCosyScenario,
      resolveEnding: resolveTrainCosyEnding,
    );
    _state = _engine.start();
    _flyCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _enterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 360))
      ..value = 1;
  }

  @override
  void dispose() {
    _flyCtrl.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  void _commit(bool right) {
    final card = _state.card;
    if (card == null) return;
    final choice = right ? card.right : card.left;
    final w = MediaQuery.of(context).size.width;
    _flyAnim = Tween<Offset>(
      begin: Offset(_drag, 0),
      end: Offset(right ? w * 1.2 : -w * 1.2, 60),
    ).animate(CurvedAnimation(parent: _flyCtrl, curve: Curves.easeIn));
    _flyCtrl.forward(from: 0).then((_) {
      final next = _engine.choose(choice);
      setState(() {
        _state = next;
        _drag = 0;
        _flash = choice.resultText;
      });
      _flyCtrl.value = 0;
      _enterCtrl.forward(from: 0);
      // efface le flash après un moment
      if (choice.resultText != null) {
        Future.delayed(const Duration(milliseconds: 2200), () {
          if (mounted) setState(() => _flash = null);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final inCold = _engine.gareIndex >= 7; // gares froides
    final bgTop = inCold ? const Color(0xFF243447) : const Color(0xFF2A2018);
    final bgBottom = inCold ? const Color(0xFF111A26) : const Color(0xFF14100B);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgTop, bgBottom],
          ),
        ),
        child: SafeArea(
          child: _state.finished
              ? _buildEnding()
              : Column(
                  children: [
                    _topBar(),
                    _statsRow(),
                    _gareProgress(),
                    Expanded(child: _cardArea()),
                    _hintRow(),
                    const SizedBox(height: 8),
                  ],
                ),
        ),
      ),
    );
  }

  // --- barre du haut ---
  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: widget.onClose,
          ),
          const Spacer(),
          Text(
            'Gare ${min(_engine.gareIndex + 1, 14)} / 14',
            style: const TextStyle(
                color: Colors.white60,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  // --- les 4 jauges ---
  Widget _statsRow() {
    final s = _engine.stats;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _gauge('💧', s[Stat.soif]!, const Color(0xFF6FAEDF)),
          _gauge('🍖', s[Stat.faim]!, const Color(0xFFE89B5C)),
          _gauge('🪵', s[Stat.bois]!, const Color(0xFFB5854E)),
          _gauge('❤️', s[Stat.moral]!, const Color(0xFFD98A8A)),
        ],
      ),
    );
  }

  Widget _gauge(String emoji, int value, Color color) {
    final low = value <= 20;
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 3),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 38,
              height: 38,
              child: CircularProgressIndicator(
                value: value / 100,
                strokeWidth: 4,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation(low ? Colors.redAccent : color),
              ),
            ),
            Text('$value',
                style: TextStyle(
                    color: low ? Colors.redAccent : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  // --- ligne de progression des 14 gares ---
  Widget _gareProgress() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: List.generate(14, (i) {
          final done = i < _engine.gareIndex;
          final cur = i == _engine.gareIndex;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              height: 4,
              decoration: BoxDecoration(
                color: done
                    ? const Color(0xFFE8B96B)
                    : cur
                        ? const Color(0xFFE8B96B).withValues(alpha: 0.5)
                        : Colors.white12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  // --- zone de carte (drag + animation) ---
  Widget _cardArea() {
    final card = _state.card;
    if (card == null) return const SizedBox.shrink();

    final w = MediaQuery.of(context).size.width;
    final rot = (_drag / w) * 0.35; // inclinaison
    final leftActive = _drag < -30;
    final rightActive = _drag > 30;

    return GestureDetector(
      onHorizontalDragUpdate: (d) => setState(() => _drag += d.delta.dx),
      onHorizontalDragEnd: (_) {
        if (_drag > _threshold) {
          _commit(true);
        } else if (_drag < -_threshold) {
          _commit(false);
        } else {
          setState(() => _drag = 0);
        }
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_flyCtrl, _enterCtrl]),
        builder: (context, _) {
          double dx = _drag;
          double dy = 0;
          double rotation = rot;
          double scale = 1;
          if (_flyCtrl.isAnimating && _flyAnim != null) {
            dx = _flyAnim!.value.dx;
            dy = _flyAnim!.value.dy;
            rotation = (dx / w) * 0.35;
          } else if (_enterCtrl.isAnimating) {
            scale = 0.9 + 0.1 * _enterCtrl.value;
          }
          return Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // indices gauche / droite révélés par le drag
                _choiceTag(card.left.label, false, leftActive),
                _choiceTag(card.right.label, true, rightActive),
                Transform.translate(
                  offset: Offset(dx, dy),
                  child: Transform.rotate(
                    angle: rotation,
                    child: Transform.scale(
                      scale: scale,
                      child: _cardFace(card, leftActive, rightActive),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _choiceTag(String label, bool right, bool active) {
    return Align(
      alignment: right ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: AnimatedOpacity(
          opacity: active ? 1 : 0.15,
          duration: const Duration(milliseconds: 120),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 120),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (active
                      ? const Color(0xFFE8B96B)
                      : Colors.white)
                  .withValues(alpha: active ? 0.95 : 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: active ? const Color(0xFF2A2018) : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cardFace(StoryCard card, bool leftActive, bool rightActive) {
    final w = MediaQuery.of(context).size.width;
    final cardW = min(w * 0.62, 340.0);
    final isGare = card.kind == CardKind.gare;
    return Container(
      width: cardW,
      constraints: BoxConstraints(
        minHeight: 200,
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF6E7CC), Color(0xFFE9D2A8)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isGare ? const Color(0xFFB5854E) : const Color(0x33000000),
          width: isGare ? 2.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (card.speaker != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFB5854E).withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  card.speaker!.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF6B4F2E),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  card.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF3A2A18),
                    fontSize: 16,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- indices de swipe en bas + flash de conséquence ---
  Widget _hintRow() {
    if (_flash != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Text(
          _flash!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFE8B96B),
            fontStyle: FontStyle.italic,
            fontSize: 14,
          ),
        ),
      );
    }
    final card = _state.card;
    if (card == null) return const SizedBox(height: 32);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _swipeButton(card.left.label, false),
          const Icon(Icons.swipe, color: Colors.white24, size: 22),
          _swipeButton(card.right.label, true),
        ],
      ),
    );
  }

  Widget _swipeButton(String label, bool right) {
    return Flexible(
      child: GestureDetector(
        onTap: () => _commit(right),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!right)
              const Icon(Icons.chevron_left, color: Colors.white54, size: 20),
            Flexible(
              child: Text(
                label,
                textAlign: right ? TextAlign.right : TextAlign.left,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            if (right)
              const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
          ],
        ),
      ),
    );
  }

  // --- écran de fin ---
  Widget _buildEnding() {
    final id = _state.endingId ?? 'deuil';
    final e = endings[id] ?? endings['deuil']!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              e.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFE8B96B),
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              e.body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8B96B),
                    foregroundColor: const Color(0xFF2A2018),
                  ),
                  onPressed: () {
                    setState(() {
                      _state = _engine.start();
                      _drag = 0;
                      _flash = null;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Recommencer'),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: widget.onClose,
                  child: const Text('Quitter',
                      style: TextStyle(color: Colors.white54)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
