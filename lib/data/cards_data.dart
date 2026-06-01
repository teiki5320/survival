// Contenu narratif du mode cartes (porté depuis docs/train_cosy_*.twee).
//
// Source de vérité narrative = les fichiers Twine dans docs/. Ici c'est la
// version "jouable" : 14 gares (avec variantes selon flags) + un paquet de
// remplissage par segment, taggé repeatable / oneshot pour le tirage.
//
// Flags utilisés : aLeChien, leVieuxABord, aAideFuyard, aLaRadio, aLEnfant
// + compteur radioSuivie via flag "radio1/2/3" (on cumule).

import '../models/reigns_engine.dart';

// Raccourcis pour alléger l'écriture.
CardChoice _c(
  String label, {
  Map<Stat, int> fx = const {},
  List<String> flags = const [],
  String? result,
}) =>
    CardChoice(label: label, effects: fx, setFlags: flags, resultText: result);

StoryCard _filler(
  String id,
  String text,
  CardChoice left,
  CardChoice right, {
  bool oneshot = false,
  bool Function(Set<String>)? requires,
}) =>
    StoryCard(
      id: id,
      kind: oneshot ? CardKind.fillerOneshot : CardKind.fillerRepeatable,
      text: text,
      left: left,
      right: right,
      requires: requires,
    );

// ============================================================
// LES 14 GARES (piliers narratifs)
// ============================================================

List<StoryCard> _gare1(Set<String> f) => [
      StoryCard(
        id: 'G1',
        kind: CardKind.gare,
        speaker: 'Gare natale',
        text:
            "Le quai brûle derrière toi. Sous un banc renversé, un chiot tremble, seul comme toi.",
        left: _c("Le recueillir",
            fx: {Stat.moral: 15}, flags: ['aLeChien'], result: "Il se blottit contre toi. Le wagon paraît moins vide."),
        right: _c("Continuer seule",
            fx: {Stat.moral: -5}, result: "Tu fermes la porte. Le silence est immense."),
      ),
      StoryCard(
        id: 'G1b',
        kind: CardKind.gare,
        speaker: 'Gare natale',
        text:
            "La ville flambe au loin. Tes parents, ta petite sœur... ils sont peut-être encore là-bas.",
        left: _c("Y retourner",
            fx: {Stat.soif: -10, Stat.faim: -10},
            result: "Les rues sont un piège de feu. Tu remontes les mains vides — mais tu as vu un train filer vers le nord, bondé."),
        right: _c("Laisser le train fuir",
            fx: {Stat.moral: -10}, result: "Tu détournes les yeux. La culpabilité s'installe."),
      ),
    ];

List<StoryCard> _gare2(Set<String> f) => [
      StoryCard(
        id: 'G2',
        kind: CardKind.gare,
        speaker: 'Le Vieux',
        text:
            "Un vieux cheminot émerge d'une guérite, lampe à la main. « Tu sais où tu vas, au moins ? »",
        left: _c("Le laisser monter",
            fx: {Stat.moral: 8}, flags: ['leVieuxABord'],
            result: "Il tapote la chaudière. « Je connais cette voie jusqu'au froid. »"),
        right: _c("Te méfier, refuser",
            fx: {Stat.moral: -4},
            result: "« Le nord boit du bois. Prévois large. » Puis il s'efface."),
      ),
    ];

List<StoryCard> _gare3(Set<String> f) => [
      StoryCard(
        id: 'G3',
        kind: CardKind.gare,
        speaker: 'Halte 47',
        text:
            "Une silhouette sort du brouillard, mains levées. « Pitié... laissez-moi monter. » Derrière, d'autres ombres approchent.",
        left: _c("Le laisser monter",
            fx: {Stat.faim: -10, Stat.soif: -8, Stat.moral: 12},
            flags: ['aAideFuyard'],
            result: "Il s'effondre de gratitude. Il dit s'appeler Tomas."),
        right: _c("Verrouiller la porte",
            fx: {Stat.moral: -15},
            result: "Ses coups s'éloignent, puis des cris, puis plus rien."),
      ),
    ];

List<StoryCard> _gare4(Set<String> f) => [
      StoryCard(
        id: 'G4',
        kind: CardKind.gare,
        speaker: 'Village fantôme',
        text:
            "Dans une maison éventrée, sous la poussière : une radio à manivelle, intacte.",
        left: _c("La prendre",
            flags: ['aLaRadio', 'radio1'],
            result: "Une voix de femme, hachée : « ...vers le nord... si vous m'entendez... »"),
        right: _c("Laisser, filer vite",
            fx: {Stat.moral: -6},
            result: "Cette nuit-là, tu rêves d'une voix que tu n'as pas entendue."),
      ),
    ];

List<StoryCard> _gare5(Set<String> f) => [
      StoryCard(
        id: 'G5',
        kind: CardKind.gare,
        speaker: 'Pont sur le fleuve',
        text:
            "Le train s'arrête sur un long pont de fer. En bas, un fleuve gris. Faire de l'eau et pêcher — mais rester à découvert.",
        left: _c("Descendre, prendre le risque",
            fx: {Stat.soif: 18, Stat.faim: 12, Stat.moral: -4},
            result: "Jarres remplies, deux poissons. Mais chaque minute à nu te noue le ventre."),
        right: _c("Traverser sans t'arrêter",
            fx: {Stat.bois: -8, Stat.moral: 5},
            result: "Le pont gronde et te recrache sur la terre ferme."),
      ),
    ];

List<StoryCard> _gare6(Set<String> f) {
  if (f.contains('leVieuxABord')) {
    return [
      StoryCard(
        id: 'G6v',
        kind: CardKind.gare,
        speaker: 'Camp-refuge',
        text:
            "Des feux, des survivants. La rumeur du nord se confirme. Le Vieux contemple le camp. « Je pourrais finir mes jours ici, petite. »",
        left: _c("Le supplier de continuer",
            fx: {Stat.moral: 8},
            result: "Il soupire, sourit. « Bon. Encore un bout de chemin. »"),
        right: _c("Le laisser rester",
            fx: {Stat.bois: 15, Stat.moral: -8}, flags: ['vieuxParti'],
            result: "Il te laisse sa réserve de bois. Le wagon perd une présence."),
      ),
    ];
  }
  return [
    StoryCard(
      id: 'G6',
      kind: CardKind.gare,
      speaker: 'Camp-refuge',
      text:
          "Des feux, des survivants. Au nord, le froid tient les pillards à distance, des familles se regroupent.",
      left: _c("Échanger avec eux",
          fx: {Stat.faim: 10, Stat.bois: 8, Stat.soif: -4},
          result: "Tu troques contre des vivres et du bois."),
      right: _c("Te méfier, repartir",
          fx: {Stat.moral: -4},
          result: "Tu repars seule, plus pauvre mais entière."),
    ),
  ];
}

