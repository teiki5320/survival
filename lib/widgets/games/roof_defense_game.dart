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
  const RoofDefenseGame({super.key, required this.onExit});
  final VoidCallback onExit;

  @override
  State<RoofDefenseGame> createState() => _RoofDefenseGameState();
}

enum _Phase { menu, atelier, playing, chest, perk, gameover }

enum _Mode { campaign, endless }

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
  double slowT = 0; // gel : ralenti restant
  bool attacking = false;
  double attackT = 0;
  double lastAtkX = 0;
  bool throwing = false;
  double throwT = 0;
  bool threwThisCycle = false;
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
}

class _EnemyShot {
  _EnemyShot(this.pos, this.vel);
  Offset pos;
  Offset vel;
}

class _Impact {
  _Impact(this.pos,
      {this.launch = false, this.crit = false, this.blast = false});
  final Offset pos;
  final bool launch;
  final bool crit;
  final bool blast;
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

  static const double _imgA = 1376 / 768;
  static const double _wagonClipFrac = 0.22;
  static const double _trainEdgeX = 0.30;

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
  static const double _bruteStep = 0.18;
  static const double _bruteAtkDur = 0.8;
  static const int _bruteHp = 4;
  static const double _throwRange = 0.55;
  static const double _throwPeriod = 1.3;
  static const int _campaignWaves = 5;

  // --- Améliorations d'atelier (clé -> (libellé, desc, coûts par niveau)) ---
  static const Map<String, (String, String, List<int>)> _shopDefs = {
    'dmg': ('Cailloux plus durs', 'Dégâts de base +1', [40, 80, 140, 220]),
    'hearts': ('Blindage du train', 'Cœur de départ +1', [50, 100, 170, 260]),
    'range': ('Meilleure fronde', 'Portée/vitesse +8%', [35, 70, 120]),
    'stones': ('Double charge', 'Démarre avec +1 pierre', [120, 260]),
    'choices': ('Plus de choix', '4 cartes de renfort', [150]),
  };

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

  // frénésie / combos
  double _frenzy = 0;
  bool _inFrenzy = false;
  double _frenzyT = 0;
  double _autoFireT = 0;
  int _combo = 0;
  int _streak = 0;
  double _streakT = 0;

  // coffre
  int _chestScrap = 0;
  String _chestExtra = ''; // '', 'heart', 'perk'
  bool _chestOpened = false;

  // juice
  double _shake = 0;
  double _hitStop = 0;
  double _slowmo = 0;

  // placement
  double _muzX = 0.30, _muzY = 0.55, _groundY = 0.80;
  Offset get _muzzle => Offset(_muzX, _muzY);

  // visée
  bool _aiming = false;
  Offset _dragStart = Offset.zero;
  Offset _dragNow = Offset.zero;

  double _S = 1, _ox = 0, _oy = 0;
  Duration _last = Duration.zero;

  bool get _explosiveWeapon => GameState.instance.shootWeaponLevel >= 3;
  double get _zoneSpeed => GameState.instance.inColdZone ? 1.18 : 1.0;
  double get _zoneCount => GameState.instance.inColdZone ? 1.3 : 1.0;

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

  // ---------------------------------------------------------------------------
  // Cycle de run
  // ---------------------------------------------------------------------------
  void _applyMeta() {
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
  }

  void _startRun(_Mode mode) {
    setState(() {
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
      _aiming = false;
      _applyMeta();
      _phase = _Phase.playing;
      _banner = 1.8;
    });
  }

  // Config (nombre, vitesse, intervalle) de la vague courante.
  (int, double, double) _waveConfig() {
    if (_mode == _Mode.campaign) {
      const waves = [
        (4, 0.09, 1.20),
        (6, 0.13, 1.00),
        (8, 0.18, 0.85),
        (11, 0.25, 0.72),
        (15, 0.32, 0.60),
      ];
      return waves[_wave.clamp(0, waves.length - 1)];
    }
    // Survie : montée infinie.
    final i = _wave;
    final count = 4 + i * 2;
    final speed = (0.10 + i * 0.025).clamp(0.10, 0.55);
    final interval = (1.10 - i * 0.05).clamp(0.35, 1.10);
    return (count, speed.toDouble(), interval.toDouble());
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
        _toSpawn = (_waveConfig().$1 * _zoneCount).round();
        _spawnTimer = 0.4;
        _spawnBarrel();
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

    _updateEnemies(dt);
    _updateProjectiles(dt);
    _updateLoot(dt);
    _updateFires(dt);

    // Fin de vague.
    if (_toSpawn == 0 && _enemies.isEmpty && _banner <= 0) {
      _endWave();
    }

    if (_reloadTimer > 0) _reloadTimer -= dt;
    if (_shake > 0) _shake = (_shake - dt).clamp(0.0, 1.0);
    setState(() {});
  }

