import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../constants.dart';

class GameState extends ChangeNotifier {
  GameState._() {
    _initWeatherCycle();
    load();
  }
  static final GameState instance = GameState._();

  // --- Autosave débounced : toute modif d'état (notifyListeners) programme
  // une sauvegarde ~1,2 s plus tard. Sans ça, la progression d'un joueur
  // normal n'était jamais persistée -> pas de « Continuer » au relancement.
  bool _loading = false; // verrou : pas de save() pendant un load()

  @override
  void notifyListeners() {
    super.notifyListeners();
    // SAUVEGARDE AUX GARES SEULEMENT (demande user) : plus d'autosave débouncé
    // sur chaque changement. La persistance se fait UNIQUEMENT aux checkpoints
    // (frontières de gare) via `save(checkpoint: true)`. Entre deux gares, rien
    // n'est écrit -> fermer l'app fait reprendre à la dernière gare.
  }

  // --- Persistence (pur dart:io, zéro plugin natif) ---
  static String? _savePath;

  static String _getSavePathSync() {
    if (_savePath != null) return _savePath!;
    // Sur iOS, le home directory pointe vers le sandbox de l'app.
    // Documents/ est persisté entre les sessions.
    final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
    final docs = Directory('$home/Documents');
    if (!docs.existsSync()) docs.createSync(recursive: true);
    _savePath = '${docs.path}/train_cosy_save.json';
    return _savePath!;
  }

  /// Écrit la sauvegarde. `checkpoint: true` = un VRAI point de sauvegarde
  /// (frontière de gare, début/fin de run, reset). Sans ça, l'appel est ignoré :
  /// on ne persiste QU'AUX GARES (demande user). Tous les anciens `save()`
  /// éparpillés (crédits, souvenirs, props…) deviennent donc inertes.
  Future<void> save({bool checkpoint = false}) async {
    if (_loading) return; // ne pas écraser pendant qu'on charge
    if (!checkpoint) return; // sauvegarde aux gares uniquement
    try {
      final path = _getSavePathSync();
      final data = jsonEncode({
        'lampOn': _lampOn,
        'poeleOn': poeleOn,
        'bacGrowth': bacGrowth, 'bacSown': bacSown,
        'debugMode': debugMode,
        'seenTips': seenTips.toList(),
        'introCinematicSeen': introCinematicSeen,
        'gareWoodLeft': gareWoodLeft,
        'unlocked': _unlocked.toList(),
        'wagonStage': wagonStage,
        'cabinTemp': cabinTemp,
        'outfitWarmth': outfitWarmth,
        'wagon2Stage': wagon2Stage,
        'atelierStage': atelierStage,
        'wagon2LampAx': wagon2LampAx,
        'wagon2LampAy': wagon2LampAy,
        'wagon2LampBx': wagon2LampBx,
        'wagon2LampBy': wagon2LampBy,
        'wagon2LampAH': wagon2LampAH, 'wagon2LampBH': wagon2LampBH,
        'stoveX': stoveX, 'stoveY': stoveY, 'stoveH': stoveH,
        'wagon1Props':
            wagon1Props.map((k, v) => MapEntry(k, v.toList())),
        'salonProps':
            salonProps.map((k, v) => MapEntry(k, v.toList())),
        'bathX': bathX, 'bathY': bathY, 'bathH': bathH,
        'showerPanelX': showerPanelX, 'showerPanelY': showerPanelY,
        'showerPanelH': showerPanelH,
        'showerHeadX': showerHeadX, 'showerHeadY': showerHeadY,
        'showerHeadH': showerHeadH,
        'wagon2CommodeX': wagon2CommodeX, 'wagon2CommodeY': wagon2CommodeY,
        'wagon2CommodeH': wagon2CommodeH,
        'locoMapCx': locoMapCx, 'locoMapCy': locoMapCy, 'locoMapW': locoMapW,
        'locoMapTurnY': locoMapTurnY, 'locoMapLeanZ': locoMapLeanZ,
        'waterTankGlasses': waterTankGlasses,
        'sleepNeed': sleepNeed,
        'hygieneNeed': hygieneNeed,
        'lastComfortMs': lastComfortMs,
        'cardsRun': _cardsRunToJson(),
        'layoutBaked': true, // coords d'objets validées appliquées
      });
      await File(path).writeAsString(data);
    } catch (e) {
      debugPrint('GameState.save() a échoué: $e');
    }
  }

