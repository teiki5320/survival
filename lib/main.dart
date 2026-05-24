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
  // Taille du chien (fraction de la hauteur scène). Réglable via HUD.
  double _dogHeight = 0.086;
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
  bool get _atBed =>
      (_heroX - SideScrollScene.bedCenterX).abs() < 0.05;

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
            dogHeight: _dogHeight,
            onUserInteract: () {
              if (_dancing) setState(() => _dancing = false);
            },
            onHeroXChanged: (x) {
              final wasL = _atLeftDoor;
              final wasR = _atRightDoor;
              final wasB = _atBed;
              _heroX = x;
              if (wasL != _atLeftDoor ||
                  wasR != _atRightDoor ||
                  wasB != _atBed) {
                setState(() {});
              }
            },
          ),
        ),
        // HUD top-left : coord live du perso + taille du chien (slider).
        Positioned(
          top: 8,
          left: 8,
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'heroX = ${_heroX.toStringAsFixed(3)}  '
                    'L=${_atLeftDoor ? "✓" : "·"}  '
                    'R=${_atRightDoor ? "✓" : "·"}',
                    style: const TextStyle(
                      color: Color(0xFFFFD9A0),
                      fontSize: 12,
                      fontFamily: 'Courier',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'chien ${_dogHeight.toStringAsFixed(3)}  ',
                        style: const TextStyle(
                          color: Color(0xFFFFD9A0),
                          fontSize: 12,
                          fontFamily: 'Courier',
                        ),
                      ),
                      _tinyBtn(Icons.remove, () => setState(() =>
                          _dogHeight = (_dogHeight - 0.005).clamp(0.04, 0.20))),
                      const SizedBox(width: 4),
                      _tinyBtn(Icons.add, () => setState(() =>
                          _dogHeight = (_dogHeight + 0.005).clamp(0.04, 0.20))),
                    ],
                  ),
                ],
              ),
            ),
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
                // Bouton ACTION contextuel — un seul rond qui s'allume
                // quand le perso atteint un bord. Tap = entre dans la
                // loco (bord gauche) ou ouvre la map (bord droit).
                _actionFab(),
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

  /// Petit bouton +/- 26x26 utilisé dans le HUD top-left.
  Widget _tinyBtn(IconData icon, VoidCallback onTap) => InkResponse(
        onTap: onTap,
        radius: 18,
        child: Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: Color(0xFFB85522),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      );

  /// Bouton ACTION contextuel — un seul FAB rond qui remplace les
  /// 3 boutons (porte loco, porte map, se coucher). Sa couleur, son
  /// icône et son action dépendent de la position du perso.
  Widget _actionFab() {
    IconData icon = Icons.help_outline;
    String tooltip = 'Approche-toi du lit, de la porte gauche ou droite';
    VoidCallback? action;

    if (_atLeftDoor && !_doorPushing) {
      icon = Icons.meeting_room;
      tooltip = 'Entrer dans la locomotive';
      action = _enterLocomotive;
    } else if (_atRightDoor) {
      icon = Icons.map;
      tooltip = 'Ouvrir la carte du monde';
      action = () {
        debugPrint('[action] open map');
        setState(() => _onMap = true);
      };
    } else if (_atBed) {
      icon = Icons.bed;
      tooltip = 'Se coucher';
      action = () => setState(() => _lieDownToken++);
    } else if (_doorPushing) {
      icon = Icons.meeting_room;
      tooltip = 'Elle ouvre la porte…';
    }

    final active = action != null;
    return FloatingActionButton.small(
      heroTag: 'action',
      tooltip: tooltip,
      backgroundColor:
          active ? const Color(0xFFB85522) : Colors.grey.shade800,
      foregroundColor: active ? Colors.white : Colors.grey.shade500,
      onPressed: action,
      child: Icon(icon),
    );
  }
}
