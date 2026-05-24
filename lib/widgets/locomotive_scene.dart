import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../data/anim_metrics.dart';
import '../services/audio_service.dart';
import 'atmosphere.dart';
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
    this.night = false,
  });

  final VoidCallback onReturn;
  final bool night;
  final int logsThrown;
  final VoidCallback onThrowLog;

  @override
  State<LocomotiveScene> createState() => _LocomotiveSceneState();
}

class _LocomotiveSceneState extends State<LocomotiveScene>
    with TickerProviderStateMixin {
  late final AnimationController _sky;
  late final AnimationController _horizon;

  static const int _heroFrameCount = 49;
  static const double _heroXMin = 0.30;
  static const double _heroXMax = 0.72;
  static const double _heroSpeed = 0.18;
  static const int _walkFrameMs = 50;
  static const int _idleFrameMs = 80;

  late final Ticker _heroTicker;
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
  static const double _fireboxX = 0.30;

  // Brief shake offset applied to the whole scene right after a log
  // thuds into the firebox. Decays to zero over ~400 ms.
  double _shake = 0;

  // Mode adjust des trous (porte + 2 fenêtres latérales). Quand
  // activé, les 3 rectangles deviennent draggables/resizables + HUD
  // top-right avec sliders. Valeurs bakées ici (normalisées au render
  // size de l'asset locomotive.png, qui occupe la scène en BoxFit.contain).
  bool _maskAdjust = false;
  int _activeMask = 0; // 0=door, 1=leftWin, 2=rightWin
  final List<_NormRect> _maskHoles = [
    _NormRect(0.420, 0.580, 0.300, 0.850), // porte centrale
    _NormRect(0.300, 0.420, 0.420, 0.660), // fenêtre gauche
    _NormRect(0.580, 0.720, 0.420, 0.660), // fenêtre droite
  ];
  static const List<String> _maskLabels = ['Porte', 'Fenêtre G', 'Fenêtre D'];
  // Couleurs des fills semi-transparents en mode adjust (porte rouge,
  // fenêtres bleu / vert) pour visualiser les futurs trous distincts.
  static const List<Color> _maskTintColors = [
    Color(0xFFE85C3F), // porte = rouge orangé
    Color(0xFF4A9CD9), // fenêtre G = bleu
    Color(0xFF6FBF73), // fenêtre D = vert
  ];

  @override
  void initState() {
    super.initState();
    _sky = AnimationController(vsync: this, duration: const Duration(seconds: 30))
      ..repeat();
    _horizon = AnimationController(vsync: this, duration: const Duration(seconds: 28))
      ..repeat();
    _heroTicker = createTicker(_onHeroTick)..start();
  }

  @override
  void dispose() {
    _heroTicker.dispose();
    _sky.dispose();
    _horizon.dispose();
    super.dispose();
  }

  void _onHeroTick(Duration elapsed) {
    final dtMicros = (elapsed - _lastTick).inMicroseconds;
    _lastTick = elapsed;
    if (dtMicros <= 0) return;
    final dt = dtMicros / 1e6;
    final dtMs = (dt * 1000).round();

    if (_shake > 0) {
      _shake = (_shake - dt * 2.5).clamp(0.0, 1.0);
    }

    // Drive the scripted log-loading sequence first; falls through to
    // free-walk + idle below when _action is idle.
    if (_action == _LocoAction.pickingUp || _action == _LocoAction.throwing) {
      setState(() {
        _actionAccumMs += dtMs;
        while (_actionAccumMs >= _actionFrameMs) {
          _actionAccumMs -= _actionFrameMs;
          _actionFrame++;
          if (_actionFrame >= _heroFrameCount) {
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
      setState(() {
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
      setState(() {
        _heroX = target;
        _heroTarget = null;
        _walkFrame = 0;
        _walkAccumMs = 0;
      });
      _onWalkTargetReached();
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

  /// Génère les widgets du mode adjust : 3 rectangles draggables/
  /// resizables (porte + 2 fenêtres) + HUD top-right avec chip
  /// selector + sliders position/taille.
  List<Widget> _buildMaskAdjustOverlay() {
    final widgets = <Widget>[];
    for (int i = 0; i < _maskHoles.length; i++) {
      final r = _maskHoles[i];
      final isActive = _activeMask == i;
      widgets.add(LayoutBuilder(
        builder: (ctx, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          return Positioned(
            left: r.x1 * w,
            top: r.y1 * h,
            width: r.w * w,
            height: r.h * h,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _activeMask = i),
              onPanUpdate: (d) => setState(() {
                final dx = d.delta.dx / w;
                final dy = d.delta.dy / h;
                r.x1 = (r.x1 + dx).clamp(0.0, 1.0 - r.w);
                r.x2 = r.x1 + r.w;
                r.y1 = (r.y1 + dy).clamp(0.0, 1.0 - r.h);
                r.y2 = r.y1 + r.h;
                _activeMask = i;
              }),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        // Fill très opaque par zone (porte rouge,
                        // fenêtre G bleu, fenêtre D vert) pour les
                        // distinguer clairement de la cab peinte.
                        // Active = plus opaque que les autres.
                        color: _maskTintColors[i]
                            .withValues(alpha: isActive ? 0.75 : 0.55),
                        border: Border.all(
                          color: isActive
                              ? const Color(0xFFFFB347)
                              : Colors.white,
                          width: isActive ? 5.0 : 3.0,
                        ),
                      ),
                    ),
                  ),
                  // Crosshair central pour repérer le centre du rect
                  // (utile pour aligner sur un détail peint).
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.black, width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -24,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFFB85522)
                            : Colors.black.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: Text(
                        _maskLabels[i],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Courier',
                        ),
                      ),
                    ),
                  ),
                  if (isActive)
                    Positioned(
                      right: -20,
                      bottom: -20,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanUpdate: (d) => setState(() {
                          final dw = d.delta.dx / w;
                          final dh = d.delta.dy / h;
                          r.x2 = (r.x2 + dw).clamp(r.x1 + 0.02, 1.0);
                          r.y2 = (r.y2 + dh).clamp(r.y1 + 0.02, 1.0);
                        }),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFB85522),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white, width: 3),
                          ),
                          child: const Icon(Icons.open_in_full,
                              color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ));
    }
    // HUD top-right : chip selector + sliders +/- pour la zone active.
    widgets.add(Positioned(
      top: 8,
      right: 80,
      child: SafeArea(child: _buildMaskAdjustHud()),
    ));
    return widgets;
  }

  Widget _tinyBtn(IconData icon, VoidCallback onTap) => InkResponse(
        onTap: onTap,
        radius: 18,
        child: Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: Color(0xFFB85522),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      );

  Widget _buildMaskAdjustHud() {
    final r = _maskHoles[_activeMask];
    Widget row(String label, double value, void Function(double) apply,
        {double step = 0.005}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 96,
              child: Text(
                '$label ${value.toStringAsFixed(3)}',
                style: const TextStyle(
                  color: Color(0xFFFFD9A0),
                  fontSize: 11,
                  fontFamily: 'Courier',
                ),
              ),
            ),
            _tinyBtn(Icons.remove,
                () => setState(() => apply(-step))),
            const SizedBox(width: 4),
            _tinyBtn(Icons.add,
                () => setState(() => apply(step))),
          ],
        ),
      );
    }

    final chips = List.generate(_maskHoles.length, (i) {
      final sel = i == _activeMask;
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: GestureDetector(
          onTap: () => setState(() => _activeMask = i),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: sel
                  ? const Color(0xFFB85522)
                  : Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _maskLabels[i],
              style: TextStyle(
                color: sel ? Colors.white : const Color(0xFFFFD9A0),
                fontSize: 10,
                fontFamily: 'Courier',
                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      );
    });

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: chips),
          const SizedBox(height: 6),
          row('x1', r.x1, (d) {
            r.x1 = (r.x1 + d).clamp(0.0, r.x2 - 0.02);
          }),
          row('x2', r.x2, (d) {
            r.x2 = (r.x2 + d).clamp(r.x1 + 0.02, 1.0);
          }),
          row('y1', r.y1, (d) {
            r.y1 = (r.y1 + d).clamp(0.0, r.y2 - 0.02);
          }),
          row('y2', r.y2, (d) {
            r.y2 = (r.y2 + d).clamp(r.y1 + 0.02, 1.0);
          }),
        ],
      ),
    );
  }

  void _throwLog() {
    // Reject if a sequence is already running.
    if (_action != _LocoAction.idle) return;
    setState(() {
      _action = _LocoAction.walkToWoodpile;
      _heroTarget = _woodpileX;
    });
  }

  Widget _nightTint(Widget child) {
    if (!widget.night) return child;
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(Color(0xFF4A5C82), BlendMode.modulate),
      child: child,
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
        prefix = 'pickup';
        frame = _actionFrame;
        break;
      case _LocoAction.throwing:
        // Reverse the pickup frames so it reads as "stand up + drop".
        prefix = 'pickup';
        frame = _heroFrameCount - 1 - _actionFrame;
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

    // pickup source bends RIGHT par défaut. Firebox à gauche = mirror
    // (pencher à gauche, donc à throwing). warm_hands.noMirror=true
    // dans la table partagée → jamais flippée (face au feu à gauche).
    final m = animMetricsFor(prefix);
    final bool shouldMirror;
    if (prefix == 'pickup') {
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
          transform: Matrix4.identity()..scale(shouldMirror ? -1.0 : 1.0, 1.0),
          child: _nightTint(Image.asset(asset, fit: BoxFit.contain)),
        ),
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
                child: Transform.translate(
                  offset: _shake > 0
                      ? Offset(
                          (math.sin(_shake * 30) * 6) * _shake,
                          (math.cos(_shake * 26) * 4) * _shake,
                        )
                      : Offset.zero,
                  child: TrainRocking(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _nightTint(
                        _ParallaxLayer(
                          controller: _sky,
                          asset: 'assets/background/sky.png',
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
                            asset: 'assets/background/horizon_a.png',
                            fit: BoxFit.fitWidth,
                            alignment: Alignment.topCenter,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: LayoutBuilder(
                          builder: (ctx, c) {
                            final image = Image.asset(
                              'assets/background/locomotive.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => _placeholder(),
                            );
                            // En mode adjust : pas de clip, locomotive
                            // pleinement visible. Sinon : trous appliqués
                            // pour révéler le background derrière.
                            if (_maskAdjust) {
                              return _nightTint(image);
                            }
                            final holes = _maskHoles
                                .map((r) => Rect.fromLTRB(
                                      c.maxWidth * r.x1,
                                      c.maxHeight * r.y1,
                                      c.maxWidth * r.x2,
                                      c.maxHeight * r.y2,
                                    ))
                                .toList();
                            return _nightTint(
                              ClipPath(
                                clipper: HoleClipper(holes),
                                child: image,
                              ),
                            );
                          },
                        ),
                      ),
                      // Firebox glow — soft amber halo anchored on the
                      // open firebox door (centre of the painted fire).
                      Positioned.fill(
                        child: FireGlow(
                          animation: _sky,
                          x: 0.17,
                          y: 0.66,
                          radius: 0.45,
                        ),
                      ),
                      // Live flames flickering inside the firebox door.
                      Positioned.fill(
                        child: FireboxFlames(
                          animation: _sky,
                          x: 0.17,
                          y: 0.66,
                          width: 0.07,
                          height: 0.08,
                        ),
                      ),
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
                    ],
                  ),
                ),
                ),
              ),
            ),
            // Log counter HUD (top-left).
            Positioned(
              top: 24,
              left: 24,
              child: SafeArea(
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Bûches : ${widget.logsThrown}',
                      style: const TextStyle(color: Color(0xFFFFD9A0), fontSize: 16),
                    ),
                  ),
                ),
              ),
            ),
            // Mode adjust : overlay des 3 trous draggables + HUD top-right.
            if (_maskAdjust) ..._buildMaskAdjustOverlay(),
            // Action buttons (bottom-right).
            Positioned(
              right: 16,
              bottom: 16,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
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
                      heroTag: 'mask_adjust',
                      tooltip: _maskAdjust
                          ? 'Valider les positions des trous'
                          : 'Régler porte + fenêtres',
                      backgroundColor: _maskAdjust
                          ? const Color(0xFFB85522)
                          : null,
                      foregroundColor:
                          _maskAdjust ? Colors.white : null,
                      onPressed: () =>
                          setState(() => _maskAdjust = !_maskAdjust),
                      child: Icon(
                          _maskAdjust ? Icons.check : Icons.crop_free),
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

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF1A1410),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.local_fire_department, size: 64, color: Color(0xFFB85522)),
            SizedBox(height: 16),
            Text(
              'Locomotive\n(image à venir)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFFFD9A0), fontSize: 20, height: 1.4),
            ),
          ],
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

/// Rectangle normalisé (0..1 sur w/h) — utilisé pour les trous du masque
/// asset locomotive (porte + 2 fenêtres latérales) ajustables en jeu.
class _NormRect {
  _NormRect(this.x1, this.x2, this.y1, this.y2);
  double x1, x2, y1, y2;
  double get cx => (x1 + x2) / 2;
  double get cy => (y1 + y2) / 2;
  double get w => x2 - x1;
  double get h => y2 - y1;
}

/// Clipper qui troue un widget : retourne un path = rectangle scène
/// PLEIN minus les trous (via PathFillType.evenOdd). Wrapping un
/// Image.asset dans ClipPath(clipper: HoleClipper(holes)) rend
/// l'image transparente sur les zones spécifiées, opaque ailleurs.
class HoleClipper extends CustomClipper<Path> {
  HoleClipper(this.holes);
  final List<Rect> holes;

  @override
  Path getClip(Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    for (final h in holes) {
      path.addRect(h);
    }
    return path;
  }

  @override
  bool shouldReclip(covariant HoleClipper old) {
    if (old.holes.length != holes.length) return true;
    for (int i = 0; i < holes.length; i++) {
      if (old.holes[i] != holes[i]) return true;
    }
    return false;
  }
}
