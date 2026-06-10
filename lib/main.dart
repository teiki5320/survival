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
import 'widgets/games/roof_defense_game.dart';
import 'widgets/title_screen.dart';
import 'widgets/loading_screen.dart';
import 'widgets/opening_cinematic.dart';
import 'widgets/tutorial_overlay.dart';
import 'widgets/wardrobe_screen.dart';
import 'widgets/workshop_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Cache d'images : plafond RAISONNABLE pour éviter l'OOM (l'app a grossi à
  // ~1650 PNG / 200 Mo ; un cache à 1.5 Go + préchargement total faisait
  // crasher iOS par dépassement mémoire). 450 Mo suffit pour les anims actives
  // (le LRU évince les frames anciennes ; au pire une petite saccade, jamais
  // de crash).
  PaintingBinding.instance.imageCache.maximumSizeBytes = 450 * 1024 * 1024;
  PaintingBinding.instance.imageCache.maximumSize = 800;
  // Affiche l'exception À L'ÉCRAN (au lieu d'un écran muet) -> diagnostic.
  ErrorWidget.builder = (FlutterErrorDetails d) => Material(
        color: const Color(0xFF2A0A0A),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Text(
              'ERREUR:\n${d.exception}',
              style: const TextStyle(color: Color(0xFFFFC0C0), fontSize: 12),
            ),
          ),
        ),
      );
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

enum _Phase { title, loading, opening, game }

class _RootScreenState extends State<RootScreen> {
  _Phase _phase = _Phase.title;

