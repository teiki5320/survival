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
      "Un homme court le long de la voie, hurlant, tendant les bras vers le train qui prend de la vitesse. Tu ne peux rien faire.",
      _c("Le regarder jusqu'au bout", fx: {Stat.moral: -6}, result: "Il tombe, ne se relève pas. Tu graveras son visage."),
      _c("Rentrer dans le wagon", fx: {Stat.moral: -2}, result: "Tu fermes la porte sur ses cris."),
      oneshot: true),
  _filler('F1_valise',
      "Une valise oubliée par un passager qui ne montera plus. Dedans : des habits, et une photo de famille.",
      _c("Garder la photo", fx: {Stat.moral: 5}, result: "Ne pas les laisser disparaître tout à fait."),
      _c("Ne pas fouiller leur vie", fx: {Stat.moral: 2}, result: "Leur intimité leur appartient."),
      oneshot: true),
  _filler('F1_draps',
      "Des draps pendent aux fenêtres des immeubles éventrés, comme des fantômes qui te saluent.",
      _c("Y voir un adieu", fx: {Stat.moral: 4}, result: "Un dernier salut à un monde qui s'éteint."),
      _c("Détourner le regard", fx: {Stat.moral: -3}, result: "Ne rien voir, c'est moins souffrir.")),
  _filler('F1_chat',
      "Un chat errant te fixe depuis un toit effondré, immobile, royal.",
      _c("L'appeler doucement", fx: {Stat.moral: 4}, result: "Il cligne des yeux — un salut — puis disparaît."),
      _c("Le regarder, sans plus", fx: {Stat.moral: 1}, result: "Chacun sa survie.")),
  _filler('F1_horloge',
      "L'horloge de la gare, figée à l'heure exacte où le monde a basculé.",
      _c("La remettre à l'heure", fx: {Stat.moral: 5}, result: "Le temps reprend, pour toi au moins."),
      _c("La laisser arrêtée", fx: {Stat.moral: -3}, result: "Qu'il reste arrêté.")),
  _filler('F1_faim',
      "La faim te tord le ventre pour de bon, pour la première fois.",
      _c("Serrer les dents", fx: {Stat.moral: 2}, result: "La faim, ça se dompte. Un peu."),
      _c("Te rappeler les repas d'avant", fx: {Stat.moral: -3}, result: "L'odeur du riz, les rires. Ça serre plus.")),
  _filler('F1_etoile',
      "Une étoile filante raye le ciel enfumé, improbable.",
      _c("Faire un vœu", fx: {Stat.moral: 6}, result: "« Faites qu'ils soient vivants. »"),
      _c("Ne plus croire aux vœux", fx: {Stat.moral: -2}, result: "Les vœux n'ont sauvé personne.")),
];