List<StoryCard> _gare7(Set<String> f) => [
      StoryCard(
        id: 'G7',
        kind: CardKind.gare,
        speaker: 'Halte 12',
        text:
            "Enfant, tu venais ici avec ta sœur regarder passer les trains. Un souvenir remonte, intact, douloureux.",
        left: _c("Te laisser submerger",
            fx: {Stat.moral: -6},
            result: "Tu pleures longtemps. Après, étrangement, tu respires mieux."),
        right: _c("En faire une promesse",
            fx: {Stat.moral: 12},
            result: "« Je te retrouverai. » Tu le dis comme un serment."),
      ),
    ];

List<StoryCard> _gare8(Set<String> f) => [
      StoryCard(
        id: 'G8',
        kind: CardKind.gare,
        speaker: 'Entrée zone froide',
        text:
            "Le froid mord pour de bon. Sur la voie, contre un signal mort : un enfant seul, bleui, vivant de justesse.",
        left: _c("Le prendre à bord",
            fx: {Stat.faim: -8, Stat.soif: -6, Stat.moral: 14},
            flags: ['aLEnfant'],
            result: "Il s'accroche à ton manteau. Il a l'âge qu'aurait ta sœur."),
        right: _c("Ne pas pouvoir le sauver",
            fx: {Stat.moral: -18},
            result: "Tu passes. Son image te suivra à chaque gare."),
      ),
    ];

List<StoryCard> _gare9(Set<String> f) {
  if (f.contains('aLEnfant')) {
    return [
      StoryCard(
        id: 'G9e',
        kind: CardKind.gare,
        speaker: 'Plaine enneigée',
        text:
            "Le blizzard enveloppe tout. L'enfant brûle de fièvre, délire, appelle une mère qui ne viendra pas.",
        left: _c("Le veiller toute la nuit",
            fx: {Stat.faim: -6, Stat.moral: 8},
            result: "Au matin, sa fièvre tombe un peu. Il serre ta main."),
        right: _c("Braver la tempête pour des médicaments",
            fx: {Stat.soif: -8, Stat.moral: 4},
            result: "Tu reviens avec des cachets périmés. Ça suffira."),
      ),
    ];
  }
  return [
    StoryCard(
      id: 'G9',
      kind: CardKind.gare,
      speaker: 'Plaine enneigée',
      text:
          "Le blizzard enveloppe tout. Le silence blanc est total ; tu pourrais hurler sans le moindre écho.",
      left: _c("Tenir bon, attendre",
          fx: {Stat.moral: -6}, result: "La nuit dure mille ans. Tu survis. Seule."),
      right: _c("Fouiller les ruines",
          fx: {Stat.faim: 8, Stat.soif: -5},
          result: "Des conserves gelées dans une cave murée."),
    ),
  ];
}

List<StoryCard> _gare10(Set<String> f) => [
      StoryCard(
        id: 'G10',
        kind: CardKind.gare,
        speaker: 'Oasis perdue',
        text:
            "Une serre intacte au milieu du blanc, chauffée par une source. Des plantes vertes. De la vie. Un répit irréel.",
        left: _c("T'installer, te reposer",
            fx: {Stat.faim: 18, Stat.soif: 15, Stat.moral: 15},
            result: "Quelques jours de chaleur, de verdure, de presque-bonheur."),
        right: _c("Faire le plein et repartir",
            fx: {Stat.faim: 12, Stat.soif: 10, Stat.bois: 10},
            result: "Le devoir avant le repos."),
      ),
    ];

List<StoryCard> _gare11(Set<String> f) {
  if (f.contains('aAideFuyard')) {
    return [
      StoryCard(
        id: 'G11t',
        kind: CardKind.gare,
        speaker: 'Halte 31',
        text:
            "Tomas t'attend sur le quai. Il a couru au-devant de toi pour te prévenir — des pillards remontent la voie.",
        left: _c("Fuir avec Tomas",
            fx: {Stat.moral: 12, Stat.faim: -6},
            result: "À deux, vous tenez les pillards en respect. Vous n'êtes plus seuls."),
        right: _c("Le remercier et filer seule",
            fx: {Stat.moral: -5, Stat.bois: -8},
            result: "Seule, tu sèmes les phares dans un tunnel."),
      ),
    ];
  }
  if (f.contains('radio2') || f.contains('radio3')) {
    return [
      StoryCard(
        id: 'G11r',
        kind: CardKind.gare,
        speaker: 'Halte 31',
        text:
            "La voix de la radio te guide, limpide : « Halte 31, prends la voie de gauche. » Elle connaît ton nom.",
        left: _c("Suivre la voix",
            fx: {Stat.moral: 14}, flags: ['radio3'],
            result: "Les pillards s'enfoncent dans la mauvaise voie. « Bien. Continue. »"),
        right: _c("Garder ta route",
            fx: {Stat.moral: -8, Stat.bois: -10},
            result: "Tu te méfies de la voix. La fuite est rude, mais tu passes."),
      ),
    ];
  }
  return [
    StoryCard(
      id: 'G11',
      kind: CardKind.gare,
      speaker: 'Halte 31',
      text:
          "Des phares crèvent le brouillard : les pillards que tu as semés à la Halte 47 ont rattrapé le train.",
      left: _c("Affronter les pillards",
          fx: {Stat.moral: -10, Stat.faim: -8},
          result: "Tu te défends, cœur cognant. Ils renoncent. Pour cette fois."),
      right: _c("Tout brûler pour les distancer",
          fx: {Stat.bois: -15, Stat.moral: -4},
          result: "La loco rugit et t'arrache au danger, presque à sec."),
    ),
  ];
}

List<StoryCard> _gare12(Set<String> f) => [
      StoryCard(
        id: 'G12',
        kind: CardKind.gare,
        speaker: 'Tour de guet',
        text:
            "Du haut d'une tour, tu le vois enfin : loin au nord, des lumières. Des cheminées qui fument. Le refuge. Des gens.",
        left: _c("Y croire de toutes tes forces",
            fx: {Stat.moral: 16},
            result: "« Ils sont là. Je le sais. » L'espoir te porte comme jamais."),
        right: _c("Te préparer à la déception",
            fx: {Stat.moral: 4},
            result: "On a moins mal quand on n'attend rien. Mais on vit moins fort, aussi."),
      ),
    ];

