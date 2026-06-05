// Contenu narratif du mode cartes (porté depuis docs/train_cosy_*.twee).
//
// Source de vérité narrative = les fichiers Twine dans docs/. Ici c'est la
// version "jouable" : 14 gares (avec variantes selon flags) + un paquet de
// remplissage par segment, taggé repeatable / oneshot pour le tirage.
//
// Flags utilisés : aLeChien, leVieuxABord, aAideFuyard, aLaRadio, aLEnfant
// + compteur radioSuivie via flag "radio1/2/3" (on cumule).

import '../models/game_state.dart';
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
// LES 14 GARES (piliers narratifs) — ARC PETITE SŒUR
// 1→4 : la fuite, Shen seule, un espoir qu'elle refoule.
// 5    : RETROUVAILLES surprise avec la petite sœur (flag aLaSoeur).
// 6→14 : la protéger (2 bouches : faim/soif plus dures, moral soutenu)
//        et tenir jusqu'au refuge nord OÙ LES PARENTS ATTENDENT.
// ============================================================

List<StoryCard> _gare1(Set<String> f) => [
      StoryCard(
        id: 'G1',
        kind: CardKind.gare,
        speaker: 'Gare natale',
        text:
            "La locomotive s'ébranle. Par la porte du wagon, ta ville natale s'embrase — le quai, la foule, les autres trains qui ne partiront jamais. Quelque part là-dedans, tes parents et ta petite sœur.",
        left: _c("Regarder jusqu'au bout",
            fx: {Stat.moral: -6},
            result: "Tu fixes les flammes jusqu'à ce que la fumée avale tout. Tu n'oublieras pas. Jamais."),
        right: _c("Fermer la porte",
            fx: {Stat.moral: 3},
            result: "Tu claques la porte sur le brasier. Survivre d'abord. Pleurer plus tard."),
      ),
      StoryCard(
        id: 'G1b',
        kind: CardKind.gare,
        speaker: 'Gare natale',
        text:
            "Le train n'a pas encore pris sa vitesse. Sous un banc renversé du wagon, deux yeux brillent : un chiot tremblant, oublié là, seul comme toi.",
        left: _c("Le recueillir",
            fx: {Stat.moral: 15}, flags: ['aLeChien'],
            result: "Il se glisse contre ta jambe et s'endort aussitôt. Le wagon paraît moins vide. Tu n'es plus tout à fait seule."),
        right: _c("Tu ne pourras pas le nourrir",
            fx: {Stat.moral: -5},
            result: "Tu détournes les yeux. Une bouche de plus, c'est non. Le silence, après, est immense."),
      ),
      StoryCard(
        id: 'G1c',
        kind: CardKind.gare,
        speaker: 'Gare natale',
        text:
            "La nuit tombe sur un monde noir. Tu revois la cohue : tes parents qui te poussaient en avant, la main de ta sœur arrachée à la tienne. Tu n'as vu personne tomber — mais personne s'en sortir non plus.",
        left: _c("Te jurer de les retrouver",
            fx: {Stat.moral: 10},
            result: "Tu serres les poings. Tant qu'il n'y a pas de preuve, tu choisis d'espérer. C'est ça qui te fera avancer."),
        right: _c("Te préparer au pire",
            fx: {Stat.moral: -8, Stat.faim: 4},
            result: "Tu enterres l'espoir avant qu'il ne te brise. Tu avanceras quand même. Autrement."),
      ),
    ];

