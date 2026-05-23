import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/audio_service.dart';
import 'widgets/locomotive_scene.dart';
import 'widgets/map_screen.dart';
import 'widgets/side_scroll_scene.dart';
import 'widgets/wardrobe_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Augmente le cache d'images de Flutter. Par défaut ~100MB, ce qui
  // est trop petit pour 13 anims × 49 frames de 512x512 RGBA décodées
  // (≈450MB). Sans ça, le cache purge des frames et re-décode au switch
  // d'anim → saccadement visible. iPhone 16 Plus a 6GB de RAM, 800MB
  // pour les sprites c'est ok.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 800 * 1024 * 1024;
  PaintingBinding.instance.imageCache.maximumSize = 2000;
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
  bool _onMap = false;
  bool _inWardrobe = false;
  bool _propsAdjust = false;
  // True while the wagon scene is playing the door_push animation,
  // before the cross-fade to the locomotive. Disables the door FAB so
  // the player can't spam-tap and restart the animation halfway.
  bool _doorPushing = false;
  // Bumped on door-action tap; the wagon scene plays door_push and
  // calls back when done, at which point we cross-fade to locomotive.
  int _doorPushToken = 0;
  // Mirror of the heroine's X position, updated by the scene. Used to
  // enable the door action buttons only when she's at the left/right edge.
  double _heroX = 0.5;
  bool get _atLeftDoor => _heroX <= SideScrollScene.heroXMin + 0.01;
  bool get _atRightDoor => _heroX >= SideScrollScene.heroXMax - 0.01;

  // Total logs the heroine has thrown into the firebox. Plumbed back
  // to the wagon scene to crank up the smoke trail + speed lines, so
  // the gesture has a visible consequence outside the cab too.
  int _logsThrown = 0;

  static const _stageLabels = ['Sale', 'Sol nettoyé', 'Vitres remises', 'Tout propre'];

  final _audio = AudioService();

  @override
  void initState() {
    super.initState();
    _audio.startAmbientTrain();
    _audio.setMusic(_night ? 'night' : 'day');
  }

  @override
  void dispose() {
    _audio.stopAll();
    super.dispose();
  }

  void _enterLocomotive() {
    if (_doorPushing) return;
    setState(() {
      _doorPushing = true;
      _doorPushToken++;
    });
    _audio.playSfx('door_open');
  }

  void _onDoorPushDone() {
    if (!mounted) return;
    setState(() {
      _doorPushing = false;
      _inLocomotive = true;
    });
    _audio.startFire();
  }

  void _exitLocomotive() {
    setState(() => _inLocomotive = false);
    _audio.stopFire();
    _audio.playSfx('door_close');
  }

  void _toggleRun() {
    setState(() => _running = !_running);
    if (_running) {
      _audio.startAmbientTrain();
    } else {
      _audio.stopAmbientTrain();
    }
  }

  void _toggleNight() {
    setState(() => _night = !_night);
    _audio.setMusic(_night ? 'night' : 'day');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        child: _inWardrobe
            ? WardrobeScreen(
                key: const ValueKey('wardrobe'),
                onClose: () => setState(() => _inWardrobe = false),
              )
            : _onMap
            ? MapScreen(
                key: const ValueKey('map'),
                onClose: () => setState(() => _onMap = false),
              )
            : _inLocomotive
                ? LocomotiveScene(
                    key: const ValueKey('locomotive'),
                    night: _night,
                    logsThrown: _logsThrown,
                    onThrowLog: () => setState(() => _logsThrown++),
                    onReturn: _exitLocomotive,
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
            logsThrown: _logsThrown,
            doorPushToken: _doorPushToken,
            onDoorPushDone: _onDoorPushDone,
            onOpenWardrobe: () => setState(() => _inWardrobe = true),
            propsAdjust: _propsAdjust,
            onUserInteract: () {
              if (_dancing) setState(() => _dancing = false);
            },
            onHeroXChanged: (x) {
              final wasAtLeft = _atLeftDoor;
              final wasAtRight = _atRightDoor;
              _heroX = x;
              if (wasAtLeft != _atLeftDoor || wasAtRight != _atRightDoor) {
                setState(() {});
              }
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
                  heroTag: 'right_door',
                  tooltip: _atRightDoor
                      ? 'Ouvrir la porte droite'
                      : 'Va à la porte droite (bord droit)',
                  backgroundColor: _atRightDoor
                      ? const Color(0xFFB85522)
                      : Colors.grey.shade800,
                  foregroundColor:
                      _atRightDoor ? Colors.white : Colors.grey.shade500,
                  onPressed:
                      _atRightDoor ? () => setState(() => _onMap = true) : null,
                  child: const Icon(Icons.meeting_room_outlined),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'props_adjust',
                  tooltip: _propsAdjust
                      ? 'Valider la position des objets'
                      : 'Régler les objets',
                  backgroundColor: _propsAdjust ? const Color(0xFFB85522) : null,
                  foregroundColor: _propsAdjust ? Colors.white : null,
                  onPressed: () => setState(() => _propsAdjust = !_propsAdjust),
                  child: Icon(_propsAdjust ? Icons.check : Icons.widgets),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'door_action',
                  tooltip: _doorPushing
                      ? 'Elle ouvre la porte…'
                      : _atLeftDoor
                          ? 'Entrer dans la locomotive'
                          : 'Va à la porte (bord gauche)',
                  backgroundColor: _atLeftDoor && !_doorPushing
                      ? const Color(0xFFB85522)
                      : Colors.grey.shade800,
                  foregroundColor:
                      _atLeftDoor && !_doorPushing ? Colors.white : Colors.grey.shade500,
                  onPressed:
                      _atLeftDoor && !_doorPushing ? _enterLocomotive : null,
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
                  onPressed: _toggleNight,
                  child: Icon(_night ? Icons.wb_sunny : Icons.nightlight_round),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'cycle_wagon_stage',
                  tooltip: 'Wagon: ${_stageLabels[_wagonStage]}',
                  onPressed: () {
                    setState(() => _wagonStage = (_wagonStage + 1) % 4);
                    _audio.playSfx('clean');
                  },
                  child: const Icon(Icons.cleaning_services),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'toggle_run',
                  tooltip: _running ? 'Arrêter le train' : 'Démarrer le train',
                  onPressed: _toggleRun,
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