List<StoryCard> _gare13(Set<String> f) {
  return [
    StoryCard(
      id: 'G13',
      kind: CardKind.gare,
      speaker: 'Col gelé',
      text:
          "La loco toussote : plus assez de bois pour le sommet. Il faut sacrifier quelque chose pour franchir la dernière pente.",
      left: _c("Brûler le mobilier du wagon",
          fx: {Stat.bois: 25, Stat.moral: -10},
          result: "La table, la couchette, le carnet — tout ce qui faisait un chez-toi. La loco repart."),
      right: f.contains('leVieuxABord') && !f.contains('vieuxParti')
          ? _c("Tout miser, finir à pied",
              fx: {Stat.moral: -12}, flags: ['vieuxParti'],
              result: "Le Vieux descend, pousse. « Vas-y, petite. Moi, j'ai fait ma route. » Il reste sur le col.")
          : _c("Tout miser, finir à pied",
              fx: {Stat.moral: -6, Stat.bois: -5},
              result: "Tu pousses, tu glisses — et la loco bascule de l'autre côté, à un souffle de la panne."),
    ),
  ];
}

List<StoryCard> _gare14(Set<String> f) => [
      StoryCard(
        id: 'G14',
        kind: CardKind.gare,
        speaker: 'Tunnel nord',
        text:
            "Le train s'engage dans le dernier tunnel. À l'autre bout : la lumière du refuge. Tu as tenu. Tu es arrivée.",
        left: _c("Sortir du tunnel",
            result: "La lumière t'aveugle. Le quai approche..."),
        right: _c("Sortir du tunnel",
            result: "La lumière t'aveugle. Le quai approche..."),
      ),
    ];

// ============================================================
// PAQUETS DE REMPLISSAGE par segment (échantillon, à étoffer)
// ============================================================

final List<StoryCard> _fill1 = [
  _filler('F1_homme',
      "Un homme court le long de la voie, hurlant, tendant les bras vers le train. Tu pourrais freiner pour le hisser à bord — mais la loco perdrait son élan.",
      _c("Freiner pour lui", fx: {Stat.bois: -10, Stat.moral: 6}, result: "Tu ralentis... il trébuche, n'y arrive pas. Mais tu auras essayé."),
      _c("Garder l'élan", fx: {Stat.moral: -8}, result: "Tu ne ralentis pas. Ses cris s'éteignent dans ton dos."),
      oneshot: true),
  _filler('F1_valise',
      "Une valise oubliée par un passager qui ne montera plus. Tu pourrais la vider de fond en comble, ou n'y prendre que l'essentiel.",
      _c("La piller à fond", fx: {Stat.faim: 8, Stat.moral: -5}, result: "Des vivres, des objets. Tu te sens charognard."),
      _c("Prendre juste la photo", fx: {Stat.moral: 7}, result: "Tu gardes leur visage. Le reste leur appartient."),
      oneshot: true),
  _filler('F1_chat',
      "Un chat errant te fixe, maigre, depuis un toit. Il a faim. Toi aussi.",
      _c("Partager ta ration", fx: {Stat.faim: -6, Stat.moral: 9}, result: "Il mange dans ta main. Un instant, tu n'es plus seule."),
      _c("Garder tes vivres", fx: {Stat.moral: -4}, result: "Tu détournes les yeux. Survivre endurcit.")),
  _filler('F1_gare',
      "Une gare intacte, distributeurs éventrés. Fouiller prend du temps — le train à l'arrêt, ça use du bois pour rien.",
      _c("Fouiller à fond", fx: {Stat.bois: -8, Stat.faim: 12}, result: "Conserves, eau en bouteille. Le détour valait le coup."),
      _c("Repartir vite", fx: {Stat.moral: 2}, result: "Tu ne traînes pas. Le nord n'attend pas.")),
  _filler('F1_blessure',
      "En forçant une porte rouillée, tu t'entailles profondément la main.",
      _c("Brûler du tissu pour cautériser", fx: {Stat.bois: -5, Stat.moral: 4}, result: "Ça pique atrocement, mais c'est propre."),
      _c("Serrer un chiffon et tenir", fx: {Stat.faim: -6, Stat.moral: -3}, result: "La fièvre monte. Ton corps puise dans ses réserves.")),
  _filler('F1_orage',
      "Un orage cendré éclate. Le toit du wagon fuit au-dessus de la couchette.",
      _c("Tendre les bâches (récolter l'eau)", fx: {Stat.soif: 12, Stat.moral: -3}, result: "Eau grise mais précieuse. Nuit trempée."),
      _c("Tout calfeutrer pour dormir au sec", fx: {Stat.moral: 6, Stat.soif: -4}, result: "Un vrai sommeil. Mais les réserves d'eau baissent.")),
];

final List<StoryCard> _fill2 = [
  _filler('F2_graffiti',
      "Sur un mur, peint en rouge : « ILS MENTENT SUR LE NORD. » Le doute te ronge le reste du jour.",
      _c("Le marquer sur ta carte (prudence)", fx: {Stat.moral: -6, Stat.faim: 8}, result: "Tu te mets à rationner dur, par peur. L'angoisse, mais des réserves."),
      _c("Cracher dessus, avancer", fx: {Stat.moral: 5, Stat.bois: -6}, result: "Tu accélères de rage. La loco boit, mais ta foi tient."),
      oneshot: true),
  _filler('F2_journal',
      "Le journal de bord d'un ancien conducteur, plein d'itinéraires utiles. Mais le papier brûle bien.",
      _c("L'étudier (gagner du temps plus tard)", fx: {Stat.moral: -4, Stat.bois: 8}, result: "Un raccourci noté. Triste à lire, mais ça paiera en bois économisé."),
      _c("Le jeter au foyer", fx: {Stat.bois: 5, Stat.moral: -5}, result: "Ses mots chauffent une heure. Pardon, l'ami."),
      oneshot: true),
  _filler('F2_aiguillage',
      "Un aiguillage. La voie connue, sûre et longue. Ou un raccourci inconnu vers le nord.",
      _c("Le raccourci", fx: {Stat.bois: 12, Stat.moral: -5}, result: "Tu gagnes des heures de bois — mais la voie se dégrade, inquiétante."),
      _c("La voie sûre", fx: {Stat.moral: 4, Stat.faim: -4}, result: "Plus long, plus de bouches à serrer. Mais tu sais où tu vas.")),
  _filler('F2_silhouettes',
      "Des silhouettes immobiles entre les rails dans le brouillard. Pillards ? Morts ? Affamés ?",
      _c("Ralentir, voir si on peut troquer", fx: {Stat.faim: 10, Stat.moral: -4}, result: "Des survivants. Tu troques, le cœur battant. Ils auraient pu être autre chose."),
      _c("Foncer sans regarder", fx: {Stat.bois: -8, Stat.moral: 3}, result: "Tu passes en trombe. Plus de peur que de mal, mais la loco a soif.")),
  _filler('F2_tunnel',
      "Un tunnel, noir absolu. La lampe rassure mais brûle de l'huile précieuse.",
      _c("Allumer la lampe", fx: {Stat.bois: -4, Stat.moral: 5}, result: "La flamme repousse les murs. Tu respires."),
      _c("Traverser dans le noir", fx: {Stat.moral: -7}, result: "Le noir, le grondement, l'éternité. Tu sors lessivée.")),
  _filler('F2_sifflet',
      "Le sifflet de la loco peut s'entendre à des kilomètres. Lancer un appel, c'est tenter le destin.",
      _c("Faire chanter le sifflet", fx: {Stat.faim: 10, Stat.moral: 4}, result: "Un survivant accourt, troque des vivres. Mais ton passage est désormais connu..."),
      _c("Rester silencieuse", fx: {Stat.moral: -3}, result: "Tu passes en fantôme. Personne ne saura que tu étais là.")),
];

