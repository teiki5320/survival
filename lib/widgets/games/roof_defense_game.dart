import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Mini-jeu de défense du toit du train, proposé aux gares.
///
/// Shen est sur le toit du wagon (à gauche), des **pillards** arrivent de la
/// droite et avancent vers le train. Elle les repousse au **lance-pierre** :
/// on glisse pour tirer la fronde vers l'arrière puis on relâche — le caillou
/// part en **arc** (gravité). On doit **survivre à plusieurs vagues** ; chaque
/// pillard qui atteint le wagon entame l'intégrité du train (cœurs).
///
/// Tout est en **unités de hauteur** (1 unité = hauteur de la zone de jeu) pour
/// que la physique de l'arc soit isotrope quel que soit le ratio d'écran.
/// Sprites en placeholders pour l'instant : `silhouette_*.png` (pillards) et
/// `idle_right_1` (Shen). À remplacer par les vrais sprites générés.
class RoofDefenseGame extends StatefulWidget {
  const RoofDefenseGame({super.key, required this.onExit});

  /// Appelé quand le joueur quitte (victoire validée ou abandon).
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
    required this.sil,
    required this.phase,
  });
  double x; // unités H (centre)
  double feetY; // ligne des pieds (unités H)
  double speed; // unités/s vers la gauche
  double height; // hauteur sprite (unités H)
  int sil; // index silhouette 1..13
  double phase; // déphasage du dandinement
  int hp = 1;
}

class _Stone {
  _Stone(this.pos, this.vel);
  Offset pos; // unités H
  Offset vel; // unités/s
}

