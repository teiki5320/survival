// Constantes de gameplay centralisées.
// Modifier ici pour tuner sans chercher dans 5 fichiers.

// --- Train route ---
const int kLoopDurationSeconds = 3600; // 60 min pour un tour complet
const double kColdZoneStart = 0.0;
const double kColdZoneEnd = 0.40;
const double kTransitionWidth = 0.05;
const double kTrainStartPosition = 0.10;

// --- Energy ---
const int kMaxEnergy = 5;
const int kEnergyRefillSeconds = 300; // 5 min en prod

// --- Survival drain (secondes pour vider complètement) ---
const double kHungerFullDrainSeconds = 30 * 60; // 30 min
const double kThirstFullDrainSeconds = 20 * 60; // 20 min
const double kFatigueFullDrainSeconds = 45 * 60; // 45 min

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