final List<StoryCard> _fill3 = [
  _filler('F3_piano',
      "Un piano à queue abandonné sur un quai. En jouer t'apaiserait — mais le son porte loin dans le silence.",
      _c("Jouer quelques notes", fx: {Stat.moral: 10, Stat.bois: -6}, result: "La musique te lave l'âme. Tu repars vite, au cas où on t'aurait entendue."),
      _c("Y résister", fx: {Stat.moral: -3}, result: "Tu n'as plus le luxe de la beauté. Pas aujourd'hui."),
      oneshot: true),
  _filler('F3_livre',
      "Un livre d'images pour enfants : un renard et la lune. Tu le lisais à ta sœur.",
      _c("Le lire à voix haute", fx: {Stat.moral: 8, Stat.faim: -3}, result: "Tu pleures et tu souris. La nuit blanche en vaut la peine."),
      _c("Le garder pour le feu", fx: {Stat.bois: 4, Stat.moral: -6}, result: "Tu sacrifies un souvenir pour une heure de chaleur.")),
  _filler('F3_vivres',
      "Une épicerie à demi pillée. Le reste est en hauteur, dans des rayons instables.",
      _c("Grimper malgré le danger", fx: {Stat.faim: 14, Stat.soif: -5}, result: "Tu décroches le magot. Une chute évitée de justesse."),
      _c("Prendre ce qui est accessible", fx: {Stat.faim: 5}, result: "Le sûr plutôt que le gros lot.")),
  _filler('F3_arcenciel',
      "La pluie cesse, un arc-en-ciel pâle perce. T'arrêter pour le regarder coûte du temps et du bois.",
      _c("Stopper, contempler", fx: {Stat.moral: 9, Stat.bois: -7}, result: "Un cadeau du ciel mort. Tu repars le cœur plus léger."),
      _c("Rouler sans t'arrêter", fx: {Stat.moral: -2}, result: "Tu le regardes dans le rétroviseur. La route d'abord.")),
  _filler('F3_pont',
      "Un vieux pont ferroviaire craque sous le convoi. Ralentir l'épargne, foncer le tente.",
      _c("Ralentir prudemment", fx: {Stat.faim: -4, Stat.moral: -3}, result: "Le pont gémit mais tient. L'attente t'a creusé le ventre."),
      _c("Foncer avant qu'il cède", fx: {Stat.bois: -10, Stat.moral: 5}, result: "Derrière toi, une poutre tombe dans le vide. De justesse.")),
  _filler('F3_potager',
      "Un potager sauvage a repoussé près d'une halte. Récolter prend du temps à découvert.",
      _c("Récolter à fond", fx: {Stat.faim: 12, Stat.moral: -4}, result: "Des légumes ! Mais tu te sens observée tout du long."),
      _c("Cueillir vite et filer", fx: {Stat.faim: 5, Stat.moral: 3}, result: "Un peu, mais sans risque. Tu files tranquille.")),
];

final List<StoryCard> _fill4 = [
  _filler('F4_chanson',
      "La radio capte une vieille chanson d'amour intacte. L'écouter use la manivelle et ravive la douleur.",
      _c("Écouter jusqu'au bout", fx: {Stat.moral: 10, Stat.faim: -4}, result: "Tu danses seule, en larmes. Tu en oublies de manger."),
      _c("Couper, garder l'énergie", fx: {Stat.moral: -5}, result: "Cette chanson, c'était la leur. Tu coupes net."),
      oneshot: true, requires: (f) => f.contains('aLaRadio')),
  _filler('F4_maria',
      "Un mur couvert de messages : des gens cherchent des gens. Tu pourrais y ajouter ton nom.",
      _c("Écrire ton nom et ta voie", fx: {Stat.moral: 8, Stat.soif: -4}, result: "Si les tiens passent ici... Tu y crois assez pour t'attarder."),
      _c("Ne pas t'exposer", fx: {Stat.moral: -4}, result: "Laisser une trace, c'est aussi être traçable. Tu t'abstiens."),
      oneshot: true),
  _filler('F4_cerfs',
      "Un troupeau de cerfs efflanqués traverse la voie. De la viande sur pattes — ou de la vie à épargner.",
      _c("Tenter d'en abattre un", fx: {Stat.faim: 16, Stat.moral: -7}, result: "De la viande pour des jours, et un goût de cendre dans la bouche."),
      _c("Freiner pour les laisser passer", fx: {Stat.bois: -8, Stat.moral: 8}, result: "L'un te regarde, longtemps. De la vie, encore. Ça vaut le bois perdu.")),
  _filler('F4_ville',
      "Une ville intacte, trop calme. Pleine de ressources — et peut-être de gens qui les gardent.",
      _c("S'arrêter explorer", fx: {Stat.faim: 14, Stat.bois: 8, Stat.moral: -8}, result: "Le jackpot — mais des traces fraîches te glacent. Tu pars en courant."),
      _c("Passer au large", fx: {Stat.moral: 3}, result: "Trop beau pour être sûr. Ton instinct te sauve peut-être.")),
  _filler('F4_reflet',
      "Une vitre te renvoie ton reflet : maigre, dure, méconnaissable. Qui es-tu devenue ?",
      _c("Te forcer à sourire à l'inconnue", fx: {Stat.moral: 7, Stat.faim: -3}, result: "« On tient bon, toi et moi. » Tu manges peu, mais tu tiens."),
      _c("Détourner le regard", fx: {Stat.moral: -5}, result: "Tu refuses de voir ce que le voyage fait de toi.")),
  _filler('F4_puits',
      "Un château d'eau encore plein, mais l'échelle est rouillée, vertigineuse.",
      _c("Grimper remplir les jarres", fx: {Stat.soif: 18, Stat.moral: -4}, result: "De l'eau pour longtemps. Tes mains tremblent encore de la hauteur."),
      _c("Renoncer, trop risqué", fx: {Stat.moral: 2, Stat.soif: -5}, result: "Mieux vaut soif que chute mortelle. Tu repars sèche.")),
];

