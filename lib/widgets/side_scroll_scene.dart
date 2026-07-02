import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../constants.dart' as consts;
import '../data/anim_metrics.dart';
import '../models/game_state.dart';
import 'atmosphere.dart';
import 'train_rocking.dart';

/// Largeur de décodage des sprites de PERSONNAGE (héroïne / sœur). Égale à la
/// résolution source des plus grands sprites (512 px) : pas de perte de qualité
/// (la fille est affichée grande, parfois upscalée), mais ça borne dur le
/// décodage et garantit une CLÉ DE CACHE COMMUNE entre le rendu et le précache
/// (loading_screen, main._warmLocoAnims). Sans clé commune, un sprite à la fois
/// préchargé et rendu serait décodé DEUX fois -> double empreinte mémoire (OOM).
const int kHeroDecodeWidth = 512;

/// Idem pour les sprites du CHIEN (512 px source, affiché petit) -> 256 suffit
/// largement et divise par 4 la RAM par frame. Doit matcher le précache du chien.
const int kDogDecodeWidth = 256;

/// Side-scroller wagon scene.
///
/// Composition (back to front):
///   1. Sky        — fixed full-frame, drifts very slowly to suggest cloud motion
///   2. Horizon    — slow-scrolling parallax layer (distant ruins)
///   3. Wagon      — fixed in the centre, dirty or clean variant
///   4. Heroine    — tap-to-walk left/right on the wagon floor
///   5. Foreground — fast-scrolling parallax layer (grass / debris / rails)
///   6. Smoke      — procedural particle trail from the locomotive
///
/// Everything except the wagon and the heroine scrolls horizontally. When
/// the train stops (no fuel) all parallax + smoke freezes via [running].
class SideScrollScene extends StatefulWidget {
  const SideScrollScene({
    super.key,
    this.wagonStage = 0,
    this.running = true,
    this.night = false,
    this.dancing = false,
    this.lieDownToken = 0,
    this.onUserInteract,
    this.onHeroXChanged,
    this.logsThrown = 0,
    this.doorPushToken = 0,
    this.doorPushRight = false,
    this.onDoorPushDone,
    this.onOpenWardrobe,
    this.dogHeight = 0.136,
    this.specialAnim,
    this.specialAnimFrames = 25,
    this.specialAnimLoops = false,
    this.specialAnimToken = 0,
    this.specialAnimNext,
    this.specialAnimNextFrames = 25,
    this.initialHeroX = 0.5,
    this.secondWagon = false,
    this.isAtelier = false,
    this.bathToken = 0,
    this.chairToken = 0,
    this.showerToken = 0,
    this.petDogToken = 0,
    this.duoToken = 0,
    this.duoAnim = 'readduo',
    this.cuisiniereToken = 0,
    this.poeleToken = 0,
    this.bacToken = 0,
    this.wagon2Adjust = false,
    this.wagon1Adjust = false,
    this.salonAdjust = false,
    this.onSisterX,
    this.onDogX,
    this.heroFloatToken = 0,
    this.heroFloatText = '',
  });

  /// Float ancré sur Shen, piloté depuis le parent (ex. boire au filtre depuis
  /// main.dart) : à chaque incrément de [heroFloatToken], le texte
  /// [heroFloatText] monte et s'efface au-dessus de sa tête.
  final int heroFloatToken;
  final String heroFloatText;

  /// Tap cuisinière : Shen se tourne, la cuisinière s'allume 5 s, puis elle
  /// mange au sol. Tap poêle : Shen se tourne, le poêle s'allume (bois qui
  /// descend doucement).
  final int cuisiniereToken;
  final int poeleToken;
  final int bacToken;

  /// Wagon visual progression, 0..3:
  ///   0 — dirty (initial discovery: trash, broken windows, scratches)
  ///   1 — swept (floor cleaned; walls + windows still wrecked)
  ///   2 — windowed (floor cleaned + windows put back; walls still rusty)
  ///   3 — clean (fully restored)
  final int wagonStage;

  /// `true` rend le **2e wagon** (cellier/stockage) : background dédié
  /// (`wagon2_messy`/`wagon2_clean` selon [wagonStage]) et tous les props de
  /// vie du 1er wagon masqués (lit, hydro, lampe, poêle, filtre, table,
  /// carnet, trousse, commode, gamelle, chien, sœur). Seule l'héroïne reste,
  /// avec son autonomie. La porte gauche y ramène au 1er wagon.
  final bool secondWagon;

  /// `true` rend l'ATELIER (wagon du milieu) : background `atelier_messy/clean`,
  /// objets fonctionnels (cuisinière, poêle, lampe, bac, filtre). Pas de
  /// compagnons ni de lit. Se comporte comme le salon pour le déplacement.
  final bool isAtelier;

  /// Incrémenté par le parent quand on appuie sur l'action "bain" (Shen est
  /// près de la baignoire). Lance le tour (use_back) puis l'anim de bain ;
  /// si elle est déjà dans le bain, la fait sortir.
  final int bathToken;
  final int chairToken;

  /// Idem pour la douche (près du panneau) : tour puis boucle de douche.
  final int showerToken;

  /// Incrémenté quand on caresse le chien (Shen près du husky) : joue le
  /// sprite petdog (Shen + husky).
  final int petDogToken;

  /// Déclenche un duo avec la sœur (test manuel via le bouton action) :
  /// [duoAnim] = 'readduo' (lecture) ou 'sister_hug' (câlin).
  final int duoToken;
  final String duoAnim;

  /// Position vivante de la sœur / du chien (ils se baladent) -> le parent
  /// l'utilise pour la proximité des actions (duo / caresse).
  final ValueChanged<double>? onSisterX;
  final ValueChanged<double>? onDogX;

  /// Mode "ajuster" du cellier : props déplaçables (drag) + redimensionnables
  /// (pincer) + HUD des coordonnées. Off = props figés (jeu normal).
  final bool wagon2Adjust;

  /// Mode "ajuster" du wagon 1 (debug) : lampe, bac de culture, filtre et poêle
  /// à bois deviennent déplaçables + redimensionnables. Off = figés.
  final bool wagon1Adjust;

  /// Mode "ajuster" du SALON (debug) : carnet, secours, gamelle, carte murale
  /// déplaçables + redimensionnables. Off = figés.
  final bool salonAdjust;

  /// When `false` all parallax + smoke animations freeze (the train stopped).
  /// The heroine can still walk — only the world stops moving.
  final bool running;

  /// `true` swaps in the night sky + horizon assets and applies a cool
  /// blue tint over the wagon and heroine so the whole scene reads as
  /// nighttime.
  final bool night;

  /// `true` puts the heroine in the dance loop (overrides idle / walk).
  /// Tapping the wagon floor cancels it and queues a walk to the tap.
  final bool dancing;

  /// Incremented by the parent every time the "lie down" button is
  /// pressed. The scene observes the change and plays the pickup
  /// frames in reverse so she bends over, then snaps into sleep.
  final int lieDownToken;

  /// Incremented by the parent when the door-action button is pressed
  /// to enter the locomotive. The scene plays the door_push animation
  /// once and calls [onDoorPushDone] when it finishes — at which point
  /// the parent transitions to the locomotive screen.
  final int doorPushToken;
  final bool doorPushRight;

  final VoidCallback? onDoorPushDone;

  /// Fired when the user taps the commode (wardrobe). The parent opens
  /// the full-screen outfit selector.
  final VoidCallback? onOpenWardrobe;

  /// Hauteur du chien en fraction de h (réglable via slider parent).
  final double dogHeight;

  /// Nom de l'anim spéciale (preset depuis le parent : 'drink', 'read',
  /// 'eat', 'use_back'…). Null = pas d'anim active.
  /// La scène lit `assets/characters/${specialAnim}_${frame+1}.png`.
  final String? specialAnim;
  /// Nombre de frames dans le PNG set.
  final int specialAnimFrames;
  /// True = boucle indéfinie, false = joue 1× puis retour à idle.
  final bool specialAnimLoops;
  /// Increment pour (re)déclencher la même anim.
  final int specialAnimToken;
  final String? specialAnimNext;
  final int specialAnimNextFrames;
  final double initialHeroX;

  /// Fired the first time the user taps the wagon floor, so the parent
  /// can drop any "she's dancing" state it was holding.
  final VoidCallback? onUserInteract;

  /// Fired every time the heroine's normalised X position changes. The
  /// parent uses it to enable/disable the door action button when she's
  /// at the left edge (locomotive door).
  final void Function(double heroX)? onHeroXChanged;

  /// Left bound for the heroine in normalised X. Exposed so the parent
  /// can compare against it to know when she's at the door (= porte
  /// gauche du wagon vers la locomotive). Source unique : constants.kHeroXMin.
  static const double heroXMin = consts.kHeroXMin;

  /// Right bound for the heroine in normalised X. Exposed so the parent
  /// can compare against it to know when she's at the right door
  /// (= ouverture sur la map du monde). Source unique : constants.kHeroXMax.
  static const double heroXMax = consts.kHeroXMax;

  /// Centre X normalisé du lit (fixe). Les AUTRES props interactifs sont
  /// déplaçables : leur zone de tap suit leur position réelle
  /// (GameState.salonProps / wagon1Props), plus de constantes figées.
  static const double bedCenterX = 0.334;

  /// Total logs thrown into the locomotive firebox so far. Scales the
  /// smoke density + speed-line intensity in this scene.
  final int logsThrown;

  @override
  State<SideScrollScene> createState() => _SideScrollSceneState();
}

