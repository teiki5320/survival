// Constantes de gameplay centralisées.
// Modifier ici pour tuner sans chercher dans 5 fichiers.

// --- Train route (piloté par la progression des 14 gares) ---
// Position normalisée (0..1 le long de la spline de la carte) de chacune des
// 14 gares, dans l'ordre narratif. DOIT rester synchro avec _stations[i].t
// dans map_screen.dart (même valeurs, même ordre). Le train n'avance plus sur
// une horloge : sa position = la gare courante de la run + progression dans
// le segment. Ainsi la carte reflète l'histoire au lieu de tourner en boucle.
const List<double> kGarePositions = [
  0.7923, // 1  Kogarashi (1re HALTE après la fuite — PAS la ville natale, qui
          //    est le départ, montré dans la cinématique).
  0.0865, // 2  Kurogane (dépôt ferroviaire — nourrir la loco)
  0.1854, // 3  Karasuno (brouillard, premiers pillards)
  0.2143, // 4  Mayoidani (village fantôme, radio à manivelle)
  0.9887, // 5  Tsukibashi (pont — RETROUVAILLES petite sœur)
  0.3467, // 6  Yasuragi (camp-refuge — cellier)
  0.4024, // 7  Hoshikage (souvenir d'enfance avec la sœur)
  0.4631, // 8  Kiribe (brume) — ENTRÉE ZONE FROIDE
  0.5714, // 9  Shizuhara (blizzard, la sœur tombe malade)
  0.6409, // 10 Hidamari (oasis / serre — répit)
  0.6771, // 11 Yukihara (barrage de pillards)
  0.2857, // 12 Miharashi (tour de guet — vue sur le refuge)
  0.8571, // 13 Fubuki (col gelé — sacrifice)
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
// idx 1 = Kurogane (dépôt), idx 5 = Yasuragi (camp, avant le froid),
// idx 9 = Hidamari (oasis, répit en plein froid). Calé par simulation : le bois
// reste une cause de mort réelle (rareté volontaire) sans empêcher un joueur
// soigneux de survivre.
const Map<int, int> kWoodSupplyByGare = {1: 5, 5: 6, 9: 4};

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

// --- Cook depth ---
const double kCookDepthScale = 0.78;
const double kCookFeetOffset = 0.06;