final List<StoryCard> _fill5 = [
  _filler('F5_trainvide',
      "Un train croise le tien : vide, portes ouvertes, pas une âme. Le fouiller, c'est s'arrêter en terrain à découvert.",
      _c("Le piller", fx: {Stat.bois: 12, Stat.faim: 8, Stat.moral: -6}, result: "Du charbon, des vivres — et la question glaçante : où sont passés ses passagers ?"),
      _c("Ne pas t'arrêter", fx: {Stat.moral: -3}, result: "Tu n'oses pas savoir. Tu passes ton chemin."),
      oneshot: true),
  _filler('F5_carnet',
      "Un carnet de croquis et un crayon. Dessiner les tiens te ferait du bien — ou te briserait.",
      _c("Dessiner leurs visages", fx: {Stat.moral: 9, Stat.faim: -3}, result: "Tant que tu peux les dessiner, tu ne les as pas perdus. Tu en oublies de souper."),
      _c("Le garder pour le feu", fx: {Stat.bois: 4, Stat.moral: -4}, result: "Du papier pour le foyer. Tu ne te sens pas prête à les regarder."),
      oneshot: true),
  _filler('F5_peche',
      "Le train longe un lac. Pêcher demande de s'arrêter des heures, à découvert.",
      _c("S'arrêter pêcher", fx: {Stat.faim: 15, Stat.bois: -6, Stat.moral: -3}, result: "Trois poissons. Mais chaque heure immobile te ronge les nerfs."),
      _c("Continuer", fx: {Stat.moral: 3}, result: "Tu ne t'arrêtes pas en terrain ouvert. Sage, mais le ventre crie.")),
  _filler('F5_graines',
      "Un sachet de graines potagères, encore viables. Les semer ici, ou les garder pour ta serre future ?",
      _c("Les garder pour cultiver", fx: {Stat.faim: 6, Stat.moral: 3}, result: "Un capital d'avenir. De quoi manger plus tard."),
      _c("En semer le long de la voie", fx: {Stat.moral: 8, Stat.faim: -2}, result: "Pour ceux qui passeront après toi. Un geste gratuit, donc précieux.")),
  _filler('F5_malade',
      "Tu te réveilles fiévreuse, frissonnante. Pousser le feu te réchaufferait, mais le bois est compté.",
      _c("Te soigner au chaud", fx: {Stat.bois: -10, Stat.moral: 6}, result: "Tu transpires la fièvre près du foyer rugissant. Ça passe."),
      _c("Serrer les dents", fx: {Stat.faim: -8, Stat.moral: -4}, result: "Ton corps brûle ses réserves pour lutter. Tu tiens, à peine.")),
  _filler('F5_doute',
      "« Et si le nord n'existait pas ? » La pensée t'écrase. Y céder ou la combattre te coûte autant.",
      _c("Combattre par l'action", fx: {Stat.moral: 7, Stat.bois: -6}, result: "Tu jettes du bois, tu accélères, tu te prouves que tu y crois."),
      _c("T'asseoir dans le doute", fx: {Stat.moral: -8, Stat.faim: 5}, result: "Tu ne fais rien, tu rumines. Au moins tu n'as pas gaspillé.")),
];

final List<StoryCard> _fill6 = [
  _filler('F6_berceuse',
      "Souvenir : ta sœur terrifiée par le noir, et toi qui chantais jusqu'à son sommeil. La chanter te coûtera des larmes.",
      _c("Chanter la berceuse", fx: {Stat.moral: 11, Stat.faim: -3}, result: "Ta voix tremble dans le wagon glacé. Tu chantes pour deux. Nuit sans manger."),
      _c("Ravaler tes larmes", fx: {Stat.moral: -5}, result: "Chanter, ce serait t'effondrer. Tu te tais."),
      oneshot: true),
  _filler('F6_village',
      "Un village de montagne, une cheminée qui fume. Des gens — donc des vivres possibles, et un danger possible.",
      _c("Aller frapper", fx: {Stat.faim: 12, Stat.moral: -6}, result: "Une vieille te nourrit contre une histoire, puis te chasse, méfiante."),
      _c("Ne pas risquer", fx: {Stat.moral: 2, Stat.faim: -4}, result: "Une cheminée qui fume veut dire quelqu'un. Tu passes, le ventre vide.")),
  _filler('F6_loups',
      "Une meute de loups suit le train. Ils s'approchent du wagon la nuit.",
      _c("Tirer une bûche enflammée", fx: {Stat.bois: -8, Stat.moral: 4}, result: "Le feu les disperse. Tu gardes ton petit monde intact."),
      _c("Te terrer en silence", fx: {Stat.moral: -6}, result: "Tu retiens ton souffle toute la nuit. Au matin, des griffures sur la porte.")),
  _filler('F6_manteau',
      "Un manteau de laine épais dans une malle. Le froid arrive — mais il sent le moisi, peut-être la maladie.",
      _c("L'enfiler quand même", fx: {Stat.moral: 7, Stat.faim: -4}, result: "Au chaud, mais une toux s'installe. Le corps lutte."),
      _c("Le brûler par prudence", fx: {Stat.bois: 5, Stat.moral: -3}, result: "Une flambée, et tant pis pour la chaleur durable.")),
  _filler('F6_eboulement',
      "Un éboulement bloque à moitié la voie. Déblayer épuise ; forcer abîme la loco.",
      _c("Déblayer à la main", fx: {Stat.faim: -8, Stat.moral: 4}, result: "Des heures de pelle. Épuisée mais la voie est nette."),
      _c("Forcer le passage", fx: {Stat.bois: -10, Stat.moral: -2}, result: "La loco racle, crache, passe. Elle s'en souviendra.")),
  _filler('F6_givre',
      "Les premières fougères de givre couvrent les vitres. Le froid devient une menace réelle.",
      _c("Pousser le foyer pour devancer le froid", fx: {Stat.bois: -8, Stat.moral: 5}, result: "Un cocon de chaleur. Tu entames sérieusement la réserve."),
      _c("Rationner le bois", fx: {Stat.moral: -5, Stat.faim: -3}, result: "Tu claques des dents pour garder du combustible. Long.")),
];

