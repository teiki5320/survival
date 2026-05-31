// Moteur de cartes "Reigns-like" pour Train Cosy.
//
// Principe : le voyage est une séquence de 14 GARES (étapes narratives
// obligatoires, jamais aléatoires). Entre deux gares, on pioche ~N cartes
// de REMPLISSAGE dans un paquet propre au segment (ambiance / tactique /
// lore), variées à chaque run. Les actions de survie (bois, eau, manger)
// se font à la main dans le wagon : les cartes ici sont NARRATIVES.
//
// Les 4 stats (soif/faim/bois/moral) vivent dans GameState ; ce moteur ne
// fait que produire la prochaine carte à montrer et appliquer les effets
// d'un choix. Les flags narratifs (aLeChien, leVieuxABord, ...) sont
// stockés ici, indépendants de la sauvegarde survie.

import 'dart:math';

/// Les 4 jauges du mode cartes.
enum Stat { soif, faim, bois, moral }

/// Type de carte, pour piloter le tirage.
enum CardKind {
  gare, // pilier narratif, jamais aléatoire
  fillerRepeatable, // ambiance, peut revenir dans une même run
  fillerOneshot, // lore/émotion fort, vue une seule fois par run
}

/// Un choix (swipe gauche ou droite).
class CardChoice {
  const CardChoice({
    required this.label,
    this.effects = const {},
    this.setFlags = const [],
    this.resultText,
  });

  /// Texte du bouton / de l'indice de swipe.
  final String label;

  /// Deltas appliqués aux stats (peut être négatif).
  final Map<Stat, int> effects;

  /// Flags narratifs posés par ce choix.
  final List<String> setFlags;

  /// Courte conséquence affichée après le swipe (style Reigns).
  final String? resultText;
}

/// Une carte : un texte + deux choix. Pour les gares à variantes, [text],
/// [left] et [right] peuvent être calculés depuis les flags via [resolve].
class StoryCard {
  const StoryCard({
    required this.id,
    required this.kind,
    required this.text,
    required this.left,
    required this.right,
    this.speaker,
    this.requires,
  });

  final String id;
  final CardKind kind;
  final String text;
  final String? speaker;
  final CardChoice left;
  final CardChoice right;

  /// Condition d'apparition (pour les fillers conditionnels). Null = toujours.
  final bool Function(Set<String> flags)? requires;
}

/// Un segment = les cartes de gare(s) + le paquet de remplissage entre la
/// gare courante et la suivante.
class Segment {
  const Segment({
    required this.gareCards,
    required this.fillerPool,
    this.drawCount = 4,
  });

  /// Cartes de gare jouées dans l'ordre (souvent 1, parfois 2-3 beats).
  /// Peut être une fonction des flags pour les gares à variantes.
  final List<StoryCard> Function(Set<String> flags) gareCards;

  /// Paquet de cartes de remplissage de ce segment.
  final List<StoryCard> fillerPool;

  /// Combien de cartes de remplissage piocher dans ce segment.
  final int drawCount;
}

/// État courant produit par le moteur.
class EngineState {
  EngineState({
    required this.card,
    required this.gareIndex,
    required this.isGare,
    required this.finished,
    this.endingId,
  });

  final StoryCard? card;
  final int gareIndex; // 0-based, quelle gare on aborde
  final bool isGare;
  final bool finished;
  final String? endingId;
}

/// Le moteur. On lui passe le scénario (liste de segments + résolveur de
/// fin) et il déroule : gare → fillers → gare → ... → fin.
class ReignsEngine {
  ReignsEngine({
    required this.segments,
    required this.resolveEnding,
    int seed = 0,
  }) : _rng = Random(seed == 0 ? DateTime.now().millisecondsSinceEpoch : seed);

  final List<Segment> segments;

  /// Calcule l'id de fin à partir des stats + flags.
  final String Function(Map<Stat, int> stats, Set<String> flags) resolveEnding;

  final Random _rng;

  // --- état runtime ---
  final Set<String> flags = {};
  final Map<Stat, int> stats = {
    Stat.soif: 70,
    Stat.faim: 70,
    Stat.bois: 70,
    Stat.moral: 70,
  };

  int _gareIndex = 0;
  // File des cartes à montrer dans le segment courant : d'abord les beats
  // de la gare, puis les fillers piochés.
  final List<StoryCard> _queue = [];
  // Ids de fillers oneshot déjà vus, pour ne pas les répéter dans la run.
  final Set<String> _seenOneshot = {};
  bool _started = false;

  int get gareIndex => _gareIndex;

  /// Démarre / renvoie la première carte.
  EngineState start() {
    _started = true;
    flags.clear();
    _seenOneshot.clear();
    stats[Stat.soif] = 70;
    stats[Stat.faim] = 70;
    stats[Stat.bois] = 70;
    stats[Stat.moral] = 70;
    _gareIndex = 0;
    _queue.clear();
    _loadSegment();
    return _emit();
  }

  void _loadSegment() {
    final seg = segments[_gareIndex];
    _queue
      ..clear()
      ..addAll(seg.gareCards(flags));
    _queue.addAll(_drawFillers(seg));
  }

  /// Pioche [seg.drawCount] cartes du paquet, sans répéter les oneshot déjà
  /// vues, en mélangeant pour la variété entre runs.
  List<StoryCard> _drawFillers(Segment seg) {
    final pool = seg.fillerPool
        .where((c) => c.requires == null || c.requires!(flags))
        .where((c) =>
            c.kind != CardKind.fillerOneshot || !_seenOneshot.contains(c.id))
        .toList()
      ..shuffle(_rng);
    final picked = pool.take(seg.drawCount).toList();
    for (final c in picked) {
      if (c.kind == CardKind.fillerOneshot) _seenOneshot.add(c.id);
    }
    return picked;
  }

  /// Applique un choix et renvoie l'état suivant (carte suivante ou fin).
  EngineState choose(CardChoice choice) {
    if (!_started) return start();
    // effets
    choice.effects.forEach((stat, delta) {
      stats[stat] = (stats[stat]! + delta).clamp(0, 100);
    });
    flags.addAll(choice.setFlags);

    // mort immédiate si une jauge touche 0
    final dead = stats.entries.firstWhere(
      (e) => e.value <= 0,
      orElse: () => const MapEntry(Stat.moral, 1),
    );
    if (stats[dead.key]! <= 0) {
      return EngineState(
        card: null,
        gareIndex: _gareIndex,
        isGare: false,
        finished: true,
        endingId: dead.key == Stat.moral ? 'abandon' : 'mort',
      );
    }

    if (_queue.isNotEmpty) _queue.removeAt(0);

    // segment courant terminé → gare suivante (ou fin)
    if (_queue.isEmpty) {
      _gareIndex++;
      if (_gareIndex >= segments.length) {
        return EngineState(
          card: null,
          gareIndex: _gareIndex,
          isGare: false,
          finished: true,
          endingId: resolveEnding(stats, flags),
        );
      }
      _loadSegment();
    }
    return _emit();
  }

  EngineState _emit() {
    final card = _queue.isEmpty ? null : _queue.first;
    return EngineState(
      card: card,
      gareIndex: _gareIndex,
      isGare: card?.kind == CardKind.gare,
      finished: false,
    );
  }
}
