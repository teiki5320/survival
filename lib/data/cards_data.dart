// Contenu narratif du mode cartes (porté depuis docs/train_cosy_*.twee).
//
// Source de vérité narrative = les fichiers Twine dans docs/. Ici c'est la
// version "jouable" : 14 gares (avec variantes selon flags) + un paquet de
// remplissage par segment, taggé repeatable / oneshot pour le tirage.
//
// Flags utilisés : aLeChien (chien recueilli),
// aLaSoeur (sœur retrouvée gare 5), soeurProtegee (gestes de soin,
// compte cardSoin), capParents, indiceSoeur, aLaRadio + chaîne radio1/2/3
// (arc radio -> fin secrète), asset_bed/filter/hydro (déblocage d'objets).

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

/// Épreuve de gare (choix pur, pas de mini-jeu) : la menace de la gare devient
/// une carte à 2 choix, chacun menant DIRECTEMENT à sa conséquence (pas de
/// stat-check caché). C'est ainsi que se résolvent les beats de danger.
StoryCard _epreuve(String id, String speaker, String text,
        CardChoice left, CardChoice right) =>
    StoryCard(
        id: id, kind: CardKind.gare, speaker: speaker,
        text: text, left: left, right: right);

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
        speaker: 'Kogarashi',
        text:
            "Le train s'arrête enfin à Kogarashi — ta ville. Ou ce qu'il en reste : un quai en ruines, des fumées âcres, et plus loin le grondement des flammes qui dévorent encore les toits. C'est ici, cette nuit, que tout a basculé.",
        left: _c("Regarder une dernière fois l'horizon en feu",
            fx: {Stat.moral: -6}, flags: ['asset_bed'],
            result: "Tu fixes Kogarashi brûler jusqu'à ce que le train s'arrache à elle. Tu n'oublieras pas. Jamais. Puis tu t'aménages un coin pour dormir dans le wagon."),
        right: _c("Te détourner et t'installer",
            fx: {Stat.moral: 3}, flags: ['asset_bed'],
            result: "Assez regardé en arrière. Survivre d'abord. Tu pousses une paillasse dans un coin : ton premier lit."),
      ),
      // PREMIÈRE ÉPREUVE (carte à choix) : un chiot est coincé sur le quai par
      // des pillards. Le défendre = le sauver (aLeChien). Barricader = il
      // disparaît dans le chaos. La menace se résout en un choix direct.
      _epreuve('G1ev', 'Kogarashi',
          "Sur le quai, un chiot tremblant, cerné par des pillards qui veulent forcer ton wagon. Tu n'as que ton lance-pierre.",
          _c("Le défendre coûte que coûte",
              fx: {Stat.moral: 12}, flags: ['aLeChien', 'asset_bowl'],
              result: "Pierre après pierre, tu tiens le quai. La petite boule de poils file se réfugier contre ta jambe et s'endort. Tu n'es plus tout à fait seule. Tu lui bricoles une gamelle."),
          _c("Barricader la porte, te protéger",
              fx: {Stat.moral: -4},
              result: "Tu claques la porte sur le chaos. En sécurité — mais quand le calme revient et que le quai s'éloigne, le chiot a disparu. Le wagon, après, est immense et vide.")),
      StoryCard(
        id: 'G1c',
        kind: CardKind.gare,
        speaker: 'Kogarashi',
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
        speaker: 'Kurogane',
        text:
            "Au dépôt de fret, le foyer de la loco agonise. Tu ne sais pas la nourrir — trop de bois l'étouffe, trop peu l'éteint. Un manuel graisseux traîne dans la cabine.",
        left: _c("Déchiffrer le manuel, page à page",
            fx: {Stat.bois: 18, Stat.faim: -4},
            flags: ['asset_lamp'],
            result: "Des heures penchée sur les schémas, l'estomac vide. Mais le feu reprend, franc et vif. Tu sauras faire, maintenant. Tu récupères au dépôt une lampe et une petite table."),
        right: _c("Y aller à l'instinct",
            fx: {Stat.bois: 6, Stat.moral: -3},
            flags: ['asset_lamp'],
            result: "Tu charges au jugé. Le feu crachote, capricieux. Tu apprendras dans la fumée et les jurons. Tu emportes quand même une lampe et une table trouvées au dépôt."),
      ),
      _epreuve('G2ev', 'Kurogane',
          "Au dépôt, des charognards rôdent entre les wagons éventrés. Le bois et les vivres sont là, à portée — mais gardés.",
          _c("Les chasser et rafler le bois",
              fx: {Stat.bois: 12, Stat.faim: -3},
              result: "Tu les fais déguerpir à coups de pierres. Traverses, palettes, charbon : la soute déborde. La loco ronronnera longtemps."),
          _c("Te faufiler en douce pour des vivres",
              fx: {Stat.faim: 8, Stat.soif: 5},
              result: "Tu évites l'affrontement et glisses jusqu'à une réserve de cheminots oubliée : conserves et bidons d'eau. Belle prise, sans une égratignure.")),
    ];

List<StoryCard> _gare3(Set<String> f) => [
      StoryCard(
        id: 'G3',
        kind: CardKind.gare,
        speaker: 'Karasuno',
        text:
            "Karasuno, noyée dans un brouillard épais. Des formes bougent entre les wagons rouillés — des pillards, qui fouillent les morts. Ils n'ont pas encore vu ta loco.",
        left: _c("Couper les feux, passer en fantôme",
            fx: {Stat.bois: -6, Stat.moral: -4},
            flags: ['asset_notebook'],
            result: "Tu éteins tout et tu pousses doucement dans la brume, le cœur au bord des lèvres. Ils ne te verront pas — mais rouler si lentement fait fondre le bois. Dans le silence, tu trouves un carnet abandonné et un crayon."),
        right: _c("Accélérer pour les semer",
            fx: {Stat.bois: -10, Stat.moral: 3},
            flags: ['asset_notebook'],
            result: "Tu ouvres les gaz. Un cri, des pas qui courent, une pierre contre la tôle — puis le brouillard les avale. Passé. Sur la banquette, un carnet oublié par un ancien passager."),
      ),
      StoryCard(
        id: 'G3b',
        kind: CardKind.gare,
        speaker: 'Karasuno',
        text:
            "Sur le quai défilant, un foulard d'enfant accroché à un clou claque au vent. Rouge à pois blancs. Le même que celui de ta petite sœur. À s'y méprendre.",
        left: _c("Risquer tout pour l'attraper",
            fx: {Stat.faim: -8, Stat.moral: 12}, flags: ['indiceSoeur'],
            result: "Tu te faufiles dehors, le cœur cognant. C'est le sien — tu en mettrais ta main au feu. Elle est passée par là. Elle est vivante."),
        right: _c("Ne pas risquer ta peau pour un bout de tissu",
            fx: {Stat.moral: -8},
            result: "Tu restes à bord. Mais le doute te ronge : et si c'était elle qui l'avait laissé là — un signe, pour toi ?"),
      ),
      // Épreuve de gare : face aux pillards dans le brouillard, ton choix.
      _epreuve('G3ev', 'Karasuno',
          "Dans le brouillard de Karasuno, des silhouettes encerclent le wagon. Des pillards, à peine visibles dans la brume.",
          _c("Les tenir à distance, pierre après pierre",
              fx: {Stat.moral: 8, Stat.faim: 6},
              result: "Ils détalent dans la brume. Pas une éraflure sur le wagon — et dans leurs sacs abandonnés, un peu de bois et deux conserves. Le butin des vaincus."),
          _c("Foncer dans la brume sans t'arrêter",
              fx: {Stat.bois: -6, Stat.moral: -3},
              result: "Tu pousses la loco à l'aveugle. Ils cognent le wagon au passage — des planches arrachées, le froid passera par là — mais tu passes.")),
    ];

List<StoryCard> _gare4(Set<String> f) => [
      StoryCard(
        id: 'G4',
        kind: CardKind.gare,
        speaker: 'Mayoidani',
        text:
            "Un mur couvert de messages de disparus. Au milieu, une écriture maladroite d'enfant : « JE VAIS AU NORD. JE T'ATTENDS. » Pas de nom.",
        left: _c("Y croire, foncer au nord",
            fx: {Stat.moral: 14, Stat.bois: -8},
            flags: ['indiceSoeur', 'asset_filter'],
            result: "Tu graves sa réponse à côté et tu pousses la loco. Au passage, tu récupères un filtre à eau dans les ruines du village — de l'eau potable, enfin. Si c'est elle, elle ne t'attendra pas en vain."),
        right: _c("Rester méfiante",
            fx: {Stat.moral: -4}, flags: ['asset_filter'],
            result: "Des milliers d'enfants ont écrit ça. Tu n'oses pas y croire. Pas encore. Tu fouilles le village et en ramènes au moins un filtre à eau."),
      ),
      // Menace = le village lui-même (silence, deuil), pas des pillards.
      _epreuve('G4ev', 'Mayoidani',
          "Le village fantôme t'aspire : maisons éventrées pleines de vivres, mais aussi de photos, de berceaux vides, d'un silence qui pèse sur l'âme. Fouiller, c'est s'y attarder.",
          _c("Fouiller maison par maison",
              fx: {Stat.faim: 10, Stat.soif: 6, Stat.moral: -7},
              result: "Tu remplis ton sac de conserves et d'eau de pluie — mais chaque pièce te raconte une famille qui n'est plus. Tu repars lestée, et plus lourde encore au-dedans."),
          _c("Prendre l'essentiel et fuir ce tombeau",
              fx: {Stat.faim: 4, Stat.moral: 5},
              result: "Tu attrapes ce qui traîne et tu files. Sur un mur, des mots d'espoir griffonnés : tu n'es pas la seule à monter vers le nord. Ça suffit à te tenir debout.")),
    ];