class _SideScrollSceneState extends State<SideScrollScene>
    with TickerProviderStateMixin {
  // World-scroll controllers.
  late final AnimationController _horizon;
  late final AnimationController _mid;
  late final AnimationController _foreground;
  late final AnimationController _smoke;
  late final AnimationController _sky;

  // Heroine state. Position is normalised to the scene width. X bounds
  // keep her on the wagon's parquet floor — left of 0.25 is the
  // locomotive / coupling, right of 0.82 is the closed back-door area.
  static const int _heroFrameCount = 25;
  // Bornes héroïne : source unique = constants.dart (plus de valeur dupliquée).
  static const double _heroXMin = consts.kHeroXMin;
  static const double _heroXMax = consts.kHeroXMax;

  // Bornes de déplacement effectives. Dans le cellier (2e wagon) elle peut
  // s'approcher de la porte (gauche), et tant qu'il est EN DÉSORDRE
  // (wagonStage 0) elle ne peut pas avancer : le bazar la bloque près de
  // l'entrée. Une fois AMÉNAGÉ (stage >= 1) elle circule dans tout le wagon.
  // L'atelier a ses portes dessinées plus PRÈS DES BORDS que le salon ->
  // bornes élargies (sinon Shen s'arrête avant la porte gauche).
  // SALON (wagon 1) : bornes = _heroXMin/_heroXMax, ALIGNÉES sur les seuils de
  // détection de porte (`_atLeftDoor`/`_atRightDoor` dans main, à ±0.01 des
  // bords). Si on les resserre, Shen n'atteint plus les portes et ne peut plus
  // les ouvrir — NE PAS rétrécir le salon sans bouger aussi ces seuils.
  // ATELIER (wagon du milieu) : ses portes sont dessinées plus VERS L'INTÉRIEUR
  // que celles du salon. À 0.08/0.92 Shen montait carrément SUR les panneaux de
  // porte des deux côtés. On la cale juste au seuil d'ouverture (gauche ~0.23 /
  // droite ~0.85 dans main) sans déborder sur la porte. NE TOUCHE QUE l'atelier.
  double get _moveMin =>
      widget.secondWagon ? 0.15 : (widget.isAtelier ? 0.18 : _heroXMin);
  // Cellier : bornes resserrées (ne plus monter sur les portes G/D). On ouvre
  // l'accès dès que le cellier est aménagé (stage>=1) OU qu'un prop du fond
  // (bain/douche) est débloqué — sinon, débloqués avant l'aménagement (ou en
  // debug), bain (0.48) et douche (0.77) resteraient hors d'atteinte.
  double get _moveMax => widget.secondWagon
      ? ((widget.wagonStage >= 1 ||
              _propUnlocked('bath') ||
              _propUnlocked('shower'))
          ? 0.82
          : 0.30)
      : (widget.isAtelier ? 0.85 : _heroXMax);
  static const double _heroSpeed = 0.18; // normalised units / second
  static const int _walkFrameMs = 50;
  static const int _idleFrameMs = 80;
  static const int _sleepFrameMs = 110;
  static const int _danceFrameMs = 55;
  static const int _lieDownFrameMs = 60;

  // Bed object placement (normalised to scene size, mutable so the
  // adjustment mode can drag + resize it live). Defaults dialled in
  // via the adjust mode and baked back here.
  // COUCHAGE — deux états : PAILLASSE (paille au sol, dès G1) puis VRAI LIT
  // (`asset_realbed`, posé à G5 quand la sœur arrive). Le lit `bed.png` reprend
  // sa géométrie d'origine (plus haute) ; la paillasse est plate au sol. Tout
  // est enfoncé dans le wagon (au fond). La pose de sommeil suit `_bedTop`.
  bool get _realBed =>
      GameState.instance.debugMode ||
      GameState.instance.cardFlags.contains('asset_realbed');
  String get _bedAsset =>
      _realBed ? 'assets/objects/bed.png' : 'assets/objects/paillasse.png';
  final double _bedLeft = 0.205;
  double get _bedTop => _realBed ? 0.448 : 0.60; // paillasse descendue au SOL
  double get _bedWidth => _realBed ? 0.28 : 0.30;

  // When the heroine arrived at the bed via a double-tap on it, render
  // the sleep sprite ON the mattress (instead of on the floor). Offsets
  // are normalised to the scene size, position is relative to the
  // bed's centre/top so it stays glued to the bed as it moves.
  bool _sleepOnBed = false;
  final double _sleepBedOffsetX = 0.0;   // centré sur le centre du couchage
  double get _sleepBedOffsetY => _realBed ? 0.115 : 0.085; // lit haut / natte au sol
  final double _sleepBedScale = 0.34;    // longueur corps en fraction de h

  // Props installés dans le wagon — chaque entry contient sa position
  // (left/top centrés, normalisés) + sa hauteur en fraction de h.
  // NB : lampe, bac de culture (ex-hydro), filtre et poêle à bois sont des
  // props AJUSTABLES (position/taille réglables en debug) rendus à part via
  // _buildWagon1Adjustable — pas dans cette liste générique (figée).
  static final List<_PropDef> _propDefs = [
    const _PropDef('notebook', 'Carnet',    animated: false),
    // 'firstaid' (trousse) DÉPLACÉE dans le cellier (wagon 3), sur la commode.
    const _PropDef('bowl',     'Gamelle',   animated: false),
    // 'wallmap' (carte murale) RETIRÉ : la map vit désormais dans la loco.
    // Table de jeu : ÉCHANGÉE avec le tourne-disque (lui → atelier), pour que
    // playduo se joue au salon où vit la sœur.
    const _PropDef('jeu',      'Table de jeu', animated: false),
    const _PropDef('carillon', 'Carillon',  animated: true, frameCount: 13),
    const _PropDef('fauteuil', 'Fauteuil',  animated: false),
    const _PropDef('panier',   'Panier',    animated: false),
    // 'console' + 'tournedisque' vivent à l'atelier (_buildWagon1Adjustable).
  ];

  // Aspect RÉEL (largeur/hauteur en px) de chaque image d'objet salon. Sert à
  // dériver la largeur depuis la hauteur -> la boîte colle pile à l'objet
  // (aucun letterbox), identique en rendu normal ET en mode ajuster, sur tout
  // écran. La position stocke la HAUTEUR ; la largeur suit l'image.
  // NB : radio / console / tourne-disque sont à l'ATELIER (aspects codés en
  // dur dans _buildWagon1Adjustable) ; le bouquet (deco_fleurs) au CELLIER.
  static const Map<String, double> _salonAspect = {
    'notebook': 1.0, 'bowl': 1.0,
    'jeu': 1.179, 'carillon': 0.464, 'fauteuil': 1.031,
    'panier': 1.528,
    'deco_photo': 0.863, 'deco_peluche': 0.780,
  };

  // Positions de repli des props SALON (les vraies coords vivent dans
  // GameState.salonProps, réglables en debug). Seules les clés de _propDefs
  // sont consommées ici (fallback de _buildProp / _buildCharAtProp).
  final Map<String, _PropPos> _propPos = {
    'notebook': _PropPos(0.265, 0.666, 0.070),
    'bowl':     _PropPos(0.382, 0.665, 0.080),
    'jeu':      _PropPos(0.548, 0.560, 0.160, 0.19),
    // Carillon : suspendu en haut (top bas = près du plafond), étroit et haut.
    'carillon': _PropPos(0.726, 0.314, 0.131, 0.067),
    // Fauteuil de lecture (salon) : meuble au sol.
    'fauteuil': _PropPos(0.794, 0.494, 0.245),
    // Panier du chien (salon) : posé au sol, bas et large.
    'panier':   _PropPos(0.670, 0.625, 0.106, 0.152),
  };

  // Gamelle double : true = pleine (eau + bouffe), false = vide. Tap
  // pour la remplir, Plume passe à empty quand elle vient de manger.
  bool _bowlFull = true;

  // Niveau visuel du filtre (0..GameState.waterTankFrames-1).
  // Animé temporairement lors du remplissage / descente lors d'un verre.
  double _filterDisplayLevel = 0;
  AnimationController? _filterFillCtrl;

  // Le chien a sa propre state machine. Sa hauteur vient du parent
  // (slider live), son Y reste fixe, son X glisse quand il marche.

  // Horizon (middle background) clipping bounds — both are fractions
  // of the scene height. `_horizonTop` is the distance from the very
  // top of the frame, `_horizonBottom` is the distance from the very
  // bottom. Defaults dialled in via the horizon adjust mode.
  final double _horizonTop = 0.0;
  final double _horizonBottom = 0.179;

  static const List<String> _horizonWarm = [
    'assets/background/horizon_a.png',
    'assets/background/horizon_b.png',
    'assets/background/horizon_c.png',
  ];
  static const List<String> _horizonCold = [
    'assets/background/horizon_snow_a.png',
    'assets/background/horizon_snow_b.png',
    'assets/background/horizon_snow_c.png',
    'assets/background/horizon_snow_d.png',
    'assets/background/horizon_snow_e.png',
    'assets/background/horizon_snow_f.png',
    'assets/background/horizon_snow_g.png',
  ];
  static const List<String> _horizonTransition = [
    'assets/background/horizon_transition_a.png',
    'assets/background/horizon_transition_b.png',
    'assets/background/horizon_transition_c.png',
    'assets/background/horizon_transition_d.png',
  ];

  List<String> get _horizonAssets {
    final zone = GameState.instance.trainZone;
    switch (zone) {
      case TrainZone.cold:
        return _horizonCold;
      case TrainZone.warm:
        return _horizonWarm;
      case TrainZone.transitionToWarm:
        // Quitter le froid : neige dominante → terre dominante.
        return _horizonTransition;
      case TrainZone.transitionToCold:
        // Entrer dans le froid : terre dominante → neige dominante.
        return _horizonTransition.reversed.toList();
    }
  }

  String get _foregroundAsset {
    if (GameState.instance.inColdZone) {
      return 'assets/background/foreground_snow.png';
    }
    return 'assets/background/foreground_band.png';
  }

  static const Duration _horizonRotatePeriod = Duration(seconds: 45);
  static const Duration _horizonCrossFade = Duration(seconds: 2);
  int _horizonIndex = 0;
  Timer? _horizonRotateTimer;
  TrainZone? _lastZone;

  late final Ticker _heroTicker;
  // Pilote les frames de l'héroïne SANS reconstruire toute la scène. Le
  // cluster héroïne (sprite + halo + poussière + bulle) écoute ce notifier ;
  // _onHeroTick le bump à chaque frame au lieu d'un setState global (qui
  // reconstruisait parallax + props + atmosphère 60×/s = saccades).
  final ValueNotifier<int> _heroAnim = ValueNotifier<int>(0);
  // Spawn clampé aux bornes du wagon (sinon, au retour de la map, elle
  // apparaissait à 0.86 = au bord du salon).
  late double _heroX = widget.initialHeroX.clamp(_moveMin, _moveMax);
  double? _heroTarget;
  // She has only two facing options: the walk_right sheet, or its
  // horizontal mirror for going left.
  bool _heroFacingRight = true;
  bool _heroSleeping = false;
  bool _heroDancing = false;
  // When set, the next walk-arrival auto-triggers a lie-down (used by
  // the double-tap-on-bed handler so she walks over before lying down).
  bool _walkingToBed = false;
  // Lie-down transition: plays pickup frames in reverse (upright → bent
  // over), then snaps into the sleep loop on the floor.
  bool _heroLyingDown = false;
  int _lieDownFrame = _heroFrameCount - 1; // counts down toward 0
  int _walkFrame = 0;
  // Occasional thought-bubble emoji shown above the heroine. Picked at
  // random every ~60 s while idle, cleared after a couple of seconds.
  String? _thoughtEmoji;
  Timer? _thoughtTimer;
  Timer? _thoughtClearTimer;
  // Vérifie fréquemment (6 s) si un besoin de confort est CRITIQUE (<20) : si
  // oui, FORCE la bulle 💤/🛁 sans attendre le tirage aléatoire (28 s), pour
  // que le joueur voie quoi faire. N'écrase pas une bulle déjà affichée.
  Timer? _needBubbleTimer;
  int _idleFrame = 0;
  // (Autonomie idle DÉSACTIVÉE : plus de pause yawn/look_window. Les champs
  // _idleBreak*/_idleStillMs ont été retirés — code mort.)

  // Bain (cellier) : après s'être tournée (use_back), Shen entre dans le bain.
  // L'anim bath_1..8 (qui contient sa propre cuve) remplace l'héroïne + la
  // baignoire statique. On joue 1->8 (entrée->détente) puis on tient la 8.
  bool _bathing = false;
  bool _pendingBath = false; // use_back en cours, le bain suit
  // Fauteuil de lecture (salon) : tap -> Shen s'installe et lit (chair_read,
  // 6f, qui contient son propre fauteuil). Remplace l'héroïne + le fauteuil
  // statique pendant ~_chairTotalMs, puis on revient au solo.
  bool _chairReading = false;
  Timer? _chairTimer;
  static const int _chairTotalMs = 6500;
  // La nuit, si le panier est débloqué, le chien va y dormir (dog_basket, qui
  // contient son propre panier) -> remplace le chien mobile + le panier vide.
  bool get _dogInBasket =>
      widget.night && _dogShown && _propUnlocked('panier');
  int _bathFrame = 0;
  bool _bathHeld = false;
  int _bathAccumMs = 0;
  static const int _bathFrameMs = 210; // entrée bien plus lente, posée
  static const int _bathFrames = 8;
  double _scaleStartH = 0; // hauteur capturée au début d'un pincer (ajuster)
  // Objet sélectionné dans le HUD d'ajuster (tap sur sa ligne) : piloté par
  // le pad ◀▶▲▼/−＋ — indispensable pour les objets trop petits à pincer ou
  // hors d'atteinte au doigt.
  String? _adjSel;

  // Douche (cellier) : Shen se tourne (use_back) puis se lave les cheveux
  // sous le pommeau, derrière le panneau. shower_1..8 en BOUCLE (+moral).
  bool _showering = false;
  bool _pendingShower = false;
  int _showerFrame = 0;
  int _showerAccumMs = 0;
  static const int _showerFrameMs = 280; // bien plus lent (shampoing posé)
  static const int _showerWashCyclesMax = 3; // nb de boucles de lavage
  bool _showerWashed = false; // lavage fini -> tient la pose propre
  int _showerWashCycles = 0;
  int _showerWaterTick = 0; // l'eau coule en continu pendant la douche

  // Duos sœur+Shen (wagon 1) : lecture (readduo, 10f) ou câlin (sister_hug,
  // 16f). Déclenchés quand Shen est près de la sœur ; les 2 solos
  // disparaissent. L'anim BOUCLE pendant _duoTotalMs puis les solos reviennent.
  double _sisterX = 0.33; // position vivante de la sœur (màj quand elle marche)
  bool _duoActive = false;
  String _duoAnim = 'readduo';
  int _duoFrame = 0;
  int _duoAccumMs = 0;
  int _duoElapsedMs = 0;
  // lecture/jeu plus lents que le câlin.
  int get _duoFrameMs => _duoAnim == 'sister_hug' ? 300 : 430;
  static const int _duoTotalMs = 6000;
  int get _duoFrames => _duoAnim == 'sister_hug'
      ? 4
      : _duoAnim == 'playduo'
          ? 10
          : 10; // readduo
  double get _duoAspect => _duoAnim == 'sister_hug'
      ? 260 / 301
      : _duoAnim == 'playduo'
          ? 279 / 262
          : 290 / 312; // readduo
  double get _duoHeightFrac => _duoAnim == 'sister_hug'
      ? 0.27
      : _duoAnim == 'playduo'
          ? 0.23
          : 0.20; // readduo

  void _startDuo(String anim) {
    setState(() {
      _duoActive = true;
      _duoAnim = anim;
      _duoFrame = 0;
      _duoAccumMs = 0;
      _duoElapsedMs = 0;
      _heroTarget = null;
    });
  }

  // Caresse du chien (Shen + husky, sprite petdog 8 frames) au niveau du
  // chien statique. Remplace solo Shen + chien statique pendant l'anim.
  double _dogX = 0.525; // position vivante du chien (màj quand il marche)
  bool _petDog = false;
  int _petDogFrame = 0;
  int _petDogAccumMs = 0;
  int _petDogElapsedMs = 0;
  static const int _petDogFrameMs = 340; // bien plus lent
  static const int _petDogTotalMs = 6000;
  // 9 frames coupées aux traits rouges : approche (1-3) -> câlin (4-9).
  static const int _petDogFrames = 9;

  // Wake-up sequence: triggered when the player taps while she's
  // sleeping. Plays wake_up_* (sit up → stand) then stretch_* (arms
  // up → arms down), then she's free to walk wherever the tap pointed.
  bool _waking = false;
  int _wakingPhase = 0; // 0 = wake_up, 1 = stretch
  int _wakingFrame = 0;
  int _wakingAccumMs = 0;
  static const int _wakingFrameMs = 55;

  // Anim spéciale en cours (drink, read, cook, pet_dog, garden_tend).
  // Pilotée par le parent via specialAnim + specialAnimToken.
  String? _activeSpecial;
  int _activeSpecialFrames = 25;
  bool _activeSpecialLoops = false;
  int _specialFrame = 0;
  int _specialAccumMs = 0;
  static const int _specialFrameMs = 70;
  // Optional follow-up anim that plays right after the current special
  // ends — used to chain "turn back" + "drink" at the filter.
  String? _nextSpecial;
  int _nextSpecialFrames = 25;

  // Cuisinière : allumée (feu animé en boucle) ou éteinte. _fireLoop fait
  // vaciller les flammes (poêle ET cuisinière).
  bool _cookLit = false;
  // True pendant toute la séquence de cuisine : bloque le déplacement de Shen.
  bool _cooking = false;
  AnimationController? _fireLoop;
  Timer? _cookT1, _cookT2, _cookT3, _cookT4;
  // Bac de culture : pousse (0..1) en 20 s une fois semé, puis récolte.
  bool _bacGrowing = false;
  Timer? _bacTimer;
  String? _bacFloat; // texte flottant ("Semé 🌱" / "+10")
  double _bacFloatT = 0; // 1 -> 0 (fondu/montée)
  // Float ANCRÉ SUR LA HÉROÏNE : retour d'effet d'action (manger/boire/laver…)
  // ou refus explicite (pas de bois/eau, trop froid). Monte + s'efface.
  String? _heroFloat;
  double _heroFloatT = 0; // 1 -> 0
  Timer? _heroFloatTimer;
  Timer? _bacFloatTimer;

  // Door-push: short one-shot animation played when entering the
  // locomotive. Fires onDoorPushDone when complete.
  bool _doorPushing = false;
  bool _doorPushRight = false;
  int _doorFrame = 0;
  int _doorAccumMs = 0;
  static const int _doorFrameMs = 50;
  static const int _doorMaxFrames = 20;
  int _sleepFrame = 0;
  int _danceFrame = 0;
  Duration _lastTick = Duration.zero;
  int _walkAccumMs = 0;
  int _idleAccumMs = 0;
  int _sleepAccumMs = 0;
  int _danceAccumMs = 0;
  int _lieDownAccumMs = 0;

  @override
  void initState() {
    super.initState();
    // Cycle durations tuned so motion is perceptible: sky reads as
    // slow drifting clouds (30s), horizon as a distant moving landscape
    // (28s), foreground as the close ground rushing by (5s).
    _sky = AnimationController(vsync: this, duration: const Duration(seconds: 80))..repeat();
    _horizon = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _mid = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _foreground = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    _smoke = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _applyRunning();
    _heroTicker = createTicker(_onHeroTick)..start();
    // Boucle de flammes (poêle + cuisinière) : ping-pong doux -> ça vacille.
    _fireLoop = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650))
      ..repeat(reverse: true);
    _ensureBacGrowing(); // reprend la pousse si déjà semé
    _lastZone = GameState.instance.trainZone;
    _horizonRotateTimer = Timer.periodic(_horizonRotatePeriod, (_) {
      if (!mounted) return;
      final currentZone = GameState.instance.trainZone;
      if (currentZone != _lastZone) {
        _lastZone = currentZone;
        _horizonIndex = 0;
      } else {
        _horizonIndex = (_horizonIndex + 1) % _horizonAssets.length;
      }
      setState(() {});
    });
    GameState.instance.addListener(_onGameStateChanged);
    _filterDisplayLevel = _glassesToFrame(
        GameState.instance.waterTankGlasses);
    _thoughtTimer = Timer.periodic(const Duration(seconds: 28), (_) {
      if (!mounted) return;
      // Léger skip aléatoire pour ne pas paraître mécanique (mais bulles
      // nettement plus fréquentes qu'avant).
      if (math.Random().nextDouble() < 0.25) return;
      setState(() => _thoughtEmoji = GameState.instance.contextualThought);
      _thoughtClearTimer?.cancel();
      _thoughtClearTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _thoughtEmoji = null);
      });
    });
    _needBubbleTimer =
        Timer.periodic(const Duration(seconds: 6), (_) => _forceNeedBubble());
    // Autonomie de Shen DÉSACTIVÉE (demande utilisateur) : le perso principal
    // reste en idle, ne se balade plus et ne lance plus d'actions tout seul.
    // Tout passe par les actions DÉCLENCHÉES par le joueur (boutons / objets).
    // (Le timer d'autonomie n'existe plus.)
  }


  /// Lance une animation spéciale one-shot de façon autonome (même mécanique
  /// que celle pilotée par le parent via specialAnimToken).
  void _startAutoSpecial(String anim, {int frames = _heroFrameCount}) {
    setState(() {
      _activeSpecial = anim;
      _activeSpecialFrames = frames;
      _activeSpecialLoops = false;
      _specialFrame = 0;
      _specialAccumMs = 0;
      _nextSpecial = null;
      _heroSleeping = false;
      _heroDancing = false;
      _heroLyingDown = false;
      _heroTarget = null;
    });
  }

  /// Cuisinière : Shen se tourne, la cuisinière s'allume 5 s (feu animé en
  /// boucle), s'éteint, puis Shen mange au sol (+faim).
  void _startCook() {
    final gs = GameState.instance;
    // SURVIE : pas de feu sans bois -> on ne peut pas cuisiner (sinon repas
    // gratuit quand le bois est vide). Le manque de bois EST le frein.
    if (gs.cardBois < 8) {
      _showHeroFloat('Pas assez de bois 🪵');
      return;
    }
    _heroFacingRight = gs.w1x('gaziniere') > _heroX;
    _cooking = true; // bloque le déplacement pendant toute la séquence
    _heroTarget = null; // si elle marchait, on l'arrête
    _startAutoSpecial('use_back', frames: 24);
    _cookT1?.cancel();
    _cookT2?.cancel();
    _cookT3?.cancel();
    _cookT4?.cancel();
    _cookT1 = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _cookLit = true); // allumage (feu animé)
    });
    _cookT2 = Timer(const Duration(milliseconds: 6100), () {
      if (!mounted) return;
      setState(() => _cookLit = false); // extinction
      _startAutoSpecial('use_back', frames: 24); // se retourne à nouveau
    });
    // ... puis elle s'installe et mange au sol.
    _cookT3 = Timer(const Duration(milliseconds: 7500), () {
      if (!mounted) return;
      _startAutoSpecial('eat', frames: 25);
      // CONVERSION (rien de gratuit) : la gazinière BRÛLE DU BOIS pour cuire.
      gs.nudgeCardStat('bois', -8);
      gs.nudgeCardStat('faim', 12);
      _showHeroFloat('+faim 🍖');
    });
    // Fin du repas : Shen peut de nouveau se déplacer.
    _cookT4 = Timer(const Duration(milliseconds: 9700), () {
      if (mounted) setState(() => _cooking = false);
    });
  }

  /// Frame de flamme animée (poêle/cuisinière) : ping-pong sur la plage de
  /// frames "feu vif" pour que ça vacille.
  int get _fireFrame {
    final v = _fireLoop?.value ?? 0.0;
    return 18 + (v * 7).round(); // frames 18..25
  }

  /// Bac de culture : 1er clic = on sème (pousse 20 s) ; clic sur plante mûre
  /// = récolte (+10 faim, plante sans fruits, float "+10").
  void _bacAction() {
    final gs = GameState.instance;
    if (gs.bacGrowth >= 1.0) {
      // Récolte : +12 faim (bouffe SANS bois, mais il a fallu de l'eau).
      // On vide le bac AVANT de créditer -> pas de double-récolte si 2 taps
      // arrivent avant le rebuild.
      gs.setBacGrowth(0.0);
      gs.setBacSown(false);
      gs.nudgeCardStat('faim', 12);
      _bacGrowing = false;
      _bacTimer?.cancel();
      _showBacFloat('+12');
    } else if (!gs.bacSown) {
      // Semer = ARROSER : coûte de l'eau. Pas d'eau -> pas de semis.
      if (gs.cardSoif < 6) {
        _showHeroFloat('Pas assez d\'eau 💧');
        return;
      }
      gs.nudgeCardStat('soif', -6);
      gs.setBacSown(true);
      _showBacFloat('Semé 🌱 (−6 eau)');
      _ensureBacGrowing();
    }
  }

  void _ensureBacGrowing() {
    final gs = GameState.instance;
    if (!gs.bacSown || gs.bacGrowth >= 1.0) {
      _bacGrowing = false;
      return;
    }
    if (_bacGrowing) return;
    _bacGrowing = true;
    _bacTimer?.cancel();
    // Pousse jusqu'aux fruits en 20 s (depuis l'état courant).
    _bacTimer = Timer.periodic(const Duration(milliseconds: 220), (t) {
      if (!mounted) { t.cancel(); return; }
      final g = (gs.bacGrowth + 0.220 / 20.0).clamp(0.0, 1.0);
      gs.setBacGrowth(g);
      if (g >= 1.0) {
        _bacGrowing = false;
        t.cancel();
      }
      setState(() {});
    });
  }

  void _showBacFloat(String text) {
    _bacFloatTimer?.cancel();
    setState(() { _bacFloat = text; _bacFloatT = 1.0; });
    int i = 0;
    _bacFloatTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) { t.cancel(); return; }
      i++;
      setState(() => _bacFloatT = (1.0 - i / 14.0).clamp(0.0, 1.0));
      if (i >= 14) { t.cancel(); if (mounted) setState(() => _bacFloat = null); }
    });
  }

  /// Float ancré sur la tête de Shen (même mécanique fondu/montée que le bac).
  void _showHeroFloat(String text) {
    _heroFloatTimer?.cancel();
    setState(() { _heroFloat = text; _heroFloatT = 1.0; });
    int i = 0;
    _heroFloatTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) { t.cancel(); return; }
      i++;
      setState(() => _heroFloatT = (1.0 - i / 14.0).clamp(0.0, 1.0));
      if (i >= 14) { t.cancel(); if (mounted) setState(() => _heroFloat = null); }
    });
  }

  /// Tap sur la gamelle : bascule plein/vide. La transition VIDE -> PLEIN
  /// (= on remplit) nourrit le chien s'il est là : petit gain de moral confort
  /// (cooldown partagé anti-farm) + float. Sans chien, simple toggle cosmétique.
  void _onBowlTap() {
    final wasEmpty = !_bowlFull;
    setState(() => _bowlFull = !_bowlFull);
    if (wasEmpty && _bowlFull && GameState.instance.dogShown) {
      GameState.instance.tryComfortMoral(6);
      _showHeroFloat('Le chien est nourri 🐶');
    }
  }

  /// Poêle à bois : Shen se tourne, le poêle s'allume (ou s'éteint). Le drain
  /// du bois est GLOBAL (géré dans main.dart, actif où que soit Shen).
  void _togglePoele() {
    final gs = GameState.instance;
    _heroFacingRight = gs.w1x('poele') > _heroX;
    _startAutoSpecial('use_back', frames: 24);
    gs.setPoeleOn(!gs.poeleOn);
  }

  /// Comportement autonome de Shen, dicté par ses besoins (cosmétique : la
  /// scène ne modifie pas les stats, gérées par les cartes). Elle ne fait
  /// rien si elle est déjà occupée (marche, dort, anim, porte...).
  void _onGameStateChanged() {
    if (!mounted) return;
    final zone = GameState.instance.trainZone;
    if (zone != _lastZone) {
      _lastZone = zone;
      _horizonIndex = _horizonIndex % _horizonAssets.length;
      setState(() {});
    }
    final targetFrame = _glassesToFrame(GameState.instance.waterTankGlasses);
    if ((targetFrame - _filterDisplayLevel).abs() > 0.1) {
      _animateFilterTo(targetFrame);
    }
  }

  double _glassesToFrame(int glasses) {
    // 0 verres → frame 0, 5 verres → frame 5 (waterTankFrames - 1 = 5)
    final maxFrame = (GameState.waterTankFrames - 1).toDouble();
    return (glasses / GameState.waterTankMax) * maxFrame;
  }

  void _animateFilterTo(double target) {
    _filterFillCtrl?.dispose();
    final start = _filterDisplayLevel;
    final ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    ctrl.addListener(() {
      setState(() {
        _filterDisplayLevel = start + (target - start) * ctrl.value;
      });
    });
    ctrl.forward();
    _filterFillCtrl = ctrl;
  }

  /// Force la bulle de pensée 💤/🛁 quand un besoin de confort est CRITIQUE
  /// (<20), sans attendre le tirage aléatoire. Ne re-force pas si une bulle est
  /// déjà affichée (anti-spam). L'hygiène ne compte que si elle est LAVABLE
  /// (bain/douche débloqué et pas en plein froid) — sinon punir/alerter sans
  /// remède possible n'aurait pas de sens.
  void _forceNeedBubble() {
    if (!mounted || _thoughtEmoji != null) return;
    final gs = GameState.instance;
    final washable =
        (gs.propUnlocked('bath') || gs.propUnlocked('shower')) && !gs.feltCold;
    final critical = gs.sleepNeed < 20 || (gs.hygieneNeed < 20 && washable);
    if (!critical) return;
    setState(() => _thoughtEmoji = gs.contextualThought);
    _thoughtClearTimer?.cancel();
    _thoughtClearTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _thoughtEmoji = null);
    });
  }

  // STATIC : le précache lourd ne doit tourner qu'UNE fois par lancement, pas
  // à chaque remontage de la scène (revenir de la loco recrée le State, ce qui
  // re-déclenchait le décodage de centaines de PNG -> pic mémoire / OOM).
  static bool _precached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    // NB : les frames du PERSONNAGE (idle/walk + sister) sont déjà préchargées
    // par l'écran de chargement (loading_screen._essential). On ne les
    // re-précache PAS ici (588 frames pleine résolution = gros pic mémoire à
    // chaque remontage). Les anims rares (dance/pickup/yawn/read...) se
    // décodent à la volée à leur 1re utilisation.
    // Précache des props animés (49 frames chacun) + statiques.
    // ResizeImage(width: 256) pour matcher le rendering et garantir
    // qu'on cache la version décodée à 256px (4× moins de mémoire).
    for (final def in _propDefs) {
      if (def.animated) {
        for (int i = 1; i <= def.frameCount; i++) {
          precacheImage(
            ResizeImage(
              AssetImage('assets/objects/${def.key}_$i.png'),
              width: 256,
            ),
            context,
          );
        }
      } else {
        precacheImage(
          AssetImage('assets/objects/${def.key}.png'),
          context,
        );
      }
    }
    // Bowl a 2 états statiques.
    precacheImage(const AssetImage('assets/objects/bowl_full.png'), context);
    precacheImage(const AssetImage('assets/objects/bowl_empty.png'), context);
    // Filtre/tank: waterTankFrames (6) pour le niveau d'eau (vide → plein).
    for (int i = 0; i < GameState.waterTankFrames; i++) {
      precacheImage(AssetImage('assets/objects/tank_$i.png'), context);
    }
    // Plume (chien) — précache les 9 anims. idle = image statique,
    // walk = 49 frames, le reste = 25 frames.
    precacheImage(const AssetImage('assets/objects/dog_idle.png'), context);
    const dogAnims = {
      'dog_walk':         49,
      'dog_sleep':        25,
      'dog_lay_down':     25,
      'dog_wag_tail':     25,
      'dog_bark':         25,
      'dog_stretch_yawn': 25,
      'dog_head_tilt':    25,
      'dog_eat':          25,
    };
    dogAnims.forEach((prefix, count) {
      for (int i = 1; i <= count; i++) {
        // Le chien est petit à l'écran : on décode à 256px (4× moins de RAM).
        precacheImage(
          ResizeImage(AssetImage('assets/objects/${prefix}_$i.png'), width: 256),
          context,
        );
      }
    });
    for (final asset in const [
      'assets/background/sky.png',
      'assets/background/sky_night.png',
      'assets/background/sky_snow.png',
      'assets/background/sky_snow_night.png',
      'assets/background/horizon_a.png',
      'assets/background/horizon_b.png',
      'assets/background/horizon_c.png',
      'assets/background/horizon_night.png',
      'assets/background/horizon_snow_a.png',
      'assets/background/horizon_snow_b.png',
      'assets/background/horizon_snow_c.png',
      'assets/background/horizon_snow_d.png',
      'assets/background/horizon_snow_e.png',
      'assets/background/horizon_snow_f.png',
      'assets/background/horizon_snow_g.png',
      'assets/background/horizon_snow_night.png',
      'assets/background/horizon_transition_a.png',
      'assets/background/horizon_transition_b.png',
      'assets/background/horizon_transition_c.png',
      'assets/background/horizon_transition_d.png',
      'assets/background/foreground_band.png',
      'assets/background/foreground_snow.png',
      'assets/background/wagon_windowed.png',
      'assets/background/wagon_clean.png',
      'assets/background/wagon2_messy.png',
      'assets/background/wagon2_clean.png',
      'assets/background/atelier_messy.png',
      'assets/background/atelier_clean.png',
      'assets/background/wagon_rails.png',
      'assets/objects/bed.png',
      'assets/objects/paillasse.png',
    ]) {
      precacheImage(AssetImage(asset), context);
    }
  }

  @override
  void didUpdateWidget(covariant SideScrollScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.running != widget.running) {
      _applyRunning();
    }
    if (oldWidget.specialAnimToken != widget.specialAnimToken &&
        widget.specialAnim != null) {
      setState(() {
        _activeSpecial = widget.specialAnim;
        _activeSpecialFrames = widget.specialAnimFrames;
        _activeSpecialLoops = widget.specialAnimLoops;
        _specialFrame = 0;
        _specialAccumMs = 0;
        _nextSpecial = widget.specialAnimNext;
        _nextSpecialFrames = widget.specialAnimNextFrames;
        // Couper les autres états qui pourraient interférer.
        _heroSleeping = false;
        _heroDancing = false;
        _heroLyingDown = false;
        _heroTarget = null;
        // Annule un bain/douche armé : sinon la fin de CE special anim
        // déclencherait à tort l'entrée dans le bain (_pendingBath).
        _pendingBath = false;
        _pendingShower = false;
        _bathHeld = false;
      });
    }
    if (oldWidget.dancing != widget.dancing) {
      setState(() {
        _heroDancing = widget.dancing;
        if (_heroDancing) {
          _heroSleeping = false;
          _heroLyingDown = false;
          _heroTarget = null;
          _danceFrame = 0;
          _danceAccumMs = 0;
        }
      });
    }
    if (oldWidget.lieDownToken != widget.lieDownToken) {
      // FAB lit → marcher vers le lit, puis se coucher dessus.
      final target = (_bedLeft + _bedWidth / 2).clamp(_heroXMin, _heroXMax);
      setState(() {
        _heroDancing = false;
        _heroSleeping = false;
        _heroLyingDown = false;
        _walkingToBed = true;
        _heroTarget = target;
      });
    }
    if (oldWidget.cuisiniereToken != widget.cuisiniereToken) {
      _startCook();
    }
    if (oldWidget.poeleToken != widget.poeleToken) {
      _togglePoele();
    }
    if (oldWidget.bacToken != widget.bacToken) {
      _bacAction();
    }
    if (oldWidget.heroFloatToken != widget.heroFloatToken &&
        widget.heroFloatText.isNotEmpty) {
      _showHeroFloat(widget.heroFloatText);
    }
    if (oldWidget.bathToken != widget.bathToken) {
      // Refus : feedback explicite (hors setState imbriqué).
      if (!_bathing) {
        if (GameState.instance.feltCold) {
          _showHeroFloat('Trop froid pour se laver 🥶');
        } else if (GameState.instance.cardSoif < 8) {
          _showHeroFloat('Pas assez d\'eau 💧');
        }
      }
      setState(() {
        if (_bathing) {
          // Déjà dans le bain -> sortir.
          _bathing = false;
          _bathHeld = false;
          _bathFrame = 0;
          _pendingBath = false;
        } else {
          // SURVIE : le bain coûte de l'eau ET ne donne du moral que si on
          // n'a pas froid (le moral est bloqué en froid) -> on refuse d'entrer
          // sans eau ou en froid, plutôt que de gaspiller l'eau pour rien.
          if (GameState.instance.cardSoif < 8 ||
              GameState.instance.feltCold) {
            return;
          }
          // Se tourner vers la cuve (use_back) puis l'anim de bain s'enchaîne
          // (cf. hook de fin de use_back dans _onHeroTick).
          _heroDancing = false;
          _heroSleeping = false;
          _heroLyingDown = false;
          _heroTarget = null;
          _activeSpecial = 'use_back';
          _activeSpecialFrames = 10;
          _activeSpecialLoops = false;
          _specialFrame = 0;
          _specialAccumMs = 0;
          _nextSpecial = null;
          _pendingBath = true;
          _showering = false; // exclusion mutuelle
          _pendingShower = false;
        }
      });
    }
    if (oldWidget.chairToken != widget.chairToken) {
      setState(() {
        if (_chairReading) {
          _chairReading = false; // re-tap -> se lève
          _chairTimer?.cancel();
        } else {
          _heroDancing = false;
          _heroSleeping = false;
          _heroLyingDown = false;
          _heroTarget = null;
          _chairReading = true;
          _chairTimer?.cancel();
          _chairTimer = Timer(
            const Duration(milliseconds: _chairTotalMs),
            () { if (mounted) setState(() => _chairReading = false); },
          );
        }
      });
    }
    if (oldWidget.showerToken != widget.showerToken) {
      if (!_showering) {
        if (GameState.instance.feltCold) {
          _showHeroFloat('Trop froid pour se laver 🥶');
        } else if (GameState.instance.cardSoif < 6) {
          _showHeroFloat('Pas assez d\'eau 💧');
        }
      }
      setState(() {
        if (_showering) {
          _showering = false;
          _showerFrame = 0;
          _pendingShower = false;
        } else {
          if (GameState.instance.cardSoif < 6 ||
              GameState.instance.feltCold) {
            return;
          }
          _heroDancing = false;
          _heroSleeping = false;
          _heroLyingDown = false;
          _heroTarget = null;
          _activeSpecial = 'use_back';
          _activeSpecialFrames = 10;
          _activeSpecialLoops = false;
          _specialFrame = 0;
          _specialAccumMs = 0;
          _nextSpecial = null;
          _pendingShower = true;
          _bathing = false; // exclusion mutuelle
          _bathHeld = false;
          _pendingBath = false;
        }
      });
    }
    if (oldWidget.petDogToken != widget.petDogToken && !_petDog) {
      setState(() {
        _petDog = true;
        _petDogFrame = 0;
        _petDogAccumMs = 0;
        _petDogElapsedMs = 0;
        _heroDancing = false;
        _heroSleeping = false;
        _heroLyingDown = false;
        _heroTarget = null;
        _activeSpecial = null;
      });
    }
    if (oldWidget.duoToken != widget.duoToken && !_duoActive) {
      _startDuo(widget.duoAnim); // test manuel : lecture / câlin
    }
    if (oldWidget.doorPushToken != widget.doorPushToken) {
      setState(() {
        _doorPushing = true;
        _doorPushRight = widget.doorPushRight;
        _doorFrame = 0;
        _doorAccumMs = 0;
        _heroTarget = null;
        _heroDancing = false;
        _heroSleeping = false;
        _heroLyingDown = false;
      });
    }
  }

  void _applyRunning() {
    final ctrls = [_horizon, _mid, _foreground, _smoke, _sky];
    if (widget.running) {
      for (final c in ctrls) {
        if (!c.isAnimating) c.repeat();
      }
    } else {
      for (final c in ctrls) {
        c.stop();
      }
    }
  }

  @override
  void dispose() {
    GameState.instance.removeListener(_onGameStateChanged);
    _heroTicker.dispose();
    _heroAnim.dispose();
    _horizonRotateTimer?.cancel();
    _thoughtTimer?.cancel();
    _thoughtClearTimer?.cancel();
    _needBubbleTimer?.cancel();
    _chairTimer?.cancel();
    _filterFillCtrl?.dispose();
    _fireLoop?.dispose();
    _cookT1?.cancel();
    _cookT2?.cancel();
    _cookT3?.cancel();
    _cookT4?.cancel();
    _bacTimer?.cancel();
    _heroFloatTimer?.cancel();
    _bacFloatTimer?.cancel();
    _sky.dispose();
    _horizon.dispose();
    _mid.dispose();
    _foreground.dispose();
    _smoke.dispose();
    super.dispose();
  }

  /// Comme setState mais ne rebuild QUE le cluster héroïne (via _heroAnim),
  /// pas toute la scène. À utiliser pour les avances de frame par tick.
  /// Conserve exactement la sémantique des closures (les `return` internes
  /// sortent de fn, comme avec le callback de setState).
  void _animSet(void Function() fn) {
    fn();
    _heroAnim.value++;
  }

  void _onHeroTick(Duration elapsed) {
    final dtMicros = (elapsed - _lastTick).inMicroseconds;
    _lastTick = elapsed;
    if (dtMicros <= 0) return;
    final dt = dtMicros / 1e6;
    final dtMs = (dt * 1000).round();

    if (_doorPushing) {
      _animSet(() {
        _doorAccumMs += dtMs;
        while (_doorAccumMs >= _doorFrameMs) {
          _doorAccumMs -= _doorFrameMs;
          _doorFrame++;
          if (_doorFrame >= _doorMaxFrames) {
            _doorPushing = false;
            widget.onDoorPushDone?.call();
            return;
          }
        }
      });
      return;
    }

    if (_activeSpecial != null) {
      // Avance des frames via _animSet : seul le cluster héroïne se reconstruit
      // (pas parallax + props + atmo). Les transitions terminales qui montent
      // un widget HORS de ce cluster (bain/douche) déclenchent leur propre
      // rebuild de scène via _showHeroFloat (qui appelle setState). Les autres
      // sorties (idle, anim suivante) restent dans le cluster héroïne.
      _animSet(() {
        _specialAccumMs += dtMs;
        while (_specialAccumMs >= _specialFrameMs) {
          _specialAccumMs -= _specialFrameMs;
          _specialFrame++;
          if (_specialFrame >= _activeSpecialFrames) {
            if (_activeSpecialLoops) {
              _specialFrame = 0;
            } else if (_nextSpecial != null) {
              _activeSpecial = _nextSpecial;
              _activeSpecialFrames = _nextSpecialFrames;
              _activeSpecialLoops = false;
              _specialFrame = 0;
              _specialAccumMs = 0;
              _nextSpecial = null;
              return;
            } else {
              _activeSpecial = null;
              // Fin du "tour" (use_back) -> on enchaîne sur le bain/la douche.
              if (_pendingBath) {
                _pendingBath = false;
                _bathing = true;
                _bathFrame = 0;
                _bathHeld = false;
                _bathAccumMs = 0;
                // Le bain consomme de l'eau et nettoie ; le BONUS moral passe
                // par le cooldown confort partagé (anti-farm).
                GameState.instance.nudgeCardStat('soif', -8);
                GameState.instance.restoreHygiene();
                final gotMoral = GameState.instance.tryComfortMoral(12);
                _showHeroFloat(gotMoral ? '+moral ❤️ 🛁' : 'Propre 🛁');
              } else if (_pendingShower) {
                _pendingShower = false;
                _showering = true;
                _showerFrame = 0;
                _showerAccumMs = 0;
                _showerWashed = false;
                _showerWashCycles = 0;
                _showerWaterTick = 0;
                GameState.instance.nudgeCardStat('soif', -6);
                GameState.instance.restoreHygiene();
                final gotMoral = GameState.instance.tryComfortMoral(10);
                _showHeroFloat(gotMoral ? '+moral ❤️ 🚿' : 'Propre 🚿');
              }
              return;
            }
          }
        }
      });
      return;
    }

    // Avance de l'anim bain (1->8 puis tient la détente).
    if (_bathing) {
      if (!_bathHeld) {
        _animSet(() {
          _bathAccumMs += dtMs;
          while (_bathAccumMs >= _bathFrameMs) {
            _bathAccumMs -= _bathFrameMs;
            _bathFrame++;
            if (_bathFrame >= _bathFrames) {
              _bathFrame = _bathFrames - 1;
              _bathHeld = true;
              break;
            }
          }
        });
      }
      return;
    }

    // Douche : l'eau coule en continu ; le corps fait plusieurs boucles de
    // shampoing (frames 1..7) puis tient la pose "lavée" (frame 8) jusqu'à
    // ce que le joueur ressorte.
    if (_showering) {
      _animSet(() {
        _showerAccumMs += dtMs;
        while (_showerAccumMs >= _showerFrameMs) {
          _showerAccumMs -= _showerFrameMs;
          _showerWaterTick++;
          if (_showerWashed) continue; // corps figé sur la frame propre
          _showerFrame++;
          if (_showerFrame >= 7) {
            _showerWashCycles++;
            if (_showerWashCycles >= _showerWashCyclesMax) {
              _showerFrame = 7; // frame 8 = propre, on tient
              _showerWashed = true;
            } else {
              _showerFrame = 1; // reboucle le shampoing
            }
          }
        }
      });
      return;
    }

    // Duo sœur+Shen (lecture/câlin) : BOUCLE pendant _duoTotalMs puis fin
    // (les solos ne reviennent qu'à la fin -> plus de coupure en plein milieu).
    if (_duoActive) {
      _duoElapsedMs += dtMs;
      if (_duoElapsedMs >= _duoTotalMs) {
        // FIN via setState (rebuild scène) pour retirer le sprite duo figé.
        setState(() => _duoActive = false);
        return;
      }
      _animSet(() {
        _duoAccumMs += dtMs;
        while (_duoAccumMs >= _duoFrameMs) {
          _duoAccumMs -= _duoFrameMs;
          _duoFrame = (_duoFrame + 1) % _duoFrames;
        }
      });
      return;
    }

    // Caresse chien : approche (frames 1-3) puis BOUCLE le câlin (frames 4-9)
    // -> ça ne reste jamais figé. La FIN passe par setState (et non _animSet)
    // pour rebuild la scène et retirer le sprite -> sinon il reste affiché ET
    // le solo debout réapparait par-dessus.
    if (_petDog) {
      _petDogElapsedMs += dtMs;
      if (_petDogElapsedMs >= _petDogTotalMs) {
        setState(() => _petDog = false);
        return;
      }
      _animSet(() {
        _petDogAccumMs += dtMs;
        while (_petDogAccumMs >= _petDogFrameMs) {
          _petDogAccumMs -= _petDogFrameMs;
          _petDogFrame++;
          if (_petDogFrame >= _petDogFrames) {
            _petDogFrame = 3; // reboucle sur le câlin (4-9), pas de gel
          }
        }
      });
      return;
    }

    if (_waking) {
      _animSet(() {
        _wakingAccumMs += dtMs;
        while (_wakingAccumMs >= _wakingFrameMs) {
          _wakingAccumMs -= _wakingFrameMs;
          _wakingFrame++;
          if (_wakingFrame >= _heroFrameCount) {
            _wakingFrame = 0;
            _wakingPhase++;
            // Fin de wake_up → si on dormait sur le lit, on skip stretch
            // (sinon ça fait un saut de ~250px vers la droite + un saut
            // vertical lit→sol). On atterrit debout au centre du lit en
            // X et on enchaîne direct sur idle.
            if (_wakingPhase == 1 && _sleepOnBed) {
              _sleepOnBed = false;
              GameState.instance.restoreSleep(); // nuit complète au lit
              final bedCenter = (_bedLeft + _bedWidth / 2)
                  .clamp(_heroXMin, _heroXMax);
              _heroX = bedCenter;
              widget.onHeroXChanged?.call(_heroX);
              _waking = false;
              return;
            }
            if (_wakingPhase >= 2) {
              _waking = false;
              return;
            }
          }
        }
      });
      return;
    }

    if (_heroLyingDown) {
      _animSet(() {
        _lieDownAccumMs += dtMs;
        while (_lieDownAccumMs >= _lieDownFrameMs) {
          _lieDownAccumMs -= _lieDownFrameMs;
          if (_lieDownFrame <= 0) {
            // Reached the most-bent frame — snap into the sleep loop.
            _heroLyingDown = false;
            _heroSleeping = true;
            _sleepFrame = 0;
            _sleepAccumMs = 0;
            return;
          }
          _lieDownFrame -= 1;
        }
      });
      return;
    }

    if (_heroSleeping) {
      _animSet(() {
        _sleepAccumMs += dtMs;
        while (_sleepAccumMs >= _sleepFrameMs) {
          _sleepAccumMs -= _sleepFrameMs;
          _sleepFrame = (_sleepFrame + 1) % _heroFrameCount;
        }
      });
      return;
    }

    if (_heroDancing) {
      _animSet(() {
        _danceAccumMs += dtMs;
        while (_danceAccumMs >= _danceFrameMs) {
          _danceAccumMs -= _danceFrameMs;
          _danceFrame = (_danceFrame + 1) % _heroFrameCount;
        }
      });
      return;
    }

    final target = _heroTarget;
    if (target == null) {
      // Idle pur (l'autonomie yawn/look_window a été retirée).
      _animSet(() {
        _idleAccumMs += dtMs;
        while (_idleAccumMs >= _idleFrameMs) {
          _idleAccumMs -= _idleFrameMs;
          _idleFrame = (_idleFrame + 1) % _heroFrameCount;
        }
      });
      return;
    }

    final delta = target - _heroX;
    final step = _heroSpeed * dt;
    if (delta.abs() <= step) {
      final arriveTriggersLieDown = _walkingToBed;
      _animSet(() {
        _heroX = target;
        _heroTarget = null;
        _walkFrame = 0;
        _walkAccumMs = 0;
        if (arriveTriggersLieDown) {
          _walkingToBed = false;
          _sleepOnBed = true;
          _heroSleeping = true;
          _sleepFrame = 0;
          _sleepAccumMs = 0;
        }
      });
      widget.onHeroXChanged?.call(_heroX);
      return;
    }

    final dir = delta > 0 ? 1.0 : -1.0;
    _animSet(() {
      _heroX += step * dir;
      _heroFacingRight = dir > 0;
      _walkAccumMs += dtMs;
      while (_walkAccumMs >= _walkFrameMs) {
        _walkAccumMs -= _walkFrameMs;
        _walkFrame = (_walkFrame + 1) % _heroFrameCount;
      }
    });
    widget.onHeroXChanged?.call(_heroX);
  }

  void _walkTo(double normalizedX) {
    if (_cooking) return; // Shen cuisine/mange : pas de déplacement
    final clamped = normalizedX.clamp(_moveMin, _moveMax);
    final wasSleeping = _heroSleeping;
    setState(() {
      _heroSleeping = false;
      _heroDancing = false;
      _heroLyingDown = false;
      _walkingToBed = false;
      _heroTarget = clamped;
      if (wasSleeping) {
        if (_sleepOnBed) {
          // Réveil depuis le LIT : skip toute la séquence wake_up +
          // stretch (causait le bug "se penche puis remonte" + saut
          // de position). On snap directement à idle au centre du lit.
          _sleepOnBed = false;
          GameState.instance.restoreSleep(); // la sieste/nuit a reposé Shen
          final bedCenter =
              (_bedLeft + _bedWidth / 2).clamp(_heroXMin, _heroXMax);
          _heroX = bedCenter;
          widget.onHeroXChanged?.call(_heroX);
        } else {
          // Réveil depuis le SOL : la séquence wake_up + stretch garde
          // du sens visuellement (couchée → debout).
          _waking = true;
          _wakingPhase = 0;
          _wakingFrame = 0;
          _wakingAccumMs = 0;
        }
      }
    });
    widget.onUserInteract?.call();
  }



  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            return Stack(
              children: [
              ClipRect(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _walkTo(d.localPosition.dx / w),
                child: TrainRocking(
                  enabled: widget.running,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 1. Sky/horizon — vertical bounds are tunable
                      //    via the horizon adjust mode (top + bottom
                      //    drag handles when widget.horizonAdjust is
                      //    on). Defaults are baked back from that mode.
                      Positioned(
                        left: 0,
                        right: 0,
                        top: h * _horizonTop,
                        bottom: h * _horizonBottom,
                        child: AnimatedSwitcher(
                          duration: _horizonCrossFade,
                          child: _nightTint(
                            _ParallaxLayer(
                              key: ValueKey(_horizonAssets[_horizonIndex]),
                              controller: _horizon,
                              asset: _horizonAssets[_horizonIndex],
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                            ),
                          ),
                        ),
                      ),
                      // 1a-bis. Mid-ground parallax — poteaux + arbres
                      //     morts qui scrollent plus vite que l'horizon.
                      Positioned(
                        left: 0,
                        right: 0,
                        top: h * 0.40,
                        height: h * 0.35,
                        child: MidgroundParallax(animation: _mid),
                      ),
                      // Silhouettes humaines sur l'horizon RETIRÉES (demande
                      // user : « personnages qui marchent dans le background à
                      // enlever »). Le monde est mort, le paysage reste vide.
                      // 1a-ter. Daytime birds drifting in the sky above
                      //     the wagon, very small + slow (far away).
                      Positioned(
                        left: 0,
                        right: 0,
                        top: h * 0.02,
                        height: h * 0.18,
                        child: DaytimeBirds(
                          animation: _sky,
                          enabled: !widget.night,
                        ),
                      ),
                      // 1a-quater. Distant animal silhouette far on the
                      //     horizon, rare (day only).
                      Positioned(
                        left: 0,
                        right: 0,
                        top: h * 0.60,
                        height: h * 0.12,
                        child: DistantAnimal(
                          animation: _sky,
                          enabled: !widget.night,
                        ),
                      ),
                      // 1b. Overlay de nuages (sky.png) RETIRÉ à la demande
                      //     (« couper les nuages au-dessus »).
                      // 2b. Birds — occasional silhouettes drifting through
                      //    the upper sky band. Sits in front of the horizon
                      //    so they read as nearer than the ruins.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _sky,
                            builder: (_, __) => CustomPaint(
                              painter: _BirdsPainter(_sky.value),
                            ),
                          ),
                        ),
                      ),
                      // 3. Rails strip — scrolls BEHIND the wagon, at
                      //    y=83..92%. Tiled from a clean sleeper section
                      //    of the source, contains no wheel content.
                      Positioned(
                        left: 0,
                        right: 0,
                        top: h * 0.83,
                        height: h * 0.09,
                        child: IgnorePointer(
                          child: _nightTint(
                            _ParallaxLayer(
                              controller: _foreground,
                              asset: 'assets/background/wagon_rails.png',
                              fit: BoxFit.fill,
                              alignment: Alignment.center,
                            ),
                          ),
                        ),
                      ),
                      // 3b. Close ground strip under the rails
                      //     (y=0.92..1.0). Painted post-apo dirt + dry
                      //     grass + small debris; scrolls on the same
                      //     foreground controller as the rails so the
                      //     two move together at close-camera speed.
                      Positioned(
                        left: 0,
                        right: 0,
                        top: h * 0.92,
                        bottom: 0,
                        child: IgnorePointer(
                          child: _nightTint(
                            _ParallaxLayer(
                              controller: _foreground,
                              asset: _foregroundAsset,
                              fit: BoxFit.cover,
                              alignment: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                      // 3b-bis. Animated grass, rail sparks, scurrying animals
                      //     on the foreground strip.
                      Positioned(
                        left: 0,
                        right: 0,
                        top: h * 0.88,
                        bottom: 0,
                        child: AnimatedGrass(animation: _foreground),
                      ),
                      // Animaux qui couraient sous les rails retirés (pas
                      // réaliste) : plus de ScurryingAnimal ici.
                      // 3b-ter. Foreground life (tumbleweed, paper, dust,
                      //     bottles, footprints, bones, wildflowers) — cycled.
                      //     Animaux (renard/serpent/lézard) retirés.
                      Positioned(
                        left: 0,
                        right: 0,
                        top: h * 0.84,
                        bottom: 0,
                        child: ForegroundLife(
                          animation: _foreground,
                          running: widget.running,
                        ),
                      ),
                      // Bloc intérieur (wagon + props + perso) descendu d'un
                      // cran pour poser le SALON sur les rails : seul le salon
                      // (wagon_windowed) est cadré ~7.6% plus haut dans son
                      // image (bas à 0.828 vs 0.904). On décale tout le bloc
                      // ensemble -> l'alignement des props est préservé.
                      // Offset NUL pour l'atelier ET le cellier : leurs images
                      // sont déjà cadrées au bon niveau ; les descendre cachait
                      // les rails sous la bande de sable (cas de l'atelier).
                      Positioned.fill(
                        child: Transform.translate(
                          offset: Offset(
                            0,
                            (widget.secondWagon || widget.isAtelier)
                                ? 0.0
                                : 0.076 * math.min(w / 1.7917, h),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                      // 4. Wagon — fixed in the centre, picked from the
                      //    progression stage (windowed → clean). Night
                      //    ColorFilter tints both the same way.
                      Positioned.fill(
                        child: _nightTint(
                          Image.asset(
                            _wagonAssetFor(widget.wagonStage),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      // 4a. Frost edges — désactivé (rectangle visible).
                      // 4b. Bed — placed at floor level on the left of
                      //     the wagon interior. Position + size are
                      //     normalised state so the in-app adjustment
                      //     mode can drag + resize them live; final
                      //     values get baked back into the defaults.
                      if (!widget.secondWagon && !widget.isAtelier && _bedUnlocked)
                        Positioned(
                          left: w * _bedLeft,
                          top: h * _bedTop,
                          width: w * _bedWidth,
                          child: _nightTint(
                            Image.asset(
                              // Paillasse (G1) -> vrai lit `bed.png` (G5).
                              _bedAsset,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      // NB : radio → ATELIER (_buildWagon1Adjustable) ;
                      // bouquet (deco_fleurs) → CELLIER (_buildWagon2Props).
                      // #4 — DÉCO-SOUVENIRS : objets qui s'accrochent dans le
                      // salon selon les souvenirs vécus. Le train raconte ta
                      // partie. (photo de famille = souvenir carnet ; peluche
                      // de la sœur = souvenir sœur.)
                      if (!widget.secondWagon && !widget.isAtelier)
                        _buildDeco('deco_photo', 'souvenir_carnet', w, h),
                      if (!widget.secondWagon && !widget.isAtelier)
                        _buildDeco('deco_peluche', 'souvenir_soeur', w, h),
                      // 4c. Floating dust motes — caught in the warm
                      //     light through the wagon windows. Confined
                      //     to the wagon interior (y=0.20..0.80) so
                      //     they don't drift in the sky above the
                      //     wagon roof. Density drops with the stage.
                      Positioned(
                        left: 0,
                        right: 0,
                        top: h * 0.20,
                        height: h * 0.60,
                        child: DustParticles(
                          animation: _sky,
                          count: 30 - widget.wagonStage * 6,
                          opacity: widget.night ? 0.20 : 0.45,
                        ),
                      ),
                      // 4d. Lucioles — night-only, drift in slow loops
                      //     across the wagon interior.
                      if (widget.night)
                        Positioned.fill(
                          child: Fireflies(animation: _foreground, count: 5),
                        ),
                      // 4e. Hanging vines — short procedural strands
                      //     between the wagon roof and the top edge of
                      //     the back-wall windows, so they don't cover
                      //     the curtains or the visible landscape.
                      // 4f. Distant zombie passing across the window band,
                      //     night only.
                      Positioned(
                        left: 0,
                        right: 0,
                        top: h * 0.30,
                        height: h * 0.30,
                        child: DistantZombie(enabled: widget.night),
                      ),
                      // 4f-bis. Window rain/snow on rainy/snowy weather.
                      if (GameState.instance.weather == Weather.rainy ||
                          GameState.instance.weather == Weather.snowy)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: h * 0.18,
                          height: h * 0.45,
                          child: WindowRain(
                            animation: _sky,
                            density: GameState.instance.weather == Weather.snowy ? 15 : 25,
                          ),
                        ),
                      // Givre sur les vitres quand il fait froid (intensité =
                      // coldness). Retour visuel direct de la température.
                      if (!widget.secondWagon && GameState.instance.feltCold)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: h * 0.16,
                          height: h * 0.46,
                          child: IgnorePointer(
                            child: WindowFrost(
                              intensity:
                                  (GameState.instance.coldness / 9).clamp(0.25, 1.0),
                            ),
                          ),
                        ),
                      // 4g. Props installés dans le wagon (tour hydro,
                      //     lampe, poêle, filtre eau, chien, table,
                      //     carnet, trousse). Rendus avant la fille pour
                      //     qu'elle puisse passer devant.
                      // Props du SALON (carnet, trousse, gamelle, carte) :
                      // uniquement dans le wagon de vie.
                      if (!widget.secondWagon && !widget.isAtelier)
                        for (final def in _propDefs)
                          if (_propUnlocked(def.key) &&
                              !(def.key == 'fauteuil' &&
                                  _chairReading &&
                                  !widget.salonAdjust) &&
                              !(def.key == 'panier' &&
                                  _dogInBasket &&
                                  !widget.salonAdjust) &&
                              // Table masquée pendant playduo (le sprite du
                              // duo contient déjà la table).
                              !(def.key == 'jeu' &&
                                  _duoActive &&
                                  _duoAnim == 'playduo' &&
                                  !widget.salonAdjust))
                            widget.salonAdjust
                                ? _buildSalonDrag(def, w, h)
                                : _buildProp(def: def, w: w, h: h),
                      // Fauteuil : Shen lit (chair_read remplace le fauteuil vide
                      // + l'héroïne solo) le temps de l'activité. (Pas en ajuster.)
                      if (!widget.secondWagon &&
                          !widget.isAtelier &&
                          _chairReading &&
                          !widget.salonAdjust)
                        _buildChairRead(w, h),
                      // Chien endormi dans son panier (nuit). (Pas en ajuster.)
                      if (!widget.secondWagon &&
                          !widget.isAtelier &&
                          _dogInBasket &&
                          !widget.salonAdjust)
                        _buildDogBasket(w, h),
                      // Props AJUSTABLES de l'ATELIER (cuisinière, lampe, bac,
                      // filtre, poêle).
                      if (widget.isAtelier) _buildWagon1Adjustable(w, h),
                      // Cellier : props déplaçables (lanternes, baignoire,
                      // panneau douche, pommeau) + anim bain quand elle baigne.
                      if (widget.secondWagon) _buildWagon2Props(w, h),
                      if (widget.secondWagon && _bathing)
                        _buildBathAnim(w, h),
                      // Vapeur du bain (devant la cuve, monte de l'eau).
                      if (widget.secondWagon && _bathing)
                        _steam(w, h,
                            cx: GameState.instance.bathX,
                            topY: GameState.instance.bathY - 0.04,
                            boxWFrac: GameState.instance.bathH * (1376 / 768) * 0.7,
                            boxHFrac: GameState.instance.bathH * 0.9,
                            intensity: 1.15),
                      // 4g-bis. Chien statique (dog_idle) ou animé
                      //     pendant les interactions (crouch → wag_tail).
                      // Chien : SALON uniquement.
                      if (!widget.secondWagon &&
                          !widget.isAtelier &&
                          !_petDog &&
                          !_dogInBasket &&
                          _dogShown)
                        _buildStaticDog(w, h),
                      if (!widget.secondWagon &&
                          !widget.isAtelier &&
                          _petDog &&
                          _dogShown)
                        _buildPetDog(w, h),
                      // Sœur : SALON + ATELIER (elle vient jouer à la table).
                      // À l'atelier, seulement de JOUR (la nuit elle dort au
                      // salon, où est le lit).
                      if (!widget.secondWagon &&
                          (!widget.isAtelier || !widget.night) &&
                          !_duoActive &&
                          _sisterShown)
                        _buildSister(w, h),
                      if (!widget.secondWagon &&
                          (!widget.isAtelier || !widget.night) &&
                          _duoActive &&
                          _sisterShown)
                        _buildDuo(w, h),
                      // 4c. Halo de la lampe — UNIQUEMENT si la lampe est
                      //     débloquée (présente) ET allumée. Sinon pas de halo
                      //     fantôme.
                      if (widget.isAtelier &&
                          _propUnlocked('lamp') &&
                          GameState.instance.lampOn)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: widget.night ? 1.0 : 0.45,
                              child: LampGlow(
                                animation: _sky,
                                x: GameState.instance.w1x('lamp'),
                                y: GameState.instance.w1y('lamp') +
                                    GameState.instance.w1h('lamp') * 0.4,
                                radius: 0.34, // lumière projetée plus large
                                halo: false, // le sprite porte déjà sa lueur
                                floorY: 0.74, // sol du wagon 1
                              ),
                            ),
                          ),
                        ),
                      // 5. Cluster héroïne (sprite + halo + poussière +
                      //    bulle de pensée). Isolé sous _heroAnim : seul ce
                      //    sous-arbre se reconstruit à chaque frame, pas la
                      //    scène entière. RepaintBoundary cantonne le repaint.
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: ValueListenableBuilder<int>(
                            valueListenable: _heroAnim,
                            builder: (_, __, ___) => Stack(
                              fit: StackFit.expand,
                              children: [
                                _buildHeroine(w, h),
                                Positioned.fill(
                                  child: CharacterHalo(
                                    heroX: _heroX,
                                    heroY: 0.72,
                                    intensity: _heroEdgeProximity() *
                                        (widget.night ? 1.0 : 0.6),
                                  ),
                                ),
                                if (_thoughtEmoji != null)
                                  Positioned.fill(
                                    child: ThoughtBubble(
                                      heroX: _heroX,
                                      heroTopY: 0.46,
                                      emoji: _thoughtEmoji!,
                                    ),
                                  ),
                                if (_heroFloat != null)
                                  _heroFloatWidget(w, h),
                              ],
                            ),
                          ),
                        ),
                      ),
                            ],
                          ),
                        ),
                      ),
                      // 5f. Overlay météo : teinte plein écran + voile
                      //     selon GameState.weather. Mis en haut du
                      //     Stack pour couvrir TOUT (sauf le HUD).
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedBuilder(
                            animation: GameState.instance,
                            builder: (_, __) {
                              final w = GameState.instance.weather;
                              Color? tint;
                              switch (w) {
                                case Weather.clear:
                                  return const SizedBox.shrink();
                                case Weather.cloudy:
                                  tint = const Color(0x0D2A3A4A);
                                case Weather.rainy:
                                  tint = const Color(0x151E2A3A);
                                case Weather.foggy:
                                  tint = const Color(0x1AD8D2C8);
                                case Weather.snowy:
                                  tint = const Color(0x15D0D8E8);
                              }
                              return DecoratedBox(
                                decoration: BoxDecoration(color: tint),
                              );
                            },
                          ),
                        ),
                      ),
                      // 5. Locomotive smoke — drifts over the top of the wagon.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _smoke,
                            builder: (_, __) => CustomPaint(
                              painter: _SmokePainter(
                                _smoke.value,
                                running: widget.running,
                                intensity: (widget.night ? 0.35 : 0.65) +
                                    0.08 * widget.logsThrown.clamp(0, 8),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // 7. Speed lines — subtle motion blur streaks at the
                      //    upper and lower edges, visible only when running.
                      //    Driven off the foreground controller so they
                      //    pulse at the same tempo as the close parallax.
                      if (widget.running)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: AnimatedBuilder(
                              animation: _foreground,
                              builder: (_, __) => CustomPaint(
                                painter: _SpeedLinesPainter(
                                  _foreground.value,
                                  intensity:
                                      1.0 + 0.18 * widget.logsThrown.clamp(0, 5),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              ),
              // HUDs d'AJUSTER (debug) — HORS de TrainRocking/ClipRect : le
              // tangage + le scale ×1.03 poussaient le panneau hors écran
              // (coupé à gauche et en bas). Ici, coordonnées écran stables.
              if (widget.salonAdjust) _salonCoordHud(GameState.instance),
              if (widget.isAtelier && widget.wagon1Adjust)
                _wagon1CoordHud(GameState.instance),
              if (widget.secondWagon && widget.wagon2Adjust)
                _coordHud(GameState.instance),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 0..1, how close the heroine is to either door — feeds the warm
  /// halo so she gets bathed in firebox / lamp glow when near the
  /// edges.
  double _heroEdgeProximity() {
    const edgeBand = 0.12;
    final dLeft = (_heroX - _heroXMin).abs();
    final dRight = (_heroXMax - _heroX).abs();
    final d = math.min(dLeft, dRight);
    if (d >= edgeBand) return 0.0;
    return 1.0 - (d / edgeBand);
  }

  /// Construit un prop (animé 49 frames ou statique) positionné selon
  /// l'entry correspondante de [_propPos] (left/top centrés, height en
  /// fraction de h). Tous les sprites AutoSprite sont 512x512 (ratio
  /// 1:1) donc width = height.
  // Prop positionnable du cellier. En jeu normal : figé (IgnorePointer).
  // En mode ajuster : déplaçable (1 doigt) + redimensionnable (pincer 2
  // doigts) + contour + label.
  Widget _w2Drag({
    required double w,
    required double h,
    required double cx,
    required double topY,
    required double heightFrac,
    required double aspect,
    required Widget child,
    required String label,
    required void Function(double dx, double dy) onMove,
    required void Function(double newH) onResize,
    VoidCallback? onTap,
    bool? adjust,
    int flipBits = 0,
    double rotDeg = 0,
    double turnY = 0,
    double tiltX = 0,
  }) {
    final ph = h * heightFrac;
    final pw = ph * aspect;
    final tinted = _nightTint(_propFx(child,
        flip: flipBits, rotDeg: rotDeg, turnY: turnY, tiltX: tiltX));
    final adjusting = adjust ?? widget.wagon2Adjust;
    if (!adjusting) {
      // Hors mode ajuster : tappable si onTap fourni (ex. armoire = garde-robe),
      // sinon décoratif (ignore les pointeurs).
      return Positioned(
        left: w * cx - pw / 2,
        top: h * topY,
        width: pw,
        height: ph,
        child: onTap == null
            ? IgnorePointer(child: tinted)
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: tinted,
              ),
      );
    }
    return Positioned(
      left: w * cx - pw / 2,
      top: h * topY,
      width: pw,
      height: ph,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: (_) => _scaleStartH = heightFrac,
        onScaleUpdate: (d) {
          setState(() {
            if (d.pointerCount >= 2) {
              onResize((_scaleStartH * d.scale).clamp(0.04, 1.4));
            } else {
              onMove(d.focalPointDelta.dx / w, d.focalPointDelta.dy / h);
            }
          });
        },
        onScaleEnd: (_) => GameState.instance.save(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: tinted),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: const Color(0xCCE8B96B), width: 1.2),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -14,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFE8B96B),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tous les props du cellier : Shen-douche + pommeau (eau on/off) + panneau
  // Props AJUSTABLES du wagon 1 : lampe (animée, on/off), bac de culture
  // (ex-tour hydro), filtre à eau (électrique animé), poêle à bois (allumé).
  // Position + taille réglables en mode ajuster debug (GameState.wagon1Props).
  /// Sprite simple d'un prop du salon (sans interaction) pour le mode ajuster.
  Widget _salonSprite(_PropDef def) {
    if (def.key == 'bowl') {
      return Image.asset(
          _bowlFull ? 'assets/objects/bowl_full.png'
                    : 'assets/objects/bowl_empty.png',
          fit: BoxFit.contain);
    }
    // Carillon animé : pas de carillon.png ; le static a un triangle blanc mal
    // détouré -> on montre la 1re frame animée (propre, fond transparent).
    if (def.key == 'carillon') {
      return Image.asset('assets/objects/carillon_1.png', fit: BoxFit.contain);
    }
    return Image.asset('assets/objects/${def.key}.png', fit: BoxFit.contain);
  }

  /// Prop du salon en mode AJUSTER : déplaçable + redimensionnable (debug).
  Widget _buildSalonDrag(_PropDef def, double w, double h) {
    final gs = GameState.instance;
    final k = def.key;
    // Aspect RÉEL de l'image -> _w2Drag (pw = ph*aspect) produit la MÊME boîte
    // que _buildProp (propW = propH*aspect) et colle pile à l'objet.
    final aspect = _salonAspect[k] ?? (w / h) * gs.slw(k) / gs.slh(k);
    return _w2Drag(
      w: w, h: h,
      cx: gs.slx(k), topY: gs.sly(k), heightFrac: gs.slh(k),
      aspect: aspect, label: k, adjust: true,
      flipBits: gs.slFlip(k), rotDeg: gs.slRot(k),
      turnY: gs.slTurnY(k), tiltX: gs.slTiltX(k),
      child: _salonSprite(def),
      onMove: (dx, dy) => gs.slMove(k, dx, dy),
      onResize: (nh) => gs.slResize(k, nh),
    );
  }

  // Déco-souvenir (photo/peluche/fleurs) : visible si son souvenir est vécu
  // (ou en debug), déplaçable en mode ajuster comme les autres props salon.
  Widget _buildDeco(String key, String flag, double w, double h) {
    final gs = GameState.instance;
    if (!gs.debugMode && !gs.cardFlags.contains(flag)) {
      return const SizedBox.shrink();
    }
    final asp = _salonAspect[key] ?? 1.0;
    if (widget.salonAdjust) {
      return _w2Drag(
        w: w, h: h,
        cx: gs.slx(key), topY: gs.sly(key), heightFrac: gs.slh(key),
        aspect: asp, label: key, adjust: true,
        flipBits: gs.slFlip(key), rotDeg: gs.slRot(key),
        turnY: gs.slTurnY(key), tiltX: gs.slTiltX(key),
        onMove: (dx, dy) => gs.slMove(key, dx, dy),
        onResize: (nh) => gs.slResize(key, nh),
        child: Image.asset('assets/objects/$key.png', fit: BoxFit.contain),
      );
    }
    // Rendu normal : miroir + inclinaison + bascule 3D persistés.
    final img = _propFx(
        Image.asset('assets/objects/$key.png', fit: BoxFit.contain),
        flip: gs.slFlip(key),
        rotDeg: gs.slRot(key),
        turnY: gs.slTurnY(key),
        tiltX: gs.slTiltX(key));
    final sp = gs.salonProps[key]!;
    final propH = h * sp[2];
    final propW = propH * asp;
    return Positioned(
      left: w * sp[0] - propW / 2,
      top: h * sp[1],
      width: propW,
      height: propH,
      child: _nightTint(img),
    );
  }

  /// Applique les réglages visuels d'un prop : miroir H/V, inclinaison (°),
  /// bascule 3D perspective (turnY = axe vertical « porte », tiltX = axe
  /// horizontal « penché ») — mêmes réglages dans les TROIS wagons.
  Widget _propFx(Widget child,
      {int flip = 0, double rotDeg = 0, double turnY = 0, double tiltX = 0}) {
    var out = child;
    if (flip != 0) {
      out = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scaleByDouble(
            (flip & 1) != 0 ? -1.0 : 1.0,
            (flip & 2) != 0 ? -1.0 : 1.0, 1.0, 1.0),
        child: out,
      );
    }
    if (rotDeg != 0) {
      out = Transform.rotate(angle: rotDeg * math.pi / 180, child: out);
    }
    if (turnY != 0 || tiltX != 0) {
      // Perspective légère, comme la map de la loco (setEntry(3,2)).
      out = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0008)
          ..rotateY(turnY)
          ..rotateX(tiltX),
        child: out,
      );
    }
    return out;
  }

  // --- Pad de réglage commun aux HUD d'ajuster (tap ligne = sélection) ---
  Widget _adjPadBtn(String lab, VoidCallback tap) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() {
          tap();
          GameState.instance.save();
        }),
        child: Container(
          margin: const EdgeInsets.only(right: 6, top: 5),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(lab,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
        ),
      );

  /// Pad COMPLET de l'objet sélectionné — IDENTIQUE dans les trois wagons :
  /// ◀▶▲▼ = position (pas 0.008), −＋ = taille (pas 0.01, sans pincer),
  /// ↔↕ = miroir H/V, ⟲⟳ = inclinaison (±2°), bH−/＋ = bascule 3D
  /// horizontale (axe vertical, « porte » comme la map de la loco),
  /// bV−/＋ = bascule 3D verticale (penché avant/arrière).
  Widget _adjPad({
    required void Function(double dx, double dy) move,
    required void Function(double dh) size,
    required void Function(int bit) flip,
    required void Function(double deg) rotate,
    required void Function(double d) turn,
    required void Function(double d) tilt,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            _adjPadBtn('◀', () => move(-0.008, 0)),
            _adjPadBtn('▶', () => move(0.008, 0)),
            _adjPadBtn('▲', () => move(0, -0.008)),
            _adjPadBtn('▼', () => move(0, 0.008)),
            _adjPadBtn('−', () => size(-0.01)),
            _adjPadBtn('＋', () => size(0.01)),
          ]),
          Row(mainAxisSize: MainAxisSize.min, children: [
            _adjPadBtn('↔', () => flip(1)),
            _adjPadBtn('↕', () => flip(2)),
            _adjPadBtn('⟲', () => rotate(-2)),
            _adjPadBtn('⟳', () => rotate(2)),
            _adjPadBtn('bH−', () => turn(-0.06)),
            _adjPadBtn('bH＋', () => turn(0.06)),
            _adjPadBtn('bV−', () => tilt(-0.06)),
            _adjPadBtn('bV＋', () => tilt(0.06)),
          ]),
        ],
      );

  /// Ligne de coords tapable : tap = sélectionne l'objet pour le pad.
  Widget _adjRow(String k, String text, bool selected) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _adjSel = k),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        color: selected ? const Color(0x66E8B96B) : Colors.transparent,
        child: Text(text,
            style: TextStyle(
                color: selected ? const Color(0xFFFFE2A8) : Colors.white,
                fontSize: 10,
                fontFamily: 'monospace')),
      ),
    );
  }

  /// Panneau d'ajuster UNIFIÉ (salon / atelier / cellier) : liste des objets
  /// (tap = sélection, 1er sélectionné par défaut) + pad complet TOUJOURS
  /// visible. Mêmes réglages partout : position, taille, miroir, inclinaison.
  Widget _adjustPanel(String title, List<_AdjItem> items) {
    final mq = MediaQuery.of(context);
    final sel = items.firstWhere((it) => it.key == _adjSel,
        orElse: () => items.first);
    return Positioned(
      left: 8,
      // + safe area (home indicator) sinon le bas passe sous l'écran.
      bottom: 8 + mq.padding.bottom,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$title — tap un objet puis règle au pad',
                style: const TextStyle(
                    color: Color(0xFFE8B96B),
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            // Liste scrollable plafonnée : ne déborde jamais de l'écran.
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: mq.size.height * 0.34),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final it in items)
                      _adjRow(it.key, it.info(), it.key == sel.key),
                  ],
                ),
              ),
            ),
            _adjPad(
                move: sel.move,
                size: sel.size,
                flip: sel.flip,
                rotate: sel.rotate,
                turn: sel.turn,
                tilt: sel.tilt),
          ],
        ),
      ),
    );
  }

  /// Ligne d'infos COMPLÈTE (x/y/h + rotation + bascules + miroir) — sert
  /// aussi de source pour rebaker les défauts depuis une capture.
  static String _fxInfo(String k, double x, double y, double h, int flip,
          double rot, double turnY, double tiltX) =>
      '${k.padRight(12)} x${x.toStringAsFixed(3)} y${y.toStringAsFixed(3)} '
      'h${h.toStringAsFixed(3)} r${rot.toStringAsFixed(0)}° '
      'bH${turnY.toStringAsFixed(2)} bV${tiltX.toStringAsFixed(2)}'
      '${flip == 0 ? '' : ' m${(flip & 1) != 0 ? 'H' : ''}${(flip & 2) != 0 ? 'V' : ''}'}';

  Widget _salonCoordHud(GameState gs) {
    final keys = <String>[
      for (final def in _propDefs)
        if (gs.salonProps.containsKey(def.key)) def.key,
      'deco_photo', 'deco_peluche',
    ];
    return _adjustPanel('AJUSTER SALON', [
      for (final k in keys)
        _AdjItem(
          k,
          () => _fxInfo(k, gs.slx(k), gs.sly(k), gs.slh(k), gs.slFlip(k),
              gs.slRot(k), gs.slTurnY(k), gs.slTiltX(k)),
          (dx, dy) => gs.slMove(k, dx, dy),
          (dh) => gs.slResize(k, gs.slh(k) + dh),
          (bit) => gs.slToggleFlip(k, bit),
          (deg) => gs.slRotate(k, deg),
          (d) => gs.slTurn(k, d),
          (d) => gs.slTilt(k, d),
        ),
    ]);
  }

  Widget _buildWagon1Adjustable(double w, double h) {
    final gs = GameState.instance;
    Widget anim(String prefix, int n) => _AnimatedSprite(
        prefix: prefix, frameCount: n, durationMs: n * 90, fit: BoxFit.contain);
    Widget still(String asset) =>
        Image.asset(asset, fit: BoxFit.contain, gaplessPlayback: true);

    Widget prop(String key, String unlock, double aspect, Widget child,
            {bool? shown}) =>
        (shown ?? _propUnlocked(unlock))
            ? _w2Drag(
                w: w, h: h,
                cx: gs.w1x(key), topY: gs.w1y(key), heightFrac: gs.w1h(key),
                aspect: aspect, label: key, adjust: widget.wagon1Adjust,
                flipBits: gs.w1Flip(key), rotDeg: gs.w1Rot(key),
                turnY: gs.w1TurnY(key), tiltX: gs.w1TiltX(key),
                child: child,
                onMove: (dx, dy) => gs.w1Move(key, dx, dy),
                onResize: (nh) => gs.w1Resize(key, nh),
              )
            : const SizedBox.shrink();

    // Lampe : flamme animée, atténuée quand éteinte (lampOn).
    final lampChild = AnimatedBuilder(
      animation: gs,
      builder: (_, child) =>
          Opacity(opacity: gs.lampOn ? 1.0 : 0.18, child: child),
      child: anim('lamp', 49),
    );

    final fire = _fireLoop ?? kAlwaysCompleteAnimation;
    // Cuisinière : éteinte (frame 1) ou feu ANIMÉ EN BOUCLE pendant la cuisson.
    final cuisiniereChild = AnimatedBuilder(
      animation: fire,
      builder: (_, __) => still(
          'assets/objects/cuisiniere_${_cookLit ? _fireFrame : 1}.png'),
    );
    // Poêle à bois : éteint (frame 1) ou feu ANIMÉ EN BOUCLE tant qu'allumé.
    final poeleChild = AnimatedBuilder(
      animation: Listenable.merge([gs, fire]),
      builder: (_, __) => still(
          'assets/objects/poele_${gs.poeleOn ? _fireFrame : 1}.png'),
    );
    // Bac de culture : frame selon la pousse (0=semé … 1=fruits mûrs).
    final bacChild = AnimatedBuilder(
      animation: gs,
      builder: (_, __) => still(
          'assets/objects/bac_${(gs.bacGrowth * 24).round().clamp(0, 24) + 1}.png'),
    );

    return Positioned.fill(
      child: Stack(
        children: [
          prop('gaziniere', 'stove', 172 / 192, cuisiniereChild),
          prop('lamp', 'lamp', 268 / 507, lampChild),
          prop('bac', 'hydro', 204 / 212, bacChild),
          // Filtre = ANCIEN filtre (tank niveau d'eau), réglable.
          prop('filtre', 'filter', 196 / 356,
              _WaterTankSprite(level: _filterDisplayLevel, fit: BoxFit.contain)),
          prop('poele', 'stove', 150 / 218, poeleChild),
          // Objets basculés du salon vers l'atelier.
          prop('console', 'console', 992 / 319,
              Image.asset('assets/objects/console.png', fit: BoxFit.contain)),
          // Tourne-disque : échangé avec la table de jeu (elle → salon),
          // posé sur la console. Tap = musique (main._atTourneDisque).
          prop('tournedisque', 'tournedisque', 0.754,
              Image.asset('assets/objects/tournedisque.png',
                  fit: BoxFit.contain)),
          prop('radio', 'radio', 200 / 247, _RadioProp(night: widget.night),
              shown: gs.debugMode || gs.cardFlags.contains('aLaRadio')),
          // Float récolte/semis au-dessus du bac.
          if (_bacFloat != null && _propUnlocked('hydro'))
            _bacFloatWidget(w, h),
        ],
      ),
    );
  }

  Widget _bacFloatWidget(double w, double h) {
    final gs = GameState.instance;
    final cx = gs.w1x('bac') * w;
    final topY = (gs.w1y('bac') - 0.04 - (1 - _bacFloatT) * 0.05) * h;
    return Positioned(
      left: cx - 60,
      top: topY,
      width: 120,
      child: IgnorePointer(
        child: Opacity(
          opacity: _bacFloatT.clamp(0.0, 1.0),
          child: Text(
            _bacFloat!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF8BD18B),
              fontSize: 22,
              fontWeight: FontWeight.w800,
              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
        ),
      ),
    );
  }

  /// Float ambré ancré au-dessus de la tête de Shen (retour d'effet d'action /
  /// refus). Position calée comme la ThoughtBubble : X = position courante de
  /// Shen, Y au-dessus de sa tête, avec une montée douce pendant le fondu.
  Widget _heroFloatWidget(double w, double h) {
    final cx = _heroX * w;
    final topY = (0.40 - (1 - _heroFloatT) * 0.06) * h;
    return Positioned(
      left: cx - 80,
      top: topY,
      width: 160,
      child: IgnorePointer(
        child: Opacity(
          opacity: _heroFloatT.clamp(0.0, 1.0),
          child: Text(
            _heroFloat!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFE8B96B), // ambré
              fontSize: 16,
              fontWeight: FontWeight.w800,
              shadows: [
                Shadow(color: Colors.black, blurRadius: 4),
                Shadow(color: Colors.black, blurRadius: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _wagon1CoordHud(GameState gs) {
    // Tous les props ajustables de l'atelier, y compris ceux basculés du salon
    // (radio, console, tourne-disque) — sinon on ne peut pas les régler.
    const props = [
      'gaziniere', 'lamp', 'bac', 'filtre', 'poele',
      'radio', 'console', 'tournedisque',
    ];
    return _adjustPanel('AJUSTER ATELIER', [
      for (final k in props)
        _AdjItem(
          k,
          () => _fxInfo(k, gs.w1x(k), gs.w1y(k), gs.w1h(k), gs.w1Flip(k),
              gs.w1Rot(k), gs.w1TurnY(k), gs.w1TiltX(k)),
          (dx, dy) => gs.w1Move(k, dx, dy),
          (dh) => gs.w1Resize(k, (gs.w1h(k) + dh).clamp(0.03, 0.8)),
          (bit) => gs.w1ToggleFlip(k, bit),
          (deg) => gs.w1Rotate(k, deg),
          (d) => gs.w1Turn(k, d),
          (d) => gs.w1Tilt(k, d),
        ),
    ]);
  }

  // + baignoire + 2 lanternes. Déplaçables/redimensionnables en mode ajuster.
  // La baignoire est masquée pendant le bain (l'anim contient sa cuve).
  Widget _buildWagon2Props(double w, double h) {
    final gs = GameState.instance;
    // Pommeau : eau qui coule UNIQUEMENT pendant la douche, sinon sec.
    final pommeau = ValueListenableBuilder<int>(
      valueListenable: _heroAnim,
      builder: (_, __, ___) {
        // Eau qui coule en continu pendant la douche (même quand le corps
        // tient la pose), sinon pommeau sec.
        final wf = _showering ? (_showerWaterTick % 2) : 5; // 0/1 flux, 5 sec
        return Image.asset('assets/objects/showerhead_${wf + 1}.png',
            fit: BoxFit.contain, gaplessPlayback: true);
      },
    );
    Widget lamp() => const _AnimatedSprite(
        prefix: 'lamp', frameCount: 49, durationMs: 49 * 70);
    return Positioned.fill(
      child: Stack(
        children: [
          // Shen sous la douche (derrière pommeau + panneau).
          if (_showering) _buildShowerHeroine(w, h),
          // Douche (pommeau + panneau) : débloquée par l'histoire (asset_shower)
          // ou en mode debug (GameState.debugMode).
          if (_propUnlocked('shower'))
            _w2Drag(
              w: w, h: h, cx: gs.showerHeadX, topY: gs.showerHeadY,
              heightFrac: gs.showerHeadH, aspect: 229 / 672, label: 'pommeau',
              flipBits: gs.w2Flip('pommeau'), rotDeg: gs.w2Rot('pommeau'),
              turnY: gs.w2TurnY('pommeau'), tiltX: gs.w2TiltX('pommeau'),
              child: pommeau,
              onMove: (dx, dy) {
                gs.showerHeadX = (gs.showerHeadX + dx).clamp(0.02, 0.98);
                gs.showerHeadY = (gs.showerHeadY + dy).clamp(0.0, 0.85);
              },
              onResize: (nh) => gs.showerHeadH = nh,
            ),
          if (_propUnlocked('shower'))
            _w2Drag(
              w: w, h: h, cx: gs.showerPanelX, topY: gs.showerPanelY,
              heightFrac: gs.showerPanelH, aspect: 720 / 768, label: 'panneau',
              flipBits: gs.w2Flip('panneau'), rotDeg: gs.w2Rot('panneau'),
              turnY: gs.w2TurnY('panneau'), tiltX: gs.w2TiltX('panneau'),
              child: Image.asset('assets/objects/shower_panel.png',
                  fit: BoxFit.contain, gaplessPlayback: true),
              onMove: (dx, dy) {
                gs.showerPanelX = (gs.showerPanelX + dx).clamp(0.02, 0.98);
                gs.showerPanelY = (gs.showerPanelY + dy).clamp(0.0, 0.85);
              },
              onResize: (nh) => gs.showerPanelH = nh,
            ),
          // Vapeur de douche : devant le panneau, autour d'elle (ambiance +
          // léger voile). Seulement pendant la douche.
          if (_showering)
            _steam(w, h,
                cx: gs.showerPanelX,
                topY: 0.30,
                boxWFrac: 0.34,
                boxHFrac: 0.58,
                intensity: 1.3),
          // Baignoire : débloquée par l'histoire (asset_bath) ou en debug.
          if (_propUnlocked('bath') && !_bathing)
            _w2Drag(
              w: w, h: h, cx: gs.bathX, topY: gs.bathY,
              heightFrac: gs.bathH, aspect: 1376 / 768, label: 'baignoire',
              flipBits: gs.w2Flip('baignoire'), rotDeg: gs.w2Rot('baignoire'),
              turnY: gs.w2TurnY('baignoire'), tiltX: gs.w2TiltX('baignoire'),
              child: Image.asset('assets/objects/bathtub.png',
                  fit: BoxFit.contain, gaplessPlayback: true),
              onMove: (dx, dy) {
                gs.bathX = (gs.bathX + dx).clamp(0.02, 0.98);
                gs.bathY = (gs.bathY + dy).clamp(0.0, 0.85);
              },
              onResize: (nh) => gs.bathH = nh,
            ),
          // Lanternes du cellier : débloquées par l'histoire (asset_lantern,
          // gare 10) ou en debug. Masquées au départ.
          if (_propUnlocked('lantern'))
            _w2Drag(
              w: w, h: h, cx: gs.wagon2LampAx, topY: gs.wagon2LampAy,
              heightFrac: gs.wagon2LampAH, aspect: 1.0, label: 'lampe A',
              flipBits: gs.w2Flip('lampeA'), rotDeg: gs.w2Rot('lampeA'),
              turnY: gs.w2TurnY('lampeA'), tiltX: gs.w2TiltX('lampeA'),
              child: lamp(),
              onMove: (dx, dy) {
                gs.wagon2LampAx = (gs.wagon2LampAx + dx).clamp(0.04, 0.96);
                gs.wagon2LampAy = (gs.wagon2LampAy + dy).clamp(0.04, 0.80);
              },
              onResize: (nh) => gs.wagon2LampAH = nh,
            ),
          if (_propUnlocked('lantern'))
            _w2Drag(
              w: w, h: h, cx: gs.wagon2LampBx, topY: gs.wagon2LampBy,
              heightFrac: gs.wagon2LampBH, aspect: 1.0, label: 'lampe B',
              flipBits: gs.w2Flip('lampeB'), rotDeg: gs.w2Rot('lampeB'),
              turnY: gs.w2TurnY('lampeB'), tiltX: gs.w2TiltX('lampeB'),
              child: lamp(),
              onMove: (dx, dy) {
                gs.wagon2LampBx = (gs.wagon2LampBx + dx).clamp(0.04, 0.96);
                gs.wagon2LampBy = (gs.wagon2LampBy + dy).clamp(0.04, 0.80);
              },
              onResize: (nh) => gs.wagon2LampBH = nh,
            ),
          // Lueur chaude des lanternes — seulement si elles sont là.
          if (_propUnlocked('lantern'))
            for (final lampPos in [
              (gs.wagon2LampAx, gs.wagon2LampAy + gs.wagon2LampAH * 0.45),
              (gs.wagon2LampBx, gs.wagon2LampBy + gs.wagon2LampBH * 0.45),
            ])
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: widget.night ? 1.0 : 0.55,
                    child: LampGlow(
                      animation: _sky,
                      x: lampPos.$1,
                      y: lampPos.$2,
                      radius: 0.21,
                      floorY: 0.88, // sol du cellier
                    ),
                  ),
                ),
              ),
          // Armoire à vêtements (commode) : débloquée avec le cellier
          // (asset_commode, gare 6) ou en debug. Tap = ouvre la garde-robe,
          // déplaçable/redimensionnable en mode ajuster comme les autres props.
          if (_propUnlocked('commode'))
            _w2Drag(
              w: w, h: h, cx: gs.wagon2CommodeX, topY: gs.wagon2CommodeY,
              heightFrac: gs.wagon2CommodeH, aspect: 1.0,
              label: 'armoire',
              flipBits: gs.w2Flip('armoire'), rotDeg: gs.w2Rot('armoire'),
              turnY: gs.w2TurnY('armoire'), tiltX: gs.w2TiltX('armoire'),
              child: Image.asset('assets/objects/commode.png',
                  fit: BoxFit.contain, gaplessPlayback: true),
              onTap: widget.onOpenWardrobe,
              onMove: (dx, dy) {
                gs.wagon2CommodeX = (gs.wagon2CommodeX + dx).clamp(0.04, 0.96);
                gs.wagon2CommodeY = (gs.wagon2CommodeY + dy).clamp(0.04, 0.85);
              },
              onResize: (nh) => gs.wagon2CommodeH = nh,
            ),
          // Trousse de secours posée sur la commode (déplaçable).
          if (_propUnlocked('firstaid'))
            _w2Drag(
              w: w, h: h, cx: gs.wagon2FirstaidX, topY: gs.wagon2FirstaidY,
              heightFrac: gs.wagon2FirstaidH, aspect: 1.0, label: 'secours',
              flipBits: gs.w2Flip('secours'), rotDeg: gs.w2Rot('secours'),
              turnY: gs.w2TurnY('secours'), tiltX: gs.w2TiltX('secours'),
              child: Image.asset('assets/objects/firstaid.png',
                  fit: BoxFit.contain, gaplessPlayback: true),
              onMove: (dx, dy) {
                gs.wagon2FirstaidX = (gs.wagon2FirstaidX + dx).clamp(0.04, 0.96);
                gs.wagon2FirstaidY = (gs.wagon2FirstaidY + dy).clamp(0.04, 0.9);
              },
              onResize: (nh) => gs.wagon2FirstaidH = nh,
            ),
          // Bouquet de fleurs séchées (souvenir_fenetre) : déplacé au cellier.
          if (gs.debugMode || gs.cardFlags.contains('souvenir_fenetre'))
            _w2Drag(
              w: w, h: h, cx: gs.wagon2FleursX, topY: gs.wagon2FleursY,
              heightFrac: gs.wagon2FleursH, aspect: 705 / 905, label: 'fleurs',
              flipBits: gs.w2Flip('fleurs'), rotDeg: gs.w2Rot('fleurs'),
              turnY: gs.w2TurnY('fleurs'), tiltX: gs.w2TiltX('fleurs'),
              child: Image.asset('assets/objects/deco_fleurs.png',
                  fit: BoxFit.contain, gaplessPlayback: true),
              onMove: (dx, dy) {
                gs.wagon2FleursX = (gs.wagon2FleursX + dx).clamp(0.04, 0.96);
                gs.wagon2FleursY = (gs.wagon2FleursY + dy).clamp(0.04, 0.9);
              },
              onResize: (nh) => gs.wagon2FleursH = nh,
            ),
        ],
      ),
    );
  }

  Widget _coordHud(GameState gs) {
    String l(String n, double x, double y, double hh) =>
        '${n.padRight(9)} x${x.toStringAsFixed(3)} y${y.toStringAsFixed(3)} h${hh.toStringAsFixed(3)}';
    // (clé, texte, move(dx,dy), size(dh)) — champs nommés du cellier.
    final rows = <(String, String, void Function(double, double),
        void Function(double))>[
      (
        'baignoire',
        l('baignoire', gs.bathX, gs.bathY, gs.bathH),
        (dx, dy) {
          gs.bathX = (gs.bathX + dx).clamp(0.02, 0.98);
          gs.bathY = (gs.bathY + dy).clamp(0.0, 0.92);
        },
        (dh) => gs.bathH = (gs.bathH + dh).clamp(0.03, 0.8)
      ),
      (
        'panneau',
        l('panneau  ', gs.showerPanelX, gs.showerPanelY, gs.showerPanelH),
        (dx, dy) {
          gs.showerPanelX = (gs.showerPanelX + dx).clamp(0.02, 0.98);
          gs.showerPanelY = (gs.showerPanelY + dy).clamp(0.0, 0.92);
        },
        (dh) => gs.showerPanelH = (gs.showerPanelH + dh).clamp(0.03, 0.8)
      ),
      (
        'pommeau',
        l('pommeau  ', gs.showerHeadX, gs.showerHeadY, gs.showerHeadH),
        (dx, dy) {
          gs.showerHeadX = (gs.showerHeadX + dx).clamp(0.02, 0.98);
          gs.showerHeadY = (gs.showerHeadY + dy).clamp(0.0, 0.92);
        },
        (dh) => gs.showerHeadH = (gs.showerHeadH + dh).clamp(0.03, 0.8)
      ),
      (
        'lampeA',
        l('lampe A  ', gs.wagon2LampAx, gs.wagon2LampAy, gs.wagon2LampAH),
        (dx, dy) {
          gs.wagon2LampAx = (gs.wagon2LampAx + dx).clamp(0.02, 0.98);
          gs.wagon2LampAy = (gs.wagon2LampAy + dy).clamp(0.0, 0.92);
        },
        (dh) => gs.wagon2LampAH = (gs.wagon2LampAH + dh).clamp(0.03, 0.8)
      ),
      (
        'lampeB',
        l('lampe B  ', gs.wagon2LampBx, gs.wagon2LampBy, gs.wagon2LampBH),
        (dx, dy) {
          gs.wagon2LampBx = (gs.wagon2LampBx + dx).clamp(0.02, 0.98);
          gs.wagon2LampBy = (gs.wagon2LampBy + dy).clamp(0.0, 0.92);
        },
        (dh) => gs.wagon2LampBH = (gs.wagon2LampBH + dh).clamp(0.03, 0.8)
      ),
      (
        'armoire',
        l('armoire  ', gs.wagon2CommodeX, gs.wagon2CommodeY, gs.wagon2CommodeH),
        (dx, dy) {
          gs.wagon2CommodeX = (gs.wagon2CommodeX + dx).clamp(0.02, 0.98);
          gs.wagon2CommodeY = (gs.wagon2CommodeY + dy).clamp(0.0, 0.92);
        },
        (dh) => gs.wagon2CommodeH = (gs.wagon2CommodeH + dh).clamp(0.03, 0.8)
      ),
      (
        'secours',
        l('secours  ', gs.wagon2FirstaidX, gs.wagon2FirstaidY,
            gs.wagon2FirstaidH),
        (dx, dy) {
          gs.wagon2FirstaidX = (gs.wagon2FirstaidX + dx).clamp(0.02, 0.98);
          gs.wagon2FirstaidY = (gs.wagon2FirstaidY + dy).clamp(0.0, 0.92);
        },
        (dh) => gs.wagon2FirstaidH = (gs.wagon2FirstaidH + dh).clamp(0.03, 0.8)
      ),
      (
        'fleurs',
        l('fleurs   ', gs.wagon2FleursX, gs.wagon2FleursY, gs.wagon2FleursH),
        (dx, dy) {
          gs.wagon2FleursX = (gs.wagon2FleursX + dx).clamp(0.02, 0.98);
          gs.wagon2FleursY = (gs.wagon2FleursY + dy).clamp(0.0, 0.92);
        },
        (dh) => gs.wagon2FleursH = (gs.wagon2FleursH + dh).clamp(0.03, 0.8)
      ),
    ];
    // Panneau UNIFIÉ : mêmes réglages que salon/atelier (pad complet, miroir
    // + inclinaison + bascule 3D via wagon2FlipRot).
    return _adjustPanel('AJUSTER CELLIER', [
      for (final r in rows)
        _AdjItem(
          r.$1,
          () => '${r.$2} r${gs.w2Rot(r.$1).toStringAsFixed(0)}° '
              'bH${gs.w2TurnY(r.$1).toStringAsFixed(2)} '
              'bV${gs.w2TiltX(r.$1).toStringAsFixed(2)}'
              '${gs.w2Flip(r.$1) == 0 ? '' : ' m${(gs.w2Flip(r.$1) & 1) != 0 ? 'H' : ''}${(gs.w2Flip(r.$1) & 2) != 0 ? 'V' : ''}'}',
          r.$3,
          r.$4,
          (bit) => gs.w2ToggleFlip(r.$1, bit),
          (deg) => gs.w2Rotate(r.$1, deg),
          (d) => gs.w2Turn(r.$1, d),
          (d) => gs.w2Tilt(r.$1, d),
        ),
    ]);
  }

  // Voile de vapeur animé (bain/douche). Boîte centrée sur cx ; la vapeur
  // monte du bas vers le haut. Cadencé sur _smoke (6s).
  Widget _steam(
    double w,
    double h, {
    required double cx,
    required double topY,
    required double boxWFrac,
    required double boxHFrac,
    double intensity = 1.0,
  }) {
    final bw = w * boxWFrac;
    return Positioned(
      left: w * cx - bw / 2,
      top: h * topY,
      width: bw,
      height: h * boxHFrac,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _smoke,
          builder: (_, __) => CustomPaint(
            painter: _SteamPainter(_smoke.value, intensity: intensity),
          ),
        ),
      ),
    );
  }

  // Anim bain : bath_1..8 (cuve + Shen) calée sur la boîte de la baignoire
  // statique (même largeur, bas aligné) pour une transition propre.
  Widget _buildBathAnim(double w, double h) {
    final gs = GameState.instance;
    // Boîte de la baignoire statique.
    final boxW = (h * gs.bathH) * (1376 / 768);
    final boxH = h * gs.bathH;
    // Bas de la cuve : ~0.884 de la hauteur de boîte dans les deux assets.
    final contentBottom = h * gs.bathY + 0.884 * boxH;
    // La cuve fait 70.1% de large dans bathtub.png mais ~92.9% dans la cellule
    // d'anim -> on réduit la boîte d'anim pour matcher la largeur de cuve.
    final animW = boxW * (0.701 / 0.929);
    final animH = animW * (336 / 396); // ratio cellule bain
    return Positioned(
      left: w * gs.bathX - animW / 2,
      top: contentBottom - 0.884 * animH,
      width: animW,
      height: animH,
      child: IgnorePointer(
        // Écoute le ticker pour avancer les frames (sinon figée).
        child: ValueListenableBuilder<int>(
          valueListenable: _heroAnim,
          builder: (_, __, ___) => _nightTint(
            Image.asset('assets/characters/bath_${_bathFrame + 1}.png',
                fit: BoxFit.contain, gaplessPlayback: true),
          ),
        ),
      ),
    );
  }

  // Shen sous la douche : sprite plein corps calé au sol sous le x du
  // panneau (auto-align). Le panneau (rendu après) cache le bas du corps.
  Widget _buildShowerHeroine(double w, double h) {
    final gs = GameState.instance;
    final sh = h * 0.44; // un peu plus petite -> effet de profondeur
    final sw = sh * (198 / 672);
    // Pieds calés DERRIÈRE le bas du panneau (un peu en profondeur) pour
    // qu'ils ne dépassent pas en dessous.
    final feetY = h * (gs.showerPanelY + gs.showerPanelH - 0.03);
    return Positioned(
      left: w * gs.showerHeadX - sw / 2,
      top: feetY - sh,
      width: sw,
      height: sh,
      child: IgnorePointer(
        child: ValueListenableBuilder<int>(
          valueListenable: _heroAnim,
          builder: (_, __, ___) => _nightTint(
            Image.asset('assets/characters/shower_${_showerFrame + 1}.png',
                fit: BoxFit.contain, gaplessPlayback: true),
          ),
        ),
      ),
    );
  }

  // Props débloqués par l'histoire (choix de cartes -> apparaissent dans le
  // wagon = sentiment de progression). lit (gare 1), filtre (gare 4),
  // hydro (gare 10). Le reste est toujours présent.
  //
  // Déblocage = SOURCE UNIQUE dans GameState (lue aussi par main.dart pour
  // l'interactivité). Visibilité et clic sont ainsi toujours cohérents.
  bool _propUnlocked(String key) => GameState.instance.propUnlocked(key);
  bool get _bedUnlocked => GameState.instance.propUnlocked('bed');
  bool get _dogShown => GameState.instance.dogShown;
  bool get _sisterShown => GameState.instance.sisterShown;

  Widget _buildProp({
    required _PropDef def,
    required double w,
    required double h,
  }) {

    // Coords du salon = persistées (réglables en debug) ; fallback sur la
    // table figée pour tout prop hors salon.
    final sp = GameState.instance.salonProps[def.key];
    final pos = sp != null
        ? _PropPos(sp[0], sp[1], sp[2], sp[3])
        : _propPos[def.key]!;
    final propH = h * pos.height;
    // Largeur dérivée de l'aspect réel de l'image (boîte = objet, pas de
    // letterbox) ; fallback sur l'ancienne largeur pour les clés hors table.
    final asp = _salonAspect[def.key];
    final propW = asp != null ? propH * asp : w * pos.width;
    final left = w * pos.left - propW / 2;
    final top = h * pos.top;
    // La gamelle a 2 états (full / empty) → asset différent selon
    // [_bowlFull]. Le reste suit le mapping standard (animé ou statique).
    final String staticAsset = def.key == 'bowl'
        ? (_bowlFull ? 'assets/objects/bowl_full.png'
                     : 'assets/objects/bowl_empty.png')
        : 'assets/objects/${def.key}.png';
    const boxFit = BoxFit.contain;
    Widget sprite;
    if (def.animated) {
      sprite = _AnimatedSprite(
        prefix: def.key,
        frameCount: def.frameCount,
        durationMs: _PropDef.frameDurationMs * def.frameCount,
        fit: boxFit,
      );
    } else {
      sprite = Image.asset(
        staticAsset,
        fit: boxFit,
      );
    }
    // Miroir + inclinaison + bascule 3D persistés (réglés au pad d'ajuster).
    final gs = GameState.instance;
    sprite = _propFx(sprite,
        flip: gs.slFlip(def.key),
        rotDeg: gs.slRot(def.key),
        turnY: gs.slTurnY(def.key),
        tiltX: gs.slTiltX(def.key));
    final Widget wrapped = _nightTint(sprite);

    // bowl = tap pour remplir si vide, reste = inert. (L'armoire/commode a
    // été déplacée dans le cellier — voir _buildWagon2Props.)
    if (def.key == 'bowl') {
      return Positioned(
        left: left,
        top: top,
        width: propW,
        height: propH,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Tap = toggle plein ↔ vide. REMPLIR la gamelle (vide -> plein) quand
          // le chien est là = on le nourrit -> petit moral confort (throttlé par
          // le cooldown partagé anti-farm) + float. Sans chien : juste cosmétique.
          onTap: _onBowlTap,
          child: wrapped,
        ),
      );
    }
    return Positioned(
      left: left,
      top: top,
      width: propW,
      height: propH,
      child: IgnorePointer(child: wrapped),
    );
  }


  // Masque le chien statique pendant que la soeur le câline/caresse
  // (sa sprite d'interaction contient déjà le chien).

  // Petite soeur autonome : danse au repos, joue une anim toutes les ~20s.
  // PLACÉE AU CENTRE pour le test ; on la repositionnera plus tard.
  Widget _buildSister(double w, double h) {
    // Petite soeur MOBILE : se balade dans le wagon. Position rapportée dans
    // _sisterX pour que l'interaction (duo) la suive.
    return Positioned.fill(
      child: _SisterCharacter(
        key: const ValueKey('sister'),
        tint: _nightTint,
        heightFrac: 0.28,
        // Sol du wagon : salon 0.74, atelier 0.785 (comme l'héroïne).
        feetY: widget.isAtelier ? 0.785 : 0.74,
        startX: _sisterX,
        minX: 0.18,
        maxX: 0.60,
        night: widget.night,
        bedCenterX: _bedLeft + _bedWidth / 2,
        bedTopY: _bedTop,
        bedWidth: _bedWidth,
        onSettled: (x) {
          _sisterX = x;
          widget.onSisterX?.call(x);
        },
      ),
    );
  }

  // Sprite DUO (câlin ou lecture) calé au sol sur la position de la sœur.
  // Remplace les deux solos pendant l'anim.
  Widget _buildDuo(double w, double h) {
    final duoH = h * _duoHeightFrac;
    final duoW = duoH * _duoAspect;
    // Sol du wagon : salon 0.74, atelier 0.785 (comme l'héroïne).
    final feetY = h * (widget.isAtelier ? 0.785 : 0.74);
    // Le jeu se joue À la table (salon, sa position) ; lecture/câlin restent
    // près de la sœur.
    final anchorX = _duoAnim == 'playduo'
        ? (GameState.instance.salonProps['jeu']?[0] ?? _sisterX)
        : _sisterX;
    return Positioned(
      left: anchorX * w - duoW / 2,
      top: feetY - duoH, // contenu collé en bas -> pieds au sol
      width: duoW,
      height: duoH,
      child: IgnorePointer(
        child: ValueListenableBuilder<int>(
          valueListenable: _heroAnim,
          builder: (_, __, ___) => _nightTint(
            Image.asset('assets/characters/${_duoAnim}_${_duoFrame + 1}.png',
                fit: BoxFit.contain, gaplessPlayback: true),
          ),
        ),
      ),
    );
  }

  // Sprite Shen + husky (caresse/câlin) calé au sol sur la position du chien.
  Widget _buildPetDog(double w, double h) {
    final ph = h * 0.21; // nettement plus petit
    final pw = ph * (423 / 324);
    final feetY = h * 0.74;
    return Positioned(
      left: _dogX * w - pw / 2,
      top: feetY - ph, // contenu collé en bas
      width: pw,
      height: ph,
      child: IgnorePointer(
        child: ValueListenableBuilder<int>(
          valueListenable: _heroAnim,
          builder: (_, __, ___) => _nightTint(
            Image.asset('assets/characters/petdog_${_petDogFrame + 1}.png',
                fit: BoxFit.contain, gaplessPlayback: true),
          ),
        ),
      ),
    );
  }


  Widget _buildStaticDog(double w, double h) {
    // Chien autonome MOBILE : se balade dans le wagon. Position rapportée
    // dans _dogX pour que la caresse le suive.
    return Positioned.fill(
      child: _DogCharacter(
        key: const ValueKey('dog'),
        tint: _nightTint,
        heightFrac: widget.dogHeight,
        feetY: 0.74,
        startX: _dogX,
        minX: 0.30,
        maxX: 0.80,
        night: widget.night,
        onSettled: (x) {
          _dogX = x;
          widget.onDogX?.call(x);
        },
      ),
    );
  }

  // Anim perso+meuble (chair_read / dog_basket) calée sur la position du prop
  // statique correspondant (mêmes coords -> remplace pile le meuble vide).
  Widget _buildCharAtProp(double w, double h, String propKey, String prefix,
      int frames, int frameMs) {
    final sp = GameState.instance.salonProps[propKey];
    final pos = sp != null
        ? _PropPos(sp[0], sp[1], sp[2], sp[3])
        : _propPos[propKey]!;
    final propW = w * pos.width;
    final propH = h * pos.height;
    return Positioned(
      left: w * pos.left - propW / 2,
      top: h * pos.top,
      width: propW,
      height: propH,
      child: IgnorePointer(
        child: _nightTint(_AnimatedSprite(
          prefix: prefix,
          dir: 'assets/characters',
          frameCount: frames,
          durationMs: frames * frameMs,
        )),
      ),
    );
  }

  Widget _buildChairRead(double w, double h) =>
      _buildCharAtProp(w, h, 'fauteuil', 'chair_read', 6, 430);

  Widget _buildDogBasket(double w, double h) =>
      _buildCharAtProp(w, h, 'panier', 'dog_basket', 6, 360);

  Widget _buildHeroine(double w, double h) {
    // Pendant bain/douche/câlin, Shen est rendue par l'anim dédiée (duo) ->
    // on masque le sprite héroïne normal.
    if (_bathing || _showering || _duoActive || _petDog || _chairReading) {
      return const SizedBox.shrink();
    }
    // Wagon's interior floor sits roughly at this Y. Le 2e wagon (cellier)
    // est dessiné plus grand dans le cadre -> son sol est plus bas.
    // SALON (wagon 1) : son sol peint est plus HAUT que celui de l'atelier ->
    // Shen y tombait trop près du bord AVANT (en profondeur). On la remonte un
    // peu (feetY plus petit = plus loin dans la pièce). N'AFFECTE QUE le salon ;
    // atelier (0.785) et cellier (0.80) inchangés. (Ajustable : ce seul nombre.)
    final feetY = h *
        (widget.secondWagon
            ? 0.80
            : (widget.isAtelier ? 0.785 : 0.745));
    final anchorX = _heroX * w;

    // Cas spéciaux ancrés sur le lit : la fille n'est pas sur le sol,
    // la géométrie est driven par les offsets bedAdjust (bakés). On
    // garde ces deux branches en early-return car le placement diffère
    // trop de la formule générale feetY-anchored.
    if (_heroSleeping && _sleepOnBed) {
      // Allongée sur le matelas, sprite mirroré (tête côté oreiller).
      final asset = 'assets/characters/sleep_right_${_sleepFrame + 1}.png';
      final bodyLen = h * _sleepBedScale;
      final bodyThick = bodyLen / (366 / 103);
      final bedCenterX = (_bedLeft + _bedWidth / 2) * w;
      final left = bedCenterX + _sleepBedOffsetX * w - bodyLen / 2;
      final top = (_bedTop + _sleepBedOffsetY) * h - bodyThick / 2;
      return Positioned(
        left: left,
        top: top,
        width: bodyLen,
        height: bodyThick,
        child: IgnorePointer(
          child: _nightTint(
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..scaleByDouble(-1.0, 1.0, 1.0, 1.0),
              child: Image.asset(asset,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                cacheWidth: kHeroDecodeWidth),
            ),
          ),
        ),
      );
    }
    if (_waking && _wakingPhase == 0 && _sleepOnBed) {
      // wake_up sur le matelas (avant que stretch ne reparte au sol).
      final asset = 'assets/characters/wake_up_${_wakingFrame + 1}.png';
      final m = animMetricsFor('wake_up');
      final heroHeight = h * kHeroBaseHeight * m.scale;
      final heroWidth = heroHeight * m.aspect;
      final bedCenterX = (_bedLeft + _bedWidth / 2) * w;
      return Positioned(
        left: bedCenterX - heroWidth / 2,
        top: (_bedTop + _sleepBedOffsetY) * h - heroHeight * 0.5,
        width: heroWidth,
        height: heroHeight,
        child: IgnorePointer(
          child: _nightTint(Image.asset(asset,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              cacheWidth: kHeroDecodeWidth)),
        ),
      );
    }

    // Dispatch unifié : choisit l'anim active selon l'état, puis lookup
    // metrics et render avec une formule unique (feetY-anchored).
    String prefix;
    int frame;
    if (_activeSpecial != null) {
      prefix = _activeSpecial!;
      frame = _specialFrame;
    } else if (_doorPushing) {
      prefix = 'open_door';
      frame = _doorFrame;
    } else if (_waking) {
      prefix = _wakingPhase == 0 ? 'wake_up' : 'stretch';
      frame = _wakingFrame;
    } else if (_heroSleeping) {
      prefix = 'sleep_right';
      frame = _sleepFrame;
    } else if (_heroLyingDown) {
      prefix = 'pickup';
      frame = _lieDownFrame;
    } else if (_heroDancing) {
      prefix = 'dance';
      frame = _danceFrame;
    } else if (_heroTarget != null) {
      prefix = 'walk_right';
      frame = _walkFrame;
    } else {
      prefix = 'idle_right';
      frame = _idleFrame;
    }

    final m = animMetricsFor(prefix);
    // Cellier plus grand -> on agrandit un peu Shen pour qu'elle ne paraisse
    // pas minuscule dans le volume.
    final wagonScale = widget.secondWagon ? 1.12 : 1.1;
    final heroHeight = h * kHeroBaseHeight * m.scale * wagonScale;
    final heroWidth = heroHeight * m.aspect;
    final asset = 'assets/characters/${prefix}_${frame + 1}.png';

    // Mirror logic :
    //  - door_push source pousse vers la droite, porte loco est à
    //    gauche → toujours mirror en wagon.
    //  - sprites noMirror (composition fixe : read, dance, sleep…) :
    //    jamais flippés.
    //  - sinon : mirror quand le perso regarde à gauche.
    final bool shouldMirror;
    if (prefix == 'open_door') {
      shouldMirror = !_doorPushRight;
    } else if (m.noMirror) {
      shouldMirror = false;
    } else {
      shouldMirror = !_heroFacingRight;
    }

    // Ancrage HORIZONTAL sur le PERSO (pas la boîte) : on cale le centre du
    // perso (m.cx, miroité si besoin) sur anchorX. Évite le "saut" au passage
    // entre anims à boîtes de largeurs différentes (ex. idle -> open_door).
    final effCx = shouldMirror ? (1 - m.cx) : m.cx;
    // cacheWidth = résolution source des plus grands sprites (512 px) -> aucune
    // perte de qualité, mais borne dur le décodage. La MÊME clé est utilisée au
    // précache (loading_screen + main._warmLocoAnims) pour partager le cache et
    // ne pas doubler l'empreinte mémoire.
    Widget sprite = Image.asset(asset,
        fit: BoxFit.contain, gaplessPlayback: true, cacheWidth: kHeroDecodeWidth);
    if (shouldMirror) {
      sprite = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scaleByDouble(-1.0, 1.0, 1.0, 1.0),
        child: sprite,
      );
    }
    // TENUE CHAUDE — overlay simple : une écharpe peinte par-dessus le sprite
    // quand une tenue chaude est portée (outfitWarmth > 0). Affichée seulement
    // sur idle/walk (les autres anims ont des poses trop différentes).
    if (GameState.instance.outfitWarmth > 0 &&
        (prefix == 'idle_right' || prefix == 'walk_right')) {
      sprite = Stack(
        fit: StackFit.expand,
        children: [
          sprite,
          CustomPaint(
            painter: _ScarfPainter(
              facingRight: !shouldMirror,
              neckCx: effCx,
              sway: (frame % 49) / 49.0,
            ),
          ),
        ],
      );
    }
    sprite = _nightTint(sprite);

    return Positioned(
      left: anchorX - heroWidth * effCx,
      top: feetY - heroHeight * m.feet,
      width: heroWidth,
      height: heroHeight,
      child: RepaintBoundary(child: IgnorePointer(child: sprite)),
    );
  }

  String _wagonAssetFor(int stage) {
    final assets = widget.secondWagon
        ? const [
            'assets/background/wagon2_messy.png',
            'assets/background/wagon2_clean.png',
          ]
        : widget.isAtelier
            ? const [
                'assets/background/atelier_messy.png',
                'assets/background/atelier_clean.png',
              ]
            : const [
                'assets/background/wagon_windowed.png',
                'assets/background/wagon_clean.png',
              ];
    final i = stage.clamp(0, assets.length - 1);
    return assets[i];
  }

  /// Multiplies a child by a cool blue-grey when [widget.night] is on, so
  /// daylit assets read as nighttime without needing redrawn variants.
  Widget _nightTint(Widget child) {
    Widget result = child;
    if (!widget.night && GameState.instance.inColdZone) {
      result = ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Color(0xFFDDE3EE),
          BlendMode.modulate,
        ),
        child: result,
      );
    }
    if (!widget.night) return result;
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(
        Color(0xFF4A5C82),
        BlendMode.modulate,
      ),
      child: result,
    );
  }
}

