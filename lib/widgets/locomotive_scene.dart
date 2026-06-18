import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../data/anim_metrics.dart';
import '../models/game_state.dart';
import '../services/audio_service.dart';
import 'atmosphere.dart';
import 'map_screen.dart';
import 'side_scroll_scene.dart' show kHeroDecodeWidth;
import 'stat_rings.dart';
import 'train_rocking.dart';

enum _LocoAction {
  idle,
  walkToWoodpile,
  pickingUp,
  carryingToFire,
  throwing,
}

/// Locomotive cab scene — heroine has walked through the door at the
/// front of the wagon and is now in the driver's compartment.
///
/// Same visual language as the wagon scene: drifting sky + horizon
/// parallax behind, the train-rocking sway on top of everything, the
/// locomotive cab as a foreground overlay (its black background was
/// keyed out so the upper window shows the scrolling landscape),
/// and the heroine walking on the cab floor between the firebox
/// (left) and the woodpile (right).
class LocomotiveScene extends StatefulWidget {
  const LocomotiveScene({
    super.key,
    required this.onReturn,
    required this.logsThrown,
    required this.onThrowLog,
    this.onOpenMap,
    this.night = false,
  });

  final VoidCallback onReturn;
  final bool night;
  final int logsThrown;
  final VoidCallback onThrowLog;

  /// Ouvre la carte du voyage (depuis la carte accrochée dans la cabine).
  final VoidCallback? onOpenMap;

  @override
  State<LocomotiveScene> createState() => _LocomotiveSceneState();
}

