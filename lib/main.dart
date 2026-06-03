import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/game_state.dart';
import 'services/audio_service.dart';
import 'widgets/locomotive_scene.dart';
import 'widgets/map_screen.dart';
import 'widgets/side_scroll_scene.dart';
import 'widgets/cards_screen.dart';
import 'widgets/stat_rings.dart';
import 'widgets/games/hydro_game.dart';
import 'widgets/title_screen.dart';
import 'widgets/loading_screen.dart';
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
      home: const RootScreen(),
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

enum _Phase { title, loading, game }

class _RootScreenState extends State<RootScreen> {
  _Phase _phase = _Phase.title;

  @override
  Widget build(BuildContext context) {
    // Précharge tous les sprites pendant la phase loading AVANT d'entrer
    // dans le wagon : plus d'à-coup au premier déclenchement d'une anim.
    final child = switch (_phase) {
      _Phase.title => TitleScreen(
          key: const ValueKey('title'),
          onStart: ({required fromScratch}) {
            setState(() => _phase = _Phase.loading);
          },
        ),
      _Phase.loading => LoadingScreen(
          key: const ValueKey('loading'),
          onReady: () => setState(() => _phase = _Phase.game),
        ),
      _Phase.game => const WagonScreen(key: ValueKey('wagon_root')),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 800),
      child: child,
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
  bool _inWagon2 = false;
  bool _onMap = false;
  double _heroSpawnX = 0.5;
  bool _inWardrobe = false;
  bool _inHydroGame = false;
  bool _inCards = false;
  // Taille du chien (fraction de la hauteur scène). Réglable via HUD.
  // Chien un peu plus grand pour mieux matcher le husky des sprites de
  // caresse (avant il faisait chiot riquiqui à côté).
  double _dogHeight = 0.17;
  int _dogInteractCount = 0;
  // True while the wagon scene is playing the door_push animation,
  // before the cross-fade to the locomotive. Disables the door FAB so
  // the player can't spam-tap and restart the animation halfway.
  bool _doorPushing = false;
  bool _doorPushRight = false;
  int _doorPushToken = 0;
  // Incrémenté pour entrer/sortir du bain et de la douche (cellier).
  int _bathToken = 0;
  int _showerToken = 0;
  // Mode ajuster (cellier) : déplacer/redimensionner les props + voir coords.
  bool _w2Adjust = false;
  // Destination visée par l'animation de porte en cours : 'loco', 'wagon2'
  // (depuis le wagon 1, porte droite) ou 'wagon1' (depuis le wagon 2, porte
  // gauche). Consommée dans _onDoorPushDone.
  String? _pendingDoor;
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
  // Proximité de la baignoire dans le cellier (position réglable).
  bool get _atBath =>
      _inWagon2 && _near(GameState.instance.bathX, 0.12);
  // Proximité de la douche (panneau) dans le cellier.
  bool get _atShower =>
      _inWagon2 && _near(GameState.instance.showerPanelX, 0.12);

  // Total logs the heroine has thrown into the firebox. Plumbed back
  // to the wagon scene to crank up the smoke trail + speed lines, so
  // the gesture has a visible consequence outside the cab too.
  int _logsThrown = 0;

  static const _stageLabels = ['Vitres remises', 'Tout propre'];
  static const _wagon2Labels = ['En désordre', 'Aménagé'];

  final _audio = AudioService();

  /// Cycle jour/nuit auto : passe day → night → day toutes les
  /// [_dayNightPeriod] minutes. Le bouton lune (FAB) garde la main si
  /// le joueur veut forcer manuellement.
  static const Duration _dayNightPeriod = Duration(minutes: 6);
  Timer? _dayNightTimer;

  String _musicMood() {
    if (_night) return 'night';
    if (GameState.instance.inColdZone) return 'cold';
    return 'day';
  }

  void _refreshMusic() {
    _audio.setMusic(_musicMood());
  }

  @override
  void initState() {
    super.initState();
    _audio.startAmbientTrain();
    _refreshMusic();
    GameState.instance.addListener(_refreshMusic);
    _dayNightTimer = Timer.periodic(_dayNightPeriod, (_) {
      if (!mounted) return;
      setState(() => _night = !_night);
      _refreshMusic();
    });
  }

  @override
  void dispose() {
    _dayNightTimer?.cancel();
    GameState.instance.removeListener(_refreshMusic);
    _heroXNotifier.dispose();
    _audio.stopAll();
    super.dispose();
  }

  void _enterLocomotive() {
    if (_doorPushing) return;
    setState(() {
      _doorPushing = true;
      _doorPushRight = false; // porte gauche
      _pendingDoor = 'loco';
      _doorPushToken++;
    });
  }

  // Wagon 1, porte droite : anim d'ouverture vers la droite -> wagon 2.
  void _enterWagon2() {
    if (_doorPushing) return;
    setState(() {
      _doorPushing = true;
      _doorPushRight = true;
      _pendingDoor = 'wagon2';
      _doorPushToken++;
    });
  }

  // Wagon 2, porte gauche : anim d'ouverture vers la gauche -> wagon 1.
  void _returnToWagon1() {
    if (_doorPushing) return;
    setState(() {
      _doorPushing = true;
      _doorPushRight = false;
      _pendingDoor = 'wagon1';
      _doorPushToken++;
    });
  }

  void _onDoorPushDone() {
    if (!mounted) return;
    switch (_pendingDoor) {
      case 'loco':
        setState(() {
          _doorPushing = false;
          _inLocomotive = true;
        });
        _audio.startFire();
        break;
      case 'wagon2':
        setState(() {
          _doorPushing = false;
          _inWagon2 = true;
          _heroSpawnX = 0.12; // arrive tout près de la porte (gauche) du cellier
        });
        break;
      case 'wagon1':
        setState(() {
          _doorPushing = false;
          _inWagon2 = false;
          _heroSpawnX = SideScrollScene.heroXMax; // revient côté droit
        });
        break;
    }
    _pendingDoor = null;
  }

  void _exitLocomotive() {
    setState(() {
      _inLocomotive = false;
      _heroSpawnX = SideScrollScene.heroXMin;
    });
    _audio.stopFire();
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
    _refreshMusic();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        child: _inCards
            ? CardsScreen(
                key: const ValueKey('cards'),
                onClose: () => setState(() => _inCards = false),
              )
            : _inHydroGame
            ? HydroGameTier1(
                key: const ValueKey('hydro_game'),
                onClose: () => setState(() => _inHydroGame = false),
              )
            : _inWardrobe
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
                    onThrowLog: () {
                      // Nourrir le foyer = brûler 1 bûche de la réserve et
                      // remonter la jauge Bois. Sans bûche, le geste ne donne
                      // rien (la réserve reste à gérer).
                      final gs = GameState.instance;
                      if (gs.itemCount('wood') > 0) {
                        gs.consumeItem('wood');
                        gs.nudgeCardStat('bois', 10);
                        setState(() => _logsThrown++);
                      }
                    },
                    onReturn: _exitLocomotive,
                  )
                : _inWagon2
                    ? _buildWagon(
                        key: const ValueKey('wagon2'), secondWagon: true)
                    : _buildWagon(key: const ValueKey('wagon')),
      ),
    );
  }

  Widget _buildWagon({required Key key, bool secondWagon = false}) {
    return Stack(
      key: key,
      children: [
        Positioned.fill(
          child: SideScrollScene(
            secondWagon: secondWagon,
            wagon2Adjust: secondWagon && _w2Adjust,
            bathToken: _bathToken,
            showerToken: _showerToken,
            initialHeroX: _heroSpawnX,
            wagonStage:
                secondWagon ? GameState.instance.wagon2Stage : _wagonStage,
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
        // HUD survie — les 4 anneaux, centrés en haut.
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Center(
              // HUD = uniquement les 4 anneaux. Les réserves (bois/eau/
              // bouffe) sont visibles là où on les utilise ; les crédits de
              // tirage "Cartes X/X" restent sur l'écran de cartes.
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const StatRingsBar(
                  ringSize: 46,
                  emojiSize: 20,
                  mainAxisSize: MainAxisSize.min,
                  alignment: MainAxisAlignment.center,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          bottom: 16,
          right: 16,
          child: SafeArea(
            // Scrollable : en paysage la pile de boutons dépasse la hauteur
            // de l'écran ; reverse=true garde le bas visible, on remonte pour
            // atteindre les boutons du haut.
            child: SingleChildScrollView(
              reverse: true,
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              // Ordre : boutons dev/secondaires EN HAUT (on scrolle pour les
              // atteindre), boutons essentiels EN BAS — avec reverse:true le
              // bas est toujours visible. L'ACTION contextuelle est en dernier
              // (= tout en bas = jamais coupée).
              children: [
                FloatingActionButton.small(
                  heroTag: 'toggle_run',
                  tooltip: _running ? 'Arrêter le train' : 'Démarrer le train',
                  onPressed: _toggleRun,
                  child: Icon(_running ? Icons.pause : Icons.play_arrow),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'cycle_wagon_stage',
                  tooltip: _inWagon2
                      ? 'Cellier: ${_wagon2Labels[GameState.instance.wagon2Stage.clamp(0, 1)]}'
                      : 'Wagon: ${_stageLabels[_wagonStage.clamp(0, _stageLabels.length - 1)]}',
                  onPressed: () {
                    setState(() {
                      if (_inWagon2) {
                        final gs = GameState.instance;
                        gs.wagon2Stage = (gs.wagon2Stage + 1) % 2;
                        gs.save();
                      } else {
                        _wagonStage = (_wagonStage + 1) % 2;
                      }
                    });
                    _audio.playSfx('clean');
                  },
                  child: const Icon(Icons.cleaning_services),
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
                  heroTag: 'toggle_dance',
                  tooltip: _dancing ? 'Arrêter de danser' : 'Danser',
                  onPressed: () => setState(() => _dancing = !_dancing),
                  child: Icon(_dancing ? Icons.stop : Icons.celebration),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'open_map',
                  tooltip: 'La carte du voyage',
                  onPressed: () => setState(() => _onMap = true),
                  child: const Icon(Icons.map),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'open_cards',
                  tooltip: 'Le voyage (cartes)',
                  backgroundColor: const Color(0xFFE8B96B),
                  foregroundColor: const Color(0xFF2A2018),
                  onPressed: () => setState(() => _inCards = true),
                  child: const Icon(Icons.style),
                ),
                const SizedBox(height: 12),
                // Cellier seulement : mode ajuster (placer/redimensionner +
                // coordonnées). Pincer un prop = changer sa taille.
                if (secondWagon) ...[
                  FloatingActionButton.small(
                    heroTag: 'w2_adjust',
                    tooltip: _w2Adjust
                        ? 'Terminer le placement'
                        : 'Ajuster les objets',
                    backgroundColor:
                        _w2Adjust ? const Color(0xFFE8B96B) : null,
                    foregroundColor:
                        _w2Adjust ? const Color(0xFF2A2018) : null,
                    onPressed: () => setState(() => _w2Adjust = !_w2Adjust),
                    child: Icon(_w2Adjust ? Icons.check : Icons.edit),
                  ),
                  const SizedBox(height: 12),
                ],
                // Bouton ACTION contextuel — toujours visible (tout en bas).
                AnimatedBuilder(
                  animation: GameState.instance,
                  builder: (_, __) => _actionFab(),
                ),
              ],
            ),
            ),
          ),
        ),
      ],
    );
  }

  /// Mini-jauge horizontale icone + barre 80px. Couleur passe au rouge
  /// quand la valeur descend sous 25 %.
  Widget _actionFab() {
    IconData icon = Icons.help_outline;
    VoidCallback? action;

    if (_atLeftDoor && !_doorPushing) {
      // Porte gauche : loco (wagon 1) ou retour wagon 1 (depuis wagon 2).
      icon = Icons.meeting_room;
      action = _inWagon2 ? _returnToWagon1 : _enterLocomotive;
    } else if (_atRightDoor && !_doorPushing && !_inWagon2) {
      // Porte droite du wagon 1 : ouverture vers le 2e wagon.
      icon = Icons.meeting_room;
      action = _enterWagon2;
    } else if (_atBath) {
      // Cellier, près de la baignoire : entrer / sortir du bain.
      // (+moral géré dans la scène, à l'entrée uniquement.)
      icon = Icons.bathtub;
      action = () => setState(() => _bathToken++);
    } else if (_atShower) {
      // Cellier, près de la douche : se doucher / arrêter.
      icon = Icons.shower;
      action = () => setState(() => _showerToken++);
    } else if (!_inWagon2 && _atBed) {
      icon = Icons.bed;
      action = () => setState(() => _lieDownToken++);
    } else if (!_inWagon2 && _atNotebook) {
      icon = Icons.menu_book;
      action = () {
        _triggerSpecial('read', frames: 49);
        // Lire réconforte : +moral.
        GameState.instance.nudgeCardStat('moral', 10);
      };
    } else if (!_inWagon2 && _atFilter) {
      final glasses = GameState.instance.waterTankGlasses;
      if (glasses == 0) {
        // Vide → remplir.
        icon = Icons.water;
        action = () {
          GameState.instance
              .setWaterTankGlasses(GameState.waterTankMax);
        };
      } else {
        // Plein ou partiel → boire un verre.
        icon = Icons.local_drink;
        action = () {
          // Boire = 1 verre de la cuve (réserve) + remonte la jauge Soif.
          GameState.instance.nudgeCardStat('soif', 10);
          _triggerSpecial('use_back', frames: 24,
              next: 'drink', nextFrames: 25);
          _audio.playSfx('drink');
          GameState.instance.setWaterTankGlasses(glasses - 1);
        };
      }
    } else if (!_inWagon2 && _atDog) {
      icon = Icons.pets;
      action = () {
        _dogInteractCount++;
        if (_dogInteractCount.isOdd) {
          _triggerSpecial('pet_dog', frames: 49);
        } else {
          _triggerSpecial('crouch', frames: 49);
        }
        // Câliner le chien remonte le moral.
        GameState.instance.nudgeCardStat('moral', 10);
        _audio.playSfx('dog_bark');
      };
    } else if (!_inWagon2 && _atStove) {
      icon = Icons.soup_kitchen;
      action = () => setState(() => _cookToken++);
    } else if (!_inWagon2 && _atHydro) {
      icon = Icons.yard;
      action = () => setState(() => _inHydroGame = true);
    } else if (!_inWagon2 && _atLamp) {
      icon = GameState.instance.lampOn
          ? Icons.lightbulb
          : Icons.lightbulb_outline;
      action = () {
        setState(() => GameState.instance.toggleLamp());
        _audio.playSfx('lamp_toggle');
      };
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
