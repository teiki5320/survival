import 'package:flutter/material.dart';
import '../models/game_state.dart';

/// Affichage UNIFIÉ des 4 jauges du voyage (soif / faim / bois / moral).
///
/// Style anneau : emoji au-dessus, anneau de progression + valeur au centre.
/// Utilisé PARTOUT (cartes, wagon, carte du monde, locomotive) pour un rendu
/// cohérent. Ne pas réinventer de jauge ailleurs : réutiliser ce widget.
class StatRingsBar extends StatelessWidget {
  final double ringSize;
  final double emojiSize;
  final MainAxisAlignment alignment;
  final MainAxisSize mainAxisSize;

  const StatRingsBar({
    super.key,
    this.ringSize = 46,
    this.emojiSize = 18,
    this.alignment = MainAxisAlignment.spaceEvenly,
    this.mainAxisSize = MainAxisSize.max,
  });

  static const List<String> _order = ['soif', 'faim', 'bois', 'moral'];
  static const Map<String, String> emoji = {
    'soif': '💧',
    'faim': '🍖',
    'bois': '🪵',
    'moral': '❤️',
  };
  static const Map<String, Color> color = {
    'soif': Color(0xFF6FAEDF),
    'faim': Color(0xFFE89B5C),
    'bois': Color(0xFFB5854E),
    'moral': Color(0xFFD98A8A),
  };

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: GameState.instance,
      builder: (_, __) {
        final gs = GameState.instance;
        final vals = {
          'soif': gs.cardSoif,
          'faim': gs.cardFaim,
          'bois': gs.cardBois,
          'moral': gs.cardMoral,
        };
        return Row(
          mainAxisAlignment: alignment,
          mainAxisSize: mainAxisSize,
          children: [
            for (final k in _order)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: ringSize * 0.12),
                child: StatRing(
                  emoji: emoji[k]!,
                  value: vals[k]!,
                  color: color[k]!,
                  ringSize: ringSize,
                  emojiSize: emojiSize,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Un seul anneau (emoji + anneau + valeur). Vire au rouge si bas (≤ 20).
class StatRing extends StatelessWidget {
  final String emoji;
  final int value;
  final Color color;
  final double ringSize;
  final double emojiSize;

  const StatRing({
    super.key,
    required this.emoji,
    required this.value,
    required this.color,
    this.ringSize = 46,
    this.emojiSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    final low = value <= 20;
    final ringColor = low ? Colors.redAccent : color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: TextStyle(fontSize: emojiSize)),
        SizedBox(height: ringSize * 0.08),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: ringSize,
              height: ringSize,
              child: CircularProgressIndicator(
                value: (value / 100).clamp(0.0, 1.0),
                strokeWidth: ringSize * 0.09,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation(ringColor),
              ),
            ),
            Text(
              '$value',
              style: TextStyle(
                color: low ? Colors.redAccent : Colors.white,
                fontSize: ringSize * 0.3,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
