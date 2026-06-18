import 'package:flutter/material.dart';

import '../models/game_state.dart';

/// Boutique CONFORT (IAP). Règle d'or du projet : l'argent réel ne doit JAMAIS
/// bloquer l'histoire — on ne vend que du CONFORT (réconfort, petits coups de
/// pouce non létaux, cosmétique). Aucune jauge de survie ni fin n'est gated.
///
/// ⚠️ Le VRAI paiement n'est pas branché ici : il faut le package
/// `in_app_purchase` + des produits déclarés sur App Store Connect (côté toi).
/// Ce fichier fournit la boutique complète (UI + effets) ; le bouton « Acheter »
/// passe par [_purchase] qui est le SEUL point à câbler sur le store le jour J.
/// En mode debug, l'achat est accordé gratuitement pour tester les effets.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopItem {
  const _ShopItem({
    required this.id,
    required this.storeId,
    required this.emoji,
    required this.title,
    required this.desc,
    required this.price,
    required this.apply,
  });
  final String id;

  /// Identifiant produit App Store Connect (à créer côté store). C'est la SEULE
  /// chose à renseigner pour brancher le vrai paiement (voir [_purchase]).
  final String storeId;
  final String emoji;
  final String title;
  final String desc;
  final String price; // libellé prix (le vrai prix viendra du store)
  final void Function(GameState gs) apply;
}

class _ShopScreenState extends State<ShopScreen> {
  // Catalogue CONFORT uniquement. Rien ici n'est nécessaire pour finir le jeu.
  // Les `storeId` sont les produits à déclarer sur App Store Connect.
  static final List<_ShopItem> _items = [
    _ShopItem(
      id: 'comfort_pack',
      storeId: 'com.teiki5320.trainCosy.comfort_pack',
      emoji: '🧺',
      title: 'Colis de réconfort',
      desc: "Un petit colis trouvé en gare : Shen est reposée et propre, "
          "le cœur un peu plus léger.",
      price: '0,99 €',
      apply: (gs) {
        gs.restoreSleep();
        gs.restoreHygiene();
        gs.nudgeCardStat('moral', 10);
      },
    ),
    _ShopItem(
      id: 'warm_plaid',
      storeId: 'com.teiki5320.trainCosy.warm_plaid',
      emoji: '🧣',
      title: 'Plaid chaud',
      desc: "Une couverture épaisse pour le grand nord. Réchauffe durablement "
          "la cabine (tenue plus chaude).",
      price: '1,99 €',
      apply: (gs) {
        if (gs.outfitWarmth < 8) gs.outfitWarmth = 8;
      },
    ),
    _ShopItem(
      id: 'tip_jar',
      storeId: 'com.teiki5320.trainCosy.tip_jar',
      emoji: '☕',
      title: 'Offrir un café au dev',
      desc: "Aucun effet en jeu — juste un grand merci, et de quoi tenir une "
          "nuit de code de plus.",
      price: '2,99 €',
      apply: (_) {},
    ),
  ];

  // === BRANCHEMENT DU VRAI PAIEMENT (à faire plus tard) =====================
  // 1) Ajouter `in_app_purchase: ^3.x` dans pubspec.yaml.
  // 2) Créer les produits (les `storeId` ci-dessus) sur App Store Connect.
  // 3) Au démarrage de l'écran : interroger le store une fois.
  //      final resp = await InAppPurchase.instance
  //          .queryProductDetails(_items.map((e) => e.storeId).toSet());
  //      // -> remplir les prix réels affichés (resp.productDetails[i].price).
  // 4) Écouter `InAppPurchase.instance.purchaseStream` ; sur `purchased`,
  //    appeler la livraison (item.apply + save) puis `completePurchase`.
  // 5) Dans [_purchase], lancer l'achat :
  //      InAppPurchase.instance.buyConsumable(
  //          purchaseParam: PurchaseParam(productDetails: pd));
  //    (warm_plaid = non-consommable -> buyNonConsumable + restore.)
  // Tant que ce n'est pas branché : debug = accordé gratuitement (test),
  // release = dialog "bientôt". Le `apply` (la LIVRAISON) est déjà écrit.
  // ==========================================================================

  /// SEUL point à brancher sur le vrai store. Pour l'instant : debug = accordé
  /// gratuitement (test) ; release = message « bientôt ».
  Future<void> _purchase(_ShopItem item) async {
    if (GameState.instance.debugMode) {
      item.apply(GameState.instance);
      GameState.instance.save();
      _toast("« ${item.title} » accordé (debug).");
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2018),
        title: Text(item.title,
            style: const TextStyle(color: Color(0xFFE8B96B))),
        content: const Text(
          "Les achats arriveront avec la sortie sur l'App Store. "
          "Le confort acheté ne débloque jamais l'histoire — seulement de "
          "petits plus douillets.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (ok == true) item.apply(GameState.instance);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE8B96B);
    return Scaffold(
      backgroundColor: const Color(0xFF1A140E),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  const Text('Boutique confort',
                      style: TextStyle(
                          color: gold,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                "Rien ici n'est nécessaire pour finir le voyage. Juste du douillet.",
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _itemTile(_items[i], gold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemTile(_ShopItem item, Color gold) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF26201A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gold.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Text(item.emoji, style: const TextStyle(fontSize: 34)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(item.desc,
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 12.5, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () => _purchase(item),
            style: ElevatedButton.styleFrom(
              backgroundColor: gold,
              foregroundColor: const Color(0xFF1A140E),
            ),
            child: Text(item.price),
          ),
        ],
      ),
    );
  }
}
