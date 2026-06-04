import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Mini-jeu de défense de gare au **lance-pierre** (poste de tir = mirador sur
/// le wagon, à gauche). Des **pillards** arrivent de la droite le long du quai
/// et avancent vers le train. On **maintient le doigt** pour bander la fronde :
/// un **arc de visée** apparaît, on **relâche** pour lober un caillou (gravité).
/// Il faut **survivre à plusieurs vagues** ; chaque pillard qui atteint le
/// wagon entame l'intégrité du train (cœurs).
///
/// Coordonnées en **unités de hauteur** (1 unité = hauteur de la zone de jeu)
/// pour une physique d'arc isotrope. Décor `gare_shoot`, mirador `mirador`,
/// pillards `pillard1_walk_*`. Projectiles, impacts et mort gérés ici (mort
/// procédurale en attendant de vraies frames de chute).
class RoofDefenseGame extends StatefulWidget {
  const RoofDefenseGame({super.key, required this.onExit});
  final VoidCallback onExit;

  @override
  State<RoofDefenseGame> createState() => _RoofDefenseGameState();
}

enum _Status { playing, won, lost }

class _Enemy {
  _Enemy({
    required this.x,
    required this.feetY,
    required this.speed,
    required this.height,
    required this.anim,
  });
  double x; // unités H (centre)
  double feetY; // ligne des pieds (unités H)
  double speed; // unités/s vers la gauche
  double height; // hauteur du perso (unités H)
  double anim; // accumulateur d'animation (s)
  int frame = 0;
  int hp = 1;
  bool dying = false;
  double dieT = 0; // temps de mort restant (s)
}

class _Stone {
  _Stone(this.pos, this.vel);
  Offset pos; // unités H
  Offset vel; // unités/s
}

class _Impact {
  _Impact(this.pos);
  final Offset pos; // unités H
  double t = 0; // 0..1 (durée _impactDur)
}

class _RoofDefenseGameState extends State<RoofDefenseGame>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _rng = math.Random();

  // --- Géométrie (unités H), calée sur le décor gare_shoot ---
  static const double _miradorX = 0.16; // centre du mirador (sur le wagon)
  static const double _miradorBottomY = 0.47; // base du mirador
  static const double _miradorH = 0.24; // hauteur du mirador
  static const Offset _muzzle = Offset(0.205, 0.33); // d'où part le tir
  static const double _groundY = 0.72; // pieds des pillards (le quai)
  static const double _trainEdgeX = 0.26; // atteint le wagon -> dégâts
  static const double _introDur = 2.0;

  static const double _g = 1.9;
  static const double _power = 5.6;
  static const double _maxSpeed = 3.0;
  static const double _stoneR = 0.013;
  static const double _enemyR = 0.060;
  static const double _reload = 0.28;
  static const double _impactDur = 0.32;
  static const double _dieDur = 0.5;

  // Pillard : pieds à ~0.865 du cadre, contenu ~0.73 de haut (mesuré).
  static const double _pillFeet = 0.865;
  static const double _pillContentH = 0.73;

  static const List<(int, double, double)> _waves = [
    (4, 0.085, 1.15),
    (5, 0.095, 1.00),
    (6, 0.110, 0.90),
    (7, 0.125, 0.80),
    (9, 0.145, 0.70),
  ];

  final List<_Enemy> _enemies = [];
  final List<_Stone> _stones = [];
  final List<_Impact> _impacts = [];

  int _wave = 0;
  int _toSpawn = 0;
  double _spawnTimer = 0;
  double _banner = 1.8;
  double _reloadTimer = 0;

  int _trainHp = 5;
  int _kills = 0;
  _Status _status = _Status.playing;

  double _introT = _introDur;
  bool _introDone = false;

  bool _aiming = false;
  Offset _dragStart = Offset.zero;
  Offset _dragNow = Offset.zero;
  double _viewH = 1;
  double _viewAspect = 1.6;

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

    // Intro : Shen rejoint le mirador.
    if (!_introDone) {
      _introT -= dt;
      if (_introT <= 0) _introDone = true;
      setState(() {});
      return;
    }

    // Impacts (toujours animés).
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

    // Pillards : avancent + animation de marche ; les mourants tombent.
    for (final e in _enemies) {
      if (e.dying) {
        e.dieT -= dt;
        continue;
      }
      e.x -= e.speed * dt;
      e.anim += dt;
      e.frame = (e.anim * 16).floor() % 49;
    }
    _enemies.removeWhere((e) {
      if (e.dying) return e.dieT <= 0;
      if (e.x <= _trainEdgeX) {
        _trainHp--;
        if (_trainHp <= 0) _status = _Status.lost;
        return true;
      }
      return false;
    });

    // Cailloux : balistique.
    for (final s in _stones) {
      s.vel = s.vel + Offset(0, _g * dt);
      s.pos = s.pos + s.vel * dt;
    }
    _stones.removeWhere((s) =>
        s.pos.dy > 1.15 || s.pos.dx > _viewAspect + 0.2 || s.pos.dx < -0.2);

    // Collisions caillou <-> pillard vivant.
    for (final s in _stones) {
      for (final e in _enemies) {
        if (e.dying) continue;
        final cx = e.x;
        final cy = e.feetY - e.height * 0.5;
        final dx = s.pos.dx - cx, dy = s.pos.dy - cy;
        if (dx * dx + dy * dy <= (_enemyR + _stoneR) * (_enemyR + _stoneR)) {
          e.hp--;
          _impacts.add(_Impact(s.pos));
          s.pos = const Offset(-99, -99);
          if (e.hp <= 0) {
            e.dying = true;
            e.dieT = _dieDur;
            _kills++;
          }
          break;
        }
      }
    }
    _stones.removeWhere((s) => s.pos.dx < -90);

    // Vague terminée ?
    if (_toSpawn == 0 && _enemies.isEmpty && _banner <= 0) {
      if (_wave >= _waves.length - 1) {
        _status = _Status.won;
      } else {
        _wave++;
        _banner = 1.8;
      }
    }

    if (_reloadTimer > 0) _reloadTimer -= dt;
    setState(() {});
  }

  void _spawnEnemy(double speed) {
    _enemies.add(_Enemy(
      x: _viewAspect + 0.14,
      feetY: _groundY + (_rng.nextDouble() - 0.5) * 0.03,
      speed: speed * (0.85 + _rng.nextDouble() * 0.3),
      height: 0.22 + _rng.nextDouble() * 0.04,
      anim: _rng.nextDouble() * 2,
    ));
  }

  Offset _launchVel() {
    final pullPx = _dragStart - _dragNow;
    final pull = Offset(pullPx.dx / _viewH, pullPx.dy / _viewH);
    var v = pull * _power;
    final sp = v.distance;
    if (sp > _maxSpeed) v = v * (_maxSpeed / sp);
    return v;
  }

  void _fire() {
    if (_reloadTimer > 0) return;
    final v = _launchVel();
    if (v.distance < 0.25) return;
    _stones.add(_Stone(_muzzle, v));
    _reloadTimer = _reload;
  }

  void _restart() {
    setState(() {
      _enemies.clear();
      _stones.clear();
      _impacts.clear();
      _wave = 0;
      _toSpawn = 0;
      _spawnTimer = 0;
      _banner = 1.8;
      _trainHp = 5;
      _kills = 0;
      _reloadTimer = 0;
      _status = _Status.playing;
      _aiming = false;
      _introT = _introDur;
      _introDone = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B2230),
      body: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          _viewH = h;
          _viewAspect = w / h;
          Offset u2p(Offset u) => Offset(u.dx * h, u.dy * h);
          final playing = _status == _Status.playing;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: playing
                ? (d) {
                    _dragStart = d.localPosition;
                    _dragNow = d.localPosition;
                    setState(() => _aiming = true);
                  }
                : null,
            onPanUpdate: playing
                ? (d) => setState(() => _dragNow = d.localPosition)
                : null,
            onPanEnd: playing
                ? (_) {
                    _fire();
                    setState(() => _aiming = false);
                  }
                : null,
            child: Stack(
              children: [
                // Décor de gare (wagon à gauche, quai à droite).
                Positioned.fill(
                  child: Image.asset(
                    'assets/background/gare_shoot.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.centerLeft,
                  ),
                ),

                // Pillards.
                for (final e in _enemies) _buildEnemy(e, h),

                // Mirador (poste de tir) sur le wagon.
                Positioned(
                  left: _miradorX * h - (_miradorH * 1.798 * h) / 2,
                  top: (_miradorBottomY - _miradorH) * h,
                  width: _miradorH * 1.798 * h,
                  height: _miradorH * h,
                  child: const IgnorePointer(
                    child: Image(
                      image: AssetImage('assets/objects/mirador.png'),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                // Intro : Shen rejoint le mirador puis disparaît dedans.
                if (!_introDone) _introShen(h),

                // Cailloux + impacts + visée.
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _ShotPainter(
                        stones: _stones,
                        impacts: _impacts,
                        anchor: u2p(_muzzle),
                        aiming: _aiming,
                        launchVel: _aiming ? _launchVel() : null,
                        g: _g,
                        hUnit: h,
                      ),
                    ),
                  ),
                ),

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
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ),
                    ),
                  ),

                if (!playing) _endOverlay(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEnemy(_Enemy e, double h) {
    final boxSize = e.height / _pillContentH * h;
    final left = e.x * h - boxSize / 2;
    final top = e.feetY * h - _pillFeet * boxSize;
    Widget img = Image.asset(
      'assets/characters/pillard1_walk_${e.frame + 1}.png',
      fit: BoxFit.contain,
      gaplessPlayback: true,
    );
    if (e.dying) {
      // Mort procédurale (en attendant les frames de chute) : il bascule
      // vers la gauche et s'efface.
      final d = (1 - e.dieT / _dieDur).clamp(0.0, 1.0);
      img = Opacity(
        opacity: (1 - d).clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: -d * 1.25, // bascule au sol
          alignment: Alignment.bottomCenter,
          child: img,
        ),
      );
    }
    return Positioned(
      left: left,
      top: top,
      width: boxSize,
      height: boxSize,
      child: IgnorePointer(child: img),
    );
  }

  Widget _introShen(double h) {
    final p = (1 - _introT / _introDur).clamp(0.0, 1.0);
    final sx = 0.42 + (_miradorX + 0.02 - 0.42) * p;
    final boxH = 0.26 * h;
    final boxW = boxH * 0.55;
    final frame = ((_introDur - _introT) * 18).floor() % 49 + 1;
    final opacity = p < 0.78 ? 1.0 : (1 - (p - 0.78) / 0.22).clamp(0.0, 1.0);
    return Positioned(
      left: sx * h - boxW / 2,
      top: _groundY * h - boxH,
      width: boxW,
      height: boxH,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
            child: Image.asset(
              'assets/characters/walk_right_$frame.png',
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          ),
        ),
      ),
    );
  }

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
                _hud('💥 $_kills'),
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
            for (int i = 0; i < 5; i++)
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
                  color: won ? const Color(0xFFB6E3A8) : const Color(0xFFE2614A),
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

