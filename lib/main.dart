import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'widgets/locomotive_scene.dart';
import 'widgets/side_scroll_scene.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const TrainCosyApp());
}

class TrainCosyApp extends StatelessWidget {
  const TrainCosyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Train Cosy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF8B6F4E),
        brightness: Brightness.dark,
      ),
      home: const WagonScreen(),
    );
  }
}

class WagonScreen extends StatefulWidget {
  const WagonScreen({super.key});

  @override
  State<WagonScreen> createState() => _WagonScreenState();
}

class _WagonScreenState extends State<WagonScreen> {
  // Wagon restoration progression: 0 dirty → 1 swept → 2 windowed → 3 clean.
  // Cycles on tap of the "nettoyer" FAB; will be driven by gameplay later.
  int _wagonStage = 0;
  bool _running = true;
  bool _night = false;
  bool _dancing = false;
  int _lieDownToken = 0;

  bool _inLocomotive = false;
  bool _bedAdjust = false;
  // Mirror of the heroine's X position, updated by the scene. Used to
  // enable the door action button only when she's at the left edge.
  double _heroX = 0.5;
  bool get _atLeftDoor => _heroX <= SideScrollScene.heroXMin + 0.01;

  static const _stageLabels = ['Sale', 'Sol nettoyé', 'Vitres remises', 'Tout propre'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        child: _inLocomotive
            ? LocomotiveScene(
                key: const ValueKey('locomotive'),
                night: _night,
                onReturn: () => setState(() => _inLocomotive = false),
              )
            : _buildWagon(key: const ValueKey('wagon')),
      ),
    );
  }

  Widget _buildWagon({required Key key}) {
    return Stack(
      key: key,
      children: [
        Positioned.fill(
          child: SideScrollScene(
            wagonStage: _wagonStage,
            running: _running,
            night: _night,
            dancing: _dancing,
            lieDownToken: _lieDownToken,
            bedAdjust: _bedAdjust,
            onUserInteract: () {
              if (_dancing) setState(() => _dancing = false);
            },
            onHeroXChanged: (x) {
              final wasAtDoor = _atLeftDoor;
              _heroX = x;
              if (wasAtDoor != _atLeftDoor) setState(() {});
            },
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'bed_adjust',
                  tooltip: _bedAdjust ? 'Valider la position du lit' : 'Régler le lit',
                  backgroundColor: _bedAdjust ? const Color(0xFFB85522) : null,
                  foregroundColor: _bedAdjust ? Colors.white : null,
                  onPressed: () => setState(() => _bedAdjust = !_bedAdjust),
                  child: Icon(_bedAdjust ? Icons.check : Icons.tune),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'door_action',
                  tooltip: _atLeftDoor
                      ? 'Entrer dans la locomotive'
                      : 'Va à la porte (bord gauche)',
                  backgroundColor: _atLeftDoor
                      ? const Color(0xFFB85522)
                      : Colors.grey.shade800,
                  foregroundColor: _atLeftDoor ? Colors.white : Colors.grey.shade500,
                  onPressed: _atLeftDoor
                      ? () => setState(() => _inLocomotive = true)
                      : null,
                  child: const Icon(Icons.meeting_room),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'lie_down',
                  tooltip: 'Se coucher',
                  onPressed: () => setState(() => _lieDownToken++),
                  child: const Icon(Icons.bed),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'toggle_dance',
                  tooltip: _dancing ? 'Arrêter de danser' : 'Danser',
                  onPressed: () => setState(() => _dancing = !_dancing),
                  child: Icon(_dancing ? Icons.stop : Icons.celebration),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'toggle_night',
                  tooltip: _night ? 'Passer en jour' : 'Passer en nuit',
                  onPressed: () => setState(() => _night = !_night),
                  child: Icon(_night ? Icons.wb_sunny : Icons.nightlight_round),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'cycle_wagon_stage',
                  tooltip: 'Wagon: ${_stageLabels[_wagonStage]}',
                  onPressed: () => setState(() => _wagonStage = (_wagonStage + 1) % 4),
                  child: const Icon(Icons.cleaning_services),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'toggle_run',
                  tooltip: _running ? 'Arrêter le train' : 'Démarrer le train',
                  onPressed: () => setState(() => _running = !_running),
                  child: Icon(_running ? Icons.pause : Icons.play_arrow),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