  Future<void> load() async {
    _loading = true;
    try {
      final path = _getSavePathSync();
      final file = File(path);
      if (!file.existsSync()) return;
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _lampOn = data['lampOn'] as bool? ?? true;
      poeleOn = data['poeleOn'] as bool? ?? false;
      bacGrowth = (data['bacGrowth'] as num?)?.toDouble() ?? 0.0;
      bacSown = data['bacSown'] as bool? ?? false;
      debugMode = data['debugMode'] as bool? ?? false;
      seenTips.clear();
      if (data['seenTips'] is List) {
        seenTips.addAll((data['seenTips'] as List).cast<String>());
      }
      introCinematicSeen = data['introCinematicSeen'] as bool? ?? false;
      gareWoodLeft = (data['gareWoodLeft'] as num?)?.toInt() ?? gareWoodLeft;
      _unlocked.clear();
      _unlocked.add('station_abandonnee');
      if (data['unlocked'] is List) {
        _unlocked.addAll((data['unlocked'] as List).cast<String>());
      }
      // 2 stages désormais (windowed/clean) : clamp pour vieilles sauvegardes.
      wagonStage = ((data['wagonStage'] as num?)?.toInt() ?? 0).clamp(0, 1);
      cabinTemp = (data['cabinTemp'] as num?)?.toDouble() ?? cabinTemp;
      outfitWarmth = (data['outfitWarmth'] as num?)?.toInt() ?? outfitWarmth;
      wagon2Stage = ((data['wagon2Stage'] as num?)?.toInt() ?? 0).clamp(0, 1);
      atelierStage = ((data['atelierStage'] as num?)?.toInt() ?? 0).clamp(0, 1);
      wagon2LampAx = (data['wagon2LampAx'] as num?)?.toDouble() ?? wagon2LampAx;
      wagon2LampAy = (data['wagon2LampAy'] as num?)?.toDouble() ?? wagon2LampAy;
      wagon2LampBx = (data['wagon2LampBx'] as num?)?.toDouble() ?? wagon2LampBx;
      wagon2LampBy = (data['wagon2LampBy'] as num?)?.toDouble() ?? wagon2LampBy;
      wagon2LampAH = (data['wagon2LampAH'] as num?)?.toDouble() ?? wagon2LampAH;
      wagon2LampBH = (data['wagon2LampBH'] as num?)?.toDouble() ?? wagon2LampBH;
      stoveX = (data['stoveX'] as num?)?.toDouble() ?? stoveX;
      stoveY = (data['stoveY'] as num?)?.toDouble() ?? stoveY;
      stoveH = (data['stoveH'] as num?)?.toDouble() ?? stoveH;
      final w1p = data['wagon1Props'];
      if (w1p is Map) {
        w1p.forEach((k, v) {
          if (v is List && v.length >= 3 && wagon1Props.containsKey(k)) {
            wagon1Props[k as String] =
                v.map((e) => (e as num).toDouble()).toList();
          }
        });
      }
      final slp = data['salonProps'];
      if (slp is Map) {
        slp.forEach((k, v) {
          if (v is List && v.length >= 4 && salonProps.containsKey(k)) {
            salonProps[k as String] =
                v.map((e) => (e as num).toDouble()).toList();
          }
        });
      }
      bathX = (data['bathX'] as num?)?.toDouble() ?? bathX;
      bathY = (data['bathY'] as num?)?.toDouble() ?? bathY;
      bathH = (data['bathH'] as num?)?.toDouble() ?? bathH;
      showerPanelX = (data['showerPanelX'] as num?)?.toDouble() ?? showerPanelX;
      showerPanelY = (data['showerPanelY'] as num?)?.toDouble() ?? showerPanelY;
      showerPanelH = (data['showerPanelH'] as num?)?.toDouble() ?? showerPanelH;
      showerHeadX = (data['showerHeadX'] as num?)?.toDouble() ?? showerHeadX;
      showerHeadY = (data['showerHeadY'] as num?)?.toDouble() ?? showerHeadY;
      showerHeadH = (data['showerHeadH'] as num?)?.toDouble() ?? showerHeadH;
      wagon2CommodeX = (data['wagon2CommodeX'] as num?)?.toDouble() ?? wagon2CommodeX;
      wagon2CommodeY = (data['wagon2CommodeY'] as num?)?.toDouble() ?? wagon2CommodeY;
      wagon2CommodeH = (data['wagon2CommodeH'] as num?)?.toDouble() ?? wagon2CommodeH;
      locoMapCx = (data['locoMapCx'] as num?)?.toDouble() ?? locoMapCx;
      locoMapCy = (data['locoMapCy'] as num?)?.toDouble() ?? locoMapCy;
      locoMapW = (data['locoMapW'] as num?)?.toDouble() ?? locoMapW;
      locoMapTurnY = (data['locoMapTurnY'] as num?)?.toDouble() ?? locoMapTurnY;
      locoMapLeanZ = (data['locoMapLeanZ'] as num?)?.toDouble() ?? locoMapLeanZ;
      waterTankGlasses =
          ((data['waterTankGlasses'] as num?)?.toInt() ?? 0)
              .clamp(0, waterTankMax);
      sleepNeed = ((data['sleepNeed'] as num?)?.toInt() ?? 100).clamp(0, 100);
      hygieneNeed = ((data['hygieneNeed'] as num?)?.toInt() ?? 100).clamp(0, 100);
      lastComfortMs = (data['lastComfortMs'] as num?)?.toInt() ?? 0;
      _loadCardsRun(data['cardsRun']);
      // MIGRATION : les anciennes sauvegardes ont des coords d'objets périmées
      // (jamais re-sauvées car l'autosave est récent) -> on applique une fois
      // les bonnes positions bakées, puis on marque la save (layoutBaked).
      if (data['layoutBaked'] != true) applyBakedLayout();
      notifyListeners();
    } catch (e, st) {
      // Sauvegarde illisible (JSON corrompu, droits, disque plein...) : on
      // démarre sur une partie vierge plutôt que de crasher, mais on LOG (en
      // debug) pour ne pas perdre l'info silencieusement.
      debugPrint('GameState.load() a échoué, partie vierge utilisée: $e\n$st');
    } finally {
      _loading = false;
    }
  }

  // --- Mode debug (outils de test cachés du vrai jeu) ---
  // Un seul interrupteur révèle tous les outils de dev (thermomètre test,
  // FAB d'ajustement des props, affichage de TOUS les objets du wagon).
  // Debug OFF = le vrai jeu (objets progressifs, température auto). Persisté.
  bool debugMode = false;
  void setDebugMode(bool v) {
    if (debugMode == v) return;
    debugMode = v;
    if (!v) _recomputeAutoTemp(); // repasse en température auto en sortant
    notifyListeners();
    save(checkpoint: true);
  }

  void toggleDebug() => setDebugMode(!debugMode);

  // --- Tutoriel & cinématique d'ouverture ---
  // `seenTips` : ids des bulles d'aide déjà vues (1re utilisation). Persisté.
  // `introCinematicSeen` : la cinématique d'ouverture a déjà été jouée.
  final Set<String> seenTips = {};
  bool introCinematicSeen = false;
  bool tipSeen(String id) => seenTips.contains(id);
  void markTipSeen(String id) {
    if (seenTips.add(id)) save();
  }

  void markIntroCinematicSeen() {
    if (!introCinematicSeen) {
      introCinematicSeen = true;
      save();
    }
  }

  // ===========================================================
  // SOURCE UNIQUE de déblocage des objets/compagnons.
  // Lue À LA FOIS pour la VISIBILITÉ (side_scroll_scene) ET pour
  // l'INTERACTIVITÉ (boutons d'action dans main.dart). Un élément non
  // débloqué est donc invisible ET non cliquable.
  // En mode debug, tout est débloqué (pour tester les anims/rendu).
  // ===========================================================
  bool propUnlocked(String key) =>
      debugMode || cardFlags.contains('asset_$key');
  bool get dogShown => debugMode || cardFlags.contains('aLeChien');
  bool get sisterShown => debugMode || cardFlags.contains('aLaSoeur');

  // --- Energy (RETIRÉ) ---
  // --- Jauges de survie : FUSIONNÉES avec les 4 stats du mode cartes ---
  // Le HUD du wagon lit les VRAIES jauges (cardFaim/Soif) normalisées 0..1.
  double get hunger => cardFaim / 100.0;
  double get thirst => cardSoif / 100.0;

