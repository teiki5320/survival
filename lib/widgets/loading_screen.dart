import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'side_scroll_scene.dart' show kHeroDecodeWidth, kDogDecodeWidth;

/// Écran de chargement affiché AVANT le jeu. Décode (precache) tous les
/// sprites du jeu et ATTEND la fin avant de céder la main au wagon. Sans ça,
/// le décodage des PNG se faisait en tâche de fond pendant qu'on jouait, et
/// la première fois qu'une animation était jouée elle saccadait le temps de
/// décoder ses frames (25 pour Shen). Ici tout est prêt avant le premier tap.
class LoadingScreen extends StatefulWidget {
  final VoidCallback onReady;
  const LoadingScreen({super.key, required this.onReady});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  double _progress = 0;
  bool _started = false;

  // On ne précharge QUE l'essentiel immédiat (sinon décoder les ~1650 PNG du
  // jeu en pleine résolution fait crasher iOS par OOM). Le reste (anims rares)
  // se décode à la volée au 1er usage.
  static bool _essential(String a) {
    if (a.startsWith('assets/background/')) return true;
    if (a.startsWith('assets/objects/')) return true;
    if (a.startsWith('assets/characters/')) {
      final f = a.split('/').last;
      const keep = [
        'idle_right_',
        'walk_right_',
        'heroine_front',
        'sister_idle_',
        'sister_walk_',
        // Anims de la locomotive (sinon ça saccade au 1er chargement).
        'carry_walk_',
        'warm_hands_',
        'open_door_',
      ];
      return keep.any(f.startsWith);
    }
    return false;
  }

  /// Choisit le provider (et sa largeur de décodage) en fonction de l'asset, de
  /// façon à PARTAGER LA CLÉ DE CACHE avec le rendu (sinon double décodage).
  ///  - personnages (Shen / sœur) : `kHeroDecodeWidth` (512 = source, full HD) ;
  ///  - chien + lampe animée (objets affichés petits, source 512) : 256 ;
  ///  - le reste (fonds, props statiques, tank…) : décodage brut (rendu brut).
  static ImageProvider _provider(String a) {
    if (a.startsWith('assets/characters/')) {
      return ResizeImage(AssetImage(a), width: kHeroDecodeWidth);
    }
    final f = a.split('/').last;
    if (a.startsWith('assets/objects/') &&
        (f.startsWith('dog_') || f.startsWith('lamp_'))) {
      return ResizeImage(AssetImage(a), width: kDogDecodeWidth);
    }
    return AssetImage(a);
  }

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
              a.toLowerCase().endsWith('.png') && _essential(a))
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
          await precacheImage(_provider(a), context);
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
    final p = _progress.clamp(0.0, 1.0);
    // Material transparent : fournit un DefaultTextStyle propre (sinon Flutter
    // ajoute le double soulignage jaune sur les Text hors Material).
    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.15),
          radius: 1.1,
          colors: [Color(0xFF2E2118), Color(0xFF160F0B)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Train Cosy',
              style: TextStyle(
                color: Color(0xFFF0DCB6),
                fontSize: 34,
                fontWeight: FontWeight.w600,
                letterSpacing: 3,
                shadows: [
                  Shadow(color: Color(0x66D9A05B), blurRadius: 18),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Le train se prépare…',
              style: TextStyle(
                color: Color(0xFFB59C7E),
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 34),
            SizedBox(
              width: 250,
              height: 26,
              child: LayoutBuilder(
                builder: (_, c) {
                  final w = c.maxWidth;
                  return Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.centerLeft,
                    children: [
                      // Rail / track.
                      Container(
                        height: 9,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3A2C1E),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                              color: const Color(0xFF4D3B28), width: 1),
                        ),
                      ),
                      // Remplissage ambré avec halo.
                      Container(
                        width: (w * p).clamp(0.0, w),
                        height: 9,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF2C078), Color(0xFFD97A35)],
                          ),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x88E0902F), blurRadius: 10),
                          ],
                        ),
                      ),
                      // Petit train qui avance au bout du remplissage.
                      Positioned(
                        left: (w * p - 13).clamp(0.0, w - 26),
                        child: const Text('🚂', style: TextStyle(fontSize: 22)),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '${(p * 100).round()} %',
              style: const TextStyle(
                color: Color(0xFF9A876E),
                fontSize: 13,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            // Numéro de build (pour vérifier qu'on teste la bonne version).
            const Text(
              'build 0.99.93',
              style: TextStyle(color: Color(0xFF6B5E4E), fontSize: 11),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
