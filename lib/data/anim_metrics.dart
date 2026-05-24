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
const Map<String, AnimMetrics> kAnimMetrics = {
  // Sprites legacy (crops serrés autour du perso debout) — mirror
  // selon `_heroFacingRight` (source face à droite).
  'walk_right':    AnimMetrics(scale: 1.000, aspect: 166 / 381, feet: 1.000),
  'idle_right':    AnimMetrics(scale: 1.000, aspect:  91 / 372, feet: 1.000),

  // Sprite couchée — proportions horizontales. Composition fixe
  // (orientation de la tête baked dans le sprite).
  'sleep_right':   AnimMetrics(
    scale: 1.000, aspect: 366 / 103, feet: 1.000, noMirror: true,
  ),

  // Dance : bras levés, 264x425, perso face caméra → jamais flippé.
  'dance':         AnimMetrics(
    scale: 425 / 365, aspect: 264 / 425, feet: 1.000, noMirror: true,
  ),

  // Pickup : 170x385, perso plié, mirror selon facing (et special-
  // case en loco selon l'action).
  'pickup':        AnimMetrics(scale: 1.000, aspect: 170 / 385, feet: 1.000),

  // Carrés 512x512 — idle-breaks debout, mirror selon facing.
  'yawn':          AnimMetrics(scale: 512 / 360, aspect: 1.0, feet: 0.86),
  'look_window':   AnimMetrics(scale: 512 / 360, aspect: 1.0, feet: 0.86),

  // 512x512, composition orientée (stretch après wake, wake_up sur
  // le lit) → jamais flippées.
  'stretch':       AnimMetrics(
    scale: 512 / 360, aspect: 1.0, feet: 0.86, noMirror: true,
  ),
  'wake_up':       AnimMetrics(
    scale: 512 / 360, aspect: 1.0, feet: 0.86, noMirror: true,
  ),
  'wake_up_clean': AnimMetrics(
    scale: 512 / 360, aspect: 1.0, feet: 0.86, noMirror: true,
  ),
  // door_push : source pousse vers la droite, mais en wagon la porte
  // loco est à gauche → la scène wagon force toujours le mirror.
  // noMirror laissé à false pour ne pas surprendre si on réutilise
  // l'anim ailleurs sans mirror forcé.
  'door_push':     AnimMetrics(scale: 512 / 360, aspect: 1.0, feet: 0.86),

  // Loco-only — warm_hands face au feu (à gauche) en source, jamais
  // flippée. Valeurs dialées à l'œil en jeu (les valeurs scale=1.733
  // / 1.353 sorties par measure_sprite_bboxes.py surévaluent le
  // perso parce que la bbox englobe le poêle / la bûche).
  'warm_hands':    AnimMetrics(
    scale: 1.000, aspect: 1.0, feet: 0.86, noMirror: true,
  ),
  'carry_walk':    AnimMetrics(scale: 1.192, aspect: 1.0, feet: 0.863),

  // Anims spéciales avec mobilier dans la bbox — composition fixe,
  // jamais flippées. scale=1.0 (= taille de walk_right) calibre le
  // rendu proche de la silhouette réelle (la chaise/chien/poêle/
  // plante élargit la bbox alpha, donc le scale mesuré par le
  // script surévalue le perso). À tweaker à la main si l'une paraît
  // encore mal proportionnée en jeu.
  'read':          AnimMetrics(
    scale: 1.00, aspect: 1.0, feet: 0.84, noMirror: true,
  ),
  'cook':          AnimMetrics(
    scale: 1.00, aspect: 1.0, feet: 0.86, noMirror: true,
  ),
  'drink':         AnimMetrics(
    scale: 1.00, aspect: 1.0, feet: 0.86, noMirror: true,
  ),
  'garden_tend':   AnimMetrics(
    scale: 1.00, aspect: 1.0, feet: 0.87, noMirror: true,
  ),
  'pet_dog':       AnimMetrics(
    scale: 1.00, aspect: 1.0, feet: 0.85, noMirror: true,
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