List<StoryCard> _gare2(Set<String> f) => [
      StoryCard(
        id: 'G2',
        kind: CardKind.gare,
        speaker: 'Dépôt de fret',
        text:
            "Au dépôt de fret, le foyer de la loco agonise. Tu ne sais pas la nourrir — trop de bois l'étouffe, trop peu l'éteint. Un manuel graisseux traîne dans la cabine.",
        left: _c("Déchiffrer le manuel, page à page",
            fx: {Stat.bois: 18, Stat.faim: -4},
            result: "Des heures penchée sur les schémas, l'estomac vide. Mais le feu reprend, franc et vif. Tu sauras faire, maintenant."),
        right: _c("Y aller à l'instinct",
            fx: {Stat.bois: 6, Stat.moral: -3},
            result: "Tu charges au jugé. Le feu crachote, capricieux. Tu apprendras dans la fumée et les jurons."),
      ),
      StoryCard(
        id: 'G2b',
        kind: CardKind.gare,
        speaker: 'Le Vieux',
        text:
            "Une silhouette voûtée se hisse dans la cabine : un vieux cheminot, mains noires de suie, regard vif. « Cette loco, je l'ai conduite trente ans, petite. Embarque-moi, et je t'apprends à la garder vivante. »",
        left: _c("L'accueillir à bord",
            fx: {Stat.bois: 10, Stat.faim: -3}, flags: ['leVieuxABord'],
            result: "Il pose son sac, tapote la chaudière comme une vieille amie. Une bouche de plus — mais des mains qui savent. « On va l'emmener loin, ta machine. »"),
        right: _c("Continuer seule",
            fx: {Stat.moral: -5},
            result: "Tu secoues la tête. Dehors, tu ne sais plus à qui te fier. Il descend sans un mot, et la voie t'avale, seule à la barre."),
      ),
    ];

List<StoryCard> _gare3(Set<String> f) => [
      StoryCard(
        id: 'G3',
        kind: CardKind.gare,
        speaker: 'Halte 47',
        text:
            "Halte 47, noyée dans un brouillard épais. Des formes bougent entre les wagons rouillés — des pillards, qui fouillent les morts. Ils n'ont pas encore vu ta loco.",
        left: _c("Couper les feux, passer en fantôme",
            fx: {Stat.bois: -6, Stat.moral: -4},
            result: "Tu éteins tout et tu pousses doucement dans la brume, le cœur au bord des lèvres. Ils ne te verront pas — mais rouler si lentement fait fondre le bois."),
        right: _c("Accélérer pour les semer",
            fx: {Stat.bois: -10, Stat.moral: 3},
            result: "Tu ouvres les gaz. Un cri, des pas qui courent, une pierre contre la tôle — puis le brouillard les avale. Passé."),
      ),
      StoryCard(
        id: 'G3b',
        kind: CardKind.gare,
        speaker: 'Halte 47',
        text:
            "Sur le quai défilant, un foulard d'enfant accroché à un clou claque au vent. Rouge à pois blancs. Le même que celui de ta petite sœur. À s'y méprendre.",
        left: _c("Risquer tout pour l'attraper",
            fx: {Stat.faim: -8, Stat.moral: 12}, flags: ['indiceSoeur'],
            result: "Tu te faufiles dehors, le cœur cognant. C'est le sien — tu en mettrais ta main au feu. Elle est passée par là. Elle est vivante."),
        right: _c("Ne pas risquer ta peau pour un bout de tissu",
            fx: {Stat.moral: -8},
            result: "Tu restes à bord. Mais le doute te ronge : et si c'était elle qui l'avait laissé là — un signe, pour toi ?"),
      ),
    ];

List<StoryCard> _gare4(Set<String> f) => [
      StoryCard(
        id: 'G4',
        kind: CardKind.gare,
        speaker: 'Village fantôme',
        text:
            "Un mur couvert de messages de disparus. Au milieu, une écriture maladroite d'enfant : « JE VAIS AU NORD. JE T'ATTENDS. » Pas de nom.",
        left: _c("Y croire, foncer au nord",
            fx: {Stat.moral: 14, Stat.bois: -8}, flags: ['indiceSoeur'], result: "Tu graves sa réponse à côté et tu pousses la loco. Si c'est elle, elle ne t'attendra pas en vain."),
        right: _c("Rester méfiante",
            fx: {Stat.moral: -4}, result: "Des milliers d'enfants ont écrit ça. Tu n'oses pas y croire. Pas encore."),
      ),
    ];

