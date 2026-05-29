import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/game_state.dart';

/// Filtre eau (tier 1) — système de décantation manuel à 5 jarres.
/// - Jarre 0 (source) se remplit en continu selon la météo (pluie/neige
///   = rapide, sec = très lent). Apporte de l'eau ET du sédiment.
/// - Le sédiment se dépose graduellement (3 min pour -1 unité).
/// - Tap sur une jarre : si clarté > 50%, transvase la moitié haute
///   dans la jarre suivante. Peu de sédiment passe.
/// - Dernière jarre : tap pour vider dans le compteur eau.
///
/// L'idée : on revient régulièrement pour faire avancer la chaîne, et
/// on apprend à doser. La décantation et le remplissage continuent
/// même quand le jeu est fermé.
class WaterGameTier1 extends StatefulWidget {
  const WaterGameTier1({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  State<WaterGameTier1> createState() => _WaterGameTier1State();
}

class _WaterGameTier1State extends State<WaterGameTier1> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      GameState.instance.advanceFarm();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E14),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: GameState.instance,
          builder: (_, __) {
            final gs = GameState.instance;
            final weatherLabel = _weatherLabel(gs);
            return Stack(
              children: [
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [Color(0xFF1A2030), Color(0xFF0A0E14)],
                        radius: 1.4,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Filtration par décantation',
                            style: TextStyle(
                              color: Color(0xFFFFD9A0),
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          _label(Icons.opacity,
                              gs.itemCount('water'),
                              const Color(0xFF6FAEDF)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        weatherLabel,
                        style: const TextStyle(
                            color: Color(0xFF8B6F4E), fontSize: 11),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Tap jarre claire → transvase le haut. Le sédiment doit décanter.',
                        style: TextStyle(
                            color: Color(0xFF8B6F4E), fontSize: 11),
                      ),
                      const SizedBox(height: 16),
                      Expanded(child: _buildJars()),
                    ],
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton(
                    icon: const Icon(Icons.close,
                        color: Color(0xFFFFD9A0), size: 28),
                    onPressed: widget.onClose,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _weatherLabel(GameState gs) {
    final inSource = gs.inColdZone ||
        gs.weather == Weather.rainy ||
        gs.weather == Weather.snowy;
    if (inSource) {
      return 'Source active : pluie / neige / zone froide';
    }
    return 'Source faible : météo sèche';
  }

  Widget _buildJars() {
    return Center(
      child: LayoutBuilder(
        builder: (_, c) {
          final maxW = c.maxWidth;
          final jarW = (maxW / 5).clamp(60.0, 110.0);
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < 5; i++) ...[
                _buildJar(i, jarW),
                if (i < 4)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.south,
                      color: Colors.white.withValues(alpha: 0.4),
                      size: 18,
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildJar(int idx, double width) {
    final jar = GameState.instance.waterJars[idx];
    final water = (jar['water'] ?? 0).toDouble();
    final sediment = (jar['sediment'] ?? 0).toDouble();
    final fillFrac = (water / 100).clamp(0.0, 1.0);
    final sedFrac = water > 0
        ? (sediment / water).clamp(0.0, 1.0)
        : 0.0;
    final clarity = 1.0 - sedFrac;
    final isSource = idx == 0;
    final isOutput = idx == 4;
    final canTransfer = !isSource && !isOutput
        ? (water >= 10 && clarity >= 0.5)
        : isOutput
            ? water >= 5
            : false;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: isSource
              ? null
              : () => GameState.instance.transferWater(idx),
          child: Container(
            width: width,
            height: 220,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: canTransfer
                    ? const Color(0xFFFFD9A0)
                    : const Color(0xFF4A3A2A),
                width: canTransfer ? 2 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Eau (couleur basée sur clarté).
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    height: 220 * fillFrac,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _waterColor(clarity, light: true),
                          _waterColor(clarity, light: false),
                        ],
                      ),
                    ),
                  ),
                ),
                // Couche sédimentaire au fond (visualisation).
                if (sedFrac > 0.05)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      height:
                          (220 * fillFrac * sedFrac * 0.4).clamp(0.0, 80.0),
                      decoration: const BoxDecoration(
                        color: Color(0xFF5A4630),
                      ),
                    ),
                  ),
                // Label en haut.
                Positioned(
                  top: 6,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      _jarLabel(idx),
                      style: const TextStyle(
                        color: Color(0xFFFFD9A0),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                // Stats au fond.
                Positioned(
                  bottom: 4,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      '${water.round()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isSource
              ? 'Source'
              : isOutput
                  ? 'Boire'
                  : '${(clarity * 100).round()}% clair',
          style: TextStyle(
            color: canTransfer
                ? const Color(0xFFFFD9A0)
                : const Color(0xFF6A5A4A),
            fontSize: 10,
            fontFamily: 'Courier',
          ),
        ),
      ],
    );
  }

  Color _waterColor(double clarity, {required bool light}) {
    // Marron-vert opaque (sale) → bleu cristal transparent (pur).
    final base = light
        ? Color.lerp(const Color(0xFF6B5536),
            const Color(0xFFA5D2E8), clarity)!
        : Color.lerp(const Color(0xFF4A3820),
            const Color(0xFF4A8AAB), clarity)!;
    return base;
  }

  String _jarLabel(int idx) {
    switch (idx) {
      case 0:
        return 'Brute';
      case 1:
        return '1er repos';
      case 2:
        return '2e repos';
      case 3:
        return 'Clarifiée';
      case 4:
        return 'Pure';
    }
    return '';
  }

  Widget _label(IconData icon, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontFamily: 'Courier',
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
