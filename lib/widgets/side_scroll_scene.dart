import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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
    this.onUserInteract,
    this.onHeroXChanged,
    this.bedAdjust = false,
    this.logsThrown = 0,
    this.doorPushToken = 0,
    this.onDoorPushDone,
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

  /// Incremented by the parent when the door-action button is pressed
  /// to enter the locomotive. The scene plays the door_push animation
  /// once and calls [onDoorPushDone] when it finishes — at which point
  /// the parent transitions to the locomotive screen.
  final int doorPushToken;

  /// Fired when the door-push animation completes — see [doorPushToken].
  final VoidCallback? onDoorPushDone;

  /// Fired the first time the user taps the wagon floor, so the parent
  /// can drop any "she's dancing" state it was holding.
  final VoidCallback? onUserInteract;

  /// Fired every time the heroine's normalised X position changes. The
  /// parent uses it to enable/disable the door action button when she's
  /// at the left edge (locomotive door).
  final void Function(double heroX)? onHeroXChanged;

  /// Left bound for the heroine in normalised X. Exposed so the parent
  /// can compare against it to know when she's at the door.
  static const double heroXMin = 0.20;

  /// When `true` the bed becomes draggable + resizable, and a HUD shows
  /// its current normalised position + width so the values can be copied
  /// back into the defaults below.
  final bool bedAdjust;

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
  late final AnimationController _foreground;
  late final AnimationController _smoke;
  late final AnimationController _sky;

  // Heroine state. Position is normalised to the scene width. X bounds
  // keep her on the wagon's parquet floor — left of 0.25 is the
  // locomotive / coupling, right of 0.82 is the closed back-door area.
  static const int _heroFrameCount = 49;
  static const double _heroXMin = SideScrollScene.heroXMin;
  static const double _heroXMax = 0.82;
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

  // Horizon parallax cycles through these in sequence with a slow
  // cross-fade so the train passes through varied scenery instead of
  // staring at the same skyline forever.
  static const List<String> _horizonAssets = [
    'assets/background/horizon_a.png',
    'assets/background/horizon_b.png',
    'assets/background/horizon_c.png',
  ];
  static const Duration _horizonRotatePeriod = Duration(seconds: 45);
  static const Duration _horizonCrossFade = Duration(seconds: 2);
  int _horizonIndex = 0;
  Timer? _horizonRotateTimer;

  late final Ticker _heroTicker;
  double _heroX = 0.5;
  double? _heroTarget;
  // She has only two facing options: the walk_right sheet, or its
  // horizontal mirror for going left.
  bool _heroFacingRight = true;
  bool _heroSleeping = false;
  bool _heroDancing = false;
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

  // Door-push: short one-shot animation played when entering the
  // locomotive. Fires onDoorPushDone when complete.
  bool _doorPushing = false;
  int _doorFrame = 0;
  int _doorAccumMs = 0;
  static const int _doorFrameMs = 40; // ~2s total for 49 frames
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
    _sky = AnimationController(vsync: this, duration: const Duration(seconds: 30))..repeat();
    _horizon = AnimationController(vsync: this, duration: const Duration(seconds: 28))..repeat();
    _foreground = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _smoke = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _applyRunning();
    _heroTicker = createTicker(_onHeroTick)..start();
    _horizonRotateTimer = Timer.periodic(_horizonRotatePeriod, (_) {
      if (!mounted) return;
      setState(() {
        _horizonIndex = (_horizonIndex + 1) % _horizonAssets.length;
      });
    });
    _thoughtTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!mounted) return;
      // 50 % chance to skip — so they don't appear like clockwork.
      if (math.Random().nextDouble() < 0.5) return;
      const moods = ['☕', '💭', '🌧', '💤', '🌿', '📖', '🎵'];
      setState(() => _thoughtEmoji = moods[math.Random().nextInt(moods.length)]);
      _thoughtClearTimer?.cancel();
      _thoughtClearTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _thoughtEmoji = null);
      });
    });
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
      'door_push',
      'warm_hands',
      'carry_walk',
    ];
    for (final anim in animations) {
      for (int i = 1; i <= _heroFrameCount; i++) {
        precacheImage(AssetImage('assets/characters/${anim}_$i.png'), context);
      }
    }
    for (final asset in const [
      'assets/background/sky.png',
      'assets/background/sky_night.png',
      'assets/background/horizon_a.png',
      'assets/background/horizon_b.png',
      'assets/background/horizon_c.png',
      'assets/background/horizon_night.png',
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
      setState(() {
        _heroDancing = false;
        _heroSleeping = false;
        _heroTarget = null;
        _heroLyingDown = true;
        _lieDownFrame = _heroFrameCount - 1;
        _lieDownAccumMs = 0;
      });
    }
    if (oldWidget.doorPushToken != widget.doorPushToken) {
      setState(() {
        _doorPushing = true;
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
    final ctrls = [_horizon, _foreground, _smoke, _sky];
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
    _heroTicker.dispose();
    _horizonRotateTimer?.cancel();
    _thoughtTimer?.cancel();
    _thoughtClearTimer?.cancel();
    _sky.dispose();
    _horizon.dispose();
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
          if (_doorFrame >= _heroFrameCount) {
            _doorPushing = false;
            widget.onDoorPushDone?.call();
            return;
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
          final nearWindow = _nearWindow();
          if (nearWindow) {
            _idleBreak = 'look_window';
          } else if (math.Random().nextDouble() < 0.6) {
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
      setState(() {
        _heroX = target;
        _heroTarget = null;
        _walkFrame = 0;
        _walkAccumMs = 0;
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
        // puff at the heroine's feet.
        if (_walkFrame % 6 == 0) _stepToken++;
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
      _heroTarget = clamped;
      if (wasSleeping) {
        // Don't let her snap from lying flat into a walk — play the
        // wake_up + stretch sequence first, then she'll walk to the
        // queued target.
        _waking = true;
        _wakingPhase = 0;
        _wakingFrame = 0;
        _wakingAccumMs = 0;
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
            return ClipRect(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _walkTo(d.localPosition.dx / w),
                child: TrainRocking(
                  enabled: widget.running,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 1. Sky — drifting clouds, visible motion. Night
                      //    re-uses the day asset with a cool blue tint so
                      //    the whole scene stays visually consistent.
                      _nightTint(
                        _ParallaxLayer(
                          controller: _sky,
                          asset: 'assets/background/sky.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                      // 2. Horizon — distant ruins reclaimed by vegetation.
                      //    Cycles through 3 variants (urban / wooded / industrial)
                      //    every ~45s with a 2s cross-fade so the train passes
                      //    through varied scenery instead of looping one image.
                      //    Stretched down past the wagon body so the bottom
                      //    of the source (meadow + ground) fills any gaps
                      //    around the coupling chains under the wagon.
                      Positioned(
                        left: 0,
                        right: 0,
                        top: h * 0.18,
                        bottom: 0,
                        child: AnimatedSwitcher(
                          duration: _horizonCrossFade,
                          child: _nightTint(
                            _ParallaxLayer(
                              key: ValueKey(_horizonAssets[_horizonIndex]),
                              controller: _horizon,
                              asset: _horizonAssets[_horizonIndex],
                              fit: BoxFit.fitWidth,
                              alignment: Alignment.topCenter,
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
                      // 4b. Bed — placed at floor level on the left of
                      //     the wagon interior. Position + size are
                      //     normalised state so the in-app adjustment
                      //     mode can drag + resize them live; final
                      //     values get baked back into the defaults.
                      Positioned(
                        left: w * _bedLeft,
                        top: h * _bedTop,
                        width: w * _bedWidth,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanUpdate: widget.bedAdjust
                              ? (d) => setState(() {
                                    _bedLeft = (_bedLeft + d.delta.dx / w)
                                        .clamp(0.0, 1.0 - _bedWidth);
                                    _bedTop = (_bedTop + d.delta.dy / h)
                                        .clamp(0.0, 0.95);
                                  })
                              : null,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              _nightTint(
                                Image.asset(
                                  'assets/objects/bed.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              if (widget.bedAdjust) ...[
                                // Dashed outline around the bed's
                                // hitbox so the drag target is visible.
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(0xFFFFB347),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Bottom-right resize handle: drag to
                                // grow / shrink the bed by changing
                                // its normalised width. Aspect ratio
                                // stays locked (Image.asset contains).
                                Positioned(
                                  right: -16,
                                  bottom: -16,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onPanUpdate: (d) => setState(() {
                                      _bedWidth = (_bedWidth + d.delta.dx / w)
                                          .clamp(0.05, 0.80);
                                    }),
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFB85522),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.open_in_full,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      // Bed-adjust HUD: live readout of the values so
                      // they can be copied into the defaults above.
                      if (widget.bedAdjust)
                        Positioned(
                          top: 16,
                          left: 16,
                          child: SafeArea(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'left: ${_bedLeft.toStringAsFixed(3)}\n'
                                'top:  ${_bedTop.toStringAsFixed(3)}\n'
                                'width:${_bedWidth.toStringAsFixed(3)}',
                                style: const TextStyle(
                                  color: Color(0xFFFFD9A0),
                                  fontSize: 14,
                                  fontFamily: 'Courier',
                                  height: 1.4,
                                ),
                              ),
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
                      Positioned(
                        left: 0,
                        right: 0,
                        top: h * 0.17,
                        height: h * 0.09,
                        child: HangingVines(
                          animation: _sky,
                          opacity: widget.night ? 0.30 : 0.45,
                        ),
                      ),
                      // 4f. Distant zombie passing across the window band,
                      //     night only.
                      Positioned(
                        left: 0,
                        right: 0,
                        top: h * 0.30,
                        height: h * 0.30,
                        child: DistantZombie(enabled: widget.night),
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
                      // 5d. Rain on the window band, night only and only
                      //     while the train is moving — gives "weather".
                      if (widget.night && widget.running)
                        Positioned.fill(
                          child: WindowRain(
                            animation: _foreground,
                            density: 24,
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
                      // 5. Locomotive smoke — drifts over the top of the wagon.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _smoke,
                            builder: (_, __) => CustomPaint(
                              painter: _SmokePainter(
                                _smoke.value,
                                running: widget.running,
                                // Lighter baseline so daytime smoke
                                // doesn't read as oppressive; each
                                // log nudges intensity up.
                                intensity: 0.65 + 0.08 * widget.logsThrown.clamp(0, 8),
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

  Widget _buildHeroine(double w, double h) {
    // Wagon's interior floor sits roughly at this Y.
    final feetY = h * 0.79;
    final anchorX = _heroX * w;

    if (_doorPushing) {
      final heroHeight = h * 0.36 * (512 / 360);
      final heroWidth = heroHeight;
      final asset = 'assets/characters/door_push_${_doorFrame + 1}.png';
      return Positioned(
        // New-square sprites have ~14 % padding below the character's
        // feet inside their 512x512 canvas; anchor on the bbox bottom
        // (86 % of sprite height) so feet sit on the floor instead of
        // floating above it.
        left: anchorX - heroWidth / 2,
        top: feetY - heroHeight * 0.86,
        width: heroWidth,
        height: heroHeight,
        child: IgnorePointer(
          child: _nightTint(
            Transform(
              alignment: Alignment.center,
              transform: _heroFacingRight
                  ? Matrix4.identity()
                  : (Matrix4.identity()..scale(-1.0, 1.0, 1.0)),
              child: Image.asset(asset, fit: BoxFit.contain),
            ),
          ),
        ),
      );
    }

    if (_waking) {
      // Wake-up sequence: wake_up_* (lying → standing) then stretch_*
      // (arms up → arms down). Both are 512x512 squares.
      final prefix = _wakingPhase == 0 ? 'wake_up' : 'stretch';
      final heroHeight = h * 0.36 * (512 / 360);
      final heroWidth = heroHeight;
      final asset = 'assets/characters/${prefix}_${_wakingFrame + 1}.png';
      return Positioned(
        left: anchorX - heroWidth / 2,
        top: feetY - heroHeight * 0.86,
        width: heroWidth,
        height: heroHeight,
        child: IgnorePointer(
          child: _nightTint(Image.asset(asset, fit: BoxFit.contain)),
        ),
      );
    }

    if (_heroSleeping) {
      // Lying on the floor. Sleep sprite is 366x103 ≈ 3.55:1.
      final bodyLen = h * 0.36;
      final bodyThick = bodyLen / (366 / 103);
      final asset = 'assets/characters/sleep_right_${_sleepFrame + 1}.png';
      return Positioned(
        left: anchorX - bodyLen / 2,
        top: feetY - bodyThick,
        width: bodyLen,
        height: bodyThick,
        child: IgnorePointer(
          child: _nightTint(Image.asset(asset, fit: BoxFit.contain)),
        ),
      );
    }

    if (_heroLyingDown) {
      // Pickup sprite is 170x385, aspect ≈ 0.44, body fills the bbox so
      // same scale as walk/idle.
      final heroHeight = h * 0.36;
      final heroWidth = heroHeight * (170 / 385);
      final asset = 'assets/characters/pickup_${_lieDownFrame + 1}.png';
      return Positioned(
        left: anchorX - heroWidth / 2,
        top: feetY - heroHeight,
        width: heroWidth,
        height: heroHeight,
        child: IgnorePointer(
          child: _nightTint(
            Transform(
              alignment: Alignment.center,
              transform: _heroFacingRight
                  ? Matrix4.identity()
                  : (Matrix4.identity()..scale(-1.0, 1.0, 1.0)),
              child: Image.asset(asset, fit: BoxFit.contain),
            ),
          ),
        ),
      );
    }

    if (_heroDancing) {
      // Dance sprite is 264x425. The body's head-to-feet height is
      // smaller than the bbox because the raised arms add ~15% of bbox
      // height above the head — bump heroHeight so the on-screen body
      // matches walk/idle scale instead of looking shrunk.
      final heroHeight = h * 0.36 * (425 / 365);
      final heroWidth = heroHeight * (264 / 425);
      final asset = 'assets/characters/dance_${_danceFrame + 1}.png';
      return Positioned(
        left: anchorX - heroWidth / 2,
        top: feetY - heroHeight,
        width: heroWidth,
        height: heroHeight,
        child: IgnorePointer(
          child: _nightTint(Image.asset(asset, fit: BoxFit.contain)),
        ),
      );
    }

    // Standing / walking / idle break. The legacy walk + idle sheets
    // are tightly cropped (walk 166x381, idle 91x372). The newer 49-
    // frame sheets (yawn, stretch, look_window, read, wake_up, etc.)
    // are 512x512 squares with the character inside a smaller bbox —
    // displaying them at the idle aspect would squash them horizontally
    // and shrink the character. Bump heroHeight by 512/360 (the new
    // sprite's vertical headroom) and use a square aspect so they read
    // at the same physical scale as the legacy sheets.
    const newSquareSprites = {
      'yawn', 'stretch', 'look_window', 'read', 'wake_up',
      'door_push', 'warm_hands', 'carry_walk',
    };
    final isMoving = _heroTarget != null;
    int frame;
    String prefix;
    if (_idleBreak != null) {
      prefix = _idleBreak!;
      frame = _idleBreakFrame;
    } else if (isMoving) {
      prefix = 'walk_right';
      frame = _walkFrame;
    } else {
      prefix = 'idle_right';
      frame = _idleFrame;
    }
    final asset = 'assets/characters/${prefix}_${frame + 1}.png';

    final isNewSquare = newSquareSprites.contains(prefix);
    final double heroHeight;
    final double spriteAspect;
    // bbox-bottom ratio: 1.0 for legacy tight crops, 0.86 for the
    // 512x512 squares (their character ends at ~y=440 of 512).
    final double feetRatio;
    if (isNewSquare) {
      heroHeight = h * 0.36 * (512 / 360);
      spriteAspect = 1.0;
      feetRatio = 0.86;
    } else if (isMoving) {
      heroHeight = h * 0.36;
      spriteAspect = 166 / 381;
      feetRatio = 1.0;
    } else {
      heroHeight = h * 0.36;
      spriteAspect = 91 / 372;
      feetRatio = 1.0;
    }
    final heroWidth = heroHeight * spriteAspect;

    return Positioned(
      left: anchorX - heroWidth / 2,
      top: feetY - heroHeight * feetRatio,
      width: heroWidth,
      height: heroHeight,
      child: IgnorePointer(
        child: _nightTint(
          Transform(
            alignment: Alignment.center,
            transform: _heroFacingRight
                ? Matrix4.identity()
                : (Matrix4.identity()..scale(-1.0, 1.0, 1.0)),
            child: Image.asset(asset, fit: BoxFit.contain),
          ),
        ),
      ),
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
    if (!widget.night) return child;
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(
        Color(0xFF4A5C82),
        BlendMode.modulate,
      ),
      child: child,
    );
  }
}

/// Translates an asset horizontally to give the illusion of infinite scroll.
/// Renders two copies side-by-side and shifts both together; when one slides
/// fully off-screen left, its partner takes over without a visible jump.
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
