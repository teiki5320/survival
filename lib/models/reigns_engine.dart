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
// d'un choix. Les flags narratifs (aLeChien, aLaSoeur, ...) sont
// stockés ici, indépendants de la sauvegarde survie.


import 'dart:math';

import '../constants.dart';
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
  });

  final List<Segment> segments;

  /// Calcule l'id de fin à partir des stats + flags.
  final String Function(Map<Stat, int> stats, Set<String> flags) resolveEnding;

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

  // Tirage aléatoire des cartes d'ambiance (variété d'un run à l'autre).
  final Random _rng = Random();

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

  // Nb de cartes du segment courant (pour calculer la progression du train).
  int _segmentTotal = 1;

  void _loadSegment() {
    final idx = _gs.cardGareIndex ?? 0;
    final seg = segments[idx];
    // Réapprovisionnement en bois à certaines gares. Garde anti-double via un
    // flag de run, pour ne pas re-créditer si on recharge une sauvegarde.
    // Bois fusionné : chaque gare a un tas de bûches à ramasser à la loco
    // (base 4 + bonus aux gares de ravitaillement). Set une seule fois par gare.
    if (flags.add('woodpile_$idx')) {
      _gs.setGareWoodLeft(4 + (kWoodSupplyByGare[idx] ?? 0));
      // RAVITAILLEMENT D'ARRIVÉE à la gare (on fouille/troque) : calibré par
      // simu (careless ~11% / casual ~62% / smart 100%). La corvée de bûches à
      // la loco reste un bonus optionnel par-dessus.
      _gs.grantGareSupply();
    }
    _queue
      ..clear()
      ..addAll(seg.gareCards(flags));
    _queue.addAll(_drawFillers(seg));
    _segmentTotal = _queue.isEmpty ? 1 : _queue.length;
    _gs.cardSegmentProgress = 0.0;
    _skipDeadHead();
  }

  /// Cartes de remplissage du segment. Deux familles :
  ///  - ÉPINGLÉES (progression) : toute carte qui a un `requires` OU qui pose un
  ///    flag narratif (chaîne radio, beats sœur/chien, payoffs, `aLaRadio`...).
  ///    Elles sont TOUJOURS jouées si éligibles — jamais droppées au hasard,
  ///    sinon l'arc se casserait d'un run à l'autre.
  ///  - AMBIANCE (stats only, pas de flag, pas de `requires`) : on en tire un
  ///    sous-ensemble ALÉATOIRE (`drawCount`) -> variété d'un run à l'autre.
  /// La condition `requires` est (re)évaluée À L'ÉMISSION (via [_skipDeadHead]),
  /// pas ici : une carte conditionnée par un flag posé par la carte de gare du
  /// même segment (ex. `aLaSoeur` en gare 5) reste jouable.
  List<StoryCard> _drawFillers(Segment seg) {
    final pool = seg.fillerPool
        .where((c) =>
            c.kind != CardKind.fillerOneshot ||
            !_gs.cardSeenOneshot.contains(c.id))
        .toList();
    // Flags POTENTIELS = flags actuels + tout flag que les cartes de gare de CE
    // segment peuvent poser (aLaSoeur/capParents se posent à la carte de gare,
    // donc pas encore dans `flags` au chargement). Une carte conditionnée par un
    // flag inatteignable (ex. `aLaRadio` jamais trouvée) ne doit PAS réserver de
    // slot pour finir droppée à l'émission (segment amputé). Une carte
    // conditionnée par un flag que la gare va poser reste, elle, éligible.
    final potential = {...flags};
    for (final gc in seg.gareCards(flags)) {
      potential
        ..addAll(gc.left.setFlags)
        ..addAll(gc.right.setFlags);
    }
    bool eligible(StoryCard c) => c.requires == null || c.requires!(potential);
    bool setsFlag(StoryCard c) =>
        c.left.setFlags.isNotEmpty || c.right.setFlags.isNotEmpty;
    // ÉPINGLÉE (progression) ET éligible : toujours jouée.
    bool pinned(StoryCard c) => (c.requires != null || setsFlag(c)) && eligible(c);
    final out = pool.where(pinned).toList();
    // Les pinned comptent DANS le budget drawCount (on ne gonfle pas le nombre
    // de cartes par segment -> difficulté préservée). L'ambiance ÉLIGIBLE
    // complète ce qu'il reste de place.
    final slots = seg.drawCount - out.length;
    if (slots > 0) {
      final ambiance = pool
          .where((c) => !pinned(c) && eligible(c))
          .toList()
        ..shuffle(_rng);
      out.addAll(ambiance.take(slots));
    }
    out.shuffle(_rng); // ordre varié (aucune dépendance intra-segment)
    return out;
  }

  /// Saute en tête de file les cartes dont la condition `requires` n'est PAS
  /// remplie au moment présent (flags courants). Marque les oneshots comme vus
  /// quand ils deviennent réellement la carte affichée. Garantit que la carte
  /// en tête de `_queue` est toujours jouable.
  void _skipDeadHead() {
    while (_queue.isNotEmpty) {
      final c = _queue.first;
      if (c.requires != null && !c.requires!(flags)) {
        _queue.removeAt(0); // condition pas remplie -> carte abandonnée
        continue;
      }
      if (c.kind == CardKind.fillerOneshot) _gs.cardSeenOneshot.add(c.id);
      break;
    }
  }

  /// Applique un choix et renvoie l'état suivant (carte suivante ou fin).
  EngineState choose(CardChoice choice) {
    // effets → GameState (clamp + persistance). Les GAINS de moral sont
    // atténués (×0.6) pour éviter que la jauge sature et devienne inutile ;
    // les pertes de moral, elles, comptent plein.
    // Les PERTES sont amplifiées (×1.7) pour créer une vraie tension de
    // survie. Calé par simulation (tools/sim_current.py) : à ×1.7 + budget 2,
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
    // ZONE FROIDE (gare 8+) : le grand nord glacé fait boire la loco — bois
    // qui fond à chaque carte. C'est le lien MÉCANIQUE carte↔monde : avancer
    // sur la carte change la difficulté, pas juste le décor. (canon : "le
    // froid menace, la loco boit plus").
    if (_gs.inDeepCold) {
      _gs.applyCardDeltas({'bois': -kColdBoisDrainPerCard});
    }
    // Compte les vrais gestes de protection (pour la fin "famille").
    if (choice.setFlags.contains('soeurProtegee')) _gs.cardSoin++;
    // Déblocage d'objet -> file un toast (avant addAll, pour ne compter que
    // les NOUVEAUX flags asset_*).
    for (final f in choice.setFlags) {
      if (f.startsWith('asset_') &&
          !flags.contains(f) &&
          GameState.unlockNames.containsKey(f)) {
        _gs.pendingUnlocks.add(GameState.unlockNames[f]!);
      }
    }
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
    _skipDeadHead(); // saute les fillers dont la condition n'est plus remplie

    // Avance le train sur la carte : fraction du segment déjà parcourue.
    _gs.cardSegmentProgress =
        ((_segmentTotal - _queue.length) / _segmentTotal).clamp(0.0, 1.0);

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
      // La météo se met au diapason de la (nouvelle) zone : entrer dans
      // le nord fait tomber la neige immédiatement.
      _gs.refreshWeatherForZone();
      _gs.save();
      _loadSegment();
    }
    return _emit();
  }

  /// État courant (re-émission de la carte en tête de file), sans rien
  /// consommer. Sert à rafraîchir l'UI sans avancer.
  EngineState get current => _emit();

  // --- Outils DEBUG (navigation libre dans les cartes, mode debug uniquement).

  /// DEBUG : passe la carte courante SANS appliquer d'effet (parcourir
  /// librement le contenu). Enchaîne sur la gare suivante si le segment est
  /// fini ; reboucle à la 1re gare après la dernière.
  EngineState debugSkipCard() {
    if (_queue.isNotEmpty) _queue.removeAt(0);
    _skipDeadHead();
    _gs.cardSegmentProgress =
        ((_segmentTotal - _queue.length) / _segmentTotal).clamp(0.0, 1.0);
    if (_queue.isEmpty) {
      final next = (_gs.cardGareIndex ?? 0) + 1;
      _gs.cardGareIndex = next >= segments.length ? 0 : next;
      _gs.refreshWeatherForZone();
      _gs.save();
      _loadSegment();
    }
    return _emit();
  }

  /// DEBUG : recharge directement le segment d'une gare donnée (wrap autour
  /// des 14). Sert à tester n'importe quelle gare sans tout rejouer.
  EngineState debugGoToGare(int idx) {
    final n = segments.length;
    _gs.cardGareIndex = ((idx % n) + n) % n;
    _gs.refreshWeatherForZone();
    _gs.save();
    _queue.clear();
    _loadSegment();
    return _emit();
  }

  EngineState _emit() {
    final card = _queue.isEmpty ? null : _queue.first;
    return EngineState(
      card: card,
      gareIndex: gareIndex,
      isGare: card?.kind == CardKind.gare,
      finished: false,
    );
  }
}