List<StoryCard> _gare5(Set<String> f) => [
      StoryCard(
        id: 'G5',
        kind: CardKind.gare,
        speaker: 'Tsukibashi',
        text: f.contains('indiceSoeur')
            // Payoff des indices (foulard G3, dessin G4) suivis tout du long.
            ? "Une silhouette menue, recroquevillée au milieu du pont. À son cou, un foulard rouge à pois — le jumeau de celui que tu as serré de gare en gare, ton fil d'Ariane vers elle. Tu cesses de respirer. Tu savais. Tu as toujours su. C'est elle. C'est ta petite sœur."
            : "Une silhouette menue, recroquevillée au milieu du pont, te barre la route. Elle lève la tête à la lumière de la loco. Tu cesses de respirer. C'est elle. C'est ta petite sœur.",
        left: _c("Courir la serrer dans tes bras",
            fx: {Stat.moral: 40}, flags: ['aLaSoeur'], result: "Tu sautes du train, tu la soulèves, vous pleurez. Le monde mort, un instant, n'existe plus. Elle monte avec toi."),
        right: _c("La couvrir et vérifier qu'elle va bien",
            fx: {Stat.moral: 34, Stat.faim: 4}, flags: ['aLaSoeur', 'soeurProtegee'], result: "Avant les larmes, tu l'enveloppes, tu palpes ses bras gelés, tu la fais manger. Elle est entière. ELLE EST LÀ. Puis seulement tu t'effondres de soulagement."),
      ),
      StoryCard(
        id: 'G5b',
        kind: CardKind.gare,
        speaker: 'Ta sœur',
        text:
            "« Papa et maman... ils sont partis devant. Vers le nord, un refuge. Ils m'ont dit de les attendre, que quelqu'un viendrait. » Ses yeux brillent. « Je savais que ce serait toi. »",
        // CHOIX STRUCTURANT (décide famille vs ensemble) : t'engager à
        // retrouver les parents (espoir, cap au nord) OU te concentrer sur la
        // sécurité de ta sœur ici et maintenant (acceptation).
        left: _c("Jurer de retrouver papa et maman",
            fx: {Stat.moral: 12}, flags: ['capParents'], result: "« On va les retrouver. Tous les deux. » Tu y crois, maintenant. Tu as une raison de tenir jusqu'au bout."),
        right: _c("Te concentrer sur elle, ici, maintenant",
            fx: {Stat.moral: 6, Stat.faim: 5, Stat.soif: 5}, flags: ['soeurProtegee'], result: "« L'important, c'est toi. Le reste viendra. » Tu la nourris, tu la réchauffes. Tu ne promets rien que le monde pourrait briser."),
      ),
      // Épreuve de gare : comment tu défends le pont décide de l'état dans
      // lequel tu retrouves ta sœur.
      _epreuve('G5ev', 'Tsukibashi',
          "Au milieu du pont, des pillards rôdent autour de ta petite sœur recroquevillée. Chaque seconde compte.",
          _c("Te jeter entre eux et elle",
              fx: {Stat.moral: 10}, flags: ['soeurProtegee'],
              result: "Tu tiens le pont avec rage, pierre après pierre. Pas une égratignure sur elle. Tu l'as protégée, et tu le referais mille fois."),
          _c("La saisir et filer sous les pierres",
              fx: {Stat.moral: 4, Stat.faim: -4},
              result: "Tu l'arraches au danger en courant. Elle est sauve — mais elle a vu des choses qu'un enfant ne devrait jamais voir.")),
    ];

List<StoryCard> _gare6(Set<String> f) => [
      StoryCard(
        id: 'G6',
        kind: CardKind.gare,
        speaker: 'Yasuragi',
        text:
            "Un camp de survivants. On peut troquer, mais ils regardent ta sœur avec trop d'intérêt — ici, un enfant en bonne santé, ça se monnaie.",
        left: _c("Troquer vite et partir",
            fx: {Stat.faim: 12, Stat.soif: 8, Stat.moral: -6}, flags: ['asset_commode', 'asset_wagon2'],
            result: "Tu obtiens des vivres mais tu sens leurs regards. Tu repars avant la nuit, elle serrée contre toi — avec une vieille commode, et tu rattaches au convoi un 2e wagon (cellier) abandonné sur une voie de garage."),
        right: _c("Ne pas t'attarder une seconde",
            fx: {Stat.moral: 6, Stat.faim: -5}, flags: ['asset_commode', 'asset_wagon2'],
            result: "Tu refuses tout contact. Le ventre vide, mais ta sœur en sécurité. En partant, tu accroches un 2e wagon (cellier) laissé là, et tu emportes une commode."),
      ),
      // Menace = dilemme SOCIAL (le camp jauge ton humanité), pas un combat.
      _epreuve('G6ev', 'Yasuragi',
          "Au camp, on surprend un gosse affamé la main dans tes réserves. Tout le monde s'arrête et te regarde : ce que tu vas faire décidera comment on te traite ici.",
          _c("Faire un exemple, récupérer ton bien",
              fx: {Stat.faim: 10, Stat.soif: 6, Stat.moral: -8},
              result: "Tu reprends tout, durement. On ne te volera plus — mais on te craint, et toi, tu te dégoûtes un peu. Le ventre plein, le cœur lourd."),
          _c("Partager le peu que tu as",
              fx: {Stat.faim: -6, Stat.moral: 12},
              result: "Tu donnes une conserve au gamin. Le camp t'adopte : on t'offre le gîte, des nouvelles du nord, un peu de chaleur humaine. Affamée, mais grandie.")),
    ];

List<StoryCard> _gare7(Set<String> f) => [
      StoryCard(
        id: 'G7',
        kind: CardKind.gare,
        speaker: 'Hoshikage',
        text:
            "Cette halte, vous y veniez enfant, toutes les deux, regarder les trains. Ta sœur la reconnaît et sourit pour la première fois depuis la fuite.",
        left: _c("Lui raconter ce souvenir",
            fx: {Stat.moral: 16, Stat.bois: -5}, result: "Vous riez ensemble dans le wagon arrêté. Un moment volé, qui coûte un peu de route, mais qui vous répare."),
        right: _c("Garder le cap, ne pas t'arrêter",
            fx: {Stat.moral: 4}, result: "Tu serres les dents et tu avances. Le nord d'abord. Les souvenirs, après."),
      ),
      _epreuve('G7ev', 'Hoshikage',
          "À la halte de votre enfance, des pillards surgissent en plein souvenir. Le charme menace de se rompre.",
          _c("Les écarter pour préserver l'instant",
              fx: {Stat.moral: 12},
              result: "Tu règles ça vite et net. Vous regardez les rails comme avant, en paix. Elle rit. Ça vaut tout l'or du monde."),
          _c("Repartir aussitôt, fouiller en chemin",
              fx: {Stat.faim: 6, Stat.bois: 4, Stat.moral: -3},
              result: "Tu n'attends pas une 2e vague. Le vieux kiosque cache provisions et bois sec — mais la halte sacrée de l'enfance a un goût de cendre, maintenant.")),
    ];

List<StoryCard> _gare8(Set<String> f) => [
      StoryCard(
        id: 'G8',
        kind: CardKind.gare,
        speaker: 'Kiribe',
        text:
            "Le froid mord pour de bon. Ta sœur grelotte, ses lèvres bleuissent. Elle n'a pas de vrai manteau.",
        left: _c("Lui donner le tien",
            fx: {Stat.moral: 14, Stat.soif: -6}, flags: ['soeurProtegee', 'asset_stove', 'asset_firstaid'], result: "Tu grelottes à sa place. Elle s'endort contre toi, au chaud. Tu ne regrettes rien. À l'entrée de la zone froide, tu as installé un vrai poêle et trouvé une trousse de secours."),
        right: _c("Pousser le feu à fond",
            fx: {Stat.bois: -16, Stat.moral: 6}, flags: ['asset_stove', 'asset_firstaid'], result: "Tu sacrifies ta réserve de bois pour la réchauffer. Le wagon est un four, pour l'instant. Tu finis par installer un vrai poêle et dénicher une trousse de secours."),
      ),
      _epreuve('G8ev', 'Kiribe',
          "À l'entrée du froid, des rôdeurs du gel tournent autour d'un wagon mal calfeutré. Et ta sœur grelotte déjà.",
          _c("Veiller ta sœur d'abord",
              fx: {Stat.moral: 8}, flags: ['soeurProtegee'],
              result: "Tu choisis de t'occuper d'elle. Elle s'endort apaisée contre toi. Les rôdeurs, eux, renoncent au froid mordant."),
          _c("Calfeutrer et tenir la porte",
              fx: {Stat.bois: 6, Stat.moral: 4},
              result: "Tu colmates chaque fente pendant le calme. La chaleur tiendra cette nuit — mais elle s'est endormie seule, en frissonnant.")),
    ];

List<StoryCard> _gare9(Set<String> f) => [
      StoryCard(
        id: 'G9',
        kind: CardKind.gare,
        speaker: 'Shizuhara',
        text:
            "Le blizzard enferme le train. Ta sœur brûle de fièvre, délire, t'appelle dans son sommeil agité. Tu n'as presque plus rien.",
        left: _c("La veiller toute la nuit",
            fx: {Stat.faim: -10, Stat.moral: 12}, flags: ['soeurProtegee'], result: "Tu ne dors pas, tu éponges son front jusqu'à l'aube. La fièvre cède. Elle vivra."),
        right: _c("Braver la tempête pour des remèdes",
            fx: {Stat.soif: -12, Stat.moral: 8}, flags: ['soeurProtegee'], result: "Tu sors dans le blizzard, tu reviens gelée avec des cachets périmés. Ça suffit. De justesse."),
      ),
      _epreuve('G9ev', 'Shizuhara',
          "En pleine tempête, ta sœur brûle de fièvre et délire — et des rôdeurs veulent profiter de ta détresse.",
          _c("La soigner sans relâche, les ignorer",
              fx: {Stat.moral: 10, Stat.faim: -6}, flags: ['soeurProtegee'],
              result: "Tu veilles sans répit, tu éponges son front. La fièvre baisse plus vite. Elle s'en sortira. Le reste attendra."),
          _c("Les repousser pour leur matériel",
              fx: {Stat.faim: 8, Stat.bois: 6, Stat.moral: -3},
              result: "Tu chasses les rôdeurs et rafles vivres et bois. Mais ta sœur a traversé l'assaut seule, fiévreuse et tremblante.")),
    ];