  // --- Besoins de CONFORT (Tamagotchi) : sommeil + hygiène ---
  // NON létaux (seules soif/faim/bois/moral tuent). Ils décroissent doucement
  // dans le train et remontent en dormant (lit) / en se lavant (bain/douche).
  // Négligés trop longtemps, ils grignotent le moral (Shen épuisée / mal). 0-100.
  int sleepNeed = 100; // 100 = reposée
  int hygieneNeed = 100; // 100 = propre
  int _comfortDecayTick = 0;

  /// Décroissance des besoins de confort, appelée par le timer des besoins du
  /// wagon (~24 s). Sommeil tous les ~48 s, hygiène tous les ~72 s (plus lente).
  /// Très bas (<20), ils érodent le moral d'un cran (geste de soin = remède).
  void decayComfortNeeds() {
    _comfortDecayTick++;
    // Le sommeil ne décroît (et ne pénalise) QUE si le lit est débloqué (gare 1) :
    // sinon on punirait le moral avant que le joueur ait un moyen de dormir.
    final canSleep = propUnlocked('bed');
    if (canSleep && _comfortDecayTick % 2 == 0 && sleepNeed > 0) sleepNeed--;
    // L'hygiène ne décroît (et ne pénalise) QUE si on peut RÉELLEMENT se laver :
    // bain/douche débloqués (gare 10) ET pas en plein froid (le bain est refusé
    // si feltCold). Sinon on punirait le moral sans aucun remède possible.
    final canWash =
        (propUnlocked('bath') || propUnlocked('shower')) && !feltCold;
    if (canWash && _comfortDecayTick % 3 == 0 && hygieneNeed > 0) hygieneNeed--;
    // PÉNALITÉ MORALE seulement HORS FROID : en plein froid le _coldTimer draine
    // déjà le moral ET les gains sont bloqués (feltCold) -> empiler le drain
    // confort = double/triple peine non remontable. Le froid prime.
    if (!feltCold &&
        ((canSleep && sleepNeed < 20) || (canWash && hygieneNeed < 20))) {
      nudgeCardStat('moral', -1); // épuisement / inconfort
    }
    notifyListeners();
  }

  /// Boost de moral « confort » qui IGNORE le blocage froid (le froid empêche
  /// les gains de moral via nudgeCardStat). Réservé aux gestes qui réchauffent
  /// vraiment (achat boutique : colis de réconfort) -> un IAP payant doit
  /// toujours produire son effet, même en zone froide.
  void boostMoralComfort(int amount) {
    cardMoral = (cardMoral + amount).clamp(0, statMax);
    notifyListeners();
  }

  /// Dormir dans le lit : nuit complète -> remise à neuf du sommeil. Une vraie
  /// nuit de repos relance le voyage à fond (élan plein). Débloque aussi une
  /// carte-souvenir « rêve » (récompense NARRATIVE, pas une stat).
  void restoreSleep() {
    sleepNeed = 100;
    cardElan = cardElanMax; // repos complet -> élan rechargé au max
    unlockSouvenir('reve');
    notifyListeners();
  }

  /// Bain / douche : se laver -> hygiène au max. Débloque la carte-souvenir
  /// « bain » (gain NARRATIF : une page d'histoire, pas une stat).
  void restoreHygiene() {
    hygieneNeed = 100;
    rechargeElan(1);
    unlockSouvenir('bain');
    notifyListeners();
  }

  /// Débloque une CARTE-SOUVENIR (« carte personnalisée ») : pose le flag
  /// `souvenir_<key>` qui rend la carte narrative correspondante éligible dans
  /// le prochain segment de cartes. Aucun effet de stat. Vue une seule fois.
  void unlockSouvenir(String key, {int hope = 3}) {
    if (cardFlags.add('souvenir_$key')) {
      // ESPOIR (#8) : un souvenir vécu nourrit l'espoir (boostMoral ignore le
      // blocage froid -> un souvenir réchauffe même dans le grand nord glacé).
      // Le moral vit de l'ÉMOTION, pas de la survie. `hope` peut être NÉGATIF
      // (#9 radio à double tranchant : une bribe désespérée brise l'espoir).
      if (hope != 0) boostMoralComfort(hope);
      notifyListeners();
      save();
    }
  }

