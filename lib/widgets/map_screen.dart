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
  _Station('Station abandonnée', 0.19, 0.22,
      big: true, locationId: 'station_abandonnee'),
  _Station('Halte 47', 0.35, 0.13),
  _Station('Dépôt ferroviaire', 0.56, 0.12,
      big: true, locationId: 'depot_ferroviaire'),
  _Station('Halte 12', 0.78, 0.25),
  _Station('Village fantôme', 0.87, 0.48,
      big: true, locationId: 'village_fantome'),
  _Station('Halte 83', 0.78, 0.72),
  _Station('Camp-refuge', 0.50, 0.82, locationId: 'camp_refuge'),
  _Station('Pont suspendu', 0.22, 0.72, locationId: 'pont_suspendu'),
  _Station('Halte 9', 0.12, 0.45),
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
          _stationAdjust
              ? _buildAdjustableMap(path)
              : InteractiveViewer(
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
                            painter: _MapPainter(
                              path: path,
                              stations: _stations,
                              trainPosition: _displayPosition,
                              elapsed: _elapsed,
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

  Widget _buildAdjustableMap(_ArcPath path) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mapW = constraints.maxWidth;
        final mapH = constraints.maxHeight;
        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/background/map_route.png',
                fit: BoxFit.contain,
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _MapPainter(
                  path: path,
                  stations: _stations,
                  trainPosition: _displayPosition,
                  elapsed: _elapsed,
                  hideStationLabels: true,
                ),
              ),
            ),
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
    // Background animations (behind track)
    _drawDriftingClouds(canvas, size);
    _drawSnowfall(canvas, size);
    _drawDustParticles(canvas, size);
    _drawRuinSmoke(canvas, size);
    _drawWaterWaves(canvas, size);
    _drawWindVegetation(canvas, size);

    // Track
    _drawTrack(canvas, size);

    // Foreground animations
    _drawBirds(canvas, size);
    _drawFireGlows(canvas, size);

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
        ..color = const Color(0x33000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    // Rail bed
    canvas.drawPath(
      trackPath,
      Paint()
        ..color = const Color(0xFF7A6548)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    // Rails
    canvas.drawPath(
      trackPath,
      Paint()
        ..color = const Color(0xFFAA9070)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Ties
    final tieCount = 80;
    final tiePaint = Paint()
      ..color = const Color(0xFF5A4A38)
      ..strokeWidth = 2.5
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
  // 8 animated background layers
  // ===========================================================================

  // 1. Drifting clouds — cold zone (top)
  void _drawDriftingClouds(Canvas canvas, Size size) {
    final t = elapsed;
    for (int i = 0; i < 6; i++) {
      final seed = i * 137.0;
      final baseX = ((seed * 0.37 + t * (0.008 + i * 0.003)) % 1.3) - 0.15;
      final baseY = 0.05 + (seed * 0.23 % 0.25);
      final w = 0.08 + (seed * 0.17 % 0.06);
      final h = 0.03 + (seed * 0.13 % 0.02);
      final opacity = 0.08 + (seed * 0.11 % 0.07);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(baseX * size.width, baseY * size.height),
          width: w * size.width,
          height: h * size.height,
        ),
        Paint()
          ..color = Color.fromRGBO(200, 210, 220, opacity)
          ..maskFilter =
              MaskFilter.blur(BlurStyle.normal, h * size.height * 0.8),
      );
    }
  }

  // 2. Snowfall — cold zone (y < 0.40)
  void _drawSnowfall(Canvas canvas, Size size) {
    final t = elapsed;
    for (int i = 0; i < 40; i++) {
      final seed = i * 73.0;
      final x = (seed * 0.41 + t * 0.01 * (1 + (seed % 3))) % 1.0;
      final y = (seed * 0.29 + t * 0.03 * (1 + (seed % 2) * 0.5)) % 0.40;
      final r = 1.0 + (seed % 3);
      final opacity = 0.3 + (seed * 0.17 % 0.3);
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        r,
        Paint()..color = Color.fromRGBO(240, 245, 255, opacity),
      );
    }
  }

  // 3. Dust / sand — warm zone (y > 0.55)
  void _drawDustParticles(Canvas canvas, Size size) {
    final t = elapsed;
    for (int i = 0; i < 30; i++) {
      final seed = i * 97.0;
      final x = (seed * 0.37 + t * 0.02 * (1 + seed % 4)) % 1.0;
      final y = 0.55 + (seed * 0.31 % 0.35);
      final r = 0.5 + (seed % 2);
      final opacity = 0.15 + (seed * 0.13 % 0.15);
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        r,
        Paint()..color = Color.fromRGBO(180, 160, 120, opacity),
      );
    }
  }

  // 4. Ruin smoke — rising from factory/ruin locations
  static const _ruinPoints = [
    Offset(0.35, 0.20),
    Offset(0.48, 0.15),
    Offset(0.62, 0.18),
    Offset(0.75, 0.22),
    Offset(0.30, 0.28),
  ];

  void _drawRuinSmoke(Canvas canvas, Size size) {
    final t = elapsed;
    for (int r = 0; r < _ruinPoints.length; r++) {
      final base = _ruinPoints[r];
      for (int p = 0; p < 5; p++) {
        final seed = r * 51.0 + p * 17.0;
        final phase = seed * 0.73;
        final life = ((t * 0.3 + phase) % 3.0) / 3.0;
        final x = base.dx + math.sin(t * 0.5 + seed) * 0.01;
        final y = base.dy - life * 0.06;
        final radius = 2.0 + life * 4.0;
        final opacity = (1.0 - life) * 0.2;
        canvas.drawCircle(
          Offset(x * size.width, y * size.height),
          radius,
          Paint()
            ..color = Color.fromRGBO(140, 130, 120, opacity)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.7),
        );
      }
    }
  }

  // 5. Birds / crows circling
  static const _flockCenters = [
    Offset(0.40, 0.18),
    Offset(0.65, 0.15),
    Offset(0.55, 0.22),
  ];

  void _drawBirds(Canvas canvas, Size size) {
    final t = elapsed;
    for (int f = 0; f < _flockCenters.length; f++) {
      final center = _flockCenters[f];
      for (int b = 0; b < 4; b++) {
        final seed = f * 37.0 + b * 19.0;
        final angle = t * 0.4 + seed;
        final radius = 0.03 + (seed * 0.11 % 0.02);
        final x = center.dx + math.cos(angle) * radius;
        final y = center.dy + math.sin(angle) * radius * 0.5;
        final px = x * size.width;
        final py = y * size.height;
        final wingPhase = math.sin(t * 8 + seed) * 2;
        final birdPath = Path()
          ..moveTo(px - 4, py + wingPhase)
          ..lineTo(px, py)
          ..lineTo(px + 4, py + wingPhase);
        canvas.drawPath(
          birdPath,
          Paint()
            ..color = const Color(0xAA2A2A2A)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  // 6. Fire glows — pulsing orange in ruins
  static const _firePoints = [
    Offset(0.38, 0.26),
    Offset(0.52, 0.18),
    Offset(0.70, 0.24),
    Offset(0.25, 0.62),
    Offset(0.72, 0.67),
    Offset(0.58, 0.75),
  ];

  void _drawFireGlows(Canvas canvas, Size size) {
    final t = elapsed;
    for (int i = 0; i < _firePoints.length; i++) {
      final pos = _firePoints[i];
      final pulse = 0.5 + 0.5 * math.sin(t * 2.5 + i * 1.7);
      final r = 3.0 + pulse * 3.0;
      final p = Offset(pos.dx * size.width, pos.dy * size.height);
      canvas.drawCircle(
        p,
        r * 2.5,
        Paint()
          ..color = Color.fromRGBO(255, 120, 30, 0.08 + pulse * 0.06)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 2),
      );
      canvas.drawCircle(
        p,
        r,
        Paint()..color = Color.fromRGBO(255, 160, 50, 0.3 + pulse * 0.3),
      );
    }
  }

  // 7. Water waves — bottom-right area
  void _drawWaterWaves(Canvas canvas, Size size) {
    final t = elapsed;
    for (int i = 0; i < 8; i++) {
      final seed = i * 53.0;
      final baseX = 0.82 + (seed * 0.17 % 0.14);
      final baseY = 0.72 + (seed * 0.23 % 0.15);
      final wave = math.sin(t * 1.5 + seed * 0.5) * 0.005;
      final px = (baseX + wave) * size.width;
      final py = baseY * size.height;
      final waveLen = 8.0 + (seed % 5);
      final wavePath = Path();
      for (double dx = -waveLen; dx <= waveLen; dx += 1) {
        final wy = math.sin((dx + t * 20) * 0.3 + seed) * 1.5;
        if (dx == -waveLen) {
          wavePath.moveTo(px + dx, py + wy);
        } else {
          wavePath.lineTo(px + dx, py + wy);
        }
      }
      canvas.drawPath(
        wavePath,
        Paint()
          ..color = Color.fromRGBO(130, 170, 200, 0.2 + (seed * 0.11 % 0.15))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }
  }

  // 8. Wind in vegetation — warm zone swaying grass
  static const _vegPoints = [
    Offset(0.15, 0.65),
    Offset(0.30, 0.75),
    Offset(0.45, 0.80),
    Offset(0.60, 0.78),
    Offset(0.10, 0.55),
    Offset(0.85, 0.60),
  ];

  void _drawWindVegetation(Canvas canvas, Size size) {
    final t = elapsed;
    for (int i = 0; i < _vegPoints.length; i++) {
      final pos = _vegPoints[i];
      final px = pos.dx * size.width;
      final py = pos.dy * size.height;
      final sway = math.sin(t * 1.2 + i * 2.1) * 3;
      final sway2 = math.sin(t * 0.8 + i * 1.3) * 2;
      for (int b = 0; b < 5; b++) {
        final bx = px + (b - 2) * 4.0;
        final tipX = bx + sway + (b.isEven ? sway2 : -sway2);
        final blade = Path()
          ..moveTo(bx, py)
          ..quadraticBezierTo(
              tipX, py - 8, tipX + sway * 0.3, py - 14 - b % 3 * 2);
        canvas.drawPath(
          blade,
          Paint()
            ..color = Color.fromRGBO(80 + b * 10, 110 + b * 8, 60, 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..strokeCap = StrokeCap.round,
        );
      }
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
