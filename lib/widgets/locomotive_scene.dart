import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../services/audio_service.dart';
import 'atmosphere.dart';
import 'train_rocking.dart';

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

  // Brief shake offset applied to the whole scene right after a log
  // thuds into the firebox. Decays to zero over ~400 ms.
  double _shake = 0;

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

    final target = _heroTarget;
    if (target == null) {
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

  void _walkTo(double normalizedX) {
    setState(() => _heroTarget = normalizedX.clamp(_heroXMin, _heroXMax));
  }

  /// 0..1 — how close the heroine is to the firebox (x=0.21). Drives
  /// the warm halo so it brightens as she steps up to the fire.
  double _fireProximity() {
    const fireboxX = 0.24;
    const range = 0.18;
    final d = (_heroX - fireboxX).abs();
    if (d >= range) return 0.0;
    return 1.0 - d / range;
  }

  void _throwLog() {
    setState(() => _shake = 1.0);
    widget.onThrowLog();
    _walkTo(_heroXMin + 0.02);
    AudioService().playSfx('log_throw');
  }

  Widget _nightTint(Widget child) {
    if (!widget.night) return child;
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(Color(0xFF4A5C82), BlendMode.modulate),
      child: child,
    );
  }

  Widget _buildHeroine(double w, double h) {
    // Standing sprite is 91x372 in source. Sized so she fits the cab —
    // roughly 50 % of scene height.
    final heroHeight = h * 0.50;
    final heroWidth = heroHeight * (91 / 372);
    final isMoving = _heroTarget != null;
    final frame = isMoving ? _walkFrame : _idleFrame;
    final prefix = isMoving ? 'walk_right' : 'idle_right';
    final asset = 'assets/characters/${prefix}_${frame + 1}.png';
    final feetY = h * 0.92;
    return Positioned(
      left: w * _heroX - heroWidth / 2,
      top: feetY - heroHeight,
      width: heroWidth,
      height: heroHeight,
      child: IgnorePointer(
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..scale(_heroFacingRight ? 1.0 : -1.0, 1.0),
          child: _nightTint(Image.asset(asset, fit: BoxFit.contain)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
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
                        child: _nightTint(
                          Image.asset(
                            'assets/background/locomotive.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => _placeholder(),
                          ),
                        ),
                      ),
                      // Firebox glow — soft amber halo anchored on the
                      // left wall where the firebox sits, pulsing.
                      Positioned.fill(
                        child: FireGlow(
                          animation: _sky,
                          x: 0.21,
                          y: 0.68,
                          radius: 0.55,
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