final List<StoryCard> _fill2 = [
  _filler('F2_graffiti',
      "Sur une paroi de béton, une phrase peinte en rouge : « ILS MENTENT SUR LE NORD. »",
      _c("Refuser d'y croire", fx: {Stat.moral: 4}, result: "Quelqu'un de désespéré, voilà tout. Tu choisis ton espoir."),
      _c("Laisser le doute entrer", fx: {Stat.moral: -5}, result: "Et si tout ça n'était qu'une rumeur ?"),
      oneshot: true),
  _filler('F2_journal',
      "Le journal de bord d'un ancien conducteur. Pages d'itinéraires, puis d'angoisse, puis plus rien.",
      _c("Le lire jusqu'au bout", fx: {Stat.moral: -4}, result: "Il a tenu trois semaines, seul. Puis ça s'arrête net."),
      _c("Le garder pour le feu", fx: {Stat.bois: 3, Stat.moral: -2}, result: "Ses mots chaufferont quelques minutes. Pardon, l'ami."),
      oneshot: true),
  _filler('F2_silhouettes',
      "Brouillard épais. Des silhouettes immobiles, debout entre les rails, te regardent passer sans bouger.",
      _c("Éteindre la lampe", fx: {Stat.moral: -3}, result: "Elles disparaissent dans ton dos."),
      _c("Soutenir leur regard", fx: {Stat.moral: 3}, result: "Elles ne te feront pas baisser les yeux.")),
  _filler('F2_tunnel',
      "Un tunnel long, noir absolu. Le train s'y enfonce.",
      _c("Allumer la lampe", fx: {Stat.moral: 3}, result: "La petite flamme repousse les murs."),
      _c("Traverser dans le noir", fx: {Stat.moral: -5}, result: "Le noir total, le grondement, l'éternité. Puis la lumière.")),
  _filler('F2_aiguillage',
      "Un poste d'aiguillage. Deux voies : celle que tu connais, et une plus directe vers le nord, inconnue.",
      _c("La voie connue", fx: {Stat.moral: 2}, result: "Le diable que tu connais."),
      _c("La voie inconnue", fx: {Stat.bois: 6, Stat.moral: -3}, result: "Un raccourci risqué, mais tu gagnes du chemin.")),
  _filler('F2_sifflet',
      "Le sifflet de la loco résonne dans la vallée morte, long, plaintif.",
      _c("Le laisser chanter", fx: {Stat.moral: 4}, result: "Une voix dans le silence, même celle d'une machine."),
      _c("Le couper, prudente", fx: {Stat.moral: -2}, result: "Mieux vaut ne pas s'annoncer.")),
];

final List<StoryCard> _fill3 = [
  _filler('F3_piano',
      "Un piano à queue, incongru, abandonné sur un quai, couvert de poussière.",
      _c("Jouer une note", fx: {Stat.moral: 6}, result: "Une note pure qui flotte longtemps. La beauté existe encore."),
      _c("Passer ton chemin", fx: {Stat.moral: 1}, result: "Tu n'as plus de musique en toi. Pas aujourd'hui."),
      oneshot: true),
  _filler('F3_livre',
      "Sur la banquette, un livre d'images pour enfants, gondolé : une histoire de renard et de lune.",
      _c("Le lire à voix haute", fx: {Stat.moral: 6}, result: "Tu lisais ça à ta sœur."),
      _c("Le serrer sans l'ouvrir", fx: {Stat.moral: 3}, result: "Trop de souvenirs dans ces pages.")),
  _filler('F3_pluie',
      "La pluie cendrée tambourine sur le toit. L'eau dévale les vitres en traînées grises.",
      _c("Coller ton front à la vitre", fx: {Stat.moral: 3}, result: "Le verre est glacé, le bruit hypnotique."),
      _c("T'éloigner du froid", fx: {Stat.moral: 1}, result: "Tu te recroquevilles au centre, au sec.")),
  _filler('F3_voitures',
      "Le train longe un cimetière de voitures empilées, figées dans leur dernière fuite.",
      _c("Imaginer leurs histoires", fx: {Stat.moral: -3}, result: "Des familles, des départs. Immobile à jamais."),
      _c("Ne voir que de la ferraille", fx: {Stat.moral: 2}, result: "Du métal mort. Tu refuses de pleurer chaque épave.")),
  _filler('F3_arcenciel',
      "La pluie cesse. Un arc-en-ciel pâle se dessine sur le ciel de cendre.",
      _c("Y voir un espoir", fx: {Stat.moral: 5}, result: "Même ici, même maintenant. Un signe."),
      _c("N'y voir qu'une illusion", fx: {Stat.moral: -2}, result: "Juste de la lumière dans des gouttes.")),
  _filler('F3_pont',
      "Un vieux pont ferroviaire craque sous le poids du convoi, métal fatigué.",
      _c("Ralentir, prudente", fx: {Stat.moral: -3}, result: "Le pont gémit, mais tient."),
      _c("Passer vite avant qu'il cède", fx: {Stat.bois: -6}, result: "Derrière toi, une poutre cède dans le vide.")),
];