/// Translates an asset horizontally to give the illusion of infinite scroll.
/// Renders two copies side-by-side and shifts both together; when one slides
/// fully off-screen left, its partner takes over without a visible jump.
/// Définition statique d'un prop : sa clé d'asset, son label HUD, et
/// s'il est animé (49 frames) ou statique (1 PNG `assets/objects/<key>.png`).
class _PropDef {
  const _PropDef(
    this.key,
    this.label, {
    required this.animated,
    // ignore: unused_element_parameter
    this.frameCount = 1,
  });

  final String key;
  final String label;
  final bool animated;
  final int frameCount;
  static const int frameDurationMs = 70; // durée d'une frame de prop animé
}

/// Position normalisée d'un prop dans la scène (centres x,y + hauteur
/// en fraction de h). Mutable pour permettre le drag en mode adjust.
class _PropPos {
  _PropPos(this.left, this.top, this.height, [double? width])
      : width = width ?? height;
  double left;
  double top;
  double height;
  double width;
}

/// Joue une animation `assets/objects/<prefix>_<i>.png` en boucle via un
/// AnimationController. Plus léger qu'un Ticker custom pour les props
/// qui n'ont pas de logique d'état.
class _AnimatedSprite extends StatefulWidget {
  const _AnimatedSprite({
    required this.prefix,
    required this.frameCount,
    required this.durationMs,
    this.fit = BoxFit.contain,
    this.dir = 'assets/objects',
  });