/// Cailloux en vol, impacts, bande de fronde + trajectoire prévisionnelle.
class _ShotPainter extends CustomPainter {
  _ShotPainter({
    required this.stones,
    required this.impacts,
    required this.anchor,
    required this.aiming,
    required this.launchVel,
    required this.g,
    required this.hUnit,
  });
  final List<_Stone> stones;
  final List<_Impact> impacts;
  final Offset anchor;
  final bool aiming;
  final Offset? launchVel;
  final double g;
  final double hUnit;

  @override
  void paint(Canvas canvas, Size size) {
    // Cailloux.
    final stonePaint = Paint()..color = const Color(0xFF6E6258);
    final stoneEdge = Paint()
      ..color = const Color(0xFF453E37)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final s in stones) {
      final p = Offset(s.pos.dx * hUnit, s.pos.dy * hUnit);
      canvas.drawCircle(p, 0.013 * hUnit, stonePaint);
      canvas.drawCircle(p, 0.013 * hUnit, stoneEdge);
    }

    // Impacts : anneau qui s'étend + éclats.
    for (final im in impacts) {
      final c = Offset(im.pos.dx * hUnit, im.pos.dy * hUnit);
      final t = im.t.clamp(0.0, 1.0);
      final r = (0.012 + 0.05 * t) * hUnit;
      final a = (1 - t);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = const Color(0xFFFFE2B0).withValues(alpha: 0.7 * a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      final speck = Paint()..color = const Color(0xFFBFA98C).withValues(alpha: a);
      for (int i = 0; i < 6; i++) {
        final ang = i * math.pi / 3 + t;
        final d = r * 1.1;
        canvas.drawCircle(
            c + Offset(math.cos(ang) * d, math.sin(ang) * d), 2.0 * (1 - t), speck);
      }
    }

    // Visée.
    if (aiming && launchVel != null) {
      final pullEnd = anchor - launchVel! * (hUnit * 0.06);
      canvas.drawLine(
        anchor,
        pullEnd,
        Paint()
          ..color = const Color(0xFFE8B96B)
          ..strokeWidth = 3,
      );
      final dot = Paint()..color = Colors.white.withValues(alpha: 0.85);
      Offset pos = Offset(anchor.dx / hUnit, anchor.dy / hUnit);
      Offset vel = launchVel!;
      const double step = 0.045;
      for (int i = 0; i < 30; i++) {
        vel = vel + Offset(0, g * step);
        pos = pos + vel * step;
        if (pos.dy > 1.2) break;
        final px = Offset(pos.dx * hUnit, pos.dy * hUnit);
        if (i.isEven) canvas.drawCircle(px, 2.2, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ShotPainter old) => true;
}