List<StoryCard> _gare10(Set<String> f) => [
      StoryCard(
        id: 'G10',
        kind: CardKind.gare,
        speaker: 'Hidamari',
        text:
            "Une serre intacte, chaude, verdoyante. Ta sœur court entre les plants en riant. Un répit irréel. On pourrait... rester ici ?",
        left: _c("S'accorder un vrai repos",
            fx: {Stat.faim: 20, Stat.soif: 16, Stat.moral: 18},
            flags: ['asset_hydro', 'asset_bath', 'asset_shower', 'asset_lantern'],
            result: "Quelques jours de chaleur et de rires. Vous reprenez des forces et de l'âme. Avant de partir, vous démontez de quoi monter une tour hydroponique, une baignoire, un coin douche et deux lanternes dans le cellier. Puis le nord rappelle."),
        right: _c("Faire le plein et repartir vite",
            fx: {Stat.faim: 12, Stat.soif: 10, Stat.bois: 12, Stat.moral: -4},
            flags: ['asset_hydro', 'asset_bath', 'asset_shower', 'asset_lantern'],
            result: "« Papa et maman attendent. » Elle comprend. Vous emportez des plants, le matériel hydroponique, de quoi installer un bain, une douche et des lanternes dans le cellier, et repartez le ventre plein, le cœur lourd."),
      ),
      _epreuve('G10ev', 'Hidamari',
          "Des maraudeurs approchent de la serre verdoyante. Tu peux la défendre, ou simplement profiter de l'instant avant qu'ils n'arrivent.",
          _c("La défendre pour tout récolter",
              fx: {Stat.faim: 14, Stat.soif: 10},
              result: "Tu les tiens à distance. Vous repartez chargées de fruits et d'eau claire. La serre vous a comblées."),
          _c("Profiter de l'instant, tant pis pour eux",
              fx: {Stat.moral: 12, Stat.faim: -4},
              result: "Une vraie journée de paix dans la chaleur verte. Vos âmes se réparent — vous laissez le reste aux pillards.")),
    ];

List<StoryCard> _gare11(Set<String> f) => [
      StoryCard(
        id: 'G11',
        kind: CardKind.gare,
        speaker: 'Yukihara',
        text:
            "Des pillards ont dressé un barrage sur la voie. Ils veulent le train, les vivres — et ils ont vu ta sœur.",
        left: _c("Foncer dans le barrage",
            fx: {Stat.bois: -18, Stat.moral: -6}, result: "Tu pousses la loco à fond et tu enfonces l'obstacle. Des cris, des tirs, puis le silence. Vous êtes passées, presque à sec."),
        right: _c("Négocier, donner des vivres",
            fx: {Stat.faim: -16, Stat.soif: -10, Stat.moral: 4}, result: "Tu sacrifies la moitié de vos réserves pour qu'ils vous laissent passer. Affamées, mais entières."),
      ),
      // Épreuve de gare : APRÈS le barrage, des éclaireurs prennent le train en
      // chasse sur une draisine. (Beat distinct de G11 — pas une redite.)
      _epreuve('G11ev', 'Yukihara',
          "Le barrage passé, une draisine de pillards surgit derrière vous, gagnant du terrain. Ta sœur s'accroche à toi, terrifiée.",
          _c("Tout brûler pour les semer",
              fx: {Stat.bois: -14, Stat.moral: 4},
              result: "Tu jettes tout ce qui brûle dans le foyer. La loco rugit, distance la draisine, et leurs silhouettes rapetissent. Vous êtes libres — à sec, mais libres."),
          _c("Te poster, viser leur draisine",
              fx: {Stat.moral: 6}, flags: ['soeurProtegee'],
              result: "Tu mets ta sœur à l'abri, tu attends, tu vises l'attelage. Une pierre bien placée, la draisine déraille dans un fracas de tôle. Le silence revient. Tu l'as protégée.")),
    ];

List<StoryCard> _gare12(Set<String> f) => [
      StoryCard(
        id: 'G12',
        kind: CardKind.gare,
        speaker: 'Miharashi',
        text:
            "Du haut d'une tour, vous le voyez enfin : le refuge du nord, ses cheminées qui fument. Et, plantée devant, une pancarte : « FAMILLES — REGROUPEMENT SECTEUR EST ». Ta sœur te serre la main à la broyer.",
        left: _c("Lui jurer qu'ils sont là",
            fx: {Stat.moral: 16}, result: "« Ils nous attendent. Je le sais. » Elle hoche la tête, les yeux pleins de larmes et d'espoir."),
        right: _c("Tempérer, la protéger d'abord",
            fx: {Stat.moral: 8}, flags: ['soeurProtegee'], result: "« On verra, ma puce. On verra. » Tu ne promets rien que le monde pourrait briser — mais tu la serres fort. Elle, ici, maintenant : c'est sûr."),
      ),
      _epreuve('G12ev', 'Miharashi',
          "Au pied de la tour, le brouillard givrant masque la seule vue dégagée sur le refuge. Grimper la tour gelée pour repérer la route est aussi épuisant que risqué.",
          _c("Grimper malgré le gel, repérer la route",
              fx: {Stat.moral: 12, Stat.faim: -6, Stat.soif: -5},
              result: "Les mains en sang sur les barreaux gelés, tu atteins le sommet. De là-haut, la route la plus sûre s'offre à toi : plus de détours, plus de pièges. Épuisée, mais tu sais où aller."),
          _c("Rester en bas, fouiller le poste",
              fx: {Stat.faim: 8, Stat.soif: 6, Stat.bois: -4},
              result: "Tu renonces à la vue et tu rafles les rations planquées du poste de guet. De quoi finir le voyage — mais tu avanceras à l'aveugle.")),
    ];

List<StoryCard> _gare13(Set<String> f) => [
      StoryCard(
        id: 'G13',
        kind: CardKind.gare,
        speaker: 'Fubuki',
        text:
            "La loco rend l'âme dans la dernière montée, à un souffle du sommet. Plus de bois. Il faut sacrifier quelque chose, vite, avant que le froid ne vous prenne.",
        left: _c("Brûler tout le mobilier du wagon",
            fx: {Stat.bois: 28, Stat.moral: -8}, result: "La table, la couchette, vos affaires — tout au feu. Le wagon n'est plus qu'une boîte nue, mais la loco franchit le col."),
        right: _c("Descendre pousser ensemble",
            fx: {Stat.faim: -14, Stat.soif: -10, Stat.moral: 10}, result: "Vous poussez à deux, à mains nues dans la neige, en hurlant. La loco bascule de l'autre côté. Vous l'avez fait. Ensemble."),
      ),
      _epreuve('G13ev', 'Fubuki',
          "Dans le col gelé, des charognards guettent les trains à l'agonie. Et la loco, elle, manque cruellement de bois.",
          _c("Les tenir à distance et rafler leur bois",
              fx: {Stat.bois: 12},
              result: "Ils avaient une réserve pour l'hiver. Tu la prends. Elle franchira le col à ta place."),
          _c("Tout brûler pour distancer la menace",
              fx: {Stat.bois: -8, Stat.faim: -6, Stat.moral: 4},
              result: "Tu jettes au feu tout ce qui brûle pour les semer. La loco hoquette, puis bascule de l'autre côté. Vivantes, à genoux.")),
      // RÉVÉLATION DU SOMMET : beat émotionnel GARANTI (promu depuis un filler
      // aléatoire). Le payoff de tout le col gelé : on aperçoit le refuge.
      StoryCard(
        id: 'G13c',
        kind: CardKind.gare,
        speaker: 'Fubuki',
        text:
            "Et soudain, la pente s'inverse. Le sommet. De l'autre côté, une vallée — et tout au fond, une lueur qui n'est pas le soleil.",
        left: _c("T'autoriser à espérer",
            fx: {Stat.moral: 16, Stat.faim: -3}, result: "Le refuge. C'est forcément le refuge. Tu ris et tu pleures en même temps. Vous y êtes presque."),
        right: _c("Rester prudente jusqu'au bout",
            fx: {Stat.moral: 6}, result: "Tu as trop vu pour crier victoire. Mais ton cœur, lui, s'est déjà mis à courir."),
      ),
    ];

List<StoryCard> _gare14(Set<String> f) => [
      // Dernière épreuve, AVANT la résolution finale.
      _epreuve('G14ev', 'Hokuto',
          "Aux portes du refuge, une dernière bande veut une ultime proie. La toute dernière du voyage.",
          _c("Les balayer, entrer la tête haute",
              fx: {Stat.moral: 12},
              result: "Tu les écartes net. Les gardes du refuge t'ouvrent grand les portes. Vous êtes arrivées, et entières."),
          _c("Forcer le passage en encaissant",
              fx: {Stat.moral: 4, Stat.faim: -4},
              result: "Tu franchis les derniers mètres sous les coups. Le train entre cabossé, mais il entre. Vous y êtes.")),
      StoryCard(
        id: 'G14',
        kind: CardKind.gare,
        speaker: 'Hokuto',
        text:
            "Le train entre en gare du refuge. Ta sœur écrase son visage contre la vitre. Sur le quai, la foule des familles qui cherchent les leurs. Tu descends, le cœur en feu.",
        left: _c("Crier leurs noms dans la foule",
            fx: {Stat.moral: 3},
            result: "« PAPA ! MAMAN ! » Ta voix se brise et porte loin par-dessus le quai. Des têtes se tournent. Vous avancez, le cœur en feu..."),
        right: _c("Avancer en silence, scruter chaque visage",
            result: "Tu prends sa main, sans un mot. Vos deux regards fouillent la foule, un visage après l'autre..."),
      ),
    ];

