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
    return Scaffold(
      backgroundColor: const Color(0xFF1A1410),
      body: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            transformationController: _transformCtrl,
            minScale: 0.8,
            maxScale: 3.0,
            boundaryMargin: const EdgeInsets.all(100),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
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
                        painter: _TrainMarkerPainter(
                          position: GameState.instance.trainPosition,
                        ),
                      ),
                    ),
                  ],
                );
              },
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

class _TrainMarkerPainter extends CustomPainter {
  _TrainMarkerPainter({required this.position});
  final double position;

  @override
  void paint(Canvas canvas, Size size) {
    // Le parcours est un ovale centré sur la carte.
    final cx = size.width * 0.5;
    final cy = size.height * 0.5;
    final rx = size.width * 0.35;
    final ry = size.height * 0.38;

    // Position sur l'ovale (0 = haut = zone froide, 0.5 = bas = zone chaude).
    final angle = position * 2 * math.pi - math.pi / 2;
    final x = cx + rx * math.cos(angle);
    final y = cy + ry * math.sin(angle);

    // Halo
    canvas.drawCircle(
      Offset(x, y),
      14,
      Paint()
        ..color = const Color(0x55FF6B00)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    // Point train
    canvas.drawCircle(
      Offset(x, y),
      7,
      Paint()..color = const Color(0xFFFF6B00),
    );
    canvas.drawCircle(
      Offset(x, y),
      7,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_TrainMarkerPainter old) => old.position != position;
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