  /// Gain de moral « confort » (lire / chien / sœur / bain / douche) passé par
  /// un cooldown PARTAGÉ (45 s) pour empêcher de farmer le moral. Le geste lui-
  /// même (se laver, lire) a lieu quand même ; seul le BONUS moral est throttlé.
  /// Retourne true si le bonus a été appliqué. `lastComfortMs` vit dans le
  /// singleton -> survit au remontage de l'écran wagon.
  bool tryComfortMoral(int amount) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - lastComfortMs < 45000) return false;
    lastComfortMs = now;
    nudgeCardStat('moral', amount);
    rechargeElan(1); // s'occuper de Shen (chien/sœur/lecture) relance un peu
    return true;
  }

  // --- Wagon state ---
  bool _lampOn = true;
  bool get lampOn => _lampOn;
  void toggleLamp() {
    _lampOn = !_lampOn;
    notifyListeners();
    save();
  }

  /// Poêle à bois allumé : tant qu'il brûle, le bois descend doucement.
  bool poeleOn = false;
  void setPoeleOn(bool v) {
    if (poeleOn == v) return;
    poeleOn = v;
    _recomputeAutoTemp(); // le poêle change la chaleur de la cabine
    notifyListeners();
    save();
  }

  /// Bac de culture : pousse (0=semé … 1=fruits mûrs) + semé une fois lancé.
  double bacGrowth = 0.0;
  bool bacSown = false;
  void setBacGrowth(double v) {
    bacGrowth = v.clamp(0.0, 1.0);
    notifyListeners(); // pas de save() à chaque tick (trop fréquent)
  }

  void setBacSown(bool v) {
    bacSown = v;
    notifyListeners();
    save();
  }

  int wagonStage = 0;

  // --- Température cabine (thermomètre) ---
  // [cabinTemp] = température ressentie dans le wagon (°C). Calculée AUTO en
  // jeu normal (zone de la map + météo + nuit + feu/bois). En mode debug, le
  // bouton de test la pilote à la main.
  double cabinTemp = 18.0;
  bool isNight = false; // reporté depuis l'écran wagon (jour/nuit)
  // Protection contre le froid : meilleur wagon + habits chauds -> Shen
  // supporte des températures plus basses (seuil plus bas). Le poêle, lui,
  // RÉCHAUFFE la cabine (entre dans cabinTemp via le feu, pas ici).
  int outfitWarmth = 0; // bonus tenue (0 = tenue de base)

  /// Température cible calculée depuis l'environnement : zone traversée +
  /// météo + nuit + chaleur du feu (poêle alimenté en bois). C'est la mécanique
  /// cosy : garder du bois = garder la cabine chaude.
  double computeAutoCabinTemp() {
    double t;
    switch (trainZone) {
      case TrainZone.warm:
        t = 17;
        break;
      case TrainZone.transitionToWarm:
        t = 12;
        break;
      case TrainZone.transitionToCold:
        t = 5;
        break;
      case TrainZone.cold:
        t = -4;
        break;
    }
    switch (weather) {
      case Weather.snowy:
        t -= 4;
        break;
      case Weather.foggy:
        t -= 2;
        break;
      case Weather.rainy:
        t -= 2;
        break;
      case Weather.cloudy:
        t -= 1;
        break;
      case Weather.clear:
        break;
    }
    if (isNight) t -= 3;
    // CHALEUR DU POÊLE À BOIS : c'est le poêle ALLUMÉ (et alimenté en bois) qui
    // réchauffe la cabine. Éteint = aucune chaleur. C'est le levier ACTIF du
    // confort : entretenir le feu coûte du bois mais vainc le froid.
    if (poeleOn && cardBois > 0) {
      t += cardBois >= 30 ? 18 : 12; // feu vif si bonne réserve
    }
    return t.clamp(-15.0, 28.0);
  }

  /// Recale [cabinTemp] sur l'environnement (sauf en mode debug = manuel).
  void _recomputeAutoTemp() {
    if (debugMode) return; // en debug, le bouton test pilote la température
    final t = computeAutoCabinTemp();
    if ((t - cabinTemp).abs() > 0.05) {
      cabinTemp = t;
      notifyListeners();
    }
  }

  /// Reporte l'état jour/nuit (depuis l'écran wagon) et recale la température.
  void setNight(bool n) {
    if (isNight == n) return;
    isNight = n;
    _recomputeAutoTemp();
  }
  double get coldThreshold => 12.0 - wagonStage * 2 - outfitWarmth;
  // Vrai si Shen (et la sœur) ont froid -> frissons + blocage gain moral.
  bool get feltCold => cabinTemp < coldThreshold;
  // 0 (juste à la limite) .. ~20 (gel) : pilote la fréquence des frissons.
  double get coldness => (coldThreshold - cabinTemp).clamp(0.0, 20.0);
  void setCabinTemp(double t) {
    cabinTemp = t.clamp(-15.0, 28.0);
    notifyListeners();
    save();
  }

  /// 2e wagon (cellier) : 0 = en désordre (état initial), 1 = aménagé/propre.
  int wagon2Stage = 0;

  /// Atelier (wagon du milieu) : 0 = sale/encombré, 1 = rangé/propre.
  int atelierStage = 0;

  /// Position des 2 lanternes du cellier (fraction w pour x, h pour y).
  /// Déplaçables au doigt dans le wagon 2 ; sauvegardées.
  double wagon2LampAx = 0.27, wagon2LampAy = 0.21, wagon2LampAH = 0.12;
  double wagon2LampBx = 0.49, wagon2LampBy = 0.22, wagon2LampBH = 0.12;

  /// Poêle du wagon 1 : position + taille déplaçables (mode ajuster debug).
  /// Défaut = ancien emplacement de la table à biscuits (centre x 0.479).
  double stoveX = 0.479, stoveY = 0.445, stoveH = 0.263;

  /// Props ajustables du wagon 1 (lampe, bac de culture, filtre, poêle à bois,
  /// gazinière) : [x (centre, frac w), y (haut, frac h), h (hauteur, frac h),
  /// flipBits (0=aucun, 1=miroir H, 2=miroir V, 3=les deux)]. Déplaçables +
  /// redimensionnables + miroitables en mode ajuster debug, persistés.
  final Map<String, List<double>> wagon1Props = {
    'lamp': [0.640, 0.251, 0.108, 0],
    'bac': [0.514, 0.464, 0.307, 0],
    'filtre': [0.379, 0.530, 0.230, 0],
    'poele': [0.276, 0.523, 0.239, 0],
    'gaziniere': [0.695, 0.486, 0.278, 0],
  };
  /// Props ajustables du SALON (carnet, secours, gamelle, carte murale) :
  /// [centreX, top, height, width] en fractions. Réglables en debug, persistés.
  final Map<String, List<double>> salonProps = {
    'notebook': [0.249, 0.670, 0.070, 0.070],
    'firstaid': [0.296, 0.635, 0.110, 0.110],
    'bowl': [0.481, 0.669, 0.080, 0.080],
    'wallmap': [0.205, 0.300, 0.135, 0.185],
  };
  double slx(String k) => salonProps[k]![0];
  double sly(String k) => salonProps[k]![1];
  double slh(String k) => salonProps[k]![2];
  double slw(String k) => salonProps[k]![3];
  void slMove(String k, double dx, double dy) {
    final p = salonProps[k]!;
    p[0] = (p[0] + dx).clamp(0.02, 0.98);
    p[1] = (p[1] + dy).clamp(0.0, 0.92);
    notifyListeners();
  }

  void slResize(String k, double h) {
    final p = salonProps[k]!;
    final ratio = p[3] / p[2]; // garde l'aspect
    p[2] = h.clamp(0.03, 0.6);
    p[3] = p[2] * ratio;
    notifyListeners();
  }

  /// Réapplique les positions/tailles d'objets « validées » (atelier + cellier).
  /// Utilisé en migration (anciennes saves) et dispo pour un reset propre.
  void applyBakedLayout() {
    wagon1Props['lamp'] = [0.640, 0.251, 0.108, 0];
    wagon1Props['bac'] = [0.514, 0.464, 0.307, 0];
    wagon1Props['filtre'] = [0.379, 0.530, 0.230, 0];
    wagon1Props['poele'] = [0.276, 0.523, 0.239, 0];
    wagon1Props['gaziniere'] = [0.695, 0.486, 0.278, 0];
    bathX = 0.48; bathY = 0.48; bathH = 0.31;
    showerPanelX = 0.77; showerPanelY = 0.44; showerPanelH = 0.35;
    showerHeadX = 0.75; showerHeadY = 0.22; showerHeadH = 0.32;
    wagon2LampAx = 0.27; wagon2LampAy = 0.21; wagon2LampAH = 0.12;
    wagon2LampBx = 0.49; wagon2LampBy = 0.22; wagon2LampBH = 0.12;
    wagon2CommodeX = 0.29; wagon2CommodeY = 0.53; wagon2CommodeH = 0.23;
  }

  double w1x(String k) => wagon1Props[k]![0];
  double w1y(String k) => wagon1Props[k]![1];
  double w1h(String k) => wagon1Props[k]![2];
  int w1Flip(String k) {
    final p = wagon1Props[k]!;
    return p.length > 3 ? p[3].toInt() : 0;
  }

  bool w1FlipH(String k) => (w1Flip(k) & 1) != 0;
  bool w1FlipV(String k) => (w1Flip(k) & 2) != 0;
  void w1Move(String k, double dx, double dy) {
    final p = wagon1Props[k]!;
    p[0] = (p[0] + dx).clamp(0.02, 0.98);
    p[1] = (p[1] + dy).clamp(0.0, 0.92);
  }

  void w1Resize(String k, double h) {
    wagon1Props[k]![2] = h;
  }

  void w1ToggleFlip(String k, int bit) {
    final p = wagon1Props[k]!;
    while (p.length < 4) {
      p.add(0);
    }
    p[3] = (p[3].toInt() ^ bit).toDouble();
    save();
    notifyListeners();
  }

  /// Props positionnables du cellier (x=fraction w du centre, y=fraction h du
  /// haut, h=fraction h de la hauteur). Déplaçables + redimensionnables,
  /// sauvegardés. Valeurs par défaut calées en jeu (mode ajuster).
  double bathX = 0.48, bathY = 0.48, bathH = 0.31;
  double showerPanelX = 0.77, showerPanelY = 0.44, showerPanelH = 0.35;
  double showerHeadX = 0.75, showerHeadY = 0.22, showerHeadH = 0.32;
  // Armoire à vêtements (commode) déplacée dans le cellier : tap = ouvre la
  // garde-robe, déplaçable/redimensionnable en mode ajuster.
  double wagon2CommodeX = 0.29, wagon2CommodeY = 0.53, wagon2CommodeH = 0.23;

  /// Carte du voyage accrochée dans la LOCOMOTIVE : centre (cx,cy en fractions
  /// de la scène) + largeur (fraction de la largeur). Déplaçable + pinçable en
  /// mode ajuster, persistée.
  double locoMapCx = 0.94, locoMapCy = 0.33, locoMapW = 0.23;
  // Rotation 3/4 (axe vertical) + penché (axe écran), réglables à la main.
  double locoMapTurnY = 1.15; // tour 3/4 pour épouser le mur de droite
  double locoMapLeanZ = -0.08; // penché léger vers la gauche
  void setLocoMap(double cx, double cy, double w) {
    locoMapCx = cx.clamp(0.04, 0.96);
    locoMapCy = cy.clamp(0.04, 0.96);
    locoMapW = w.clamp(0.08, 0.95);
    notifyListeners();
    save();
  }

  void nudgeLocoMapRot(double dTurn, double dLean) {
    locoMapTurnY = (locoMapTurnY + dTurn).clamp(-1.4, 1.4);
    locoMapLeanZ = (locoMapLeanZ + dLean).clamp(-0.6, 0.6);
    notifyListeners();
    save();
  }

  // --- Water tank (filter prop) — 0..5 verres stockés ---
  int waterTankGlasses = 0;
  static const int waterTankMax = 5;
  static const int waterTankFrames = 6;

  void setWaterTankGlasses(int n) {
    waterTankGlasses = n.clamp(0, waterTankMax);
    notifyListeners();
    save();
  }


  // --- Météo (liée à la zone) ---
  Weather _weather = Weather.clear;
  Weather get weather => _weather;
  Timer? _weatherTimer;

  /// Palette météo cohérente avec la zone traversée. Le grand nord est
  /// majoritairement neigeux/brumeux ; la zone tempérée n'a JAMAIS de neige.
  List<Weather> _weatherPoolForZone(TrainZone zone) {
    switch (zone) {
      case TrainZone.cold:
        return [Weather.snowy, Weather.snowy, Weather.foggy, Weather.cloudy];
      case TrainZone.transitionToCold:
        return [Weather.foggy, Weather.cloudy, Weather.snowy, Weather.clear];
      case TrainZone.transitionToWarm:
        return [Weather.cloudy, Weather.clear, Weather.foggy, Weather.rainy];
      case TrainZone.warm:
        return [Weather.clear, Weather.clear, Weather.cloudy, Weather.rainy,
          Weather.foggy];
    }
  }

  void _pickWeather() {
    final pool = _weatherPoolForZone(trainZone)
      ..removeWhere((w) => w == _weather);
    if (pool.isEmpty) return;
    _weather = pool[DateTime.now().millisecondsSinceEpoch % pool.length];
    _recomputeAutoTemp(); // météo/zone changent -> température recalculée
    notifyListeners();
  }

  /// Force un rafraîchissement météo cohérent avec la zone courante. Appelé
  /// quand on change de gare (donc potentiellement de zone) : entrer dans le
  /// nord fait tomber la neige tout de suite, sans attendre le timer.
  void refreshWeatherForZone() => _pickWeather();

  void _initWeatherCycle() {
    // Variation d'ambiance DANS une zone (le changement de zone, lui, est
    // déclenché par refreshWeatherForZone à l'avance de gare).
    _weatherTimer ??= Timer.periodic(kWeatherPeriod, (_) => _pickWeather());
  }

  // --- Train route ---
  // Progression DANS le segment courant (0..1) : 0 = on vient d'arriver à la
  // gare, 1 = dernière carte du segment jouée. Mise à jour par le moteur de
  // cartes ; sert à faire glisser le train entre deux gares sur la carte.
  double cardSegmentProgress = 0.0;

  /// Position du train sur la spline de la carte (0..1). Dérivée de la
  /// progression de la run : gare courante + fraction du segment. Plus
  /// d'horloge — la carte suit l'histoire. Hors run, on est à la gare 1.
  double get trainPosition {
    if (!hasCardRun) return kGarePositions.first;
    final i = (cardGareIndex ?? 0).clamp(0, kGarePositions.length - 1);
    final t0 = kGarePositions[i];
    if (i >= kGarePositions.length - 1) return t0;
    final t1 = kGarePositions[i + 1];
    var forward = (t1 - t0) % 1.0; // distance vers l'avant (gère le wrap 1→0)
    if (forward < 0) forward += 1.0;
    final p = t0 + cardSegmentProgress.clamp(0.0, 1.0) * forward;
    return p % 1.0;
  }

  /// Indice de gare effectif pour les effets de zone (clampé).
  int get _effectiveGareIndex =>
      (cardGareIndex ?? 0).clamp(0, kGarePositions.length - 1);

  TrainZone get trainZone {
    if (!hasCardRun) return TrainZone.warm;
    final i = _effectiveGareIndex;
    if (i >= kColdGareIndex) return TrainZone.cold;
    if (i == kColdGareIndex - 1) return TrainZone.transitionToCold;
    return TrainZone.warm;
  }

  // Ambiance « froid » : dès la gare 7 (le froid s'annonce, givre/❄️).
  bool get inColdZone =>
      trainZone == TrainZone.cold || trainZone == TrainZone.transitionToCold;

  // Froid PROFOND (gare 8+, canon « entrée zone froide ») : c'est SEULEMENT ici
  // que la loco boit plus (drain bois/carte). La gare 7 (souvenir tendre) garde
  // l'ambiance froide mais pas la surconso -> cohérent avec le sim d'équilibrage.
  bool get inDeepCold => trainZone == TrainZone.cold;

  // --- Thought bubble context ---
  final Random _thoughtRng = Random();

  /// Emoji de la bulle de pensée de Shen. PRIORITÉ aux besoins urgents (cause →
  /// action évidente pour le joueur), sinon une pensée d'ambiance tirée au
  /// hasard parmi les options pertinentes (compagnons, espoir, météo, détente).
  String get contextualThought {
    // 1) BESOINS URGENTS — chaque emoji dit quoi faire.
    if (cardBois < 18) return '🪵'; // bois bas → nourrir la loco
    if (hunger < 0.2) return '🍖'; // faim → cuisiner
    if (thirst < 0.2) return '💧'; // soif → filtrer/boire
    if (sleepNeed < 20) return '💤'; // épuisée → dormir au lit
    if (hygieneNeed < 20) return '🛁'; // sale → bain/douche
    if (feltCold) return '🥶'; // a froid → poêle / manteau
    if (cardMoral < 20) return '😔'; // moral bas → réconfort

    // 2) AMBIANCE — pensées pertinentes selon l'état, tirées au hasard.
    final pool = <String>[];
    if (dogShown) pool.addAll(['🐶', '🐾']);
    if (sisterShown) pool.addAll(['👧', '❤️']);
    if (cardFlags.contains('capParents')) pool.add('👨‍👩‍👧'); // pense aux parents
    if (cardFlags.contains('aLaRadio')) pool.add('📻'); // espoir radio
    if (isNight) {
      pool.addAll(['🌙', '⭐']);
    } else {
      pool.add('☀️');
    }
    if (inColdZone) pool.add('❄️');
    // Détente cosy, toujours possible.
    pool.addAll(['☕', '🎵', '📖', '🌿', '😊', '💭']);
    return pool[_thoughtRng.nextInt(pool.length)];
  }

  // ===========================================================
  // MODE CARTES (Reigns) — source de vérité unique des 4 jauges
  // soif/faim/bois/moral (0-100) + état d'une run en cours.
  // Le wagon (manger/boire/mettre du bois) nudge ces jauges ; le
  // moteur de cartes les lit et les modifie. Tout est persisté.
  // ===========================================================
  static const int statMax = 100;
  int cardSoif = 70;
  int cardFaim = 70;
  int cardBois = 70;
  int cardMoral = 70;

  /// Ravitaillement à l'arrivée d'une gare (fouille/troc), appliqué une fois
  /// par gare par le moteur. Calibré par simulation (careless ~11% / casual
  /// ~62% / smart 100%). Appliqué en direct (pas de blocage froid : ce sont
  /// des vivres trouvés, pas du réconfort).
  void grantGareSupply() {
    cardBois = (cardBois + 9).clamp(0, statMax);
    cardSoif = (cardSoif + 5).clamp(0, statMax);
    cardFaim = (cardFaim + 7).clamp(0, statMax);
    cardMoral = (cardMoral + 4).clamp(0, statMax);
    notifyListeners();
  }

  /// Bois fusionné : `cardBois` est LA jauge de bois (mort à 0). `gareWoodLeft`
  /// = combien de bûches il reste à ramasser à la loco pour CETTE gare (chaque
  /// bûche jetée au foyer = +10 cardBois). Remplace l'ancienne réserve
  /// `_items['wood']` (deux nombres de bois -> un seul).
  int gareWoodLeft = 4;
  void setGareWoodLeft(int v) {
    gareWoodLeft = v.clamp(0, 99);
    save(checkpoint: true); // checkpoint gare (woodpile + supply)
    notifyListeners();
  }

  // File de déblocages d'objets à annoncer (toast dans le wagon). Non persisté.
  final List<String> pendingUnlocks = [];
  static const Map<String, String> unlockNames = {
    'asset_bed': 'la paillasse',
    'asset_realbed': 'un vrai lit',
    'asset_bowl': 'la gamelle',
    'asset_notebook': 'le carnet',
    'asset_firstaid': 'la trousse de secours',
    'asset_lamp': 'la lampe',
    'asset_filter': 'le filtre à eau',
    'asset_hydro': 'le bac de culture',
    'asset_bath': 'la baignoire',
    'asset_shower': 'la douche',
    'asset_stove': 'le poêle',
    'asset_lantern': 'les lanternes',
    'asset_commode': 'la commode',
    'asset_wagon2': 'le cellier (2e wagon)',
  };
  String? popUnlock() => pendingUnlocks.isEmpty ? null : pendingUnlocks.removeAt(0);

  // Progression de la run en cours (null = pas de run / terminée).
  int? cardGareIndex; // segment courant (0-based)
  final Set<String> cardFlags = {}; // flags narratifs de la run
  final Set<String> cardSeenOneshot = {}; // fillers oneshot déjà vus
  int cardSoin = 0; // nb de fois où Shen a vraiment protégé sa sœur

  // Cooldown partagé du moral « confort » (lire/chien/sœur/bain), porté ici pour
  // survivre au remontage de l'écran wagon ET persisté (relancer l'app ne doit
  // pas réarmer le cooldown = micro-exploit).
  int lastComfortMs = 0;

  bool get hasCardRun => cardGareIndex != null;

  // --- Crédits de tirage de cartes ---
  // Répondre à une carte (= la tirer) coûte 1 crédit. On en a
  // [cardCreditsMax] et ils se rechargent lentement EN TEMPS RÉEL (1 toutes
  // les [creditRefillInterval]). C'est CE rythme qui ralentit l'avancée de
  // l'histoire : on joue quelques cartes d'affilée, puis on laisse le temps
  // passer avant de continuer. (Remplace l'ancien budget de ravitaillement.)
  // Toggle GLOBAL du système de crédits. DÉSACTIVÉ (jeu sans mur de temps) ;
  // toute la machinerie est conservée si on veut réactiver un rythme.
  static const bool creditsEnabled = true;
  static const int cardCreditsMax = 5;
  static const Duration creditRefillInterval = Duration(minutes: 5);
  int cardCredits = cardCreditsMax;
  // Timestamp (ms epoch) où le PROCHAIN crédit sera rendu. 0 = pile pleine.
  int cardCreditNextMs = 0;

  /// Recalcule les crédits gagnés avec le temps écoulé (régen même hors-ligne).
  /// À appeler à l'ouverture de l'écran cartes et périodiquement.
  bool _refreshingCredits = false;
  void refreshCredits() {
    if (_refreshingCredits) return; // anti-réentrance (timer + ouverture écran)
    _refreshingCredits = true;
    try {
      _refreshCreditsInner();
    } finally {
      _refreshingCredits = false;
    }
  }

  void _refreshCreditsInner() {
    if (cardCredits >= cardCreditsMax) {
      cardCreditNextMs = 0;
      return;
    }
    final intervalMs = creditRefillInterval.inMilliseconds;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (cardCreditNextMs == 0) {
      // Aucune minuterie en cours : on en démarre une.
      cardCreditNextMs = now + intervalMs;
      save();
      return;
    }
    var changed = false;
    while (cardCredits < cardCreditsMax && now >= cardCreditNextMs) {
      cardCredits++;
      cardCreditNextMs += intervalMs;
      changed = true;
    }
    if (cardCredits >= cardCreditsMax) cardCreditNextMs = 0;
    if (changed) {
      notifyListeners();
      save();
    }
  }

  /// Millisecondes avant le prochain crédit (0 si pile pleine).
  int get msToNextCredit {
    if (cardCredits >= cardCreditsMax || cardCreditNextMs == 0) return 0;
    final d = cardCreditNextMs - DateTime.now().millisecondsSinceEpoch;
    return d < 0 ? 0 : d;
  }

  /// Dépense 1 crédit pour tirer une carte. Retourne false si à sec (l'écran
  /// bloque alors le swipe et invite à attendre la recharge).
  /// CRÉDITS : 5 max, −1 par carte, +1 toutes les 5 min en TEMPS RÉEL (régen
  /// même hors-ligne via timestamps). Le temps d'attente se meuble dans le wagon.
  bool spendCardCredit() {
    refreshCredits();
    if (cardCredits <= 0) return false;
    final wasFull = cardCredits >= cardCreditsMax;
    cardCredits--;
    if (wasFull) {
      // On était plein : démarre le minuteur de recharge du 1er crédit manquant.
      cardCreditNextMs =
          DateTime.now().millisecondsSinceEpoch + creditRefillInterval.inMilliseconds;
    }
    notifyListeners();
    save();
    return true;
  }

  // --- Élan du voyage (rythme cosy : alterner cartes <-> soins du wagon) ---
  // REMPLACE l'ancien mur de temps réel (crédits) par un rythme fondé sur
  // L'ENGAGEMENT : `cardElan` = le nombre d'« étapes » (gares) que le train peut
  // enchaîner avant que Shen ne soit à bout. On dépense 1 élan à CHAQUE gare
  // franchie (frontière de segment = point de reprise propre, jamais en plein
  // milieu). À 0, le train fait HALTE : il faut retourner s'occuper de Shen dans
  // le wagon (dormir la recharge à fond, la réchauffer / jouer un peu) avant de
  // repartir. Pas d'attente sur un écran verrouillé : c'est le wagon (le cœur
  // Tamagotchi) qui relance le voyage — ce qui remplace l'ancien combat comme
  // « chose à faire entre deux phases de cartes ».
  // ÉLAN DÉSACTIVÉ (remplacé par les crédits temps réel + la cinématique de
  // gare, à la demande). Code conservé au cas où.
  static const bool elanEnabled = false;
  static const int cardElanMax = 3;
  int cardElan = cardElanMax;

  // --- Cinématique d'arrivée en gare (FORCE la sortie des cartes) ---
  // À chaque NOUVELLE gare atteinte, on montre une cinématique (texte
  // `kGareIntros`) qui oblige à QUITTER les cartes (bouton -> onClose). On
  // mémorise les gares déjà « vues » pour ne pas la rejouer au retour. La gare
  // de départ (0) est marquée vue d'office (la cinématique d'ouverture la
  // couvre déjà). Persisté.
  final Set<int> cardGareCineSeen = {0};

  /// Vrai quand on vient d'arriver à une gare dont la cinématique n'a pas encore
  /// été jouée -> l'écran cartes montre la cinématique au lieu de la carte.
  bool gareCineBlocking(int gareIndex) =>
      !debugMode && !cardGareCineSeen.contains(gareIndex);

  /// Vrai quand Shen est à bout : la HALTE bloque le tirage de la gare suivante
  /// tant qu'on n'est pas repassé soigner Shen au wagon. (Jamais en debug.)
  bool get elanGateBlocking =>
      elanEnabled && !debugMode && hasCardRun && cardElan <= 0;

  /// Dépense 1 élan en franchissant une gare (appelé au passage de segment).
  void consumeLeg() {
    if (!elanEnabled || debugMode) return;
    if (cardElan > 0) cardElan--;
    notifyListeners();
  }

  /// Regagne de l'élan via les soins du wagon (dormir = plein, le reste = +n).
  void rechargeElan(int n) {
    if (n <= 0 || cardElan >= cardElanMax) return;
    cardElan = (cardElan + n).clamp(0, cardElanMax);
    notifyListeners();
  }

  // Stat de départ QUASI À ZÉRO (demande user) : l'histoire commence au bord du
  // gouffre — train abîmé, froid, Shen à bout, jauges presque vides. Avec le
  // petit ravito de la gare 0, les anneaux s'affichent ~10-15 % (presque vides).
  // À remonter péniblement en jouant. (Calé par simu : start 6 + pertes ×1.20.)
  static const int kStartStat = 6;

  /// Démarre une nouvelle run : remet jauges (basses), flags, progression à 0.
  void startCardRun() {
    cardSoif = kStartStat;
    cardFaim = kStartStat;
    cardBois = kStartStat;
    cardMoral = kStartStat;
    cardGareIndex = 0;
    cardFlags.clear();
    cardSeenOneshot.clear();
    cardSoin = 0;
    cardCredits = cardCreditsMax;
    cardCreditNextMs = 0;
    cardElan = cardElanMax;
    cardGareCineSeen
      ..clear()
      ..add(0); // gare de départ : pas de cinématique forcée (déjà l'ouverture)
    cardSegmentProgress = 0.0;
    // Réserve de bois de départ (bûches dans le wagon).
    gareWoodLeft = kWoodStartReserve; // bûches à ramasser à la gare de départ
    // Météo de départ cohérente avec la zone tempérée du début.
    _pickWeather();
    save(checkpoint: true);
    notifyListeners();
  }

  /// NOUVELLE PARTIE : remet TOUT à zéro (flags, jauges, objets débloqués,
  /// compagnons, état du wagon). Sans ça, « Nouvelle partie » gardait les flags
  /// (asset_*, aLeChien, aLaSoeur...) de la sauvegarde -> chien/objets restaient
  /// présents. Le mode debug, lui, est conservé (préférence de dev).
  void resetForNewGame() {
    waterTankGlasses = 0;
    sleepNeed = 100;
    hygieneNeed = 100;
    _comfortDecayTick = 0;
    lastComfortMs = 0;
    wagonStage = 0;
    wagon2Stage = 0;
    atelierStage = 0;
    // Train abîmé/vide à l'arrivée : pas de bac semé, pas de poêle allumé, pas
    // de manteau chaud hérités d'une partie précédente (sinon récolte/chaleur
    // gratuites au départ).
    poeleOn = false;
    bacSown = false;
    bacGrowth = 0.0;
    outfitWarmth = 0;
    seenTips.clear(); // le tuto rejoue
    introCinematicSeen = false; // la cinématique d'ouverture rejoue
    _lampOn = true;
    isNight = false;
    startCardRun(); // remet jauges + cardGareIndex=0 + VIDE cardFlags/oneshot/soin
    _recomputeAutoTemp();
  }

  /// Termine la run (atteinte d'une fin) : on efface la progression mais on
  /// garde les jauges figées pour l'écran de fin.
  void endCardRun() {
    cardGareIndex = null;
    save(checkpoint: true);
  }

  /// Applique des deltas aux 4 jauges, clampe 0-100, persiste.
  void applyCardDeltas(Map<String, int> deltas) {
    cardSoif = (cardSoif + (deltas['soif'] ?? 0)).clamp(0, statMax);
    cardFaim = (cardFaim + (deltas['faim'] ?? 0)).clamp(0, statMax);
    cardBois = (cardBois + (deltas['bois'] ?? 0)).clamp(0, statMax);
    cardMoral = (cardMoral + (deltas['moral'] ?? 0)).clamp(0, statMax);
    _recomputeAutoTemp(); // le bois alimente le feu -> impacte la température
    notifyListeners();
    save();
  }

  /// Nudge ponctuel d'une jauge depuis le wagon (manger, boire, bois).
  void nudgeCardStat(String stat, int delta) {
    switch (stat) {
      case 'soif':
        cardSoif = (cardSoif + delta).clamp(0, statMax);
      case 'faim':
        cardFaim = (cardFaim + delta).clamp(0, statMax);
      case 'bois':
        cardBois = (cardBois + delta).clamp(0, statMax);
        // Plus de bois -> poêle s'éteint tout seul (et la cabine refroidit).
        if (cardBois <= 0 && poeleOn) poeleOn = false;
        _recomputeAutoTemp(); // le bois alimente le feu -> impacte la chaleur
      case 'moral':
        // Le froid empêche de GAGNER du moral (on peut encore en perdre).
        if (delta > 0 && feltCold) delta = 0;
        cardMoral = (cardMoral + delta).clamp(0, statMax);
    }
    // Pas de save() direct ici : l'autosave débounced (via notifyListeners)
    // suffit. Évite 1 écriture disque complète par tick de decay/poêle/besoin.
    notifyListeners();
  }

  Map<String, dynamic> _cardsRunToJson() => {
        'soif': cardSoif,
        'faim': cardFaim,
        'bois': cardBois,
        'moral': cardMoral,
        'gareIndex': cardGareIndex,
        'flags': cardFlags.toList(),
        'seenOneshot': cardSeenOneshot.toList(),
        'soin': cardSoin,
        'credits': cardCredits,
        'creditNextMs': cardCreditNextMs,
        'elan': cardElan,
        'gareCine': cardGareCineSeen.toList(),
        'segProgress': cardSegmentProgress,
      };

  void _loadCardsRun(dynamic raw) {
    if (raw is! Map) return;
    final m = raw.cast<String, dynamic>();
    cardSoif = (m['soif'] as num?)?.toInt() ?? 70;
    cardFaim = (m['faim'] as num?)?.toInt() ?? 70;
    cardBois = (m['bois'] as num?)?.toInt() ?? 70;
    cardMoral = (m['moral'] as num?)?.toInt() ?? 70;
    cardGareIndex = (m['gareIndex'] as num?)?.toInt();
    cardFlags
      ..clear()
      ..addAll(((m['flags'] as List?) ?? const []).cast<String>());
    cardSeenOneshot
      ..clear()
      ..addAll(((m['seenOneshot'] as List?) ?? const []).cast<String>());
    cardSoin = (m['soin'] as num?)?.toInt() ?? 0;
    cardCredits = ((m['credits'] as num?)?.toInt() ?? cardCreditsMax)
        .clamp(0, cardCreditsMax);
    cardCreditNextMs = (m['creditNextMs'] as num?)?.toInt() ?? 0;
    cardElan = ((m['elan'] as num?)?.toInt() ?? cardElanMax).clamp(0, cardElanMax);
    cardGareCineSeen
      ..clear()
      ..add(0)
      ..addAll(((m['gareCine'] as List?) ?? const [])
          .map((e) => (e as num).toInt()));
    cardSegmentProgress =
        ((m['segProgress'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);
  }

  // --- Locations ---
  final Set<String> _unlocked = {'station_abandonnee'};

  bool isLocationUnlocked(String id) => _unlocked.contains(id);

  @override
  void dispose() {
    _weatherTimer?.cancel();
    super.dispose();
  }
}

enum Weather { clear, cloudy, rainy, foggy, snowy }

enum TrainZone { cold, warm, transitionToCold, transitionToWarm }