final List<StoryCard> _fill4 = [
  _filler('F4_chanson',
      "La radio capte, miraculeusement, une vieille chanson d'amour, intacte.",
      _c("Écouter, danser seule", fx: {Stat.moral: 7}, result: "Tu tournes lentement dans le wagon, les yeux fermés. Vivante."),
      _c("Éteindre, trop douloureux", fx: {Stat.moral: -4}, result: "Cette chanson, c'était la leur."),
      oneshot: true, requires: (f) => f.contains('aLaRadio')),
  _filler('F4_maria',
      "Sur un mur : « MARIA — SI TU LIS ÇA — RENDEZ-VOUS AU NORD. JE T'ATTENDS. »",
      _c("Imaginer Maria les retrouvant", fx: {Stat.moral: 5}, result: "Quelqu'un attend quelqu'un. Ça suffit à y croire."),
      _c("Penser aux tiens", fx: {Stat.moral: -4}, result: "Et toi, qui t'attend ?"),
      oneshot: true),
  _filler('F4_cerfs',
      "Un troupeau de cerfs efflanqués traverse la voie, juste devant la loco.",
      _c("Freiner pour les épargner", fx: {Stat.bois: -5, Stat.moral: 7}, result: "L'un d'eux te regarde, longtemps. De la vie, encore."),
      _c("Ne pas ralentir", fx: {Stat.faim: 8, Stat.moral: -6}, result: "Un choc sourd. De la viande, et un goût de cendre.")),
  _filler('F4_eoliennes',
      "Un champ d'éoliennes immobiles, géants blancs endormis dans la brume.",
      _c("Les trouver majestueuses", fx: {Stat.moral: 4}, result: "Des sentinelles patientes."),
      _c("Les trouver sinistres", fx: {Stat.moral: -3}, result: "Des cadavres de fer, bras figés.")),
  _filler('F4_reflet',
      "Une vitre intacte te renvoie ton reflet. Tu te reconnais à peine : maigre, dure, les yeux d'une autre.",
      _c("Sourire à cette inconnue", fx: {Stat.moral: 6}, result: "« On tient bon, toi et moi. »"),
      _c("Te détourner", fx: {Stat.moral: -5}, result: "Tu ne veux pas voir ce que le voyage fait de toi.")),
  _filler('F4_ville',
      "Une ville plus grande au loin, silencieuse, étrangement intacte.",
      _c("S'arrêter explorer", fx: {Stat.faim: 8, Stat.moral: -5}, result: "Des vivres — et des traces récentes qui te glacent."),
      _c("Se méfier, passer", fx: {Stat.moral: 2}, result: "Trop calme. Trop intacte. Tu files.")),
];

final List<StoryCard> _fill5 = [
  _filler('F5_trainvide',
      "Un autre train croise le tien, en sens inverse. Vide. Toutes portes ouvertes. Pas une âme.",
      _c("Te demander ce qui s'est passé", fx: {Stat.moral: -4}, result: "Où sont passés ses passagers ?"),
      _c("Y voir un présage", fx: {Stat.moral: -6}, result: "Est-ce ton train, dans quelques jours ?"),
      oneshot: true),
  _filler('F5_carnet',
      "Tu trouves un carnet de croquis et un crayon dans un casier.",
      _c("Dessiner les visages des tiens", fx: {Stat.moral: 9}, result: "Tant que tu peux les dessiner, tu ne les as pas perdus."),
      _c("Le ranger, trop dur", fx: {Stat.moral: -2}, result: "Pas prête à les regarder en face."),
      oneshot: true),
  _filler('F5_enfantsigne',
      "Au loin, un petit camp. Un enfant grimpé sur un toit te fait de grands signes des deux bras.",
      _c("Lui répondre", fx: {Stat.moral: 7}, result: "Tu agites le bras jusqu'à perte de vue. Un lien d'une seconde, réel."),
      _c("Te contenter de le regarder", fx: {Stat.moral: 2}, result: "Tu penses à ta sœur, à cet âge.")),
  _filler('F5_graines',
      "Dans un tiroir, un sachet de graines potagères, encore viables.",
      _c("Les garder précieusement", fx: {Stat.faim: 4, Stat.moral: 3}, result: "De quoi cultiver plus tard."),
      _c("En semer le long de la voie", fx: {Stat.moral: 6}, result: "Pour ceux qui passeront après.")),
  _filler('F5_cimetiere',
      "Un cimetière immense longe la voie, croix à perte de vue sous la cendre.",
      _c("Te recueillir un instant", fx: {Stat.moral: -2}, result: "Tu inclines la tête pour ces inconnus."),
      _c("Détourner les yeux", fx: {Stat.moral: -4}, result: "Trop de morts. Tu fixes l'avant de la voie.")),
  _filler('F5_doute',
      "La grande question revient, lancinante : et si le nord n'existait pas ?",
      _c("La repousser fermement", fx: {Stat.moral: 5}, result: "« Il existe. Je le verrai. »"),
      _c("T'y enfoncer un moment", fx: {Stat.moral: -6}, result: "Un mensonge collectif pour tenir debout ?")),
];

