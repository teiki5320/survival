import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../constants.dart';
import '../models/game_state.dart';
import 'stat_rings.dart';

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
  _Station(this.name, this.t, {this.big = false});
  final String name;
  double t; // 0→1 position along the spline
  final bool big;
}

// Positions (t) tirées de kGarePositions (constants.dart) : source unique de
// vérité partagée avec le moteur de cartes, pour que carte et run ne dérivent
// jamais. Ici on n'ajoute que les noms / le type (big).
// Noms de gares japonisants (ordre du voyage, escalade vers le grand froid).
final List<_Station> _stations = [
  // Ordre THÉMATIQUE : chaque nom colle à sa scène narrative (synchro avec les
  // speakers de cards_data._gareN).
  _Station('Kogarashi', kGarePositions[0], big: true),
  _Station('Kurogane', kGarePositions[1], big: true),
  _Station('Karasuno', kGarePositions[2]),
  _Station('Mayoidani', kGarePositions[3], big: true),
  _Station('Tsukibashi', kGarePositions[4]),
  _Station('Yasuragi', kGarePositions[5]),
  _Station('Hoshikage', kGarePositions[6]),
  _Station('Kiribe', kGarePositions[7]),
  _Station('Shizuhara', kGarePositions[8]),
  _Station('Hidamari', kGarePositions[9]),
  _Station('Yukihara', kGarePositions[10]),
  _Station('Miharashi', kGarePositions[11]),
  _Station('Fubuki', kGarePositions[12]),
  _Station('Hokuto', kGarePositions[13]),
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
  const MapScreen({
    super.key,
    required this.onClose,
    this.onOpenCards,
  });
  final VoidCallback onClose;

  /// Ouvre les CARTES narratives (le voyage). C'est LE point d'entrée du
  /// voyage depuis la map ("Débuter/Continuer le voyage").
  final VoidCallback? onOpenCards;

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
    // La position cible bouge maintenant par paliers (gare → gare). On glisse
    // le train en douceur vers elle, par le plus court chemin sur le cercle
    // (gère le wrap 1.0 → 0.0 de la boucle).
    var diff = (target - _displayPosition) % 1.0;
    if (diff > 0.5) diff -= 1.0;
    if (diff < -0.5) diff += 1.0;
    setState(() {
      var p = _displayPosition + diff * 0.06;
      p %= 1.0;
      if (p < 0) p += 1.0;
      _displayPosition = p;
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
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MapIconButton(
                      icon: Icons.close,
                      tooltip: 'Retour au train',
                      onTap: widget.onClose,
                    ),
                    // Placement des gares = outil de réglage : MODE DEBUG only.
                    if (GameState.instance.debugMode) ...[
                      const SizedBox(height: 10),
                      _MapIconButton(
                        icon: _stationAdjust
                            ? Icons.check
                            : Icons.edit_location_alt,
                        tooltip: 'Placer les gares',
                        active: _stationAdjust,
                        onTap: () =>
                            setState(() => _stationAdjust = !_stationAdjust),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // Action principale : AU CENTRE de l'image.
          if (widget.onOpenCards != null)
            Center(
              child: _ContinueJourneyButton(
                onTap: widget.onOpenCards!,
                // « Débuter » tant que le voyage n'a pas commencé, sinon
                // « Continuer ».
                label: (GameState.instance.cardGareIndex ?? 0) > 0
                    ? 'Continuer le voyage'
                    : 'Débuter le voyage',
              ),
            ),
          // HUD de zone : tout en bas (un peu plus bas qu'avant).
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _TrainZoneHUD(
                    path: path, displayPosition: _displayPosition),
              ),
            ),
          ),
          // Les 4 jauges + réserve de bois, pour décider AVANT d'entrer dans
          // le froid (visible seulement pendant une run).
          if (GameState.instance.hasCardRun)
            const SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: _MapStatsBar(),
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
    // Silhouettes animées (zombies/animaux) retirées : map statique.
    if (!hideStationLabels) _drawStations(canvas, size);
    _drawSmokeTrail(canvas, size);
    _drawTrain(canvas, size);
  }

  // ---- Stations ----

  void _drawStations(Canvas canvas, Size size) {
    for (var i = 0; i < stations.length; i++) {
      final s = stations[i];
      final p = _px(path.at(s.t), size);
      // Gare DORÉE = déjà atteinte dans la run (progression réelle du voyage) ;
      // grise = encore devant. Remplace l'ancien système `_unlocked` mort.
      final gs = GameState.instance;
      final reached = gs.hasCardRun && i <= (gs.cardGareIndex ?? 0);
      final radius = s.big ? 10.0 : 6.0;

      canvas.drawCircle(p, radius + 2, Paint()..color = const Color(0x44000000));
      canvas.drawCircle(
        p,
        radius,
        Paint()
          ..color =
              reached ? const Color(0xFFD4A55A) : const Color(0xFF6A6A6A),
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
    final tangent = path.tangent(trainPosition);

    // Smoke puffs trailing behind the train.
    for (int i = 0; i < 5; i++) {
      final age = i / 5.0;
      final puffPos = _px(path.at(trainPosition - 0.012 * (i + 1)), size);
      final r = 2.5 + age * 4.0;
      final opacity = (1.0 - age) * 0.35;
      canvas.drawCircle(
        Offset(puffPos.dx, puffPos.dy - 4 - age * 6),
        r,
        Paint()
          ..color = Color.fromRGBO(90, 75, 60, opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.7),
      );
    }

    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(tangent);

    // Wash shadow under the whole train.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-3, 5), width: 38, height: 5),
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    final ink = Paint()
      ..color = const Color(0xFF2A1A0E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    final wheel = Paint()..color = const Color(0xFF2A1A0E);

    // === Wagon (behind, left side) ===
    final wagonBody = Path()
      ..addRRect(RRect.fromRectAndRadius(
        const Rect.fromLTWH(-19, -4, 14, 6),
        const Radius.circular(1),
      ));
    canvas.drawPath(
      wagonBody,
      Paint()..color = const Color(0xFF6B5536),
    );
    // Wagon roof.
    canvas.drawRect(
      const Rect.fromLTWH(-19, -5, 14, 1.5),
      Paint()..color = const Color(0xFF2E1F12),
    );
    // Wagon windows.
    final win = Paint()..color = const Color(0xFFF0DDB0);
    canvas.drawRect(const Rect.fromLTWH(-17.5, -3, 2.5, 2.5), win);
    canvas.drawRect(const Rect.fromLTWH(-13.5, -3, 2.5, 2.5), win);
    canvas.drawRect(const Rect.fromLTWH(-9.5, -3, 2.5, 2.5), win);
    // Wagon wheels.
    canvas.drawCircle(const Offset(-16, 3), 1.6, wheel);
    canvas.drawCircle(const Offset(-8, 3), 1.6, wheel);
    canvas.drawPath(wagonBody, ink);

    // === Coupling between wagon and locomotive ===
    canvas.drawRect(
      const Rect.fromLTWH(-5, -0.5, 2, 1),
      Paint()..color = const Color(0xFF2A1A0E),
    );

    // === Locomotive (front, right side) ===
    // Cabin (back of loco).
    final cabin = Path()
      ..addRRect(RRect.fromRectAndRadius(
        const Rect.fromLTWH(-3, -7, 6, 9),
        const Radius.circular(1),
      ));
    canvas.drawPath(cabin, Paint()..color = const Color(0xFF8B3A1A));
    // Cabin window.
    canvas.drawRect(const Rect.fromLTWH(-2, -5.5, 4, 3), win);
    canvas.drawPath(cabin, ink);

    // Boiler (front of loco).
    final boiler = Path()
      ..addRRect(RRect.fromRectAndRadius(
        const Rect.fromLTWH(3, -4, 9, 6),
        const Radius.circular(2),
      ));
    canvas.drawPath(boiler, Paint()..color = const Color(0xFFB8451A));
    canvas.drawPath(boiler, ink);
    // Boiler band.
    canvas.drawRect(
      const Rect.fromLTWH(7, -4, 1, 6),
      Paint()..color = const Color(0xFF3A2010),
    );
    // Headlight.
    canvas.drawCircle(
      const Offset(12, -1),
      1.2,
      Paint()..color = const Color(0xFFFFD680),
    );

    // Smokestack on top of boiler.
    canvas.drawRect(
      const Rect.fromLTWH(8.5, -8, 2.5, 4),
      Paint()..color = const Color(0xFF3A2010),
    );
    // Smokestack rim.
    canvas.drawRect(
      const Rect.fromLTWH(8, -8.5, 3.5, 0.8),
      Paint()..color = const Color(0xFF2A1A0E),
    );

    // Locomotive wheels — bigger than wagon wheels.
    canvas.drawCircle(const Offset(4, 3), 2.0, wheel);
    canvas.drawCircle(const Offset(10, 3), 2.0, wheel);

    canvas.restore();
  }


  @override
  bool shouldRepaint(_MapPainter old) => true;
}

// ---------------------------------------------------------------------------
// HUD
// ---------------------------------------------------------------------------

/// Barre des 4 jauges (anneaux unifiés), en haut de la carte.
class _MapStatsBar extends StatelessWidget {
  const _MapStatsBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const StatRingsBar(
        ringSize: 34,
        emojiSize: 15,
        mainAxisSize: MainAxisSize.min,
      ),
    );
  }
}

/// FAB "Atelier & Quotidien" avec une pastille verte quand un coffre ou une
/// mission journalière est réclamable (incitation à revenir).
/// Bouton rond cohérent du menu map (parchemin sombre + liseré ambré).
class _MapIconButton extends StatelessWidget {
  const _MapIconButton(
      {required this.icon, required this.onTap, this.tooltip, this.active = false});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: active ? const Color(0xFFD9A05B) : const Color(0xE62A2018),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFD9A05B), width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8)],
        ),
        child: Icon(icon,
            color: active ? const Color(0xFF2A2018) : const Color(0xFFEAD8B6),
            size: 22),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

