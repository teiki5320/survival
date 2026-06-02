import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Écran de chargement affiché AVANT le jeu. Décode (precache) tous les
/// sprites du jeu et ATTEND la fin avant de céder la main au wagon. Sans ça,
/// le décodage des PNG se faisait en tâche de fond pendant qu'on jouait, et
/// la première fois qu'une animation était jouée elle saccadait le temps de
/// décoder ses 49 frames. Ici tout est prêt avant le premier tap.
class LoadingScreen extends StatefulWidget {
  final VoidCallback onReady;
  const LoadingScreen({super.key, required this.onReady});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  double _progress = 0;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _warmUp();
  }

  Future<void> _warmUp() async {
    List<String> assets = const [];
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      assets = manifest
          .listAssets()
          .where((a) =>
              a.startsWith('assets/') && a.toLowerCase().endsWith('.png'))
          .toList();
    } catch (_) {
      // Si le manifest échoue, on laisse simplement passer (le jeu
      // préchargera au vol comme avant).
    }

    if (assets.isEmpty) {
      if (mounted) widget.onReady();
      return;
    }

    // Priorise les sprites du personnage (la cause des saccades), puis le
    // reste. On décode par petits lots en parallèle pour aller vite tout en
    // gardant une progression fluide.
    assets.sort((a, b) {
      int rank(String s) {
        if (s.startsWith('assets/characters/')) return 0;
        if (s.startsWith('assets/objects/')) return 1;
        return 2;
      }

      return rank(a).compareTo(rank(b));
    });

    const batch = 8;
    int done = 0;
    for (int i = 0; i < assets.length; i += batch) {
      if (!mounted) return;
      final slice = assets.skip(i).take(batch);
      await Future.wait(slice.map((a) async {
        try {
          await precacheImage(AssetImage(a), context);
        } catch (_) {/* asset illisible : on ignore */}
      }));
      done += slice.length;
      if (mounted) setState(() => _progress = done / assets.length);
    }

    // Laisse une frame s'afficher à 100% avant de basculer.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (mounted) widget.onReady();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1B1410),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Train Cosy',
              style: TextStyle(
                color: Color(0xFFE8D5B0),
                fontSize: 30,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Le train se prépare…',
              style: TextStyle(color: Color(0xFF9A8B76), fontSize: 14),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress,
                  minHeight: 6,
                  backgroundColor: Colors.white12,
                  valueColor:
                      const AlwaysStoppedAnimation(Color(0xFFD9A05B)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${(_progress * 100).round()} %',
              style: const TextStyle(color: Color(0xFF7A6E5E), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