final List<StoryCard> _fill6 = [
  _filler('F6_berceuse',
      "Souvenir : ta sœur, terrifiée par le noir, et toi qui lui chantais une berceuse jusqu'à ce qu'elle s'endorme.",
      _c("Chanter cette berceuse maintenant", fx: {Stat.moral: 8}, result: "Ta voix tremble dans le wagon glacé. Tu chantes pour deux."),
      _c("Ravaler tes larmes", fx: {Stat.moral: -4}, result: "Chanter, ce serait t'effondrer."),
      oneshot: true),
  _filler('F6_luge',
      "Une luge d'enfant abandonnée dans la neige, peinture écaillée.",
      _c("Sourire au souvenir", fx: {Stat.moral: 4}, result: "Les descentes avec ta sœur, ses cris de joie."),
      _c("Sentir la mélancolie", fx: {Stat.moral: -3}, result: "À quel enfant était-elle ?")),
  _filler('F6_givre',
      "Les premières fougères de givre se dessinent sur les vitres, fines comme de la dentelle.",
      _c("T'émerveiller", fx: {Stat.moral: 5}, result: "Le monde meurt, mais il sait encore être beau."),
      _c("Y lire une menace", fx: {Stat.moral: -3}, result: "Le froid arrive. Et le froid, ici, ça tue.")),
  _filler('F6_loups',
      "Une meute de loups suit le train à distance, ombres grises bondissant dans la neige sale.",
      _c("Les admirer courir", fx: {Stat.moral: 4}, result: "Libres, sauvages, vivants. Tu les envies presque."),
      _c("Surveiller la porte", fx: {Stat.moral: -2}, result: "La faim rend tout dangereux.")),
  _filler('F6_village',
      "Un village de montagne, lumières éteintes — mais une cheminée fume faiblement.",
      _c("Aller vérifier", fx: {Stat.faim: 6, Stat.moral: -4}, result: "Une vieille femme te donne du pain, puis te chasse."),
      _c("Ne pas prendre le risque", fx: {Stat.moral: 2}, result: "Une cheminée qui fume veut dire quelqu'un. Risqué.")),
  _filler('F6_manteau',
      "Tu trouves un épais manteau de laine dans une malle, à ta taille presque.",
      _c("L'enfiler", fx: {Stat.moral: 6}, result: "Enveloppée de chaleur, un peu protégée du monde."),
      _c("Le garder en réserve", fx: {Stat.moral: 2}, result: "Pour plus froid encore.")),
];