  final String prefix;
  final int frameCount;
  final int durationMs;
  final BoxFit fit;
  final String dir;
  // Les props sont petits à l'écran : on décode toujours à 256px (allège le
  // cache, matche le précache).
  static const int _resizeWidth = 256;

  @override
  State<_AnimatedSprite> createState() => _AnimatedSpriteState();
}

class _AnimatedSpriteState extends State<_AnimatedSprite>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.durationMs),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final frame = (_ctrl.value * widget.frameCount)
            .floor()
            .clamp(0, widget.frameCount - 1);
        final asset = '${widget.dir}/${widget.prefix}_${frame + 1}.png';
        return Image(
          image: ResizeImage(AssetImage(asset),
              width: _AnimatedSprite._resizeWidth),
          fit: widget.fit,
          gaplessPlayback: true,
        );
      },
    );
  }
}

/// Petite sœur autonome dans le wagon. Au repos = boucle idle debout
/// (`sister_idle`, 49f). De temps en temps elle se déplace (`sister_walk`,
/// vrai cycle de profil 49f), frissonne si froid (`sister_cold`). **La nuit**
/// elle va se coucher sur le lit (`sister_sleep`, mirroré tête-oreiller) et se
/// réveille au lever du jour. Reporte sa position via [onSettled].
class _SisterCharacter extends StatefulWidget {
  const _SisterCharacter({
    super.key,
    required this.tint,
    required this.heightFrac,
    required this.feetY,
    required this.startX,
    required this.minX,
    required this.maxX,
    required this.onSettled,
    this.night = false,
    required this.bedCenterX,
    required this.bedTopY,
    required this.bedWidth,
  });