  void _updateEnemies(double dt) {
    for (final e in _enemies) {
      if (e.dying) {
        e.dieT -= dt;
        continue;
      }
      e.anim += dt;
      if (e.slowT > 0) e.slowT -= dt;
      final spd = e.slowT > 0 ? e.speed * 0.4 : e.speed;
      switch (e.type) {
        case _PillType.basic:
          e.x -= spd * dt;
        case _PillType.brute:
          if (e.attacking) {
            e.attackT += dt;
            if (e.attackT >= _bruteAtkDur) {
              e.attacking = false;
              e.lastAtkX = e.x;
            }
          } else {
            e.x -= spd * dt;
            if (e.lastAtkX - e.x >= _bruteStep) {
              e.attacking = true;
              e.attackT = 0;
            }
          }
        case _PillType.lanceur:
          if (e.x > _trainEdgeX + _throwRange) {
            e.x -= spd * dt;
          } else {
            e.throwing = true;
            e.throwT += dt;
            final phase = e.throwT % _throwPeriod;
            if (phase >= _throwPeriod * 0.55 && !e.threwThisCycle) {
              e.threwThisCycle = true;
              _enemyShots.add(_EnemyShot(
                Offset(e.x - e.height * 0.20, e.feetY - e.height * 0.55),
                const Offset(-1.15, -0.35),
              ));
            }
            if (phase < _throwPeriod * 0.55) e.threwThisCycle = false;
          }
      }
    }
    _enemies.removeWhere((e) {
      if (e.dying) return e.dieT <= 0;
      if (e.x <= _trainEdgeX) {
        _damageTrain();
        return true;
      }
      return false;
    });
  }

