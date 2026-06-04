import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../models/game_state.dart';

/// Mini-jeu de défense de gare au lance-pierre. Des **pillards** arrivent de la
/// droite le long du quai et avancent vers le train ; ils **disparaissent
/// derrière le wagon** à gauche. On **maintient et glisse vers l'arrière** pour
/// bander la fronde (arc de visée), on **relâche** : le caillou part **de la
/// lucarne/porte arrière du wagon** en cloche (gravité), avec un petit effet de
/// départ. Survivre aux vagues ; à chaque vague un **renfort** au choix.
///
/// Tout est en "unités décor" (origine = coin haut-gauche du décor affiché,
/// 1 unité = hauteur affichée du décor `_S`) -> le gameplay reste collé à la
/// gare quel que soit l'écran (décor en BoxFit.contain).
class RoofDefenseGame extends StatefulWidget {
  const RoofDefenseGame({super.key, required this.onExit});
  final VoidCallback onExit;

  @override
  State<RoofDefenseGame> createState() => _RoofDefenseGameState();
}

enum _Status { playing, won, lost }

enum _PillType { basic, brute, lanceur }

class _Enemy {
  _Enemy({
    required this.type,
    required this.x,
    required this.feetY,
    required this.speed,
    required this.height,
    required this.anim,
    this.hp = 1,
  }) : hpMax = hp;
  final _PillType type;
  double x;
  double feetY;
  double speed;
  double height;
  double anim;
  int hp;
  final int hpMax;
  bool dying = false;
  double dieT = 0;
  // Brute : coup de hache périodique (tous les ~_bruteStep).
  bool attacking = false;
  double attackT = 0;
  double lastAtkX = 0;
  // Lanceur : s'arrête à distance et lance.
  bool throwing = false;
  double throwT = 0;
  bool threwThisCycle = false;
}

/// Caillou lancé par un Lanceur vers le train (vole vers la gauche).
class _EnemyShot {
  _EnemyShot(this.pos, this.vel);
  Offset pos;
  Offset vel;
}

class _Stone {
  _Stone(this.pos, this.vel);
  Offset pos;
  Offset vel;
}

class _Impact {
  _Impact(this.pos, {this.launch = false});
  final Offset pos;
  final bool launch; // true = poussière de départ (lucarne)
  double t = 0;
}

