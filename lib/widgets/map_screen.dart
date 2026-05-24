import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/world.dart';
import '../models/game_state.dart';
import 'location_event_screen.dart';

/// World map: shows the train + a pin for each location. Unlocked pins
/// are tappable, locked ones are dimmed. Procedural map for now —
/// drop a real map image at assets/background/map.png and it'll be
/// used as the backdrop instead.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  @override
  void initState() {
    super.initState();
    GameState.instance.addListener(_onState);
  }

  @override
  void dispose() {
    GameState.instance.removeListener(_onState);
    super.dispose();
  }

  void _onState() {
    if (mounted) setState(() {});
  }

  void _openLocation(Location loc) async {
    final state = GameState.instance;
    if (!state.canLeaveTrain) return;
    state.spendEnergy(1);
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black,
      builder: (_) => LocationEventScreen(location: loc),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = GameState.instance;
    return Scaffold(
      backgroundColor: const Color(0xFF161310),
      body: SafeArea(
        child: Stack(
          children: [
            // Map backdrop : fond sépia procédural TOUJOURS rendu (garantit
            // qu'on ne voit pas un écran gris si l'image asset rate). Puis
            // map.png par-dessus si elle charge.
            Positioned.fill(
              child: SizedBox.expand(
                child: CustomPaint(painter: _ProceduralMapPainter()),
              ),
            ),
            Positioned.fill(
              child: Image.asset(
                'assets/background/map.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            // Train icon — fixed home base in the middle-left.
            Positioned.fill(
              child: IgnorePointer(
                child: SizedBox.expand(
                  child: CustomPaint(painter: _TrainPinPainter()),
                ),
              ),
            ),
            // Location pins, one per world entry.
            ...world.map((loc) => _LocationPin(
                  location: loc,
                  unlocked: state.isLocationUnlocked(loc.id),
                  enabled: state.canLeaveTrain,
                  onTap: () => _openLocation(loc),
                )),
            // HUD top-left: energy + inventory summary.
            Positioned(
              top: 16,
              left: 16,
              child: _HudPanel(state: state),
            ),
            // Close button top-right.
            Positioned(
              top: 12,
              right: 12,
              child: FloatingActionButton.small(
                heroTag: 'map_close',
                tooltip: 'Retour au train',
                onPressed: widget.onClose,
                child: const Icon(Icons.close),
              ),
            ),
            if (!state.canLeaveTrain)
              Positioned(
                bottom: 24,
                left: 24,
                right: 24,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFB85522)),
                    ),
                    child: const Text(
                      'Tu es épuisée. Tu ne peux plus quitter le train. '
                      'L\'énergie remonte petit à petit — repose-toi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFFFD9A0),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LocationPin extends StatelessWidget {
  const _LocationPin({
    required this.location,
    required this.unlocked,
    required this.enabled,
    required this.onTap,
  });

  final Location location;
  final bool unlocked;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final x = c.maxWidth * location.mapX;
        final y = c.maxHeight * location.mapY;
        const r = 22.0;
        final canTap = unlocked && enabled;
        return Positioned(
          left: x - r,
          top: y - r,
          width: r * 2,
          height: r * 2 + 32,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: canTap ? onTap : null,
                child: Container(
                  width: r * 2,
                  height: r * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: unlocked
                        ? const Color(0xFFB85522)
                        : Colors.grey.shade800,
                    border: Border.all(
                      color: const Color(0xFFFFD9A0),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    unlocked ? Icons.place : Icons.lock,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  unlocked ? location.name : '???',
                  style: const TextStyle(
                    color: Color(0xFFFFD9A0),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HudPanel extends StatelessWidget {
  const _HudPanel({required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: List.generate(GameState.maxEnergy, (i) {
              final on = i < state.energy;
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  on ? Icons.bolt : Icons.bolt_outlined,
                  size: 18,
                  color: on ? const Color(0xFFFFD66B) : Colors.grey.shade600,
                ),
              );
            }),
          ),
          if (state.items.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: state.items.entries
                  .map((e) => Text(
                        '${_itemLabel(e.key)} × ${e.value}',
                        style: const TextStyle(
                          color: Color(0xFFFFD9A0),
                          fontSize: 11,
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _itemLabel(String id) {
    switch (id) {
      case 'wood':
        return '🪵';
      case 'canned_food':
        return '🥫';
      case 'tools':
        return '🔧';
      case 'manual':
        return '📕';
      case 'bread':
        return '🍞';
      case 'seeds':
        return '🌱';
      case 'book':
        return '📖';
      case 'blanket':
        return '🧣';
      default:
        return id;
    }
  }
}

class _ProceduralMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Sepia parchment backdrop.
    final bgPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFE8D2A0), Color(0xFFB8945C), Color(0xFF5A3A1F)],
        stops: [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Rivers (a couple of wavy strokes).
    final rPaint = Paint()
      ..color = const Color(0xAA3E5C82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final p1 = Path()..moveTo(0, size.height * 0.7);
    for (double x = 0; x <= size.width; x += 20) {
      p1.lineTo(x, size.height * 0.7 + math.sin(x * 0.02) * 18);
    }
    canvas.drawPath(p1, rPaint);

    // Mountains (zigzag).
    final mPaint = Paint()
      ..color = const Color(0x804A3220)
      ..style = PaintingStyle.fill;
    final mp = Path()..moveTo(0, size.height * 0.30);
    for (int i = 0; i < 12; i++) {
      final x = i * size.width / 11;
      mp.lineTo(x, size.height * (0.25 + (i.isEven ? 0.05 : 0.0)));
    }
    mp.lineTo(size.width, size.height * 0.30);
    mp.lineTo(size.width, 0);
    mp.lineTo(0, 0);
    mp.close();
    canvas.drawPath(mp, mPaint);

    // Rail line crossing the map (the train's track).
    final trackPaint = Paint()
      ..color = const Color(0xCC3A2A1C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final tp = Path()..moveTo(0, size.height * 0.50);
    for (double x = 0; x <= size.width; x += 8) {
      tp.lineTo(x, size.height * 0.50 + math.sin(x * 0.014) * 22);
    }
    canvas.drawPath(tp, trackPaint);
    final tickPaint = Paint()..color = const Color(0xAA3A2A1C);
    for (double x = 0; x <= size.width; x += 22) {
      final y = size.height * 0.50 + math.sin(x * 0.014) * 22;
      canvas.drawRect(Rect.fromCenter(center: Offset(x, y), width: 3, height: 8), tickPaint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _TrainPinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.15;
    final cy = size.height * 0.50;
    // Filled circle + train icon (chimney + box).
    final outer = Paint()..color = const Color(0xFFFFD9A0);
    canvas.drawCircle(Offset(cx, cy), 26, outer);
    final inner = Paint()..color = const Color(0xFF2A1E14);
    canvas.drawCircle(Offset(cx, cy), 22, inner);
    // Tiny chimney
    canvas.drawRect(
        Rect.fromCenter(center: Offset(cx - 4, cy - 6), width: 6, height: 10),
        Paint()..color = const Color(0xFFFFD9A0));
    // Body
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx + 2, cy + 4), width: 22, height: 10),
            const Radius.circular(2)),
        Paint()..color = const Color(0xFFFFD9A0));
    // Label
    const tp = TextStyle(color: Color(0xFFFFD9A0), fontSize: 11);
    final tpw = TextPainter(
      text: const TextSpan(text: 'Train', style: tp),
      textDirection: TextDirection.ltr,
    )..layout();
    tpw.paint(canvas, Offset(cx - tpw.width / 2, cy + 30));
  }

  @override
  bool shouldRepaint(_) => false;
}