  // Après le chargement : cinématique d'ouverture si pas encore vue, sinon jeu.
  void _afterLoading() {
    if (!GameState.instance.introCinematicSeen) {
      setState(() => _phase = _Phase.opening);
    } else {
      setState(() => _phase = _Phase.game);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Précharge tous les sprites pendant la phase loading AVANT d'entrer
    // dans le wagon : plus d'à-coup au premier déclenchement d'une anim.
    final child = switch (_phase) {
      _Phase.title => TitleScreen(
          key: const ValueKey('title'),
          onStart: ({required fromScratch}) {
            // Nouvelle partie = vrai reset (vide les flags : chien/objets/sœur
            // ne persistent plus de la sauvegarde précédente).
            if (fromScratch) GameState.instance.resetForNewGame();
            setState(() => _phase = _Phase.loading);
          },
        ),
      _Phase.loading => LoadingScreen(
          key: const ValueKey('loading'),
          onReady: _afterLoading,
        ),
      _Phase.opening => OpeningCinematic(
          key: const ValueKey('opening'),
          onDone: () {
            GameState.instance.markIntroCinematicSeen();
            setState(() => _phase = _Phase.game);
          },
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

class _WagonScreenState extends State<WagonScreen>
    with SingleTickerProviderStateMixin {
  // Wagon restoration progression: 0 dirty → 1 swept → 2 windowed → 3 clean.
  // Cycles on tap of the "nettoyer" FAB; will be driven by gameplay later.
  int _wagonStage = 0;
  bool _running = true;
  bool _night = false;
  bool _dancing = false;
  int _lieDownToken = 0;

  bool _inLocomotive = false;
  bool _inWagon2 = false;
  bool _onMap = false;
  double _heroSpawnX = 0.5;
  bool _inWardrobe = false;
  bool _inHydroGame = false;
  bool _inCards = false;
  bool _inShootGame = false; // mini-jeu défense du toit (gares)
  bool _inWorkshop = false; // atelier + quotidien + collection (depuis la map)
  // Combat lancé depuis une gare de la map (la map = le menu). On mémorise
  // l'index de gare pour appliquer le score (récompenses + flags) au retour.
  bool _shootFromGare = false;
  int _shootGareIndex = 0;
  // Vrai si la map a été ouverte depuis la loco (pour y revenir en quittant).
  bool _mapFromLoco = false;
  // Taille du chien (fraction de la hauteur scène). Réglable via HUD.
  // Chien un peu plus grand pour mieux matcher le husky des sprites de
  // caresse (avant il faisait chiot riquiqui à côté).
  final double _dogHeight = 0.17;
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
  // Mode ajuster wagon 1 (debug) : lampe/bac/filtre/poêle déplaçables+taille.
  bool _w1Adjust = false;
  // Caresse du chien (Shen + husky).
  int _petDogToken = 0;
  // Cuisinière (cuisine + mange au sol) / poêle à bois (allumage) / bac (semer).
  int _cuisiniereToken = 0;
  int _poeleToken = 0;
  int _bacToken = 0;
  // Interaction sœur (test manuel) : alterne lecture / câlin à chaque tap.
  int _duoToken = 0;
  String _duoAnimToPlay = 'readduo';
  // Positions vivantes de la sœur / du chien (ils se baladent dans le wagon).
  double _sisterLiveX = 0.33;
  double _dogLiveX = 0.525;
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
  // Un objet n'est INTERACTIF que s'il est débloqué (= visible). Même source
  // de vérité que la visibilité : GameState.propUnlocked / dogShown /
  // sisterShown. Pas d'objet invisible mais cliquable.
  bool _unlocked(String key) => GameState.instance.propUnlocked(key);
  bool get _atBed =>
      _unlocked('bed') && (_heroX - SideScrollScene.bedCenterX).abs() < 0.05;
  // Zones interactives autour des props.
  bool _near(double centerX, [double tol = 0.05]) =>
      (_heroX - centerX).abs() < tol;
  bool get _atNotebook =>
      _unlocked('notebook') && _near(SideScrollScene.notebookCenterX);
  // Lampe / bac de culture / filtre sont des props AJUSTABLES : leur position
  // vit dans GameState.wagon1Props (et plus dans des constantes figées).
  bool get _atFilter =>
      _unlocked('filter') && _near(GameState.instance.w1x('filtre'));
  bool get _atLamp =>
      _unlocked('lamp') && _near(GameState.instance.w1x('lamp'));
  bool get _atStove =>
      _unlocked('stove') && _near(GameState.instance.w1x('gaziniere'));
  bool get _atPoele =>
      _unlocked('stove') && _near(GameState.instance.w1x('poele'));
  bool get _atHydro =>
      _unlocked('hydro') && _near(GameState.instance.w1x('bac'));
  bool get _atDog => GameState.instance.dogShown && _near(_dogLiveX, 0.10);
  // Proximité de la baignoire dans le cellier (position réglable).
  bool get _atBath =>
      _inWagon2 && _unlocked('bath') && _near(GameState.instance.bathX, 0.12);
  // Proximité de la douche (panneau) dans le cellier.
  bool get _atShower =>
      _inWagon2 &&
      _unlocked('shower') &&
      _near(GameState.instance.showerPanelX, 0.12);
  // Proximité de la petite sœur (wagon 1, position vivante).
  bool get _atSister =>
      !_inWagon2 && GameState.instance.sisterShown && _near(_sisterLiveX, 0.08);

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

  // Rideau noir pour masquer les changements de scène ET le passage de porte.
  // Le fondu DÉMARRE dès le clic et s'assombrit pendant que Shen ouvre la porte
  // (~1 s) : on voit le début de l'anim, puis l'écran est NOIR avant le moindre
  // "saut" (perso loco plus gros, swap de scène...), et on révèle la nouvelle
  // pièce. 0 = transparent, 1 = noir plein.
  late final AnimationController _curtain = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 170),
    reverseDuration: const Duration(milliseconds: 240),
  );

  void _startDoorFade() {
    _curtain.animateTo(1.0,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic);
  }

  /// Effectue [applySwap] (le setState qui change de scène) à l'abri du rideau :
  /// on force le noir complet, on swap, on maintient un court instant (le temps
  /// que la nouvelle scène se monte), puis on révèle.
  void _curtainSwap(VoidCallback applySwap) {
    if (!mounted) return;
    // Si le fondu n'a pas été lancé au clic (sortie loco/map), on assombrit ici.
    if (_curtain.value < 1.0 && !_curtain.isAnimating) {
      _curtain.forward(from: _curtain.value).whenComplete(() {
        _doCurtainSwap(applySwap);
      });
      return;
    }
    _doCurtainSwap(applySwap);
  }

  void _doCurtainSwap(VoidCallback applySwap) {
    if (!mounted) return;
    _curtain.value = 1.0; // noir complet garanti avant le swap
    setState(applySwap);
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) _curtain.reverse();
    });
  }