final List<StoryCard> _fill7 = [
  _filler('F7_corps',
      "Un corps gelé est assis contre un poteau, paisible, serrant une photo contre sa poitrine.",
      _c("Regarder la photo", fx: {Stat.moral: -5}, result: "Il est mort en les regardant."),
      _c("Le laisser en paix", fx: {Stat.moral: 3}, result: "Tu inclines la tête. Repose-toi."),
      oneshot: true),
  _filler('F7_aurores',
      "La nuit, les aurores boréales s'allument : voiles verts ondulant sur le ciel noir.",
      _c("Les partager (chien/vide)", fx: {Stat.moral: 6}, result: "Un émerveillement. Tu voudrais montrer ça à quelqu'un."),
      _c("Les garder pour toi seule", fx: {Stat.moral: 5}, result: "Un cadeau rien que pour toi, dans l'immensité."),
      oneshot: true),
  _filler('F7_refuge',
      "Un refuge de montagne, porte battante. Lits faits, table mise — et personne, depuis longtemps.",
      _c("Y dormir une nuit", fx: {Stat.moral: 6}, result: "Un vrai lit, un vrai toit. Tu rêves de chez toi."),
      _c("Prendre et partir", fx: {Stat.faim: 5, Stat.moral: -2}, result: "Tu rafles ce qui reste et tu files.")),
  _filler('F7_rennes',
      "Des rennes sauvages grattent la neige pour trouver du lichen, paisibles.",
      _c("Les observer longtemps", fx: {Stat.moral: 5}, result: "La vie s'accroche, têtue, même ici."),
      _c("Y penser comme à du gibier", fx: {Stat.faim: 6, Stat.moral: -4}, result: "La faim parle plus fort que la beauté.")),
  _filler('F7_nuit',
      "La nuit tombe à quatre heures, désormais. Les jours rétrécissent.",
      _c("T'adapter, accepter", fx: {Stat.moral: 3}, result: "Tu y trouves un rythme."),
      _c("Le vivre comme une menace", fx: {Stat.moral: -4}, result: "Comme si le monde s'éteignait pour de bon.")),
  _filler('F7_voix',
      "Tu réalises que tu n'as pas entendu ta propre voix depuis des jours.",
      _c("Te mettre à chanter", fx: {Stat.moral: 5}, result: "Ta voix résonne, rauque, vivante. Tu existes."),
      _c("Rester dans le silence", fx: {Stat.moral: -3}, result: "Le silence t'a avalée.")),
];

final List<StoryCard> _fill8 = [
  _filler('F8_dirigeable',
      "Une carcasse émerge de la neige comme un monstre — un dirigeable abattu.",
      _c("T'en approcher", fx: {Stat.faim: 5, Stat.moral: 2}, result: "Dans la nacelle, des rations militaires intactes. Aubaine."),
      _c("La contourner", fx: {Stat.moral: -2}, result: "Qui sait ce qui se cache là-dedans."),
      oneshot: true),
  _filler('F8_boite',
      "Une boîte à musique dans un tiroir. La mélodie s'élève, fragile, dans le froid.",
      _c("La laisser jouer jusqu'au bout", fx: {Stat.moral: 6}, result: "Tu n'oses plus bouger."),
      _c("L'arrêter, trop triste", fx: {Stat.moral: -3}, result: "Le silence revient, plus lourd qu'avant."),
      oneshot: true),
  _filler('F8_lunaire',
      "Le paysage devient lunaire : étendue blanche infinie, sans le moindre repère.",
      _c("Y trouver une paix étrange", fx: {Stat.moral: 4}, result: "Le vide te lave la tête."),
      _c("T'y sentir minuscule", fx: {Stat.moral: -4}, result: "Un grain de poussière sur une page blanche.")),
  _filler('F8_buee',
      "Tu dessines machinalement sur la vitre embuée : ta famille, au complet.",
      _c("Compléter le dessin", fx: {Stat.moral: 5}, result: "Un chien, un soleil. Une famille de buée."),
      _c("L'effacer, trop dur", fx: {Stat.moral: -3}, result: "D'un revers de main, tout disparaît.")),
  _filler('F8_tempete',
      "Le vent forcit. À l'horizon, le ciel noircit d'un coup : la tempête arrive.",
      _c("L'affronter de face", fx: {Stat.moral: 3}, result: "« Viens. On verra qui plie. »"),
      _c("La redouter en silence", fx: {Stat.moral: -3}, result: "Tu as appris à craindre le ciel.")),
];