class _LocomotiveSceneState extends State<LocomotiveScene>
    with TickerProviderStateMixin {
  late final AnimationController _sky;
  late final AnimationController _horizon;

  static const int _heroFrameCount = 25;
  static const double _heroXMin = 0.30;
  static const double _heroXMax = 0.72;
  static const double _heroSpeed = 0.18;
  static const int _walkFrameMs = 50;
  static const int _idleFrameMs = 80;

  late final Ticker _heroTicker;
  // Pilote les frames de l'héroïne SANS reconstruire toute la cabine. Seul le
  // cluster héroïne (sprite + halo) écoute ce notifier ; _onHeroTick le bump à
  // chaque frame au lieu d'un setState global (qui reconstruisait sky + horizon
  // + cab + oiseaux + braises + fumée + HUD 60×/s).
  final ValueNotifier<int> _heroAnim = ValueNotifier<int>(0);
  double _heroX = 0.55;
  double? _heroTarget;
  bool _heroFacingRight = true;
  int _walkFrame = 0;
  int _idleFrame = 0;
  int _walkAccumMs = 0;
  int _idleAccumMs = 0;
  Duration _lastTick = Duration.zero;

  // Scripted log-loading sequence: tap "mettre une bûche" → walk to
  // woodpile → pickup → carry to firebox → throw → done.
  _LocoAction _action = _LocoAction.idle;
  int _actionFrame = 0;
  int _actionAccumMs = 0;
  static const int _actionFrameMs = 55;

  // Layout anchors (normalised to scene size). _fireboxX is also the
  // centre of the warm-hands proximity zone — used by both _fireProximity
  // and the scripted walk target so the two stay in sync.
  static const double _woodpileX = 0.70;
  static const double _fireboxX = 0.34;

  // Brief shake offset applied to the whole scene right after a log
  // thuds into the firebox. Decays to zero over ~400 ms.
  double _shake = 0;
  // Le shake décale TOUTE la scène : on l'isole dans un ValueNotifier pour ne
  // ré-appliquer que le Transform (le sous-arbre est hissé via le param child),
  // sans reconstruire la scène à chaque frame du tremblement.
  final ValueNotifier<double> _shakeNotifier = ValueNotifier<double>(0);

  // Carte murale de la cabine : mode ajuster (déplacer + pincer) + largeur de
  // départ d'un pinch. La carte ouvre la map au tap hors mode ajuster.
  bool _mapAdjust = false; // ajustement de la carte = MODE DEBUG only
  double _mapStartW = 0.2;
  // Ratio largeur/hauteur du cadre de la carte (paysage).
  static const double _mapAspect = 1.85;


  static const List<String> _coldHorizons = [
    'assets/background/horizon_snow_a.png',
    'assets/background/horizon_snow_b.png',
    'assets/background/horizon_snow_c.png',
  ];
  int _coldHorizonIndex = 0;
  Timer? _horizonTimer;

  @override
  void initState() {
    super.initState();
    _sky = AnimationController(vsync: this, duration: const Duration(seconds: 30))
      ..repeat();
    _horizon = AnimationController(vsync: this, duration: const Duration(seconds: 28))
      ..repeat();
    _heroTicker = createTicker(_onHeroTick)..start();
    _horizonTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (!mounted) return;
      setState(() => _coldHorizonIndex = (_coldHorizonIndex + 1) % _coldHorizons.length);
    });
  }

  String get _locoHorizonAsset {
    if (GameState.instance.inColdZone) return _coldHorizons[_coldHorizonIndex];
    return 'assets/background/horizon_a.png';
  }

  @override
  void dispose() {
    _horizonTimer?.cancel();
    _heroTicker.dispose();
    _heroAnim.dispose();
    _shakeNotifier.dispose();
    _sky.dispose();
    _horizon.dispose();
    super.dispose();
  }

  /// Comme setState mais ne rebuild QUE le cluster héroïne (via _heroAnim),
  /// pas toute la cabine. Conserve la sémantique des closures de setState
  /// (un `return` interne sort de fn).
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

    if (_shake > 0) {
      _shake = (_shake - dt * 2.5).clamp(0.0, 1.0);
      // Le shake ne touche que le Transform de scène -> notifier dédié.
      _shakeNotifier.value = _shake;
    }

    // Drive the scripted log-loading sequence first; falls through to
    // free-walk + idle below when _action is idle.
    if (_action == _LocoAction.pickingUp || _action == _LocoAction.throwing) {
      const actionMaxFrames = 14;
      _animSet(() {
        _actionAccumMs += dtMs;
        while (_actionAccumMs >= _actionFrameMs) {
          _actionAccumMs -= _actionFrameMs;
          _actionFrame++;
          if (_actionFrame >= actionMaxFrames) {
            _onActionAnimDone();
            return;
          }
        }
      });
      return;
    }

    final target = _heroTarget;
    if (target == null) {
      // Action complete or never started — idle anim.
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
      _animSet(() {
        _heroX = target;
        _heroTarget = null;
        _walkFrame = 0;
        _walkAccumMs = 0;
      });
      _onWalkTargetReached();
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
  }

  /// Called when the heroine reaches her current walk target — advances
  /// the scripted log-loading sequence if one is in progress.
  void _onWalkTargetReached() {
    switch (_action) {
      case _LocoAction.walkToWoodpile:
        _action = _LocoAction.pickingUp;
        _actionFrame = 0;
        _actionAccumMs = 0;
        AudioService().playSfx('pickup');
        break;
      case _LocoAction.carryingToFire:
        _action = _LocoAction.throwing;
        _actionFrame = 0;
        _actionAccumMs = 0;
        break;
      default:
        break;
    }
  }

  /// Called when a one-shot pickup or throw animation completes.
  void _onActionAnimDone() {
    switch (_action) {
      case _LocoAction.pickingUp:
        // Bûche in arms — head to the firebox.
        _action = _LocoAction.carryingToFire;
        _actionFrame = 0;
        _actionAccumMs = 0;
        _walkFrame = 0;
        _walkAccumMs = 0;
        _heroTarget = _fireboxX;
        break;
      case _LocoAction.throwing:
        // Bûche delivered. Counter ticks up, scene shakes, fire whoofs.
        _action = _LocoAction.idle;
        _actionFrame = 0;
        widget.onThrowLog();
        _shake = 1.0;
        _shakeNotifier.value = _shake; // démarre le tremblement (Transform seul)
        AudioService().playSfx('log_throw');
        break;
      default:
        break;
    }
  }

  void _walkTo(double normalizedX) {
    setState(() => _heroTarget = normalizedX.clamp(_heroXMin, _heroXMax));
  }

  /// 0..1 — how close the heroine is to the firebox. Drives the warm
  /// halo so it brightens as she steps up to the fire.
  double _fireProximity() {
    const range = 0.18;
    final d = (_heroX - _fireboxX).abs();
    if (d >= range) return 0.0;
    return 1.0 - d / range;
  }

  void _throwLog() {
    // Reject if a sequence is already running.
    if (_action != _LocoAction.idle) return;
    // Tas de bûches vide -> pas d'anim pour rien (le geste ne donnerait pas
    // de bois).
    if (GameState.instance.gareWoodLeft <= 0) return;
    setState(() {
      _action = _LocoAction.walkToWoodpile;
      _heroTarget = _woodpileX;
    });
  }

  Widget _nightTint(Widget child) {
    Widget result = child;
    if (!widget.night && GameState.instance.inColdZone) {
      result = ColorFiltered(
        colorFilter: const ColorFilter.mode(Color(0xFFDDE3EE), BlendMode.modulate),
        child: result,
      );
    }
    if (!widget.night) return result;
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(Color(0xFF4A5C82), BlendMode.modulate),
      child: result,
    );
  }

  // Base de hauteur du perso dans la scène loco. walk_right rend à
  // h * _kLocoHeroBase. Plus grand que le wagon (kHeroBaseHeight =
  // 0.36) parce que la caméra loco est plus rapprochée. Les ratios
  // scale / aspect / feet par anim sont piochés dans la table
  // partagée kAnimMetrics (lib/data/anim_metrics.dart).
  static const double _kLocoHeroBase = 0.572;

  Widget _buildHeroine(double w, double h) {
    final isMoving = _heroTarget != null;
    String prefix;
    int frame;
    switch (_action) {
      case _LocoAction.pickingUp:
        prefix = 'open_door';
        frame = _actionFrame.clamp(0, 13);
        break;
      case _LocoAction.throwing:
        prefix = 'open_door';
        frame = (13 - _actionFrame).clamp(0, 13);
        break;
      case _LocoAction.carryingToFire:
        prefix = 'carry_walk';
        frame = _walkFrame;
        break;
      case _LocoAction.walkToWoodpile:
        prefix = 'walk_right';
        frame = _walkFrame;
        break;
      case _LocoAction.idle:
        if (!isMoving && _fireProximity() > 0.5) {
          prefix = 'warm_hands';
          frame = _idleFrame;
        } else {
          prefix = isMoving ? 'walk_right' : 'idle_right';
          frame = isMoving ? _walkFrame : _idleFrame;
        }
        break;
    }
    final asset = 'assets/characters/${prefix}_${frame + 1}.png';

    final m = animMetricsFor(prefix);
    final bool shouldMirror;
    if (prefix == 'open_door') {
      shouldMirror = _action == _LocoAction.throwing;
    } else if (m.noMirror) {
      shouldMirror = false;
    } else {
      shouldMirror = !_heroFacingRight;
    }
    // walk_right rend à h * _kLocoHeroBase * 1.0. Les autres anims
    // se calibrent via m.scale (relatif à walk_right). Cf.
    // lib/data/anim_metrics.dart.
    final heroHeight = h * _kLocoHeroBase * m.scale;
    final heroWidth = heroHeight * m.aspect;
    final feetRatio = m.feet;
    final feetY = h * 0.92;
    return Positioned(
      left: w * _heroX - heroWidth / 2,
      top: feetY - heroHeight * feetRatio,
      width: heroWidth,
      height: heroHeight,
      child: IgnorePointer(
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..scaleByDouble(shouldMirror ? -1.0 : 1.0, 1.0, 1.0, 1.0),
          // cacheWidth = source (512) : full quality + clé partagée avec le
          // précache (main._warmLocoAnims) et le rendu wagon.
          child: _nightTint(Image.asset(asset,
              fit: BoxFit.contain, cacheWidth: kHeroDecodeWidth)),
        ),
      ),
    );
  }

  // Carte du voyage accrochée dans la cabine. Tap = ouvre la map. En mode
  // ajuster : 1 doigt = déplacer, pincer = redimensionner ; coords persistées.
  Widget _buildLocoMap(double w, double h) {
    final gs = GameState.instance;
    final boxW = gs.locoMapW * w;
    final boxH = boxW / _mapAspect;
    final left = gs.locoMapCx * w - boxW / 2;
    final top = gs.locoMapCy * h - boxH / 2;

    final frame = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF5A3E22),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
            color: _mapAdjust ? const Color(0xFFE8B96B) : const Color(0xFF3A2614),
            width: _mapAdjust ? 2 : 1),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 5, offset: Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: const MiniRouteMap(aged: true),
      ),
    );

    // Vue 3/4 : on incline la carte autour de l'axe vertical pour qu'elle
    // épouse le mur de droite (le bord droit recule vers le fond). Inverser
    // le signe de _mapTurn si l'angle part du mauvais côté.
    final turned = _nightTint(Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0008)
        ..rotateY(gs.locoMapTurnY)
        ..rotateZ(gs.locoMapLeanZ),
      child: frame,
    ));

    return Positioned(
      left: left,
      top: top,
      width: boxW,
      height: boxH,
      child: _mapAdjust
          // En mode ajuster, le geste se fait sur TOUT l'écran (couche dédiée
          // ci-dessous) : ici la carte n'est plus que visuelle.
          ? IgnorePointer(child: turned)
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onOpenMap,
              // Halo doux permanent : signale que la carte est interactive
              // (avant, rien ne disait qu'on pouvait la toucher pour ouvrir
              // la carte du voyage).
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x66FFC04A),
                        blurRadius: 18,
                        spreadRadius: 1),
                  ],
                ),
                child: turned,
              ),
            ),
    );
  }

  void _nudgeRot(double dTurn, double dLean) =>
      setState(() => GameState.instance.nudgeLocoMapRot(dTurn, dLean));

  // Une ligne de réglage rotation : libellé + valeur + boutons − / +.
  Widget _rotRow(String label, double value, VoidCallback minus, VoidCallback plus) {
    Widget btn(String t, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            width: 30,
            height: 26,
            alignment: Alignment.center,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF3A4656),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(t,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 92,
            child: Text('$label ${value.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          btn('−', minus),
          btn('+', plus),
        ],
      ),
    );
  }

  // Couche plein écran active en mode ajuster : pincer/déplacer n'importe où
  // pour bouger + redimensionner la carte (pas besoin de viser la mini-carte).
  Widget _mapAdjustLayer(double w, double h) {
    final gs = GameState.instance;
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: (_) => _mapStartW = gs.locoMapW,
        onScaleUpdate: (d) {
          setState(() {
            gs.setLocoMap(
              gs.locoMapCx + d.focalPointDelta.dx / w,
              gs.locoMapCy + d.focalPointDelta.dy / h,
              d.scale != 1.0 ? _mapStartW * d.scale : gs.locoMapW,
            );
          });
        },
      ),
    );
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
            // Tappable rocking scene: sky + horizon + cab + heroine.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _walkTo(d.localPosition.dx / w),
                // Le tremblement ne ré-applique QUE le Transform : le sous-arbre
                // (TrainRocking + Stack) est hissé via `child` et n'est PAS
                // reconstruit à chaque frame du shake.
                child: ValueListenableBuilder<double>(
                  valueListenable: _shakeNotifier,
                  child: TrainRocking(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _nightTint(
                        _ParallaxLayer(
                          controller: _sky,
                          asset: GameState.instance.inColdZone
                              ? 'assets/background/sky_snow.png'
                              : 'assets/background/sky.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: h * 0.05,
                        bottom: 0,
                        child: _nightTint(
                          _ParallaxLayer(
                            controller: _horizon,
                            asset: _locoHorizonAsset,
                            fit: BoxFit.fitWidth,
                            alignment: Alignment.topCenter,
                          ),
                        ),
                      ),
                      // Daytime birds in the sky visible through the
                      // door opening. Drawn BEFORE the cab so they're
                      // masked outside the door window.
                      Positioned(
                        left: 0,
                        right: w * 0.4,
                        top: h * 0.05,
                        height: h * 0.20,
                        child: DaytimeBirds(
                          animation: _sky,
                          enabled: !widget.night,
                        ),
                      ),
                      // Silhouettes au loin RETIRÉES (demande user : pas de
                      // personnages qui marchent dans le background).
                      // Fond chaud derrière le poêle — simule des
                      // braises/parois éclairées. Bloque le paysage
                      // pour que seul le feu soit visible.
                      Positioned(
                        left: w * 0.10,
                        top: h * 0.52,
                        width: w * 0.18,
                        height: h * 0.28,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment(0.0, 0.3),
                              radius: 0.9,
                              colors: [
                                Color(0xFF4A2008),
                                Color(0xFF1A0A02),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Flammes animées DERRIÈRE le PNG — visibles à
                      // travers le petit carré transparent du poêle.
                      Positioned.fill(
                        child: FireboxFlames(
                          animation: _sky,
                          x: 0.17,
                          y: 0.78,
                          width: 0.14,
                          height: 0.16,
                        ),
                      ),
                      // Locomotive cab — la transparence est bakée dans
                      // le PNG (chroma key vert + bleu). Vert = paysage
                      // (porte, hublot, fenêtres), bleu = feu (poêle).
                      Positioned.fill(
                        child: _nightTint(
                          Image.asset(
                            'assets/background/locomotive.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const ColoredBox(color: Color(0xFF1A1410)),
                          ),
                        ),
                      ),
                      // Firebox glow — halo ambré devant la cab, donne
                      // l'impression que le feu éclaire l'intérieur.
                      Positioned.fill(
                        child: FireGlow(
                          animation: _sky,
                          x: 0.17,
                          y: 0.66,
                          radius: 0.45,
                        ),
                      ),
                      // Lampe suspendue : sprite + halo. Débloquée par
                      // l'histoire (asset_lamp, gare 2) — absente au départ.
                      if (GameState.instance.propUnlocked('lamp')) ...[
                        Positioned(
                          left: w * 0.62 - h * 0.06,
                          top: h * 0.04,
                          width: h * 0.12,
                          height: h * 0.20,
                          child: _nightTint(Image.asset(
                            'assets/objects/lamp_1.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          )),
                        ),
                        // Halo : marqué la nuit, discret le jour.
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: widget.night ? 1.0 : 0.4,
                              child: LampGlow(
                                animation: _sky,
                                x: 0.62,
                                y: 0.20,
                                radius: 0.18,
                                floorY: 0.92,
                              ),
                            ),
                          ),
                        ),
                      ],
                      _buildHeroine(w, h),
                      // Warm halo when she's near the firebox (left)
                      // or the woodpile (right). Brightest right next
                      // to the open firebox door.
                      Positioned.fill(
                        child: CharacterHalo(
                          heroX: _heroX,
                          heroY: 0.68,
                          intensity: _fireProximity(),
                        ),
                      ),
                      // Subtle breathing of the ambient light synced
                      // to the rocking cadence.
                      Positioned.fill(
                        child: AmbientPulse(animation: _sky, amplitude: 0.04),
                      ),
                      if (widget.night)
                        Positioned.fill(
                          child: Fireflies(animation: _horizon, count: 4),
                        ),
                      // Steam wisps drifting in through the door.
                      Positioned(
                        left: 0,
                        right: w * 0.4,
                        top: h * 0.2,
                        height: h * 0.5,
                        child: DoorSteam(animation: _sky),
                      ),
                      // Flying embers from the firebox.
                      Positioned.fill(
                        child: FlyingEmbers(
                          animation: _sky,
                          intensity:
                              (0.3 + widget.logsThrown.clamp(0, 8) / 8.0 * 0.7)
                                  .clamp(0.3, 1.0),
                        ),
                      ),
                      // (effet aiguilles retiré : rendait mal)
                      // Floating ashes near the firebox floor.
                      const Positioned.fill(child: FloatingAshes()),
                      // Pipe steam from valves (intensity grows with logs).
                      Positioned.fill(
                        child: PipeSteam(
                          intensity: (0.4 +
                                  widget.logsThrown.clamp(0, 8) / 8.0 * 0.6)
                              .clamp(0.4, 1.0),
                        ),
                      ),
                      // Carte du voyage accrochée dans la cabine (tap = map).
                      if (widget.onOpenMap != null) _buildLocoMap(w, h),
                    ],
                  ),
                ),
                ),
              ),
            ),
            // Couche de geste plein écran (ajuster la carte partout).
            if (_mapAdjust && widget.onOpenMap != null) _mapAdjustLayer(w, h),
            // Panneau de réglage de la carte (mode ajuster) : coords + rotation.
            if (_mapAdjust)
              Positioned(
                left: 12,
                bottom: 12,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Builder(builder: (_) {
                      final gs = GameState.instance;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'glisser/pincer = déplacer/taille\n'
                            'cx ${gs.locoMapCx.toStringAsFixed(2)}  '
                            'cy ${gs.locoMapCy.toStringAsFixed(2)}  '
                            'w ${gs.locoMapW.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFFFFD9A0),
                              fontSize: 11,
                              fontFamily: 'Courier',
                            ),
                          ),
                          const SizedBox(height: 6),
                          _rotRow('3/4', gs.locoMapTurnY,
                              () => _nudgeRot(-0.05, 0),
                              () => _nudgeRot(0.05, 0)),
                          _rotRow('penché', gs.locoMapLeanZ,
                              () => _nudgeRot(0, -0.03),
                              () => _nudgeRot(0, 0.03)),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            // HUD : anneaux centrés en haut (MÊME placement que le wagon), avec
            // la réserve de bois en dessous (spécifique loco).
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: SafeArea(
                child: IgnorePointer(
                  child: Center(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const StatRingsBar(
                          ringSize: 34,
                          emojiSize: 15,
                          mainAxisSize: MainAxisSize.min,
                          alignment: MainAxisAlignment.center,
                        ),
                        const SizedBox(height: 4),
                        Builder(builder: (_) {
                          final stock = GameState.instance.gareWoodLeft;
                          return Text(
                            stock > 0
                                ? 'Bûches à ramasser ici : $stock'
                                : 'Tas vide — d\'autres bûches à la prochaine gare',
                            style: TextStyle(
                              color: stock > 0
                                  ? const Color(0xFFFFD9A0)
                                  : const Color(0xFFE0A0A0),
                              fontSize: 12,
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Action buttons (bottom-right).
            Positioned(
              right: 16,
              bottom: 16,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Ajuster la carte murale = outil de réglage : DEBUG only.
                    if (GameState.instance.debugMode) ...[
                      FloatingActionButton.small(
                        heroTag: 'loco_map_adjust',
                        tooltip: 'Ajuster la carte',
                        backgroundColor: _mapAdjust
                            ? const Color(0xFFE8B96B)
                            : Colors.black54,
                        foregroundColor:
                            _mapAdjust ? const Color(0xFF2A2018) : Colors.white,
                        onPressed: () => setState(() => _mapAdjust = !_mapAdjust),
                        child: Icon(_mapAdjust ? Icons.check : Icons.edit),
                      ),
                      const SizedBox(height: 12),
                    ],
                    FloatingActionButton.small(
                      heroTag: 'throw_log',
                      tooltip: 'Mettre une bûche',
                      backgroundColor: const Color(0xFFB85522),
                      foregroundColor: Colors.white,
                      onPressed: _throwLog,
                      child: const Icon(Icons.local_fire_department),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton.small(
                      heroTag: 'return_to_wagon',
                      tooltip: 'Retourner au wagon',
                      onPressed: widget.onReturn,
                      child: const Icon(Icons.arrow_back),
                    ),
                  ],
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

}

class _ParallaxLayer extends StatelessWidget {
  const _ParallaxLayer({
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

