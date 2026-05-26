import '../models/game_state.dart';

/// A single multiple-choice option attached to a Question.
class Choice {
  const Choice({
    required this.label,
    required this.outcomeText,
    this.energyDelta = 0,
    this.grantItems = const {},
    this.setFlags = const [],
    this.unlocksLocation,
  });

  /// What the player sees on the button.
  final String label;

  /// What the player sees after picking — the consequence text.
  final String outcomeText;

  /// Negative = costs extra energy, positive = restores.
  final int energyDelta;

  /// Items added to the player's inventory (id → qty).
  final Map<String, int> grantItems;

  /// Story flags raised when this option is picked.
  final List<String> setFlags;

  /// Optional location id that this choice unlocks on the map.
  final String? unlocksLocation;

  /// Apply this choice's outcome to the singleton game state.
  void apply() {
    final state = GameState.instance;
    if (energyDelta != 0) {
      if (energyDelta > 0) {
        state.grantEnergy(energyDelta);
      } else {
        state.spendEnergy(-energyDelta);
      }
    }
    grantItems.forEach(state.grantItem);
    for (final f in setFlags) {
      state.setFlag(f);
    }
    final unlock = unlocksLocation;
    if (unlock != null) state.unlockLocation(unlock);
  }
}

class Question {
  const Question({
    required this.text,
    required this.choices,
    this.requiresFlag,
  });

  final String text;
  final List<Choice> choices;

  /// If set, this question only fires when the player has the named flag.
  final String? requiresFlag;
}

class Location {
  const Location({
    required this.id,
    required this.name,
    required this.mapX,
    required this.mapY,
    required this.backgrounds,
    required this.questions,
  });

  /// Stable id, also the key used in unlock sets / flag names.
  final String id;

  /// Display name on the map + event header.
  final String name;

  /// Normalised position on the map screen.
  final double mapX;
  final double mapY;

  /// Background images that cross-fade in the event screen. Either real
  /// asset paths under assets/locations/ or — for now — null entries
  /// that fall back to procedural placeholder gradients.
  final List<String?> backgrounds;

  /// All possible questions in this location. The event screen picks
  /// one at random among those whose [Question.requiresFlag] matches
  /// the current state.
  final List<Question> questions;
}

