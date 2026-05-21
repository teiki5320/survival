import 'package:flutter/material.dart';

/// Locomotive cab scene — heroine has walked through the door at the
/// front of the wagon and is now in the driver's compartment.
///
/// Placeholder until the user pushes the real locomotive image.
/// Once dropped at assets/background/locomotive.png it shows it
/// instead of the placeholder.
class LocomotiveScene extends StatefulWidget {
  const LocomotiveScene({
    super.key,
    required this.onReturn,
  });

  /// Called when the user wants to go back to the wagon.
  final VoidCallback onReturn;

  @override
  State<LocomotiveScene> createState() => _LocomotiveSceneState();
}

class _LocomotiveSceneState extends State<LocomotiveScene> {
  int _logsThrown = 0;

  void _throwLog() {
    setState(() => _logsThrown++);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/background/locomotive.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(),
              ),
            ),
            // Log counter HUD (top-left).
            Positioned(
              top: 24,
              left: 24,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Bûches : $_logsThrown',
                    style: const TextStyle(
                      color: Color(0xFFFFD9A0),
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
            // Action buttons (bottom-right).
            Positioned(
              right: 16,
              bottom: 16,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'throw_log',
                      tooltip: 'Mettre une bûche',
                      backgroundColor: const Color(0xFFB85522),
                      foregroundColor: Colors.white,
                      onPressed: _throwLog,
                      child: const Icon(Icons.local_fire_department),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton.small(
                      heroTag: 'return_to_wagon',
                      tooltip: 'Retourner au wagon',
                      onPressed: widget.onReturn,
                      child: const Icon(Icons.arrow_back),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF1A1410),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.local_fire_department,
              size: 64,
              color: Color(0xFFB85522),
            ),
            SizedBox(height: 16),
            Text(
              'Locomotive\n(image à venir)',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFFFD9A0),
                fontSize: 20,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