  final Widget Function(Widget child) tint;
  final double heightFrac;
  final double feetY;
  final double startX;
  final double minX;
  final double maxX;
  final ValueChanged<double> onSettled;
  // La nuit : elle va se coucher sur le lit (dodo groupé).
  final bool night;
  final double bedCenterX;
  final double bedTopY;
  final double bedWidth;

  @override
  State<_SisterCharacter> createState() => _SisterCharacterState();
}

class _SisterCharacterState extends State<_SisterCharacter>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl; // frames gestes (walk / cold / sleep)
  late final AnimationController _move; // déplacement
  late final AnimationController _idle; // boucle idle debout (continu)
  Timer? _timer;
  final _rng = math.Random();

  late double _x = widget.startX;
  double _fromX = 0, _toX = 0;
  bool _faceRight = true;
  // null = idle (boucle debout) ; 'walk' ; 'cold' ; 'sleep' (sur le lit)
  String? _anim;
  int _frames = 49;
  bool _goingToBed = false;

  static const int _walkFrames = 49;
  static const int _idleFrames = 49;
  static const int _sleepFrames = 49;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _ctrl.addStatusListener((s) {
      // Walk + sleep bouclent (repeat) -> jamais "completed". Les gestes
      // one-shot (cold) reviennent à l'idle en fin.
      if (s == AnimationStatus.completed &&
          mounted &&
          _anim != 'walk' &&
          _anim != 'sleep') {
        setState(() => _anim = null);
      }
    });
    _move = AnimationController(vsync: this);
    _move.addListener(() {
      setState(() => _x = _fromX + (_toX - _fromX) * _move.value);
    });
    _move.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        if (_goingToBed) {
          _goingToBed = false;
          _startSleep();
        } else {
          _ctrl.stop();
          setState(() => _anim = null);
        }
        widget.onSettled(_x);
      }
    });
    // Idle : boucle debout calme (sister_idle), tourne en continu.
    _idle = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 4200))
      ..repeat();
    // Première décision rapide puis cadence régulière.
    Timer(Duration(milliseconds: 800 + _rng.nextInt(1600)), () {
      if (mounted) _decide();
    });
    _timer = Timer.periodic(const Duration(seconds: 7), (_) => _decide());
  }

  @override
  void didUpdateWidget(covariant _SisterCharacter old) {
    super.didUpdateWidget(old);
    // Le jour se lève -> elle se réveille et reprend sa vie.
    if (old.night && !widget.night && _anim == 'sleep') {
      _ctrl.stop();
      setState(() => _anim = null);
    }
    // La nuit tombe -> elle va se coucher PEU APRÈS (1-3 s), pas au prochain
    // tick de 7 s.
    if (!old.night && widget.night) {
      Timer(Duration(milliseconds: 1000 + _rng.nextInt(2000)), () {
        if (mounted &&
            widget.night &&
            _anim != 'sleep' &&
            !_goingToBed) {
          _walkTo(widget.bedCenterX, toBed: true);
        }
      });
    }
  }

  void _decide() {
    if (!mounted || _anim == 'walk' || _anim == 'sleep') return;
    // La nuit : direction le lit pour dormir.
    if (widget.night) {
      _walkTo(widget.bedCenterX, toBed: true);
      return;
    }
    final r = _rng.nextDouble();
    if (GameState.instance.feltCold && r < 0.35) {
      _play('cold', 8, 8 * 140);
    } else if (r < 0.62) {
      _walkTo(widget.minX + _rng.nextDouble() * (widget.maxX - widget.minX));
    } // sinon (~38 %) : pause -> boucle idle debout
  }

  void _play(String anim, int frames, int ms) {
    setState(() { _anim = anim; _frames = frames; });
    _ctrl.duration = Duration(milliseconds: ms);
    _ctrl.forward(from: 0);
  }

  void _walkTo(double tx, {bool toBed = false}) {
    _fromX = _x;
    _toX = tx.clamp(widget.minX, widget.maxX);
    if ((_toX - _fromX).abs() < 0.02) {
      if (toBed) _startSleep();
      return;
    }
    _faceRight = _toX > _fromX;
    _goingToBed = toBed;
    setState(() { _anim = 'walk'; _frames = _walkFrames; });
    _ctrl.duration = const Duration(milliseconds: 1300); // cycle de marche
    _ctrl.repeat();
    _move.duration = Duration(
        milliseconds: ((_toX - _fromX).abs() * 5500).clamp(800, 4500).round());
    _move.forward(from: 0);
  }

  void _startSleep() {
    _ctrl.stop();
    setState(() { _anim = 'sleep'; _frames = _sleepFrames; });
    _ctrl.duration = const Duration(milliseconds: 6500); // respiration lente
    _ctrl.repeat();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    _move.dispose();
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (_, c) {
          final w = c.maxWidth, h = c.maxHeight;
          if (_anim == 'sleep') return _buildSleepOnBed(w, h);
          final sisH = h * widget.heightFrac;
          final sisW = sisH; // sprites carrés
          Widget sprite = AnimatedBuilder(
            animation: Listenable.merge([_ctrl, _idle]),
            builder: (_, __) {
              final String asset;
              if (_anim == null) {
                // Idle : boucle debout calme (sister_idle).
                final f = (_idle.value * _idleFrames).floor().clamp(0, _idleFrames - 1);
                asset = 'assets/characters/sister_idle_${f + 1}.png';
              } else if (_anim == 'walk') {
                // Marche : vrai cycle de profil (49 frames) -> plus de pas inversés.
                final f = (_ctrl.value * _walkFrames).floor().clamp(0, _walkFrames - 1);
                asset = 'assets/characters/sister_walk_${f + 1}.png';
              } else {
                final f = (_ctrl.value * _frames).floor().clamp(0, _frames - 1);
                asset = 'assets/characters/sister_${_anim}_${f + 1}.png';
              }
              // Même cap que l'héroïne (512 = source, full quality) + clé de
              // cache alignée avec le précache (loading_screen).
              return Image.asset(asset,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  cacheWidth: kHeroDecodeWidth);
            },
          );
          // Profil orienté à DROITE par défaut -> miroir si elle va à gauche.
          if (_anim == 'walk' && !_faceRight) {
            sprite = Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..scaleByDouble(-1.0, 1.0, 1.0, 1.0),
              child: sprite,
            );
          }
          return Stack(children: [
            Positioned(
              left: _x * w - sisW / 2,
              top: widget.feetY * h - sisH * 0.85,
              width: sisW,
              height: sisH,
              child: widget.tint(sprite),
            ),
          ]);
        },
      ),
    );
  }

  // Sommeil sur le lit : le sprite sister_sleep a la tête à DROITE, l'oreiller
  // du lit est à GAUCHE -> on miroir horizontalement pour poser la tête sur
  // l'oreiller. Cadré sur le matelas à partir de la géométrie du lit.
  Widget _buildSleepOnBed(double w, double h) {
    // Contenu du sprite (MESURÉ) : corps horizontal occupant 0.738 du cadre en
    // largeur, centré verticalement à 0.563 du cadre. La sœur est petite -> on
    // limite la longueur à ~0.5 de la largeur du lit.
    final bodyLen = widget.bedWidth * 0.42 * w; // longueur du corps (réduite)
    final boxSize = bodyLen / 0.738;            // cadre 512 correspondant
    final left = widget.bedCenterX * w - boxSize / 2;
    final mattressY = (widget.bedTopY + 0.105) * h; // ligne du matelas (un peu + bas)
    final top = mattressY - 0.563 * boxSize;        // centre contenu sur matelas
    Widget img = AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final f = (_ctrl.value * _sleepFrames).floor().clamp(0, _sleepFrames - 1);
        return Image.asset('assets/characters/sister_sleep_${f + 1}.png',
            fit: BoxFit.contain,
            gaplessPlayback: true,
            cacheWidth: kHeroDecodeWidth);
      },
    );
    img = Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..scaleByDouble(-1.0, 1.0, 1.0, 1.0), // tête -> oreiller
      child: img,
    );
    return Stack(children: [
      Positioned(
        left: left,
        top: top,
        width: boxSize,
        height: boxSize,
        child: widget.tint(img),
      ),
    ]);
  }
}

