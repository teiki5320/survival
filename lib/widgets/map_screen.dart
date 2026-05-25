import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/game_state.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final TransformationController _transformCtrl = TransformationController();

  @override
  void initState() {
    super.initState();
    GameState.instance.addListener(_onTrainMoved);
  }

  @override
  void dispose() {
    GameState.instance.removeListener(_onTrainMoved);
    _transformCtrl.dispose();
    super.dispose();
  }

  void _onTrainMoved() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

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
                      painter: _TrainOnTrackPainter(
                        position: GameState.instance.trainPosition,
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
                child: _TrainZoneHUD(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainOnTrackPainter extends CustomPainter {
  _TrainOnTrackPainter({required this.position});
  final double position;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.50;
    final cy = size.height * 0.46;
    final rx = size.width * 0.38;
    final ry = size.height * 0.34;

    // 0 = top (cold zone), 0.5 = bottom (warm zone)
    final angle = position * 2 * math.pi - math.pi / 2;
    final x = cx + rx * math.cos(angle);
    final y = cy + ry * math.sin(angle);

    // Train icon: small locomotive shape
    canvas.save();
    canvas.translate(x, y);

    // Direction tangente à l'ovale
    final tangentAngle = math.atan2(
      ry * math.cos(angle),
      -rx * math.sin(angle),
    );
    canvas.rotate(tangentAngle);

    // Corps du train
    final bodyPaint = Paint()..color = const Color(0xFFD4440F);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-12, -5, 24, 10),
        const Radius.circular(3),
      ),
      bodyPaint,
    );

    // Cheminée
    canvas.drawRect(
      const Rect.fromLTWH(6, -9, 4, 4),
      Paint()..color = const Color(0xFF2A2A2A),
    );

    // Roues
    final wheelPaint = Paint()..color = const Color(0xFF1A1A1A);
    canvas.drawCircle(const Offset(-6, 5), 3, wheelPaint);
    canvas.drawCircle(const Offset(6, 5), 3, wheelPaint);

    canvas.restore();

    // Halo
    canvas.drawCircle(
      Offset(x, y),
      18,
      Paint()
        ..color = const Color(0x33FF6B00)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }

  @override
  bool shouldRepaint(_TrainOnTrackPainter old) => old.position != position;
}

class _TrainZoneHUD extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final zone = GameState.instance.trainZone;
    final pos = GameState.instance.trainPosition;

    String label;
    IconData icon;
    Color color;
    switch (zone) {
      case TrainZone.cold:
        label = 'Zone froide';
        icon = Icons.ac_unit;
        color = const Color(0xFF8BB8D0);
      case TrainZone.warm:
        label = 'Zone tempérée';
        icon = Icons.wb_sunny;
        color = const Color(0xFFD4A55A);
      case TrainZone.transitionToCold:
        label = 'Entrée zone froide';
        icon = Icons.ac_unit;
        color = const Color(0xFFA0B8C0);
      case TrainZone.transitionToWarm:
        label = 'Sortie zone froide';
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
            '$label  •  ${(pos * 100).toStringAsFixed(0)}%',
            style: TextStyle(color: color, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