final List<StoryCard> _fill7 = [
  _filler('F7_corps',
      "Un corps gelé serre une photo contre lui. Il porte aussi un bon manteau et un sac plein.",
      _c("Prendre ses affaires", fx: {Stat.faim: 10, Stat.moral: -8}, result: "Vivres et chaleur. Mais tu lui as pris jusqu'à sa dignité."),
      _c("Le laisser en paix", fx: {Stat.moral: 7, Stat.faim: -3}, result: "Tu inclines la tête et tu passes. Le ventre vide, la conscience nette."),
      oneshot: true),
  _filler('F7_refuge',
      "Un refuge de montagne : lits faits, table mise, vide depuis longtemps. Y dormir = perdre une nuit de route.",
      _c("Y passer la nuit", fx: {Stat.moral: 10, Stat.bois: -5}, result: "Un vrai lit, un vrai toit. Tu rêves de chez toi. La loco a refroidi."),
      _c("Rafler et repartir", fx: {Stat.faim: 8, Stat.moral: -3}, result: "Tu prends les vivres, tu files. Pas le temps de t'attendrir."),
      oneshot: true),
  _filler('F7_rennes',
      "Des rennes grattent la neige, paisibles. Du gibier facile — ou un spectacle de vie à préserver.",
      _c("En prélever un", fx: {Stat.faim: 16, Stat.moral: -6}, result: "De quoi tenir longtemps. La faim parle plus fort que la beauté."),
      _c("Les regarder vivre", fx: {Stat.moral: 8, Stat.faim: -4}, result: "La vie s'accroche, têtue. Ça te donne du courage, sinon des calories.")),
  _filler('F7_glace',
      "La voie est verglacée. Saler/sabler prend du bois chaud ; passer tel quel risque le déraillement.",
      _c("Chauffer pour faire fondre", fx: {Stat.bois: -10, Stat.moral: 4}, result: "Tu avances sûr, lentement. Le foyer rugit."),
      _c("Passer au jugé", fx: {Stat.moral: -7}, result: "Le wagon glisse, tangue, manque verser. Tu blêmis.")),
  _filler('F7_voix',
      "Tu n'as pas entendu ta propre voix depuis des jours. Le silence t'engloutit.",
      _c("Chanter, parler, crier", fx: {Stat.moral: 8, Stat.soif: -4}, result: "Ta voix résonne, rauque, vivante. La gorge sèche, mais l'âme tient."),
      _c("T'enfoncer dans le silence", fx: {Stat.moral: -6}, result: "Tu n'as plus rien à dire au vide. Le mutisme gagne.")),
  _filler('F7_traces',
      "Des traces de pas fraîches s'éloignent de la voie vers une cache possible.",
      _c("Suivre la piste", fx: {Stat.faim: 10, Stat.bois: -5, Stat.moral: -3}, result: "Une réserve abandonnée. Mais t'éloigner du train t'a glacée d'angoisse."),
      _c("Rester près du train", fx: {Stat.moral: 3}, result: "Tu ne quittes pas ta loco. La prudence avant le butin.")),
];

final List<StoryCard> _fill8 = [
  _filler('F8_dirigeable',
      "Une carcasse de dirigeable abattu émerge de la neige. La nacelle peut cacher un trésor — ou un piège.",
      _c("Fouiller la nacelle", fx: {Stat.faim: 12, Stat.bois: 8, Stat.moral: -5}, result: "Rations militaires, charbon ! Mais des ossements récents te pressent de partir."),
      _c("Contourner", fx: {Stat.moral: 2}, result: "Qui sait ce qui s'y terre. Tu passes au large."),
      oneshot: true),
  _filler('F8_boite',
      "Une boîte à musique. La mélodie est belle mais elle réveille tout ce que tu fuis.",
      _c("La laisser jouer", fx: {Stat.moral: 7, Stat.faim: -3}, result: "Tu écoutes, immobile, jusqu'au dernier tour. La nuit file sans repas."),
      _c("L'arrêter net", fx: {Stat.moral: -4}, result: "Trop. Tu refermes le couvercle d'un coup sec."),
      oneshot: true),
  _filler('F8_rivet',
      "Le gel fait éclater un rivet : un courant d'air glacé envahit le wagon.",
      _c("Colmater (mains nues dans le froid)", fx: {Stat.faim: -6, Stat.moral: 5}, result: "Tu bouches la fissure, doigts gelés. Le wagon redevient vivable."),
      _c("Pousser le feu à la place", fx: {Stat.bois: -10, Stat.moral: -2}, result: "Tu compenses par la chaleur. La réserve fond à vue d'œil.")),
  _filler('F8_lunaire',
      "Plaine blanche infinie, aucun repère. S'arrêter pour t'orienter coûte ; avancer à l'aveugle risque l'errance.",
      _c("Stopper, t'orienter", fx: {Stat.bois: -6, Stat.moral: 4}, result: "Tu retrouves le cap aux étoiles. Sûr, mais coûteux."),
      _c("Avancer à l'instinct", fx: {Stat.moral: -5, Stat.faim: -4}, result: "Tu roules dans le vide, le doute au ventre. Un détour involontaire ?")),
  _filler('F8_tempete',
      "Le ciel noircit d'un coup : une tempête fond sur le train.",
      _c("S'abriter et attendre", fx: {Stat.bois: -6, Stat.soif: 6, Stat.moral: -2}, result: "Tu te calfeutres. La neige fondue fait de l'eau, mais tu perds un jour."),
      _c("Tenter de la devancer", fx: {Stat.bois: -12, Stat.moral: 4}, result: "Course folle contre le mur blanc. Tu passes devant, presque à sec.")),
];

final List<StoryCard> _fill9 = [
  _filler('F9_cristal',
      "Une forêt entière figée en cristal de givre. Traverser lentement pour admirer, ou foncer ?",
      _c("Ralentir, contempler", fx: {Stat.moral: 10, Stat.bois: -7}, result: "Une cathédrale de glace rien que pour toi. Le bois fond avec le temps."),
      _c("Traverser vite", fx: {Stat.moral: -2}, result: "Trop beau, trop silencieux. Tu n'aimes pas t'attarder."),
      oneshot: true),
  _filler('F9_traineau',
      "Un traîneau et un harnais abandonnés. Lourds, encombrants — mais utiles si la loco lâche.",
      _c("L'embarquer", fx: {Stat.bois: -4, Stat.moral: 6}, result: "Un plan B rassurant. Mais ça pèse, la loco peine un peu plus."),
      _c("Le laisser", fx: {Stat.moral: -2}, result: "Tu paries tout sur le train. Pas de filet.")),
  _filler('F9_ours',
      "Des empreintes d'ours blanc, immenses. Le suivre mène peut-être à une carcasse à charogner.",
      _c("Suivre la piste", fx: {Stat.faim: 14, Stat.moral: -7}, result: "Une carcasse à demi dévorée. Tu prélèves, vite, terrifiée."),
      _c("Verrouiller et fuir", fx: {Stat.bois: -6, Stat.moral: 3}, result: "Tu accélères loin du prédateur. Sûr, mais le ventre crie.")),
  _filler('F9_lac',
      "Un lac gelé fait miroir au ciel. La glace tiendra-t-elle le poids du convoi ?",
      _c("Traverser sur la glace (raccourci)", fx: {Stat.bois: 10, Stat.moral: -8}, result: "La glace craque sous toi. Tu passes — le cœur arrêté — mais tu gagnes des heures."),
      _c("Contourner par la berge", fx: {Stat.bois: -8, Stat.moral: 4}, result: "Plus long, plus de bois brûlé, mais tes nerfs sont saufs.")),
  _filler('F9_aurore',
      "Une aurore embrase tout le ciel. Couper le moteur pour la vivre pleinement coûte du temps.",
      _c("Stopper sous les lumières", fx: {Stat.moral: 12, Stat.bois: -6}, result: "Le silence et le ciel en feu. Inoubliable. Tu repars régénérée."),
      _c("Rouler en la regardant", fx: {Stat.moral: 5}, result: "Le ciel danse dans le pare-brise givré. Tu n'arrêtes pas la route.")),
];

