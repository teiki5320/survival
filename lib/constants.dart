// Constantes de gameplay centralisées.
// Modifier ici pour tuner sans chercher dans 5 fichiers.

// --- Train route (piloté par la progression des 14 gares) ---
// Position normalisée (0..1 le long de la spline de la carte) de chacune des
// 14 gares, dans l'ordre narratif. DOIT rester synchro avec _stations[i].t
// dans map_screen.dart (même valeurs, même ordre). Le train n'avance plus sur
// une horloge : sa position = la gare courante de la run + progression dans
// le segment. Ainsi la carte reflète l'histoire au lieu de tourner en boucle.
const List<double> kGarePositions = [
  0.9887, // 1  Station abandonnée
  0.0865, // 2  Halte 47
  0.1854, // 3  Dépôt ferroviaire
  0.2143, // 4  Halte 12
  0.2857, // 5  Village fantôme
  0.3467, // 6  Halte 83
  0.4024, // 7  Camp-refuge
  0.4631, // 8  Pont suspendu — ENTRÉE ZONE FROIDE
  0.5714, // 9  Halte 9
  0.6409, // 10 Oasis perdue
  0.6771, // 11 Halte 31
  0.7923, // 12 Tour de guet
  0.8571, // 13 Halte 6
  0.9286, // 14 Tunnel nord (refuge)
];

// Gare (0-based) à partir de laquelle on bascule dans le grand nord glacé.
// Canon : gare 8 = "entrée zone froide" → la loco boit plus de bois.
const int kColdGareIndex = 7;
// Surconsommation de bois par carte une fois dans le froid (drain mécanique
// qui relie la carte au gameplay ; calé par simulation).
const int kColdBoisDrainPerCard = 2;

// --- Réserve de bois (bûches) ---
// Le bois est une RÉSERVE épuisable (itemCount('wood')), pas une prod infinie :
// alimenter le foyer (jauge Bois) consomme 1 bûche. On se réapprovisionne à
// certaines gares (dépôt, camp, oasis) → il faut FAIRE DES STOCKS avant le
// grand nord, sinon la loco s'éteint. Valeurs calées par simulation.
const int kWoodStartReserve = 4;
// Bûches offertes à l'arrivée de certaines gares (index 0-based de la gare).
// idx 2 = Dépôt ferroviaire, idx 6 = Camp-refuge (juste avant le froid),
// idx 9 = Oasis perdue (répit en plein froid). Calé par simulation : le bois
// devient une cause de mort réelle (~16% des morts d'un joueur attentif, 68%
// d'un joueur négligent) sans empêcher un joueur soigneux de survivre.
const Map<int, int> kWoodSupplyByGare = {2: 5, 6: 6, 9: 4};

// --- Weather ---
const Duration kWeatherPeriod = Duration(minutes: 5);

// --- Hero ---
const double kHeroXMin = 0.22;
const double kHeroXMax = 0.86;
const double kHeroBaseHeight = 0.36;
const double kHeroSpeed = 0.18;
const int kWalkFrameMs = 50;
const int kIdleFrameMs = 80;
const int kDanceFrameMs = 55;
const int kSleepFrameMs = 110;
const int kSpecialFrameMs = 70;
const int kHeroFrameCount = 49;

// --- Dog ---
const double kDogDefaultHeight = 0.136;
const double kDogTop = 0.673;
const double kDogXMin = 0.35;
const double kDogXMax = 0.70;

// --- Parallax ---
const Duration kSkyDuration = Duration(seconds: 30);
const Duration kHorizonDuration = Duration(seconds: 28);
const Duration kForegroundDuration = Duration(seconds: 4);
const Duration kHorizonRotatePeriod = Duration(seconds: 45);
const Duration kHorizonCrossFade = Duration(seconds: 2);

// --- Cook depth ---
const double kCookDepthScale = 0.78;
const double kCookFeetOffset = 0.06;
