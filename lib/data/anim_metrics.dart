/// Table unifiée des métriques de rendu pour les sprites héroïne (49
/// frames chacun). Une seule source de vérité partagée entre wagon
/// et locomotive.
///
/// Pour chaque anim, [scale] est un multiplicateur sur [kHeroBaseHeight]
/// (lui-même en fraction de la hauteur de scène) — il sert à compenser
/// la fraction du sprite occupée par le personnage. [aspect] est le
/// ratio largeur/hauteur du sprite source. [feet] est la position
/// verticale de la bbox-bottom dans le sprite (1.0 = pieds collés au
/// bord du sprite, 0.86 = pieds à 86%, donc 14% de padding sous).
///
/// Pour ajuster une anim qui paraît mal calibrée :
/// 1) Lancer `python3 tools/measure_sprite_bboxes.py` pour voir les
///    valeurs mesurées.
/// 2) Tweaker [scale] (réduit ou agrandit) et [feet] (remonte ou
///    descend la position verticale) pour cette anim.
/// 3) Les anims avec **du mobilier dans la bbox** (read = chaise,
///    pet_dog = chien, cook = poêle, garden_tend = plante) ont une
///    bbox plus large que le perso — pour elles, [scale] mesurée par
///    le script surévalue la taille du perso. Garder une valeur plus
///    proche de 1.0.
class AnimMetrics {
  const AnimMetrics({
    required this.scale,
    required this.aspect,
    required this.feet,
    this.noMirror = false,
  });

  final double scale;
  final double aspect;
  final double feet;

  /// Si vrai, le sprite n'est JAMAIS flippé horizontalement quel que
  /// soit `_heroFacingRight`. À mettre sur les anims dont la
  /// composition a une orientation fixe (chaise + livre dans `read`,
  /// chien dans `pet_dog`, ou perso face caméra comme `dance`) — ou
  /// quand la source pointe déjà dans la bonne direction (`warm_hands`
  /// face au feu à gauche).
  final bool noMirror;
}

/// Hauteur de référence du sprite walk_right (scale=1.0) en fraction
/// de la hauteur de scène — c'est la **base wagon**. Toutes les
/// autres anims se calibrent via `scale` pour matcher visuellement
/// cette taille de perso.
///
/// La scène loco utilise sa propre base (plus grande, cf. constante
/// `_kLocoHeroBase` dans `locomotive_scene.dart`) car la caméra y
/// est plus rapprochée. Mais elle pioche les mêmes ratios scale /
/// aspect / feet dans la table ci-dessous.
const double kHeroBaseHeight = 0.36;

/// Bake des valeurs au 2026-05-24. Les anims avec [scale] = 1.422 =
/// 512/360 correspondent aux sprites 512x512 dont le perso debout
/// occupe la pleine hauteur (yawn, look_window, stretch, wake_up,
/// door_push). Les anims avec un meuble dans la bbox (read, pet_dog,
/// cook, garden_tend, drink) sont calibrées scale=1.0 pour ne pas
/// surévaluer la taille perso — la bbox enveloppe à la fois le
/// perso et le mobilier, donc 1.0 (= taille de walk_right) reste
/// proche de la silhouette réelle.
/// Toutes les valeurs scale sont calibrées via
/// `python3 tools/measure_sprite_bboxes.py` : scale = 0.974 / h_ratio
/// (idle_right h_ratio = 0.974 sert de référence). Ce ratio garantit
/// que la tête du perso reste à la même hauteur écran quelle que soit
/// l'anim. Les anims avec gros mobilier dans la bbox (read, pet_dog)
/// sont capées plus bas pour ne pas que le meuble domine.
const Map<String, AnimMetrics> kAnimMetrics = {
  // --- Debout, crops serrés (legacy 170×381 / 91×372) ---
  'walk_right':    AnimMetrics(scale: 1.01, aspect: 166 / 381, feet: 0.984),
  'idle_right':    AnimMetrics(scale: 1.00, aspect:  91 / 372, feet: 0.989),

  // --- Couchée (366×103) — géométrie horizontale, scale=1.0 ---
  'sleep_right':   AnimMetrics(
    scale: 1.00, aspect: 366 / 103, feet: 1.00, noMirror: true,
  ),

  // --- Dance (264×425) — bras levés, face caméra ---
  'dance':         AnimMetrics(
    scale: 1.11, aspect: 264 / 425, feet: 0.987, noMirror: true,
  ),

  // --- Pickup (170×385) — penchée, garder ~1.0 ---
  'pickup':        AnimMetrics(scale: 1.00, aspect: 170 / 385, feet: 0.948),

  // --- 512×512 debout (idle-breaks), mirror selon facing ---
  'yawn':          AnimMetrics(scale: 1.40, aspect: 1.0, feet: 0.861),
  'look_window':   AnimMetrics(scale: 1.22, aspect: 1.0, feet: 0.891),

  // --- 512×512 composition orientée → noMirror ---
  'stretch':       AnimMetrics(
    scale: 1.25, aspect: 1.0, feet: 0.891, noMirror: true,
  ),
  'wake_up':       AnimMetrics(
    scale: 1.67, aspect: 1.0, feet: 0.859, noMirror: true,
  ),
  'wake_up_clean': AnimMetrics(
    scale: 1.40, aspect: 1.0, feet: 0.859, noMirror: true,
  ),
  'door_push':     AnimMetrics(scale: 1.46, aspect: 1.0, feet: 0.857),
  'open_door':     AnimMetrics(scale: 1.40, aspect: 1.0, feet: 0.88),
  'crouch':        AnimMetrics(scale: 1.30, aspect: 1.0, feet: 0.92, noMirror: true),

  // --- Loco-only ---
  'warm_hands':    AnimMetrics(
    scale: 1.00, aspect: 1.0, feet: 0.86, noMirror: true,
  ),
  'carry_walk':    AnimMetrics(scale: 1.37, aspect: 1.0, feet: 0.863),

  // --- Anims spéciales avec mobilier → noMirror ---
  'drink':         AnimMetrics(
    scale: 1.36, aspect: 1.0, feet: 0.863, noMirror: true,
  ),
  'cook':          AnimMetrics(
    scale: 1.38, aspect: 1.0, feet: 0.859, noMirror: true,
  ),
  'garden_tend':   AnimMetrics(
    scale: 1.30, aspect: 1.0, feet: 0.871, noMirror: true,
  ),
  // Capés — gros mobilier dans la bbox gonfle le h_ratio.
  'read':          AnimMetrics(
    scale: 0.90, aspect: 1.0, feet: 0.840, noMirror: true,
  ),
  'pet_dog':       AnimMetrics(
    scale: 1.20, aspect: 1.0, feet: 0.845, noMirror: true,
  ),
};

/// Fallback pour une anim non listée — préserve les proportions d'un
/// carré 512x512 type yawn pour éviter un crash.
const AnimMetrics kAnimMetricsDefault = AnimMetrics(
  scale: 512 / 360,
  aspect: 1.0,
  feet: 0.86,
);

AnimMetrics animMetricsFor(String prefix) {
  return kAnimMetrics[prefix] ?? kAnimMetricsDefault;
}
