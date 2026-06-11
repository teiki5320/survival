// Constantes de gameplay centralisées.
// Modifier ici pour tuner sans chercher dans 5 fichiers.

// --- Train route (piloté par la progression des 14 gares) ---
// Position normalisée (0..1 le long de la spline de la carte) de chacune des
// 14 gares, dans l'ordre narratif. DOIT rester synchro avec _stations[i].t
// dans map_screen.dart (même valeurs, même ordre). Le train n'avance plus sur
// une horloge : sa position = la gare courante de la run + progression dans
// le segment. Ainsi la carte reflète l'histoire au lieu de tourner en boucle.
const List<double> kGarePositions = [
  0.7923, // 1  Kogarashi (ville natale, DÉPART) — échangé avec Miharashi
  0.0865, // 2  Karasuno
  0.1854, // 3  Kurogane (dépôt ferroviaire)
  0.2143, // 4  Hoshikage
  0.9887, // 5  Mayoidani (ex-village fantôme, radio)
  0.3467, // 6  Shizuhara
  0.4024, // 7  Yasuragi (camp-refuge)
  0.4631, // 8  Tsukibashi (pont) — ENTRÉE ZONE FROIDE
  0.5714, // 9  Kiribe
  0.6409, // 10 Hidamari (oasis / serre)
  0.6771, // 11 Yukihara
  0.2857, // 12 Miharashi (tour de guet) — échangé avec le départ Kogarashi
  0.8571, // 13 Fubuki (col gelé)
  0.9286, // 14 Hokuto (tunnel nord / refuge)
];

// Gare (0-based) à partir de laquelle on bascule dans le grand nord glacé.
// Canon : gare 8 = "entrée zone froide" → la loco boit plus de bois.
const int kColdGareIndex = 7;
// Surconsommation de bois par carte une fois dans le froid (drain mécanique
// qui relie la carte au gameplay ; calé par simulation).
const int kColdBoisDrainPerCard = 2;

// --- Bois (FUSIONNÉ) ---
// Le bois = UNE seule jauge `cardBois` (0-100, mort à 0). `gareWoodLeft` =
// bûches à ramasser à la loco pour la gare courante (chaque bûche = +10
// cardBois). Tas par gare = 4 + bonus aux gares de ravitaillement (dépôt,
// camp, oasis). Le poêle, la gazinière et le froid puisent tous dans cardBois.
const int kWoodStartReserve = 4;
// Bûches offertes à l'arrivée de certaines gares (index 0-based de la gare).
// idx 2 = Kurogane (dépôt), idx 6 = Yasuragi (camp, juste avant le froid),
// idx 9 = Hidamari (oasis, répit en plein froid). Calé par simulation : le bois
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
// Anims héroïne réduites à 25 frames (cf. _heroFrameCount dans les scènes).
const int kHeroFrameCount = 25;

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
