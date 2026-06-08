import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../models/game_state.dart';

/// Mini-jeu de défense de gare au lance-pierre, version "addictive" :
/// menu + 2 modes (campagne / survie), butin + ferraille, coffre de fin de
/// vague, atelier d'améliorations permanentes, jauge de frénésie + callouts,
/// perks synergiques (perçant / ricochet / split / incendiaire / gel), record.
///
/// Coordonnées en "unités décor" (origine = coin haut-gauche du décor affiché,
/// 1 unité = hauteur affichée `_S`) -> tout reste collé à la gare quel que soit
/// l'écran (décor en BoxFit.contain).
class RoofDefenseGame extends StatefulWidget {
  const RoofDefenseGame(
      {super.key, required this.onExit, this.onResult, this.gareIndex = 0});
  final VoidCallback onExit;

  /// Index de la gare (0-based) -> choisit le décor de combat.
  final int gareIndex;

  /// Si fourni : combat de GARE. Le jeu démarre direct en campagne (pas de
  /// menu) et appelle onResult(score sur 100) quand le joueur valide.
  final void Function(int score100)? onResult;

  @override
  State<RoofDefenseGame> createState() => _RoofDefenseGameState();
}

enum _Phase { menu, atelier, playing, chest, perk, gameover, progress }

enum _Mode { campaign, endless }

enum _PillType { basic, brute, lanceur, boss }

class _Enemy {
  _Enemy({
    required this.type,
    required this.x,
    required this.feetY,
    required this.speed,
    required this.height,
    required this.anim,
    this.hp = 1,
    this.golden = false,
  }) : hpMax = hp;
  final _PillType type;
  double x;
  double feetY;
  double speed;
  double height;
  double anim;
  int hp;
  final int hpMax;
  final bool golden; // pillard doré : jackpot de ferraille
  bool dying = false;
  double dieT = 0;
  // Ragdoll de mort : le pillard part en pantin (recule + saute + tourne).
  double dieVX = 0, dieVY = 0, dieRot = 0, dieRotV = 0;
  double slowT = 0; // gel : ralenti restant
  double staggerT = 0; // touché au corps : tombe en arrière puis se relève
  bool attacking = false;
  double attackT = 0;
  double lastAtkX = 0;
  bool throwing = false;
  double throwT = 0;
  bool threwThisCycle = false;
  bool melee = false; // arrivé au train -> frappe au corps à corps
  double meleeT = 0;
  double bossThrowT = 0; // cadence de jet du boss
}

class _Stone {
  _Stone(this.pos, this.vel,
      {this.pierce = 0,
      this.ricochet = 0,
      this.splits = 0,
      this.big = false,
      this.fire = false,
      this.freeze = false,
      this.dmg = 1});
  Offset pos;
  Offset vel;
  int pierce;
  int ricochet;
  int splits;
  final bool big;
  final bool fire;
  final bool freeze;
  final int dmg;
  final List<Offset> trail = []; // petites positions récentes (traînée d'air)
  int bounces = 0; // rebonds sur la ligne de marche
}

class _EnemyShot {
  _EnemyShot(this.pos, this.vel);
  Offset pos;
  Offset vel;
  final List<Offset> trail = []; // traînée d'air
}

class _Impact {
  _Impact(this.pos, {this.launch = false, this.crit = false, this.blast = false})
      : seed = ((pos.dx * 131.0 + pos.dy * 977.0) * 100).toInt() & 0x7fffffff;
  final Offset pos;
  final bool launch;
  final bool crit;
  final bool blast;
  final int seed; // pour disperser les débris de façon variée
  double t = 0;
}

class _Loot {
  _Loot(this.pos, this.vel, this.value);
  Offset pos;
  Offset vel;
  final int value; // ferraille
  bool landed = false;
  double life = 0; // temps restant pour la ramasser (3 s après l'atterrissage)
}

class _FirePatch {
  _FirePatch(this.x, this.feetY);
  final double x;
  final double feetY;
  double life = 3.0;
  double dmgT = 0;
}

class _FloatText {
  _FloatText(this.pos, this.text, this.color, {this.big = false});
  Offset pos;
  final String text;
  final Color color;
  final bool big;
  double t = 0;
}

class _Barrel {
  _Barrel(this.x, this.feetY);
  final double x;
  final double feetY;
}