/// Chien autonome : au repos posé (dog_idle), parfois une petite anim sur
/// place (s'étire, aboie…), et de temps en temps il **se déplace** dans le
/// wagon (dog_walk) vers une nouvelle position. Reporte sa position posée via
/// [onSettled] pour que les interactions (caresse) le suivent.
class _DogCharacter extends StatefulWidget {
  const _DogCharacter({
    super.key,
    required this.tint,
    required this.heightFrac,
    required this.feetY,
    required this.startX,
    required this.minX,
    required this.maxX,
    required this.onSettled,
    this.night = false,
  });
  final Widget Function(Widget child) tint;
  final double heightFrac;
  final double feetY;
  final double startX;
  final double minX;
  final double maxX;
  final ValueChanged<double> onSettled;
  final bool night;

  @override
  State<_DogCharacter> createState() => _DogCharacterState();
}

class _DogCharacterState extends State<_DogCharacter>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl; // frames
  late final AnimationController _move; // déplacement
  late final AnimationController _idle; // respiration au repos (continu)
  Timer? _timer;
  final _rng = math.Random();

  late double _x = widget.startX;
  double _fromX = 0, _toX = 0;
  bool _faceRight = true;
  String? _anim; // null = idle ; 'walk' ; ou une anim du pool
  int _frames = 25;
  bool _sleeping = false; // dort la nuit (sleep en boucle)

  static const _pool = [
    ('stretch_yawn', 2000), ('head_tilt', 1500), ('bark', 1400),
    ('wag_tail', 1600), ('lay_down', 2000), ('sleep', 2600),
  ];

  @override
  void didUpdateWidget(covariant _DogCharacter old) {
    super.didUpdateWidget(old);
    // Le jour se lève -> réveil.
    if (old.night && !widget.night && _sleeping) {
      _sleeping = false;
      _ctrl.stop();
      setState(() => _anim = null);
    }
    // La nuit tombe -> il se couche et dort PEU APRÈS (2-4 s).
    if (!old.night && widget.night) {
      Timer(Duration(milliseconds: 2000 + _rng.nextInt(2000)), () {
        if (mounted && widget.night && !_sleeping) _sleepNow();
      });
    }
  }

  void _sleepNow() {
    _move.stop();
    _sleeping = true;
    setState(() { _anim = 'sleep'; _frames = 25; });
    _ctrl.duration = const Duration(milliseconds: 3200); // respiration lente
    _ctrl.repeat();
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted && _anim != 'walk') {
        setState(() => _anim = null);
      }
    });
    _move = AnimationController(vsync: this);
    _move.addListener(() {
      setState(() => _x = _fromX + (_toX - _fromX) * _move.value);
    });
    _move.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        _ctrl.stop();
        setState(() => _anim = null);
        widget.onSettled(_x);
      }
    });
    // Respiration au repos : le chien se soulève doucement (jamais figé).
    _idle = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat(reverse: true);
    // Première décision rapide (1-3s) puis cadence régulière.
    Timer(Duration(milliseconds: 1000 + _rng.nextInt(2000)), () {
      if (mounted) _decide();
    });
    _timer = Timer.periodic(const Duration(seconds: 7), (_) => _decide());
  }

  void _decide() {
    if (!mounted || _anim == 'walk') return;
    if (widget.night || _sleeping) {
      // La nuit, il dort (pas de balade).
      if (!_sleeping) _sleepNow();
      return;
    }
    if (_rng.nextDouble() < 0.5) {
      _walkTo(widget.minX + _rng.nextDouble() * (widget.maxX - widget.minX));
    } else {
      final p = _pool[_rng.nextInt(_pool.length)];
      setState(() { _anim = p.$1; _frames = 25; });
      _ctrl.duration = Duration(milliseconds: p.$2);
      _ctrl.forward(from: 0);
    }
  }

  void _walkTo(double tx) {
    _fromX = _x;
    _toX = tx.clamp(widget.minX, widget.maxX);
    if ((_toX - _fromX).abs() < 0.03) return;
    _faceRight = _toX > _fromX;
    setState(() { _anim = 'walk'; _frames = 49; });
    _ctrl.duration = const Duration(milliseconds: 700);
    _ctrl.repeat();
    _move.duration = Duration(
        milliseconds: ((_toX - _fromX).abs() * 5000).clamp(700, 4000).round());
    _move.forward(from: 0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    _move.dispose();
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (_, c) {
          final w = c.maxWidth, h = c.maxHeight;
          final dogH = h * widget.heightFrac;
          final dogW = dogH;
          Widget sprite = AnimatedBuilder(
            animation: Listenable.merge([_ctrl, _idle]),
            builder: (_, __) {
              final String asset;
              if (_anim == null) {
                asset = 'assets/objects/dog_idle.png';
              } else {
                final f = (_ctrl.value * _frames).floor().clamp(0, _frames - 1);
                asset = 'assets/objects/dog_${_anim}_${f + 1}.png';
              }
              // cacheWidth 256 = MÊME clé que le précache du chien (ResizeImage
              // width:256) -> pas de double décodage, et 4× moins de RAM/frame
              // (source 512 px affichée petite).
              Widget img = Image.asset(asset,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  cacheWidth: kDogDecodeWidth);
              // Respiration douce au repos, pattes ancrées au sol.
              if (_anim == null) {
                img = Transform.scale(
                  scaleY: 1.0 + 0.018 * _idle.value,
                  alignment: Alignment.bottomCenter,
                  child: img,
                );
              }
              return img;
            },
          );
          // dog_walk pointe vers la DROITE par défaut -> miroir si va à gauche.
          if (_anim == 'walk' && !_faceRight) {
            sprite = Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..scaleByDouble(-1.0, 1.0, 1.0, 1.0),
              child: sprite,
            );
          }
          return Stack(children: [
            Positioned(
              left: _x * w - dogW / 2,
              top: widget.feetY * h - dogH * 0.75,
              width: dogW,
              height: dogH,
              child: widget.tint(sprite),
            ),
          ]);
        },
      ),
    );
  }
}

