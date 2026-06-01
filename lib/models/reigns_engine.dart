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

import 'game_state.dart';

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

  // GameState est la SOURCE DE VÉRITÉ : jauges (cardSoif…), flags de run
  // (cardFlags), oneshot vues (cardSeenOneshot), segment courant
  // (cardGareIndex). Le moteur lit/écrit dedans, ne duplique rien.
  GameState get _gs => GameState.instance;

  /// Vue lecture des 4 jauges (pour l'UI), tirée de GameState.
  Map<Stat, int> get stats => {
        Stat.soif: _gs.cardSoif,
        Stat.faim: _gs.cardFaim,
        Stat.bois: _gs.cardBois,
        Stat.moral: _gs.cardMoral,
      };

  Set<String> get flags => _gs.cardFlags;

  // File des cartes du segment courant : beats de gare puis fillers piochés.
  final List<StoryCard> _queue = [];

  int get gareIndex => _gs.cardGareIndex ?? 0;

  static const Map<Stat, String> _statKey = {
    Stat.soif: 'soif',
    Stat.faim: 'faim',
    Stat.bois: 'bois',
    Stat.moral: 'moral',
  };

  /// Nouvelle run depuis zéro.
  EngineState start() {
    _gs.startCardRun();
    _queue.clear();
    _loadSegment();
    return _emit();
  }

  /// Reprend une run sauvegardée si elle existe, sinon en démarre une neuve.
  /// On reprend au début du segment courant (granularité gare).
  EngineState startOrResume() {
    if (!_gs.hasCardRun) return start();
    _queue.clear();
    _loadSegment();
    return _emit();
  }

  void _loadSegment() {
    final idx = _gs.cardGareIndex ?? 0;
    final seg = segments[idx];
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
            c.kind != CardKind.fillerOneshot ||
            !_gs.cardSeenOneshot.contains(c.id))
        .toList()
      ..shuffle(_rng);
    final picked = pool.take(seg.drawCount).toList();
    for (final c in picked) {
      if (c.kind == CardKind.fillerOneshot) _gs.cardSeenOneshot.add(c.id);
    }
    return picked;
  }

  /// Applique un choix et renvoie l'état suivant (carte suivante ou fin).
  EngineState choose(CardChoice choice) {
    // effets → GameState (clamp + persistance). Les GAINS de moral sont
    // atténués (×0.6) pour éviter que la jauge sature et devienne inutile ;
    // les pertes de moral, elles, comptent plein.
    // Les PERTES sont amplifiées (×1.7) pour créer une vraie tension de
    // survie. Calé par simulation (tools/sim_game.py) : à ×1.7 + budget 2,
    // une joueuse négligente meurt ~42% du temps, une attentive survit
    // ~95%, une experte ~100%. En-dessous (×1.5) le drain est trop mou et
    // tout le monde survit passivement. Les GAINS de moral restent atténués
    // (×0.6) pour éviter que la jauge sature et devienne inutile.
    if (choice.effects.isNotEmpty) {
      _gs.applyCardDeltas({
        for (final e in choice.effects.entries)
          _statKey[e.key]!: e.value < 0
              ? (e.value * 1.7).round()
              : (e.key == Stat.moral ? (e.value * 0.6).round() : e.value),
      });
    }
    // MÉCANIQUE SŒUR (fondu dans le moral) : tant qu'elle est à bord, elle
    // est une 2e bouche (faim/soif -1 par carte) mais sa présence soutient
    // un peu le moral (+1). Appliqué à chaque carte après la gare 5.
    if (flags.contains('aLaSoeur')) {
      _gs.applyCardDeltas({'faim': -1, 'soif': -1, 'moral': 1});
    }
    // Compte les vrais gestes de protection (pour la fin "famille").
    if (choice.setFlags.contains('soeurProtegee')) _gs.cardSoin++;
    flags.addAll(choice.setFlags);

    // mort immédiate si une jauge touche 0
    final dead = stats.entries.firstWhere(
      (e) => e.value <= 0,
      orElse: () => const MapEntry(Stat.moral, 1),
    );
    if (stats[dead.key]! <= 0) {
      _gs.endCardRun();
      return EngineState(
        card: null,
        gareIndex: gareIndex,
        isGare: false,
        finished: true,
        endingId: dead.key == Stat.moral ? 'abandon' : 'mort',
      );
    }

    if (_queue.isNotEmpty) _queue.removeAt(0);

    // segment courant terminé → gare suivante (ou fin)
    if (_queue.isEmpty) {
      final next = (_gs.cardGareIndex ?? 0) + 1;
      if (next >= segments.length) {
        final endId = resolveEnding(stats, flags);
        _gs.endCardRun();
        return EngineState(
          card: null,
          gareIndex: next,
          isGare: false,
          finished: true,
          endingId: endId,
        );
      }
      _gs.cardGareIndex = next;
      // Nouvelle gare = le wagon se recharge : budget de ravitaillement plein.
      _gs.resetRavitaillement();
      _gs.save();
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
