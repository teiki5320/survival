import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../constants.dart';
import '../models/game_state.dart';

// ---------------------------------------------------------------------------
// Data — fixed track + stations that slide along the track
// ---------------------------------------------------------------------------

const List<Offset> _trackPoints = [
  Offset(0.239, 0.291),
  Offset(0.337, 0.248),
  Offset(0.492, 0.246),
  Offset(0.650, 0.246),
  Offset(0.769, 0.312),
  Offset(0.832, 0.433),
  Offset(0.826, 0.628),
  Offset(0.734, 0.738),
  Offset(0.642, 0.771),
  Offset(0.515, 0.778),
  Offset(0.370, 0.778),
  Offset(0.230, 0.725),
  Offset(0.160, 0.543),
  Offset(0.182, 0.387),
];

class _Station {
  _Station(this.name, this.t, {this.big = false, this.locationId});
  final String name;
  double t; // 0→1 position along the spline
  final bool big;
  final String? locationId;
}

final List<_Station> _stations = [
  _Station('Station abandonnée', 0.9887, big: true, locationId: 'station_abandonnee'),
  _Station('Halte 47', 0.0865),
  _Station('Dépôt ferroviaire', 0.1854, big: true, locationId: 'depot_ferroviaire'),
  _Station('Halte 12', 0.2143),
  _Station('Village fantôme', 0.2857, big: true, locationId: 'village_fantome'),
  _Station('Halte 83', 0.3467),
  _Station('Camp-refuge', 0.4024, locationId: 'camp_refuge'),
  _Station('Pont suspendu', 0.4631, locationId: 'pont_suspendu'),
  _Station('Halte 9', 0.5714),
  _Station('Oasis perdue', 0.6409, locationId: 'oasis_perdue'),
  _Station('Halte 31', 0.6771),
  _Station('Tour de guet', 0.7923, locationId: 'tour_de_guet'),
  _Station('Halte 6', 0.8571),
  _Station('Tunnel nord', 0.9286, locationId: 'tunnel_nord'),
];

// ---------------------------------------------------------------------------
// Catmull-Rom closed spline
// ---------------------------------------------------------------------------

Offset _catmullRom(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
  final t2 = t * t, t3 = t2 * t;
  return Offset(
    0.5 *
        ((2 * p1.dx) +
            (-p0.dx + p2.dx) * t +
            (2 * p0.dx - 5 * p1.dx + 4 * p2.dx - p3.dx) * t2 +
            (-p0.dx + 3 * p1.dx - 3 * p2.dx + p3.dx) * t3),
    0.5 *
        ((2 * p1.dy) +
            (-p0.dy + p2.dy) * t +
            (2 * p0.dy - 5 * p1.dy + 4 * p2.dy - p3.dy) * t2 +
            (-p0.dy + 3 * p1.dy - 3 * p2.dy + p3.dy) * t3),
  );
}

List<Offset> _buildSpline(List<Offset> pts, {int stepsPerSeg = 50}) {
  final n = pts.length;
  if (n < 2) return List.of(pts);
  final result = <Offset>[];
  for (int i = 0; i < n; i++) {
    final p0 = pts[(i - 1 + n) % n];
    final p1 = pts[i];
    final p2 = pts[(i + 1) % n];
    final p3 = pts[(i + 2) % n];
    for (int s = 0; s < stepsPerSeg; s++) {
      result.add(_catmullRom(p0, p1, p2, p3, s / stepsPerSeg));
    }
  }
  return result;
}

// ---------------------------------------------------------------------------
// Arc-length parameterized path (closed loop)
// ---------------------------------------------------------------------------

class _ArcPath {
  _ArcPath(this.points) {
    _cumLen = List<double>.filled(points.length, 0);
    for (int i = 1; i < points.length; i++) {
      _cumLen[i] = _cumLen[i - 1] + (points[i] - points[i - 1]).distance;
    }
    totalLen =
        _cumLen.isEmpty ? 0 : _cumLen.last + (points.first - points.last).distance;
  }