/// Gros bouton d'action principal de la map : ouvrir les cartes du voyage.
class _ContinueJourneyButton extends StatelessWidget {
  const _ContinueJourneyButton({required this.onTap, required this.label});
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF2C078), Color(0xFFD97A35)],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFFFE6B8), width: 1.5),
          boxShadow: const [
            BoxShadow(
                color: Color(0x99000000), blurRadius: 16, offset: Offset(0, 5)),
            BoxShadow(color: Color(0x55FFB347), blurRadius: 22, spreadRadius: 1),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_stories, color: Color(0xFF3A2410), size: 22),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF3A2410),
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3)),
          ],
        ),
      ),
    );
  }
}

/// Bouton libellé « Nouvelle partie » — bien visible (pas une icône cryptique).
/// Mini-carte du parcours : réutilise le décor de la vraie map + son tracé
/// en BOUCLE (ronde) + les gares, à afficher en petit (ex. carte accrochée au
/// mur du wagon). Si [aged], applique un filtre sépia + vignette "vieilli".
class MiniRouteMap extends StatelessWidget {
  const MiniRouteMap({super.key, this.aged = true});
  final bool aged;

  @override
  Widget build(BuildContext context) {
    Widget map = Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/background/map_route.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const ColoredBox(color: Color(0xFFB8945C)),
        ),
        CustomPaint(painter: _MiniRoutePainter()),
      ],
    );
    if (aged) {
      // Sépia.
      map = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.393, 0.769, 0.189, 0, 0, //
          0.349, 0.686, 0.168, 0, 0, //
          0.272, 0.534, 0.131, 0, 0, //
          0, 0, 0, 1, 0, //
        ]),
        child: map,
      );
      // Vignette sombre + léger voile ambré (papier jauni).
      map = Stack(
        fit: StackFit.expand,
        children: [
          map,
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 0.95,
                colors: [Color(0x00000000), Color(0x773A2410)],
              ),
            ),
          ),
          const ColoredBox(color: Color(0x1FA8721E)),
        ],
      );
    }
    return map;
  }
}