  void _updateProjectiles(double dt) {
    final wind = GameState.instance.inColdZone ? -0.22 : 0.0;
    for (final s in _stones) {
      s.vel = s.vel + Offset(wind * dt, _g * dt);
      s.pos = s.pos + s.vel * dt;
    }
    _stones.removeWhere((s) =>
        s.pos.dy > 1.15 || s.pos.dx > _imgA + 0.2 || s.pos.dx < -0.2);

    for (final es in _enemyShots) {
      es.vel = es.vel + Offset(0, _g * 0.5 * dt);
      es.pos = es.pos + es.vel * dt;
    }
    _enemyShots.removeWhere((es) {
      if (es.pos.dx <= _trainEdgeX) {
        _damageTrain();
        _shake = 0.2;
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
      final headBot = e.feetY - e.height * 0.78;
      final head = s.pos.dy <= headBot;
      e.hp -= s.dmg * (head ? 2 : 1);
      e.x += 0.015;
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

  void _damageTrain() {
    _trainHp--;
    _hpLost++;
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
    _kills++;
    _combo++;
    _streak++;
    _streakT = 1.2;
    final gain = 10 * (head ? 2 : 1) * (1 + _combo ~/ 5);
    _score += gain;
    _shake = math.max(_shake, head ? 0.22 : 0.16);
    _hitStop = 0.05;
    _floats.add(_FloatText(
        Offset(e.x, e.feetY - e.height * 0.6), '+$gain',
        head ? const Color(0xFFFFD24A) : Colors.white));
    // Callouts de série.
    const calls = {3: 'Double !', 5: 'Triple !', 8: 'Carnage !', 12: 'Massacre !'};
    if (calls.containsKey(_streak)) {
      _floats.add(_FloatText(
          Offset(_imgA * 0.5, 0.32), calls[_streak]!, const Color(0xFFFF8A3A),
          big: true));
    }
    // Frénésie.
    if (!_inFrenzy) {
      _frenzy = (_frenzy + (head ? 0.14 : 0.09)).clamp(0.0, 1.0);
      if (_frenzy >= 1.0) {
        _inFrenzy = true;
        _frenzyT = 5.0;
        _frenzy = 0;
        _slowmo = 0.5;
        _floats.add(_FloatText(Offset(_imgA * 0.5, 0.28), 'FRÉNÉSIE !',
            const Color(0xFFFFD24A),
            big: true));
      }
    }
    // Butin.
    final v = e.type == _PillType.brute
        ? 5
        : (e.type == _PillType.lanceur ? 2 : 1);
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
    final span = _imgA - _trainEdgeX - 0.9;
    final x = _trainEdgeX + 0.5 + _rng.nextDouble() * (span > 0 ? span : 0.3);
    _barrel = _Barrel(x.clamp(0.5, _imgA - 0.2), _groundY);
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

  _PillType _pickType() {
    final r = _rng.nextDouble();
    final w = _wave;
    if (w >= 2) {
      if (r < 0.18) return _PillType.brute;
      if (r < 0.40) return _PillType.lanceur;
    } else if (w >= 1) {
      if (r < 0.22) return _PillType.lanceur;
    }
    return _PillType.basic;
  }

  // ---------------------------------------------------------------------------
  // Tir
  // ---------------------------------------------------------------------------
  Offset _launchVel() {
    final pullPx = _dragStart - _dragNow;
    final pull = Offset(pullPx.dx / _S, pullPx.dy / _S);
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
        pierce: _pierce + (reinforced ? 2 : 0),
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
    final v = _launchVel();
    if (v.distance < 0.25) return;
    _spawnStones(v);
    _reloadTimer = _reload;
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
    // Coffre de fin de vague (récompense aléatoire).
    _chestOpened = false;
    final waveBonus = (_wave + 1) * 2;
    final roll = _rng.nextDouble();
    _chestExtra = '';
    if (roll < 0.18) {
      _chestExtra = 'heart';
      _chestScrap = waveBonus;
    } else if (roll < 0.36) {
      _chestExtra = 'perk';
      _chestScrap = waveBonus;
    } else {
      _chestScrap = waveBonus + 5 + _rng.nextInt(15); // ferraille variable
    }
    setState(() => _phase = _Phase.chest);
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
        _maxHp += 2;
        _trainHp += 2;
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
        _powerMult *= 1.12;
    }
    setState(() {
      _phase = _Phase.playing;
      _banner = 1.8;
    });
  }

  // Quitter une partie en cours : on encaisse la ferraille gagnée puis menu.
  void _quitToMenu() {
    final gs = GameState.instance;
    if (_runScrap > 0) {
      gs.scrap += _runScrap;
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
    _shownScrap = _runScrap;
    gs.scrap += _runScrap;
    _runScrap = 0;
    if (won) {
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
          final scale = math.min(w / _imgA, h);
          _S = scale;
          final dispW = _imgA * scale, dispH = scale;
          _ox = (w - dispW) / 2;
          _oy = (h - dispH) / 2;
          Offset u2p(Offset u) => Offset(_ox + u.dx * _S, _oy + u.dy * _S);
          final canAim = _phase == _Phase.playing && !_adjust && _banner <= 0;
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
                    _fireShot();
                    setState(() => _aiming = false);
                  }
                : null,
            child: Transform.translate(
              offset: shakeOffset,
              child: Stack(
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
                  const Positioned.fill(
                    child: Image(
                      image: AssetImage('assets/background/gare_shoot.png'),
                      fit: BoxFit.contain,
                    ),
                  ),

                  // Flaques de feu (sous les pillards).
                  for (final p in _fires) _buildFire(p),
                  if (_barrel != null) _buildBarrel(_barrel!),
                  for (final e in _enemies) _buildEnemy(e),

                  // Occlusion wagon.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ClipRect(
                        clipper: _RectClip(Rect.fromLTWH(
                            _ox, _oy, _wagonClipFrac * dispW, dispH)),
                        child: const Image(
                          image:
                              AssetImage('assets/background/gare_shoot.png'),
                          fit: BoxFit.contain,
                        ),
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

                  // Textes flottants.
                  for (final f in _floats) _buildFloat(f),

                  if (_adjust) ..._adjustHandles(u2p),
                  if (_phase == _Phase.playing) _hudBar(),
                  if (_phase == _Phase.playing && _banner > 0) _bannerWidget(),
                  if (_adjust) _coordHud(),

                  if (_phase == _Phase.menu) _menu(),
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
  Widget _buildEnemy(_Enemy e) {
    final boxSize = e.height / _pillContentH * _S;
    final left = _ox + e.x * _S - boxSize / 2;
    final top = _oy + e.feetY * _S - _pillFeet * boxSize;
    String asset;
    double opacity = 1.0;
    double rot = 0;
    bool mirror = true;
    if (e.dying) {
      if (e.type == _PillType.basic) {
        final df =
            ((_dieDur - e.dieT) / _dieAnim * 49).floor().clamp(0, 48) + 1;
        asset = 'assets/characters/pillard1_die_$df.png';
        mirror = false;
        if (e.dieT < 0.3) opacity = (e.dieT / 0.3).clamp(0.0, 1.0);
      } else {
        asset = _liveAsset(e);
        final d = (1 - e.dieT / _dieDur).clamp(0.0, 1.0);
        rot = -d * 1.1;
        opacity = (1 - d).clamp(0.0, 1.0);
      }
    } else {
      asset = _liveAsset(e);
    }
    Widget img = Image.asset(asset, fit: BoxFit.contain, gaplessPlayback: true);
    if (e.slowT > 0 && !e.dying) {
      img = ColorFiltered(
        colorFilter: const ColorFilter.mode(Color(0x6688D8FF), BlendMode.srcATop),
        child: img,
      );
    }
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _hud(_mode == _Mode.campaign
                        ? 'Vague ${_wave + 1}/$_campaignWaves'
                        : 'Vague ${_wave + 1}'),
                    const SizedBox(width: 10),
                    _hearts(),
                    const Spacer(),
                    _hud('$_score pts'),
                    const SizedBox(width: 8),
                    _hud('🔩$_runScrap'),
                    const SizedBox(width: 8),
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
                      onPressed: _quitToMenu,
                      child: const Icon(Icons.close),
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
          onPanUpdate: (d) => setState(
              () => _groundY = (_groundY + d.delta.dy / _S).clamp(0.4, 1.0)),
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
          _menuBtn('Survie', const Color(0xFF8A3B2E),
              () => _startRun(_Mode.endless)),
          const SizedBox(height: 12),
          _menuBtn('Atelier 🔧', const Color(0xFF3A4656),
              () => setState(() => _phase = _Phase.atelier)),
          const SizedBox(height: 20),
          TextButton(
              onPressed: widget.onExit,
              child: const Text('Quitter',
                  style: TextStyle(color: Colors.white54))),
        ],
      ));

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
                ? () => setState(() {
                      gs.scrap -= cost;
                      gs.shootUpgrades[key] = lvl + 1;
                      gs.save();
                    })
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
              children: [
                if (_won && _mode == _Mode.campaign)
                  _menuBtn('Continuer en survie', const Color(0xFF8A3B2E), () {
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
      final rr = (s.big ? 0.020 : 0.013) * scale;
      if (s.big) {
        canvas.drawCircle(p, rr * 1.6, Paint()..color = const Color(0x55FFD24A));
      }
      canvas.drawCircle(
          p, rr, s.big ? (Paint()..color = const Color(0xFFE8B96B)) : stonePaint);
      canvas.drawCircle(p, rr, stoneEdge);
    }

    final enemyPaint = Paint()..color = const Color(0xFF8A4A3A);
    for (final es in enemyShots) {
      canvas.drawCircle(_p(es.pos), 0.014 * scale, enemyPaint);
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
      final r = (0.012 + 0.05 * t) * scale;
      final ringColor =
          im.crit ? const Color(0xFFFFD24A) : const Color(0xFFFFE2B0);
      canvas.drawCircle(
        c,
        r * (im.crit ? 1.5 : 1.0),
        Paint()
          ..color = ringColor.withValues(alpha: 0.8 * a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = im.crit ? 3.5 : 2.5,
      );
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