  final List<Offset> points;
  late final List<double> _cumLen;
  late final double totalLen;

  Offset at(double t) {
    if (points.isEmpty) return Offset.zero;
    final target = (t % 1.0) * totalLen;
    if (target <= 0) return points.first;
    if (target >= _cumLen.last) {
      final segLen = totalLen - _cumLen.last;
      if (segLen < 0.0001) return points.last;
      final frac = ((target - _cumLen.last) / segLen).clamp(0.0, 1.0);
      return Offset.lerp(points.last, points.first, frac)!;
    }
    int lo = 1, hi = points.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_cumLen[mid] < target) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final segLen = _cumLen[lo] - _cumLen[lo - 1];
    if (segLen < 0.0001) return points[lo];
    final frac = (target - _cumLen[lo - 1]) / segLen;
    return Offset.lerp(points[lo - 1], points[lo], frac)!;
  }

  double tangent(double t) {
    const dt = 0.001;
    final a = at(t - dt);
    final b = at(t + dt);
    return math.atan2(b.dy - a.dy, b.dx - a.dx);
  }

  double stationT(int i, int stationCount) {
    if (stationCount == 0 || points.isEmpty) return 0;
    final stepsPerSeg = points.length ~/ stationCount;
    final idx = (i * stepsPerSeg).clamp(0, points.length - 1);
    return totalLen > 0 ? _cumLen[idx] / totalLen : 0;
  }

  double closestT(Offset target, Size screenSize) {
    if (points.isEmpty) return 0;
    final tx = target.dx / screenSize.width;
    final ty = target.dy / screenSize.height;
    final norm = Offset(tx, ty);
    double bestDist = double.infinity;
    int bestIdx = 0;
    for (int i = 0; i < points.length; i++) {
      final d = (points[i] - norm).distanceSquared;
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    return totalLen > 0 ? _cumLen[bestIdx] / totalLen : 0;
  }
}