List<StoryCard> _gare5(Set<String> f) => [
      StoryCard(
        id: 'G5',
        kind: CardKind.gare,
        speaker: 'Pont sur le fleuve',
        text:
            "Une silhouette menue, recroquevillée au milieu du pont, te barre la route. Elle lève la tête à la lumière de la loco. Tu cesses de respirer. C'est elle. C'est ta petite sœur.",
        left: _c("Courir la serrer dans tes bras",
            fx: {Stat.moral: 40}, flags: ['aLaSoeur'], result: "Tu sautes du train, tu la soulèves, vous pleurez. Le monde mort, un instant, n'existe plus. Elle monte avec toi."),
        right: _c("Courir la serrer dans tes bras",
            fx: {Stat.moral: 40}, flags: ['aLaSoeur'], result: "Tu sautes du train, tu la soulèves, vous pleurez. Le monde mort, un instant, n'existe plus. Elle monte avec toi."),
      ),
      StoryCard(
        id: 'G5b',
        kind: CardKind.gare,
        speaker: 'Ta sœur',
        text:
            "« Papa et maman... ils sont partis devant. Vers le nord, un refuge. Ils m'ont dit de les attendre, que quelqu'un viendrait. » Ses yeux brillent. « Je savais que ce serait toi. »",
        left: _c("Lui promettre de les retrouver",
            fx: {Stat.moral: 12}, flags: ['capParents'], result: "« On va les retrouver. Tous les deux. » Tu y crois, maintenant. Tu as une raison."),
        right: _c("Rester prudente devant elle",
            fx: {Stat.moral: 4}, flags: ['capParents'], result: "Tu hoches la tête sans promettre. Mais au fond, le cap est fixé : le nord, les parents."),
      ),
    ];

List<StoryCard> _gare6(Set<String> f) => [
      StoryCard(
        id: 'G6',
        kind: CardKind.gare,
        speaker: 'Camp-refuge',
        text:
            "Un camp de survivants. On peut troquer, mais ils regardent ta sœur avec trop d'intérêt — ici, un enfant en bonne santé, ça se monnaie.",
        left: _c("Troquer vite et partir",
            fx: {Stat.faim: 12, Stat.soif: 8, Stat.moral: -6}, result: "Tu obtiens des vivres mais tu sens leurs regards. Tu repars avant la nuit, elle serrée contre toi."),
        right: _c("Ne pas t'attarder une seconde",
            fx: {Stat.moral: 6, Stat.faim: -5}, result: "Tu refuses tout contact. Le ventre vide, mais ta sœur en sécurité. C'est tout ce qui compte."),
      ),
    ];

List<StoryCard> _gare7(Set<String> f) => [
      StoryCard(
        id: 'G7',
        kind: CardKind.gare,
        speaker: 'Halte 12',
        text:
            "Cette halte, vous y veniez enfant, toutes les deux, regarder les trains. Ta sœur la reconnaît et sourit pour la première fois depuis la fuite.",
        left: _c("Lui raconter ce souvenir",
            fx: {Stat.moral: 16, Stat.bois: -5}, result: "Vous riez ensemble dans le wagon arrêté. Un moment volé, qui coûte un peu de route, mais qui vous répare."),
        right: _c("Garder le cap, ne pas t'arrêter",
            fx: {Stat.moral: 4}, result: "Tu serres les dents et tu avances. Le nord d'abord. Les souvenirs, après."),
      ),
    ];

List<StoryCard> _gare8(Set<String> f) => [
      StoryCard(
        id: 'G8',
        kind: CardKind.gare,
        speaker: 'Entrée zone froide',
        text:
            "Le froid mord pour de bon. Ta sœur grelotte, ses lèvres bleuissent. Elle n'a pas de vrai manteau.",
        left: _c("Lui donner le tien",
            fx: {Stat.moral: 14, Stat.soif: -6}, flags: ['soeurProtegee'], result: "Tu grelottes à sa place. Elle s'endort contre toi, au chaud. Tu ne regrettes rien."),
        right: _c("Pousser le feu à fond",
            fx: {Stat.bois: -16, Stat.moral: 6}, result: "Tu sacrifies ta réserve de bois pour la réchauffer. Le wagon est un four, pour l'instant."),
      ),
    ];