class _RoofDefenseGameState extends State<RoofDefenseGame>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _rng = math.Random();

  static const double _imgA = 1376 / 768; // décor combat en couches (parallaxe)
  static const double _trainEdgeX = 0.24;

  // Tir ultra lent (gros lobé, on suit la pierre tout du long).
  static const double _g = 0.12;
  static const double _power = 4.6;
  static const double _maxSpeed = 0.58;
  static const double _stoneR = 0.013;
  static const double _reload = 0.26;
  static const double _impactDur = 0.32;
  static const double _dieDur = 1.2;
  static const double _pillFeet = 0.855; // mesuré sur pillard1_walk
  static const double _pillContentH = 0.70;
  static const double _bruteAtkDur = 0.8;
  static const int _bruteHp = 4;
  static const double _throwPeriod = 1.3;
  static const int _campaignWaves = 5;

  // --- Améliorations d'atelier : défs partagées dans GameState ---
  static const Map<String, (String, String, List<int>)> _shopDefs =
      GameState.shootShopDefs;

  static const Map<String, (String, String, String)> _perkData = {
    'stone': ('🪨', '+1 pierre', 'Un caillou de plus par tir'),
    'hearts': ('❤️', '+2 cœurs', 'Train plus résistant'),
    'pierce': ('🎯', 'Perçant', 'Traverse 1 ennemi de plus'),
    'ricochet': ('↩️', 'Ricochet', 'Rebondit sur un ennemi'),
    'split': ('✳️', 'Éclats', 'Le caillou éclate en 2'),
    'fire': ('🔥', 'Incendiaire', 'Laisse une flaque de feu'),
    'freeze': ('❄️', 'Gel', 'Ralentit les ennemis touchés'),
    'speed': ('⚡', 'Tir vif', 'Caillou plus rapide'),
  };
  static const List<String> _weaponNames = ['Fronde', 'Arc', 'Arbalète', 'Cocktail'];

  // --- État global ---
  _Phase _phase = _Phase.menu;
  _Mode _mode = _Mode.campaign;
  bool _adjust = false;

  // --- Entités ---
  final List<_Enemy> _enemies = [];
  final List<_Stone> _stones = [];
  final List<_EnemyShot> _enemyShots = [];
  final List<_Impact> _impacts = [];
  final List<_Loot> _loot = [];
  final List<_FirePatch> _fires = [];
  final List<_FloatText> _floats = [];
  _Barrel? _barrel;

  // --- Run ---
  int _wave = 0;
  int _toSpawn = 0;
  double _spawnTimer = 0;
  double _banner = 0;
  double _reloadTimer = 0;
  int _trainHp = 5;
  int _maxHp = 5;
  int _kills = 0;
  int _score = 0;
  int _hpLost = 0;
  int _runScrap = 0;
  int _shownScrap = 0; // ferraille du run (affichage écran de fin)
  bool _won = false;
  int _wonStars = 0;
  bool _weaponUp = false;
  bool _newRecord = false;

  // perks/arme du run
  int _stonesPerShot = 1;
  double _powerMult = 1.0;
  int _pierce = 0;
  int _ricochet = 0;
  int _split = 0;
  int _fire = 0;
  int _freeze = 0;
  int _baseDmg = 1;
  int _perkCount = 3;
  List<String> _perkChoices = const [];

  // Mécaniques débloquées à l'atelier (méta transformative).
  int _magnet = 0; // butin auto-ramassé
  int _shieldMax = 0, _shield = 0; // coups gratuits encaissés par vague
  int _bombMax = 0, _bombLeft = 0; // bombe écran, 1/vague

  // Évolution d'arme : un perk choisi 3× dans la run "évolue" (gros bonus).
  final Map<String, int> _perkLevels = {};
  final Set<String> _evolved = {};
  bool _nearMiss = false; // perdu de justesse -> consolation

  // frénésie / combos
  double _frenzy = 0;
  bool _inFrenzy = false;
  double _frenzyT = 0;
  double _autoFireT = 0;
  int _combo = 0;
  int _streak = 0;
  double _streakT = 0;

  // coffre
  final int _chestScrap = 0;
  final String _chestExtra = ''; // '', 'heart', 'perk'
  bool _chestOpened = false;

  // juice
  double _shake = 0;
  double _hitStop = 0;
  double _slowmo = 0;
  bool _storm = false; // vague de tempête : voile sombre + vent fort

  // placement
  double _muzX = 0.16, _muzY = 0.64, _groundY = 0.865;
  Offset get _muzzle => Offset(_muzX, _muzY);

  // visée
  bool _aiming = false;
  Offset _dragStart = Offset.zero;
  Offset _dragNow = Offset.zero;
  // Caméra libre (regarder le terrain avant de viser).
  bool _looking = false;
  double _lookX = 0;

  // ignore: non_constant_identifier_names  (_S = "scene unit" du décor combat)
  double _S = 1, _ox = 0, _oy = 0;
  Duration _last = Duration.zero;

  // --- Caméra : zoom FIXE, on SUIT le projectile (le pillard est hors champ
  //     au lancer, la caméra le révèle en suivant la pierre). Retour au train. ---
  static const double _zoomRest = 1.35; // gros plan train (départ moins fort)
  // Dézoom de visée : LIMITÉ à 1.0. En dessous, le décor (1 unité de haut) ne
  // couvre plus la hauteur écran -> bande vide sous l'image. 1.0 = vue la plus
  // large possible sans révéler le bord bas du décor.
  static const double _zoomAim = 1.0; // dézoom LARGE pendant la visée (plancher)
  static const double _kBg = 0.9; // parallaxe du fond lointain
  double _zoomCur = 1.35, _zoomTarget = 1.35;
  double _camLaunchHold = 0; // reste sur le train un instant après le tir
  double _camPunch = 0; // petit coup de zoom sur le coup fatal (0..1)
  double _windowHalo = 0; // petit halo dans la fenêtre quand le pillard touche

  // --- Mode DUEL de test (réglage du feeling) : 1 seul lanceur, 3 PV, on tire
  //     chacun son tour, il recule quand touché. Réservé au MODE DEBUG ; en jeu
  //     normal on lance la vraie campagne (vagues, économie, score de gare). ---
  bool get _duelTest => GameState.instance.debugMode;
  bool _playerTurn = true; // le joueur peut tirer
  bool _awaitingStones = false; // on attend que la pierre du joueur retombe
  bool _enemyAiming = false; // caméra recentrée sur le pillard, il vise
  double _enemyAimT = 0; // télégraphe avant son tir
  bool _enemyThrowing = false; // le pillard riposte (son tour)
  // Intro de duel : la caméra glisse vers l'ennemi, son nom apparaît, retour.
  bool _intro = false;
  double _introT = 0;
  String _foeName = '';
  static const List<String> _foeNames = [
    'Croc', 'Le Borgne', 'Ferraille', 'La Hyène', 'Cendre',
    'Le Rat', 'Bave-de-Loup', 'Tord-Cou', 'La Teigne', 'Os-Brisé',
  ];
  double _camX = 0; // centre du viewport, en unités-x de scène
  double _camHome = 0; // position de repos (train ~ gauche)
  double _camTarget = 0;
  double _camMin = 0, _camMax = 0;
  // Suivi vertical : la pierre lobée monte haut -> la caméra remonte pour la
  // garder à l'écran, puis redescend au repos.
  double _camY = 0, _camYTarget = 0, _camYHome = 0, _camYMin = 0, _camYMax = 0;
  bool _camInit = false;

  bool get _explosiveWeapon =>
      !_duelTest && GameState.instance.shootWeaponLevel >= 3;
  double get _zoneSpeed => GameState.instance.inColdZone ? 1.18 : 1.0;
  double get _zoneCount => GameState.instance.inColdZone ? 1.3 : 1.0;

  // Mode "combat de gare" : lancé depuis l'écran cartes, démarre direct en
  // campagne (pas de menu) et renvoie un score /100 via onResult.
  bool get _gareMode => widget.onResult != null;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    // Position du canon / sol depuis la sauvegarde (réglable en jeu).
    final gs = GameState.instance;
    _muzX = gs.shootMuzX;
    _muzY = gs.shootMuzY;
    _groundY = gs.shootGroundY;
    // En mode gare : pas de menu, on attaque la campagne tout de suite.
    if (_gareMode) _setupRun(_Mode.campaign);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Cycle de run
  // ---------------------------------------------------------------------------
  void _applyMeta() {
    // Mode duel : on DÉMARRE toujours avec la pierre standard basique (aucun
    // upgrade), pour régler le feeling de base. Les bonus viennent ensuite par
    // les choix de victoire.
    if (_duelTest) {
      _baseDmg = 1;
      _maxHp = 5;
      _trainHp = 5;
      _stonesPerShot = 1;
      _powerMult = 1.0;
      _pierce = 0;
      _perkCount = 3;
      _ricochet = _split = _fire = _freeze = 0;
      _magnet = _shieldMax = _bombMax = 0;
      _shield = _bombLeft = 0;
      _perkLevels.clear();
      _evolved.clear();
      _nearMiss = false;
      return;
    }
    final up = GameState.instance.shootUpgrades;
    final lvl = GameState.instance.shootWeaponLevel.clamp(0, 3);
    _baseDmg = 1 + (up['dmg'] ?? 0);
    _maxHp = 5 + (up['hearts'] ?? 0);
    _trainHp = _maxHp;
    _stonesPerShot = 1 + (up['stones'] ?? 0);
    _powerMult = (1.0 + 0.10 * lvl) * (1.0 + 0.08 * (up['range'] ?? 0));
    _pierce = lvl >= 2 ? 1 : 0;
    _perkCount = 3 + (up['choices'] ?? 0);
    _ricochet = 0;
    _split = 0;
    _fire = 0;
    _freeze = 0;
    _magnet = up['magnet'] ?? 0;
    _shieldMax = up['shield'] ?? 0;
    _bombMax = (up['bomb'] ?? 0) > 0 ? 1 : 0;
    _shield = 0;
    _bombLeft = 0;
    _perkLevels.clear();
    _evolved.clear();
    _nearMiss = false;
  }

  void _startRun(_Mode mode) => setState(() => _setupRun(mode));

  // Corps du démarrage de run (sans setState : appelable depuis initState).
  void _setupRun(_Mode mode) {
    {
      _mode = mode;
      _enemies.clear();
      _stones.clear();
      _enemyShots.clear();
      _impacts.clear();
      _loot.clear();
      _fires.clear();
      _floats.clear();
      _barrel = null;
      _wave = 0;
      _toSpawn = 0;
      _spawnTimer = 0;
      _kills = 0;
      _score = 0;
      _hpLost = 0;
      _runScrap = 0;
      _won = false;
      _wonStars = 0;
      _weaponUp = false;
      _newRecord = false;
      _combo = 0;
      _streak = 0;
      _frenzy = 0;
      _inFrenzy = false;
      _frenzyT = 0;
      _shake = 0;
      _hitStop = 0;
      _slowmo = 0;
      _storm = false;
      _aiming = false;
      _applyMeta();
      _playerTurn = true;
      _awaitingStones = false;
      _enemyAiming = false;
      _enemyThrowing = false;
      _intro = false;
      _windowHalo = 0;
      _zoomCur = _zoomTarget = _zoomRest;
      _phase = _Phase.playing;
      _banner = 1.8;
    }
  }

  /// Score /100 du combat de gare : si gagné, 70..100 selon les cœurs restants ;
  /// si perdu, 0..65 selon les vagues survécues + un bonus de kills.
  int get _score100 {
    if (_won) {
      final hpFrac = _maxHp > 0 ? _trainHp / _maxHp : 0.0;
      return (70 + 30 * hpFrac).round().clamp(70, 100);
    }
    final waveFrac = (_wave / _campaignWaves).clamp(0.0, 1.0);
    final killBonus = _kills.clamp(0, 15);
    return (waveFrac * 50 + killBonus).round().clamp(0, 65);
  }

  // Config (nombre, vitesse, intervalle) de la vague courante.
  (int, double, double) _waveConfig() {
    if (_duelTest) return (1, 0.0, 1.0); // test : un seul pillard
    if (_mode == _Mode.campaign) {
      // Pillards STATIQUES : counts = nombre de pillards postés (ils restent et
      // ripostent), interval = cadence d'apparition. (speed inutilisé.)
      const waves = [
        (3, 0.0, 1.3),
        (4, 0.0, 1.2),
        (6, 0.0, 1.1),
        (7, 0.0, 1.0),
        (9, 0.0, 0.9),
      ];
      return waves[_wave.clamp(0, waves.length - 1)];
    }
    // Survie : montée infinie (de plus en plus de pillards postés).
    final i = _wave;
    final count = 3 + (i * 1.5).round();
    final interval = (1.20 - i * 0.05).clamp(0.6, 1.20);
    return (count, 0.0, interval.toDouble());
  }

  bool get _isLastWave =>
      _mode == _Mode.campaign && _wave >= _campaignWaves - 1;

  // ---------------------------------------------------------------------------
  // Boucle
  // ---------------------------------------------------------------------------
  void _tick(Duration elapsed) {
    double dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0) return;
    if (dt > 0.05) dt = 0.05;
    if (_phase != _Phase.playing) return;
    if (_adjust) return;

    // Animations toujours actives (impacts, textes flottants).
    for (final im in _impacts) {
      im.t += dt / _impactDur;
    }
    _impacts.removeWhere((im) => im.t >= 1);
    for (final f in _floats) {
      f.t += dt;
    }
    _floats.removeWhere((f) => f.t > 1.0);

    if (_hitStop > 0) {
      _hitStop -= dt;
      setState(() {});
      return;
    }
    if (_slowmo > 0) {
      _slowmo -= dt;
      dt *= 0.35;
    }

    // Frénésie.
    if (_inFrenzy) {
      _frenzyT -= dt;
      _autoFireT -= dt;
      if (_autoFireT <= 0) {
        _autoFire();
        _autoFireT = 0.16;
      }
      if (_frenzyT <= 0) _inFrenzy = false;
    } else {
      _frenzy = (_frenzy - dt * 0.03).clamp(0.0, 1.0);
    }
    if (_streakT > 0) {
      _streakT -= dt;
      if (_streakT <= 0) _streak = 0;
    }

    if (_banner > 0) {
      _banner -= dt;
      if (_banner <= 0) {
        _storm = _wave >= 2 &&
            (GameState.instance.inColdZone || _rng.nextDouble() < 0.35);
        _toSpawn = (_waveConfig().$1 * _zoneCount).round();
        _spawnTimer = 0.4;
        _shield = _shieldMax; // bouclier rechargé à chaque vague
        _bombLeft = _bombMax; // bombe dispo une fois par vague
        if (_duelTest) {
          // Intro : la caméra va voir l'ennemi, son nom s'affiche, puis revient.
          _intro = true;
          _introT = 3.0;
          _foeName = _foeNames[_rng.nextInt(_foeNames.length)];
        } else {
          _spawnBarrel();
          if (_isBossWave) _spawnBoss();
        }
      }
      setState(() {});
      return;
    }

    if (_toSpawn > 0) {
      _spawnTimer -= dt;
      if (_spawnTimer <= 0) {
        _spawnEnemy(_waveConfig().$2 * _zoneSpeed);
        _toSpawn--;
        _spawnTimer = _waveConfig().$3;
      }
    }

    // Filet de sécurité : une frame fautive ne doit jamais tuer le ticker.
    try {
      _updateEnemies(dt);
      _updateProjectiles(dt);
      _updateLoot(dt);
      _updateFires(dt);
      _updateDuelTurn(dt);
      _updateCamera(dt);
      if (_toSpawn == 0 && _enemies.isEmpty && _banner <= 0) {
        _endWave();
      }
    } catch (e, st) {
      debugPrint('roof_defense tick error: $e\n$st');
    }

    if (_reloadTimer > 0) _reloadTimer -= dt;
    if (_shake > 0) _shake = (_shake - dt).clamp(0.0, 1.0);
    if (_intro) {
      _introT -= dt;
      if (_introT <= 0) _intro = false;
    }
    if (_camPunch > 0) _camPunch = (_camPunch - dt * 3.0).clamp(0.0, 1.0);
    if (_windowHalo > 0) _windowHalo -= dt;
    setState(() {});
  }

  void _updateEnemies(double dt) {
    for (final e in _enemies) {
      if (e.dying) {
        e.dieT -= dt;
        // Ragdoll : intègre vol + chute + rotation.
        e.dieVY += _g * 2.4 * dt;
        e.x += e.dieVX * dt;
        e.feetY = (e.feetY + e.dieVY * dt).clamp(0.0, _groundY + 0.12);
        e.dieRot += e.dieRotV * dt;
        continue;
      }
      e.anim += dt;
      if (e.slowT > 0) e.slowT -= dt;
      if (e.staggerT > 0) e.staggerT -= dt;

      // Pillard doré : posté un temps limité, puis il s'enfuit avec le magot
      // (jackpot perdu) -> il faut l'abattre vite.
      if (e.golden) {
        e.meleeT -= dt;
        if (e.meleeT <= 0) {
          e.dying = true;
          e.dieT = 0;
          _floats.add(_FloatText(Offset(e.x, e.feetY - e.height * 0.7),
              'Enfui ! 🔩', const Color(0xFFE2A33A)));
          continue;
        }
      }

      // En mode duel, l'ennemi ne riposte QUE pendant son tour (géré ailleurs).
      if (_duelTest) {
        if (e.throwing) {
          e.attackT += dt;
          if (e.attackT >= _bruteAtkDur) e.throwing = false;
        }
        continue;
      }
      // Pillards STATIQUES : ils restent au loin et RIPOSTENT en lançant des
      // projectiles sur le train, par intervalles (avec un bref élan animé).
      final base = e.type == _PillType.brute
          ? 2.6
          : (e.type == _PillType.boss ? 1.6 : 1.8);
      final period = (_storm ? base * 0.75 : base) * (e.slowT > 0 ? 1.8 : 1.0);
      if (e.throwing) {
        e.attackT += dt;
        if (e.attackT >= _bruteAtkDur) e.throwing = false;
      }
      e.throwT += dt;
      if (e.throwT >= period) {
        e.throwT = 0;
        e.throwing = true;
        e.attackT = 0;
        final n = e.type == _PillType.boss ? 2 : 1;
        for (int k = 0; k < n; k++) {
          _enemyShots.add(_EnemyShot(
            Offset(e.x - e.height * 0.20, e.feetY - e.height * 0.55),
            Offset(-1.15, -0.35 - k * 0.12),
          ));
        }
      }
    }
    _enemies.removeWhere((e) => e.dying && e.dieT <= 0);
  }

  void _updateProjectiles(double dt) {
    final wind = GameState.instance.inColdZone ? -0.22 : 0.0;
    for (final s in _stones) {
      // Traînée d'air : on mémorise quelques positions récentes.
      s.trail.add(s.pos);
      if (s.trail.length > 7) s.trail.removeAt(0);
      s.vel = s.vel + Offset(wind * dt, _g * dt);
      s.pos = s.pos + s.vel * dt;
      // Rebond sur la ligne de marche des pillards (le sol).
      if (s.pos.dy >= _groundY && s.vel.dy > 0) {
        s.pos = Offset(s.pos.dx, _groundY);
        s.vel = Offset(s.vel.dx * 0.62, -s.vel.dy * 0.5);
        s.bounces++;
      }
    }
    // Retiré quand il sort, ou après quelques rebonds devenus faibles.
    _stones.removeWhere((s) =>
        s.pos.dx > _imgA + 0.2 ||
        s.pos.dx < -0.2 ||
        (s.bounces >= 3 && s.vel.distance < 0.25));

    for (final es in _enemyShots) {
      es.trail.add(es.pos);
      if (es.trail.length > 7) es.trail.removeAt(0);
      es.vel = es.vel + Offset(0, _g * 0.5 * dt);
      es.pos = es.pos + es.vel * dt;
    }
    _enemyShots.removeWhere((es) {
      // Tombé au sol avant la fenêtre -> raté court (poussière), aucun dégât.
      if (es.pos.dy >= _groundY && es.vel.dy > 0 && es.pos.dx > _muzX) {
        _impacts.add(_Impact(Offset(es.pos.dx, _groundY)));
        return true;
      }
      // Atteint le plan de la fenêtre : touche si assez proche, sinon raté de peu.
      if (es.pos.dx <= _muzX) {
        if ((es.pos.dy - _muzY).abs() < 0.045) {
          _damageTrain();
          _windowHalo = 1.2;
          _shake = math.max(_shake, 0.22);
        } else {
          _impacts.add(_Impact(es.pos)); // éclat juste à côté de la fenêtre
        }
        return true;
      }
      return es.pos.dy > 1.15 || es.pos.dx < -0.2;
    });

    // Collisions caillou -> pillard. On itère une COPIE et on collecte les
    // éclats à part : interdit de modifier _stones pendant l'itération (sinon
    // ConcurrentModificationError -> ticker planté -> écran figé).
    final frags = <_Stone>[];
    for (final s in List.of(_stones)) {
      _Enemy? hit;
      for (final e in _enemies) {
        if (e.dying) continue;
        final hw = e.height * 0.24;
        final top = e.feetY - e.height * 0.95;
        final bot = e.feetY - e.height * 0.05;
        if (s.pos.dx >= e.x - hw - _stoneR &&
            s.pos.dx <= e.x + hw + _stoneR &&
            s.pos.dy >= top &&
            s.pos.dy <= bot) {
          hit = e;
          break;
        }
      }
      if (hit == null) continue;
      final e = hit;
      // Zones : tête (gros dégâts), corps, jambes (juste un peu de vie).
      final headBot = e.feetY - e.height * 0.78;
      final legTop = e.feetY - e.height * 0.30;
      final head = s.pos.dy <= headBot;
      final leg = s.pos.dy >= legTop;
      final zoneMult = head ? 3 : (leg ? 1 : 2);
      e.hp -= s.dmg * zoneMult;
      if (leg && !head) {
        _floats.add(_FloatText(Offset(e.x, e.feetY - e.height * 0.2), 'jambe',
            const Color(0xFFE2C28A)));
      }
      // Recul : touché mais pas mort -> le pillard tombe en arrière (plus
      // loin), ce qui oblige à recorriger le tir suivant. Touché au HAUT du
      // corps (tête/torse) = il tombe à la renverse puis se relève sur place.
      if (e.hp > 0) {
        e.x = (e.x + (_duelTest ? 0.14 : 0.04)).clamp(0.9, _imgA - 0.08);
        e.throwing = false;
        if (!leg) e.staggerT = 0.9; // chute + relève
      } else {
        e.x += 0.015;
      }
      if (s.freeze) e.slowT = 2.0;
      if (s.fire) _fires.add(_FirePatch(s.pos.dx, _groundY));
      _impacts.add(_Impact(s.pos, crit: head));
      if (_explosiveWeapon) _explode(s.pos);
      if (s.splits > 0) {
        for (int k = 0; k < 2; k++) {
          frags.add(_Stone(
            s.pos,
            Offset((k == 0 ? -0.5 : 0.5), 0.4) + s.vel * 0.3,
            dmg: s.dmg,
            fire: s.fire,
            freeze: s.freeze,
          ));
        }
        s.splits = 0;
      }
      if (e.hp <= 0) _killEnemy(e, head: head);
      if (s.ricochet > 0) {
        final next = _nearestOther(e);
        if (next != null) {
          final dir = Offset(next.x, next.feetY - next.height * 0.5) - s.pos;
          final sp = s.vel.distance;
          if (dir.distance > 0) s.vel = dir / dir.distance * sp;
          s.ricochet--;
        } else {
          s.pos = const Offset(-99, -99);
        }
      } else if (s.pierce > 0) {
        s.pierce--;
      } else {
        s.pos = const Offset(-99, -99);
      }
    }
    _stones.addAll(frags);
    // Baril.
    if (_barrel != null) {
      final b = _barrel!;
      for (final s in _stones) {
        if ((s.pos.dx - b.x).abs() < 0.05 &&
            (s.pos.dy - (b.feetY - 0.06)).abs() < 0.07) {
          _explode(Offset(b.x, b.feetY - 0.06), big: true);
          _barrel = null;
          s.pos = const Offset(-99, -99);
          break;
        }
      }
    }
    _stones.removeWhere((s) => s.pos.dx < -90);
  }

  void _updateLoot(double dt) {
    for (final l in _loot) {
      if (l.landed) {
        l.life -= dt; // décompte des 3 s : si on ne tape pas, c'est perdu
        continue;
      }
      l.vel = l.vel + Offset(0, _g * dt);
      l.pos = l.pos + l.vel * dt;
      if (l.pos.dy >= _groundY) {
        l.landed = true;
        l.life = 3.0;
        l.pos = Offset(l.pos.dx, _groundY);
        // Aimant à ferraille : ramassage automatique à l'atterrissage.
        if (_magnet > 0) {
          _runScrap += l.value;
          _floats.add(_FloatText(Offset(l.pos.dx, _groundY - 0.05),
              '+${l.value}🔩', const Color(0xFFE8B96B)));
          l.life = 0;
        }
      }
    }
    _loot.removeWhere((l) => l.landed && l.life <= 0);
  }

  void _updateFires(double dt) {
    for (final p in _fires) {
      p.life -= dt;
      p.dmgT -= dt;
      if (p.dmgT <= 0) {
        p.dmgT = 0.4;
        for (final e in _enemies) {
          if (e.dying) continue;
          if ((e.x - p.x).abs() < 0.06) {
            e.hp -= 1;
            if (e.hp <= 0) _killEnemy(e);
          }
        }
      }
    }
    _fires.removeWhere((p) => p.life <= 0);
  }

  // Duel tour-par-tour : le joueur tire, on attend que sa pierre retombe, puis
  // le pillard riposte une fois, puis c'est de nouveau au joueur.
  void _updateDuelTurn(double dt) {
    if (!_duelTest) return;
    bool stoneFlying() => _stones.any((s) => s.pos.dx > -90);
    if (_awaitingStones) {
      if (!stoneFlying()) {
        _awaitingStones = false;
        final alive = _enemies.where((e) => !e.dying).toList();
        if (alive.isEmpty) {
          _playerTurn = true;
        } else {
          // Recentre sur le pillard, il vise (télégraphe) avant de lancer.
          _enemyAiming = true;
          _enemyAimT = 1.9; // lancer du pillard retardé

        }
      }
    } else if (_enemyAiming) {
      _enemyAimT -= dt;
      if (_enemyAimT <= 0) {
        _enemyAiming = false;
        final alive = _enemies.where((e) => !e.dying).toList();
        if (alive.isEmpty) {
          _playerTurn = true;
        } else {
          final e = alive.first;
          e.throwing = true;
          e.attackT = 0;
          _enemyThrowAt(e);
          _enemyThrowing = true;
        }
      }
    } else if (_enemyThrowing) {
      if (_enemyShots.isEmpty) {
        _enemyThrowing = false;
        _playerTurn = true;
      }
    }
  }

  // Bruit ~gaussien dans ~[-1,1] (somme de 3 uniformes) : la plupart des tirs
  // tombent PRÈS de la cible, rarement loin.
  double _gauss() =>
      (_rng.nextDouble() + _rng.nextDouble() + _rng.nextDouble() - 1.5) / 1.5;

  // Le pillard VISE toujours la fenêtre, avec une erreur réaliste : quand il
  // loupe, c'est de peu (juste à côté / un peu court), jamais "à 2m de lui".
  // [spread] grossit l'erreur (niveau 1 = gros, baissera avec le niveau).
  void _enemyThrowAt(_Enemy e) {
    final from = Offset(e.x - e.height * 0.2, e.feetY - e.height * 0.55);
    const ge = _g * 0.5; // gravité des tirs ennemis (cf _updateProjectiles)
    const t = 4.8; // vol très lent (suivable à la caméra)
    const spread = 0.14; // niveau 1 : dispersion autour de la fenêtre
    final to = Offset(
      _muzX + _gauss() * spread, // un peu court / un peu long
      _muzY + _gauss() * spread * 0.8, // un peu haut / un peu bas
    );
    final vx = (to.dx - from.dx) / t;
    final vy = (to.dy - from.dy) / t - 0.5 * ge * t;
    _enemyShots.add(_EnemyShot(from, Offset(vx, vy)));
  }

  // Caméra : suit la pierre en vol (la plus avancée), marque un temps sur
  // l'impact, puis revient en douceur sur le train.
  void _updateCamera(double dt) {
    if (_camLaunchHold > 0) _camLaunchHold -= dt;
    // Ma pierre (la plus avancée) / le tir ennemi / le pillard.
    _Stone? lead;
    for (final s in _stones) {
      if (s.pos.dx < -90) continue;
      if (lead == null || s.pos.dx > lead.pos.dx) lead = s;
    }
    final eShot = _enemyShots.isNotEmpty ? _enemyShots.first : null;
    _Enemy? foe;
    for (final e in _enemies) {
      if (!e.dying) {
        foe = e;
        break;
      }
    }
    final flying = lead != null || eShot != null;

    if (_intro && foe != null) {
      // Intro : la caméra glisse lentement vers l'ennemi (on voit son nom).
      _zoomTarget = _zoomRest;
      _camTarget = foe.x;
      _camYTarget = math.min(_camYHome, foe.feetY - foe.height * 0.5);
    } else if (_looking && !flying) {
      // Caméra libre : on regarde où on veut (dézoom large pour voir loin).
      _zoomTarget = _zoomAim;
      _camTarget = _lookX;
      _camYTarget = _camYHome;
    } else if (_aiming && _playerTurn && _camLaunchHold <= 0 && !flying) {
      // 1) On tend l'arc -> DÉZOOM selon la tension (on reste sur le train).
      final maxs = _maxSpeed * _powerMult;
      final f =
          (_launchVel().distance / (maxs <= 0 ? 1 : maxs)).clamp(0.0, 1.0);
      _zoomTarget = _zoomRest + (_zoomAim - _zoomRest) * f;
      _camTarget = _camHome;
      _camYTarget = _camYHome;
    } else {
      _zoomTarget = _zoomRest;
      Offset focus;
      if (_camLaunchHold > 0) {
        focus = Offset(_camHome, _camYHome); // on voit le départ
      } else if (lead != null) {
        focus = lead.pos; // 2) on suit MA pierre
      } else if (_enemyThrowing && eShot != null) {
        focus = eShot.pos; // 4c) on suit la pierre DU pillard
      } else if (_enemyAiming && foe != null) {
        // 4a/b) recentré sur le pillard : on le voit tendre la main.
        focus = Offset(foe.x, foe.feetY - foe.height * 0.5);
      } else {
        focus = Offset(_camHome, _camYHome); // retour au train (mon tour)
      }
      _camTarget = focus.dx;
      _camYTarget = math.min(_camYHome, focus.dy);
    }

    if (_camMax > _camMin) _camTarget = _camTarget.clamp(_camMin, _camMax);
    if (_camYMax > _camYMin) _camYTarget = _camYTarget.clamp(_camYMin, _camYMax);
    // Pan plus lent pendant l'intro (effet cinématique).
    final k = 1 - math.exp((_intro ? -2.2 : -5.0) * dt);
    _zoomCur += (_zoomTarget - _zoomCur) * (1 - math.exp(-4.0 * dt));
    _camX += (_camTarget - _camX) * k;
    _camY += (_camYTarget - _camY) * k;
  }

  void _damageTrain({int amount = 1}) {
    // Bouclier de wagon : absorbe entièrement un coup (consomme 1 charge).
    if (_shield > 0) {
      _shield -= 1;
      _floats.add(_FloatText(Offset(_trainEdgeX + 0.04, _groundY - 0.22), '🛡️',
          const Color(0xFF8FC4EE)));
      _shake = math.max(_shake, 0.12);
      return;
    }
    _trainHp -= amount;
    _hpLost += amount;
    _combo = 0;
    _streak = 0;
    _shake = math.max(_shake, 0.18);
    if (_trainHp <= 0) _gameOver(won: false);
  }

  _Enemy? _nearestOther(_Enemy not) {
    _Enemy? best;
    double bd = 1e9;
    for (final e in _enemies) {
      if (e.dying || identical(e, not)) continue;
      final d = (e.x - not.x).abs();
      if (d < bd) {
        bd = d;
        best = e;
      }
    }
    return best;
  }

  void _killEnemy(_Enemy e, {bool head = false}) {
    if (e.dying) return;
    e.dying = true;
    e.dieT = _dieDur;
    // Point 2 — RAGDOLL : il part en pantin (recule + saute + tourne). Un
    // headshot l'envoie plus fort.
    e.dieVX = (head ? 0.9 : 0.55) + _rng.nextDouble() * 0.2;
    e.dieVY = head ? -1.3 : -0.95;
    e.dieRotV = (head ? 7.0 : 4.5) * (_rng.nextBool() ? 1 : -1);
    // Point 8 — finish cinématique : coup de zoom + ralenti sur le kill.
    _camPunch = 1.0;
    _slowmo = math.max(_slowmo, head ? 0.45 : 0.3);
    _kills++;
    _combo++;
    _streak++;
    _streakT = 1.2;
    final gain = 10 * (head ? 2 : 1) * (1 + _combo ~/ 5);
    _score += gain;
    _shake = math.max(_shake, head ? 0.30 : 0.18);
    _hitStop = head ? 0.09 : 0.05;
    // Point 1 — headshot qui claque.
    if (head) {
      _floats.add(_FloatText(const Offset(_imgA * 0.5, 0.30), 'EN PLEINE TÊTE !',
          const Color(0xFFFFD24A),
          big: true));
    }
    _floats.add(_FloatText(
        Offset(e.x, e.feetY - e.height * 0.6), '+$gain',
        head ? const Color(0xFFFFD24A) : Colors.white));
    // Callouts de série.
    const calls = {3: 'Double !', 5: 'Triple !', 8: 'Carnage !', 12: 'Massacre !'};
    if (calls.containsKey(_streak)) {
      _floats.add(_FloatText(
          const Offset(_imgA * 0.5, 0.32), calls[_streak]!, const Color(0xFFFF8A3A),
          big: true));
    }
    // Frénésie.
    if (!_inFrenzy) {
      _frenzy = (_frenzy + (head ? 0.14 : 0.09)).clamp(0.0, 1.0);
      if (_frenzy >= 1.0) {
        _inFrenzy = true;
        _frenzyT = 3.5;
        _frenzy = 0;
        _slowmo = 0.5;
        _floats.add(_FloatText(const Offset(_imgA * 0.5, 0.28), 'FRÉNÉSIE !',
            const Color(0xFFFFD24A),
            big: true));
      }
    }
    // Butin (boss + doré = jackpot).
    final int v;
    if (e.type == _PillType.boss) {
      v = 60;
    } else if (e.golden) {
      v = 35; // jackpot doré (s'enfuit si on le rate)
    } else if (e.type == _PillType.brute) {
      v = 5;
    } else if (e.type == _PillType.lanceur) {
      v = 2;
    } else {
      v = 1;
    }
    _loot.add(_Loot(Offset(e.x, e.feetY - e.height * 0.5),
        Offset((_rng.nextDouble() - 0.5) * 0.3, -0.4), v));
    // Dernier de la vague -> ralenti.
    if (_toSpawn == 0 && !_enemies.any((x) => x != e && !x.dying)) {
      _slowmo = math.max(_slowmo, 0.7);
    }
  }

  void _explode(Offset pos, {bool big = false}) {
    final r = big ? 0.22 : 0.10;
    _impacts.add(_Impact(pos, blast: true));
    _shake = math.max(_shake, big ? 0.32 : 0.2);
    for (final e in _enemies) {
      if (e.dying) continue;
      final c = Offset(e.x, e.feetY - e.height * 0.5);
      if ((c - pos).distance < r) {
        e.hp = 0;
        _killEnemy(e);
      }
    }
  }

  // Ramassage de la ferraille au tap (dans les 3 s après l'atterrissage).
  void _collectAt(Offset local) {
    final ux = (local.dx - _ox) / _S, uy = (local.dy - _oy) / _S;
    _Loot? best;
    double bd = 0.08; // rayon de collecte généreux (doigt)
    for (final l in _loot) {
      if (!l.landed) continue;
      final d = (l.pos - Offset(ux, uy)).distance;
      if (d < bd) {
        bd = d;
        best = l;
      }
    }
    if (best != null) {
      _runScrap += best.value;
      _floats.add(_FloatText(Offset(best.pos.dx, _groundY - 0.05),
          '+${best.value}🔩', const Color(0xFFE8B96B)));
      _loot.remove(best);
      setState(() {});
    }
  }

  void _spawnBarrel() {
    const span = _imgA - _trainEdgeX - 0.9;
    final x = _trainEdgeX + 0.5 + _rng.nextDouble() * (span > 0 ? span : 0.3);
    _barrel = _Barrel(x.clamp(0.5, _imgA - 0.2), _groundY);
  }

  void _spawnEnemy(double baseSpeed) {
    final type = _pickType();
    final feetY = _groundY + (_rng.nextDouble() - 0.5) * 0.03;
    final anim = _rng.nextDouble() * 2;
    // Posté STATIQUE au loin. En mode duel : carrément HORS CHAMP au repos
    // (on ne le voit qu'en suivant le tir). Sinon dans la bande visible.
    final double x;
    if (_duelTest) {
      // Assez loin pour être hors champ au repos, mais pas collé au bord droit
      // -> la caméra peut le CENTRER pendant l'intro.
      x = (1.05 + _rng.nextDouble() * 0.18).clamp(0.9, _imgA - 0.25);
    } else {
      final right = _camHome + _camMin; // bord droit visible au repos
      final lo = math.min(_camHome + 0.35, right - 0.2);
      x = (lo + _rng.nextDouble() * math.max(0.12, right - 0.12 - lo))
          .clamp(0.9, _imgA - 0.1);
    }
    switch (type) {
      case _PillType.brute:
        _enemies.add(_Enemy(
          type: type, x: x, feetY: feetY,
          speed: 0, height: 0.22, anim: anim, hp: _bruteHp,
        )..throwT = _rng.nextDouble() * 2.0);
      case _PillType.lanceur:
        _enemies.add(_Enemy(
          type: type, x: x, feetY: feetY,
          speed: 0, height: 0.17, anim: anim,
          hp: _duelTest ? 6 : 1,
        )..throwT = _rng.nextDouble() * 1.5);
      case _PillType.basic:
        // Pillard doré rare : jackpot de ferraille, mais il décampe au bout de
        // quelques secondes -> il faut l'abattre vite.
        final golden = _wave >= 1 && _rng.nextDouble() < 0.08;
        _enemies.add(_Enemy(
          type: type, x: x, feetY: feetY,
          speed: 0, height: 0.16, anim: anim, golden: golden,
        )
          ..throwT = _rng.nextDouble() * 1.5
          ..meleeT = 5.5);
      case _PillType.boss:
        return; // le boss n'apparaît pas par le spawn normal
    }
  }

  _PillType _pickType() {
    if (_duelTest) return _PillType.lanceur; // test : uniquement le lanceur
    final r = _rng.nextDouble();
    final w = _wave;
    if (w >= 1) {
      if (r < 0.12 + 0.02 * w) return _PillType.brute;
      if (r < 0.38 + 0.02 * w) return _PillType.lanceur;
    }
    return _PillType.basic;
  }

  bool get _isBossWave => _mode == _Mode.campaign
      ? _wave == _campaignWaves - 1
      : (_wave > 0 && _wave % 4 == 3);

  void _spawnBoss() {
    final hp = 22 + (_mode == _Mode.endless ? _wave * 2 : 0);
    final right = _camHome + _camMin;
    final x = (right - 0.25).clamp(0.9, _imgA - 0.15);
    _enemies.add(_Enemy(
      type: _PillType.boss,
      x: x,
      feetY: _groundY + 0.01,
      speed: 0,
      height: 0.30,
      anim: 0,
      hp: hp,
    )..throwT = 0.5);
    _floats.add(_FloatText(const Offset(_imgA * 0.5, 0.30), '⚠ CHEF PILLARD',
        const Color(0xFFE2614A),
        big: true));
  }

  // ---------------------------------------------------------------------------
  // Tir
  // ---------------------------------------------------------------------------
  Offset _launchVel() {
    final pullPx = _dragStart - _dragNow;
    // Aide à la visée INDÉPENDANTE du zoom : on rapporte le glissement à la
    // hauteur d'écran (= _S / _zoomCur), pas à l'échelle zoomée. Sinon plus on
    // zoome, moins le tir porte loin. La portée reste donc proportionnelle au
    // geste quel que soit le zoom.
    final ref = _S / _zoomCur;
    final pull = Offset(pullPx.dx / ref, pullPx.dy / ref);
    var v = pull * (_power * _powerMult);
    final maxs = _maxSpeed * _powerMult;
    final sp = v.distance;
    if (sp > maxs) v = v * (maxs / sp);
    return v;
  }

  void _spawnStones(Offset v) {
    final reinforced = _combo >= 5 || _inFrenzy;
    final n = _stonesPerShot;
    for (int i = 0; i < n; i++) {
      final a = n == 1 ? 0.0 : (i - (n - 1) / 2) * 0.08;
      _stones.add(_Stone(
        _muzzle,
        _rot(v, a),
        pierce: _pierce + (reinforced ? 1 : 0),
        ricochet: _ricochet,
        splits: _split,
        big: reinforced,
        fire: _fire > 0,
        freeze: _freeze > 0,
        dmg: _baseDmg,
      ));
    }
    _impacts.add(_Impact(_muzzle, launch: true));
  }

  void _fireShot() {
    if (_reloadTimer > 0) return;
    // Duel : un seul tir par tour.
    if (_duelTest && (!_playerTurn || _awaitingStones || _enemyThrowing)) return;
    final v = _launchVel();
    if (v.distance < 0.12) return;
    _spawnStones(v);
    _reloadTimer = _reload;
    _camLaunchHold = 0.30; // montre le départ depuis la fenêtre puis suit
    if (_duelTest) {
      _playerTurn = false;
      _awaitingStones = true;
    }
  }

  void _autoFire() {
    // Vise le pillard le plus proche du train (tir direct rapide).
    _Enemy? target;
    double bx = 1e9;
    for (final e in _enemies) {
      if (e.dying) continue;
      if (e.x < bx) {
        bx = e.x;
        target = e;
      }
    }
    if (target == null) return;
    final dir =
        Offset(target.x, target.feetY - target.height * 0.5) - _muzzle;
    if (dir.distance < 1e-4) return;
    final sp = _maxSpeed * _powerMult * 1.25;
    _spawnStones(dir / dir.distance * sp);
  }

  Offset _rot(Offset v, double a) {
    final c = math.cos(a), s = math.sin(a);
    return Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
  }

  // ---------------------------------------------------------------------------
  // Vague / coffre / perk / fin
  // ---------------------------------------------------------------------------
  void _endWave() {
    if (_isLastWave) {
      _gameOver(won: true);
      return;
    }
    // Récompense ferraille + un BONUS à CHOISIR à chaque victoire de vague.
    _runScrap += (_wave + 1) * 2 + 3 + _rng.nextInt(8);
    _wave++;
    _perkChoices =
        ([..._perkData.keys]..shuffle(_rng)).take(_perkCount).toList();
    setState(() => _phase = _Phase.perk);
  }

  void _openChest() {
    setState(() {
      _chestOpened = true;
      _runScrap += _chestScrap;
      if (_chestExtra == 'heart') {
        _maxHp += 1;
        _trainHp += 1;
      }
    });
  }

  void _afterChest() {
    // Si le coffre donnait un perk gratuit, on saute droit au prochain.
    _wave++;
    _perkChoices = ([..._perkData.keys]..shuffle(_rng)).take(_perkCount).toList();
    setState(() => _phase = _Phase.perk);
  }

  void _pickPerk(String perk) {
    switch (perk) {
      case 'stone':
        _stonesPerShot++;
      case 'hearts':
        _maxHp += 1;
        _trainHp += 1;
      case 'pierce':
        _pierce++;
      case 'ricochet':
        _ricochet++;
      case 'split':
        _split++;
      case 'fire':
        _fire++;
      case 'freeze':
        _freeze++;
      case 'speed':
        _powerMult *= 1.10;
    }
    // Évolution d'arme : 3 fois le même perk dans une run -> gros bonus unique.
    _perkLevels[perk] = (_perkLevels[perk] ?? 0) + 1;
    if (_perkLevels[perk] == 3 && _evolved.add(perk)) {
      _applyEvolution(perk);
      _floats.add(_FloatText(const Offset(_imgA * 0.5, 0.34), '✦ ÉVOLUTION ✦',
          const Color(0xFFFFD24A),
          big: true));
    }
    setState(() {
      _phase = _Phase.playing;
      _banner = 1.8;
    });
  }

  // Bonus d'évolution (en plus du 3e palier) quand on se spécialise.
  // Volontairement modeste : récompense la spécialisation sans rendre le
  // joueur invincible (demande user : bonus moins importants).
  void _applyEvolution(String perk) {
    switch (perk) {
      case 'stone':
        _stonesPerShot += 1;
      case 'hearts':
        _maxHp += 2;
        _trainHp += 2;
      case 'pierce':
        _pierce += 1;
      case 'ricochet':
        _ricochet += 1;
      case 'split':
        _split += 1;
      case 'fire':
        _fire += 1;
      case 'freeze':
        _freeze += 1;
      case 'speed':
        _powerMult *= 1.12;
    }
  }

  // Bombe de secours (atelier) : frappe tout l'écran, 1 fois par vague.
  void _useBomb() {
    if (_bombLeft <= 0) return;
    _bombLeft--;
    _impacts.add(_Impact(Offset(_imgA * 0.5, _groundY - 0.2), blast: true));
    _shake = math.max(_shake, 0.4);
    for (final e in List.of(_enemies)) {
      if (e.dying || e.type == _PillType.boss) continue;
      e.hp = 0;
      _killEnemy(e);
    }
    setState(() {});
  }

  // Quitter une partie en cours : on encaisse la ferraille gagnée puis menu.
  void _quitToMenu() {
    final gs = GameState.instance;
    if (_runScrap > 0) {
      gs.scrap += (_runScrap * (_mode == _Mode.endless ? 0.5 : 1.0)).round();
      _runScrap = 0;
      gs.save();
    }
    setState(() => _phase = _Phase.menu);
  }

  void _gameOver({required bool won}) {
    _won = won;
    final gs = GameState.instance;
    _wonStars = won ? (_hpLost == 0 ? 3 : (_hpLost <= 2 ? 2 : 1)) : 0;
    if (won && _wonStars > gs.shootBestStars) gs.shootBestStars = _wonStars;
    _weaponUp = false;
    if (won && _mode == _Mode.campaign && gs.shootWeaponLevel < 3) {
      _weaponUp = true;
      gs.shootWeaponLevel++;
    }
    _newRecord = _score > gs.shootBestScore;
    if (_newRecord) gs.shootBestScore = _score;
    // Ferraille (encaissée + remise à 0 pour ne pas double-compter si on
    // continue en survie) + récompense au jeu principal.
    // Entraînement (survie) : ferraille divisée par 2 pour ne pas
    // déséquilibrer la campagne.
    _shownScrap = (_runScrap * (_mode == _Mode.endless ? 0.5 : 1.0)).round();
    // Quasi-victoire : perdu sur la DERNIÈRE vague -> consolation (le quasi-
    // échec est le plus gros moteur de "encore une fois").
    _nearMiss =
        !won && _mode == _Mode.campaign && _wave >= _campaignWaves - 1;
    if (_nearMiss) _shownScrap += 15;
    gs.scrap += _shownScrap;
    _runScrap = 0;
    // Alimente les missions quotidiennes.
    gs.reportCombat(
      kills: _kills,
      scrapCollected: _shownScrap,
      perfect: won && _hpLost == 0,
    );
    // Hors mode gare : petit bonus direct. En mode gare, les ressources sont
    // attribuées par applyCombatRewards(score100) quand on valide l'écran de fin.
    if (won && !_gareMode) {
      gs.nudgeCardStat('bois', 8);
      gs.nudgeCardStat('moral', 6);
    }
    gs.save();
    setState(() => _phase = _Phase.gameover);
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B2230),
      body: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          // Caméra : 1 unité = hauteur écran × zoom courant (eased entre repos
          // et reculé). + petit "punch" sur le coup fatal.
          final scale = h * _zoomCur * (1 + 0.06 * _camPunch);
          _S = scale;
          final dispW = _imgA * scale, dispH = scale;
          final viewHalf = (w / scale) / 2;
          _camMin = viewHalf;
          _camMax = math.max(viewHalf, _imgA - viewHalf);
          // Repos : train calé à gauche (centre = demi-vue au zoom de repos).
          final restViewHalf = w / (2 * h * _zoomRest);
          _camHome = restViewHalf.clamp(_camMin, _camMax).toDouble();
          // Bornes verticales : la scène fait 1 unité de haut.
          final viewHalfY = (h / scale) / 2;
          _camYMin = viewHalfY;
          _camYMax = math.max(viewHalfY, 1.0 - viewHalfY);
          _camYHome = (1.0 - viewHalfY).clamp(_camYMin, _camYMax).toDouble();
          if (!_camInit) {
            _camX = _camTarget = _camHome;
            _camY = _camYTarget = _camYHome;
            _camInit = true;
          }
          _camX = _camX.clamp(_camMin, _camMax);
          _camY = _camY.clamp(_camYMin, _camYMax);
          // Décalage du gameplay (suit la caméra 1:1, X et Y).
          _ox = w / 2 - _camX * scale;
          _oy = h / 2 - _camY * scale;
          // Parallaxe : le FOND LOINTAIN bouge plus lentement que le plan de
          // jeu (mid/train, eux à 1:1). Aligné au repos.
          final camFar = _camHome + (_camX - _camHome) * _kBg;
          final oxFar = w / 2 - camFar * scale;
          Offset u2p(Offset u) => Offset(_ox + u.dx * _S, _oy + u.dy * _S);
          final canAim = _phase == _Phase.playing &&
              !_adjust &&
              _banner <= 0 &&
              !_intro &&
              (!_duelTest || _playerTurn);
          final canTap = _phase == _Phase.playing && !_adjust;
          final shakeOffset = _shake > 0
              ? Offset(_rng.nextDouble() - 0.5, _rng.nextDouble() - 0.5) *
                  (_shake / 0.16) *
                  14
              : Offset.zero;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: canTap ? (d) => _collectAt(d.localPosition) : null,
            onPanStart: canAim
                ? (d) {
                    // Glisser depuis la GAUCHE (près du train) = viser. Glisser
                    // depuis la droite = CAMÉRA LIBRE (regarder où est la cible).
                    if (d.localPosition.dx < w * 0.34) {
                      _dragStart = d.localPosition;
                      _dragNow = d.localPosition;
                      setState(() => _aiming = true);
                    } else {
                      _lookX = _camX;
                      setState(() => _looking = true);
                    }
                  }
                : null,
            onPanUpdate: canAim
                ? (d) {
                    if (_aiming) {
                      setState(() => _dragNow = d.localPosition);
                    } else if (_looking) {
                      setState(() {
                        _lookX = (_lookX - d.delta.dx / _S)
                            .clamp(_camMin, _camMax);
                      });
                    }
                  }
                : null,
            onPanEnd: canAim
                ? (_) {
                    if (_aiming) _fireShot();
                    setState(() {
                      _aiming = false;
                      _looking = false;
                    });
                  }
                : null,
            child: Transform.translate(
              offset: shakeOffset,
              child: Stack(
                fit: StackFit.expand, // sinon le Stack (tout en Positioned)
                // se réduit à 0×0 sous les contraintes lâches de
                // l'AnimatedSwitcher -> body invisible (écran bleu).
                children: [
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF7C8597),
                            Color(0xFF3A3F49),
                            Color(0xFF20242C),
                          ],
                          stops: [0.0, 0.62, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // COUCHE 1 — fond lointain (parallaxe lente), légèrement
                  // surdimensionné pour ne jamais laisser de bord visible.
                  Positioned(
                    left: oxFar - dispW * 0.15,
                    top: _oy - dispH * 0.15,
                    width: dispW * 1.3,
                    height: dispH * 1.3,
                    child: const Image(
                      image: AssetImage('assets/background/combat_far.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  // COUCHE 2 — plan de jeu (gare/sol), ciel transparent -> le
                  // fond apparaît. À 1:1 avec la caméra.
                  Positioned(
                    left: _ox,
                    top: _oy,
                    width: dispW,
                    height: dispH,
                    child: const Image(
                      image: AssetImage('assets/background/combat_mid.png'),
                      fit: BoxFit.fill,
                    ),
                  ),

                  // Flaques de feu (sous les pillards).
                  for (final p in _fires) _buildFire(p),
                  if (_barrel != null) _buildBarrel(_barrel!),
                  for (final e in _enemies) _buildEnemy(e),

                  // COUCHE 3 — le TRAIN au premier plan (occlude la gauche).
                  Positioned(
                    left: _ox,
                    top: _oy,
                    width: dispW,
                    height: dispH,
                    child: const IgnorePointer(
                      child: Image(
                        image: AssetImage('assets/background/combat_train.png'),
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),

                  // Butin (ferraille qui tombe).
                  for (final l in _loot) _buildLoot(l),

                  // Cailloux / impacts / visée.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _ShotPainter(
                          stones: _stones,
                          impacts: _impacts,
                          enemyShots: _enemyShots,
                          anchor: u2p(_muzzle),
                          aiming: _aiming && _phase == _Phase.playing,
                          launchVel: _aiming ? _launchVel() : null,
                          g: _g,
                          ox: _ox,
                          oy: _oy,
                          scale: _S,
                        ),
                      ),
                    ),
                  ),

                  // Voile de tempête (assombrit la scène).
                  if (_storm && _phase == _Phase.playing)
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: Color(0x44101820)),
                        ),
                      ),
                    ),

                  // Nom de l'ennemi pendant l'intro de duel.
                  if (_intro) _buildFoeNameLabel(u2p),

                  // Indicateur PUISSANCE / ANGLE pendant la visée (Bowmasters).
                  if (_aiming && _phase == _Phase.playing) _powerAngleChip(),

                  // Petit halo dans la fenêtre quand le pillard touche.
                  if (_windowHalo > 0) _buildWindowHalo(u2p),

                  // Textes flottants.
                  for (final f in _floats) _buildFloat(f),

                  if (_adjust) ..._adjustHandles(u2p),
                  if (_phase == _Phase.playing) _bossBar(),
                  if (_phase == _Phase.playing) _hudBar(),
                  if (_phase == _Phase.playing && _banner > 0) _bannerWidget(),
                  if (_adjust) _coordHud(),

                  if (_phase == _Phase.menu) _menu(),
                  if (_phase == _Phase.progress) _progressOverlay(),
                  if (_phase == _Phase.atelier) _atelier(),
                  if (_phase == _Phase.chest) _chestOverlay(),
                  if (_phase == _Phase.perk) _perkOverlay(),
                  if (_phase == _Phase.gameover) _endOverlay(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ----- entités visuelles -----
  // Nom de l'ennemi affiché au-dessus de lui pendant l'intro de duel.
  Widget _buildFoeNameLabel(Offset Function(Offset) u2p) {
    _Enemy? foe;
    for (final e in _enemies) {
      if (!e.dying) {
        foe = e;
        break;
      }
    }
    if (foe == null) return const SizedBox.shrink();
    final head = u2p(Offset(foe.x, foe.feetY - foe.height * 1.05));
    // Fondu : apparaît puis reste.
    final a = (1.0 - (_introT - 1.5).clamp(0.0, 1.5) / 1.5).clamp(0.0, 1.0);
    return Positioned(
      left: head.dx - 100,
      top: (head.dy - 26).clamp(6.0, double.infinity),
      width: 200,
      child: IgnorePointer(
        child: Opacity(
          opacity: a,
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2614A), width: 1.2),
              ),
              child: Text(
                _foeName,
                style: const TextStyle(
                  color: Color(0xFFFFD9A0),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Pastille PUISSANCE / ANGLE pendant la visée — position FIXE (bas-centre)
  // pour rester visible quelle que soit la caméra/le dézoom.
  Widget _powerAngleChip() {
    final v = _launchVel();
    final maxs = _maxSpeed * _powerMult;
    final powerPct = (v.distance / (maxs <= 0 ? 1 : maxs) * 100).clamp(0, 100).round();
    final angle = (math.atan2(-v.dy, v.dx.abs() < 1e-4 ? 1e-4 : v.dx) * 180 / math.pi)
        .clamp(-90, 90)
        .round();
    return Positioned(
      left: 0,
      right: 0,
      bottom: 24,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$powerPct%',
                      style: const TextStyle(
                          color: Color(0xFF5A3E8E),
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  const Text('PUISSANCE',
                      style: TextStyle(color: Color(0xFF8A7AA8), fontSize: 8)),
                ]),
                Container(
                    width: 1,
                    height: 26,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    color: const Color(0x335A3E8E)),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$angle°',
                      style: const TextStyle(
                          color: Color(0xFF5A3E8E),
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  const Text('ANGLE',
                      style: TextStyle(color: Color(0xFF8A7AA8), fontSize: 8)),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Petit halo lumineux À L'INTÉRIEUR de la fenêtre quand le pillard touche.
  // Discret : un point chaud qui pulse et s'éteint.
  Widget _buildWindowHalo(Offset Function(Offset) u2p) {
    final c = u2p(_muzzle);
    final life = (_windowHalo / 1.2).clamp(0.0, 1.0);
    final size = 0.05 * _S * (0.8 + 0.2 * life);
    return Positioned(
      left: c.dx - size / 2,
      top: c.dy - size / 2,
      width: size,
      height: size,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              const Color(0xFFFFB347).withValues(alpha: 0.9 * life),
              const Color(0xFFFF6A2A).withValues(alpha: 0.5 * life),
              const Color(0x00000000),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildEnemy(_Enemy e) {
    final boxSize = e.height / _pillContentH * _S;
    final left = _ox + e.x * _S - boxSize / 2;
    final top = _oy + e.feetY * _S - _pillFeet * boxSize;
    String asset;
    double opacity = 1.0;
    double rot = 0;
    bool mirror = true;
    if (e.dying) {
      // Ragdoll : on garde le sprite vivant et on le fait TOURNER (pantin).
      asset = _liveAsset(e);
      rot = e.dieRot;
      if (e.dieT < 0.3) opacity = (e.dieT / 0.3).clamp(0.0, 1.0);
    } else {
      asset = _liveAsset(e);
      // Tombe à la renverse puis se relève (touché au corps).
      if (e.staggerT > 0) rot = 1.15 * (e.staggerT / 0.9).clamp(0.0, 1.0);
    }
    // cacheWidth : on décode petit (les pillards s'affichent en ~100-180 px) ->
    // mémoire image divisée par ~4, évite l'OOM en combat.
    Widget img = Image.asset(asset,
        fit: BoxFit.contain, gaplessPlayback: true, cacheWidth: 256);
    if (e.golden && !e.dying) {
      img = ColorFiltered(
        colorFilter: const ColorFilter.mode(Color(0x99FFD24A), BlendMode.srcATop),
        child: img,
      );
    }
    if (e.slowT > 0 && !e.dying) {
      img = ColorFiltered(
        colorFilter: const ColorFilter.mode(Color(0x6688D8FF), BlendMode.srcATop),
        child: img,
      );
    }
    if (mirror) {
      img = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scaleByDouble(-1.0, 1.0, 1.0, 1.0),
        child: img,
      );
    }
    if (rot != 0) {
      img = Transform.rotate(
          angle: rot,
          alignment: e.dying ? Alignment.center : Alignment.bottomCenter,
          child: img);
    }
    if (opacity < 1.0) img = Opacity(opacity: opacity, child: img);

    Widget content = img;
    if (e.type == _PillType.brute && !e.dying && e.hp < e.hpMax) {
      content = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: img),
          Positioned(
            top: boxSize * 0.06,
            left: boxSize * 0.30,
            right: boxSize * 0.30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < e.hpMax; i++)
                  Container(
                    width: 6,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    color: i < e.hp
                        ? const Color(0xFFE2614A)
                        : const Color(0x55000000),
                  ),
              ],
            ),
          ),
        ],
      );
    }
    return Positioned(
      left: left,
      top: top,
      width: boxSize,
      height: boxSize,
      child: IgnorePointer(child: content),
    );
  }

  String _liveAsset(_Enemy e) {
    final wf = (e.anim * 16).floor() % 49 + 1;
    switch (e.type) {
      case _PillType.basic:
        return 'assets/characters/pillard1_walk_$wf.png';
      case _PillType.brute:
      case _PillType.boss:
        // Le boss réutilise les sprites de la brute (agrandis).
        if (e.attacking || e.melee) {
          final af = e.attacking
              ? (e.attackT / _bruteAtkDur * 49).floor().clamp(0, 48) + 1
              : (e.anim * 14).floor() % 49 + 1;
          return 'assets/characters/brute_attack_$af.png';
        }
        return 'assets/characters/brute_walk_$wf.png';
      case _PillType.lanceur:
        if (e.throwing) {
          final pf = ((e.throwT % _throwPeriod) / _throwPeriod * 49)
                  .floor()
                  .clamp(0, 48) +
              1;
          return 'assets/characters/lanceur_throw_$pf.png';
        }
        return 'assets/characters/lanceur_walk_$wf.png';
    }
  }

  Widget _buildBarrel(_Barrel b) {
    final s = 0.085 * _S;
    return Positioned(
      left: _ox + b.x * _S - s / 2,
      top: _oy + b.feetY * _S - s,
      width: s,
      height: s,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF8A3B2E),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: const Color(0xFF3A1C16), width: 1.5),
          ),
          alignment: Alignment.center,
          child: const Text('☠',
              style: TextStyle(color: Color(0xFFFFD24A), fontSize: 14)),
        ),
      ),
    );
  }

  Widget _buildFire(_FirePatch p) {
    final wPx = 0.12 * _S;
    final a = (p.life / 3.0).clamp(0.0, 1.0);
    return Positioned(
      left: _ox + p.x * _S - wPx / 2,
      top: _oy + p.feetY * _S - 0.05 * _S,
      width: wPx,
      height: 0.06 * _S,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.6 * a,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD24A), Color(0xFFFF6A2A)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoot(_Loot l) {
    final landed = l.landed;
    final pulse = landed ? (1 + 0.12 * math.sin(l.life * 12)) : 1.0;
    final s = (landed ? 0.052 * _S : 0.035 * _S) * pulse;
    final op = (landed && l.life < 0.8) ? (l.life / 0.8).clamp(0.0, 1.0) : 1.0;
    return Positioned(
      left: _ox + l.pos.dx * _S - s / 2,
      top: _oy + l.pos.dy * _S - s / 2,
      width: s,
      height: s,
      child: IgnorePointer(
        child: Opacity(
          opacity: op,
          child: Container(
            decoration: landed
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0x33FFD24A),
                    border:
                        Border.all(color: const Color(0xCCE8B96B), width: 1.5),
                  )
                : null,
            alignment: Alignment.center,
            child: Text('🔩', style: TextStyle(fontSize: landed ? 15 : 12)),
          ),
        ),
      ),
    );
  }

  Widget _buildFloat(_FloatText f) {
    final p = Offset(_ox + f.pos.dx * _S, _oy + f.pos.dy * _S - f.t * 40);
    return Positioned(
      left: p.dx - 60,
      top: p.dy - 12,
      width: 120,
      child: IgnorePointer(
        child: Opacity(
          opacity: (1 - f.t).clamp(0.0, 1.0),
          child: Text(
            f.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: f.color,
              fontSize: f.big ? 26 : 15,
              fontWeight: FontWeight.w800,
              shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
            ),
          ),
        ),
      ),
    );
  }

  // ----- HUD -----
  Widget _hudBar() => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _hud(_mode == _Mode.campaign
                        ? 'Vague ${_wave + 1}/$_campaignWaves'
                        : 'Vague ${_wave + 1}'),
                    const SizedBox(width: 10),
                    _hearts(),
                    if (_shield > 0) ...[
                      const SizedBox(width: 6),
                      _hud('🛡️$_shield'),
                    ],
                    const Spacer(),
                    _hud('$_score pts'),
                    const SizedBox(width: 8),
                    _hud('🔩$_runScrap'),
                    const SizedBox(width: 8),
                    if (_bombLeft > 0) ...[
                      FloatingActionButton.small(
                        heroTag: 'shoot_bomb',
                        backgroundColor: const Color(0xFFE2614A),
                        foregroundColor: Colors.white,
                        onPressed: _useBomb,
                        child: const Text('💣', style: TextStyle(fontSize: 18)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    // Réglage canon/sol (recalibrage sur le nouveau décor).
                    FloatingActionButton.small(
                      heroTag: 'shoot_adjust',
                      backgroundColor:
                          _adjust ? const Color(0xFFE8B96B) : Colors.black54,
                      foregroundColor:
                          _adjust ? const Color(0xFF2A2018) : Colors.white,
                      onPressed: () => setState(() => _adjust = !_adjust),
                      child: Icon(_adjust ? Icons.check : Icons.edit),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton.small(
                      heroTag: 'shoot_quit',
                      backgroundColor: Colors.black54,
                      // En mode gare : pas de menu, abandonner = défense perdue
                      // (on file vers l'écran de fin pour récolter le score).
                      onPressed:
                          _gareMode ? () => _gameOver(won: false) : _quitToMenu,
                      child: Icon(_gareMode ? Icons.flag : Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Jauge de frénésie.
                SizedBox(
                  width: 180,
                  height: 7,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _inFrenzy ? 1.0 : _frenzy,
                      backgroundColor: Colors.black45,
                      valueColor: AlwaysStoppedAnimation(
                          _inFrenzy ? const Color(0xFFFFD24A) : const Color(0xFFFF8A3A)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _bossBar() {
    _Enemy? boss;
    for (final e in _enemies) {
      if (e.type == _PillType.boss && !e.dying) {
        boss = e;
        break;
      }
    }
    if (boss == null) return const SizedBox.shrink();
    final frac = (boss.hp / boss.hpMax).clamp(0.0, 1.0);
    return Positioned(
      top: 56,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚠ CHEF PILLARD',
                  style: TextStyle(
                      color: Color(0xFFE2614A),
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: SizedBox(
                  width: 260,
                  height: 12,
                  child: LinearProgressIndicator(
                    value: frac,
                    backgroundColor: Colors.black54,
                    valueColor:
                        const AlwaysStoppedAnimation(Color(0xFFE2614A)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bannerWidget() => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text('Vague ${_wave + 1}',
              style: const TextStyle(
                  color: Color(0xFFFFD9A0),
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2)),
        ),
      );

  Widget _hud(String s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(s,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
      );

  Widget _hearts() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < _maxHp.clamp(0, 10); i++)
              Icon(i < _trainHp ? Icons.favorite : Icons.favorite_border,
                  color: const Color(0xFFE2614A), size: 16),
          ],
        ),
      );

  // ----- réglage -----
  List<Widget> _adjustHandles(Offset Function(Offset) u2p) {
    final muz = u2p(_muzzle);
    return [
      Positioned(
        left: 0,
        right: 0,
        top: _oy + _groundY * _S - 16,
        height: 32,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) => setState(() {
            _groundY = (_groundY + d.delta.dy / _S).clamp(0.4, 1.0);
            GameState.instance.setShootMuzzle(_muzX, _muzY, _groundY);
          }),
          child: Center(
              child: Container(height: 2, color: const Color(0xCC66E0FF))),
        ),
      ),
      Positioned(
        left: muz.dx - 22,
        top: muz.dy - 22,
        width: 44,
        height: 44,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) => setState(() {
            _muzX = (_muzX + d.delta.dx / _S).clamp(0.0, _imgA);
            _muzY = (_muzY + d.delta.dy / _S).clamp(0.0, 1.0);
            GameState.instance.setShootMuzzle(_muzX, _muzY, _groundY);
          }),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE8B96B), width: 2),
              color: const Color(0x55E8B96B),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _coordHud() => Positioned(
        left: 10,
        bottom: 10,
        child: IgnorePointer(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'muzX ${_muzX.toStringAsFixed(3)}  muzY ${_muzY.toStringAsFixed(3)}  solY ${_groundY.toStringAsFixed(3)}',
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ),
      );

  // ----- overlays -----
  Widget _scrim(Widget child) => Positioned.fill(
        child: Container(
          color: Colors.black.withValues(alpha: 0.72),
          child: Center(child: child),
        ),
      );

  Widget _menu() => _scrim(Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Défense de la gare',
              style: TextStyle(
                  color: Color(0xFFFFD9A0),
                  fontSize: 30,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('🔩 ${GameState.instance.scrap}    🏆 ${GameState.instance.shootBestScore} pts',
              style: const TextStyle(color: Colors.white70, fontSize: 15)),
          const SizedBox(height: 26),
          _menuBtn('Campagne', const Color(0xFFE8B96B),
              () => _startRun(_Mode.campaign)),
          const SizedBox(height: 12),
          _menuBtn('Entraînement (survie)', const Color(0xFF8A3B2E),
              () => _startRun(_Mode.endless)),
          const SizedBox(height: 12),
          _menuBtn('Atelier 🔧', const Color(0xFF3A4656),
              () => setState(() => _phase = _Phase.atelier)),
          const SizedBox(height: 12),
          _menuBtn(
              _dailyHasReward ? 'Quotidien & Gares 🎁' : 'Quotidien & Gares',
              _dailyHasReward
                  ? const Color(0xFF3E7A4E)
                  : const Color(0xFF3A4656),
              () => setState(() => _phase = _Phase.progress)),
          const SizedBox(height: 20),
          TextButton(
              onPressed: widget.onExit,
              child: const Text('Quitter',
                  style: TextStyle(color: Colors.white54))),
        ],
      ));

  // Vrai si un coffre quotidien ou une mission est réclamable (pastille menu).
  bool get _dailyHasReward {
    final gs = GameState.instance;
    return gs.dailyChestAvailable ||
        GameState.dailyMissions.keys.any(gs.dailyReady);
  }

  // ----- overlay "Quotidien & Gares" : coffre du jour + missions + étoiles -----
  Widget _progressOverlay() {
    final gs = GameState.instance;
    return _scrim(SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Quotidien',
              style: TextStyle(
                  color: Color(0xFFFFD9A0),
                  fontSize: 26,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          // Coffre du jour.
          GestureDetector(
            onTap: gs.dailyChestAvailable
                ? () {
                    final r = gs.claimDailyChest();
                    setState(() {});
                    _floats.add(_FloatText(const Offset(_imgA * 0.5, 0.3),
                        '+$r🔩', const Color(0xFFE8B96B)));
                  }
                : null,
            child: Container(
              width: 280,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: gs.dailyChestAvailable
                    ? const Color(0xFF3E7A4E)
                    : const Color(0xFF2A2018),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8B96B), width: 1.2),
              ),
              child: Text(
                gs.dailyChestAvailable
                    ? '🎁 Coffre du jour — toucher !'
                    : '🎁 Coffre déjà ouvert (reviens demain)',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Missions du jour',
              style: TextStyle(
                  color: Color(0xFFFFD9A0),
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final id in GameState.dailyMissions.keys) _missionRow(id),
          const SizedBox(height: 18),
          Text('Gares — ⭐ ${gs.totalGareStars} / 42',
              style: const TextStyle(
                  color: Color(0xFFFFD9A0),
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SizedBox(
            width: 300,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (int i = 0; i < 14; i++) _gareStarCell(i),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _menuBtn('Retour', const Color(0xFF3A4656),
              () => setState(() => _phase = _Phase.menu)),
        ],
      ),
    ));
  }

  Widget _missionRow(String id) {
    final gs = GameState.instance;
    final m = GameState.dailyMissions[id]!;
    final prog = gs.dailyProgress(id).clamp(0, m.$2);
    final ready = gs.dailyReady(id);
    final claimed = gs.dailyClaimed.contains(id);
    return Container(
      width: 300,
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2018),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.$1,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
                Text('$prog / ${m.$2}   •   🔩${m.$3}',
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          if (claimed)
            const Icon(Icons.check_circle, color: Color(0xFF7FB86A), size: 22)
          else if (ready)
            GestureDetector(
              onTap: () {
                final r = gs.claimDailyMission(id);
                setState(() {});
                _floats.add(_FloatText(const Offset(_imgA * 0.5, 0.3), '+$r🔩',
                    const Color(0xFFE8B96B)));
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3E7A4E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Réclamer',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _gareStarCell(int i) {
    final stars = GameState.instance.gareStars(i);
    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2018),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: stars > 0
                ? const Color(0xFFE8B96B)
                : Colors.white12,
            width: 1),
      ),
      child: Column(
        children: [
          Text('G${i + 1}',
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          Text(stars > 0 ? '⭐' * stars : '·',
              style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _menuBtn(String label, Color color, VoidCallback onTap) => SizedBox(
        width: 240,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: Text(label,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
      );

  Widget _atelier() => _scrim(SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Atelier',
                style: TextStyle(
                    color: Color(0xFFFFD9A0),
                    fontSize: 26,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Ferraille : 🔩 ${GameState.instance.scrap}',
                style: const TextStyle(color: Colors.white70, fontSize: 15)),
            const SizedBox(height: 16),
            for (final entry in _shopDefs.entries) _shopCard(entry.key),
            const SizedBox(height: 12),
            _menuBtn('Retour', const Color(0xFF3A4656),
                () => setState(() => _phase = _Phase.menu)),
          ],
        ),
      ));

  Widget _shopCard(String key) {
    final gs = GameState.instance;
    final def = _shopDefs[key]!;
    final lvl = gs.shootUpgrades[key] ?? 0;
    final maxed = lvl >= def.$3.length;
    final cost = maxed ? 0 : def.$3[lvl];
    final canBuy = !maxed && gs.scrap >= cost;
    return Container(
      width: 320,
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2018),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x55E8B96B)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${def.$1}  (niv $lvl${maxed ? ' max' : ''})',
                    style: const TextStyle(
                        color: Color(0xFFFFD9A0),
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                Text(def.$2,
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: canBuy
                ? () => setState(() => gs.buyShootUpgrade(key))
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE8B96B),
              foregroundColor: const Color(0xFF2A2018),
              disabledBackgroundColor: Colors.white12,
            ),
            child: Text(maxed ? 'MAX' : '🔩$cost'),
          ),
        ],
      ),
    );
  }

  Widget _chestOverlay() => _scrim(Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Coffre de fin de vague',
              style: TextStyle(
                  color: Color(0xFFFFD9A0),
                  fontSize: 22,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 18),
          if (!_chestOpened)
            GestureDetector(
              onTap: _openChest,
              child: const Text('🎁', style: TextStyle(fontSize: 90)),
            )
          else ...[
            const Text('✨', style: TextStyle(fontSize: 50)),
            const SizedBox(height: 8),
            Text('🔩 +$_chestScrap',
                style: const TextStyle(
                    color: Color(0xFFE8B96B),
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
            if (_chestExtra == 'heart')
              const Text('❤️ +1 cœur',
                  style: TextStyle(color: Color(0xFFE2614A), fontSize: 18)),
            if (_chestExtra == 'perk')
              const Text('🎁 Renfort bonus !',
                  style: TextStyle(color: Color(0xFFB6E3A8), fontSize: 18)),
          ],
          const SizedBox(height: 18),
          if (!_chestOpened)
            const Text('Touche le coffre',
                style: TextStyle(color: Colors.white54, fontSize: 14))
          else
            _menuBtn('Continuer', const Color(0xFFE8B96B), _afterChest),
        ],
      ));

  Widget _perkOverlay() => _scrim(Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Renfort — choisis-en un',
              style: TextStyle(
                  color: Color(0xFFFFD9A0),
                  fontSize: 22,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final perk in _perkChoices)
                _choiceCard(
                  emoji: _perkData[perk]!.$1,
                  title: _perkData[perk]!.$2,
                  desc: _perkData[perk]!.$3,
                  onTap: () => _pickPerk(perk),
                ),
            ],
          ),
        ],
      ));

  Widget _choiceCard({
    required String emoji,
    required String title,
    required String desc,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 150,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2018),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8B96B), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(height: 8),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFFFFD9A0),
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(desc,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      );

  Widget _endOverlay() => _scrim(SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _won ? 'Train défendu !' : 'Le train est tombé…',
              style: TextStyle(
                color:
                    _won ? const Color(0xFFB6E3A8) : const Color(0xFFE2614A),
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            if (_won && _mode == _Mode.campaign)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < 3; i++)
                    Icon(i < _wonStars ? Icons.star : Icons.star_border,
                        color: const Color(0xFFFFD24A), size: 38),
                ],
              ),
            const SizedBox(height: 8),
            if (_gareMode) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < 3; i++)
                    Icon(
                        i < GameState.starsForScore(_score100)
                            ? Icons.star
                            : Icons.star_border,
                        color: const Color(0xFFFFD24A),
                        size: 40),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('Score de gare : $_score100 / 100',
                    style: const TextStyle(
                        color: Color(0xFFE8B96B),
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
              ),
            ],
            if (_nearMiss)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('Si près ! 🔩 +15 de consolation',
                    style: TextStyle(
                        color: Color(0xFFE2A33A),
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
            Text('Score $_score   •   💥$_kills   •   🔩+$_shownScrap',
                style: const TextStyle(color: Colors.white70, fontSize: 15)),
            if (_newRecord)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('🏆 Nouveau record !',
                    style: TextStyle(
                        color: Color(0xFFFFD24A),
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
            if (_won && _weaponUp)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '🔓 Nouvelle arme : ${_weaponNames[GameState.instance.shootWeaponLevel.clamp(0, 3)]}',
                  style: const TextStyle(
                      color: Color(0xFFE8B96B),
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: _gareMode
                  ? [
                      // Combat de gare : on récolte le score (ressources +
                      // branche d'histoire) puis on rend la main à l'écran cartes.
                      _menuBtn('Récolter et continuer', const Color(0xFFE8B96B),
                          () => widget.onResult!(_score100)),
                      _menuBtn('Réessayer', const Color(0xFF8A3B2E),
                          () => _startRun(_Mode.campaign)),
                    ]
                  : [
                      if (_won && _mode == _Mode.campaign)
                        _menuBtn('Continuer en survie', const Color(0xFF8A3B2E),
                            () {
                          // reprend là où on s'est arrêté, en survie.
                          setState(() {
                            _mode = _Mode.endless;
                            _phase = _Phase.playing;
                            _won = false;
                            _banner = 1.8;
                            _wave++;
                          });
                        }),
                      _menuBtn('Rejouer', const Color(0xFFE8B96B),
                          () => _startRun(_mode)),
                      _menuBtn('Menu', const Color(0xFF3A4656),
                          () => setState(() => _phase = _Phase.menu)),
                    ],
            ),
          ],
        ),
      ));
}