  @override
  void initState() {
    super.initState();
    _audio.startAmbientTrain();
    _refreshMusic();
    GameState.instance.addListener(_refreshMusic);
    GameState.instance.setNight(_night);
    _dayNightTimer = Timer.periodic(_dayNightPeriod, (_) {
      if (!mounted) return;
      setState(() => _night = !_night);
      GameState.instance.setNight(_night);
      _refreshMusic();
    });
  }

  @override
  void dispose() {
    _dayNightTimer?.cancel();
    GameState.instance.removeListener(_refreshMusic);
    _heroXNotifier.dispose();
    _curtain.dispose();
    _audio.stopAll();
    super.dispose();
  }

  // Anims jouées DANS la loco. On les décode à l'avance (dès le clic sur la
  // porte : l'anim d'ouverture dure ~1 s, largement le temps de tout décoder)
  // pour qu'elles ne saccadent pas au 1er affichage dans la cabine.
  static const Map<String, int> _locoAnims = {
    'carry_walk': 49,
    'warm_hands': 49,
    'open_door': 20,
    'walk_right': 49,
    'idle_right': 49,
  };

  void _warmLocoAnims() {
    if (!mounted) return;
    _locoAnims.forEach((p, n) {
      for (int i = 1; i <= n; i++) {
        precacheImage(AssetImage('assets/characters/${p}_$i.png'), context)
            .catchError((_) {});
      }
    });
  }

  void _enterLocomotive() {
    if (_doorPushing || _curtain.isAnimating) return;
    _warmLocoAnims(); // décode les sprites loco pendant l'anim de porte
    _startDoorFade(); // l'écran s'assombrit pendant qu'elle ouvre la porte
    setState(() {
      _doorPushing = true;
      _doorPushRight = false; // porte gauche
      _pendingDoor = 'loco';
      _doorPushToken++;
    });
  }

  // Wagon 1, porte droite : anim d'ouverture vers la droite -> wagon 2.
  void _enterWagon2() {
    if (_doorPushing || _curtain.isAnimating) return;
    _startDoorFade();
    setState(() {
      _doorPushing = true;
      _doorPushRight = true;
      _pendingDoor = 'wagon2';
      _doorPushToken++;
    });
  }

  // Wagon 2, porte gauche : anim d'ouverture vers la gauche -> wagon 1.
  void _returnToWagon1() {
    if (_doorPushing || _curtain.isAnimating) return;
    _startDoorFade();
    setState(() {
      _doorPushing = true;
      _doorPushRight = false;
      _pendingDoor = 'wagon1';
      _doorPushToken++;
    });
  }

  void _onDoorPushDone() {
    if (!mounted) return;
    final dest = _pendingDoor;
    _pendingDoor = null;
    // L'anim de porte a joué EN ENTIER (20 frames). On échange maintenant la
    // scène DERRIÈRE le rideau noir : le perso de la loco est rendu plus gros
    // (caméra rapprochée), sans le rideau on voyait un "saut" au passage.
    _curtainSwap(() {
      _doorPushing = false;
      switch (dest) {
        case 'loco':
          _inLocomotive = true;
          break;
        case 'wagon2':
          _inWagon2 = true;
          _heroSpawnX = 0.12; // arrive tout près de la porte (gauche) du cellier
          break;
        case 'wagon1':
          _inWagon2 = false;
          _heroSpawnX = SideScrollScene.heroXMax; // revient côté droit
          break;
      }
    });
    if (dest == 'loco') _audio.startFire();
  }

  void _exitLocomotive() {
    if (_curtain.isAnimating) return;
    _curtainSwap(() {
      _inLocomotive = false;
      _heroSpawnX = SideScrollScene.heroXMin;
    });
    _audio.stopFire();
  }

  void _exitMap() {
    if (_mapFromLoco) _warmLocoAnims(); // évite le stutter au retour en loco
    setState(() {
      _onMap = false;
      // Revenir à l'endroit d'où la map a été ouverte (loco ou wagon).
      if (_mapFromLoco) {
        _mapFromLoco = false;
        _inLocomotive = true;
      } else {
        _heroSpawnX = SideScrollScene.heroXMax;
      }
    });
    if (_inLocomotive) _audio.startFire();
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
    GameState.instance.setNight(_night);
    _refreshMusic();
  }