// ============================================================
// PAQUETS DE REMPLISSAGE par segment (échantillon, à étoffer)
// ============================================================

final List<StoryCard> _fill1 = [
  _filler('F1_homme',
      "Un homme court le long de la voie, hurlant, tendant les bras vers le train. Tu pourrais freiner pour le hisser à bord — mais la loco perdrait son élan.",
      _c("Freiner pour lui", fx: {Stat.bois: -5, Stat.moral: 8}, result: "Tu ralentis juste assez. Il s'agrippe, court à côté, et bifurque vers un abri que tu lui désignes au loin. Il te salue, vivant. Un geste pour rien, ou pour tout — ça réchauffe."),
      _c("Garder l'élan", fx: {Stat.moral: -8}, result: "Tu ne ralentis pas. Ses cris s'éteignent dans ton dos. Survivre, te répètes-tu. Survivre."),
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
  _filler('F1_chien_nuit',
      "Le chiot tremble contre toi dans le noir du wagon. Il a peur — mais sa petite chaleur te tient éveillée et vivante.",
      _c("Le serrer contre toi", fx: {Stat.moral: 8}, result: "Vous vous réchauffez l'un l'autre. Tu n'es plus tout à fait seule au monde."),
      _c("Le laisser dans son coin", fx: {Stat.moral: -3}, result: "Tu gardes tes distances. Il gémit doucement jusqu'au matin."),
      requires: (f) => f.contains('aLeChien')),
  _filler('F1_marchand',
      "À un passage à niveau, un vieux marchand agite un fanion. Il propose un troc rapide, sans que personne descende.",
      _c("Troquer des vivres", fx: {Stat.faim: 10, Stat.bois: -4}, result: "Un sac de conserves contre quelques bûches. Marché honnête, pour une fois."),
      _c("Te méfier et passer", fx: {Stat.moral: -2}, result: "Tu ne ralentis pas. Ses yeux te suivent, déçus — ou calculateurs."),
      oneshot: true),
  _filler('F1_pancarte',
      "Une pancarte rouillée : « NORD — 1400 km ». Quelqu'un a rayé le chiffre et griffonné dessous : « TROP LOIN ».",
      _c("Y croire quand même", fx: {Stat.moral: 6, Stat.bois: -4}, result: "Tu accélères, têtue. 1400 km, et alors ? Un rail après l'autre."),
      _c("Encaisser le coup", fx: {Stat.moral: -5}, result: "1400 km. Le poids du chiffre t'écrase un long moment.")),
  _filler('F1_linceul',
      "Sous une banquette, les affaires des passagers tués la nuit de la fuite : manteaux, sacs, une poupée de chiffon.",
      _c("Tout récupérer", fx: {Stat.faim: 8, Stat.moral: -6}, result: "De quoi survivre. Mais fouiller leurs poches te serre la gorge."),
      _c("N'en faire qu'un linceul", fx: {Stat.moral: 7, Stat.faim: -3}, result: "Tu les couvres décemment. Le peu que tu puisses encore offrir à des morts."),
      oneshot: true),
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
      _c("Le raccourci", fx: {Stat.bois: 12, Stat.moral: -7}, result: "Tu gagnes des heures de bois — mais la voie se dégrade, des rails tordus passent sous toi, le cœur au bord des lèvres."),
      _c("La voie sûre", fx: {Stat.moral: 5, Stat.bois: -6}, result: "Plus long, plus de bois à brûler. Mais tu sais où tu vas, et ça apaise.")),
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
  _filler('F2_huile',
      "Un bidon d'huile de graissage, à moitié plein. Précieux pour la mécanique — ou comme combustible d'appoint.",
      _c("Graisser la loco", fx: {Stat.bois: 8}, result: "Les bielles glissent sans gémir. La machine te remercie en silence."),
      _c("Le garder pour le feu", fx: {Stat.bois: 6, Stat.moral: -2}, result: "De quoi rallumer vite un foyer mourant. Au prix de l'entretien.")),
  _filler('F2_famille_quai',
      "Sur un quai, une famille attend un train qui ne viendra plus. Le père te supplie d'emporter au moins leur fille.",
      _c("Refuser, le cœur en miettes", fx: {Stat.moral: -9}, result: "Tu ne peux pas nourrir une bouche de plus. Leurs visages te hanteront."),
      _c("Leur donner tes vivres", fx: {Stat.faim: -8, Stat.moral: 9}, result: "Tu n'as pas de place, mais tu vides ton sac dans leurs bras. Le train repart, eux restent."),
      oneshot: true),
  _filler('F2_citerne',
      "Un wagon-citerne abandonné, peut-être plein d'eau. En forcer la vanne prend du temps et des forces.",
      _c("Forcer la vanne", fx: {Stat.soif: 14, Stat.faim: -4}, result: "De l'eau ! Croupie mais filtrable. L'effort en valait la peine."),
      _c("Ne pas perdre de temps", fx: {Stat.moral: 2}, result: "Tu n'as pas le luxe de fouiller chaque épave. Tu roules.")),
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
  _filler('F3_chien_garde',
      "Le chien se dresse soudain, grondant vers l'avant, poils hérissés. Il a flairé quelque chose dans le brouillard.",
      _c("Ralentir, te fier à lui", fx: {Stat.bois: -5, Stat.moral: 6}, result: "Tu freines juste à temps : un éboulis barre la voie. Il t'a sauvée."),
      _c("Le faire taire et avancer", fx: {Stat.moral: -6}, result: "Tu passes en force. Un choc sourd sous le wagon. Tu n'as pas voulu savoir."),
      requires: (f) => f.contains('aLeChien')),
  _filler('F3_blesses',
      "Deux pillards blessés lèvent les mains au bord de la voie. Piège tendu, ou vrais désespérés ?",
      _c("Leur jeter des vivres au passage", fx: {Stat.faim: -6, Stat.moral: 7}, result: "Tu balances un sac sans ralentir. Des humains, peut-être, malgré tout."),
      _c("Ne pas tomber dans le panneau", fx: {Stat.moral: -3}, result: "Tu gardes le cap, méfiante. Dans ce monde, la pitié se paie cher.")),
  _filler('F3_fumee',
      "Une colonne de fumée droit devant : campement vivant, ou incendie mort. La voie y plonge tout droit.",
      _c("Traverser vite, tête baissée", fx: {Stat.bois: -8, Stat.moral: 3}, result: "Tu passes au cœur des braises d'un village brûlé. Vite, vite, vite."),
      _c("Attendre que ça se dégage", fx: {Stat.faim: -5, Stat.moral: -2}, result: "Tu patientes, à l'arrêt. Le temps file, le ventre crie.")),
];

final List<StoryCard> _fill4 = [
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
  _filler('F4_radio_trouvee',
      "Dans les décombres du village, sous un mur couvert de messages de disparus, une radio à manivelle, intacte. Un fil vers le monde — s'il reste un monde au bout.",
      _c("L'emporter précieusement", fx: {Stat.moral: 8, Stat.faim: -3}, flags: ['aLaRadio'], result: "Tu la serres contre toi comme un trésor. Ce soir, tu tourneras la manivelle."),
      _c("L'emporter, mais sans trop d'espoir", fx: {Stat.moral: -2, Stat.faim: -3}, flags: ['aLaRadio'], result: "Tu la glisses dans ton sac, le cœur lourd. Écouter le silence du monde te fait peur — mais tu la gardes, on ne sait jamais."),
      oneshot: true),
  _filler('F4_dessin_soeur',
      "Parmi les messages du mur, un dessin d'enfant : deux bonshommes-bâtons main dans la main, un grand, un petit. « MA GRANDE SŒUR VIENDRA. »",
      _c("Le prendre comme un signe", fx: {Stat.moral: 10, Stat.faim: -4}, result: "Ton cœur bondit. Et si... Tu n'oses pas finir la pensée. Mais tu y crois un peu plus."),
      _c("Ne pas te bercer d'illusions", fx: {Stat.moral: -5}, result: "Des milliers de sœurs, des milliers d'attentes griffonnées. Tu ravales l'espoir."),
      oneshot: true),
  _filler('F4_chien_cache',
      "Le chien gratte la terre près d'une maison et déterre une réserve enfouie : conserves, et même un sac de croquettes.",
      _c("Le récompenser", fx: {Stat.faim: 12, Stat.moral: 5}, result: "Vous festoyez tous les deux. Bon chien. Le meilleur de ce monde mort."),
      _c("Tout rationner", fx: {Stat.faim: 14, Stat.moral: -2}, result: "Tu ranges tout. Il te fixe, déçu. Mais l'hiver vient, et il dévore."),
      requires: (f) => f.contains('aLeChien')),
  _filler('F4_fonts',
      "Une église éventrée, des fonts baptismaux pleins d'une eau de pluie limpide.",
      _c("Remplir tes jarres", fx: {Stat.soif: 16}, result: "Eau claire, presque douce. Tu murmures un merci à personne."),
      _c("Respecter le lieu", fx: {Stat.moral: 5, Stat.soif: -3}, result: "Tu n'oses pas. Tu repars la gorge sèche, mais l'âme en paix.")),
];

