import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../data/anim_metrics.dart';
import '../models/game_state.dart';
import '../services/audio_service.dart';
import 'atmosphere.dart';
import 'train_rocking.dart';

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
    this.cookToken = 0,
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
  });

  /// Wagon visual progression, 0..3:
  ///   0 — dirty (initial discovery: trash, broken windows, scratches)
  ///   1 — swept (floor cleaned; walls + windows still wrecked)
  ///   2 — windowed (floor cleaned + windows put back; walls still rusty)
  ///   3 — clean (fully restored)
  final int wagonStage;

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
  final int cookToken;

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
  /// 'cook', 'pet_dog', 'garden_tend'). Null = pas d'anim active.
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
  /// gauche du wagon vers la locomotive).
  static const double heroXMin = 0.22;

  /// Right bound for the heroine in normalised X. Exposed so the parent
  /// can compare against it to know when she's at the right door
  /// (= ouverture sur la map du monde).
  static const double heroXMax = 0.86;

  /// Centres X normalisés des props interactifs. Le parent compare
  /// _heroX à ces valeurs pour décider quoi afficher sur l'action FAB.
  static const double bedCenterX = 0.334;
  static const double notebookCenterX = 0.249;
  static const double lampCenterX = 0.415;
  static const double stoveCenterX = 0.629;
  static const double filterCenterX = 0.727;
  static const double hydroCenterX = 0.805;
  static const double bowlCenterX = 0.481;

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
  static const int _heroFrameCount = 49;
  static const double _heroXMin = SideScrollScene.heroXMin;
  static const double _heroXMax = SideScrollScene.heroXMax;
  static const double _heroSpeed = 0.18; // normalised units / second
  static const int _walkFrameMs = 50;
  static const int _idleFrameMs = 80;
  static const int _sleepFrameMs = 110;
  static const int _danceFrameMs = 55;
  static const int _lieDownFrameMs = 60;

  // Bed object placement (normalised to scene size, mutable so the
  // adjustment mode can drag + resize it live). Defaults dialled in
  // via the adjust mode and baked back here.
  double _bedLeft = 0.194;
  double _bedTop = 0.448;
  double _bedWidth = 0.280;

  // When the heroine arrived at the bed via a double-tap on it, render
  // the sleep sprite ON the mattress (instead of on the floor). Offsets
  // are normalised to the scene size, position is relative to the
  // bed's centre/top so it stays glued to the bed as it moves.
  bool _sleepOnBed = false;
  double _sleepBedOffsetX = 0.0;   // centré sur le centre du lit
  double _sleepBedOffsetY = 0.115; // calé sur le matelas
  double _sleepBedScale = 0.36;    // longueur corps en fraction de h

  // Props installés dans le wagon — chaque entry contient sa position
  // (left/top centrés, normalisés) + sa hauteur en fraction de h.
  static final List<_PropDef> _propDefs = [
    _PropDef('hydro',    'Hydro',     animated: true,  frameCount: 49),
    _PropDef('lamp',     'Lampe',     animated: true,  frameCount: 49),
    _PropDef('stove',    'Poele',     animated: true,  frameCount: 49),
    _PropDef('filter',   'Filtre',    animated: false),
    _PropDef('table',    'Table',     animated: false),
    _PropDef('notebook', 'Carnet',    animated: false),
    _PropDef('firstaid', 'Secours',   animated: false),
    _PropDef('commode',  'Commode',   animated: false),
    _PropDef('bowl',     'Gamelle',   animated: false),
  ];

  final Map<String, _PropPos> _propPos = {
    'hydro':    _PropPos(0.805, 0.412, 0.326),
    'lamp':     _PropPos(0.415, 0.323, 0.104),
    'stove':    _PropPos(0.629, 0.445, 0.263),
    'filter':   _PropPos(0.727, 0.514, 0.200),
    'table':    _PropPos(0.479, 0.557, 0.151),
    'notebook': _PropPos(0.249, 0.670, 0.070),
    'firstaid': _PropPos(0.296, 0.635, 0.110),
    'commode':  _PropPos(0.539, 0.571, 0.139),
    'bowl':     _PropPos(0.481, 0.669, 0.080),
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
  static const double _dogTop = 0.673;
  static const double _dogXMin = 0.35;
  static const double _dogXMax = 0.70;

  // Horizon (middle background) clipping bounds — both are fractions
  // of the scene height. `_horizonTop` is the distance from the very
  // top of the frame, `_horizonBottom` is the distance from the very
  // bottom. Defaults dialled in via the horizon adjust mode.
  double _horizonTop = 0.0;
  double _horizonBottom = 0.179;

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

  String get _skyAsset {
    if (GameState.instance.inColdZone) {
      return widget.night
          ? 'assets/background/sky_snow_night.png'
          : 'assets/background/sky_snow.png';
    }
    return widget.night
        ? 'assets/background/sky_night.png'
        : 'assets/background/sky.png';
  }

  String get _foregroundAsset {
    if (GameState.instance.inColdZone) {
      return 'assets/background/foreground_snow.png';
    }
    return 'assets/background/foreground_band.png';
  }

  String get _horizonNightAsset {
    if (GameState.instance.inColdZone) {
      return 'assets/background/horizon_snow_night.png';
    }
    return 'assets/background/horizon_night.png';
  }

  static const Duration _horizonRotatePeriod = Duration(seconds: 45);
  static const Duration _horizonCrossFade = Duration(seconds: 2);
  int _horizonIndex = 0;
  Timer? _horizonRotateTimer;
  TrainZone? _lastZone;

  late final Ticker _heroTicker;
  late double _heroX = widget.initialHeroX;
  double? _heroTarget;
  // She has only two facing options: the walk_right sheet, or its
  // horizontal mirror for going left.
  bool _heroFacingRight = true;
  bool _heroSleeping = false;
  bool _heroDancing = false;
  // When set, the next walk-arrival auto-triggers a lie-down (used by
  // the double-tap-on-bed handler so she walks over before lying down).
  bool _walkingToBed = false;
  bool _walkingToStove = false;
  // Lie-down transition: plays pickup frames in reverse (upright → bent
  // over), then snaps into the sleep loop on the floor.
  bool _heroLyingDown = false;
  int _lieDownFrame = _heroFrameCount - 1; // counts down toward 0
  int _walkFrame = 0;
  // Step counter — bumped each time a foot plants; consumed by the
  // FootstepDust widget to render a puff burst.
  int _stepToken = 0;
  // Occasional thought-bubble emoji shown above the heroine. Picked at
  // random every ~60 s while idle, cleared after a couple of seconds.
  String? _thoughtEmoji;
  Timer? _thoughtTimer;
  Timer? _thoughtClearTimer;
  int _idleFrame = 0;
  // Random idle break: after ~15 s standing still the heroine plays a
  // yawn or look-window sheet once, then returns to idle. Breaks the
  // monotony without needing any input.
  int _idleStillMs = 0;
  String? _idleBreak; // 'yawn' / 'look_window' while playing
  int _idleBreakFrame = 0;
  int _idleBreakAccumMs = 0;
  static const int _idleBreakFrameMs = 65;
  static const int _idleBreakAfterMs = 15000;

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
    _thoughtTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!mounted) return;
      // 50 % chance to skip — so they don't appear like clockwork.
      if (math.Random().nextDouble() < 0.5) return;
      setState(() => _thoughtEmoji = GameState.instance.contextualThought);
      _thoughtClearTimer?.cancel();
      _thoughtClearTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _thoughtEmoji = null);
      });
    });
  }

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
    // 0 verres → frame 0, 5 verres → frame 11 (12 frames - 1)
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

  bool _precached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    // Decode and cache every animation frame plus the background variants
    // before the user can interact. Without this, the first cycle of any
    // animation stutters while Flutter lazily decodes the PNGs.
    const animations = [
      'walk_right',
      'idle_right',
      'sleep_right',
      'dance',
      'pickup',
      'yawn',
      'stretch',
      'look_window',
      'read',
      'wake_up',
      'warm_hands',
      'carry_walk',
      'cook',
      'drink',
      'pet_dog',
      'garden_tend',
    ];
    for (final anim in animations) {
      for (int i = 1; i <= _heroFrameCount; i++) {
        precacheImage(AssetImage('assets/characters/${anim}_$i.png'), context);
      }
    }
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
    // Filtre/tank: 12 frames pour niveau d'eau.
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
        precacheImage(
          AssetImage('assets/objects/${prefix}_$i.png'),
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
      'assets/background/wagon_dirty.png',
      'assets/background/wagon_swept.png',
      'assets/background/wagon_windowed.png',
      'assets/background/wagon_clean.png',
      'assets/background/wagon_rails.png',
      'assets/objects/bed.png',
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
    if (oldWidget.cookToken != widget.cookToken) {
      final target = SideScrollScene.stoveCenterX.clamp(_heroXMin, _heroXMax);
      setState(() {
        _heroDancing = false;
        _heroSleeping = false;
        _heroLyingDown = false;
        _walkingToStove = true;
        _heroTarget = target;
      });
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
    _horizonRotateTimer?.cancel();
    _thoughtTimer?.cancel();
    _thoughtClearTimer?.cancel();
    _sky.dispose();
    _horizon.dispose();
    _mid.dispose();
    _foreground.dispose();
    _smoke.dispose();
    super.dispose();
  }

  void _onHeroTick(Duration elapsed) {
    final dtMicros = (elapsed - _lastTick).inMicroseconds;
    _lastTick = elapsed;
    if (dtMicros <= 0) return;
    final dt = dtMicros / 1e6;
    final dtMs = (dt * 1000).round();

    if (_doorPushing) {
      setState(() {
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
      setState(() {
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
              return;
            }
          }
        }
      });
      return;
    }

    if (_waking) {
      setState(() {
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
      setState(() {
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
      setState(() {
        _sleepAccumMs += dtMs;
        while (_sleepAccumMs >= _sleepFrameMs) {
          _sleepAccumMs -= _sleepFrameMs;
          _sleepFrame = (_sleepFrame + 1) % _heroFrameCount;
        }
      });
      return;
    }

    if (_heroDancing) {
      setState(() {
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
      // Idle break currently playing — advance its frames, snap back
      // to idle when done.
      if (_idleBreak != null) {
        setState(() {
          _idleBreakAccumMs += dtMs;
          while (_idleBreakAccumMs >= _idleBreakFrameMs) {
            _idleBreakAccumMs -= _idleBreakFrameMs;
            _idleBreakFrame++;
            if (_idleBreakFrame >= _heroFrameCount) {
              _idleBreak = null;
              _idleBreakFrame = 0;
              _idleStillMs = 0;
              return;
            }
          }
        });
        return;
      }
      setState(() {
        _idleAccumMs += dtMs;
        while (_idleAccumMs >= _idleFrameMs) {
          _idleAccumMs -= _idleFrameMs;
          _idleFrame = (_idleFrame + 1) % _heroFrameCount;
        }
        _idleStillMs += dtMs;
        // Pick an idle break when she's been still long enough. Look
        // at the window if she's near one, otherwise yawn (with a
        // probability so it doesn't fire like clockwork).
        if (_idleStillMs >= _idleBreakAfterMs) {
          _idleStillMs = 0;
          if (math.Random().nextDouble() < 0.6) {
            _idleBreak = 'yawn';
          }
          _idleBreakFrame = 0;
          _idleBreakAccumMs = 0;
        }
      });
      return;
    }
    // Walking — reset the still timer so we don't yawn mid-step.
    _idleStillMs = 0;

    final delta = target - _heroX;
    final step = _heroSpeed * dt;
    if (delta.abs() <= step) {
      final arriveTriggersLieDown = _walkingToBed;
      final arriveTriggerssCook = _walkingToStove;
      setState(() {
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
        if (arriveTriggerssCook) {
          _walkingToStove = false;
          _activeSpecial = 'use_back';
          _activeSpecialFrames = 49;
          _activeSpecialLoops = false;
          _specialFrame = 0;
          _specialAccumMs = 0;
          GameState.instance.restoreHunger(0.20);
          // Cuisiner/manger au réchaud remplit la jauge Faim de la run.
          GameState.instance.nudgeCardStat('faim', 15);
        }
      });
      widget.onHeroXChanged?.call(_heroX);
      return;
    }

    final dir = delta > 0 ? 1.0 : -1.0;
    setState(() {
      _heroX += step * dir;
      _heroFacingRight = dir > 0;
      _walkAccumMs += dtMs;
      while (_walkAccumMs >= _walkFrameMs) {
        _walkAccumMs -= _walkFrameMs;
        _walkFrame = (_walkFrame + 1) % _heroFrameCount;
        // Roughly every 6 walk frames a foot is planted — kick a dust
        // puff at the heroine's feet + footstep sound.
        if (_walkFrame % 6 == 0) {
          _stepToken++;
          AudioService().playSfx('footstep', volume: 0.4);
        }
      }
    });
    widget.onHeroXChanged?.call(_heroX);
  }

  void _walkTo(double normalizedX) {
    final clamped = normalizedX.clamp(_heroXMin, _heroXMax);
    final wasSleeping = _heroSleeping;
    setState(() {
      _heroSleeping = false;
      _heroDancing = false;
      _heroLyingDown = false;
      _walkingToBed = false;
      _walkingToStove = false;
      _idleBreak = null;
      _idleBreakFrame = 0;
      _idleBreakAccumMs = 0;
      _idleStillMs = 0;
      _heroTarget = clamped;
      if (wasSleeping) {
        if (_sleepOnBed) {
          // Réveil depuis le LIT : skip toute la séquence wake_up +
          // stretch (causait le bug "se penche puis remonte" + saut
          // de position). On snap directement à idle au centre du lit.
          _sleepOnBed = false;
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
                      // 1a-ter. Horizon figures — silhouettes scrolling
                      //     across the horizon line. Drawn BEFORE the
                      //     wagon image so they're masked by it and only
                      //     visible through the wagon windows.
                      Positioned(
                        left: 0,
                        right: 0,
                        top: h * 0.55,
                        height: h * 0.18,
                        child: const HorizonFigures(density: 5),
                      ),
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
                      // 1b. Drifting cloud overlay — sky.png at a low
                      //     opacity, scrolling on its own faster
                      //     controller. Gives the sky a second layer of
                      //     motion (cloud parallax) over the horizon's
                      //     own painted sky.
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        height: h * 0.30,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: widget.night ? 0.18 : 0.30,
                            child: _ParallaxLayer(
                              controller: _sky,
                              asset: _skyAsset,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
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
                      Positioned(
                        left: 0,
                        right: 0,
                        top: h * 0.88,
                        bottom: 0,
                        child: ScurryingAnimal(
                          animation: _foreground,
                          running: widget.running,
                        ),
                      ),
                      // 3b-ter. Foreground life (tumbleweed, paper, dust,
                      //     fox, snake, lizard, bottles, footprints, bones,
                      //     wildflowers) — cycled.
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
                      // 3c. Fond bois derrière le wagon pour masquer
                      //     les trous dans le plancher (dirty/swept).
                      if (widget.wagonStage <= 1)
                        Positioned(
                          left: w * 0.12,
                          right: w * 0.08,
                          top: h * 0.65,
                          bottom: h * 0.14,
                          child: _nightTint(
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFF3D2B1A),
                                    Color(0xFF2E1F12),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      // 4. Wagon — fixed in the centre, picked from the
                      //    progression stage (dirty → swept → windowed →
                      //    clean). Night ColorFilter tints all four the
                      //    same way.
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
                      Positioned(
                        left: w * _bedLeft,
                        top: h * _bedTop,
                        width: w * _bedWidth,
                        child: _nightTint(
                          Image.asset(
                            'assets/objects/bed.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
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
                      // 4g. Props installés dans le wagon (tour hydro,
                      //     lampe, poêle, filtre eau, chien, table,
                      //     carnet, trousse). Rendus avant la fille pour
                      //     qu'elle puisse passer devant.
                      for (final def in _propDefs)
                        _buildProp(def: def, w: w, h: h),
                      // 4g-bis. Chien statique (dog_idle) ou animé
                      //     pendant les interactions (crouch → wag_tail).
                      if (_activeSpecial != 'pet_dog')
                        _buildStaticDog(w, h),
                      // 4c. Lamp glow when lamp is on.
                      if (GameState.instance.lampOn)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: widget.night ? 0.9 : 0.35,
                              child: FireGlow(
                                animation: _sky,
                                x: 0.415,
                                y: 0.35,
                                radius: 0.25,
                              ),
                            ),
                          ),
                        ),
                      // 5. Heroine — walks on the wagon floor.
                      _buildHeroine(w, h),
                      // 5b. Warm halo around the heroine when she's at
                      //     either edge of the wagon (door areas — lamp
                      //     glow / firebox spill from off-frame).
                      Positioned.fill(
                        child: CharacterHalo(
                          heroX: _heroX,
                          heroY: 0.72,
                          intensity: _heroEdgeProximity() * (widget.night ? 1.0 : 0.6),
                        ),
                      ),
                      // 5c. Footstep dust puff at her feet each plant.
                      Positioned.fill(
                        child: FootstepDust(
                          heroX: _heroX,
                          feetY: 0.92,
                          stepToken: _stepToken,
                          enabled: widget.wagonStage <= 1,
                        ),
                      ),
                      // 5e. Random thought bubble above her head.
                      if (_thoughtEmoji != null)
                        Positioned.fill(
                          child: ThoughtBubble(
                            heroX: _heroX,
                            heroTopY: 0.30,
                            emoji: _thoughtEmoji!,
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
              ],
            );
          },
        ),
      ),
    );
  }

  /// True if the heroine is standing close to one of the wagon's
  /// three back-wall windows — triggers the look_window idle break.
  bool _nearWindow() {
    const windowsX = [0.40, 0.55, 0.70];
    for (final wx in windowsX) {
      if ((_heroX - wx).abs() < 0.04) return true;
    }
    return false;
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
  Widget _buildProp({
    required _PropDef def,
    required double w,
    required double h,
  }) {

    final pos = _propPos[def.key]!;
    final propH = h * pos.height;
    final propW = w * pos.width;
    final left = w * pos.left - propW / 2;
    final top = h * pos.top;
    // La gamelle a 2 états (full / empty) → asset différent selon
    // [_bowlFull]. Le reste suit le mapping standard (animé ou statique).
    final String staticAsset = def.key == 'bowl'
        ? (_bowlFull ? 'assets/objects/bowl_full.png'
                     : 'assets/objects/bowl_empty.png')
        : 'assets/objects/${def.key}.png';
    const boxFit = BoxFit.contain;
    final Widget sprite;
    if (def.key == 'filter') {
      sprite = _WaterTankSprite(level: _filterDisplayLevel, fit: boxFit);
    } else if (def.animated) {
      sprite = _AnimatedSprite(
        prefix: def.key,
        frameCount: def.frameCount,
        durationMs: def.frameDurationMs * def.frameCount,
        fit: boxFit,
      );
    } else {
      sprite = Image.asset(
        staticAsset,
        fit: boxFit,
      );
    }
    Widget wrapped = _nightTint(sprite);
    if (def.key == 'stove' && (pos.animDx != 0 || pos.animDy != 0)) {
      wrapped = Transform.translate(
        offset: Offset(w * pos.animDx, h * pos.animDy),
        child: wrapped,
      );
    }
    // Lampe à pétrole : dim quand éteinte (GameState.lampOn = false).
    if (def.key == 'lamp') {
      wrapped = AnimatedBuilder(
        animation: GameState.instance,
        builder: (_, child) => Opacity(
          opacity: GameState.instance.lampOn ? 1.0 : 0.18,
          child: child,
        ),
        child: wrapped,
      );
    }

    // commode = tappable (ouvre wardrobe), bowl = tap
    // pour remplir si vide, reste = inert.
    if (def.key == 'commode' && widget.onOpenWardrobe != null) {
      return Positioned(
        left: left,
        top: top,
        width: propW,
        height: propH,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onOpenWardrobe,
          child: wrapped,
        ),
      );
    }
    if (def.key == 'bowl') {
      return Positioned(
        left: left,
        top: top,
        width: propW,
        height: propH,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Tap = toggle full ↔ empty. Pour l'instant pas de coût/inventaire ;
          // c'est juste pour tester la mécanique. Plus tard on conditionnera
          // la recharge à une ressource "ration" dans le GameState.
          onTap: () => setState(() => _bowlFull = !_bowlFull),
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


  int _dogAnimFrame = 0;

  Widget _buildStaticDog(double w, double h) {
    final dogH = h * widget.dogHeight;
    final dogW = dogH;
    final dogX = 0.525 * w;
    final feetY = h * 0.74;

    if (_activeSpecial == 'crouch') {
      _dogAnimFrame = (_dogAnimFrame + 1) % 25;
      final frame = _dogAnimFrame + 1;
      final asset = 'assets/objects/dog_wag_tail_$frame.png';
      return Positioned(
        left: dogX - dogW * 0.3,
        top: feetY - dogH * 0.8,
        width: dogW,
        height: dogH,
        child: _nightTint(Image.asset(asset, fit: BoxFit.contain)),
      );
    }

    return Positioned(
      left: dogX - dogW / 2,
      top: feetY - dogH * 0.75,
      width: dogW,
      height: dogH,
      child: _nightTint(
        Image.asset('assets/objects/dog_idle.png', fit: BoxFit.contain),
      ),
    );
  }

  Widget _buildHeroine(double w, double h) {
    // Wagon's interior floor sits roughly at this Y.
    final feetY = h * 0.74;
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
              transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
              child: Image.asset(asset, fit: BoxFit.contain),
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
          child: _nightTint(Image.asset(asset, fit: BoxFit.contain)),
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
    } else if (_idleBreak != null) {
      prefix = _idleBreak!;
      frame = _idleBreakFrame;
    } else if (_heroTarget != null) {
      prefix = 'walk_right';
      frame = _walkFrame;
    } else {
      prefix = 'idle_right';
      frame = _idleFrame;
    }

    final m = animMetricsFor(prefix);
    final bool deepInWagon = prefix == 'cook';
    final depthScale = deepInWagon ? 0.78 : 1.0;
    final heroHeight = h * kHeroBaseHeight * m.scale * depthScale;
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

    final adjustedFeetY = deepInWagon ? feetY - h * 0.06 : feetY;
    Widget sprite = Image.asset(asset, fit: BoxFit.contain);
    if (shouldMirror) {
      sprite = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
        child: sprite,
      );
    }
    sprite = _nightTint(sprite);

    return Positioned(
      left: anchorX - heroWidth / 2,
      top: adjustedFeetY - heroHeight * m.feet,
      width: heroWidth,
      height: heroHeight,
      child: IgnorePointer(child: sprite),
    );
  }

  String _wagonAssetFor(int stage) {
    const assets = [
      'assets/background/wagon_dirty.png',
      'assets/background/wagon_swept.png',
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
    this.frameCount = 1,
    this.frameDurationMs = 70,
  });

  final String key;
  final String label;
  final bool animated;
  final int frameCount;
  final int frameDurationMs;
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
  double animDx = 0;
  double animDy = 0;
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
  });

  final String prefix;
  final int frameCount;
  final int durationMs;
  final BoxFit fit;

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
        // ResizeImage : décode à 256px max (au lieu de la taille native
        // 512px). Divise par 4 la mémoire de chaque frame en cache et
        // donc la fréquence des purges qui re-décodent à chaud (cause
        // des saccades au démarrage d'anim).
        return Image(
          image: ResizeImage(
            AssetImage(
              'assets/objects/${widget.prefix}_${frame + 1}.png',
            ),
            width: 256,
          ),
          fit: widget.fit,
        );
      },
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

/// Chien autonome. Tourne entre 3 états (idle, walk, sleep) en piochant
/// aléatoirement chaque transition. Pendant `walk`, sa position X glisse
/// dans [xMin, xMax] ; le sprite est miroré selon la direction.
class _DogActor extends StatefulWidget {
  const _DogActor({
    required this.w,
    required this.h,
    required this.height,
    required this.topFrac,
    required this.xMin,
    required this.xMax,
    required this.tint,
    this.bowlX,
    this.isBowlFull,
    this.onAteFromBowl,
  });
  final double w;
  final double h;
  final double height; // fraction de h
  final double topFrac;
  final double xMin;
  final double xMax;
  final Widget Function(Widget) tint;
  /// Position X normalisée de la gamelle (centre). Si null, pas de gamelle.
  final double? bowlX;
  /// Lambda qui renvoie l'état actuel de la gamelle (true = pleine).
  final bool Function()? isBowlFull;
  /// Callback appelé quand Plume vient de finir un cycle d'eat près
  /// d'une gamelle pleine → la passe à vide.
  final VoidCallback? onAteFromBowl;
  @override
  State<_DogActor> createState() => _DogActorState();
}

enum _DogState {
  idle,        // assis tranquille (image statique : dog_idle.png)
  walk,        // se déplace, X glisse, direction selon target
  layDown,     // transition idle → sleep (joue 1x, non-loop)
  sleep,       // dort en boule (loop)
  stretchYawn, // transition sleep → idle (joue 1x, non-loop)
  wagTail,     // assis, queue qui s'agite (loop court)
  bark,        // aboie (loop court)
  headTilt,    // incline la tête, curieux (loop court)
  eat,         // mange dans la gamelle (loop court, conditionnel)
}

class _DogActorState extends State<_DogActor>
    with SingleTickerProviderStateMixin {
  // Frame count + cadence par état. idle = 1 (image statique).
  static const Map<_DogState, _AnimDef> _anims = {
    _DogState.idle:        _AnimDef(prefix: 'dog_idle',         frames: 1,  frameMs: 0,   loops: true),
    _DogState.walk:        _AnimDef(prefix: 'dog_walk',         frames: 49, frameMs: 50,  loops: true),
    _DogState.layDown:     _AnimDef(prefix: 'dog_lay_down',     frames: 25, frameMs: 70,  loops: false),
    _DogState.sleep:       _AnimDef(prefix: 'dog_sleep',        frames: 25, frameMs: 110, loops: true),
    _DogState.stretchYawn: _AnimDef(prefix: 'dog_stretch_yawn', frames: 25, frameMs: 70,  loops: false),
    _DogState.wagTail:     _AnimDef(prefix: 'dog_wag_tail',     frames: 25, frameMs: 60,  loops: true),
    _DogState.bark:        _AnimDef(prefix: 'dog_bark',         frames: 25, frameMs: 60,  loops: true),
    _DogState.headTilt:    _AnimDef(prefix: 'dog_head_tilt',    frames: 25, frameMs: 70,  loops: true),
    _DogState.eat:         _AnimDef(prefix: 'dog_eat',          frames: 25, frameMs: 70,  loops: true),
  };

  static const double _walkSpeed = 0.06; // unités normalisées / sec

  final math.Random _rng = math.Random();
  late final Ticker _ticker;
  Duration? _lastTick;

  _DogState _state = _DogState.idle;
  int _frame = 0;
  int _accumMs = 0;
  double _x = 0.45;
  double _dir = 1.0; // +1 = droite, -1 = gauche (sprite source face droite)
  double _walkTargetX = 0.45;
  int _stateRemainMs = 0;
  // Quand true, la marche en cours vise la gamelle ; à la fin du walk
  // on enchaîne sur `eat` au lieu de retomber en idle.
  bool _walkingToBowl = false;

  @override
  void initState() {
    super.initState();
    _enterState(_DogState.idle, initial: true);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// Configure les paramètres d'un nouvel état (durée, direction, etc.).
  /// [walkTarget] permet de forcer la cible quand on l'envoie manger à
  /// la gamelle (sinon la cible est random).
  void _enterState(_DogState next,
      {bool initial = false, double? walkTarget}) {
    _state = next;
    _frame = 0;
    _accumMs = 0;
    switch (next) {
      case _DogState.idle:
        _stateRemainMs = 2500 + _rng.nextInt(3500); // 2.5-6s
        break;
      case _DogState.walk:
        if (walkTarget != null) {
          _walkTargetX = walkTarget.clamp(widget.xMin, widget.xMax);
        } else {
          double target;
          do {
            target = widget.xMin +
                _rng.nextDouble() * (widget.xMax - widget.xMin);
          } while ((target - _x).abs() < 0.10);
          _walkTargetX = target;
        }
        _dir = _walkTargetX > _x ? 1.0 : -1.0;
        _stateRemainMs = 8000;
        break;
      case _DogState.layDown:
      case _DogState.stretchYawn:
        // Anim non-loop : durée = framesCount × frameMs (joue 1×).
        final a = _anims[next]!;
        _stateRemainMs = a.frames * a.frameMs;
        break;
      case _DogState.sleep:
        _stateRemainMs = 8000 + _rng.nextInt(10000); // 8-18s
        break;
      case _DogState.wagTail:
      case _DogState.bark:
      case _DogState.headTilt:
        _stateRemainMs = 1500 + _rng.nextInt(2000); // 1.5-3.5s
        break;
      case _DogState.eat:
        _stateRemainMs = 3000 + _rng.nextInt(3000); // 3-6s
        break;
    }
    if (initial) return;
  }

  /// Pick la prochaine action depuis l'état actuel. Les transitions
  /// suivent une logique naturelle : sleep s'enchaîne avec stretchYawn,
  /// layDown enchaîne sur sleep, et depuis idle on peut partir sur
  /// n'importe quelle action courte.
  void _pickNextState() {
    _DogState next;
    double? walkTarget;
    switch (_state) {
      case _DogState.layDown:
        next = _DogState.sleep;
        break;
      case _DogState.sleep:
        next = _DogState.stretchYawn;
        break;
      case _DogState.stretchYawn:
        next = _DogState.idle;
        break;
      case _DogState.walk:
        // Si on allait vers la gamelle → manger sur place.
        if (_walkingToBowl) {
          _walkingToBowl = false;
          next = _DogState.eat;
        } else {
          next = _rng.nextDouble() < 0.7
              ? _DogState.idle
              : _DogState.headTilt;
        }
        break;
      case _DogState.eat:
        // Fini de manger → vide la gamelle puis idle.
        widget.onAteFromBowl?.call();
        next = _DogState.idle;
        break;
      case _DogState.bark:
      case _DogState.wagTail:
      case _DogState.headTilt:
        next = _DogState.idle;
        break;
      case _DogState.idle:
        // Si la gamelle est pleine, ~30% de chance de partir manger.
        final bowlX = widget.bowlX;
        final bowlFull = widget.isBowlFull?.call() ?? false;
        if (bowlX != null && bowlFull && _rng.nextDouble() < 0.30) {
          _walkingToBowl = true;
          walkTarget = bowlX;
          next = _DogState.walk;
          break;
        }
        // Sinon : pondération standard entre actions possibles.
        final r = _rng.nextDouble();
        if (r < 0.30) {
          next = _DogState.walk;
        } else if (r < 0.45) {
          next = _DogState.wagTail;
        } else if (r < 0.58) {
          next = _DogState.headTilt;
        } else if (r < 0.65) {
          next = _DogState.bark;
        } else if (r < 0.80) {
          next = _DogState.layDown;
        } else {
          next = _DogState.idle;
        }
        break;
    }
    _enterState(next, walkTarget: walkTarget);
  }

  void _onTick(Duration elapsed) {
    final last = _lastTick ?? elapsed;
    final dtMs = (elapsed - last).inMilliseconds;
    _lastTick = elapsed;
    if (dtMs <= 0) return;

    final a = _anims[_state]!;
    _accumMs += dtMs;
    if (a.frameMs > 0) {
      while (_accumMs >= a.frameMs) {
        _accumMs -= a.frameMs;
        if (a.loops) {
          _frame = (_frame + 1) % a.frames;
        } else if (_frame < a.frames - 1) {
          _frame++;
        }
      }
    }

    _stateRemainMs -= dtMs;

    if (_state == _DogState.walk) {
      final step = _walkSpeed * (dtMs / 1000.0) * _dir;
      _x = (_x + step).clamp(widget.xMin, widget.xMax);
      if ((_x - _walkTargetX).abs() < 0.005 || _stateRemainMs <= 0) {
        _pickNextState();
      }
    } else if (_stateRemainMs <= 0) {
      _pickNextState();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final propH = widget.h * widget.height;
    final propW = propH;
    final left = widget.w * _x - propW / 2;
    final top = widget.h * widget.topFrac;
    final a = _anims[_state]!;
    final asset = a.frames == 1
        ? 'assets/objects/${a.prefix}.png'
        : 'assets/objects/${a.prefix}_${_frame + 1}.png';
    Widget sprite = Image.asset(asset, fit: BoxFit.contain);
    if (_dir < 0) {
      sprite = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
        child: sprite,
      );
    }
    return Positioned(
      left: left,
      top: top,
      width: propW,
      height: propH,
      child: IgnorePointer(child: widget.tint(sprite)),
    );
  }
}

class _AnimDef {
  const _AnimDef({
    required this.prefix,
    required this.frames,
    required this.frameMs,
    required this.loops,
  });
  final String prefix;
  final int frames;
  final int frameMs;
  final bool loops;
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
    final maxFrame = GameState.waterTankFrames - 1;
    final idx = level.round().clamp(0, maxFrame);
    return Image.asset(
      'assets/objects/tank_$idx.png',
      fit: fit,
    );
  }
}