/// All locations available in the world. Initial unlock = station_abandonnee.
const List<Location> world = [
  Location(
    id: 'station_abandonnee',
    name: 'Station abandonnée',
    mapX: 0.32,
    mapY: 0.55,
    backgrounds: [null, null, null], // procedural placeholders for now
    questions: [
      Question(
        text:
            'Tu pousses la porte rouillée du guichet. Sur le comptoir, '
            'un sac à dos éventré. Tu entends un grattement derrière une '
            'porte fermée.',
        choices: [
          Choice(
            label: 'Fouiller le sac à dos.',
            outcomeText:
                'Tu trouves trois bûches sèches et une vieille boîte '
                'de conserve. Tu fourres tout dans tes poches.',
            grantItems: {'wood': 3, 'canned_food': 1},
          ),
          Choice(
            label: 'Ouvrir la porte qui gratte.',
            outcomeText:
                'Un chien maigre, terrifié. Il file entre tes jambes '
                'sans demander son reste. Tu remarques au sol un trousseau '
                'de clés. Une mène quelque part de précis.',
            setFlags: ['found_keys'],
            unlocksLocation: 'depot_ferroviaire',
          ),
          Choice(
            label: 'Partir, ce n\'est pas prudent.',
            outcomeText:
                'Tu rebrousses chemin. Le grattement s\'arrête net '
                'derrière toi. Tu accélères le pas.',
            energyDelta: 1,
          ),
        ],
      ),
      Question(
        text:
            'Tu retournes dans la station. Le sac est toujours là. '
            'Une affiche annonce un train pour 14h12 — il y a longtemps.',
        choices: [
          Choice(
            label: 'Décrocher l\'affiche.',
            outcomeText:
                'Le papier s\'effrite. Derrière, une note griffonnée : '
                '"Le dépôt — wagon vert. Bois pour 2 ans."',
            setFlags: ['heard_about_wood'],
          ),
          Choice(
            label: 'Inspecter les bancs.',
            outcomeText: 'Une bûche oubliée sous un banc. Pratique.',
            grantItems: {'wood': 1},
          ),
          Choice(
            label: 'Se reposer un moment.',
            outcomeText:
                'Tu t\'assois. Le silence te détend. Tu reprends des '
                'forces avant de continuer.',
            energyDelta: 2,
          ),
        ],
      ),
    ],
  ),
  Location(
    id: 'depot_ferroviaire',
    name: 'Dépôt ferroviaire',
    mapX: 0.62,
    mapY: 0.38,
    backgrounds: [null, null, null],
    questions: [
      Question(
        text:
            'Le dépôt est immense, envahi de lierre. Tu repères trois '
            'pistes : un wagon vert au fond, un atelier ouvert, et un '
            'escalier qui monte dans une tour de contrôle.',
        choices: [
          Choice(
            label: 'Le wagon vert.',
            outcomeText:
                'Plein à craquer de bûches sèches. Tu en charges '
                'autant que tu peux porter.',
            grantItems: {'wood': 6},
          ),
          Choice(
            label: 'L\'atelier.',
            outcomeText:
                'Outils, huile, un vieux carnet de mécanicien. Utile '
                'pour bricoler le poêle.',
            grantItems: {'tools': 1, 'manual': 1},
          ),
          Choice(
            label: 'La tour de contrôle.',
            outcomeText:
                'En haut, une carte. Une nouvelle destination s\'éclaire '
                'dans ta tête.',
            unlocksLocation: 'village_fantome',
            energyDelta: -1,
          ),
        ],
      ),
    ],
  ),
  Location(
    id: 'village_fantome',
    name: 'Village fantôme',
    mapX: 0.78,
    mapY: 0.62,
    backgrounds: [null, null, null],
    questions: [
      Question(
        text:
            'Une dizaine de maisons en pierre, toutes ouvertes, toutes '
            'vides. Une fumée monte d\'une seule cheminée, au bout de la '
            'rue.',
        choices: [
          Choice(
            label: 'Frapper à la porte.',
            outcomeText:
                'Une vieille femme. Elle te tend une miche de pain '
                'tiède sans dire un mot. Tu la remercies de la tête.',
            grantItems: {'bread': 1},
            setFlags: ['met_old_woman'],
          ),
          Choice(
            label: 'Faire le tour, voir les maisons vides.',
            outcomeText:
                'Tu trouves des graines de tomate, un livre intact, et '
                'une couverture épaisse.',
            grantItems: {'seeds': 1, 'book': 1, 'blanket': 1},
          ),
          Choice(
            label: 'Repartir tout de suite, ça te met mal à l\'aise.',
            outcomeText: 'Tu retournes au train, sans regret.',
          ),
        ],
      ),
    ],
  ),
  Location(
    id: 'camp_refuge',
    name: 'Camp-refuge',
    mapX: 0.45,
    mapY: 0.35,
    backgrounds: [null, null],
    questions: [
      Question(
        text:
            'Un campement sous un viaduc. Des tentes rapiécées, un feu '
            'presque éteint. Quelqu\'un a laissé une note sur un bidon.',
        choices: [
          Choice(
            label: 'Lire la note.',
            outcomeText:
                '"Si tu lis ça, prends le bois, laisse de la nourriture. '
                'On revient demain." Tu prends le bois.',
            grantItems: {'wood': 4},
            setFlags: ['read_camp_note'],
          ),
          Choice(
            label: 'Fouiller les tentes.',
            outcomeText:
                'Un sac de couchage en bon état et une gourde pleine.',
            grantItems: {'sleeping_bag': 1, 'water': 1},
          ),
          Choice(
            label: 'Laisser de la nourriture et repartir.',
            outcomeText:
                'Tu laisses une boîte de conserve près du feu.',
            energyDelta: 1,
            setFlags: ['generous_camp'],
          ),
        ],
      ),
    ],
  ),
  Location(
    id: 'pont_suspendu',
    name: 'Pont suspendu',
    mapX: 0.60,
    mapY: 0.75,
    backgrounds: [null, null],
    questions: [
      Question(
        text:
            'Un pont métallique au-dessus d\'un ravin. Le vent siffle '
            'entre les câbles. Au milieu, une caisse coincée dans les '
            'garde-fous.',
        choices: [
          Choice(
            label: 'Traverser jusqu\'à la caisse.',
            outcomeText:
                'Le pont tangue, mais tu atteins la caisse. Dedans : '
                'des outils rouillés mais utilisables.',
            grantItems: {'tools': 2},
            energyDelta: -1,
          ),
          Choice(
            label: 'Couper un câble pour récupérer la caisse.',
            outcomeText:
                'Le câble cède, la caisse glisse vers toi. Tu '
                'récupères du fil de fer et une lampe frontale.',
            grantItems: {'wire': 3, 'headlamp': 1},
            setFlags: ['cut_bridge_cable'],
          ),
          Choice(
            label: 'Faire demi-tour, c\'est trop risqué.',
            outcomeText:
                'Le pont grince derrière toi. Sage décision.',
          ),
        ],
      ),
    ],
  ),
];

/// Lookup helper.
Location? locationById(String id) {
  for (final l in world) {
    if (l.id == id) return l;
  }
  return null;
}

/// Pick the next playable question for a location based on current
/// story flags. Cycles in order; falls back to the first one if none
/// gate-match.
Question pickQuestion(Location loc) {
  final state = GameState.instance;
  for (final q in loc.questions) {
    final gate = q.requiresFlag;
    if (gate == null || state.hasFlag(gate)) {
      return q;
    }
  }
  return loc.questions.first;
}