class _RoofDefenseGameState extends State<RoofDefenseGame>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _rng = math.Random();

  // --- Géométrie (unités H) ---
  static const Offset _shen = Offset(0.22, 0.43); // ancre fronde (mains)
  static const double _shenFeetY = 0.55; // pieds de Shen sur le toit
  static const double _groundY = 0.74; // ligne des pieds des pillards
  static const double _trainEdgeX = 0.13; // au-delà = dégâts au train
  static const double _g = 1.9; // gravité (unités/s²)
  static const double _power = 5.2; // vitesse = pull * power
  static const double _maxSpeed = 2.6;
  static const double _stoneR = 0.013;
  static const double _enemyR = 0.058;
  static const double _reload = 0.28; // s entre deux tirs

  // --- Vagues ---
  // (nombre de pillards, vitesse, intervalle d'apparition)
  static const List<(int, double, double)> _waves = [
    (4, 0.085, 1.15),
    (5, 0.095, 1.00),
    (6, 0.110, 0.90),
    (7, 0.125, 0.80),
    (9, 0.145, 0.70),
  ];

  final List<_Enemy> _enemies = [];
  final List<_Stone> _stones = [];

  int _wave = 0; // index vague courante
  int _toSpawn = 0; // pillards restant à faire apparaître dans la vague
  double _spawnTimer = 0;
  double _banner = 1.8; // bandeau "Vague X" (s) avant de lancer la vague
  double _reloadTimer = 0;

  int _trainHp = 5;
  int _kills = 0;
  _Status _status = _Status.playing;

  // --- Visée ---
  bool _aiming = false;
  Offset _dragStart = Offset.zero; // px
  Offset _dragNow = Offset.zero; // px
  double _viewH = 1; // hauteur zone de jeu en px (pour px<->unités)

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
    if (dt > 0.05) dt = 0.05; // clamp (lag / pause)
    if (_status != _Status.playing) return;

    // Bandeau de vague : on attend avant de faire apparaître les pillards.
    if (_banner > 0) {
      _banner -= dt;
      if (_banner <= 0) {
        _toSpawn = _waves[_wave].$1;
        _spawnTimer = 0.4;
      }
      setState(() {});
      return;
    }

    // Apparition des pillards de la vague.
    if (_toSpawn > 0) {
      _spawnTimer -= dt;
      if (_spawnTimer <= 0) {
        _spawnEnemy(_waves[_wave].$2);
        _toSpawn--;
        _spawnTimer = _waves[_wave].$3;
      }
    }

    // Pillards : avancent vers la gauche.
    for (final e in _enemies) {
      e.x -= e.speed * dt;
    }
    _enemies.removeWhere((e) {
      if (e.x <= _trainEdgeX) {
        _trainHp--;
        if (_trainHp <= 0) _status = _Status.lost;
        return true;
      }
      return false;
    });

    // Cailloux : balistique + sortie d'écran.
    final aspect = _viewAspect;
    for (final s in _stones) {
      s.vel = s.vel + Offset(0, _g * dt);
      s.pos = s.pos + s.vel * dt;
    }
    _stones.removeWhere((s) =>
        s.pos.dy > 1.15 || s.pos.dx > aspect + 0.2 || s.pos.dx < -0.2);

    // Collisions caillou <-> pillard.
    for (final s in _stones) {
      for (final e in _enemies) {
        if (e.hp <= 0) continue;
        final dx = s.pos.dx - e.x;
        final dy = s.pos.dy - (e.feetY - e.height * 0.45);
        if (dx * dx + dy * dy <= (_enemyR + _stoneR) * (_enemyR + _stoneR)) {
          e.hp--;
          s.pos = const Offset(-99, -99); // marque pour suppression
          _kills++;
          break;
        }
      }
    }
    _stones.removeWhere((s) => s.pos.dx < -90);
    _enemies.removeWhere((e) => e.hp <= 0);

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
    final aspect = _viewAspect;
    _enemies.add(_Enemy(
      x: aspect + 0.12,
      feetY: _groundY + (_rng.nextDouble() - 0.5) * 0.04,
      speed: speed * (0.85 + _rng.nextDouble() * 0.3),
      height: 0.20 + _rng.nextDouble() * 0.05,
      sil: 1 + _rng.nextInt(13),
      phase: _rng.nextDouble() * math.pi * 2,
    ));
  }

  // Ratio largeur/hauteur de la zone de jeu, mis à jour à chaque build.
  double _viewAspect = 1.6;

  // Vitesse de tir courante d'après le drag (unités/s), pour preview + tir.
  Offset _launchVel() {
    final pullPx = _dragStart - _dragNow; // tirer vers l'arrière
    final pull = Offset(pullPx.dx / _viewH, pullPx.dy / _viewH);
    var v = pull * _power;
    final sp = v.distance;
    if (sp > _maxSpeed) v = v * (_maxSpeed / sp);
    return v;
  }

  void _fire() {
    if (_reloadTimer > 0) return;
    final v = _launchVel();
    if (v.distance < 0.25) return; // trop faible = pas de tir
    _stones.add(_Stone(_shen, v));
    _reloadTimer = _reload;
  }

  void _restart() {
    setState(() {
      _enemies.clear();
      _stones.clear();
      _wave = 0;
      _toSpawn = 0;
      _spawnTimer = 0;
      _banner = 1.8;
      _trainHp = 5;
      _kills = 0;
      _reloadTimer = 0;
      _status = _Status.playing;
      _aiming = false;
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
                // Décor (ciel, horizon, sol, rails, toit du wagon).
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SceneryPainter(
                      groundY: _groundY,
                      shenFeetY: _shenFeetY,
                    ),
                  ),
                ),

                // Pillards.
                for (final e in _enemies)
                  Positioned(
                    left: e.x * h - (e.height * h * 0.30),
                    top: e.feetY * h - e.height * h,
                    width: e.height * h * 0.60,
                    height: e.height * h,
                    child: IgnorePointer(
                      child: _Pillard(sil: e.sil, phase: e.phase),
                    ),
                  ),

                // Shen sur le toit (placeholder idle, face à droite).
                Positioned(
                  left: _shen.dx * h - 0.13 * h,
                  top: _shenFeetY * h - 0.28 * h,
                  width: 0.26 * h,
                  height: 0.28 * h,
                  child: const IgnorePointer(
                    child: Image(
                      image: AssetImage('assets/characters/idle_right_1.png'),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                // Cailloux + bande de visée + trajectoire.
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _ShotPainter(
                        stones: _stones,
                        anchor: u2p(_shen),
                        aiming: _aiming,
                        launchVel: _aiming ? _launchVel() : null,
                        g: _g,
                        hUnit: h,
                      ),
                    ),
                  ),
                ),

                // HUD.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
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
                ),

                // Bandeau "Vague X".
                if (playing && _banner > 0)
                  Center(
                    child: _banner > 0
                        ? Container(
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
                          )
                        : const SizedBox.shrink(),
                  ),

                // Aide visée (au tout début).
                if (playing && _wave == 0 && _kills == 0 && _banner <= 0)
                  const Positioned(
                    bottom: 28,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: Text(
                          'Glisse vers l’arrière puis relâche pour tirer',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Fin de partie.
                if (!playing) _endOverlay(),
              ],
            ),
          );
        },
      ),
    );
  }

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

