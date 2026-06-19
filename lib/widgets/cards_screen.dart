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
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/cards_data.dart';
import '../models/game_state.dart';
import '../models/reigns_engine.dart';

/// Emblèmes de carte DESSINÉS AU TRAIT (SVG inline), accordés à la palette
/// honey/gold du jeu — remplacent les icônes système (placeholders). Tracés
/// stroke-only, teintés par `ColorFilter` selon l'ambiance de la carte.
const Map<CardArt, String> _kEmblemSvg = {
  CardArt.water:
      '<svg viewBox="0 0 48 48"><path d="M24 7 C24 7 11 23 11 31 a13 13 0 0 0 26 0 C37 23 24 7 24 7 Z" fill="none" stroke="#000" stroke-width="2.4" stroke-linejoin="round"/><path d="M18.5 31 a5.5 5.5 0 0 0 5.5 5.5" fill="none" stroke="#000" stroke-width="2" stroke-linecap="round"/></svg>',
  CardArt.fire:
      '<svg viewBox="0 0 48 48"><path d="M24 6 c5 8 11 11 11 19 a11 11 0 0 1 -22 0 c0 -5 3 -8 5.5 -10 c0.5 3 2.5 4 4 4.5 c-2.5 -5.5 -0.5 -9.5 1.5 -13.5 Z" fill="none" stroke="#000" stroke-width="2.4" stroke-linejoin="round"/></svg>',
  CardArt.cold:
      '<svg viewBox="0 0 48 48"><g fill="none" stroke="#000" stroke-width="2.2" stroke-linecap="round"><line x1="24" y1="8" x2="24" y2="40"/><line x1="11.6" y1="15" x2="36.4" y2="33"/><line x1="36.4" y1="15" x2="11.6" y2="33"/><path d="M20 12 l4 -3 4 3 M20 36 l4 3 4 -3 M13 19 l-0.5 -5 5 0.5 M35 29 l0.5 5 -5 -0.5 M35 19 l0.5 -5 -5 0.5 M13 29 l-0.5 5 5 -0.5"/></g></svg>',
  CardArt.radio:
      '<svg viewBox="0 0 48 48"><circle cx="17" cy="32" r="2.6" fill="#000"/><g fill="none" stroke="#000" stroke-width="2.2" stroke-linecap="round"><path d="M22 28 a8 8 0 0 1 0 8"/><path d="M26.5 24 a14 14 0 0 1 0 16"/><path d="M31 20 a20 20 0 0 1 0 24"/></g></svg>',
  CardArt.food:
      '<svg viewBox="0 0 48 48"><g fill="none" stroke="#000" stroke-width="2.4" stroke-linejoin="round"><rect x="15" y="13" width="18" height="23" rx="2"/><line x1="15" y1="19" x2="33" y2="19"/><line x1="15" y1="30" x2="33" y2="30"/></g></svg>',
  CardArt.refuge:
      '<svg viewBox="0 0 48 48"><g fill="none" stroke="#000" stroke-width="2.4" stroke-linejoin="round" stroke-linecap="round"><path d="M9 25 L24 12 L39 25"/><path d="M13 22 V38 H35 V22"/><path d="M21 38 V29 H27 V38"/></g></svg>',
  CardArt.hope:
      '<svg viewBox="0 0 48 48"><g fill="none" stroke="#000" stroke-width="2.3" stroke-linecap="round"><line x1="8" y1="34" x2="40" y2="34"/><path d="M16 34 a8 8 0 0 1 16 0"/><line x1="24" y1="14" x2="24" y2="20"/><line x1="13" y1="18" x2="16" y2="22"/><line x1="35" y1="18" x2="32" y2="22"/></g></svg>',
  CardArt.memory:
      '<svg viewBox="0 0 48 48"><path d="M24 14 c-4 -3 -9.5 -3 -13.5 -1 v21 c4 -2 9.5 -2 13.5 1 c4 -3 9.5 -3 13.5 -1 v-21 c-4 -2 -9.5 -2 -13.5 1 Z M24 14 v21" fill="none" stroke="#000" stroke-width="2.2" stroke-linejoin="round"/></svg>',
  CardArt.pillards:
      '<svg viewBox="0 0 48 48"><g fill="none" stroke="#000" stroke-width="2.6" stroke-linecap="round"><line x1="12" y1="37" x2="19" y2="13"/><line x1="24" y1="37" x2="24" y2="11"/><line x1="36" y1="37" x2="29" y2="13"/><line x1="10" y1="25" x2="38" y2="25"/></g></svg>',
};

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
  String? _resultReaction; // réplique perso à afficher sous la conséquence
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

  // Tic 1s : régénère les crédits en temps réel + rafraîchit le compte à
  // rebours affiché. Flash quand on tente un swipe sans crédit.
  Timer? _creditTimer;

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
    // Plus longue (~3,4 s) qu'avant : laisse le temps de lire la ligne
    // d'ambiance de la gare (mini-cinématique texte) sous le titre.
    _gareCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3400));
    // Régen des crédits + tic 1s pour animer le compte à rebours. Crédits
    // DÉSACTIVÉS pour l'instant -> on n'arme PAS le timer (évite un rebuild
    // complet de l'écran à 1 Hz pour rien). À réarmer si on réactive le rythme.
    GameState.instance.refreshCredits();
    if (GameState.creditsEnabled) {
      _creditTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        GameState.instance.refreshCredits();
        setState(() {});
      });
    }
    // Présente la première carte (annonce de gare le cas échéant).
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

  /// Présente la carte courante : annonce de gare le cas échéant. Les gares se
  /// jouent entièrement en cartes/choix (pas de mini-jeu).
  void _presentCurrentCard() {
    _maybeAnnounceGare();
  }

  /// Si la carte courante est une gare jamais annoncée, déclenche l'overlay
  /// plein écran "GARE X — Nom".
  void _maybeAnnounceGare() {
    if (_state.halt) return; // pas d'annonce sous l'écran de halte
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
    if (card == null || _showingResult || _state.halt) return;
    if (_flyCtrl.isAnimating) return;
    // Le rythme n'est plus géré carte par carte (ancien système de crédits)
    // mais gare par gare via l'ÉLAN : la HALTE (écran dédié) bloque entre deux
    // gares quand Shen est à bout. Ici, on tire librement dans le segment.
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
          _resultReaction = choice.reaction;
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
    _resultReaction = null;
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
                  : (_state.halt && !_showingResult)
                  ? _buildHalt()
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
                        const SizedBox(height: 16),
                        // Mini-cinématique texte : une ligne d'ambiance par gare.
                        if (_announcedGare >= 0 &&
                            _announcedGare < kGareIntros.length)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 44),
                            child: Text(
                              kGareIntros[_announcedGare],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: 15,
                                fontStyle: FontStyle.italic,
                                height: 1.4,
                              ),
                            ),
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
  // ◀/▶ Gare = saute au segment d'une autre gare.
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
          _elanChip(),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  // Pastille ÉLAN : N petites flammes = étapes (gares) que le train peut encore
  // enchaîner avant la HALTE (où il faut retourner soigner Shen au wagon). En
  // debug : masquée (élan infini).
  Widget _elanChip() {
    if (GameState.instance.debugMode || !GameState.elanEnabled) {
      return const SizedBox.shrink();
    }
    final n = GameState.instance.cardElan;
    const max = GameState.cardElanMax;
    final low = n <= 1;
    final accent = low ? const Color(0xFFD98A8A) : const Color(0xFFE8B96B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: low ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, size: 12, color: accent.withValues(alpha: 0.9)),
          const SizedBox(width: 3),
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
          // surligne la jauge qui va changer pendant un drag (sauf carte à
          // ENJEU CACHÉ : on parie sans voir).
          int preview = 0;
          if (!_showingResult &&
              _state.card != null &&
              !_state.card!.hiddenStakes &&
              _drag.abs() > 30) {
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
        // aperçu du changement pendant le drag (+ alerte MORTEL si la jauge
        // tomberait à 0 — les pertes sont amplifiées ×1.7 par le moteur).
        SizedBox(
          height: 16,
          child: preview == 0
              ? null
              : Builder(builder: (_) {
                  final eff =
                      preview < 0 ? (preview * 1.7).round() : preview;
                  final fatal = value + eff <= 0;
                  return Text(
                    fatal
                        ? '☠ $preview'
                        : (preview > 0 ? '+$preview' : '$preview'),
                    style: TextStyle(
                      color: fatal
                          ? const Color(0xFFFF4D4D)
                          : (preview > 0
                              ? const Color(0xFF8BD18B)
                              : Colors.redAccent),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }),
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
            child: Transform.translate(
              offset: Offset(dx, dy),
              child: Transform.rotate(
                angle: rotation,
                child: Transform.scale(
                  scale: scale,
                  // Le choix s'affiche SUR la carte au penché (style Reigns).
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      _cardFace(card),
                      Positioned.fill(
                        child: _onCardChoice(card, leftActive, rightActive),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Le CHOIX révélé SUR la carte au penché (style Reigns) : le label du choix
  // côté penché apparaît en grand en haut de la carte, sur un voile sombre,
  // avec le preview des deltas (ou « ? ? ? » si enjeu caché).
  Widget _onCardChoice(StoryCard card, bool leftActive, bool rightActive) {
    final active = leftActive || rightActive;
    final choice = leftActive ? card.left : card.right;
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AnimatedOpacity(
          opacity: active ? 1 : 0,
          duration: const Duration(milliseconds: 110),
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.82),
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    choice.label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lora(
                      color: Colors.white,
                      fontSize: 21,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (card.hiddenStakes)
                    const Text('? ? ?',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 3))
                  else if (choice.effects.isNotEmpty)
                    _deltaChips(choice.effects),
                ],
              ),
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

  /// Visuel de carte (illustration MINIMALE) : portrait réutilisant les sprites
  /// existants (Shen/sœur/chien), sinon un emblème d'ambiance dessiné. Retourne
  /// null pour `CardArt.none` (carte texte classique).
  Widget? _cardArt(CardArt art) {
    String? sprite;
    switch (art) {
      case CardArt.shen:
        sprite = 'assets/characters/heroine_front.png';
      case CardArt.sister:
        sprite = 'assets/characters/sister_idle_1.png';
      case CardArt.dog:
        sprite = 'assets/objects/dog_bark_1.png';
      default:
        break;
    }
    if (sprite != null) {
      return SizedBox(
        height: 72,
        child: Image.asset(sprite,
            fit: BoxFit.contain, cacheWidth: 160, gaplessPlayback: true),
      ).animate().fadeIn(duration: 350.ms).scale(
          begin: const Offset(0.85, 0.85),
          end: const Offset(1, 1),
          curve: Curves.easeOutBack,
          duration: 380.ms);
    }
    final svg = _kEmblemSvg[art];
    final color = _emblemColor(art);
    if (svg == null || color == null) return null;
    return Container(
      width: 54,
      height: 54,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.4),
      ),
      child: SvgPicture.string(
        svg,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    ).animate().fadeIn(duration: 350.ms).scale(
        begin: const Offset(0.7, 0.7),
        end: const Offset(1, 1),
        curve: Curves.easeOutBack,
        duration: 420.ms);
  }

  Color? _emblemColor(CardArt art) {
    switch (art) {
      case CardArt.radio:
        return const Color(0xFF9BC4E2);
      case CardArt.pillards:
        return const Color(0xFFCF6B6B);
      case CardArt.refuge:
        return const Color(0xFFE8B96B);
      case CardArt.cold:
        return const Color(0xFF9BC4E2);
      case CardArt.fire:
        return const Color(0xFFE89B5C);
      case CardArt.water:
        return const Color(0xFF6FAEDF);
      case CardArt.food:
        return const Color(0xFFD9A05B);
      case CardArt.memory:
        return const Color(0xFFCBB68F);
      case CardArt.hope:
        return const Color(0xFFE8C98B);
      default:
        return null;
    }
  }

  // --- carte de REMPLISSAGE : parchemin clair, léger ---
  Widget _fillerFace(StoryCard card) {
    final w = MediaQuery.of(context).size.width;
    final cardW = min(w * 0.82, 430.0);
    return Container(
      width: cardW,
      constraints: BoxConstraints(
        minHeight: 230,
        maxHeight: MediaQuery.of(context).size.height * 0.66,
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_cardArt(card.art) case final a?) ...[
                  a,
                  const SizedBox(height: 12),
                ],
                Text(
                  card.text,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lora(
                    color: const Color(0xFF3A2A18),
                    fontSize: 16.5,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- carte de GARE : sombre, solennelle, liseré doré, bandeau titre ---
  Widget _gareFace(StoryCard card) {
    final w = MediaQuery.of(context).size.width;
    final cardW = min(w * 0.84, 450.0);
    const gold = Color(0xFFE8B96B);
    return Container(
      width: cardW,
      constraints: BoxConstraints(
        minHeight: 260,
        maxHeight: MediaQuery.of(context).size.height * 0.68,
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
                    style: GoogleFonts.cinzel(
                      color: gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_cardArt(card.art) case final a?) ...[
                        a,
                        const SizedBox(height: 12),
                      ],
                      Text(
                        card.text,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.lora(
                          color: const Color(0xFFF3E6CF),
                          fontSize: 17,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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
                      style: GoogleFonts.lora(
                        color: const Color(0xFFF0E6D2),
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
                // RÉACTION d'un personnage à ton choix : rend la décision « vue ».
                if (_resultReaction != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8B96B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border(
                        left: BorderSide(
                            color: const Color(0xFFE8B96B)
                                .withValues(alpha: 0.7),
                            width: 3),
                      ),
                    ),
                    child: Text(
                      _resultReaction!,
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                        color: Color(0xFFE8C98B),
                        fontSize: 14,
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
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

  // --- écran de HALTE : Shen est à bout d'élan, le train s'arrête à la gare.
  // On invite à retourner s'occuper d'elle au wagon (dormir = repos complet,
  // ou la réchauffer / jouer) avant de repartir. C'est le va-et-vient
  // cartes <-> Tamagotchi qui donne le rythme (remplace l'ancien combat).
  Widget _buildHalt() {
    final gare = _state.card?.speaker ?? 'le prochain arrêt';
    const gold = Color(0xFFE8B96B);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: gold, width: 2),
                boxShadow: [
                  BoxShadow(
                      color: gold.withValues(alpha: 0.35),
                      blurRadius: 26,
                      spreadRadius: 2),
                ],
              ),
              child: const Icon(Icons.local_cafe_outlined,
                  color: gold, size: 38),
            ),
            const SizedBox(height: 22),
            Text(
              'Halte à $gare',
              textAlign: TextAlign.center,
              style: GoogleFonts.cinzel(
                color: gold,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Le train s'arrête. Shen est à bout de forces — le voyage l'a vidée. "
              "Retourne t'occuper d'elle dans le wagon : la faire dormir la "
              "remettra d'aplomb, la réchauffer ou jouer un peu l'aideront aussi. "
              "Vous repartirez quand elle sera prête.",
              textAlign: TextAlign.center,
              style: GoogleFonts.lora(
                  color: Colors.white70, fontSize: 15, height: 1.55),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: const Color(0xFF2A2018),
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 14),
              ),
              onPressed: widget.onClose,
              icon: const Icon(Icons.weekend_outlined),
              label: const Text('Retourner au wagon'),
            ),
          ],
        ),
      ),
    );
  }

  // --- écran de fin ---
  Widget _buildEnding() {
    final id = _state.endingId ?? 'ensemble';
    final e = endingText(id);
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