class _RoofDefenseGameState extends State<RoofDefenseGame>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _rng = math.Random();

  static const double _imgA = 1376 / 768; // ratio du décor gare_shoot
  static const double _wagonClipFrac = 0.22; // largeur (ifx) du wagon à gauche
  static const double _trainEdgeX = 0.30; // (sx) atteint le wagon -> dégâts

  static const double _g = 1.9;
  static const double _power = 5.6;
  static const double _maxSpeed = 3.0;
  static const double _stoneR = 0.013;
  static const double _reload = 0.26;
  static const double _impactDur = 0.32;
  static const double _dieDur = 1.2;
  static const double _dieAnim = 0.9;
  static const double _pillFeet = 0.865;
  static const double _pillContentH = 0.73;
  // Comportements spéciaux.
  static const double _bruteStep = 0.18; // ~2 m entre deux coups de hache
  static const double _bruteAtkDur = 0.8; // durée d'un coup de hache
  static const int _bruteHp = 4; // 4 cailloux pour tuer la brute
  static const double _throwRange = 0.55; // ~3 m : distance d'arrêt du lanceur
  static const double _throwPeriod = 1.3; // cadence de jet du lanceur

  // Vitesses RÉDUITES (les pillards étaient trop rapides) mais courbe montante.
  static const List<(int, double, double)> _waves = [
    (4, 0.09, 1.20),
    (6, 0.13, 1.00),
    (8, 0.18, 0.85),
    (11, 0.25, 0.72),
    (15, 0.32, 0.60),
  ];

  final List<_Enemy> _enemies = [];
  final List<_Stone> _stones = [];
  final List<_Impact> _impacts = [];
  final List<_EnemyShot> _enemyShots = []; // cailloux lancés par les lanceurs

  int _wave = 0;
  int _toSpawn = 0;
  double _spawnTimer = 0;
  double _banner = 1.8;
  double _reloadTimer = 0;

  int _trainHp = 5;
  int _maxHp = 5;
  int _kills = 0;
  _Status _status = _Status.playing;

  // Point de tir (lucarne / porte arrière du wagon) + ligne de sol des
  // pillards. Réglables en mode crayon (-> coords pour rebaker).
  double _muzX = 0.30, _muzY = 0.55;
  double _groundY = 0.80;
  bool _adjust = false;
  Offset get _muzzle => Offset(_muzX, _muzY);

  int _stonesPerShot = 1;
  double _reloadMult = 1.0;
  double _powerMult = 1.0;
  bool _awaitingChoice = false;

  double _shake = 0;
  int _combo = 0;

  bool _aiming = false;
  Offset _dragStart = Offset.zero;
  Offset _dragNow = Offset.zero;

  double _S = 1, _ox = 0, _oy = 0;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    double dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0) return;
    if (dt > 0.05) dt = 0.05;
    if (_status != _Status.playing) return;
    if (_adjust || _awaitingChoice) return;

    for (final im in _impacts) {
      im.t += dt / _impactDur;
    }
    _impacts.removeWhere((im) => im.t >= 1);

    if (_banner > 0) {
      _banner -= dt;
      if (_banner <= 0) {
        _toSpawn = _waves[_wave].$1;
        _spawnTimer = 0.4;
      }
      setState(() {});
      return;
    }

    if (_toSpawn > 0) {
      _spawnTimer -= dt;
      if (_spawnTimer <= 0) {
        _spawnEnemy(_waves[_wave].$2);
        _toSpawn--;
        _spawnTimer = _waves[_wave].$3;
      }
    }

    for (final e in _enemies) {
      if (e.dying) {
        e.dieT -= dt;
        continue;
      }
      e.anim += dt;
      switch (e.type) {
        case _PillType.basic:
          e.x -= e.speed * dt;
        case _PillType.brute:
          // Marche lente ; tous les ~_bruteStep, coup de hache sur place.
          if (e.attacking) {
            e.attackT += dt;
            if (e.attackT >= _bruteAtkDur) {
              e.attacking = false;
              e.lastAtkX = e.x;
            }
          } else {
            e.x -= e.speed * dt;
            if (e.lastAtkX - e.x >= _bruteStep) {
              e.attacking = true;
              e.attackT = 0;
            }
          }
        case _PillType.lanceur:
          // Avance jusqu'à ~3 m du train, puis lance des cailloux en boucle.
          if (e.x > _trainEdgeX + _throwRange) {
            e.x -= e.speed * dt;
          } else {
            e.throwing = true;
            e.throwT += dt;
            final phase = e.throwT % _throwPeriod;
            if (phase >= _throwPeriod * 0.55 && !e.threwThisCycle) {
              e.threwThisCycle = true;
              _enemyShots.add(_EnemyShot(
                Offset(e.x - e.height * 0.20, e.feetY - e.height * 0.55),
                const Offset(-1.15, -0.35), // vers le train, léger arc
              ));
            }
            if (phase < _throwPeriod * 0.55) e.threwThisCycle = false;
          }
      }
    }
    _enemies.removeWhere((e) {
      if (e.dying) return e.dieT <= 0;
      if (e.x <= _trainEdgeX) {
        _trainHp--;
        _combo = 0;
        if (_trainHp <= 0) _status = _Status.lost;
        return true;
      }
      return false;
    });

    final wind = GameState.instance.inColdZone ? -0.22 : 0.0;
    for (final s in _stones) {
      s.vel = s.vel + Offset(wind * dt, _g * dt);
      s.pos = s.pos + s.vel * dt;
    }
    _stones.removeWhere((s) =>
        s.pos.dy > 1.15 || s.pos.dx > _imgA + 0.2 || s.pos.dx < -0.2);

    // Cailloux lancés par les lanceurs : volent vers le train, l'endommagent.
    for (final es in _enemyShots) {
      es.vel = es.vel + Offset(0, _g * 0.5 * dt);
      es.pos = es.pos + es.vel * dt;
    }
    _enemyShots.removeWhere((es) {
      if (es.pos.dx <= _trainEdgeX) {
        _trainHp--;
        _combo = 0;
        _shake = 0.2;
        if (_trainHp <= 0) _status = _Status.lost;
        return true;
      }
      return es.pos.dy > 1.15 || es.pos.dx < -0.2;
    });

    // Collisions caillou <-> pillard : hitbox CORPS (boîte) -> plus de cailloux
    // qui traversent la tête.
    for (final s in _stones) {
      for (final e in _enemies) {
        if (e.dying) continue;
        final hw = e.height * 0.24; // demi-largeur du corps
        final top = e.feetY - e.height * 0.95;
        final bot = e.feetY - e.height * 0.05;
        if (s.pos.dx >= e.x - hw - _stoneR &&
            s.pos.dx <= e.x + hw + _stoneR &&
            s.pos.dy >= top &&
            s.pos.dy <= bot) {
          e.hp--;
          _impacts.add(_Impact(s.pos));
          s.pos = const Offset(-99, -99);
          if (e.hp <= 0) {
            e.dying = true;
            e.dieT = _dieDur;
            _kills++;
            _combo++;
            _shake = 0.16;
          }
          break;
        }
      }
    }
    _stones.removeWhere((s) => s.pos.dx < -90);

    if (_toSpawn == 0 && _enemies.isEmpty && _banner <= 0) {
      if (_wave >= _waves.length - 1) {
        _status = _Status.won;
      } else {
        _wave++;
        _awaitingChoice = true;
      }
    }

    if (_reloadTimer > 0) _reloadTimer -= dt;
    if (_shake > 0) _shake = (_shake - dt).clamp(0.0, 1.0);
    setState(() {});
  }

  void _spawnEnemy(double baseSpeed) {
    final type = _pickType();
    final feetY = _groundY + (_rng.nextDouble() - 0.5) * 0.02;
    final anim = _rng.nextDouble() * 2;
    const x0 = _imgA + 0.14;
    switch (type) {
      case _PillType.brute:
        _enemies.add(_Enemy(
          type: type, x: x0, feetY: feetY,
          speed: baseSpeed * 0.45, height: 0.30, anim: anim, hp: _bruteHp,
        )..lastAtkX = x0);
      case _PillType.lanceur:
        _enemies.add(_Enemy(
          type: type, x: x0, feetY: feetY,
          speed: baseSpeed * 0.9, height: 0.22, anim: anim,
        ));
      case _PillType.basic:
        _enemies.add(_Enemy(
          type: type, x: x0, feetY: feetY,
          speed: baseSpeed * (0.85 + _rng.nextDouble() * 0.3),
          height: 0.21, anim: anim,
        ));
    }
  }

  // Apparition progressive : que des basics au début, brutes + lanceurs à
  // partir de la vague 3, de plus en plus souvent.
  _PillType _pickType() {
    final r = _rng.nextDouble();
    if (_wave >= 2) {
      if (r < 0.18) return _PillType.brute;
      if (r < 0.40) return _PillType.lanceur;
    } else if (_wave >= 1) {
      if (r < 0.22) return _PillType.lanceur;
    }
    return _PillType.basic;
  }

  Offset _launchVel() {
    final pullPx = _dragStart - _dragNow;
    final pull = Offset(pullPx.dx / _S, pullPx.dy / _S);
    var v = pull * (_power * _powerMult);
    final maxs = _maxSpeed * _powerMult;
    final sp = v.distance;
    if (sp > maxs) v = v * (maxs / sp);
    return v;
  }

  void _fire() {
    if (_reloadTimer > 0) return;
    final v = _launchVel();
    if (v.distance < 0.25) return;
    final n = _stonesPerShot;
    for (int i = 0; i < n; i++) {
      final a = n == 1 ? 0.0 : (i - (n - 1) / 2) * 0.08;
      _stones.add(_Stone(_muzzle, _rot(v, a)));
    }
    _impacts.add(_Impact(_muzzle, launch: true)); // effet de départ
    _reloadTimer = _reload * _reloadMult;
  }

  Offset _rot(Offset v, double a) {
    final c = math.cos(a), s = math.sin(a);
    return Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
  }

  void _pickPerk(String perk) {
    setState(() {
      switch (perk) {
        case 'stone':
          _stonesPerShot++;
        case 'hearts':
          _maxHp += 2;
          _trainHp += 2;
        case 'speed':
          _powerMult *= 1.12;
      }
      _awaitingChoice = false;
      _banner = 1.8;
    });
  }

  void _restart() {
    setState(() {
      _enemies.clear();
      _stones.clear();
      _impacts.clear();
      _enemyShots.clear();
      _wave = 0;
      _toSpawn = 0;
      _spawnTimer = 0;
      _banner = 1.8;
      _trainHp = 5;
      _maxHp = 5;
      _kills = 0;
      _reloadTimer = 0;
      _status = _Status.playing;
      _aiming = false;
      _stonesPerShot = 1;
      _reloadMult = 1.0;
      _powerMult = 1.0;
      _awaitingChoice = false;
      _shake = 0;
      _combo = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B2230),
      body: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          final scale = math.min(w / _imgA, h);
          _S = scale;
          final dispW = _imgA * scale, dispH = scale;
          _ox = (w - dispW) / 2;
          _oy = (h - dispH) / 2;
          Offset u2p(Offset u) => Offset(_ox + u.dx * _S, _oy + u.dy * _S);
          final playing = _status == _Status.playing;
          final canAim = playing && !_adjust && !_awaitingChoice;
          final shakeOffset = _shake > 0
              ? Offset(_rng.nextDouble() - 0.5, _rng.nextDouble() - 0.5) *
                  (_shake / 0.16) *
                  14
              : Offset.zero;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: canAim
                ? (d) {
                    _dragStart = d.localPosition;
                    _dragNow = d.localPosition;
                    setState(() => _aiming = true);
                  }
                : null,
            onPanUpdate: canAim
                ? (d) => setState(() => _dragNow = d.localPosition)
                : null,
            onPanEnd: canAim
                ? (_) {
                    _fire();
                    setState(() => _aiming = false);
                  }
                : null,
            child: Transform.translate(
              offset: shakeOffset,
              child: Stack(
                children: [
                  // Fond : dégradé ciel/sol pour les bandes hors décor.
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
                  // Décor de gare entier.
                  const Positioned.fill(
                    child: Image(
                      image: AssetImage('assets/background/gare_shoot.png'),
                      fit: BoxFit.contain,
                    ),
                  ),

                  // Pillards.
                  for (final e in _enemies) _buildEnemy(e),

                  // Re-dessin du WAGON (bande gauche du décor) PAR-DESSUS les
                  // pillards -> ils disparaissent derrière le wagon.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ClipRect(
                        clipper: _RectClip(
                            Rect.fromLTWH(_ox, _oy, _wagonClipFrac * dispW, dispH)),
                        child: const Image(
                          image:
                              AssetImage('assets/background/gare_shoot.png'),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),

                  // Cailloux + impacts + visée.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _ShotPainter(
                          stones: _stones,
                          impacts: _impacts,
                          enemyShots: _enemyShots,
                          anchor: u2p(_muzzle),
                          aiming: _aiming,
                          launchVel: _aiming ? _launchVel() : null,
                          g: _g,
                          ox: _ox,
                          oy: _oy,
                          scale: _S,
                        ),
                      ),
                    ),
                  ),

                  // Mode réglage : poignées lucarne + ligne de sol.
                  if (_adjust) ..._adjustHandles(u2p),

                  _hudBar(),

                  if (playing && _banner > 0)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 26, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'Vague ${_wave + 1}',
                          style: const TextStyle(
                            color: Color(0xFFFFD9A0),
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),

                  if (playing && _wave == 0 && _kills == 0 && _banner <= 0)
                    const Positioned(
                      bottom: 24,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Center(
                          child: Text(
                            'Maintiens et glisse vers l’arrière, relâche pour tirer',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ),
                      ),
                    ),

                  if (_adjust) _coordHud(),
                  if (_awaitingChoice) _choiceOverlay(),
                  if (!playing) _endOverlay(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Asset "vivant" (marche / coup de hache / jet) selon le type et l'état.
  String _liveAsset(_Enemy e) {
    final wf = (e.anim * 16).floor() % 49 + 1;
    switch (e.type) {
      case _PillType.basic:
        return 'assets/characters/pillard1_walk_$wf.png';
      case _PillType.brute:
        if (e.attacking) {
          final af = (e.attackT / _bruteAtkDur * 49).floor().clamp(0, 48) + 1;
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

  Widget _buildEnemy(_Enemy e) {
    final boxSize = e.height / _pillContentH * _S;
    final left = _ox + e.x * _S - boxSize / 2;
    final top = _oy + e.feetY * _S - _pillFeet * boxSize;

    String asset;
    double opacity = 1.0;
    double rot = 0;
    bool mirror = true; // les sprites pointent à droite -> miroir vers gauche

    if (e.dying) {
      if (e.type == _PillType.basic) {
        // Vraie anim de chute (frames déjà retournées -> pas de miroir).
        final df = ((_dieDur - e.dieT) / _dieAnim * 49).floor().clamp(0, 48) + 1;
        asset = 'assets/characters/pillard1_die_$df.png';
        mirror = false;
        if (e.dieT < 0.3) opacity = (e.dieT / 0.3).clamp(0.0, 1.0);
      } else {
        // Brute/lanceur : pas de sheet de mort -> on fige + bascule + fondu.
        asset = _liveAsset(e);
        final d = (1 - e.dieT / _dieDur).clamp(0.0, 1.0);
        rot = -d * 1.1;
        opacity = (1 - d).clamp(0.0, 1.0);
      }
    } else {
      asset = _liveAsset(e);
    }

    Widget img =
        Image.asset(asset, fit: BoxFit.contain, gaplessPlayback: true);
    if (mirror) {
      img = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
        child: img,
      );
    }
    if (rot != 0) {
      img = Transform.rotate(
          angle: rot, alignment: Alignment.bottomCenter, child: img);
    }
    if (opacity < 1.0) img = Opacity(opacity: opacity, child: img);

    // Barre de vie de la brute (pips) tant qu'elle est blessée.
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

  // Poignées de réglage : la lucarne (cercle déplaçable) + la ligne de sol.
  List<Widget> _adjustHandles(Offset Function(Offset) u2p) {
    final muz = u2p(_muzzle);
    return [
      // Ligne de sol (déplaçable verticalement).
      Positioned(
        left: 0,
        right: 0,
        top: _oy + _groundY * _S - 16,
        height: 32,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) => setState(() {
            _groundY = (_groundY + d.delta.dy / _S).clamp(0.4, 1.0);
          }),
          child: Center(
            child: Container(height: 2, color: const Color(0xCC66E0FF)),
          ),
        ),
      ),
      // Lucarne (déplaçable).
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('RÉGLAGE — bouge la lucarne (rond) + la ligne de sol',
                    style: TextStyle(
                        color: Color(0xFFE8B96B),
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
                Text(
                  'muzX ${_muzX.toStringAsFixed(3)}   muzY ${_muzY.toStringAsFixed(3)}   solY ${_groundY.toStringAsFixed(3)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _choiceOverlay() => Positioned.fill(
        child: Container(
          color: Colors.black.withValues(alpha: 0.66),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Renfort — choisis-en un',
                    style: TextStyle(
                        color: Color(0xFFFFD9A0),
                        fontSize: 24,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 22),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _choiceCard(
                      emoji: '🪨',
                      title: '+1 pierre',
                      desc: 'Un caillou de plus\npar tir',
                      onTap: () => _pickPerk('stone'),
                    ),
                    const SizedBox(width: 14),
                    _choiceCard(
                      emoji: '❤️',
                      title: '+2 cœurs',
                      desc: 'Train plus résistant',
                      onTap: () => _pickPerk('hearts'),
                    ),
                    const SizedBox(width: 14),
                    _choiceCard(
                      emoji: '⚡',
                      title: 'Tir plus vif',
                      desc: 'Caillou plus rapide\n(portée)',
                      onTap: () => _pickPerk('speed'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

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
              Text(emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(height: 8),
              Text(title,
                  style: const TextStyle(
                      color: Color(0xFFFFD9A0),
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(desc,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      );

  Widget _hudBar() => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                _hud('Vague ${_wave + 1}/${_waves.length}'),
                const SizedBox(width: 12),
                _hearts(),
                const Spacer(),
                _hud(_combo > 1 ? '💥 $_kills   🔥x$_combo' : '💥 $_kills'),
                const SizedBox(width: 12),
                FloatingActionButton.small(
                  heroTag: 'shoot_adjust',
                  tooltip: 'Régler la lucarne / le sol',
                  backgroundColor:
                      _adjust ? const Color(0xFFE8B96B) : Colors.black54,
                  foregroundColor:
                      _adjust ? const Color(0xFF2A2018) : Colors.white,
                  onPressed: () => setState(() => _adjust = !_adjust),
                  child: Icon(_adjust ? Icons.check : Icons.edit),
                ),
                const SizedBox(width: 12),
                FloatingActionButton.small(
                  heroTag: 'shoot_quit',
                  backgroundColor: Colors.black54,
                  onPressed: widget.onExit,
                  child: const Icon(Icons.close),
                ),
              ],
            ),
          ),
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
            for (int i = 0; i < _maxHp; i++)
              Icon(
                i < _trainHp ? Icons.favorite : Icons.favorite_border,
                color: const Color(0xFFE2614A),
                size: 18,
              ),
          ],
        ),
      );

  Widget _endOverlay() {
    final won = _status == _Status.won;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.62),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                won ? 'Train défendu !' : 'Le train est tombé…',
                style: TextStyle(
                  color:
                      won ? const Color(0xFFB6E3A8) : const Color(0xFFE2614A),
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text('Pillards repoussés : $_kills',
                  style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 26),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: _restart,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Rejouer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE8B96B),
                      foregroundColor: const Color(0xFF2A2018),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: widget.onExit,
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text('Quitter'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RectClip extends CustomClipper<Rect> {
  _RectClip(this.rect);
  final Rect rect;
  @override
  Rect getClip(Size size) => rect;
  @override
  bool shouldReclip(covariant _RectClip old) => old.rect != rect;
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
      canvas.drawCircle(p, 0.013 * scale, stonePaint);
      canvas.drawCircle(p, 0.013 * scale, stoneEdge);
    }

    // Cailloux lancés par les lanceurs (vers le train) — teinte rougeâtre.
    final enemyPaint = Paint()..color = const Color(0xFF8A4A3A);
    for (final es in enemyShots) {
      canvas.drawCircle(_p(es.pos), 0.014 * scale, enemyPaint);
      canvas.drawCircle(
        _p(es.pos),
        0.014 * scale,
        Paint()
          ..color = const Color(0xFF4A241C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    for (final im in impacts) {
      final c = _p(im.pos);
      final t = im.t.clamp(0.0, 1.0);
      final a = (1 - t);
      if (im.launch) {
        // Poussière de départ : petit nuage qui se dissipe vers le haut-droite.
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
      final r = (0.012 + 0.05 * t) * scale;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = const Color(0xFFFFE2B0).withValues(alpha: 0.7 * a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      final speck =
          Paint()..color = const Color(0xFFBFA98C).withValues(alpha: a);
      for (int i = 0; i < 6; i++) {
        final ang = i * math.pi / 3 + t;
        final d = r * 1.1;
        canvas.drawCircle(
            c + Offset(math.cos(ang) * d, math.sin(ang) * d),
            2.0 * (1 - t),
            speck);
      }
    }

    if (aiming && launchVel != null) {
      final dot = Paint()..color = Colors.white.withValues(alpha: 0.85);
      Offset pos = Offset((anchor.dx - ox) / scale, (anchor.dy - oy) / scale);
      Offset vel = launchVel!;
      const double step = 0.045;
      for (int i = 0; i < 30; i++) {
        vel = vel + Offset(0, g * step);
        pos = pos + vel * step;
        if (pos.dy > 1.2) break;
        if (i.isEven) canvas.drawCircle(_p(pos), 2.2, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ShotPainter old) => true;
}