final List<StoryCard> _fill5 = [
  // La chanson de la radio (trouvée gare 4) : jouée sur la route vers la gare 5.
  // (Déplacée depuis _fill4 où elle était morte : son `requires aLaRadio` était
  // évalué avant que la radio ne soit trouvée dans le même segment.)
  _filler('F5_chanson',
      "La radio capte une vieille chanson d'amour intacte. L'écouter use la manivelle et ravive la douleur.",
      _c("Écouter jusqu'au bout", fx: {Stat.moral: 10, Stat.faim: -4}, result: "Tu danses seule, en larmes. Tu en oublies de manger."),
      _c("Couper, garder l'énergie", fx: {Stat.moral: -5}, result: "Cette chanson, c'était la leur. Tu coupes net."),
      oneshot: true, requires: (f) => f.contains('aLaRadio')),
  // Payoff des indices (foulard G3, dessin/mur G4) : ils ont entretenu
  // l'espoir jusqu'aux retrouvailles. Sans ce câblage, indiceSoeur était mort.
  _filler('F5_indices_payoff',
      "Tu ressors le foulard, le dessin du mur, tous les indices gardés de gare en gare. Chacun te criait qu'elle était vivante. Tu as eu raison de ne jamais y renoncer.",
      _c("Les serrer une dernière fois", fx: {Stat.moral: 13}, result: "Ils t'ont tenue debout dans le noir. Aujourd'hui, ils t'ont menée jusqu'à elle."),
      _c("Les confier au vent", fx: {Stat.moral: 9, Stat.faim: 3}, result: "Tu les relâches un à un. Ils ont fait leur travail. Maintenant tu l'as, ELLE, en vrai."),
      requires: (f) => f.contains('indiceSoeur') && f.contains('aLaSoeur')),
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
  _filler('F5_radio_premier',
      "Tu tournes la manivelle. À travers la friture, une voix de femme, hachée : « ...refuge... secteur est... on vous attend... » Puis le néant.",
      _c("Noter chaque bribe", fx: {Stat.moral: 9, Stat.faim: -3}, flags: ['radio1'], result: "Tu griffonnes les mots. Quelqu'un, là-haut, parle encore. Tu n'es pas seule sur cette Terre."),
      _c("Ne pas trop espérer", fx: {Stat.moral: 2}, result: "Un vieux message en boucle, sûrement. Tu coupes la manivelle. À quoi bon s'accrocher à une friture ?"),
      oneshot: true,
      requires: (f) => f.contains('aLaRadio') && !f.contains('radio1')),
  _filler('F5_soeur_cabane',
      "Ta sœur a transformé le wagon en cabane : couvertures tendues, cailloux alignés en chemin. « C'est notre maison, maintenant. »",
      _c("Jouer le jeu avec elle", fx: {Stat.moral: 11, Stat.faim: -4}, result: "Tu rampes sous les couvertures. Vous riez. La maison tient tout entière dans un wagon."),
      _c("Lui dire de rester sérieuse", fx: {Stat.moral: -4}, result: "Son sourire retombe. Tu regrettes aussitôt : la survie n'a pas tué les jeux, pourtant."),
      requires: (f) => f.contains('aLaSoeur')),
  _filler('F5_radeau',
      "Le fleuve charrie un radeau de débris où s'accroche un sac scellé. L'attraper depuis le bord est risqué.",
      _c("Te pencher pour l'attraper", fx: {Stat.faim: 12, Stat.moral: -3}, result: "Tu manques basculer, mais tu décroches le sac. Conserves et allumettes !"),
      _c("Le laisser filer", fx: {Stat.moral: 2}, result: "Un sac ne vaut pas une chute dans l'eau noire. Tu le regardes s'éloigner.")),
  _filler('F5_brume',
      "La brume avale le pont. Tu ne vois pas l'autre rive. Avancer à l'aveugle, ou attendre qu'elle se lève ?",
      _c("Avancer au pas", fx: {Stat.bois: -6, Stat.moral: 4}, result: "Mètre par mètre, à l'oreille. La rive surgit enfin. Soulagement glacé."),
      _c("Attendre la levée", fx: {Stat.faim: -5}, result: "Tu patientes des heures. La brume se déchire enfin. Le temps perdu pèse.")),
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
  _filler('F6_eboulement',
      "Un éboulement bloque à moitié la voie. Déblayer épuise ; forcer abîme la loco.",
      _c("Déblayer à la main", fx: {Stat.faim: -8, Stat.moral: 4}, result: "Des heures de pelle. Épuisée mais la voie est nette."),
      _c("Forcer le passage", fx: {Stat.bois: -10, Stat.moral: -2}, result: "La loco racle, crache, passe. Elle s'en souviendra.")),
  _filler('F6_poupee',
      "Une marchande propose une poupée de chiffon contre trois conserves. Inutile — sauf pour un cœur d'enfant.",
      _c("L'acheter pour ta sœur", fx: {Stat.faim: -8, Stat.moral: 12}, result: "Le visage de ta sœur s'illumine. Douze conserves n'auraient pas valu ce sourire."),
      _c("L'économie d'abord", fx: {Stat.moral: -3}, result: "Tu gardes tes vivres. Le superflu n'a pas sa place. Pas encore."),
      requires: (f) => f.contains('aLaSoeur')),
  _filler('F6_rumeurs',
      "Au camp, les rumeurs vont bon train : le refuge nord serait surpeuplé, ou tombé, ou un mirage. Chacun jure du contraire.",
      _c("Recouper les infos utiles", fx: {Stat.bois: 6, Stat.moral: -4}, result: "Tu tries le vrai du faux. Un itinéraire fiable — et une boule au ventre."),
      _c("Ne croire que tes yeux", fx: {Stat.moral: 5}, result: "Tu n'écoutes pas les peurs des autres. Tu verras de tes propres yeux.")),
  _filler('F6_guerisseur',
      "Un homme se dit guérisseur et propose de t'examiner contre du bois. Charlatan, ou vraie aubaine ?",
      _c("Le payer en bois", fx: {Stat.bois: -8, Stat.moral: 8}, result: "Il vous ausculte, te donne des cachets, te dit solide. Du baume sur l'angoisse."),
      _c("Te fier à ta santé", fx: {Stat.moral: -2}, result: "Tu n'as pas de bois à gaspiller pour un inconnu. Tu repars.")),
];

final List<StoryCard> _fill7 = [
  // Écho du choix de la gare 5 : la voie de l'ESPOIR (cap parents). Donne du
  // poids et de la lisibilité au flag capParents entre G5 et la fin.
  _filler('F7_cap_parents',
      "« Tu crois qu'ils sont là-haut ? » te demande ta sœur, le menton sur tes genoux. Tu repenses à ta promesse : les retrouver. Tous.",
      _c("« J'en suis sûre. On les ramènera. »", fx: {Stat.moral: 9}, result: "Tu y crois assez pour qu'elle y croie aussi. Cette certitude vous tient chaudes toutes les deux."),
      _c("« On verra. Avance. »", fx: {Stat.moral: 4, Stat.faim: 3}, result: "Tu ne veux pas trop promettre. Mais au fond, tu scrutes déjà chaque horizon pour deux visages."),
      oneshot: true, requires: (f) => f.contains('capParents')),
  // Écho de l'AUTRE voie : l'acceptation (cap sœur seule).
  _filler('F7_cap_soeur',
      "« Et si on ne retrouvait personne ? » murmure ta sœur. Tu n'as pas promis de les chercher. Tu as promis de la garder, ELLE.",
      _c("« Alors on se suffira à deux. »", fx: {Stat.moral: 8}, result: "Pas de fausse promesse, juste elle et toi. C'est déjà beaucoup. C'est peut-être tout."),
      _c("La serrer sans répondre", fx: {Stat.moral: 5}, result: "Tu n'as pas de mots. Juste tes bras autour d'elle, et le train qui roule vers on ne sait quoi."),
      oneshot: true, requires: (f) => f.contains('aLaSoeur') && !f.contains('capParents')),
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
  _filler('F7_radio_voix',
      "La radio, encore. Cette fois la voix perce, plus nette : « ...si vous m'entendez... gare du nord... ne renoncez pas... » Une voix de femme, chaude. Familière ?",
      _c("T'accrocher à cette voix", fx: {Stat.moral: 10}, flags: ['radio2'], result: "Tu connais cette voix. Tu en jurerais. Mais d'où ? Le doute, délicieux et déchirant, te tient éveillée."),
      _c("Te raisonner", fx: {Stat.moral: 3}, result: "L'esprit joue des tours aux affamées. Tu éteins la radio. Mieux vaut ne pas se bercer d'une voix qui n'existe peut-être pas."),
      oneshot: true,
      requires: (f) => f.contains('radio1') && !f.contains('radio2')),
  _filler('F7_soeur_billes',
      "Ta sœur t'entraîne vers une cachette d'enfant sous un vieux quai, où vous planquiez des billes, dans une autre vie.",
      _c("Fouiller la cachette", fx: {Stat.moral: 12, Stat.faim: -3}, result: "Les billes sont là, intactes sous la poussière. Vous pleurez de rire. Le passé existe encore."),
      _c("Ne pas réveiller le passé", fx: {Stat.moral: -3}, result: "Tu n'oses pas. Trop de douceur fait trop mal, maintenant."),
      requires: (f) => f.contains('aLaSoeur')),
  _filler('F7_train_jouet',
      "Un petit train miniature rouillé dans une vitrine de gare. Vous le regardiez, gamines, le nez collé au verre.",
      _c("Le récupérer", fx: {Stat.moral: 8, Stat.bois: -3}, result: "Un souvenir de plus à traîner. Ça vaut bien trois bûches de détour."),
      _c("Le laisser à sa vitrine", fx: {Stat.moral: 3}, result: "Certaines choses doivent rester là où on les a aimées.")),
  _filler('F7_car_scolaire',
      "Un car scolaire renversé, à demi enseveli. Des cartables, des goûters momifiés... et un silence terrible.",
      _c("Fouiller les cartables", fx: {Stat.faim: 10, Stat.moral: -8}, result: "Des biscuits intacts dans une boîte. Tu manges en détournant les yeux des petits manteaux."),
      _c("Refermer la porte", fx: {Stat.moral: 5, Stat.faim: -3}, result: "Non. Pas celui-là. Tu repars le ventre vide, l'âme intacte.")),
  _filler('F7_neige_premiere',
      "Les premiers flocons. Pas encore le grand froid, mais l'avertissement. Le ciel a changé d'odeur.",
      _c("Stocker du bois maintenant", fx: {Stat.bois: 12, Stat.faim: -5}, result: "Tu ramasses tout ce qui brûle tant qu'il fait encore doux. Sage."),
      _c("Profiter des derniers jours doux", fx: {Stat.moral: 6, Stat.bois: -4}, result: "Tu t'accordes un dernier répit tiède. Le froid attendra un jour de plus.")),
];