final List<StoryCard> _fill9 = [
  _filler('F9_cristal',
      "Le givre a transformé une forêt entière en sculptures de cristal.",
      _c("Traverser émerveillée", fx: {Stat.moral: 6}, result: "Une cathédrale de glace rien que pour toi."),
      _c("Presser le pas", fx: {Stat.moral: -2}, result: "Trop beau, trop silencieux. Ça ne dit rien qui vaille."),
      oneshot: true),
  _filler('F9_traineau',
      "Tu trouves un traîneau et un harnais.",
      _c("Imaginer une vie d'après", fx: {Stat.moral: 5}, result: "Toi, un attelage, une cabane au nord. Le rêve réchauffe."),
      _c("Rester focalisée sur le train", fx: {Stat.moral: 2}, result: "Le train d'abord. Les rêves, après le tunnel.")),
  _filler('F9_aurore2',
      "Une aurore exceptionnelle embrase tout le ciel de rouge et de vert.",
      _c("T'arrêter pour la contempler", fx: {Stat.bois: -4, Stat.moral: 7}, result: "Le silence et le ciel en feu. Inoubliable."),
      _c("Rouler en la regardant", fx: {Stat.moral: 4}, result: "Le ciel dansant dans le pare-brise givré.")),
  _filler('F9_ours',
      "Des empreintes immenses dans la neige, comme celles d'un ours blanc.",
      _c("Redoubler de prudence", fx: {Stat.moral: -2}, result: "Tu verrouilles tout."),
      _c("Les suivre par curiosité", fx: {Stat.faim: 4, Stat.moral: -3}, result: "Une carcasse à demi dévorée. Tu prélèves, vite.")),
  _filler('F9_lac',
      "Un lac gelé, immense miroir, renvoie le ciel à l'envers. Le train semble rouler dans les nuages.",
      _c("Te perdre dans cette image", fx: {Stat.moral: 6}, result: "Plus de différence. Juste de la beauté."),
      _c("Y voir un présage fragile", fx: {Stat.moral: 2}, result: "La glace est mince. Comme ton espoir.")),
];

final List<StoryCard> _fill10 = [
  _filler('F10_bain',
      "Un bain. De l'eau chaude de source, fumante. Un luxe oublié.",
      _c("T'y plonger longuement", fx: {Stat.moral: 8}, result: "La chaleur te dénoue. Tu pleures de soulagement."),
      _c("Te laver vite", fx: {Stat.moral: 3}, result: "Propre, déjà, c'est énorme."),
      oneshot: true),
  _filler('F10_arme',
      "Dans un casier scellé, une arme — un vieux fusil de chasse et trois cartouches.",
      _c("La prendre", fx: {Stat.moral: -4}, flags: ['aArme'], result: "Le poids du métal te rassure et te dégoûte."),
      _c("La laisser", fx: {Stat.moral: 4}, result: "Si tu dois survivre, ce ne sera pas comme ça."),
      oneshot: true),
  _filler('F10_fruits',
      "La serre regorge de fruits mûrs. Une abondance presque indécente.",
      _c("T'en gorger", fx: {Stat.faim: 10, Stat.moral: 5}, result: "Le pur bonheur d'avoir assez."),
      _c("Rationner par habitude", fx: {Stat.faim: 5, Stat.moral: -2}, result: "La peur du manque ne te quitte pas.")),
  _filler('F10_chambre',
      "Un coin de la serre aménagé en chambre par un occupant précédent. Photos, livres, une vie suspendue.",
      _c("Ne rien toucher", fx: {Stat.moral: 4}, result: "Une trace d'humanité à préserver."),
      _c("Fouiller, par nécessité", fx: {Stat.soif: 5, Stat.moral: -3}, result: "Utile, mais tu te sens voleuse.")),
  _filler('F10_etoiles',
      "Le ciel se déploie, immense, constellé.",
      _c("Compter les étoiles comme avant", fx: {Stat.moral: 6}, result: "La Grande Ourse. Ta sœur disait qu'elle ramène à la maison."),
      _c("Dormir, rassembler tes forces", fx: {Stat.moral: 3}, result: "Demain sera rude.")),
];

