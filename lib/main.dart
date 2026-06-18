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
import 'widgets/title_screen.dart';
import 'widgets/loading_screen.dart';
import 'widgets/opening_cinematic.dart';
import 'widgets/tutorial_overlay.dart';
import 'widgets/wardrobe_screen.dart';
import 'widgets/shop_screen.dart';

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
  // Wagon courant : 0 = salon (sœur/chien/lit), 1 = atelier (cuisinière, poêle,
  // lampe, bac, filtre), 2 = cellier (bain, douche, armoire, lanternes).
  int _wagon = 0;
  bool get _inLiving => _wagon == 0;
  bool get _inAtelier => _wagon == 1;
  bool get _inCellier => _wagon == 2;
  bool _onMap = false;
  double _heroSpawnX = 0.5;
  bool _inWardrobe = false;
  bool _inShop = false;
  bool _inCards = false;
  bool _cardsFromLoco = false; // cartes ouvertes via le voyage (loco->map) : y revenir
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
  // Mode ajuster salon (debug) : carnet/secours/gamelle/carte déplaçables.
  bool _salonAdjust = false;
  // Bannière « Nouvel objet débloqué ! » (file dans GameState.pendingUnlocks).
  String? _unlockBanner;
  Timer? _unlockTimer;
  void _checkUnlocks() {
    if (_unlockBanner != null) return;
    if (_inCards || _onMap || _inLocomotive) return;
    final name = GameState.instance.popUnlock();
    if (name == null) return;
    setState(() => _unlockBanner = 'Nouvel objet : $name !');
    _unlockTimer?.cancel();
    _unlockTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted) setState(() => _unlockBanner = null);
    });
  }

  // Anti-spam du moral « confort » (lire/chien/sœur) : ces gestes ne coûtent
  // rien (cosy), mais sans frein le moral montait à 100 d'un tap. Cooldown
  // partagé : un seul gain de moral confort toutes les 45 s. Le timestamp vit
  // dans GameState (singleton) pour SURVIVRE au remontage de l'écran (un
  // aller-retour loco/map ne doit pas réarmer le cooldown = exploit).
  void _comfortMoral(int amount) => GameState.instance.tryComfortMoral(amount);

  // Déclenche un float ancré sur Shen dans la scène (retour d'action / refus).
  void _heroFloat(String text) {
    setState(() {
      _heroFloatText = text;
      _heroFloatToken++;
    });
  }

  // Activation du debug par TRIPLE-TAP caché (plus de bouton visible en jeu).
  int _debugTaps = 0;
  Timer? _debugTapTimer;
  void _debugCornerTap() {
    _debugTaps++;
    _debugTapTimer?.cancel();
    _debugTapTimer = Timer(const Duration(milliseconds: 900), () {
      _debugTaps = 0;
    });
    if (_debugTaps >= 3) {
      _debugTaps = 0;
      GameState.instance.toggleDebug();
      setState(() {});
    }
  }
  // Caresse du chien (Shen + husky).
  int _petDogToken = 0;
  // Cuisinière (cuisine + mange au sol) / poêle à bois (allumage) / bac (semer).
  int _cuisiniereToken = 0;
  int _poeleToken = 0;
  int _bacToken = 0;
  // Float ancré sur Shen, piloté depuis main (boire au filtre / refus bois).
  int _heroFloatToken = 0;
  String _heroFloatText = '';
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
      _inCellier && _unlocked('bath') && _near(GameState.instance.bathX, 0.12);
  // Proximité de la douche (panneau) dans le cellier.
  bool get _atShower =>
      _inCellier &&
      _unlocked('shower') &&
      _near(GameState.instance.showerPanelX, 0.12);
  // Proximité de la petite sœur (salon, position vivante).
  bool get _atSister =>
      _inLiving && GameState.instance.sisterShown && _near(_sisterLiveX, 0.08);

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
    // Tension du froid (RÈGLE PRÉCISE) : toutes les 14 s, si la cabine est sous
    // le seuil de froid, le moral s'érode d'un cran PROPORTIONNEL à l'intensité
    // du froid : drain = max(1, coldness / 5) (coldness = seuil − température).
    //   léger (coldness ~5) → −1   |  mordant (~10) → −2   |  glacial (~20) → −4
    _coldTimer = Timer.periodic(const Duration(seconds: 14), (_) {
      // Pas de drain pendant les cartes NI sur la map (écrans où le joueur ne
      // peut ni manger, ni boire, ni se réchauffer) : sinon on perdait la run
      // sur un timer non actionnable. Cohérent avec le timer des besoins.
      if (!mounted || _inCards || _onMap) return;
      final gs = GameState.instance;
      if (gs.feltCold) {
        final d = (gs.coldness / 5).round();
        gs.nudgeCardStat('moral', -(d < 1 ? 1 : d));
      }
    });
    // TAMAGOTCHI LÉGER : faim et soif descendent doucement avec le temps passé
    // dans le train (−1 toutes les 24 s, hors cartes qui ont leur propre
    // économie). Manger (cuisinière/bac) et boire (filtre) deviennent
    // NÉCESSAIRES, pas décoratifs. Ralenti pour limiter les allers-retours.
    _needsTimer = Timer.periodic(const Duration(seconds: 24), (_) {
      if (!mounted || _inCards || _onMap) return;
      final gs = GameState.instance;
      gs.nudgeCardStat('faim', -1);
      gs.nudgeCardStat('soif', -1);
      // Besoins de confort (sommeil/hygiène) : décroissance lente, érodent le
      // moral si négligés. Remontés en dormant / en se lavant.
      gs.decayComfortNeeds();
    });
    // POÊLE À BOIS : draine le bois GLOBALEMENT tant qu'il est allumé (avant,
    // le drain vivait dans l'atelier -> chaleur gratuite ailleurs). Le poêle
    // s'éteint tout seul à 0 bois (nudgeCardStat).
    _poeleTimer = Timer.periodic(const Duration(seconds: 9), (_) {
      if (!mounted || _inCards || _onMap) return;
      final gs = GameState.instance;
      if (gs.poeleOn) gs.nudgeCardStat('bois', -1);
    });
  }

  Timer? _coldTimer;
  Timer? _needsTimer;
  Timer? _poeleTimer;

  @override
  void dispose() {
    _dayNightTimer?.cancel();
    _coldTimer?.cancel();
    _needsTimer?.cancel();
    _poeleTimer?.cancel();
    _debugTapTimer?.cancel();
    _unlockTimer?.cancel();
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
    'carry_walk': 25,
    'warm_hands': 25,
    'open_door': 20,
    'walk_right': 25,
    'idle_right': 25,
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

  int _pendingWagon = 0; // wagon visé par l'anim de porte (si _pendingDoor='wagon')

  // Porte d'un wagon vers le wagon voisin : delta = +1 (droite) / -1 (gauche).
  void _wagonDoor(int delta) {
    if (_doorPushing || _curtain.isAnimating) return;
    _startDoorFade();
    setState(() {
      _doorPushing = true;
      _doorPushRight = delta > 0;
      _pendingDoor = 'wagon';
      _pendingWagon = (_wagon + delta).clamp(0, 2);
      _doorPushToken++;
    });
  }

  void _onDoorPushDone() {
    if (!mounted) return;
    final dest = _pendingDoor;
    _pendingDoor = null;
    // L'anim de porte a joué EN ENTIER (20 frames). On échange maintenant la
    // scène DERRIÈRE le rideau noir.
    _curtainSwap(() {
      _doorPushing = false;
      if (dest == 'loco') {
        _inLocomotive = true;
      } else if (dest == 'wagon') {
        final from = _wagon;
        _wagon = _pendingWagon;
        // Vers la DROITE (wagon+1) -> on arrive côté gauche (0.12) ; vers la
        // GAUCHE (wagon-1) -> on arrive côté droit.
        _heroSpawnX = _wagon > from ? 0.12 : SideScrollScene.heroXMax;
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
  /// température, danse, ajustement des props).
  bool get _debug => GameState.instance.debugMode;

  @override
  Widget build(BuildContext context) {
    // Annonce des objets débloqués au retour dans le wagon.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUnlocks());
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
        child: _inCards
            ? CardsScreen(
                key: const ValueKey('cards'),
                onClose: () => setState(() {
                  _inCards = false;
                  // Le voyage se pilote depuis la loco : on y revient en
                  // quittant les cartes (sinon on retombait sur le wagon 1).
                  if (_cardsFromLoco) {
                    _cardsFromLoco = false;
                    _inLocomotive = true;
                  }
                }),
              )
            : _inWardrobe
            ? WardrobeScreen(
                key: const ValueKey('wardrobe'),
                onClose: () => setState(() => _inWardrobe = false),
              )
            : _inShop
            ? ShopScreen(
                key: const ValueKey('shop'),
                onClose: () => setState(() => _inShop = false),
              )
            : _onMap
            ? MapScreen(
                key: const ValueKey('map'),
                onClose: _exitMap,
                // Entrée des cartes narratives depuis la map (le voyage).
                onOpenCards: () => setState(() {
                  _onMap = false;
                  _inCards = true;
                  _cardsFromLoco = true; // voyage : retour loco en quittant
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
                      // Ramasser une bûche du tas de la gare et la jeter au
                      // foyer = +10 à la jauge Bois. Le tas est limité par gare
                      // (gareWoodLeft) : il faut le gérer.
                      final gs = GameState.instance;
                      if (gs.gareWoodLeft > 0) {
                        gs.setGareWoodLeft(gs.gareWoodLeft - 1);
                        gs.nudgeCardStat('bois', 10);
                        setState(() => _logsThrown++);
                      }
                    },
                    onReturn: _exitLocomotive,
                  )
                : _wagon == 2
                    ? _buildWagon(
                        key: const ValueKey('cellier'), secondWagon: true)
                    : _wagon == 1
                        ? _buildWagon(
                            key: const ValueKey('atelier'), isAtelier: true)
                        : _buildWagon(key: const ValueKey('salon')),
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
          // Bannière « Nouvel objet débloqué ! » (haut de l'écran, auto-fade).
          if (_unlockBanner != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xE6B85522),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                            color: const Color(0xFFFFD9A0), width: 1.4),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x88000000),
                              blurRadius: 12,
                              offset: Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(_unlockBanner!,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Bulles de TUTO d'intro : seulement sur la vue wagon 1, une fois.
          if (!_onMap &&
              !_inCards &&
              !_inWardrobe &&
              !_inShop &&
              !_inLocomotive &&
              _inLiving &&
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

  Widget _buildWagon(
      {required Key key, bool secondWagon = false, bool isAtelier = false}) {
    return Stack(
      key: key,
      children: [
        Positioned.fill(
          child: SideScrollScene(
            secondWagon: secondWagon,
            isAtelier: isAtelier,
            wagon2Adjust: secondWagon && _w2Adjust,
            wagon1Adjust: isAtelier && _w1Adjust,
            salonAdjust: !secondWagon && !isAtelier && _salonAdjust,
            bathToken: _bathToken,
            cuisiniereToken: _cuisiniereToken,
            poeleToken: _poeleToken,
            bacToken: _bacToken,
            heroFloatToken: _heroFloatToken,
            heroFloatText: _heroFloatText,
            showerToken: _showerToken,
            petDogToken: _petDogToken,
            duoToken: _duoToken,
            duoAnim: _duoAnimToPlay,
            onSisterX: (x) => setState(() => _sisterLiveX = x),
            onDogX: (x) => setState(() => _dogLiveX = x),
            initialHeroX: _heroSpawnX,
            // En mode debug : wagon NETTOYÉ (stage 1) + tous les objets.
            // En jeu : cellier ET atelier sont ENCOMBRÉS au départ, leur
            // rangement se gagne (flag / FAB debug). Salon = _wagonStage.
            wagonStage: GameState.instance.debugMode
                ? 1
                : secondWagon
                    ? ((GameState.instance.wagon2Stage >= 1 ||
                            GameState.instance.cardFlags
                                .contains('asset_wagon2'))
                        ? 1
                        : 0)
                    : isAtelier
                        ? GameState.instance.atelierStage
                        : _wagonStage,
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
                    tooltip: _inCellier
                        ? 'Cellier: ${_wagon2Labels[GameState.instance.wagon2Stage.clamp(0, 1)]}'
                        : _inAtelier
                            ? 'Atelier: ${_wagon2Labels[GameState.instance.atelierStage.clamp(0, 1)]}'
                            : 'Salon: ${_stageLabels[_wagonStage.clamp(0, _stageLabels.length - 1)]}',
                    onPressed: () {
                      setState(() {
                        final gs = GameState.instance;
                        if (_inCellier) {
                          gs.wagon2Stage = (gs.wagon2Stage + 1) % 2;
                          gs.save();
                        } else if (_inAtelier) {
                          gs.atelierStage = (gs.atelierStage + 1) % 2;
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
                  // Atelier seulement : ajuster cuisinière/lampe/bac/filtre/poêle.
                  if (isAtelier) ...[
                    FloatingActionButton.small(
                      heroTag: 'w1_adjust',
                      tooltip: _w1Adjust
                          ? 'Terminer le placement'
                          : 'Ajuster cuisinière/lampe/bac/filtre/poêle',
                      backgroundColor:
                          _w1Adjust ? const Color(0xFFE8B96B) : null,
                      foregroundColor:
                          _w1Adjust ? const Color(0xFF2A2018) : null,
                      onPressed: () => setState(() => _w1Adjust = !_w1Adjust),
                      child: Icon(_w1Adjust ? Icons.check : Icons.edit),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Salon seulement : ajuster carnet/secours/gamelle/carte.
                  if (!isAtelier && !secondWagon) ...[
                    FloatingActionButton.small(
                      heroTag: 'salon_adjust',
                      tooltip: _salonAdjust
                          ? 'Terminer le placement'
                          : 'Ajuster carnet/secours/gamelle/carte',
                      backgroundColor:
                          _salonAdjust ? const Color(0xFFE8B96B) : null,
                      foregroundColor:
                          _salonAdjust ? const Color(0xFF2A2018) : null,
                      onPressed: () =>
                          setState(() => _salonAdjust = !_salonAdjust),
                      child: Icon(_salonAdjust ? Icons.check : Icons.edit),
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
                // ===== BOUTON BOUTIQUE (toujours visible, confort only) =====
                FloatingActionButton.small(
                  heroTag: 'open_shop',
                  tooltip: 'Boutique confort',
                  onPressed: () => setState(() => _inShop = true),
                  child: const Icon(Icons.shopping_bag_outlined),
                ),
                const SizedBox(height: 12),
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
                // DEBUG OFF : zone INVISIBLE (triple-tap pour activer) -> plus
                // de bouton qui piège les testeurs. DEBUG ON : pastille verte
                // discrète (1 tap = sortir du debug).
                if (!on) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _debugCornerTap,
                    child: const SizedBox(width: 64, height: 64),
                  );
                }
                return GestureDetector(
                  onTap: () {
                    GameState.instance.toggleDebug();
                    setState(() {});
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A8A3A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bug_report, size: 18, color: Colors.white),
                        SizedBox(width: 5),
                        Text('DEBUG ON · tap pour sortir',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
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
        id: 'go_left',
        text: _inLiving
            ? 'Porte vers la locomotive : c\'est là qu\'on ouvre la carte du voyage.'
            : _inAtelier
                ? 'Retour au salon (sœur, chien, lit).'
                : 'Retour à l\'atelier.'
      );
    }
    if (_atRightDoor && !_inCellier) {
      return (
        id: 'go_right',
        text: _inLiving ? 'L\'atelier (cuisine, poêle, serre…).' : 'Le cellier (bain, douche).'
      );
    }
    if (_atBath) return (id: 'bath', text: 'Un bon bain pour te détendre.');
    if (_atShower) return (id: 'shower', text: 'Une douche pour te laver.');
    if (_atSister) {
      return (id: 'sister', text: 'Ta sœur : un câlin remonte le moral.');
    }
    if (_inLiving && _atBed) {
      return (id: 'bed', text: 'Dors ici pour récupérer des forces.');
    }
    if (_inLiving && _atNotebook) {
      return (id: 'notebook', text: 'Lis un moment : ça apaise.');
    }
    if (_inLiving && _atDog) {
      return (id: 'dog', text: 'Caresse le chien : ça réchauffe le cœur.');
    }
    if (_inAtelier && _atFilter) {
      return (id: 'filter', text: 'Remplis le filtre, puis bois (jauge Soif).');
    }
    if (_inAtelier && _atHydro) {
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
    if (_inAtelier && _atLamp) {
      return (id: 'lamp', text: 'Allume ou éteins la lampe.');
    }
    if (_inAtelier && _atStove) {
      return (id: 'cuisiniere', text: 'Cuisine un repas (jauge Faim).');
    }
    if (_inAtelier && _atPoele) {
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
      // Porte gauche : salon -> loco ; sinon -> wagon précédent (gauche).
      icon = Icons.meeting_room;
      action = _inLiving ? _enterLocomotive : () => _wagonDoor(-1);
    } else if (_atRightDoor && !_doorPushing && !_inCellier) {
      // Porte droite : vers le wagon suivant (salon->atelier->cellier).
      icon = Icons.meeting_room;
      action = () => _wagonDoor(1);
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
            _comfortMoral(8);
          });
    } else if (_inLiving && _atBed) {
      icon = Icons.bed;
      action = () => setState(() => _lieDownToken++);
    } else if (_inLiving && _atNotebook) {
      icon = Icons.menu_book;
      action = () {
        _triggerSpecial('read', frames: 25);
        // Lire réconforte : +moral.
        _comfortMoral(10);
      };
    } else if (_inAtelier && _atFilter) {
      final glasses = GameState.instance.waterTankGlasses;
      if (glasses == 0) {
        // Vide → remplir : PURIFIER/BOUILLIR coûte du bois (rien de gratuit).
        // Conversion bois -> réserve d'eau potable.
        icon = Icons.water;
        action = () {
          // Purifier/bouillir EXIGE du feu : pas de bois -> pas d'eau potable.
          // Coût relevé (l'eau était ~5x moins chère que les autres ressources).
          if (GameState.instance.cardBois < 10) {
            _heroFloat('Pas assez de bois 🪵');
            return;
          }
          GameState.instance.nudgeCardStat('bois', -10);
          GameState.instance
              .setWaterTankGlasses(GameState.waterTankMax);
        };
      } else {
        // Plein ou partiel → boire un verre.
        icon = Icons.local_drink;
        action = () {
          // Boire = 1 verre de la cuve (réserve) + remonte la jauge Soif.
          GameState.instance.nudgeCardStat('soif', 6);
          _triggerSpecial('use_back', frames: 24,
              next: 'drink', nextFrames: 25);
          _audio.playSfx('drink');
          GameState.instance.setWaterTankGlasses(glasses - 1);
          _heroFloat('+soif 💧');
        };
      }
    } else if (_inLiving && _atDog) {
      icon = Icons.pets;
      action = () {
        // Sprite Shen + husky (caresse -> câlin), bon chien.
        setState(() => _petDogToken++);
        _comfortMoral(10);
        _audio.playSfx('dog_bark');
      };
    } else if (_inAtelier && _atHydro) {
      // Bac de culture : semer / récolter (séquence dans la scène). Plus de
      // fenêtre de mini-jeu serre.
      icon = Icons.yard;
      action = () => setState(() => _bacToken++);
    } else if (_inAtelier && _atLamp) {
      icon = GameState.instance.lampOn
          ? Icons.lightbulb
          : Icons.lightbulb_outline;
      action = () {
        setState(() => GameState.instance.toggleLamp());
        _audio.playSfx('lamp_toggle');
      };
    } else if (_inAtelier && _atStove) {
      // Cuisinière : Shen se tourne, la cuisinière s'allume 5 s, puis elle
      // mange au sol (séquence pilotée dans la scène).
      icon = Icons.local_dining;
      action = () => setState(() => _cuisiniereToken++);
    } else if (_inAtelier && _atPoele) {
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