class _ParallaxLayer extends StatelessWidget {
  const _ParallaxLayer({
    super.key,
    required this.controller,
    required this.asset,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });

  final AnimationController controller;
  final String asset;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            // Scroll RIGHT — the locomotive sits on the left of the frame
            // so the train travels leftward, and the world appears to
            // slide rightward past it. One copy enters from the left edge,
            // the other exits at the right.
            final dx = controller.value * w;
            return ClipRect(
              child: Stack(
                children: [
                  Positioned(
                    left: dx - w,
                    top: 0,
                    bottom: 0,
                    width: w,
                    child: Image.asset(asset, fit: fit, alignment: alignment),
                  ),
                  Positioned(
                    left: dx,
                    top: 0,
                    bottom: 0,
                    width: w,
                    child: Image.asset(asset, fit: fit, alignment: alignment),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Soft dark smoke trail rising from the locomotive (off-frame at the
/// left) and drifting back across the top of the wagon. Each puff is a
/// cluster of 3 overlapping radial-gradient blobs (so the silhouette is
/// irregular, not a clean circle), drawn with a colour that lerps from
/// near-black at the source to dusty grey as the puff ages.
/// Voile de vapeur d'eau : volutes blanches floues qui montent et se
/// dissipent. Utilisé pour le bain et la douche (ambiance + léger voile).
class _SteamPainter extends CustomPainter {
  _SteamPainter(this.t, {this.intensity = 1.0});
  final double t; // 0..1 (boucle)
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final n = (11 * intensity).round().clamp(3, 34);
    final rnd = math.Random(7); // déterministe -> volutes stables
    for (int i = 0; i < n; i++) {
      final phase = rnd.nextDouble();
      final x0 = 0.08 + 0.84 * rnd.nextDouble();
      final drift = (rnd.nextDouble() - 0.5) * 0.32;
      final life = (t + phase) % 1.0; // 0 (bas) -> 1 (haut)
      final y = 1.0 - life;
      final x = x0 + drift * life;
      final r = size.width * (0.12 + 0.22 * life);
      // Opacité plafonnée pour rester laiteux sans masquer la scène.
      final op =
          (math.sin(life * math.pi) * 0.16 * intensity).clamp(0.0, 0.5).toDouble();
      if (op <= 0.01) continue;
      final paint = Paint()
        ..color = Color.fromRGBO(255, 255, 255, op)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      canvas.drawCircle(
          Offset(x * size.width, y * size.height), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SteamPainter old) =>
      old.t != t || old.intensity != intensity;
}

class _SmokePainter extends CustomPainter {
  _SmokePainter(this.t, {required this.running, this.intensity = 1.0});
  final double t;
  final bool running;

  /// Multiplier on puff size + alpha. 1.0 = baseline; the parent feeds
  /// in something like 1 + 0.1 * min(logs, 8) so the trail visibly
  /// thickens after a few logs.
  final double intensity;

  static const int _count = 12;
  static const int _subPuffs = 3;
  static final math.Random _rng = math.Random(11);
  static final List<double> _phase = List.generate(_count, (_) => _rng.nextDouble());
  static final List<double> _vertJitter = List.generate(_count, (_) => _rng.nextDouble() * 2 - 1);
  static final List<double> _sizeJitter = List.generate(_count, (_) => 0.75 + _rng.nextDouble() * 0.55);
  // Sub-puff angles + distances baked once per particle so the silhouette is stable per particle.
  static final List<double> _subAng = List.generate(_count * _subPuffs, (_) => _rng.nextDouble() * math.pi * 2);
  static final List<double> _subDist = List.generate(_count * _subPuffs, (_) => 0.3 + _rng.nextDouble() * 0.5);

  static const Color _young = Color(0xFF1B1410);
  static const Color _old = Color(0xFF6F665C);

  @override
  void paint(Canvas canvas, Size size) {
    // Smokestack at the top of the off-frame locomotive.
    final originX = -size.width * 0.015;
    final originY = size.height * 0.10;

    for (int i = 0; i < _count; i++) {
      final life = (t + _phase[i]) % 1.0;
      // Trail path: drifts up-right, slows in Y as the puff ages.
      final x = originX + life * size.width * 0.95;
      final y = originY - math.pow(life, 0.7).toDouble() * size.height * 0.10 +
          _vertJitter[i] * 10;
      // Fade in fast, fade out gradually.
      final alpha = life < 0.06
          ? life / 0.06
          : (life > 0.55 ? (1.0 - (life - 0.55) / 0.45) : 1.0);
      final clamped = alpha.clamp(0.0, 1.0);
      final baseRadius = (10 + life * 40) * _sizeJitter[i] * intensity;
      // Puff colour darker at source, lighter as it dissipates.
      final puffColor = Color.lerp(_young, _old, life)!;

      for (int s = 0; s < _subPuffs; s++) {
        final ang = _subAng[i * _subPuffs + s];
        final dist = _subDist[i * _subPuffs + s] * baseRadius;
        final cx = x + math.cos(ang) * dist;
        final cy = y + math.sin(ang) * dist * 0.6; // squash vertically — smoke spreads laterally
        final r = baseRadius * (0.85 + (s * 0.10));
        final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
        final shader = RadialGradient(
          colors: [
            puffColor.withValues(alpha: 0.55 * clamped),
            puffColor.withValues(alpha: 0.18 * clamped),
            puffColor.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(rect);
        final paint = Paint()..shader = shader;
        canvas.drawCircle(Offset(cx, cy), r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SmokePainter old) =>
      old.t != t || old.running != running || old.intensity != intensity;
}

/// Distant birds drifting across the sky band. Three flocks spaced along
/// the cycle so there is almost always one visible. Each flock is a small
/// V of three chevrons.
class _BirdsPainter extends CustomPainter {
  _BirdsPainter(this.t);
  final double t;

  static const int _flocks = 3;
  static final math.Random _rng = math.Random(23);
  static final List<double> _phase = List.generate(_flocks, (_) => _rng.nextDouble());
  static final List<double> _yFrac = List.generate(_flocks, (_) => 0.08 + _rng.nextDouble() * 0.18);
  static final List<double> _scale = List.generate(_flocks, (_) => 0.7 + _rng.nextDouble() * 0.6);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF20262C).withValues(alpha: 0.55);
    for (int i = 0; i < _flocks; i++) {
      final life = (t + _phase[i]) % 1.0;
      // Birds drift left → right faster than the sky.
      final x = -size.width * 0.10 + life * size.width * 1.20;
      final y = size.height * _yFrac[i];
      final s = 6.0 * _scale[i];
      for (int b = 0; b < 3; b++) {
        final bx = x + b * (s * 2.8) + math.sin(life * math.pi * 2 + b) * 1.5;
        final by = y + math.sin(life * math.pi * 4 + b * 0.7) * 1.0;
        final path = Path()
          ..moveTo(bx - s, by + s * 0.3)
          ..lineTo(bx, by)
          ..lineTo(bx + s, by + s * 0.3);
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BirdsPainter old) => old.t != t;
}

/// Thin horizontal motion-blur streaks along the top and bottom edges to
/// reinforce the sense of speed. Streaks fade in/out and shift on every
/// pass so they don't read as a repeating pattern.
class _SpeedLinesPainter extends CustomPainter {
  _SpeedLinesPainter(this.t, {this.intensity = 1.0});
  final double t;

  /// 1.0 baseline; >1 = more visible streaks (more bois in the firebox →
  /// faster-feeling train).
  final double intensity;

  static const int _count = 9;
  static final math.Random _rng = math.Random(91);
  static final List<double> _yFrac = List.generate(_count, (_) {
    // Streaks cluster at upper and lower edges only.
    final r = _rng.nextDouble();
    return r < 0.5 ? r * 0.18 : 0.82 + r * 0.16;
  });
  static final List<double> _phase = List.generate(_count, (_) => _rng.nextDouble());
  static final List<double> _len = List.generate(_count, (_) => 0.10 + _rng.nextDouble() * 0.18);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withValues(alpha: 0.18);
    for (int i = 0; i < _count; i++) {
      final life = (t + _phase[i]) % 1.0;
      // Streaks travel left → right across the frame (world rushes past
      // the leftward-moving train). Each streak is a trail with its tail
      // lagging behind.
      final startX = size.width * (life * 1.4 - 0.4);
      final endX = startX - size.width * _len[i];
      final y = size.height * _yFrac[i];
      final alpha = life < 0.15
          ? life / 0.15
          : (life > 0.70 ? (1.0 - (life - 0.70) / 0.30) : 1.0);
      paint.color = Colors.white.withValues(
        alpha: (0.18 * alpha.clamp(0.0, 1.0) * intensity).clamp(0.0, 0.6),
      );
      canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedLinesPainter old) =>
      old.t != t || old.intensity != intensity;
}

/// Affiche le bon frame du tank selon le niveau (0..waterTankFrames-1).
/// Niveau peut être fractionnaire (interpolation visuelle pendant l'anim
/// de remplissage / descente).
class _WaterTankSprite extends StatelessWidget {
  const _WaterTankSprite({required this.level, required this.fit});
  final double level;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    const maxFrame = GameState.waterTankFrames - 1;
    final idx = level.round().clamp(0, maxFrame);
    return Image.asset(
      'assets/objects/tank_$idx.png',
      fit: fit,
    );
  }
}

/// Écharpe peinte par-dessus Shen (tenue chaude, overlay simple sans sprites
/// dédiés) : bande autour du cou + pan qui pend et ondule doucement.
/// Dessinée dans la boîte du sprite ; tailles en fraction de hauteur (h).
class _ScarfPainter extends CustomPainter {
  _ScarfPainter({
    required this.facingRight,
    required this.neckCx,
    required this.sway,
  });
  final bool facingRight;
  final double neckCx; // centre du perso dans la boîte (fraction de largeur)
  final double sway; // 0..1 cycle d'ondulation

  static const _scarf = Color(0xFFA8453A); // rouge brique chaud
  static const _scarfLight = Color(0xFFC2685B);

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final cx = size.width * neckCx;
    final neckY = h * 0.225; // hauteur du cou (sous le menton)
    final bandW = h * 0.085;
    final bandH = h * 0.045;
    // Bande de cou (deux épaisseurs pour un peu de volume).
    final band = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(cx, neckY), width: bandW, height: bandH),
      Radius.circular(bandH * 0.5),
    );
    canvas.drawRRect(band, Paint()..color = _scarf);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, neckY - bandH * 0.22),
            width: bandW * 0.92,
            height: bandH * 0.5),
        Radius.circular(bandH * 0.3),
      ),
      Paint()..color = _scarfLight,
    );
    // Pan qui pend DERRIÈRE l'épaule (côté dos = opposé au regard), avec une
    // ondulation douce.
    final dir = facingRight ? -1.0 : 1.0;
    final wave = math.sin(sway * 2 * math.pi) * h * 0.012;
    final tailTopX = cx + dir * bandW * 0.32;
    final tail = Path()
      ..moveTo(tailTopX - bandW * 0.16, neckY)
      ..lineTo(tailTopX + bandW * 0.16, neckY)
      ..quadraticBezierTo(
        tailTopX + bandW * 0.22 + dir * h * 0.012,
        neckY + h * 0.07,
        tailTopX + bandW * 0.10 + dir * h * 0.022 + wave,
        neckY + h * 0.13,
      )
      ..lineTo(tailTopX - bandW * 0.20 + dir * h * 0.022 + wave,
          neckY + h * 0.125)
      ..quadraticBezierTo(
        tailTopX - bandW * 0.22 + dir * h * 0.010,
        neckY + h * 0.06,
        tailTopX - bandW * 0.16,
        neckY,
      )
      ..close();
    canvas.drawPath(tail, Paint()..color = _scarf);
    // Petite rayure crème au bout du pan.
    final stripeY = neckY + h * 0.112;
    canvas.drawLine(
      Offset(tailTopX - bandW * 0.18 + dir * h * 0.020 + wave, stripeY),
      Offset(tailTopX + bandW * 0.08 + dir * h * 0.020 + wave, stripeY),
      Paint()
        ..color = const Color(0xFFE8D9B8)
        ..strokeWidth = h * 0.008
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ScarfPainter old) =>
      old.sway != sway ||
      old.facingRight != facingRight ||
      old.neckCx != neckCx;
}

/// RADIO À MANIVELLE animée (16 frames : manivelle qui tourne + éclairs au
/// dessus de l'antenne). Objet du salon débloqué à G4. Tap direct -> débloque
/// la carte-souvenir « radio » (gain NARRATIF, pas de stat). Boucle en continu
/// pour montrer qu'« elle capte ».
class _RadioProp extends StatefulWidget {
  const _RadioProp({required this.night});
  final bool night;
  @override
  State<_RadioProp> createState() => _RadioPropState();
}

class _RadioPropState extends State<_RadioProp>
    with SingleTickerProviderStateMixin {
  static const int _frames = 16;
  late final AnimationController _c;
  bool _flash = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _tap() {
    // #9 — PARI ÉMOTIONNEL : ~40% du temps, la radio crache une bribe
    // désespérée (souvenir sombre, -espoir) au lieu d'une voix d'espoir.
    if (math.Random().nextDouble() < 0.4) {
      GameState.instance.unlockSouvenir('radio_sombre', hope: -5);
    } else {
      GameState.instance.unlockSouvenir('radio');
    }
    setState(() => _flash = true);
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _flash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _tap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final f = (_c.value * _frames).floor().clamp(0, _frames - 1) + 1;
          Widget img = Image.asset(
            'assets/objects/radio_$f.png',
            fit: BoxFit.contain,
            gaplessPlayback: true,
          );
          if (widget.night) {
            img = ColorFiltered(
              colorFilter: const ColorFilter.mode(
                  Color(0xFF6A7CA0), BlendMode.modulate),
              child: img,
            );
          }
          if (_flash) {
            img = Stack(
              alignment: Alignment.center,
              children: [
                img,
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFFE8C56A).withValues(alpha: 0.5),
                          blurRadius: 24,
                          spreadRadius: 6),
                    ],
                  ),
                ),
              ],
            );
          }
          return img;
        },
      ),
    );
  }
}

/// Entrée du panneau d'ajuster unifié : un objet réglable (position, taille,
/// miroir, inclinaison, bascule 3D) piloté par des closures vers son stockage
/// (salonProps / wagon1Props / champs cellier + wagon2FlipRot).
class _AdjItem {
  const _AdjItem(this.key, this.info, this.move, this.size, this.flip,
      this.rotate, this.turn, this.tilt);
  final String key;
  final String Function() info;
  final void Function(double dx, double dy) move;
  final void Function(double dh) size;
  final void Function(int bit) flip;
  final void Function(double deg) rotate;
  final void Function(double d) turn;
  final void Function(double d) tilt;
}
