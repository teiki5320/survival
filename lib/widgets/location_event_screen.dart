import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/world.dart';
import '../models/game_state.dart';

/// Modal that opens when the player taps a map location. Shows a
/// cross-fading stack of "place" backgrounds (or a procedural
/// placeholder if assets aren't there yet) and a question with three
/// choices. Picking a choice shows the outcome text then returns to the
/// map.
class LocationEventScreen extends StatefulWidget {
  const LocationEventScreen({super.key, required this.location});
  final Location location;

  @override
  State<LocationEventScreen> createState() => _LocationEventScreenState();
}

class _LocationEventScreenState extends State<LocationEventScreen> {
  late final Question _question;
  late final int _bgSeed;
  int _bgIndex = 0;
  Timer? _bgTimer;
  Choice? _picked;

  @override
  void initState() {
    super.initState();
    _question = pickQuestion(widget.location);
    _bgSeed = widget.location.id.hashCode;
    _bgTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      setState(() {
        _bgIndex = (_bgIndex + 1) % widget.location.backgrounds.length;
      });
    });
  }

  @override
  void dispose() {
    _bgTimer?.cancel();
    super.dispose();
  }

  void _pick(Choice c) {
    setState(() => _picked = c);
    c.apply();
  }

  void _close() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.location;
    final bgPath = loc.backgrounds[_bgIndex];
    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF0E0B09),
      child: SafeArea(
        child: Stack(
          children: [
            // Cross-fading backgrounds.
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 1500),
                child: _LocationBackground(
                  key: ValueKey(_bgIndex),
                  assetPath: bgPath,
                  seed: _bgSeed + _bgIndex * 31,
                ),
              ),
            ),
            // Dark vignette so the centred panel reads.
            const Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [Color(0x00000000), Color(0xB0000000)],
                      stops: [0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            // Header: location name + close button.
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      loc.name,
                      style: const TextStyle(
                        color: Color(0xFFFFD9A0),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: FloatingActionButton.small(
                heroTag: 'event_close',
                tooltip: 'Quitter',
                onPressed: _close,
                child: const Icon(Icons.close),
              ),
            ),
            // Centre panel: question + choices, or outcome.
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: _picked == null
                      ? _QuestionPanel(question: _question, onPick: _pick)
                      : _OutcomePanel(choice: _picked!, onContinue: _close),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionPanel extends StatelessWidget {
  const _QuestionPanel({required this.question, required this.onPick});
  final Question question;
  final ValueChanged<Choice> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x55FFD9A0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            question.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFF5E5C5),
              fontSize: 17,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          ...question.choices.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFFD9A0),
                    backgroundColor: const Color(0xFF3B2A1C),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => onPick(c),
                  child: Text(
                    c.label,
                    textAlign: TextAlign.left,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutcomePanel extends StatelessWidget {
  const _OutcomePanel({required this.choice, required this.onContinue});
  final Choice choice;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final deltas = <String>[];
    if (choice.energyDelta > 0) {
      deltas.add('+${choice.energyDelta} énergie');
    } else if (choice.energyDelta < 0) {
      deltas.add('${choice.energyDelta} énergie');
    }
    if (choice.grantItems.isNotEmpty) {
      deltas.add(choice.grantItems.entries
          .map((e) => '+${e.value} ${e.key}')
          .join(', '));
    }
    if (choice.unlocksLocation != null) {
      deltas.add('Nouveau lieu débloqué : ${choice.unlocksLocation}');
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFB85522)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            choice.outcomeText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFF5E5C5),
              fontSize: 16,
              height: 1.4,
            ),
          ),
          if (deltas.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              deltas.join('  •  '),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFFD66B),
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 22),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB85522),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: onContinue,
            child: const Text('Retour au train'),
          ),
        ],
      ),
    );
  }
}

/// Either the real asset (if [assetPath] is given AND loads) or a
/// procedural sketch of an abandoned scene tinted from a seed colour.
class _LocationBackground extends StatelessWidget {
  const _LocationBackground({super.key, required this.assetPath, required this.seed});
  final String? assetPath;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final path = assetPath;
    if (path != null) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _procedural(),
      );
    }
    return _procedural();
  }

  Widget _procedural() {
    return CustomPaint(painter: _PlacePainter(seed: seed));
  }
}

class _PlacePainter extends CustomPainter {
  _PlacePainter({required this.seed});
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    final hue = rng.nextDouble();
    final base = HSLColor.fromAHSL(1, hue * 360, 0.18, 0.22).toColor();
    final accent = HSLColor.fromAHSL(1, (hue + 0.5) % 1.0 * 360, 0.4, 0.55).toColor();
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          base.withValues(alpha: 0.9),
          base.withValues(alpha: 1.0),
          base.withValues(alpha: 0.55),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Silhouettes of buildings / ruins along the bottom.
    final buildings = Paint()..color = const Color(0xCC1A130C);
    for (int i = 0; i < 8; i++) {
      final bx = (i + rng.nextDouble()) * size.width / 8 - 30;
      final bw = 60.0 + rng.nextDouble() * 40;
      final bh = 80.0 + rng.nextDouble() * 140;
      canvas.drawRect(
        Rect.fromLTWH(bx, size.height - bh, bw, bh),
        buildings,
      );
      // A few warm windows in each building.
      final wp = Paint()..color = accent.withValues(alpha: 0.6);
      final wCount = 1 + rng.nextInt(3);
      for (int w = 0; w < wCount; w++) {
        canvas.drawRect(
          Rect.fromLTWH(
            bx + 8 + rng.nextDouble() * (bw - 18),
            size.height - bh + 10 + rng.nextDouble() * (bh - 30),
            6,
            8,
          ),
          wp,
        );
      }
    }

    // Drifting smoke / mist patches in the upper third.
    final mist = Paint()
      ..color = const Color(0x55E8D2A0)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width,
            rng.nextDouble() * size.height * 0.4),
        40 + rng.nextDouble() * 40,
        mist,
      );
    }
  }

  @override
  bool shouldRepaint(_PlacePainter old) => old.seed != seed;
}
