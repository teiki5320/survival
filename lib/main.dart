import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/game_state.dart';
import 'services/audio_service.dart';
import 'widgets/locomotive_scene.dart';
import 'widgets/map_screen.dart';
import 'widgets/side_scroll_scene.dart';
import 'widgets/wardrobe_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Augmente le cache d'images Flutter. Par défaut ~100MB, trop petit
  // pour 13 anims × 49 frames hero + 4 props animés 49 frames × 512²
  // + 9 anims chien + à venir cook/pet_dog/garden/drink. iPhone 16
  // Plus a 8GB RAM, on s'autorise 1.5GB pour éviter toute purge du
  // cache qui cause des saccades au démarrage d'anim (re-decode JIT).
  PaintingBinding.instance.imageCache.maximumSizeBytes = 1500 * 1024 * 1024;
  PaintingBinding.instance.imageCache.maximumSize = 4000;
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
  int _cookToken = 0;

  bool _inLocomotive = false;
  bool _onMap = false;
  double _heroSpawnX = 0.5;
  bool _inWardrobe = false;
  // Taille du chien (fraction de la hauteur scène). Réglable via HUD.
  double _dogHeight = 0.136;
  int _dogInteractCount = 0;
  // True while the wagon scene is playing the door_push animation,
  // before the cross-fade to the locomotive. Disables the door FAB so
  // the player can't spam-tap and restart the animation halfway.
  bool _doorPushing = false;
  bool _doorPushRight = false;
  int _doorPushToken = 0;
  // Mirror of the heroine's X position. `_heroX` change quand le perso
  // bouge (60Hz) — pour éviter un setState à chaque tick qui rebuild
  // toute la scène et fait saccader, on l'expose via un ValueNotifier
  // que seul le HUD heroX écoute. Le setState n'est appelé que sur les
  // transitions de zone (porte gauche, porte droite, lit) qui modifient
  // l'apparence du _actionFab.
  double _heroX = 0.5;
  final ValueNotifier<double> _heroXNotifier = ValueNotifier(0.5);

  // Anim spéciale (drink, read, cook, pet_dog, garden_tend). On
  // incrémente `_specialAnimToken` à chaque (re)déclenchement pour que
  // la scène détecte le changement même si le nom reste identique.
  String? _specialAnim;
  int _specialAnimFrames = 25;
  bool _specialAnimLoops = false;
  int _specialAnimToken = 0;
  String? _specialAnimNext;
  int _specialAnimNextFrames = 25;

  void _triggerSpecial(String name,
      {int frames = 25, bool loops = false, String? next, int nextFrames = 25}) {
    setState(() {
      _specialAnim = name;
      _specialAnimFrames = frames;
      _specialAnimLoops = loops;
      _specialAnimNext = next;
      _specialAnimNextFrames = nextFrames;
      _specialAnimToken++;
    });
  }
  bool get _atLeftDoor => _heroX <= SideScrollScene.heroXMin + 0.01;
  bool get _atRightDoor => _heroX >= SideScrollScene.heroXMax - 0.01;
  bool get _atBed =>
      (_heroX - SideScrollScene.bedCenterX).abs() < 0.05;
  // Zones interactives autour des props.
  bool _near(double centerX, [double tol = 0.05]) =>
      (_heroX - centerX).abs() < tol;
  bool get _atNotebook => _near(SideScrollScene.notebookCenterX);
  bool get _atFilter => _near(SideScrollScene.filterCenterX);
  bool get _atLamp => _near(SideScrollScene.lampCenterX);
  bool get _atStove => _near(SideScrollScene.stoveCenterX);
  bool get _atHydro => _near(SideScrollScene.hydroCenterX);
  bool get _atDog => _near(0.525, 0.10);

  // Total logs the heroine has thrown into the firebox. Plumbed back
  // to the wagon scene to crank up the smoke trail + speed lines, so
  // the gesture has a visible consequence outside the cab too.
  int _logsThrown = 0;

  static const _stageLabels = ['Sale', 'Sol nettoyé', 'Vitres remises', 'Tout propre'];

  final _audio = AudioService();

  /// Cycle jour/nuit auto : passe day → night → day toutes les
  /// [_dayNightPeriod] minutes. Le bouton lune (FAB) garde la main si
  /// le joueur veut forcer manuellement.
  static const Duration _dayNightPeriod = Duration(minutes: 6);
  Timer? _dayNightTimer;

  @override
  void initState() {
    super.initState();
    _audio.startAmbientTrain();
    _audio.setMusic(_night ? 'night' : 'day');
    _dayNightTimer = Timer.periodic(_dayNightPeriod, (_) {
      if (!mounted) return;
      setState(() => _night = !_night);
      _audio.setMusic(_night ? 'night' : 'day');
    });
  }

  @override
  void dispose() {
    _dayNightTimer?.cancel();
    _heroXNotifier.dispose();
    _audio.stopAll();
    super.dispose();
  }

  void _enterLocomotive() {
    if (_doorPushing) return;
    setState(() {
      _doorPushing = true;
      _doorPushRight = false;
      _doorPushToken++;
    });
    _audio.playSfx('door_open');
  }

  void _openMapDoor() {
    if (_doorPushing) return;
    setState(() {
      _doorPushing = true;
      _doorPushRight = true;
      _doorPushToken++;
    });
    _audio.playSfx('door_open');
  }

  void _onDoorPushDone() {
    if (!mounted) return;
    if (_doorPushRight) {
      setState(() {
        _doorPushing = false;
        _onMap = true;
      });
    } else {
      setState(() {
        _doorPushing = false;
        _inLocomotive = true;
      });
      _audio.startFire();
    }
  }

  void _exitLocomotive() {
    setState(() {
      _inLocomotive = false;
      _heroSpawnX = SideScrollScene.heroXMin;
    });
    _audio.stopFire();
    _audio.playSfx('door_close');
  }

  void _exitMap() {
    setState(() {
      _onMap = false;
      _heroSpawnX = SideScrollScene.heroXMax;
    });
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
                onClose: _exitMap,
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
            initialHeroX: _heroSpawnX,
            wagonStage: _wagonStage,
            running: _running,
            night: _night,
            dancing: _dancing,
            lieDownToken: _lieDownToken,
            cookToken: _cookToken,
            logsThrown: _logsThrown,
            doorPushToken: _doorPushToken,
            doorPushRight: _doorPushRight,
            onDoorPushDone: _onDoorPushDone,
            onOpenWardrobe: () => setState(() => _inWardrobe = true),
            dogHeight: _dogHeight,
            specialAnim: _specialAnim,
            specialAnimFrames: _specialAnimFrames,
            specialAnimLoops: _specialAnimLoops,
            specialAnimToken: _specialAnimToken,
            specialAnimNext: _specialAnimNext,
            specialAnimNextFrames: _specialAnimNextFrames,
            onUserInteract: () {
              if (_dancing) setState(() => _dancing = false);
            },
            onHeroXChanged: (x) {
              _heroXNotifier.value = x;
              final wasL = _atLeftDoor;
              final wasR = _atRightDoor;
              final wasB = _atBed;
              final wasN = _atNotebook;
              final wasF = _atFilter;
              final wasLamp = _atLamp;
              final wasStove = _atStove;
              final wasDog = _atDog;
              final wasHydro = _atHydro;
              _heroX = x;
              if (wasL != _atLeftDoor ||
                  wasR != _atRightDoor ||
                  wasB != _atBed ||
                  wasN != _atNotebook ||
                  wasF != _atFilter ||
                  wasLamp != _atLamp ||
                  wasStove != _atStove ||
                  wasDog != _atDog ||
                  wasHydro != _atHydro) {
                setState(() {});
              }
            },
          ),
        ),
        // HUD survie — jauges compactes hunger/thirst/fatigue.
        Positioned(
          top: 8,
          left: 8,
          child: SafeArea(
            child: AnimatedBuilder(
              animation: GameState.instance,
              builder: (_, __) {
                final gs = GameState.instance;
                return Container(
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
                      _statBar(Icons.restaurant, gs.hunger,
                          const Color(0xFFE89B5C)),
                      const SizedBox(height: 2),
                      _statBar(Icons.water_drop, gs.thirst,
                          const Color(0xFF6FAEDF)),
                      const SizedBox(height: 2),
                      _statBar(Icons.bedtime, gs.fatigue,
                          const Color(0xFFB385D9)),
                    ],
                  ),
                );
              },
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

  /// Mini-jauge horizontale icone + barre 80px. Couleur passe au rouge
  /// quand la valeur descend sous 25 %.
  Widget _statBar(IconData icon, double value, Color color) {
    final low = value < 0.25;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 12,
            color: low ? const Color(0xFFE05A4D) : color.withValues(alpha: 0.9)),
        const SizedBox(width: 4),
        Container(
          width: 80,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: low ? const Color(0xFFE05A4D) : color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }


  /// Gros bouton rond contextuel — remplace les 3 anciens FABs (porte
  /// loco, porte map, lit). Icône + action dépendent de la position
  /// du perso. Style cosy : disque brun warm + bordure dorée + ombre.
  Widget _actionFab() {
    IconData icon = Icons.help_outline;
    VoidCallback? action;

    if (_atLeftDoor && !_doorPushing) {
      icon = Icons.meeting_room;
      action = _enterLocomotive;
    } else if (_atRightDoor && !_doorPushing) {
      icon = Icons.map;
      action = _openMapDoor;
    } else if (_atBed) {
      icon = Icons.bed;
      action = () => setState(() => _lieDownToken++);
    } else if (_atNotebook) {
      icon = Icons.menu_book;
      action = () {
        _triggerSpecial('read', frames: 49);
        GameState.instance.restoreFatigue(0.10);
      };
    } else if (_atFilter) {
      icon = Icons.local_drink;
      action = () {
        _triggerSpecial('use_back', frames: 24,
            next: 'drink', nextFrames: 25);
        GameState.instance.restoreThirst(0.20);
      };
    } else if (_atDog) {
      icon = Icons.pets;
      action = () {
        _dogInteractCount++;
        if (_dogInteractCount.isOdd) {
          _triggerSpecial('pet_dog', frames: 49);
        } else {
          _triggerSpecial('crouch', frames: 49);
        }
        GameState.instance.restoreFatigue(0.05);
      };
    } else if (_atStove) {
      icon = Icons.soup_kitchen;
      action = () => setState(() => _cookToken++);
    } else if (_atHydro) {
      icon = Icons.yard;
      action = () {
        _triggerSpecial('use_back', frames: 49);
      };
    } else if (_atLamp) {
      icon = GameState.instance.lampOn
          ? Icons.lightbulb
          : Icons.lightbulb_outline;
      action = () => setState(() => GameState.instance.toggleLamp());
    } else if (_doorPushing) {
      icon = Icons.meeting_room;
    }

    final bool active = action != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: active
            ? const RadialGradient(
                center: Alignment(-0.2, -0.3),
                radius: 1.0,
                colors: [
                  Color(0xFFF2B879), // honey crème en haut-gauche
                  Color(0xFFD97A35), // orange chaud
                  Color(0xFF8A3E15), // rouge brique en bas
                ],
                stops: [0.0, 0.55, 1.0],
              )
            : RadialGradient(
                center: const Alignment(-0.2, -0.3),
                radius: 1.0,
                colors: [
                  Colors.grey.shade500,
                  Colors.grey.shade700,
                  Colors.grey.shade900,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
        boxShadow: [
          // Ombre portée douce.
          BoxShadow(
            color: Colors.black.withValues(alpha: active ? 0.55 : 0.30),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
          // Halo chaud externe quand actif.
          if (active)
            const BoxShadow(
              color: Color(0x66FFB347),
              blurRadius: 26,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: action,
          splashColor: Colors.white.withValues(alpha: 0.25),
          highlightColor: Colors.white.withValues(alpha: 0.10),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Highlight haut (rim light) pour donner le côté bombé.
              Positioned(
                top: 6,
                left: 14,
                right: 14,
                height: 14,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(
                            alpha: active ? 0.45 : 0.18),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // Ombrage du bas (inset shadow) — affine le volume.
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 26,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.0),
                          Colors.black.withValues(alpha: 0.22),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Icône.
              Icon(
                icon,
                color: active
                    ? const Color(0xFFFFF6E2)
                    : Colors.grey.shade400,
                size: 32,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