// ---------------------------------------------------------------------------
// MapScreen
// ---------------------------------------------------------------------------

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
  double _elapsed = 0;
  bool _stationAdjust = false;
  int? _dragIndex;
  late final _ArcPath _trackPath = _ArcPath(_buildSpline(_trackPoints));

  _ArcPath _getPath() => _trackPath;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final target = GameState.instance.trainPosition;
    final secs = elapsed.inMicroseconds / 1e6;
    setState(() {
      _displayPosition = target;
      _elapsed = secs;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _transformCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = _getPath();
    return Scaffold(
      backgroundColor: const Color(0xFF1A1410),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildMap(path),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'map_close',
                      tooltip: 'Retour au train',
                      backgroundColor: const Color(0xFFB85522),
                      foregroundColor: Colors.white,
                      onPressed: widget.onClose,
                      child: const Icon(Icons.close),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'map_adjust',
                      tooltip: 'Placer les gares',
                      backgroundColor: _stationAdjust
                          ? const Color(0xFFFF6B00)
                          : const Color(0xFF6A5A4A),
                      foregroundColor: Colors.white,
                      onPressed: () =>
                          setState(() => _stationAdjust = !_stationAdjust),
                      child: Icon(
                          _stationAdjust ? Icons.check : Icons.edit_location_alt),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _TrainZoneHUD(
                    path: path, displayPosition: _displayPosition),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(_ArcPath path) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mapW = constraints.maxWidth;
        final mapH = constraints.maxHeight;
        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/background/map_route.png',
                fit: BoxFit.fill,
                errorBuilder: (_, e, __) {
                  debugPrint('map_route.png load failed: $e');
                  return const ColoredBox(color: Color(0xFFB8945C));
                },
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _MapPainter(
                  path: path,
                  stations: _stations,
                  trainPosition: _displayPosition,
                  elapsed: _elapsed,
                  hideStationLabels: _stationAdjust,
                ),
              ),
            ),
            if (_stationAdjust) ...[
              for (int i = 0; i < _stations.length; i++)
                Builder(builder: (_) {
                  final s = _stations[i];
                  final pos = path.at(s.t);
                  final px = pos.dx * mapW;
                  final py = pos.dy * mapH;
                  return Positioned(
                    left: px - 16,
                    top: py - 16,
                    child: GestureDetector(
                      onPanStart: (_) => _dragIndex = i,
                      onPanUpdate: (d) {
                        setState(() {
                          final currentPos = path.at(s.t);
                          final newScreenX = currentPos.dx * mapW + d.delta.dx;
                          final newScreenY = currentPos.dy * mapH + d.delta.dy;
                          s.t = path.closestT(
                            Offset(newScreenX, newScreenY),
                            Size(mapW, mapH),
                          );
                        });
                      },
                      onPanEnd: (_) => _dragIndex = null,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _dragIndex == i
                              ? const Color(0xCCFF6B00)
                              : const Color(0x99D4A55A),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            s.big ? '★' : '•',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              Positioned(
                left: 12,
                top: 12,
                child: SafeArea(
                  child: IgnorePointer(
                    child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Placement gares',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        for (final s in _stations)
                          Text(
                            '${s.name.padRight(20)} t=${s.t.toStringAsFixed(4)}',
                            style: const TextStyle(
                              color: Color(0xFFFFD9A0),
                              fontSize: 10,
                              fontFamily: 'Courier',
                            ),
                          ),
                      ],
                    ),
                  ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Painter — track + stations + train + 8 animated layers
// ---------------------------------------------------------------------------

class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.path,
    required this.stations,
    required this.trainPosition,
    required this.elapsed,
    this.hideStationLabels = false,
  });

  final _ArcPath path;
  final List<_Station> stations;
  final double trainPosition;
  final double elapsed;
  final bool hideStationLabels;

  Offset _px(Offset norm, Size s) => Offset(norm.dx * s.width, norm.dy * s.height);

  @override
  void paint(Canvas canvas, Size size) {
    _drawShadowSilhouettes(canvas, size);

    if (!hideStationLabels) _drawStations(canvas, size);
    _drawSmokeTrail(canvas, size);
    _drawTrain(canvas, size);
  }

  // ---- Stations ----

  void _drawStations(Canvas canvas, Size size) {
    for (final s in stations) {
      final p = _px(path.at(s.t), size);
      final unlocked = s.locationId != null &&
          GameState.instance.isLocationUnlocked(s.locationId!);
      final radius = s.big ? 10.0 : 6.0;

      canvas.drawCircle(p, radius + 2, Paint()..color = const Color(0x44000000));
      canvas.drawCircle(
        p,
        radius,
        Paint()
          ..color =
              unlocked ? const Color(0xFFD4A55A) : const Color(0xFF6A6A6A),
      );
      canvas.drawCircle(
        p,
        radius,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: s.name,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: s.big ? 13 : 11,
            fontWeight: s.big ? FontWeight.bold : FontWeight.normal,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 4),
              Shadow(color: Colors.black, blurRadius: 8),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelAbove = p.dy > size.height * 0.55;
      final labelY = labelAbove
          ? p.dy - radius - 4 - tp.height
          : p.dy + radius + 4;
      tp.paint(canvas, Offset(p.dx - tp.width / 2, labelY));
    }
  }

  // ---- Train + smoke ----

  void _drawSmokeTrail(Canvas canvas, Size size) {
    const trailLength = 0.04;
    const puffs = 12;
    for (int i = 0; i < puffs; i++) {
      final t = i / puffs;
      final trailPos = (trainPosition - trailLength * t) % 1.0;
      final p = _px(path.at(trailPos), size);
      final opacity = (1.0 - t) * 0.3;
      final r = 3.0 + t * 5.0;
      canvas.drawCircle(
        Offset(p.dx, p.dy - 4 - t * 8),
        r,
        Paint()
          ..color = Color.fromRGBO(180, 170, 160, opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.8),
      );
    }
  }

  void _drawTrain(Canvas canvas, Size size) {
    final p = _px(path.at(trainPosition), size);

    canvas.drawCircle(
      p,
      20,
      Paint()
        ..color = const Color(0x55FF6B00)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    final tp = TextPainter(
      text: const TextSpan(
        text: '🚂',
        style: TextStyle(fontSize: 26),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(p.dx - tp.width / 2, p.dy - tp.height / 2));
  }

  // ===========================================================================
  // Shadow silhouettes — zombies (cold zone) + animals (warm zone)
  // ===========================================================================

  void _drawShadowSilhouettes(Canvas canvas, Size size) {
    final t = elapsed;
    _drawZombieSilhouettes(canvas, size, t);
    _drawAnimalSilhouettes(canvas, size, t);
  }

  void _drawZombieSilhouettes(Canvas canvas, Size size, double t) {
    for (int i = 0; i < 6; i++) {
      final seed = i * 127.0;
      final speed = 0.012 + (seed * 0.17 % 0.008);
      final x = ((seed * 0.41 + t * speed) % 1.4) - 0.2;
      final baseY = 0.32 + (seed * 0.23 % 0.12);
      final h = 14.0 + (seed % 8);
      final px = x * size.width;
      final py = baseY * size.height;
      final opacity = 0.15 + (seed * 0.11 % 0.15);

      // Bob up/down while walking
      final bob = math.sin(t * 2.5 + seed) * 1.5;
      // Lean slightly
      final lean = math.sin(t * 1.2 + seed * 0.7) * 0.08;

      final paint = Paint()
        ..color = Color.fromRGBO(20, 20, 30, opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

      canvas.save();
      canvas.translate(px, py + bob);
      canvas.skew(lean, 0);

      // Head
      canvas.drawCircle(Offset(0, -h), h * 0.2, paint);
      // Body
      canvas.drawLine(Offset(0, -h + h * 0.2), Offset(0, -h * 0.35), paint..strokeWidth = 2.5);
      // Arms (asymmetric, one drooping)
      final armSway = math.sin(t * 2.0 + seed) * 3;
      canvas.drawLine(Offset(0, -h * 0.7), Offset(-5 + armSway, -h * 0.35), paint);
      canvas.drawLine(Offset(0, -h * 0.7), Offset(6, -h * 0.2), paint);
      // Legs (shuffling)
      final legPhase = math.sin(t * 3.0 + seed) * 2.5;
      canvas.drawLine(Offset(0, -h * 0.35), Offset(-3 + legPhase, 0), paint);
      canvas.drawLine(Offset(0, -h * 0.35), Offset(3 - legPhase, 0), paint);

      canvas.restore();
    }
  }

  void _drawAnimalSilhouettes(Canvas canvas, Size size, double t) {
    // Wolves — 3, prowling across the warm zone
    for (int i = 0; i < 3; i++) {
      final seed = i * 193.0;
      final speed = 0.018 + (seed * 0.13 % 0.01);
      final facingLeft = i.isEven;
      final rawX = (seed * 0.37 + t * speed) % 1.4;
      final x = facingLeft ? 1.2 - rawX : rawX - 0.2;
      final baseY = 0.62 + (seed * 0.19 % 0.12);
      final px = x * size.width;
      final py = baseY * size.height;
      final opacity = 0.18 + (seed * 0.11 % 0.12);
      final dir = facingLeft ? -1.0 : 1.0;

      final paint = Paint()
        ..color = Color.fromRGBO(30, 20, 15, opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;

      // Trot animation
      final legF = math.sin(t * 4.0 + seed) * 3;
      final legB = math.sin(t * 4.0 + seed + math.pi) * 3;
      final headBob = math.sin(t * 2.0 + seed) * 1;

      canvas.save();
      canvas.translate(px, py);

      // Body line
      canvas.drawLine(Offset(-10 * dir, 0), Offset(10 * dir, -1 + headBob), paint);
      // Head
      canvas.drawCircle(Offset(12 * dir, -3 + headBob), 3, paint);
      // Ears
      canvas.drawLine(Offset(11 * dir, -3 + headBob), Offset(10 * dir, -7 + headBob), paint..strokeWidth = 1.5);
      canvas.drawLine(Offset(13 * dir, -3 + headBob), Offset(14 * dir, -7 + headBob), paint);
      // Front legs
      paint.strokeWidth = 1.8;
      canvas.drawLine(Offset(6 * dir, 0), Offset(6 * dir + legF * dir * 0.3, 6), paint);
      canvas.drawLine(Offset(8 * dir, 0), Offset(8 * dir - legF * dir * 0.3, 6), paint);
      // Back legs
      canvas.drawLine(Offset(-6 * dir, 0), Offset(-6 * dir + legB * dir * 0.3, 6), paint);
      canvas.drawLine(Offset(-8 * dir, 0), Offset(-8 * dir - legB * dir * 0.3, 6), paint);
      // Tail
      final tailWag = math.sin(t * 3.0 + seed) * 2;
      canvas.drawLine(Offset(-10 * dir, -1), Offset(-15 * dir, -4 + tailWag),
          paint..strokeWidth = 1.5);

      canvas.restore();
    }

    // Rats — 4, scurrying fast
    for (int i = 0; i < 4; i++) {
      final seed = i * 83.0 + 500;
      final speed = 0.04 + (seed * 0.11 % 0.02);
      final x = ((seed * 0.43 + t * speed) % 1.6) - 0.3;
      final baseY = 0.55 + (seed * 0.31 % 0.25);
      final px = x * size.width;
      final py = baseY * size.height;
      final opacity = 0.12 + (seed * 0.07 % 0.1);

      final paint = Paint()
        ..color = Color.fromRGBO(25, 20, 20, opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8);

      // Tiny body
      canvas.drawOval(
        Rect.fromCenter(center: Offset(px, py), width: 6, height: 3),
        paint,
      );
      // Tail
      final tailCurve = math.sin(t * 10 + seed) * 2;
      canvas.drawLine(
        Offset(px - 3, py),
        Offset(px - 8, py - 1 + tailCurve),
        paint..strokeWidth = 0.8,
      );
    }

    // Crows — 5, circling in the sky
    for (int i = 0; i < 5; i++) {
      final seed = i * 67.0 + 300;
      final cx = 0.25 + (seed * 0.23 % 0.50);
      final cy = 0.15 + (seed * 0.17 % 0.12);
      final radius = 0.04 + (seed * 0.11 % 0.03);
      final angle = t * (0.3 + i * 0.1) + seed;
      final x = (cx + math.cos(angle) * radius) * size.width;
      final y = (cy + math.sin(angle) * radius * 0.4) * size.height;
      final wingPhase = math.sin(t * 6 + seed) * 3;
      final opacity = 0.2 + (seed * 0.07 % 0.15);

      final birdPath = Path()
        ..moveTo(x - 5, y + wingPhase)
        ..lineTo(x, y)
        ..lineTo(x + 5, y + wingPhase);
      canvas.drawPath(
        birdPath,
        Paint()
          ..color = Color.fromRGBO(15, 15, 20, opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_MapPainter old) => true;
}

// ---------------------------------------------------------------------------
// HUD
// ---------------------------------------------------------------------------

class _TrainZoneHUD extends StatelessWidget {
  const _TrainZoneHUD({required this.path, required this.displayPosition});
  final _ArcPath path;
  final double displayPosition;

  @override
  Widget build(BuildContext context) {
    final zone = GameState.instance.trainZone;

    _Station? nextStation;
    double minDist = 2.0;
    for (final s in _stations) {
      double dist = s.t - displayPosition;
      if (dist < 0) dist += 1.0;
      if (dist < minDist) {
        minDist = dist;
        nextStation = s;
      }
    }
    final etaSeconds = (minDist * kLoopDurationSeconds).round();
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
          Text('$zoneLabel  •  ',
              style: TextStyle(color: color, fontSize: 13)),
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