final List<StoryCard> _fill10 = [
  _filler('F10_bain',
      "Une source chaude, fumante. Un bain — luxe oublié — mais t'attarder retarde le voyage.",
      _c("T'y plonger longuement", fx: {Stat.moral: 12, Stat.bois: -5}, result: "La chaleur te dénoue. Tu pleures de soulagement. La loco refroidit dehors."),
      _c("Te laver vite", fx: {Stat.moral: 5}, result: "Propre, déjà énorme. Tu ne traînes pas."),
      oneshot: true),
  _filler('F10_lettre',
      "Dans la serre, une lettre jamais envoyée, posée près d'un lit défait. « Mon amour, si tu lis ça, c'est que j'ai attendu trop longtemps... »",
      _c("La lire en entier", fx: {Stat.moral: -6, Stat.faim: 4}, result: "Une histoire d'amour brisée par l'hiver. Tu pleures, puis tu manges ce qu'il reste de leurs conserves."),
      _c("La reposer, respecter", fx: {Stat.moral: 5}, result: "Certaines douleurs ne sont pas à lire. Tu la laisses à sa place."),
      oneshot: true),
  _filler('F10_fruits',
      "La serre croule sous les fruits mûrs. Te gaver ou faire des réserves de conserves ?",
      _c("Te gorger maintenant", fx: {Stat.faim: 14, Stat.moral: 6, Stat.soif: 6}, result: "Du jus plein le menton, les yeux fermés. Le bonheur d'avoir assez, ici et maintenant."),
      _c("Tout mettre en conserve", fx: {Stat.faim: 8, Stat.moral: -2}, result: "Tu remplis des bocaux pour la route. La tête prime sur l'instant.")),
  _filler('F10_occupant',
      "Une chambre aménagée par un occupant disparu : photos, médicaments, vivres. Respecter ou fouiller ?",
      _c("Fouiller (tu en as besoin)", fx: {Stat.faim: 8, Stat.soif: 6, Stat.moral: -5}, result: "Médocs et conserves. Mais tu te sens voleuse de sa vie suspendue."),
      _c("Ne rien toucher", fx: {Stat.moral: 7}, result: "Tu laisses son sanctuaire intact. Une trace d'humanité préservée.")),
  _filler('F10_etoiles',
      "Dernière nuit calme avant la halte 31. Veiller sous les étoiles, ou dormir pour être prête ?",
      _c("Compter les étoiles comme avant", fx: {Stat.moral: 9, Stat.faim: -3}, result: "La Grande Ourse, qui ramène à la maison, disait ta sœur. Tu veilles tard."),
      _c("Dormir pour récupérer", fx: {Stat.moral: 4, Stat.faim: 4}, result: "Un sommeil profond. Demain sera rude, tu seras prête.")),
];

final List<StoryCard> _fill11 = [
  _filler('F11_englouti',
      "Sous la glace transparente, une ville engloutie. La fixer trop longtemps te ronge ; détourner les yeux coûte du bois pour fuir.",
      _c("Contempler le monde noyé", fx: {Stat.moral: -7, Stat.faim: 5}, result: "Toits, rues, lampadaires figés sous tes roues. Tu en oublies tout, même la faim."),
      _c("Accélérer pour quitter ça", fx: {Stat.bois: -8, Stat.moral: 3}, result: "Tu fuis l'image. La loco boit, mais ta tête respire."),
      oneshot: true),
  _filler('F11_draisine',
      "Une draisine à bras abandonnée : quelqu'un a tenté le nord seul. La récupérer = un secours si la loco meurt.",
      _c("La charger", fx: {Stat.bois: -5, Stat.moral: 5}, result: "Une assurance-vie. Lourde, mais rassurante."),
      _c("La laisser", fx: {Stat.moral: -3}, result: "Abandonnée en pleine voie... il n'est pas allé loin. Mauvais présage.")),
  _filler('F11_statue',
      "Une statue ensevelie, bras tendu vers le nord. Un guide de pierre — ou un leurre ?",
      _c("Suivre sa direction", fx: {Stat.bois: 8, Stat.moral: 5}, result: "Le bras pointait un raccourci réel. Du temps et du bois gagnés."),
      _c("Te fier à ta carte", fx: {Stat.moral: -2, Stat.faim: -3}, result: "Tu ne suis pas une pierre. Plus long, mais tu maîtrises.")),
  _filler('F11_froid',
      "Le froid devient absolu, le givre gagne l'intérieur. Tenir chaud épuise le bois ; endurer épuise le corps.",
      _c("Pousser le feu à fond", fx: {Stat.bois: -12, Stat.moral: 6}, result: "Un brasier. Tu survis à la nuit polaire, mais la réserve s'effondre."),
      _c("Endurer, stoïque", fx: {Stat.faim: -8, Stat.moral: -4}, result: "Ton corps brûle ses calories pour ne pas geler. Tu tiens, exsangue.")),
  _filler('F11_provisions',
      "Tu fais les comptes : les vivres ne tiendront pas jusqu'au refuge sans rationner dès maintenant.",
      _c("Rationner dur dès aujourd'hui", fx: {Stat.faim: -6, Stat.moral: -4}, result: "Demi-portions. Le ventre crie, mais tu ne manqueras pas au pire moment."),
      _c("Manger normalement, aviser après", fx: {Stat.faim: 8, Stat.moral: 3}, result: "Tu refuses de te priver maintenant. On verra. L'angoisse reviendra.")),
];

