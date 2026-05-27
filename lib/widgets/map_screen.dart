import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../constants.dart';
import '../models/game_state.dart';

// ---------------------------------------------------------------------------
// Data — stations with free (x, y) placement
// ---------------------------------------------------------------------------

class _Station {
  _Station(this.name, this.x, this.y, {this.big = false, this.locationId});
  final String name;
  double x;
  double y;
  final bool big;
  final String? locationId;
}

final List<_Station> _stations = [
  _Station('Station abandonnée', 0.264, 0.372,
      big: true, locationId: 'station_abandonnee'),
  _Station('Halte 47', 0.374, 0.350),
  _Station('Dépôt ferroviaire', 0.479, 0.354,
      big: true, locationId: 'depot_ferroviaire'),
  _Station('Halte 12', 0.625, 0.356),
  _Station('Village fantôme', 0.737, 0.377,
      big: true, locationId: 'village_fantome'),
  _Station('Halte 83', 0.816, 0.427),
  _Station('Camp-refuge', 0.836, 0.531, locationId: 'camp_refuge'),
  _Station('Pont suspendu', 0.762, 0.630, locationId: 'pont_suspendu'),
  _Station('Halte 9', 0.656, 0.656),
  _Station('Oasis perdue', 0.523, 0.659, locationId: 'oasis_perdue'),
  _Station('Halte 31', 0.396, 0.660),
  _Station('Tour de guet', 0.271, 0.642, locationId: 'tour_de_guet'),
  _Station('Halte 6', 0.163, 0.547),
  _Station('Tunnel nord', 0.178, 0.438, locationId: 'tunnel_nord'),
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

List<Offset> _buildSpline(List<_Station> stations, {int stepsPerSeg = 50}) {
  final n = stations.length;
  if (n < 2) return stations.map((s) => Offset(s.x, s.y)).toList();
  final pts = stations.map((s) => Offset(s.x, s.y)).toList();
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
  _ArcPath? _cachedPath;

  _ArcPath _getPath() {
    _cachedPath ??= _ArcPath(_buildSpline(_stations));
    return _cachedPath!;
  }

  void _invalidatePath() => _cachedPath = null;

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
                  final px = s.x * mapW;
                  final py = s.y * mapH;
                  return Positioned(
                    left: px - 22,
                    top: py - 22,
                    child: GestureDetector(
                      onPanStart: (_) => _dragIndex = i,
                      onPanUpdate: (d) {
                        setState(() {
                          s.x = ((s.x * mapW + d.delta.dx) / mapW)
                              .clamp(0.02, 0.98);
                          s.y = ((s.y * mapH + d.delta.dy) / mapH)
                              .clamp(0.02, 0.98);
                          _invalidatePath();
                        });
                      },
                      onPanEnd: (_) => _dragIndex = null,
                      child: Container(
                        width: 44,
                        height: 44,
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
                            '${s.name.padRight(20)} (${s.x.toStringAsFixed(3)}, ${s.y.toStringAsFixed(3)})',
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
    // Shadow silhouettes behind track
    _drawShadowSilhouettes(canvas, size);

    // Track
    _drawTrack(canvas, size);

    // Stations + train
    if (!hideStationLabels) _drawStations(canvas, size);
    _drawSmokeTrail(canvas, size);
    _drawTrain(canvas, size);
  }

  // ---- Track (spline rails) ----

  void _drawTrack(Canvas canvas, Size size) {
    if (path.points.length < 2) return;
    final trackPath = Path();
    final first = _px(path.points.first, size);
    trackPath.moveTo(first.dx, first.dy);
    for (int i = 1; i < path.points.length; i++) {
      final p = _px(path.points[i], size);
      trackPath.lineTo(p.dx, p.dy);
    }
    trackPath.close();

    // Rail bed shadow
    canvas.drawPath(
      trackPath,
      Paint()
        ..color = const Color(0x44000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    // Rail bed (bois)
    canvas.drawPath(
      trackPath,
      Paint()
        ..color = const Color(0xFF6B4226)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    // Rails
    canvas.drawPath(
      trackPath,
      Paint()
        ..color = const Color(0xFF8B6914)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Ties
    final tieCount = 100;
    final tiePaint = Paint()
      ..color = const Color(0xFF4A3520)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < tieCount; i++) {
      final t = i / tieCount;
      final p = _px(path.at(t), size);
      final angle = path.tangent(t);
      final perpX = math.cos(angle + math.pi / 2) * 6;
      final perpY = math.sin(angle + math.pi / 2) * 6;
      canvas.drawLine(
        Offset(p.dx - perpX, p.dy - perpY),
        Offset(p.dx + perpX, p.dy + perpY),
        tiePaint,
      );
    }
  }

  // ---- Stations ----

  void _drawStations(Canvas canvas, Size size) {
    for (final s in stations) {
      final p = _px(Offset(s.x, s.y), size);
      final unlocked = s.locationId != null &&
          GameState.instance.isLocationUnlocked(s.locationId!);
      final radius = s.big ? 8.0 : 5.0;

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
    final tangent = path.tangent(trainPosition);

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

    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-14, -6, 28, 12), const Radius.circular(3)),
      Paint()..color = const Color(0xFFD4440F),
    );
    canvas.drawRect(
        const Rect.fromLTWH(-14, -6, 10, 12), Paint()..color = const Color(0xFF8B2500));
    canvas.drawRect(
        const Rect.fromLTWH(8, -10, 4, 4), Paint()..color = const Color(0xFF2A2A2A));
    final wp = Paint()..color = const Color(0xFF1A1A1A);
    canvas.drawCircle(const Offset(-8, 6), 3, wp);
    canvas.drawCircle(const Offset(0, 6), 3, wp);
    canvas.drawCircle(const Offset(8, 6), 3, wp);
    canvas.drawRect(
        const Rect.fromLTWH(-12, -4, 6, 6), Paint()..color = const Color(0xFFFFD080));

    canvas.restore();
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
    // 6 zombies shambling across the cold zone (top half)
    for (int i = 0; i < 6; i++) {
      final seed = i * 127.0;
      final speed = 0.012 + (seed * 0.17 % 0.008);
      final x = ((seed * 0.41 + t * speed) % 1.4) - 0.2;
      final baseY = 0.12 + (seed * 0.23 % 0.22);
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
      final baseY = 0.58 + (seed * 0.19 % 0.22);
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
      final baseY = 0.42 + (seed * 0.31 % 0.45);
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
      final cx = 0.15 + (seed * 0.23 % 0.70);
      final cy = 0.08 + (seed * 0.17 % 0.20);
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
    for (int i = 0; i < _stations.length; i++) {
      final stationT = path.stationT(i, _stations.length);
      double dist = stationT - displayPosition;
      if (dist < 0) dist += 1.0;
      if (dist < minDist) {
        minDist = dist;
        nextStation = _stations[i];
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
