import 'package:flutter/material.dart';

/// Séquence de bulles de TUTO affichée une fois, à l'arrivée dans le wagon
/// vide (résume la situation + dit comment avancer). Tap = bulle suivante.
class IntroTutorial extends StatefulWidget {
  const IntroTutorial({super.key, required this.onDone});
  final VoidCallback onDone;

  static const List<String> messages = [
    'Te voilà. Seule, dans un wagon d\'un train qui file vers le nord.',
    'Le wagon est vide et abîmé. À toi d\'en refaire un foyer, gare après gare.',
    'En haut, tes 4 jauges vitales : 💧 soif · 🍖 faim · 🪵 bois · ❤️ moral. Si l\'une tombe à ZÉRO, le voyage s\'arrête.',
    'Le 🌡️ thermomètre (à gauche) : quand il fait froid, ton moral ne remonte plus. Allume le poêle pour te réchauffer — mais ça brûle du bois.',
    'Pour voyager : prends la porte de GAUCHE → la locomotive → ramasse des bûches → touche la carte murale.',
    'Sur la carte, « Débuter le voyage » lance tes cartes : chaque choix coûte et rapporte des ressources.',
  ];

  @override
  State<IntroTutorial> createState() => _IntroTutorialState();
}

class _IntroTutorialState extends State<IntroTutorial> {
  int _i = 0;

  void _next() {
    if (_i >= IntroTutorial.messages.length - 1) {
      widget.onDone();
      return;
    }
    setState(() => _i++);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _next,
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.55),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: _TutoCard(
                text: IntroTutorial.messages[_i],
                footer:
                    '${_i + 1}/${IntroTutorial.messages.length}   ·   touche pour continuer',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Carte de tuto stylée (parchemin sombre + liseré ambré).
class _TutoCard extends StatelessWidget {
  const _TutoCard({required this.text, this.footer});
  final String text;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      decoration: BoxDecoration(
        color: const Color(0xF22A2018),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9A05B), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x88000000), blurRadius: 20),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline,
                  color: Color(0xFFE8C06A), size: 20),
              const SizedBox(width: 8),
              Text('Tutoriel',
                  style: TextStyle(
                      color: const Color(0xFFE8C06A).withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Color(0xFFF0E2C6), fontSize: 17, height: 1.45),
          ),
          if (footer != null) ...[
            const SizedBox(height: 14),
            Text(footer!,
                style: const TextStyle(
                    color: Color(0xFF9A8A6E), fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

/// Petite bulle d'aide « 1re utilisation » : pointe vers le bouton d'action.
/// Affichée tant que le joueur n'a pas utilisé l'objet (puis marquée vue).
class HintBubble extends StatelessWidget {
  const HintBubble({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 240),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xF22A2018),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD9A05B), width: 1.2),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 12)],
        ),
        child: Text(
          text,
          style: const TextStyle(
              color: Color(0xFFF0E2C6), fontSize: 13, height: 1.35),
        ),
      ),
    );
  }
}
