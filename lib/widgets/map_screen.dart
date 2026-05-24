import 'package:flutter/material.dart';

/// Écran carte du monde. Version ultra-minimaliste pour s'assurer que
/// l'image s'affiche. Pins / HUD énergie / event screens seront
/// rebranchés une fois ce fix validé en TestFlight.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fond sépia : visible si Image.asset rate, garantit qu'on voit
      // toujours quelque chose de chaud plutôt que le placeholder gris.
      backgroundColor: const Color(0xFFB8945C),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Map en plein écran.
          Image.asset(
            'assets/background/map.png',
            fit: BoxFit.cover,
            errorBuilder: (_, e, __) {
              debugPrint('map.png load failed: $e');
              return const ColoredBox(color: Color(0xFFB8945C));
            },
          ),
          // Bouton close en haut à droite.
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
                  onPressed: onClose,
                  child: const Icon(Icons.close),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