  /// Mode debug actif ? (révèle les outils de test : nettoyage, jour/nuit,
  /// température, danse, ajustement des props, et le duel du combat).
  bool get _debug => GameState.instance.debugMode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
        // Transition courte : un fondu long faisait apparaître le perso de la
        // loco (bien plus grand, caméra rapprochée) en surimpression sur le
        // wagon pendant ~0,5 s ("saut"). Court = quasi-coupure, plus de saut.
        duration: const Duration(milliseconds: 200),
        // On NE superpose PAS l'ancienne scène : elle disparaît tout de suite,
        // la nouvelle apparaît seule (fondu depuis le noir) -> aucun chevauchement
        // de deux persos de tailles différentes.
        layoutBuilder: (currentChild, previousChildren) =>
            currentChild ?? const SizedBox.shrink(),
        child: _inShootGame
            ? RoofDefenseGame(
                key: const ValueKey('shoot_game'),
                gareIndex: _shootGareIndex,
                onExit: () => setState(() {
                  _inShootGame = false;
                  if (_shootFromGare) {
                    _shootFromGare = false;
                    _onMap = true; // retour à la map (le menu)
                  }
                }),
                // Lancé depuis une gare -> mode gare (score /100). Le score est
                // appliqué (ressources + flags) puis on revient à la map.
                onResult: _shootFromGare
                    ? (score) {
                        GameState.instance
                            .applyCombatRewards(_shootGareIndex, score);
                        setState(() {
                          _inShootGame = false;
                          _shootFromGare = false;
                          _onMap = true;
                        });
                      }
                    : null,
              )
            : _inCards
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
            : _inWorkshop
            ? WorkshopScreen(
                key: const ValueKey('workshop'),
                onClose: () => setState(() {
                  _inWorkshop = false;
                  _onMap = true; // retour à la map (le menu)
                }),
              )
            : _onMap
            ? MapScreen(
                key: const ValueKey('map'),
                onClose: _exitMap,
                // La map est le menu : taper une gare lance son combat.
                onGareSelected: (i) => setState(() {
                  _shootGareIndex = i;
                  _shootFromGare = true;
                  _onMap = false;
                  _inShootGame = true;
                }),
                onOpenWorkshop: () => setState(() {
                  _onMap = false;
                  _inWorkshop = true;
                }),
                // Entrée des cartes narratives depuis la map (jeu normal).
                onOpenCards: () => setState(() {
                  _onMap = false;
                  _inCards = true;
                }),
              )
            : _inLocomotive
                ? LocomotiveScene(
                    key: const ValueKey('locomotive'),
                    night: _night,
                    logsThrown: _logsThrown,
                    onOpenMap: () => setState(() {
                      _inLocomotive = false;
                      _onMap = true;
                      _mapFromLoco = true;
                    }),
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
          // Rideau noir : par-dessus tout, masque le swap de scène (porte).
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _curtain,
                builder: (_, __) => _curtain.value <= 0
                    ? const SizedBox.shrink()
                    : Opacity(
                        opacity: _curtain.value.clamp(0.0, 1.0),
                        child: const ColoredBox(color: Colors.black),
                      ),
              ),
            ),
          ),
          // Bulles de TUTO d'intro : seulement sur la vue wagon 1, une fois.
          if (!_onMap &&
              !_inCards &&
              !_inHydroGame &&
              !_inWardrobe &&
              !_inWorkshop &&
              !_inShootGame &&
              !_inLocomotive &&
              !_inWagon2 &&
              !_doorPushing &&
              GameState.instance.introCinematicSeen &&
              !GameState.instance.tipSeen('intro_done'))
            IntroTutorial(
              onDone: () {
                GameState.instance.markTipSeen('intro_done');
                setState(() {});
              },
            ),
        ],
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
            wagon1Adjust: !secondWagon && _w1Adjust,
            bathToken: _bathToken,
            cuisiniereToken: _cuisiniereToken,
            poeleToken: _poeleToken,
            bacToken: _bacToken,
            showerToken: _showerToken,
            petDogToken: _petDogToken,
            duoToken: _duoToken,
            duoAnim: _duoAnimToPlay,
            onSisterX: (x) => setState(() => _sisterLiveX = x),
            onDogX: (x) => setState(() => _dogLiveX = x),
            initialHeroX: _heroSpawnX,
            // En mode debug : wagon NETTOYÉ (stage 1) + tous les objets
            // (gérés par propUnlocked). En jeu : le cellier (wagon 2) est
            // ENCOMBRÉ au départ et son rangement se GAGNE dans l'histoire
            // (flag asset_wagon2, gare 6) ou via le FAB debug (wagon2Stage).
            wagonStage: GameState.instance.debugMode
                ? 1
                : (secondWagon
                    ? ((GameState.instance.wagon2Stage >= 1 ||
                            GameState.instance.cardFlags
                                .contains('asset_wagon2'))
                        ? 1
                        : 0)
                    : _wagonStage),
            running: _running,
            night: _night,
            dancing: _dancing,
            lieDownToken: _lieDownToken,
            logsThrown: _logsThrown,
            doorPushToken: _doorPushToken,
            doorPushRight: _doorPushRight,
            onDoorPushDone: _onDoorPushDone,
            onOpenWardrobe: () => setState(() => _inWardrobe = true),
            // La carte est désormais dans la LOCOMOTIVE (plus dans le wagon).
            onOpenMap: null,
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
              final wasPoele = _atPoele;
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
                  wasPoele != _atPoele ||
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
                  ringSize: 34,
                  emojiSize: 15,
                  mainAxisSize: MainAxisSize.min,
                  alignment: MainAxisAlignment.center,
                ),
              ),
            ),
          ),
        ),
        // Thermomètre (haut-gauche) : montre la température cabine.
        Positioned(
          top: 8,
          left: 8,
          child: SafeArea(child: _thermometer()),
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
                // ===== OUTILS DE DEBUG (cachés du vrai jeu) =====
                // Visibles seulement quand le mode debug est activé (bouton 🐞
                // en bas à gauche). En jeu normal : nettoyage/jour-nuit/temp
                // sont pilotés par l'histoire et l'environnement, pas à la main.
                if (_debug) ...[
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
                    child:
                        Icon(_night ? Icons.wb_sunny : Icons.nightlight_round),
                  ),
                  const SizedBox(height: 12),
                  // Test : cycle la température (chaud -> frais -> gel).
                  FloatingActionButton.small(
                    heroTag: 'temp_test',
                    tooltip: 'Température (test)',
                    onPressed: () {
                      final gs = GameState.instance;
                      final next = gs.cabinTemp > 14
                          ? 6.0
                          : (gs.cabinTemp > 0 ? -6.0 : 20.0);
                      gs.setCabinTemp(next);
                      setState(() {});
                    },
                    child: const Icon(Icons.thermostat),
                  ),
                  const SizedBox(height: 12),
                  FloatingActionButton.small(
                    heroTag: 'toggle_dance',
                    tooltip: _dancing ? 'Arrêter de danser' : 'Danser',
                    onPressed: () => setState(() => _dancing = !_dancing),
                    child: Icon(_dancing ? Icons.stop : Icons.celebration),
                  ),
                  const SizedBox(height: 12),
                  // Cellier seulement : mode ajuster (placer/redimensionner).
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
                  // Wagon 1 seulement : ajuster lampe/bac/filtre/poêle.
                  if (!secondWagon) ...[
                    FloatingActionButton.small(
                      heroTag: 'w1_adjust',
                      tooltip: _w1Adjust
                          ? 'Terminer le placement'
                          : 'Ajuster lampe/bac/filtre/poêle',
                      backgroundColor:
                          _w1Adjust ? const Color(0xFFE8B96B) : null,
                      foregroundColor:
                          _w1Adjust ? const Color(0xFF2A2018) : null,
                      onPressed: () => setState(() => _w1Adjust = !_w1Adjust),
                      child: Icon(_w1Adjust ? Icons.check : Icons.edit),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Accès rapide DEBUG à la map + aux cartes. En JEU NORMAL :
                  // la map s'ouvre depuis la LOCO, et les cartes depuis la map.
                  FloatingActionButton.small(
                    heroTag: 'open_map',
                    tooltip: 'La carte du voyage (debug)',
                    onPressed: () => setState(() {
                      _onMap = true;
                      _mapFromLoco = false;
                    }),
                    child: const Icon(Icons.map),
                  ),
                  const SizedBox(height: 12),
                  FloatingActionButton.small(
                    heroTag: 'open_cards',
                    tooltip: 'Le voyage (cartes) (debug)',
                    backgroundColor: const Color(0xFFE8B96B),
                    foregroundColor: const Color(0xFF2A2018),
                    onPressed: () => setState(() => _inCards = true),
                    child: const Icon(Icons.style),
                  ),
                  const SizedBox(height: 12),
                ],
                // ===== BOUTON DE JEU (toujours visible) =====
                // Seul le bouton d'ACTION contextuel reste en jeu normal.
                // Bouton ACTION contextuel + bulle de hint « 1re utilisation ».
                AnimatedBuilder(
                  animation: GameState.instance,
                  builder: (_, __) {
                    final h = _computeHint();
                    final showHint =
                        h != null && !GameState.instance.tipSeen(h.id);
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (showHint) ...[
                          HintBubble(text: h.text),
                          const SizedBox(height: 10),
                        ],
                        _actionFab(),
                      ],
                    );
                  },
                ),
              ],
            ),
            ),
          ),
        ),
        // Interrupteur du MODE DEBUG (bas-gauche) : un seul bouton révèle/masque
        // tous les outils de test. Vert + « DEBUG ON » quand actif, ambré
        // « debug » quand inactif. Toujours bien visible.
        Positioned(
          left: 10,
          bottom: 10,
          child: SafeArea(
            child: AnimatedBuilder(
              animation: GameState.instance,
              builder: (_, __) {
                final on = GameState.instance.debugMode;
                return GestureDetector(
                  onTap: () {
                    GameState.instance.toggleDebug();
                    setState(() {});
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: on
                          ? const Color(0xFF3A8A3A)
                          : Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: on
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.5),
                          width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bug_report,
                            size: 20, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          on ? 'DEBUG ON' : 'debug',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Mini-jauge horizontale icone + barre 80px. Couleur passe au rouge
  /// quand la valeur descend sous 25 %.
  // Petit thermomètre HUD : tube + °C, bleu si Shen a froid.
  Widget _thermometer() {
    return AnimatedBuilder(
      animation: GameState.instance,
      builder: (_, __) {
        final gs = GameState.instance;
        final t = gs.cabinTemp;
        final cold = gs.feltCold;
        final f = ((t + 15) / 43).clamp(0.0, 1.0); // -15..28 -> 0..1
        final fill = cold
            ? const Color(0xFF5BA8E0)
            : (t > 18 ? const Color(0xFFE08A3C) : const Color(0xFFE0C060));
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2E),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: const Color(0xFF555555), width: 1),
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: f.clamp(0.05, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: fill,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${t.round()}°',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  if (cold)
                    const Text('❄ froid',
                        style:
                            TextStyle(color: Color(0xFF8FD0FF), fontSize: 10)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Hint contextuel « 1re utilisation » selon la position de Shen. Suit le
  /// MÊME ordre de priorité que [_actionFab] (sinon le hint ne matche pas
  /// l'action proposée). null = pas de hint pour ce contexte.
  ({String id, String text})? _computeHint() {
    if (_doorPushing) return null;
    if (_atLeftDoor) {
      return (
        id: 'go_loco',
        text: _inWagon2
            ? 'Retour au wagon principal.'
            : 'Porte vers la locomotive : c\'est là qu\'on ouvre la carte du voyage.'
      );
    }
    if (_atRightDoor && !_inWagon2) {
      // Le cellier est accessible dès le départ, mais ENCOMBRÉ tant que son
      // rangement n'est pas gagné dans l'histoire (wagon2Stage 0 = en désordre).
      return (id: 'go_cellier', text: 'Le cellier (2e wagon).');
    }
    if (_atBath) return (id: 'bath', text: 'Un bon bain pour te détendre.');
    if (_atShower) return (id: 'shower', text: 'Une douche pour te laver.');
    if (_atSister) {
      return (id: 'sister', text: 'Ta sœur : un câlin remonte le moral.');
    }
    if (!_inWagon2 && _atBed) {
      return (id: 'bed', text: 'Dors ici pour récupérer des forces.');
    }
    if (!_inWagon2 && _atNotebook) {
      return (id: 'notebook', text: 'Lis un moment : ça apaise.');
    }
    if (!_inWagon2 && _atFilter) {
      return (id: 'filter', text: 'Remplis le filtre, puis bois (jauge Soif).');
    }
    if (!_inWagon2 && _atDog) {
      return (id: 'dog', text: 'Caresse le chien : ça réchauffe le cœur.');
    }
    if (!_inWagon2 && _atHydro) {
      final ripe = GameState.instance.bacGrowth >= 1.0;
      final sown = GameState.instance.bacSown;
      return (
        id: 'hydro',
        text: ripe
            ? 'Récolte les fruits (+ Faim).'
            : sown
                ? 'Ça pousse… reviens quand c\'est mûr.'
                : 'Sème des graines dans le bac.'
      );
    }
    if (!_inWagon2 && _atLamp) {
      return (id: 'lamp', text: 'Allume ou éteins la lampe.');
    }
    if (!_inWagon2 && _atStove) {
      return (id: 'cuisiniere', text: 'Cuisine un repas (jauge Faim).');
    }
    if (!_inWagon2 && _atPoele) {
      return (
        id: 'poele',
        text: GameState.instance.poeleOn
            ? 'Éteindre le poêle.'
            : 'Allumer le poêle (brûle du bois, réchauffe).'
      );
    }
    return null;
  }

  Widget _actionFab() {
    IconData icon = Icons.help_outline;
    VoidCallback? action;

    if (_atLeftDoor && !_doorPushing) {
      // Porte gauche : loco (wagon 1) ou retour wagon 1 (depuis wagon 2).
      icon = Icons.meeting_room;
      action = _inWagon2 ? _returnToWagon1 : _enterLocomotive;
    } else if (_atRightDoor && !_doorPushing && !_inWagon2) {
      // Porte droite du wagon 1 : ouverture vers le 2e wagon (cellier).
      // Accessible dès le départ ; le cellier est juste ENCOMBRÉ tant que son
      // rangement n'est pas gagné dans l'histoire (wagon2Stage).
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
    } else if (_atSister) {
      // Test : tap près de la sœur -> alterne lecture / câlin.
      icon = Icons.favorite;
      action = () => setState(() {
            _duoAnimToPlay =
                _duoAnimToPlay == 'readduo' ? 'sister_hug' : 'readduo';
            _duoToken++;
            GameState.instance.nudgeCardStat('moral', 8);
          });
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
        // Sprite Shen + husky (caresse -> câlin), bon chien.
        setState(() => _petDogToken++);
        GameState.instance.nudgeCardStat('moral', 10);
        _audio.playSfx('dog_bark');
      };
    } else if (!_inWagon2 && _atHydro) {
      // Bac de culture : semer / récolter (séquence dans la scène). Plus de
      // fenêtre de mini-jeu serre.
      icon = Icons.yard;
      action = () => setState(() => _bacToken++);
    } else if (!_inWagon2 && _atLamp) {
      icon = GameState.instance.lampOn
          ? Icons.lightbulb
          : Icons.lightbulb_outline;
      action = () {
        setState(() => GameState.instance.toggleLamp());
        _audio.playSfx('lamp_toggle');
      };
    } else if (!_inWagon2 && _atStove) {
      // Cuisinière : Shen se tourne, la cuisinière s'allume 5 s, puis elle
      // mange au sol (séquence pilotée dans la scène).
      icon = Icons.local_dining;
      action = () => setState(() => _cuisiniereToken++);
    } else if (!_inWagon2 && _atPoele) {
      // Poêle à bois : allumer/éteindre (brûle du bois doucement).
      icon = Icons.local_fire_department;
      action = () => setState(() => _poeleToken++);
    } else if (_doorPushing) {
      icon = Icons.meeting_room;
    }

    // Hint « 1re utilisation » : marqué vu dès qu'on utilise l'objet.
    final hint = _computeHint();
    final baseAction = action;
    final onTapAction = baseAction == null
        ? null
        : () {
            if (hint != null) GameState.instance.markTipSeen(hint.id);
            baseAction();
          };
    final bool active = onTapAction != null;
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
          onTap: onTapAction,
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