final List<StoryCard> _fill8 = [
  // Cartes du FROID (déplacées depuis _fill6 : elles parlaient de givre/grand
  // froid alors qu'on était encore en zone tempérée). Ici = entrée zone froide.
  _filler('F8_givre',
      "Les premières fougères de givre couvrent les vitres. Le froid devient une menace réelle.",
      _c("Pousser le foyer pour devancer le froid", fx: {Stat.bois: -8, Stat.moral: 5}, result: "Un cocon de chaleur. Tu entames sérieusement la réserve."),
      _c("Rationner le bois", fx: {Stat.moral: -5, Stat.faim: -3}, result: "Tu claques des dents pour garder du combustible. Long.")),
  _filler('F8_manteau',
      "Un manteau de laine épais dans une malle. Le froid mord pour de bon — mais il sent le moisi, peut-être la maladie.",
      _c("L'enfiler quand même", fx: {Stat.moral: 7, Stat.faim: -4}, result: "Au chaud, mais une toux s'installe. Le corps lutte."),
      _c("Le brûler par prudence", fx: {Stat.bois: 5, Stat.moral: -3}, result: "Une flambée, et tant pis pour la chaleur durable.")),
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
  _filler('F8_chien_froid',
      "Le chien claque des dents, le museau givré. Le froid le prend plus vite que toi.",
      _c("Le glisser sous ta couverture", fx: {Stat.moral: 9, Stat.soif: -4}, result: "Il se love contre ton ventre. Vous tremblez moins, à deux."),
      _c("Le coucher près du foyer", fx: {Stat.bois: -6}, result: "Tu pousses le feu rien que pour lui. La réserve baisse, mais il dort enfin."),
      requires: (f) => f.contains('aLeChien')),
  _filler('F8_soeur_cache',
      "Ta sœur ne se plaint jamais, mais ses doigts sont blancs. Elle te cache qu'elle a froid, pour ne pas t'inquiéter.",
      _c("Lui frictionner les mains", fx: {Stat.moral: 10, Stat.faim: -3}, flags: ['soeurProtegee'], result: "Tu souffles sur ses doigts jusqu'à ce qu'ils rosissent. Elle sourit, coupable et heureuse."),
      _c("Lui apprendre les gestes du froid", fx: {Stat.moral: 4}, result: "Tu lui montres comment se couvrir. Elle apprend vite. Trop vite pour son âge."),
      requires: (f) => f.contains('aLaSoeur')),
  _filler('F8_loup_blanc',
      "Un loup arctique, splendide, marche un moment à hauteur du wagon. Il ne menace pas. Il accompagne.",
      _c("Lui parler doucement", fx: {Stat.moral: 8}, result: "« Toi aussi tu cherches les tiens ? » Il file enfin, comme un esprit du froid."),
      _c("Le tenir en joue", fx: {Stat.moral: -3, Stat.faim: 4}, result: "Tu ne tires pas, mais tu restes tendue. Il s'éloigne, déçu peut-être.")),
  _filler('F8_geyser',
      "Un geyser d'eau chaude perce la neige. Eau et chaleur d'un coup — mais s'arrêter en terrain exposé.",
      _c("Faire le plein d'eau chaude", fx: {Stat.soif: 16, Stat.bois: 4}, result: "De l'eau brûlante plein les jarres : à boire ET à chauffer. Une aubaine fumante."),
      _c("Ne pas t'exposer", fx: {Stat.moral: 2}, result: "Trop à découvert. Tu renonces à la manne et tu files.")),
  _filler('F8_borne',
      "Une borne kilométrique givrée : le nord se rapproche. Mais un thermomètre peint à côté annonce -30 plus haut.",
      _c("T'endurcir mentalement", fx: {Stat.moral: 6, Stat.faim: -4}, result: "Tu te prépares au pire. Mieux vaut une peur lucide qu'un espoir naïf."),
      _c("Ne pas regarder le chiffre", fx: {Stat.moral: -3}, result: "Tu détournes les yeux du -30. Certaines vérités gèlent le courage.")),
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
  _filler('F9_radio_maman',
      "La radio crache une dernière fois, limpide cette fois : « ...ma puce, si tu m'entends, continue. Maman t'attend. » La voix se brise. C'était... maman.",
      _c("Hurler de joie et de larmes", fx: {Stat.moral: 14, Stat.faim: -4}, flags: ['radio3'], result: "Maman. C'est maman ! Vivante, là-haut, et elle t'appelle par ton surnom. Plus rien ne pourra t'arrêter."),
      _c("Ne pas y croire, par peur", fx: {Stat.moral: 4}, result: "Et si c'était un vieux message en boucle ? Tu n'oses pas espérer si fort — tu éteins avant que ça te brise. Tu avanceras quand même, mais sans cette certitude au cœur."),
      oneshot: true,
      requires: (f) => f.contains('radio2') && !f.contains('radio3')),
  _filler('F9_soeur_doute',
      "En pleine tempête, ta sœur murmure : « Et si on n'y arrive pas ? » Pour la première fois, elle doute tout haut.",
      _c("Lui mentir avec douceur", fx: {Stat.moral: 8, Stat.faim: -3}, result: "« On y arrivera. Promis. » Elle te croit. Tu te forces à te croire aussi."),
      _c("Lui dire la vérité, et l'espoir", fx: {Stat.moral: 5}, flags: ['soeurProtegee'], result: "« Je ne sais pas. Mais je ne te lâcherai jamais. » Elle serre ta main plus fort."),
      requires: (f) => f.contains('aLaSoeur')),
  _filler('F9_congere',
      "Une congère barre la voie, plus haute que le wagon. La percer au chasse-neige de la loco, ou la pelleter ?",
      _c("Charger au chasse-neige", fx: {Stat.bois: -12, Stat.moral: 4}, result: "La loco mugit et fend le mur blanc. Spectaculaire, et coûteux en feu."),
      _c("Pelleter des heures", fx: {Stat.faim: -10, Stat.soif: -6}, result: "À la pelle, dans le vent qui coupe. Tu passes, vidée jusqu'à l'os.")),
  _filler('F9_foyer_eteint',
      "Tu te réveilles : le foyer s'est éteint dans la nuit. Le froid s'est glissé partout. Il faut tout relancer, vite.",
      _c("Brûler du mobilier pour repartir", fx: {Stat.bois: 14, Stat.moral: -5}, result: "Tu casses une étagère, tu rallumes. Le wagon revit, plus nu."),
      _c("Souffler les braises mourantes", fx: {Stat.faim: -8, Stat.moral: 3}, result: "À genoux, tu ranimes une braise à bout de souffle. Ça repart, de justesse.")),
  _filler('F9_repere',
      "Le blizzard a tout effacé. Plus un repère. Avancer dans le blanc, ou attendre qu'un détail émerge ?",
      _c("Avancer dans l'inconnu", fx: {Stat.moral: -4, Stat.bois: -5}, result: "Tu roules dans une page vierge, le doute au ventre. Un détour involontaire, peut-être."),
      _c("Attendre un repère", fx: {Stat.faim: -6}, result: "Tu attends qu'un poteau, un toit, quelque chose perce le blanc. Le temps gèle avec toi.")),
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
      "Dernière nuit calme avant le grand froid. Veiller sous les étoiles, ou dormir pour être prête ?",
      _c("Compter les étoiles comme avant", fx: {Stat.moral: 9, Stat.faim: -3}, result: "La Grande Ourse, qui ramène à la maison, disait ta sœur. Tu veilles tard."),
      _c("Dormir pour récupérer", fx: {Stat.moral: 4, Stat.faim: 4}, result: "Un sommeil profond. Demain sera rude, tu seras prête.")),
  _filler('F10_soeur_fleur',
      "Ta sœur cueille une fleur dans la serre et te la glisse dans les cheveux. « T'es belle, même en hiver. »",
      _c("Garder la fleur précieusement", fx: {Stat.moral: 12}, result: "Tu la presses dans ton carnet. Une couleur à emporter dans le grand blanc."),
      _c("La lui rendre en riant", fx: {Stat.moral: 9, Stat.faim: 3}, result: "Vous vous décorez mutuellement de pétales. Un moment volé hors du temps."),
      requires: (f) => f.contains('aLaSoeur')),
  _filler('F10_chien_herbe',
      "Le chien se roule dans l'herbe tiède de la serre, fou de joie, comme un chiot redevenu chiot.",
      _c("Jouer avec lui", fx: {Stat.moral: 10, Stat.faim: -3}, result: "Vous courez entre les plants. Son bonheur est contagieux, guérisseur."),
      _c("Le regarder, attendrie", fx: {Stat.moral: 6}, result: "Tu t'assois et tu le regardes vivre. Ça suffit, parfois, au bonheur."),
      requires: (f) => f.contains('aLeChien')),
  _filler('F10_graines_rares',
      "Des semences rares, étiquetées à la main : tomates, courges, herbes. Un trésor pour qui voudrait recommencer à vivre.",
      _c("Tout emporter pour plus tard", fx: {Stat.faim: 6, Stat.moral: 6}, result: "De quoi faire pousser un avenir, si avenir il y a."),
      _c("En semer ici, pour les suivants", fx: {Stat.moral: 9, Stat.faim: -2}, result: "Tu plantes pour des inconnus de demain. Un pari gratuit sur le futur du monde.")),
  _filler('F10_bassin',
      "Un bassin d'irrigation, eau claire et tiède. Ton reflet a meilleure mine ici, presque humain.",
      _c("Te baigner longuement", fx: {Stat.moral: 11, Stat.soif: 6, Stat.bois: -4}, result: "L'eau tiède dénoue des mois de tension. Tu renais un peu."),
      _c("Juste remplir les jarres", fx: {Stat.soif: 12}, result: "Tu fais le plein et tu files. Le luxe, ce sera pour une autre fois.")),
  _filler('F10_rester',
      "La serre est sûre, chaude, nourricière. Une voix en toi murmure : pourquoi continuer ? Pourquoi ne pas vivre ici, simplement ?",
      _c("Tenir le cap du nord", fx: {Stat.moral: 6, Stat.faim: -4}, result: "« Parce qu'ils nous attendent. » Tu refermes la serre derrière vous, le cœur lourd mais droit."),
      _c("T'attarder encore un peu", fx: {Stat.moral: -3, Stat.faim: 8}, result: "Tu restes un jour de plus. Puis un autre. Le confort est un piège très doux.")),
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
  _filler('F11_radio_muette',
      "Tu tournes la manivelle, encore et encore. Mais la fréquence de maman est muette, désormais. Juste le souffle du vide.",
      _c("Continuer d'appeler", fx: {Stat.moral: -4, Stat.soif: -3}, result: "« Maman ? Maman ?! » Rien. Mais tu sais qu'elle est là. Tu le sais."),
      _c("Économiser, garder espoir", fx: {Stat.moral: 5}, result: "Tu ranges la radio. Le silence ne veut pas dire l'absence. Tu y crois dur."),
      requires: (f) => f.contains('radio3')),
  _filler('F11_soeur_pierre',
      "Ta sœur, qui tremblait il y a peu, te tend une pierre : « Apprends-moi. Si les méchants reviennent, je veux t'aider. »",
      _c("Lui apprendre à viser", fx: {Stat.moral: 9, Stat.faim: -3}, result: "Vous vous entraînez sur des boîtes. Elle a la rage de vivre. Ça fait peur, et fierté."),
      _c("La protéger de tout ça", fx: {Stat.moral: 3}, result: "« Ton boulot, c'est d'être une enfant. Le mien, de te protéger. » Elle boude, secrètement rassurée."),
      requires: (f) => f.contains('aLaSoeur')),
  _filler('F11_pont_coupe',
      "Le pont devant est à moitié effondré. Un saut de quelques mètres manque. Élan maximal, ou demi-tour ?",
      _c("Tout miser sur l'élan", fx: {Stat.bois: -14, Stat.moral: -6}, result: "La loco bondit par-dessus le vide. Atterrissage brutal, boulons arrachés. Mais passé !"),
      _c("Chercher un autre passage", fx: {Stat.faim: -8, Stat.bois: -6}, result: "Long détour par la vallée gelée. Plus sûr, mais ça mange tout.")),
  _filler('F11_feu_lointain',
      "Un grand feu brûle au loin, régulier : un signal. Amis qui guident, ou pillards qui appâtent ?",
      _c("T'en approcher prudemment", fx: {Stat.faim: 10, Stat.moral: -6}, result: "Des survivants accueillants, cette fois. Vivres et chaleur — méfiance récompensée."),
      _c("T'en tenir loin", fx: {Stat.moral: 3, Stat.faim: -3}, result: "Tu as trop vu de pièges. Tu contournes la lueur sans un regard.")),
  _filler('F11_rodeurs',
      "Au matin, des traces dans la neige : quelqu'un a tenté de forcer le wagon dans la nuit. Rien volé — mais ils savent où tu es.",
      _c("Doubler les tours de garde", fx: {Stat.moral: -4, Stat.faim: -3}, result: "Tu dors d'un œil, arme à la main. Épuisant, mais nul ne t'aura par surprise."),
      _c("Repartir sur-le-champ", fx: {Stat.bois: -8, Stat.moral: 3}, result: "Tu files dans la nuit sans demander ton reste. Le bois brûle, mais tu sèmes la menace.")),
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
  _filler('F12_radio_derniere',
      "Tout près du but, la radio renaît une seconde : « ...je les vois... mon Dieu, c'est elle... » puis le grésillement avale tout. Quelqu'un, là-haut, vous a peut-être aperçues.",
      _c("Répondre dans le micro", fx: {Stat.moral: 13, Stat.bois: -3}, result: "« On arrive ! Tenez bon ! » Tu ne sais pas si ça émet. Mais tu l'as crié, et ça compte."),
      _c("Foncer sans répondre", fx: {Stat.moral: 8, Stat.bois: -5}, result: "Pas le temps des mots. Tu pousses la loco vers les fumées. Les actes, maintenant."),
      requires: (f) => f.contains('radio3')),
  _filler('F12_soeur_promesse',
      "Du haut de la tour, ta sœur fixe les fumées du refuge. « Quand on les aura retrouvés... on arrête de courir, hein ? On reste. »",
      _c("Le lui promettre", fx: {Stat.moral: 12}, result: "« On reste. Pour toujours. » Tu scelles la promesse d'un crachat dans la paume, comme avant."),
      _c("Ne rien promettre que tu ne tiendras", fx: {Stat.moral: 5}, result: "« On verra ce que le monde nous laisse. » Elle hoche la tête, mûre malgré elle."),
      requires: (f) => f.contains('aLaSoeur')),
];