final List<StoryCard> _fill11 = [
  _filler('F11_englouti',
      "La voie traverse un lac gelé. Sous la glace transparente, une ville engloutie.",
      _c("Contempler ce monde noyé", fx: {Stat.moral: -3}, result: "Des toits, des rues, des lampadaires, figés sous tes roues."),
      _c("Presser pour quitter la glace", fx: {Stat.bois: -5}, result: "La glace craque sous le poids."),
      oneshot: true),
  _filler('F11_draisine',
      "Une draisine à bras, abandonnée. Quelqu'un a tenté le nord à la force des bras.",
      _c("Espérer qu'il a réussi", fx: {Stat.moral: 4}, result: "Si lui a pu, à mains nues, alors toi avec un train..."),
      _c("Craindre le pire", fx: {Stat.moral: -3}, result: "Abandonnée en pleine voie. Il n'est pas allé loin.")),
  _filler('F11_aurore3',
      "La nuit polaire, immense, et les aurores qui reviennent danser.",
      _c("Les contempler longtemps", fx: {Stat.moral: 8}, result: "Le monde te fait un cadeau."),
      _c("Dormir enfin", fx: {Stat.moral: 4}, result: "Un sommeil profond, mérité.")),
  _filler('F11_statue',
      "Une statue à demi ensevelie : un soldat de pierre, bras tendu vers le nord, comme un guide.",
      _c("Y voir un signe", fx: {Stat.moral: 4}, result: "« Par là. » Même la pierre te dit de continuer."),
      _c("Un vestige inutile", fx: {Stat.moral: -2}, result: "Un monument à un monde qui n'a pas su se sauver.")),
  _filler('F11_air',
      "L'air se fait si pur et si froid que chaque respiration pique et réveille.",
      _c("Respirer à pleins poumons", fx: {Stat.moral: 5}, result: "Glacée jusqu'aux os, mais terriblement vivante."),
      _c("Te couvrir le visage", fx: {Stat.moral: 1}, result: "Le nord ne pardonne pas l'imprudence.")),
];

final List<StoryCard> _fill12 = [
  _filler('F12_autel',
      "Un petit autel laissé par d'autres voyageurs : photos, jouets, mots d'adieu sous des pierres.",
      _c("Y laisser un objet à toi", fx: {Stat.moral: 6}, result: "Qu'ils reposent là, au seuil du refuge."),
      _c("Te recueillir et partir", fx: {Stat.moral: 3}, result: "Un instant de silence pour ceux qui n'arriveront pas."),
      oneshot: true),
  _filler('F12_carcasses',
      "Dans le col, des carcasses d'autres trains, figées, ensevelies. Ils n'ont pas passé l'hiver.",
      _c("Te jurer de réussir", fx: {Stat.moral: 5}, result: "« Pas moi. Pas nous. Pas si près. »"),
      _c("Sentir la peur t'envahir", fx: {Stat.moral: -6}, result: "Et si c'était ça, ton train, demain ?"),
      oneshot: true),
  _filler('F12_loco',
      "Tu écoutes le cœur de la loco : un battement irrégulier, inquiétant.",
      _c("La rassurer, lui parler", fx: {Stat.moral: 4}, result: "« Tiens bon, ma belle. On y est presque. »"),
      _c("Juste serrer les dents", fx: {Stat.moral: -2}, result: "Plus de mots à gaspiller. Que de la volonté.")),
  _filler('F12_croix',
      "Une croix de pierre fleurie de fleurs gelées encore fraîches. Quelqu'un est passé récemment.",
      _c("Y voir une présence proche", fx: {Stat.moral: 5}, result: "Des vivants, tout près. Tu n'es pas seule."),
      _c("Y voir une tombe de plus", fx: {Stat.moral: -3}, result: "On meurt encore, si près du but.")),
  _filler('F12_vagues',
      "Le vent sculpte la neige en vagues figées, un océan blanc immobile.",
      _c("Y naviguer en pensée", fx: {Stat.moral: 4}, result: "Ton train est un navire, le nord ton port."),
      _c("T'y sentir naufragée", fx: {Stat.moral: -3}, result: "Perdue en mer blanche, sans rivage en vue.")),
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