class _MiniRoutePainter extends CustomPainter {
  static final _ArcPath _path = _ArcPath(_buildSpline(_trackPoints));

  @override
  void paint(Canvas canvas, Size size) {
    final pts = _path.points;
    if (pts.isEmpty) return;
    final loop = Path()
      ..moveTo(pts.first.dx * size.width, pts.first.dy * size.height);
    for (final pt in pts.skip(1)) {
      loop.lineTo(pt.dx * size.width, pt.dy * size.height);
    }
    loop.close();
    // Liseré clair sous le tracé (lisibilité sur le décor).
    canvas.drawPath(
      loop,
      Paint()
        ..color = const Color(0x66F3E2C0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * 0.03
        ..strokeJoin = StrokeJoin.round,
    );
    // Tracé du rail en boucle.
    canvas.drawPath(
      loop,
      Paint()
        ..color = const Color(0xDD4A2F18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * 0.016
        ..strokeJoin = StrokeJoin.round,
    );
    // Gares (points rouges).
    final dot = Paint()..color = const Color(0xFFC8412A);
    for (final t in kGarePositions) {
      final o = _path.at(t);
      canvas.drawCircle(
        Offset(o.dx * size.width, o.dy * size.height),
        size.shortestSide * 0.018,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(_MiniRoutePainter old) => false;
}

class _TrainZoneHUD extends StatelessWidget {
  const _TrainZoneHUD({required this.path, required this.displayPosition});
  final _ArcPath path;
  final double displayPosition;

  @override
  Widget build(BuildContext context) {
    final gs = GameState.instance;
    final zone = gs.trainZone;

    // La position du train suit l'histoire : on affiche la prochaine gare et
    // l'avancement dans le segment courant (plus d'ETA chronométré).
    final gareIdx = (gs.cardGareIndex ?? 0).clamp(0, _stations.length - 1);
    final hasNext = gs.hasCardRun && gareIdx < _stations.length - 1;
    final nextStation = hasNext ? _stations[gareIdx + 1] : null;
    final progressPct = (gs.cardSegmentProgress * 100).round();
    final String etaLabel;
    if (!gs.hasCardRun) {
      etaLabel = ''; // pas de "Voyage à commencer" (inutile)
    } else if (nextStation == null) {
      etaLabel = 'Terminus — refuge nord';
    } else {
      etaLabel = '${nextStation.name} — $progressPct%';
    }

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
          Text(zoneLabel, style: TextStyle(color: color, fontSize: 13)),
          if (etaLabel.isNotEmpty) ...[
            Text('  •  ', style: TextStyle(color: color, fontSize: 13)),
            const Icon(Icons.train, color: Colors.white70, size: 14),
            const SizedBox(width: 4),
            Text(etaLabel,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}