// Gare 13 — Fubuki, le col gelé : la loco menace de lâcher, le froid est
// absolu, il faut tout donner. (Avant : aucun filler -> climax vide.)
final List<StoryCard> _fill13 = [
  _filler('F13_souffle',
      "La loco tousse, crache une vapeur noire. Le manomètre plonge. Elle n'aime pas cette pente, ce froid, ce poids.",
      _c("La ménager, ralentir", fx: {Stat.bois: 6, Stat.moral: -5}, result: "Tu coupes la vapeur, tu pries. Elle tient, de justesse, mais chaque mètre est une éternité."),
      _c("La pousser à fond", fx: {Stat.bois: -12, Stat.moral: 6}, result: "Tu enfournes tout. La loco rugit, crache le feu, et arrache la pente d'un coup. Brûlant, mais glorieux.")),
  _filler('F13_blizzard',
      "Un blizzard efface le monde. Tu ne vois plus les rails. Avancer à l'aveugle, ou attendre que ça passe ?",
      _c("Avancer à l'aveugle", fx: {Stat.moral: -6, Stat.soif: -4}, result: "Tu devines la voie au son des roues. Terrifiant, mais tu gagnes du terrain."),
      _c("Attendre la fin du blizzard", fx: {Stat.bois: -8, Stat.faim: -6}, result: "Tu te terres, le poêle dévorant le bois pour ne pas geler. L'attente coûte cher.")),
  _filler('F13_soeur_gel',
      "Ta sœur grelotte, les lèvres bleues. Le wagon ne tient plus la chaleur.",
      _c("Lui donner ton manteau", fx: {Stat.moral: 10, Stat.soif: -4}, flags: ['soeurProtegee'], result: "Tu grelottes à sa place. Elle s'endort contre toi, au chaud. Ça en vaut chaque frisson."),
      _c("Tout brûler pour chauffer", fx: {Stat.bois: -14, Stat.moral: 5}, flags: ['soeurProtegee'], result: "Tu nourris le poêle jusqu'à ce qu'elle cesse de trembler. Le bois fond, mais elle respire."),
      requires: (f) => f.contains('aLaSoeur')),
  _filler('F13_sacrifice',
      "Plus assez de bois pour le sommet. Il reste le mobilier du wagon, et le vieux carnet où tu notes tout depuis le départ.",
      _c("Brûler les meubles", fx: {Stat.bois: 14, Stat.moral: -6}, result: "Le wagon se vide, nu et froid, mais la loco repart. Le confort contre l'avenir."),
      _c("Brûler le carnet", fx: {Stat.bois: 8, Stat.moral: -12}, result: "Tu regardes tes mots noircir : les morts, les gares, les espoirs. Tout part en fumée, et la loco grimpe.")),
  _filler('F13_verglas',
      "La descente est pire que la montée : du verglas plein les rails, le wagon qui chasse à chaque courbe. Un faux mouvement et tout déraille.",
      _c("Freiner par à-coups, millimètre par millimètre", fx: {Stat.soif: -6, Stat.moral: 6}, result: "Les mains crispées sur le frein des heures durant. Mais vous tenez la voie. Vivantes."),
      _c("Lester l'arrière avec ce qui reste", fx: {Stat.bois: -6}, result: "Tu cales du poids sur les essieux arrière. Le wagon mord mieux les rails. Ça passe.")),
  _filler('F13_main_gelee',
      "Ta sœur a une main bleuie par le froid, à force de s'agripper à la rambarde. Elle ne se plaint pas — c'est ça qui te serre le cœur.",
      _c("Réchauffer ses doigts dans les tiennes", fx: {Stat.moral: 10}, flags: ['soeurProtegee'], result: "Tu souffles sur ses petits doigts, tu les frottes. Elle sourit faiblement. La couleur revient."),
      _c("Lui céder ta place près du poêle", fx: {Stat.moral: 8, Stat.soif: -4}, flags: ['soeurProtegee'], result: "Tu prends le froid à sa place, sans un mot. Elle s'endort enfin au chaud."),
      requires: (f) => f.contains('aLaSoeur')),
];