class _ShotPainter extends CustomPainter {
  _ShotPainter({
    required this.stones,
    required this.impacts,
    required this.enemyShots,
    required this.anchor,
    required this.aiming,
    required this.launchVel,
    required this.g,
    required this.ox,
    required this.oy,
    required this.scale,
  });
  final List<_Stone> stones;
  final List<_Impact> impacts;
  final List<_EnemyShot> enemyShots;
  final Offset anchor;
  final bool aiming;
  final Offset? launchVel;
  final double g;
  final double ox;
  final double oy;
  final double scale;

  Offset _p(Offset u) => Offset(ox + u.dx * scale, oy + u.dy * scale);

  @override
  void paint(Canvas canvas, Size size) {
    final stonePaint = Paint()..color = const Color(0xFF6E6258);
    final stoneEdge = Paint()
      ..color = const Color(0xFF453E37)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final s in stones) {
      final p = _p(s.pos);
      final rr = (s.big ? 0.012 : 0.008) * scale;
      // Petite traînée d'air derrière le caillou (points qui s'estompent).
      for (int i = 0; i < s.trail.length; i++) {
        final f = (i + 1) / (s.trail.length + 1);
        canvas.drawCircle(
          _p(s.trail[i]),
          rr * (0.35 + 0.5 * f),
          Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.28 * f),
        );
      }
      if (s.big) {
        canvas.drawCircle(p, rr * 1.6, Paint()..color = const Color(0x55FFD24A));
      }
      canvas.drawCircle(
          p, rr, s.big ? (Paint()..color = const Color(0xFFE8B96B)) : stonePaint);
      canvas.drawCircle(p, rr, stoneEdge);
    }

    final enemyPaint = Paint()..color = const Color(0xFF8A4A3A);
    for (final es in enemyShots) {
      final rr = 0.009 * scale;
      for (int i = 0; i < es.trail.length; i++) {
        final f = (i + 1) / (es.trail.length + 1);
        canvas.drawCircle(
          _p(es.trail[i]),
          rr * (0.35 + 0.5 * f),
          Paint()..color = const Color(0xFFB57A5A).withValues(alpha: 0.30 * f),
        );
      }
      canvas.drawCircle(_p(es.pos), rr, enemyPaint);
    }

    for (final im in impacts) {
      final c = _p(im.pos);
      final t = im.t.clamp(0.0, 1.0);
      final a = (1 - t);
      if (im.launch) {
        final r = (0.01 + 0.04 * t) * scale;
        canvas.drawCircle(
          c + Offset(0.02 * scale * t, -0.015 * scale * t),
          r,
          Paint()
            ..color = const Color(0xFFD8D2C4).withValues(alpha: 0.5 * a)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        continue;
      }
      if (im.blast) {
        final r = (0.04 + 0.16 * t) * scale;
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..color = const Color(0xFFFF8A3A).withValues(alpha: 0.55 * a)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..color = const Color(0xFFFFD24A).withValues(alpha: 0.8 * a)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        continue;
      }
      // Impact "caillou" : un flash bref + une gerbe de petits débris qui
      // jaillissent et retombent. Plus satisfaisant qu'un anneau.
      final base = im.crit ? const Color(0xFFFFD24A) : const Color(0xFFD8C8AC);
      // Flash court.
      if (t < 0.35) {
        final ft = 1 - t / 0.35;
        canvas.drawCircle(
          c,
          (0.006 + 0.006 * (1 - ft)) * scale,
          Paint()..color = Colors.white.withValues(alpha: 0.85 * ft),
        );
      }
      // Débris (gerbe).
      final n = im.crit ? 9 : 6;
      for (int i = 0; i < n; i++) {
        final ang = ((im.seed + i * 53) % 360) * math.pi / 180;
        final speed = 0.04 + ((im.seed >> i) % 7) * 0.006;
        final dist = speed * t * scale * 6;
        final dx = math.cos(ang) * dist;
        // gravité : retombe (le t² tire vers le bas)
        final dy = math.sin(ang) * dist * 0.6 + 0.5 * t * t * 0.10 * scale;
        final pr = (im.crit ? 2.4 : 1.8) * (1 - t);
        if (pr <= 0) continue;
        canvas.drawCircle(
          c + Offset(dx, dy),
          pr,
          Paint()..color = base.withValues(alpha: 0.95 * a),
        );
      }
    }

    if (aiming && launchVel != null) {
      // Arc de visée : trait PLEIN rouge, qui suit la vraie trajectoire de la
      // pierre (même physique) jusqu'au sol.
      Offset pos = Offset((anchor.dx - ox) / scale, (anchor.dy - oy) / scale);
      Offset vel = launchVel!;
      const double step = 0.03;
      final path = Path()..moveTo(_p(pos).dx, _p(pos).dy);
      // Arc court : juste un guide de départ (≈ le début de la trajectoire).
      for (int i = 0; i < 22; i++) {
        vel = vel + Offset(0, g * step);
        pos = pos + vel * step;
        path.lineTo(_p(pos).dx, _p(pos).dy);
        if (pos.dy > 1.05) break;
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFE23B2E).withValues(alpha: 0.92)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ShotPainter old) => true;
}