/// Pillard placeholder : silhouette sombre orientée vers la gauche (vers le
/// train), avec un léger dandinement vertical pour simuler la marche.
class _Pillard extends StatefulWidget {
  const _Pillard({required this.sil, required this.phase});
  final int sil;
  final double phase;

  @override
  State<_Pillard> createState() => _PillardState();
}

class _PillardState extends State<_Pillard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final bob = math.sin(_c.value * math.pi * 2 + widget.phase) * 3;
        return Transform.translate(offset: Offset(0, bob), child: child);
      },
      // Miroir : les silhouettes regardent à droite -> on les retourne vers
      // la gauche (sens de marche vers le train).
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
        child: ColorFiltered(
          colorFilter: const ColorFilter.mode(
            Color(0xFF20242E),
            BlendMode.srcATop,
          ),
          child: Image.asset(
            'assets/characters/silhouette_${widget.sil}.png',
            fit: BoxFit.contain,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}

/// Décor : ciel, horizon, sol, rails, et le toit du wagon (à gauche).
class _SceneryPainter extends CustomPainter {
  _SceneryPainter({
    required this.groundY,
    required this.shenFeetY,
  });
  final double groundY;
  final double shenFeetY;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final gy = groundY * h;

    // Ciel.
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF2C3A4F), Color(0xFF55617A), Color(0xFF8A8FA0)],
        stops: [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, gy));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, gy), sky);

    // Horizon lointain (collines floues).
    final hill = Paint()..color = const Color(0xFF6A7081);
    final path = Path()..moveTo(0, gy);
    for (double x = 0; x <= w; x += w / 8) {
      path.lineTo(x, gy - 30 - 18 * math.sin(x / w * 6));
    }
    path
      ..lineTo(w, gy)
      ..close();
    canvas.drawPath(path, hill);

    // Sol.
    canvas.drawRect(
      Rect.fromLTWH(0, gy, w, h - gy),
      Paint()..color = const Color(0xFF3A3A40),
    );
    // Ballast / rail.
    final railY = gy + (h - gy) * 0.30;
    canvas.drawLine(Offset(0, railY), Offset(w, railY),
        Paint()..color = const Color(0xFF20232A)..strokeWidth = 4);
    final tie = Paint()..color = const Color(0xFF2A2C33)..strokeWidth = 6;
    for (double x = 0; x < w; x += 38) {
      canvas.drawLine(Offset(x, railY - 6), Offset(x - 10, railY + 10), tie);
    }

    // Toit du wagon (à gauche) : bloc sombre arrondi qui dépasse du bord.
    final roofTop = shenFeetY * h;
    final roofRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(-w * 0.05, roofTop, w * 0.40, h - roofTop),
      topRight: const Radius.circular(16),
    );
    canvas.drawRRect(
      roofRect,
      Paint()..color = const Color(0xFF4A3A2C),
    );
    // Liseré clair du bord du toit.
    canvas.drawLine(
      Offset(0, roofTop),
      Offset(w * 0.35, roofTop),
      Paint()
        ..color = const Color(0xFF6B5236)
        ..strokeWidth = 5,
    );
    // Planches du toit.
    final plank = Paint()..color = const Color(0x33000000)..strokeWidth = 2;
    for (double x = 0; x < w * 0.34; x += 26) {
      canvas.drawLine(Offset(x, roofTop + 6), Offset(x, h), plank);
    }
  }

  @override
  bool shouldRepaint(covariant _SceneryPainter old) => false;
}

/// Cailloux en vol + bande de fronde + trajectoire prévisionnelle en pointillé.
class _ShotPainter extends CustomPainter {
  _ShotPainter({
    required this.stones,
    required this.anchor,
    required this.aiming,
    required this.launchVel,
    required this.g,
    required this.hUnit,
  });
  final List<_Stone> stones;
  final Offset anchor; // px
  final bool aiming;
  final Offset? launchVel; // unités/s
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

    // Visée : fronde + trajectoire.
    if (aiming && launchVel != null) {
      // Bande de la fronde (de l'ancre vers la position "tirée").
      final pullEnd = anchor - launchVel! * (hUnit * 0.06);
      canvas.drawLine(
        anchor,
        pullEnd,
        Paint()
          ..color = const Color(0xFFE8B96B)
          ..strokeWidth = 3,
      );
      // Trajectoire : on simule en unités H puis on convertit.
      final dot = Paint()..color = Colors.white.withValues(alpha: 0.85);
      Offset pos = Offset(anchor.dx / hUnit, anchor.dy / hUnit);
      Offset vel = launchVel!;
      const double step = 0.045;
      for (int i = 0; i < 26; i++) {
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