List<StoryCard> _gare9(Set<String> f) => [
      StoryCard(
        id: 'G9',
        kind: CardKind.gare,
        speaker: 'Plaine enneigée',
        text:
            "Le blizzard enferme le train. Ta sœur brûle de fièvre, délire, t'appelle dans son sommeil agité. Tu n'as presque plus rien.",
        left: _c("La veiller toute la nuit",
            fx: {Stat.faim: -10, Stat.moral: 12}, flags: ['soeurProtegee'], result: "Tu ne dors pas, tu éponges son front jusqu'à l'aube. La fièvre cède. Elle vivra."),
        right: _c("Braver la tempête pour des remèdes",
            fx: {Stat.soif: -12, Stat.moral: 8}, flags: ['soeurProtegee'], result: "Tu sors dans le blizzard, tu reviens gelée avec des cachets périmés. Ça suffit. De justesse."),
      ),
    ];

List<StoryCard> _gare10(Set<String> f) => [
      StoryCard(
        id: 'G10',
        kind: CardKind.gare,
        speaker: 'Oasis perdue',
        text:
            "Une serre intacte, chaude, verdoyante. Ta sœur court entre les plants en riant. Un répit irréel. On pourrait... rester ici ?",
        left: _c("S'accorder un vrai repos",
            fx: {Stat.faim: 20, Stat.soif: 16, Stat.moral: 18},
            flags: ['asset_hydro'],
            result: "Quelques jours de chaleur et de rires. Vous reprenez des forces et de l'âme. Avant de partir, vous démontez de quoi monter une petite tour hydroponique dans le wagon. Puis le nord rappelle."),
        right: _c("Faire le plein et repartir vite",
            fx: {Stat.faim: 12, Stat.soif: 10, Stat.bois: 12, Stat.moral: -4},
            flags: ['asset_hydro'],
            result: "« Papa et maman attendent. » Elle comprend. Vous emportez des plants et le matériel hydroponique, et repartez le ventre plein, le cœur lourd."),
      ),
    ];

List<StoryCard> _gare11(Set<String> f) => [
      StoryCard(
        id: 'G11',
        kind: CardKind.gare,
        speaker: 'Halte 31',
        text:
            "Des pillards ont dressé un barrage sur la voie. Ils veulent le train, les vivres — et ils ont vu ta sœur.",
        left: _c("Foncer dans le barrage",
            fx: {Stat.bois: -18, Stat.moral: -6}, result: "Tu pousses la loco à fond et tu enfonces l'obstacle. Des cris, des tirs, puis le silence. Vous êtes passées, presque à sec."),
        right: _c("Négocier, donner des vivres",
            fx: {Stat.faim: -16, Stat.soif: -10, Stat.moral: 4}, result: "Tu sacrifies la moitié de vos réserves pour qu'ils vous laissent passer. Affamées, mais entières."),
      ),
    ];

List<StoryCard> _gare12(Set<String> f) => [
      StoryCard(
        id: 'G12',
        kind: CardKind.gare,
        speaker: 'Tour de guet',
        text:
            "Du haut d'une tour, vous le voyez enfin : le refuge du nord, ses cheminées qui fument. Et, plantée devant, une pancarte : « FAMILLES — REGROUPEMENT SECTEUR EST ». Ta sœur te serre la main à la broyer.",
        left: _c("Lui jurer qu'ils sont là",
            fx: {Stat.moral: 18}, result: "« Ils nous attendent. Je le sais. » Elle hoche la tête, les yeux pleins de larmes et d'espoir."),
        right: _c("Tempérer son espoir",
            fx: {Stat.moral: 6}, result: "« On verra, ma puce. On verra. » Tu ne veux pas qu'elle s'effondre si... non. N'y pense pas."),
      ),
    ];

