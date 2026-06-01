// Écran du mode cartes "Reigns-like".
//
// Design : une carte centrale qu'on swipe à gauche ou à droite. Chaque
// choix affiche À L'AVANCE ce qu'on gagne / perd (deltas de stats). Au
// lâcher au-delà d'un seuil, le choix est validé : la carte glisse, puis
// une CARTE DE CONSÉQUENCE prend sa place (texte + bilan des stats) et
// reste affichée jusqu'à ce qu'on tape pour passer à la suite. Pas de
// minuterie — on lit à son rythme.
//
// Les 4 jauges (soif/faim/bois/moral) sont en haut, la progression des
// gares en dessous. Palette warm honey/cream dedans, cold blue dehors.

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

  // Drag horizontal (px) de la carte courante.
  double _drag = 0;

  // Quand on a choisi : on affiche la conséquence et on attend un tap.
  String? _resultText;
  Map<Stat, int> _resultDeltas = const {};
  EngineState? _pending; // état à révéler au tap

  late final AnimationController _flyCtrl; // sortie de carte
  late final AnimationController _enterCtrl; // entrée de carte
  Animation<Offset>? _flyAnim;

  // Une impulsion par stat : se déclenche quand la jauge change vraiment,
  // pour la faire pulser (scale + halo) au moment de l'application.
  final Map<Stat, AnimationController> _pulse = {};
  // Sens du dernier changement par stat (pour colorer le halo).
  final Map<Stat, int> _pulseSign = {};

  static const double _threshold = 110;

  // Métadonnées d'affichage des stats.
  static const Map<Stat, String> _emoji = {
    Stat.soif: '💧',
    Stat.faim: '🍖',
    Stat.bois: '🪵',
    Stat.moral: '❤️',
  };
  static const Map<Stat, Color> _color = {
    Stat.soif: Color(0xFF6FAEDF),
    Stat.faim: Color(0xFFE89B5C),
    Stat.bois: Color(0xFFB5854E),
    Stat.moral: Color(0xFFD98A8A),
  };

  @override
  void initState() {
    super.initState();
    _engine = ReignsEngine(
      segments: trainCosyScenario,
      resolveEnding: resolveTrainCosyEnding,
    );
    _state = _engine.start();
    _flyCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _enterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 340))
      ..value = 1;
    for (final st in Stat.values) {
      _pulse[st] = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 520));
      _pulseSign[st] = 0;
    }
  }

  @override
  void dispose() {
    _flyCtrl.dispose();
    _enterCtrl.dispose();
    for (final c in _pulse.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _showingResult => _resultText != null;

  void _commit(bool right) {
    final card = _state.card;
    if (card == null || _showingResult) return;
    final choice = right ? card.right : card.left;
    final w = MediaQuery.of(context).size.width;
    _flyAnim = Tween<Offset>(
      begin: Offset(_drag, 0),
      end: Offset(right ? w * 1.2 : -w * 1.2, 60),
    ).animate(CurvedAnimation(parent: _flyCtrl, curve: Curves.easeIn));
    _flyCtrl.forward(from: 0).then((_) {
      final next = _engine.choose(choice); // applique les effets
      // pulse les jauges qui ont effectivement changé
      choice.effects.forEach((st, delta) {
        if (delta == 0) return;
        _pulseSign[st] = delta;
        _pulse[st]?.forward(from: 0);
      });
      setState(() {
        _drag = 0;
        _pending = next;
        // Si la carte n'a pas de conséquence écrite, on enchaîne direct.
        if (choice.resultText == null) {
          _revealPending();
        } else {
          _resultText = choice.resultText;
          _resultDeltas = choice.effects;
        }
      });
      _flyCtrl.value = 0;
    });
  }

  void _revealPending() {
    _state = _pending ?? _state;
    _pending = null;
    _resultText = null;
    _resultDeltas = const {};
    _enterCtrl.forward(from: 0);
  }

  void _tapAdvance() {
    if (!_showingResult) return;
    setState(_revealPending);
  }

  @override
  Widget build(BuildContext context) {
    final inCold = _engine.gareIndex >= 7;
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
                    _bottomZone(),
                    const SizedBox(height: 10),
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
        children: Stat.values.map((st) {
          // surligne la jauge qui va changer pendant un drag
          int preview = 0;
          if (!_showingResult && _state.card != null && _drag.abs() > 30) {
            final ch = _drag > 0 ? _state.card!.right : _state.card!.left;
            preview = ch.effects[st] ?? 0;
          }
          return _gauge(st, s[st]!, preview);
        }).toList(),
      ),
    );
  }

  Widget _gauge(Stat st, int value, int preview) {
    final low = value <= 20;
    final color = _color[st]!;
    final pulseCtrl = _pulse[st]!;
    final gain = (_pulseSign[st] ?? 0) > 0;
    final haloColor = gain ? const Color(0xFF8BD18B) : Colors.redAccent;
    return Column(
      children: [
        Text(_emoji[st]!, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 3),
        AnimatedBuilder(
          animation: pulseCtrl,
          builder: (context, child) {
            // courbe d'impulsion : 0→1→0 (un aller-retour doux)
            final t = pulseCtrl.value;
            final p = t == 0 ? 0.0 : (t < 0.5 ? t * 2 : (1 - t) * 2);
            final scale = 1 + 0.28 * p;
            return Transform.scale(
              scale: scale,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: p == 0
                      ? null
                      : [
                          BoxShadow(
                            color: haloColor.withValues(alpha: 0.7 * p),
                            blurRadius: 14 * p,
                            spreadRadius: 3 * p,
                          ),
                        ],
                ),
                child: child,
              ),
            );
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  value: value / 100,
                  strokeWidth: 4,
                  backgroundColor: Colors.white12,
                  valueColor:
                      AlwaysStoppedAnimation(low ? Colors.redAccent : color),
                ),
              ),
              Text('$value',
                  style: TextStyle(
                      color: low ? Colors.redAccent : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        // aperçu du changement pendant le drag
        SizedBox(
          height: 16,
          child: preview == 0
              ? null
              : Text(
                  preview > 0 ? '+$preview' : '$preview',
                  style: TextStyle(
                    color: preview > 0
                        ? const Color(0xFF8BD18B)
                        : Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }

  // --- progression des 14 gares ---
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

  // --- zone de carte ---
  Widget _cardArea() {
    if (_showingResult) return _resultCard();

    final card = _state.card;
    if (card == null) return const SizedBox.shrink();

    final w = MediaQuery.of(context).size.width;
    final rot = (_drag / w) * 0.35;
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
          double dx = _drag, dy = 0, rotation = rot, scale = 1;
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
                _choiceTag(card.left, false, leftActive),
                _choiceTag(card.right, true, rightActive),
                Transform.translate(
                  offset: Offset(dx, dy),
                  child: Transform.rotate(
                    angle: rotation,
                    child: Transform.scale(
                      scale: scale,
                      child: _cardFace(card),
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

  // étiquette de choix révélée pendant le drag (avec deltas)
  Widget _choiceTag(CardChoice choice, bool right, bool active) {
    return Align(
      alignment: right ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: AnimatedOpacity(
          opacity: active ? 1 : 0.12,
          duration: const Duration(milliseconds: 120),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 130),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8B96B)
                  .withValues(alpha: active ? 0.95 : 0.3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  choice.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF2A2018),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                if (choice.effects.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _deltaChips(choice.effects, dark: true),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // petites pastilles 🍖+10 🪵-6
  Widget _deltaChips(Map<Stat, int> fx, {bool dark = false}) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: fx.entries.map((e) {
        final pos = e.value > 0;
        return Text(
          '${_emoji[e.key]}${pos ? '+' : ''}${e.value}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: pos
                ? (dark ? const Color(0xFF2C6E2C) : const Color(0xFF8BD18B))
                : (dark ? const Color(0xFF9E2B2B) : Colors.redAccent),
          ),
        );
      }).toList(),
    );
  }

  Widget _cardFace(StoryCard card) {
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
              _speakerBadge(card.speaker!),
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

  Widget _speakerBadge(String s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFB5854E).withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          s.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF6B4F2E),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      );

  // --- carte de conséquence (reste jusqu'au tap) ---
  Widget _resultCard() {
    final w = MediaQuery.of(context).size.width;
    final cardW = min(w * 0.66, 360.0);
    return GestureDetector(
      onTap: _tapAdvance,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Container(
          width: cardW,
          constraints: BoxConstraints(
            minHeight: 180,
            maxHeight: MediaQuery.of(context).size.height * 0.58,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1813),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE8B96B), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      _resultText ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFF0E6D2),
                        fontSize: 16,
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
                if (_resultDeltas.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _deltaChips(_resultDeltas),
                ],
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.touch_app, color: Colors.white38, size: 16),
                    SizedBox(width: 6),
                    Text('Toucher pour continuer',
                        style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- zone du bas : boutons de choix (avec deltas) ou rien en résultat ---
  Widget _bottomZone() {
    if (_showingResult) return const SizedBox(height: 56);
    final card = _state.card;
    if (card == null) return const SizedBox(height: 56);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _swipeButton(card.left, false)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.swipe, color: Colors.white24, size: 22),
          ),
          Expanded(child: _swipeButton(card.right, true)),
        ],
      ),
    );
  }

  Widget _swipeButton(CardChoice choice, bool right) {
    return GestureDetector(
      onTap: () => _commit(right),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment:
            right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!right)
                const Icon(Icons.chevron_left,
                    color: Colors.white54, size: 20),
              Flexible(
                child: Text(
                  choice.label,
                  textAlign: right ? TextAlign.right : TextAlign.left,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              if (right)
                const Icon(Icons.chevron_right,
                    color: Colors.white54, size: 20),
            ],
          ),
          if (choice.effects.isNotEmpty) ...[
            const SizedBox(height: 4),
            _deltaChips(choice.effects),
          ],
        ],
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
                      _resultText = null;
                      _resultDeltas = const {};
                      _pending = null;
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