final List<StoryCard> _fill12 = [
  _filler('F12_autel',
      "Un autel de voyageurs : photos, jouets, mots d'adieu. Y laisser un objet à toi t'allège — mais c'est un objet de moins.",
      _c("Y déposer la photo de famille", fx: {Stat.moral: 9}, result: "Tu confies leur image au seuil du refuge. Étrangement, tu te sens plus légère."),
      _c("Tout garder", fx: {Stat.moral: -3}, result: "Tu n'as rien à donner. Tu pries en silence et tu pars."),
      oneshot: true),
  _filler('F12_carcasses',
      "Des carcasses d'autres trains, ensevelies dans le col. Ils n'ont pas passé l'hiver. Fouiller leurs réserves ?",
      _c("Fouiller les épaves", fx: {Stat.bois: 14, Stat.moral: -7}, result: "Du charbon dans une soute. Mais marcher parmi ces morts te glace l'âme."),
      _c("Ne pas profaner", fx: {Stat.moral: 5, Stat.bois: -4}, result: "Tu passes, tête basse. Pas question de piller des tombes."),
      oneshot: true),
  _filler('F12_loco',
      "Le cœur de la loco bat irrégulièrement. La réparer maintenant coûte un arrêt ; l'ignorer risque le pire au col.",
      _c("S'arrêter la réparer", fx: {Stat.bois: -6, Stat.faim: -4, Stat.moral: 5}, result: "Des heures sous la machine, gelée. Mais elle ronronne de nouveau."),
      _c("Continuer, prier", fx: {Stat.moral: -5}, result: "Tu pousses, le ventre noué. Chaque toux de la loco te terrifie.")),
  _filler('F12_croix',
      "Une croix fleurie de fleurs gelées fraîches : des vivants, tout près. Les chercher, ou rester sur ta voie ?",
      _c("Chercher la présence", fx: {Stat.faim: 10, Stat.bois: -6, Stat.moral: 4}, result: "Un campement minuscule, un troc rapide. Détour payant mais coûteux en bois."),
      _c("Rester sur ta voie", fx: {Stat.moral: 2}, result: "Si près du but, tu ne te disperses pas.")),
  _filler('F12_vivres_finales',
      "Avant le col, dernier choix de réserves : alléger le wagon pour grimper, ou tout garder pour le refuge ?",
      _c("Tout garder, quitte à peiner", fx: {Stat.bois: -10, Stat.faim: 6}, result: "Le wagon lourd peine dans la pente. Mais tu arriveras les bras pleins."),
      _c("Alléger pour grimper", fx: {Stat.bois: 8, Stat.faim: -8}, result: "Tu jettes du lest. La loco grimpe mieux, mais tu arriveras les mains vides.")),
  _filler('F12_phare',
      "Au sommet d'un pylône, une lampe clignote encore, alimentée par le vent. Un signal ? Grimper pour voir coûte des forces.",
      _c("Grimper voir le signal", fx: {Stat.faim: -7, Stat.moral: 13}, result: "De là-haut, tu aperçois les fumées du refuge, plus proches que tu ne croyais. L'espoir te submerge."),
      _c("Rester en bas", fx: {Stat.moral: -3}, result: "Tu n'as plus la force des détours. Tu fixes les rails.")),
  _filler('F12_gel',
      "Le gel a soudé l'aiguillage. Le dégeler à l'eau chaude vide tes réserves ; forcer au pied-de-biche risque de tout casser.",
      _c("Dégeler à l'eau chaude", fx: {Stat.soif: -16, Stat.moral: 4}, result: "Tu sacrifies ta réserve d'eau bouillante. L'aiguille cède, tu passes."),
      _c("Forcer au pied-de-biche", fx: {Stat.bois: -6, Stat.moral: -8}, result: "Un craquement sinistre. Ça passe, mais l'aiguillage est mort derrière toi.")),
  _filler('F12_silence',
      "Un silence absolu, irréel. Même le vent s'est tu. Ton souffle givre devant toi.",
      _c("Briser le silence (crier)", fx: {Stat.moral: 7, Stat.soif: -3}, result: "Tu hurles ton nom dans l'immensité. L'écho te répond. Tu existes encore."),
      _c("T'y fondre", fx: {Stat.moral: -9}, result: "Le silence t'avale. Tu te sens disparaître, grain par grain.")),
];

// ============================================================
// LE SCÉNARIO : 14 segments
// ============================================================

final List<Segment> trainCosyScenario = [
  Segment(gareCards: _gare1, fillerPool: _fill1, drawCount: 4),
  Segment(gareCards: _gare2, fillerPool: _fill2, drawCount: 4),
  Segment(gareCards: _gare3, fillerPool: _fill3, drawCount: 4),
  Segment(gareCards: _gare4, fillerPool: _fill4, drawCount: 4),
  Segment(gareCards: _gare5, fillerPool: _fill5, drawCount: 4),
  Segment(gareCards: _gare6, fillerPool: _fill6, drawCount: 4),
  Segment(gareCards: _gare7, fillerPool: _fill7, drawCount: 4),
  Segment(gareCards: _gare8, fillerPool: _fill8, drawCount: 4),
  Segment(gareCards: _gare9, fillerPool: _fill9, drawCount: 4),
  Segment(gareCards: _gare10, fillerPool: _fill10, drawCount: 4),
  Segment(gareCards: _gare11, fillerPool: _fill11, drawCount: 4),
  Segment(gareCards: _gare12, fillerPool: _fill12, drawCount: 4),
  Segment(gareCards: _gare13, fillerPool: const [], drawCount: 0),
  Segment(gareCards: _gare14, fillerPool: const [], drawCount: 0),
];

/// Résout la fin à partir des stats finales + flags.
String resolveTrainCosyEnding(Map<Stat, int> stats, Set<String> flags) {
  final moral = stats[Stat.moral] ?? 0;
  final radio3 = flags.contains('radio3');
  final hasCompagnon = flags.contains('aLEnfant') || flags.contains('aAideFuyard');
  if (radio3 && moral >= 60 && flags.contains('aLaRadio')) return 'secrete';
  if (moral >= 55 && hasCompagnon) return 'retrouvailles';
  if (moral >= 30) return 'deuil';
  return 'abandon';
}

/// Textes des fins.
const Map<String, ({String title, String body})> endings = {
  'retrouvailles': (
    title: 'Retrouvailles',
    body:
        "Sur le quai du refuge, des silhouettes se précipitent. Parmi elles, un visage que tu connais par cœur. Tu n'as pas rêvé. Tu n'as pas tenu pour rien.\n\nTu as survécu, de corps et d'âme. Vous êtes ensemble.",
  ),
  'deuil': (
    title: 'Le deuil et la vie',
    body:
        "Ils ne sont pas là. Tu cherches, tu demandes, tu montres leurs visages dessinés de mémoire. Personne. La vérité s'impose : ils ne viendront pas.\n\nMais tu es là. Tu choisis de rester, de reconstruire, de vivre. Une autre forme de victoire.",
  ),
  'mort': (
    title: "Le voyage s'arrête",
    body:
        "Le train ralentit, puis se tait, au milieu du blanc. Une jauge est tombée à zéro. Quelque part, peut-être, quelqu'un t'attend encore. Il ne le saura jamais.",
  ),
  'abandon': (
    title: "L'abandon",
    body:
        "À quoi bon. Tu n'y crois plus. À une gare sans nom, tu descends. Le train repart sans toi, vide, et disparaît dans le blanc.",
  ),
  'secrete': (
    title: 'La voix',
    body:
        "Sur le quai, une femme tient une vieille radio à manivelle, jumelle de la tienne. Elle se retourne. C'est ta sœur. C'était elle, depuis le début, qui parlait dans le grésillement. Qui t'a guidée.\n\nVous avez survécu, toutes les deux. Le monde mort, pour une fois, n'a pas gagné.",
  ),
};