List<StoryCard> _gare13(Set<String> f) => [
      StoryCard(
        id: 'G13',
        kind: CardKind.gare,
        speaker: 'Col gelé',
        text:
            "La loco rend l'âme dans la dernière montée, à un souffle du sommet. Plus de bois. Il faut sacrifier quelque chose, vite, avant que le froid ne vous prenne.",
        left: _c("Brûler tout le mobilier du wagon",
            fx: {Stat.bois: 28, Stat.moral: -8}, result: "La table, la couchette, vos affaires — tout au feu. Le wagon n'est plus qu'une boîte nue, mais la loco franchit le col."),
        right: _c("Descendre pousser ensemble",
            fx: {Stat.faim: -14, Stat.soif: -10, Stat.moral: 10}, result: "Vous poussez à deux, à mains nues dans la neige, en hurlant. La loco bascule de l'autre côté. Vous l'avez fait. Ensemble."),
      ),
    ];

List<StoryCard> _gare14(Set<String> f) => [
      StoryCard(
        id: 'G14',
        kind: CardKind.gare,
        speaker: 'Refuge du nord',
        text:
            "Le train entre en gare du refuge. Ta sœur écrase son visage contre la vitre. Sur le quai, la foule des familles qui cherchent les leurs. Tu descends, le cœur en feu.",
        left: _c("Chercher vos parents dans la foule",
            result: "Tu prends sa main et vous avancez dans la foule, scrutant chaque visage..."),
        right: _c("Chercher vos parents dans la foule",
            result: "Tu prends sa main et vous avancez dans la foule, scrutant chaque visage..."),
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
/// Arc sœur : si on arrive au refuge avec un bon moral et qu'on a vraiment
/// pris soin d'elle, on retrouve aussi les parents (fin pleine). Sinon, on
/// arrive éprouvés mais ensemble (fin douce-amère).
String resolveTrainCosyEnding(Map<Stat, int> stats, Set<String> flags) {
  final moral = stats[Stat.moral] ?? 0;
  final aSoeur = flags.contains('aLaSoeur');
  // Fin pleine "famille" : sœur à bord + au moins 2 vrais gestes de
  // protection + moral ÉLEVÉ (>=65). Le seuil haut rend la meilleure fin
  // *méritée* sans être automatique : par simulation, une joueuse experte
  // l'obtient ~94% du temps, une attentive ~52% (le reste bascule sur
  // "ensemble", la fin douce-amère). En-dessous (>=50) famille devenait
  // automatique et "ensemble" n'apparaissait jamais. Sinon abandon.
  final soin = GameState.instance.cardSoin;
  if (aSoeur && soin >= 2 && moral >= 65) return 'famille';
  if (aSoeur && moral >= 30) return 'ensemble';
  return 'abandon';
}

/// Textes des fins.
const Map<String, ({String title, String body})> endings = {
  'famille': (
    title: 'Réunis',
    body:
        "Dans la foule du refuge, deux silhouettes se figent, puis se précipitent : vos parents. Ta sœur leur saute au cou en sanglotant. Vous y êtes. Tous. Ensemble.\n\nTu les as ramenés. Tu as tenu, de corps et d'âme, et le monde mort n'a pas gagné.",
  ),
  'ensemble': (
    title: 'Toutes les deux',
    body:
        "Vous cherchez longtemps. Vos parents ne sont pas sur ce quai — partis ailleurs, ou jamais arrivés, tu ne sauras pas tout de suite.\n\nMais ta sœur est là, sa main dans la tienne, vivante. Vous êtes arrivées. Le reste, vous l'affronterez ensemble. C'est déjà une victoire.",
  ),
  'mort': (
    title: "Le voyage s'arrête",
    body:
        "Le train ralentit, puis se tait, au milieu du blanc. Une jauge est tombée à zéro. Le froid entre. Quelque part au nord, quelqu'un vous attend encore. Il ne le saura jamais.",
  ),
  'abandon': (
    title: "L'abandon",
    body:
        "À quoi bon. Tu n'y crois plus. À une gare sans nom, tu descends. Le train repart sans toi, et le blanc t'avale.",
  ),
};
