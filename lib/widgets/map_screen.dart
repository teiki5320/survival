import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/game_state.dart';

// Gares sur le parcours ovale. position = 0→1 sur l'ovale.
class _Station {
  const _Station(this.name, this.position, {this.big = false});
  final String name;
  final double position;
  final bool big;
}

const _stations = [
  _Station('Norilsk', 0.08, big: true),
  _Station('Halte 47', 0.18),
  _Station('Vorkuta', 0.32, big: true),
  _Station('Halte 12', 0.48),
  _Station('Ashford', 0.58, big: true),
  _Station('Halte 83', 0.68),
  _Station('Halte 9', 0.78),
  _Station('Dustwell', 0.90),
];

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformCtrl = TransformationController();
  late final Ticker _ticker;
  double _displayPosition = GameState.instance.trainPosition;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final target = GameState.instance.trainPosition;
    if ((_displayPosition - target).abs() > 0.0001) {
      setState(() => _displayPosition = target);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _transformCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1410),
      body: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            transformationController: _transformCtrl,
            minScale: 0.5,
            maxScale: 3.0,
            boundaryMargin: const EdgeInsets.all(200),
            child: Center(
              child: Stack(
                children: [
                  Image.asset(
                    'assets/background/map_route.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, e, __) {
                      debugPrint('map_route.png load failed: $e');
                      return const ColoredBox(color: Color(0xFFB8945C));
                    },
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _MapOverlayPainter(
                        trainPosition: _displayPosition,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FloatingActionButton.small(
                  heroTag: 'map_close',
                  tooltip: 'Retour au train',
                  backgroundColor: const Color(0xFFB85522),
                  foregroundColor: Colors.white,
                  onPressed: widget.onClose,
                  child: const Icon(Icons.close),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _TrainZoneHUD(displayPosition: _displayPosition),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Calcule un point sur l'ovale pour une position 0→1.
Offset _ovalPoint(Size size, double position) {
  final cx = size.width * 0.50;
  final cy = size.height * 0.46;
  final rx = size.width * 0.38;
  final ry = size.height * 0.34;
  final angle = position * 2 * math.pi - math.pi / 2;
  return Offset(cx + rx * math.cos(angle), cy + ry * math.sin(angle));
}

double _ovalTangent(Size size, double position) {
  final rx = size.width * 0.38;
  final ry = size.height * 0.34;
  final angle = position * 2 * math.pi - math.pi / 2;
  return math.atan2(ry * math.cos(angle), -rx * math.sin(angle));
}

class _MapOverlayPainter extends CustomPainter {
  _MapOverlayPainter({required this.trainPosition});
  final double trainPosition;

  @override
  void paint(Canvas canvas, Size size) {
    _drawStations(canvas, size);
    _drawSmokeTrail(canvas, size);
    _drawTrain(canvas, size);
  }

  void _drawStations(Canvas canvas, Size size) {
    for (final s in _stations) {
      final p = _ovalPoint(size, s.position);
      final unlocked =
          GameState.instance.isLocationUnlocked(s.name.toLowerCase().replaceAll(' ', '_'));

      // Cercle gare
      final radius = s.big ? 8.0 : 5.0;
      canvas.drawCircle(
        p,
        radius + 2,
        Paint()..color = const Color(0x44000000),
      );
      canvas.drawCircle(
        p,
        radius,
        Paint()..color = unlocked ? const Color(0xFFD4A55A) : const Color(0xFF6A6A6A),
      );
      canvas.drawCircle(
        p,
        radius,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // Nom de la gare
      final tp = TextPainter(
        text: TextSpan(
          text: s.name,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: s.big ? 11 : 9,
            fontWeight: s.big ? FontWeight.bold : FontWeight.normal,
            shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(p.dx - tp.width / 2, p.dy + radius + 4));
    }
  }

  void _drawSmokeTrail(Canvas canvas, Size size) {
    const trailLength = 0.04;
    const puffs = 12;
    for (int i = 0; i < puffs; i++) {
      final t = i / puffs;
      final trailPos = (trainPosition - trailLength * t) % 1.0;
      final p = _ovalPoint(size, trailPos);
      final opacity = (1.0 - t) * 0.3;
      final radius = 3.0 + t * 5.0;
      canvas.drawCircle(
        Offset(p.dx, p.dy - 4 - t * 8),
        radius,
        Paint()
          ..color = Color.fromRGBO(180, 170, 160, opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.8),
      );
    }
  }

  void _drawTrain(Canvas canvas, Size size) {
    final p = _ovalPoint(size, trainPosition);
    final tangent = _ovalTangent(size, trainPosition);

    // Halo pulsant
    canvas.drawCircle(
      p,
      20,
      Paint()
        ..color = const Color(0x44FF6B00)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(tangent);

    // Corps
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-14, -6, 28, 12),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFD4440F),
    );
    // Cabine
    canvas.drawRect(
      const Rect.fromLTWH(-14, -6, 10, 12),
      Paint()..color = const Color(0xFF8B2500),
    );
    // Cheminée
    canvas.drawRect(
      const Rect.fromLTWH(8, -10, 4, 4),
      Paint()..color = const Color(0xFF2A2A2A),
    );
    // Roues
    final wp = Paint()..color = const Color(0xFF1A1A1A);
    canvas.drawCircle(const Offset(-8, 6), 3, wp);
    canvas.drawCircle(const Offset(0, 6), 3, wp);
    canvas.drawCircle(const Offset(8, 6), 3, wp);
    // Fenêtre cabine
    canvas.drawRect(
      const Rect.fromLTWH(-12, -4, 6, 6),
      Paint()..color = const Color(0xFFFFD080),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_MapOverlayPainter old) =>
      old.trainPosition != trainPosition;
}

class _TrainZoneHUD extends StatelessWidget {
  const _TrainZoneHUD({required this.displayPosition});
  final double displayPosition;

  @override
  Widget build(BuildContext context) {
    final zone = GameState.instance.trainZone;

    // Prochaine gare
    _Station? nextStation;
    double minDist = 2.0;
    for (final s in _stations) {
      double dist = s.position - displayPosition;
      if (dist < 0) dist += 1.0;
      if (dist < minDist) {
        minDist = dist;
        nextStation = s;
      }
    }
    final etaSeconds = (minDist * GameState.loopDurationSeconds).round();
    final etaMin = etaSeconds ~/ 60;
    final etaSec = etaSeconds % 60;

    String zoneLabel;
    IconData icon;
    Color color;
    switch (zone) {
      case TrainZone.cold:
        zoneLabel = 'Zone froide';
        icon = Icons.ac_unit;
        color = const Color(0xFF8BB8D0);
      case TrainZone.warm:
        zoneLabel = 'Zone tempérée';
        icon = Icons.wb_sunny;
        color = const Color(0xFFD4A55A);
      case TrainZone.transitionToCold:
        zoneLabel = 'Entrée zone froide';
        icon = Icons.ac_unit;
        color = const Color(0xFFA0B8C0);
      case TrainZone.transitionToWarm:
        zoneLabel = 'Sortie zone froide';
        icon = Icons.wb_sunny;
        color = const Color(0xFFC0A880);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            '$zoneLabel  •  ',
            style: TextStyle(color: color, fontSize: 13),
          ),
          const Icon(Icons.train, color: Colors.white70, size: 14),
          const SizedBox(width: 4),
          Text(
            '${nextStation?.name ?? "?"} — ${etaMin}m${etaSec.toString().padLeft(2, '0')}s',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
