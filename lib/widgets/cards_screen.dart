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

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/cards_data.dart';
import '../models/game_state.dart';
import '../models/reigns_engine.dart';
import 'games/roof_defense_game.dart';

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

  // Annonce plein écran à l'arrivée d'une gare ("GARE X — Nom").
  late final AnimationController _gareCtrl;
  int _announcedGare = -1;
  String _gareLabel = '';

  // Combat de gare en cours (index de gare) : superpose le mini-jeu plein
  // écran. null = pas de combat. Déclenché à l'arrivée à une gare non encore
  // défendue (sauf la gare tuto 0).
  int? _combatGare;

  // Tic 1s : régénère les crédits en temps réel + rafraîchit le compte à
  // rebours affiché. Flash quand on tente un swipe sans crédit.
  Timer? _creditTimer;
  bool _noCreditFlash = false;

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
    _state = _engine.startOrResume();
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
    _gareCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1700));
    // Régen des crédits (rattrape le temps écoulé hors-ligne) + tic 1s pour
    // animer le compte à rebours et créditer en direct.
    GameState.instance.refreshCredits();
    _creditTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      GameState.instance.refreshCredits();
      setState(() {});
    });
    // Présente la première carte (combat de gare si besoin, sinon annonce).
    _presentCurrentCard();
  }

  @override
  void dispose() {
    _creditTimer?.cancel();
    _flyCtrl.dispose();
    _enterCtrl.dispose();
    _gareCtrl.dispose();
    for (final c in _pulse.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Présente la carte courante : si c'est une gare pas encore défendue (hors
  /// gare tuto 0), lance le COMBAT plein écran d'abord ; sinon enchaîne sur
  /// l'annonce de gare classique.
  void _presentCurrentCard() {
    // NB : appelé depuis initState (avant le 1er build) et depuis
    // _revealPending (déjà dans un setState) -> on assigne sans setState.
    final card = _state.card;
    if (card != null && card.kind == CardKind.gare) {
      final idx = _engine.gareIndex;
      final done = GameState.instance.cardFlags.contains('combatDone_$idx');
      if (idx >= 1 && !done) {
        _combatGare = idx;
        return; // l'annonce de gare se fera après le combat
      }
    }
    _maybeAnnounceGare();
  }

  /// Fin du combat de gare : applique les récompenses (ressources + flags de
  /// tier), reconstruit la variante de gare selon le score, puis révèle la
  /// carte de gare.
  void _onCombatResult(int idx, int score) {
    GameState.instance.applyCombatRewards(idx, score);
    _engine.rebuildGareCards();
    // Pulse les jauges qui viennent d'être ravitaillées.
    for (final st in Stat.values) {
      _pulseSign[st] = 1;
      _pulse[st]?.forward(from: 0);
    }
    setState(() {
      _combatGare = null;
      _state = _engine.current;
    });
    _maybeAnnounceGare();
  }

  /// Si la carte courante est une gare jamais annoncée, déclenche l'overlay
  /// plein écran "GARE X — Nom".
  void _maybeAnnounceGare() {
    final card = _state.card;
    if (card == null || card.kind != CardKind.gare) return;
    if (_announcedGare == _engine.gareIndex) return;
    _announcedGare = _engine.gareIndex;
    _gareLabel = card.speaker ?? 'Gare';
    _gareCtrl.forward(from: 0);
  }

  bool get _showingResult => _resultText != null;

  void _commit(bool right) {
    final card = _state.card;
    if (card == null || _showingResult) return;
    if (_flyCtrl.isAnimating) return;
    // Tirer une carte coûte 1 crédit. À sec : on annule le swipe et on
    // signale qu'il faut attendre la recharge. En mode debug : gratuit (on
    // joue les cartes comme on veut).
    if (!GameState.instance.debugMode &&
        !GameState.instance.spendCardCredit()) {
      setState(() {
        _drag = 0;
        _noCreditFlash = true;
      });
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _noCreditFlash = false);
      });
      return;
    }
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
    _presentCurrentCard();
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
        child: Stack(
          children: [
            SafeArea(
              child: _state.finished
                  ? _buildEnding()
                  : Column(
                      children: [
                        _topBar(),
                        _statsRow(),
                        _gareProgress(),
                        _debugBar(),
                        // Marge sous le trait de progression : la carte ne doit
                        // plus passer par-dessus la ligne des gares.
                        const SizedBox(height: 16),
                        Expanded(child: _cardArea()),
                        _bottomZone(),
                        const SizedBox(height: 10),
                      ],
                    ),
            ),
            _gareAnnounce(),
            if (_combatGare != null)
              Positioned.fill(
                child: RoofDefenseGame(
                  key: ValueKey('gareCombat_$_combatGare'),
                  onExit: () {},
                  onResult: (score) => _onCombatResult(_combatGare!, score),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- overlay d'annonce de gare : assombrit l'écran, fait surgir le titre
  // doré, puis s'efface. Non interactif (laisse passer les taps une fois fini).
  Widget _gareAnnounce() {
    return AnimatedBuilder(
      animation: _gareCtrl,
      builder: (context, _) {
        final t = _gareCtrl.value;
        if (t == 0 || t >= 1) return const SizedBox.shrink();
        // courbe : apparition rapide, maintien, fondu de sortie
        final fade = t < 0.18
            ? t / 0.18
            : t > 0.78
                ? (1 - t) / 0.22
                : 1.0;
        final slide = (1 - Curves.easeOut.transform((t / 0.3).clamp(0, 1))) * 28;
        const gold = Color(0xFFE8B96B);
        final num = min(_announcedGare + 1, 14);
        return Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: fade.clamp(0, 1),
              child: Container(
                color: Colors.black.withValues(alpha: 0.66 * fade),
                child: Center(
                  child: Transform.translate(
                    offset: Offset(0, slide),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: gold, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: gold.withValues(alpha: 0.5 * fade),
                                blurRadius: 30,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.train, color: gold, size: 32),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'GARE $num',
                          style: const TextStyle(
                            color: gold,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            _gareLabel,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: 80,
                          height: 2,
                          color: gold.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // mm:ss à partir de millisecondes.
  static String _fmt(int ms) {
    final s = (ms / 1000).ceil();
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  // --- barre DEBUG (mode debug uniquement) : navigation libre dans les
  // cartes pour tester le contenu. Passer une carte = avance sans effet ;
  // ◀/▶ Gare = saute au segment d'une autre gare (combat zappé).
  Widget _debugBar() {
    if (!GameState.instance.debugMode) return const SizedBox.shrink();
    Widget btn(String label, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E7A3A).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF49D17B), width: 1),
            ),
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          btn('◀ Gare', () => _debugJump(_engine.gareIndex - 1)),
          btn('Passer ▸', _debugSkip),
          btn('Gare ▶', () => _debugJump(_engine.gareIndex + 1)),
        ],
      ),
    );
  }

  void _debugSkip() {
    final next = _engine.debugSkipCard();
    setState(() => _state = next);
    _maybeAnnounceGare();
  }

  void _debugJump(int idx) {
    final next = _engine.debugGoToGare(idx);
    _announcedGare = -1; // force la ré-annonce de la nouvelle gare
    setState(() {
      _state = next;
      _combatGare = null; // pas de combat forcé en navigation debug
      _resultText = null;
      _pending = null;
    });
    _maybeAnnounceGare();
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
          _creditsChip(),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  // Pastille crédits : N petits jetons + compte à rebours du prochain.
  Widget _creditsChip() {
    final gs = GameState.instance;
    final n = gs.cardCredits;
    const max = GameState.cardCreditsMax;
    final next = gs.msToNextCredit;
    final empty = n <= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (_noCreditFlash ? Colors.redAccent : const Color(0xFFE8B96B))
            .withValues(alpha: _noCreditFlash ? 0.30 : 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _noCreditFlash
              ? Colors.redAccent
              : const Color(0xFFE8B96B).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < max; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Icon(
                Icons.circle,
                size: 9,
                color: i < n
                    ? const Color(0xFFE8C56A)
                    : Colors.white.withValues(alpha: 0.18),
              ),
            ),
          if (next > 0) ...[
            const SizedBox(width: 6),
            Text(
              _fmt(next),
              style: TextStyle(
                color: empty ? const Color(0xFFD98A8A) : Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- les 4 jauges ---
  Widget _statsRow() {
    final s = _engine.stats;
    return Padding(
      // Remonté (vertical réduit) pour dégager le trait de progression.
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
    return card.kind == CardKind.gare
        ? _gareFace(card)
        : _fillerFace(card);
  }

  // --- carte de REMPLISSAGE : parchemin clair, léger ---
  Widget _fillerFace(StoryCard card) {
    final w = MediaQuery.of(context).size.width;
    final cardW = min(w * 0.6, 330.0);
    return Container(
      width: cardW,
      constraints: BoxConstraints(
        minHeight: 190,
        maxHeight: MediaQuery.of(context).size.height * 0.58,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF6E7CC), Color(0xFFE9D2A8)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x33000000), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Center(
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
      ),
    );
  }

  // --- carte de GARE : sombre, solennelle, liseré doré, bandeau titre ---
  Widget _gareFace(StoryCard card) {
    final w = MediaQuery.of(context).size.width;
    final cardW = min(w * 0.66, 360.0);
    const gold = Color(0xFFE8B96B);
    return Container(
      width: cardW,
      constraints: BoxConstraints(
        minHeight: 230,
        maxHeight: MediaQuery.of(context).size.height * 0.62,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A2A1A), Color(0xFF241812)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: gold, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: gold.withValues(alpha: 0.35),
            blurRadius: 28,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // bandeau titre de la gare
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.16),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: const Border(
                bottom: BorderSide(color: gold, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.train, color: gold, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    (card.speaker ?? 'GARE').toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: gold,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Center(
                child: SingleChildScrollView(
                  child: Text(
                    card.text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFF3E6CF),
                      fontSize: 17,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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
    // Plus de crédits : on bloque le tirage et on invite à attendre.
    // (En debug le tirage est gratuit -> pas de message.)
    if (GameState.instance.cardCredits <= 0 && !GameState.instance.debugMode) {
      final next = GameState.instance.msToNextCredit;
      return Container(
        height: 56,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Plus de crédits — le voyage reprend son souffle.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFD98A8A), fontSize: 12),
            ),
            const SizedBox(height: 3),
            Text(
              next > 0
                  ? 'Prochaine carte dans ${_fmt(next)}'
                  : 'Recharge…',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      );
    }
    // Les choix s'affichent sur les CÔTÉS de la carte pendant le glissé
    // (_choiceTag). On ne garde donc en bas qu'un discret indice de swipe,
    // plus les libellés blancs en double à gauche/droite.
    return const SizedBox(
      height: 56,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swipe, color: Colors.white30, size: 20),
            SizedBox(width: 8),
            Text('Glisse à gauche ou à droite pour choisir',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // --- écran de fin ---
  Widget _buildEnding() {
    final id = _state.endingId ?? 'ensemble';
    final e = endings[id] ?? endings['ensemble']!;
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