// Gare 14 — Hokuto, le refuge : l'arrivée, le quai, les visages. Le moment
// que tout le voyage préparait. (Avant : aucun filler.)
final List<StoryCard> _fill14 = [
  _filler('F14_fumees',
      "Les fumées du refuge montent droites dans l'air glacé. Des toits, des lumières, des gens. Vivants.",
      _c("Accélérer vers elles", fx: {Stat.bois: -4, Stat.moral: 12}, result: "Tu ne sens plus la fatigue. La loco file vers la chaleur des autres."),
      _c("Ralentir, savourer", fx: {Stat.moral: 9}, result: "Tu veux garder ce moment : le dernier où tout est encore possible, où ils sont peut-être tous là.")),
  _filler('F14_seuil',
      "Le train ralentit le long d'un quai bondé. Des dizaines de visages se tournent vers toi. Le cœur te manque : et s'ils n'étaient pas parmi eux ?",
      _c("Descendre la tête haute", fx: {Stat.moral: 10}, result: "Quoi qu'il arrive, tu les as menées jusqu'ici. Tu poses le pied sur le quai."),
      _c("Chercher déjà des yeux", fx: {Stat.moral: 6, Stat.soif: -3}, result: "Tu scrutes chaque visage, le souffle court, avant même que le train ne s'arrête.")),
  _filler('F14_soeur_seuil',
      "Ta sœur serre ta main à la broyer. « Et s'ils ne sont pas là ? » Sa voix tremble de la même peur que la tienne.",
      _c("« Alors on les cherchera. Ensemble. »", fx: {Stat.moral: 12}, flags: ['soeurProtegee'], result: "Elle hoche la tête. Tant que vous êtes deux, rien n'est tout à fait perdu."),
      _c("La serrer sans un mot", fx: {Stat.moral: 8}, flags: ['soeurProtegee'], result: "Pas besoin de mots. Vos deux peurs, à parts égales, et vos deux courages."),
      requires: (f) => f.contains('aLaSoeur')),
  _filler('F14_dernieres_braises',
      "Le foyer de la loco n'a plus qu'une poignée de braises. Juste assez pour les derniers kilomètres — ou pour s'arrêter net à la vue du but.",
      _c("Tout donner dans la dernière ligne", fx: {Stat.bois: -10, Stat.moral: 10}, result: "Tu jettes les ultimes bûches. La loco bondit vers les fumées. Advienne que pourra."),
      _c("Économiser, glisser en roue libre", fx: {Stat.moral: 4}, result: "Tu coupes la vapeur et laisses la pente vous porter. Lentement, sûrement, vers le quai.")),
  _filler('F14_quai_visages',
      "Le quai défile au ralenti. Des dizaines de visages se tournent vers le train. Aucun, pour l'instant, n'est celui que tu cherches.",
      _c("Scruter chaque visage, le cœur battant", fx: {Stat.moral: 6, Stat.soif: -3}, result: "Tu dévisages la foule, le souffle court. Pas encore. Pas encore. Mais le quai est long."),
      _c("Garder les yeux sur la sortie", fx: {Stat.moral: 3}, result: "Tu fixes les portes du refuge. Si quelqu'un t'attend, c'est là qu'il sera. Tu avances.")),
  _filler('F14_chien_flaire',
      "Le chien dresse soudain les oreilles, le museau au vent, et se met à gémir vers la foule du quai, queue battante.",
      _c("Le suivre, il a peut-être senti quelqu'un", fx: {Stat.moral: 12}, result: "Tu te laisses tirer par la laisse improvisée. Un animal n'oublie jamais une odeur aimée..."),
      _c("Le calmer, ne pas trop espérer", fx: {Stat.moral: 4}, result: "« Doucement, mon grand. » Tu retiens ton propre élan, de peur d'avoir trop mal."),
      requires: (f) => f.contains('aLeChien')),
];


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
  Segment(gareCards: _gare13, fillerPool: _fill13, drawCount: 4),
  Segment(gareCards: _gare14, fillerPool: _fill14, drawCount: 4),
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
  // Fin SECRÈTE : tu as suivi la voix radio jusqu'au bout (radio3) ET réuni
  // toutes les conditions de la fin pleine -> tu apprends que la voix qui
  // t'a guidée était celle de maman.
  // Fin pleine (parents retrouvés) : il faut S'ÊTRE ENGAGÉ à les chercher
  // (capParents, gare 5) en plus du soin + moral élevé. Sans cet engagement,
  // même un excellent voyage donne 'ensemble' (tu as choisi de protéger ta
  // sœur plutôt que de courir après l'espoir) -> incarne le thème du jeu.
  final capParents = flags.contains('capParents');
  if (aSoeur && capParents && soin >= 2 && moral >= 65 && flags.contains('radio3')) {
    return 'secret';
  }
  if (aSoeur && capParents && soin >= 2 && moral >= 65) return 'famille';
  // Arriver AVEC la sœur = au moins 'ensemble' (vous y êtes, ensemble), quel
  // que soit le moral final. L'ancien seuil moral>=30 renvoyait 'abandon' pour
  // une joueuse arrivée vivante avec sa sœur -> incohérent (l'abandon, c'est
  // descendre en route). L'abandon ne vient plus QUE du moteur (moral -> 0 en
  // cours de voyage). Le cas !aSoeur est injoignable en jeu normal (G5 obligatoire).
  if (aSoeur) return 'ensemble';
  return 'abandon';
}

/// Textes des fins.
const Map<String, ({String title, String body})> endings = {
  'secret': (
    title: 'La voix retrouvée',
    body:
        "Sur le quai bondé du refuge, une femme se retourne, une radio à manivelle encore serrée contre elle. Elle vous cherchait sur les ondes depuis des mois, lançant la même prière dans le vide.\n\nMaman. Elle vous étouffe toutes les deux dans ses bras, et derrière elle papa accourt en hurlant vos noms. La voix qui t'a guidée à travers le monde mort, nuit après nuit, c'était la sienne. Vous êtes rentrées. Vraiment, pleinement rentrées.",
  ),
  'famille': (
    title: 'Réunis',
    body:
        "Dans la foule du refuge, deux silhouettes se figent, puis se précipitent : vos parents. Ta sœur leur saute au cou en sanglotant. Vous y êtes. Tous. Ensemble.\n\nTu les as ramenés. Tu as tenu, de corps et d'âme, et le monde mort n'a pas gagné.",
  ),
  'ensemble': (
    title: 'Toutes les deux',
    body:
        "Le refuge grouille de monde. Vous scrutez les visages, un à un — vos parents ne sont pas dans cette première foule. Peut-être plus loin, peut-être demain : tu continueras de chercher.\n\nMais ta sœur est là, sa main dans la tienne, vivante. Vous êtes arrivées. Le reste, vous l'affronterez ensemble. C'est déjà une victoire.",
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

/// Mini-cinématique d'entrée en gare (version texte) : une ligne d'ambiance
/// affichée sous le bandeau "GARE N — Nom" à l'arrivée. Donne à chaque gare une
/// identité immédiate avant les cartes. Index 0-based (= gare N-1).
const List<String> kGareIntros = [
  "Kogarashi, ta ville. Ou ce qu'il en reste : un quai en ruines, des flammes au loin.", // 1 Kogarashi (ville natale)
  "Un dépôt de fret mort. Le fer rouille, la loco agonise.", //           2 Kurogane
  "Un brouillard épais avale les rails. Des ombres y fouillent les morts.", // 3 Karasuno
  "Un village fantôme. Des messages d'absents couvrent les murs.", //     4 Mayoidani
  "Un pont enjambe un fleuve noir. Une petite silhouette, dessus, t'attend.", // 5 Tsukibashi
  "Un camp de survivants : une frêle lueur de chaleur humaine.", //       6 Yasuragi
  "La halte de votre enfance. Les souvenirs remontent comme une marée.", // 7 Hoshikage
  "La brume se glace. Ici, le froid devient une bête vivante.", //        8 Kiribe
  "Un blizzard noie la plaine. Le monde se réduit à un wagon.", //        9 Shizuhara
  "Une oasis impossible : une serre tiède au cœur de la neige.", //       10 Hidamari
  "Un champ de neige barré. Des silhouettes attendent sur la voie.", //   11 Yukihara
  "Une tour de guet. De là-haut, on voit enfin le nord.", //             12 Miharashi
  "Le col gelé. La loco râle. C'est le dernier mur avant le refuge.", //  13 Fubuki
  "Le refuge du nord. Des toits, des fumées, des visages. Vivants.", //   14 Hokuto
];

/// Texte de fin ENRICHI dynamiquement selon les flags/le soin de la run :
///  - le chien (s'il est là) descend avec elles sur le quai (fins d'arrivée) ;
///  - le niveau de soin (`cardSoin`) colore les fins « famille »/« secret » ;
///  - les fins « mort »/« abandon » évoquent la sœur / le chien présents.
/// Garde la map `endings` comme base et n'AJOUTE que des lignes variantes.
({String title, String body}) endingText(String id) {
  final base = endings[id] ?? endings['ensemble']!;
  final gs = GameState.instance;
  final flags = gs.cardFlags;
  final soin = gs.cardSoin;
  final hasDog = flags.contains('aLeChien');
  final hasSister = flags.contains('aLaSoeur');
  var body = base.body;

  if (id == 'famille' || id == 'secret' || id == 'ensemble') {
    // Arrivée : le chien a traversé tout le voyage, lui aussi.
    if (hasDog) {
      body +=
          "\n\nÀ vos pieds, le chien tourne en rond en jappant, fou de joie. Lui aussi est arrivé. Il n'a jamais lâché.";
    }
    // Granularité du soin : une protection sans faille se voit.
    if ((id == 'famille' || id == 'secret') && soin >= 6) {
      body +=
          "\n\nTu l'as protégée mille fois, à chaque gare, à chaque nuit. Elle le sait. Elle le saura toujours.";
    }
  } else if (id == 'mort') {
    if (hasSister) {
      body +=
          "\n\nTa sœur serre ta main glacée et refuse de la lâcher. « Réveille-toi. S'il te plaît, réveille-toi. »";
    } else if (hasDog) {
      body +=
          "\n\nLe chien se couche contre toi et gémit doucement, longtemps, dans le silence blanc.";
    }
  } else if (id == 'abandon') {
    if (hasSister) {
      body +=
          "\n\nDerrière la vitre, ta sœur te regarde t'éloigner sans comprendre. Tu détournes les yeux. C'est plus facile.";
    }
  }
  return (title: base.title, body: body);
}
