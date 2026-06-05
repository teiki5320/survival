// Écran "Atelier & Quotidien", ouvert depuis la MAP (qui sert de menu).
//
// Rassemble la méta-progression hors-combat : dépenser la ferraille à
// l'atelier, ouvrir le coffre du jour, réclamer les missions journalières,
// et voir la collection d'étoiles des 14 gares. Le combat, lui, se lance en
// tapant une gare sur la map.

import 'package:flutter/material.dart';

import '../models/game_state.dart';

class WorkshopScreen extends StatefulWidget {
  const WorkshopScreen({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  State<WorkshopScreen> createState() => _WorkshopScreenState();
}

class _WorkshopScreenState extends State<WorkshopScreen> {
  static const _gold = Color(0xFFE8B96B);
  static const _cream = Color(0xFFFFD9A0);

  @override
  Widget build(BuildContext context) {
    final gs = GameState.instance;
    return Scaffold(
      backgroundColor: const Color(0xFF1A1410),
      body: SafeArea(
        child: Column(
          children: [
            // Barre du haut : titre + ferraille + fermer.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 12, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: widget.onClose,
                  ),
                  const Spacer(),
                  const Text('Atelier & Quotidien',
                      style: TextStyle(
                          color: _cream,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _gold.withValues(alpha: 0.4)),
                    ),
                    child: Text('🔩 ${gs.scrap}',
                        style: const TextStyle(
                            color: _cream,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _sectionTitle('Quotidien'),
                    _dailyChest(gs),
                    const SizedBox(height: 10),
                    for (final id in GameState.dailyMissions.keys)
                      _missionRow(gs, id),
                    const SizedBox(height: 22),
                    _sectionTitle('Atelier'),
                    for (final key in GameState.shootShopDefs.keys)
                      _shopRow(gs, key),
                    const SizedBox(height: 22),
                    _sectionTitle('Gares — ⭐ ${gs.totalGareStars} / 42'),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [for (int i = 0; i < 14; i++) _gareCell(gs, i)],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t,
            style: const TextStyle(
                color: _cream, fontSize: 20, fontWeight: FontWeight.w800)),
      );

  Widget _dailyChest(GameState gs) {
    final avail = gs.dailyChestAvailable;
    return GestureDetector(
      onTap: avail
          ? () {
              gs.claimDailyChest();
              setState(() {});
            }
          : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: avail ? const Color(0xFF3E7A4E) : const Color(0xFF2A2018),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _gold, width: 1.2),
        ),
        child: Text(
          avail
              ? '🎁 Coffre du jour — toucher pour ouvrir !'
              : '🎁 Coffre déjà ouvert (reviens demain)',
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }

  Widget _missionRow(GameState gs, String id) {
    final m = GameState.dailyMissions[id]!;
    final prog = gs.dailyProgress(id).clamp(0, m.$2);
    final ready = gs.dailyReady(id);
    final claimed = gs.dailyClaimed.contains(id);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2018),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.$1,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
                Text('$prog / ${m.$2}   •   🔩${m.$3}',
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          if (claimed)
            const Icon(Icons.check_circle, color: Color(0xFF7FB86A), size: 22)
          else if (ready)
            GestureDetector(
              onTap: () {
                gs.claimDailyMission(id);
                setState(() {});
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3E7A4E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Réclamer',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _shopRow(GameState gs, String key) {
    final def = GameState.shootShopDefs[key]!;
    final lvl = gs.shootUpgrades[key] ?? 0;
    final maxed = lvl >= def.$3.length;
    final cost = maxed ? 0 : def.$3[lvl];
    final canBuy = !maxed && gs.scrap >= cost;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2018),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x55E8B96B)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${def.$1}  (niv $lvl${maxed ? ' max' : ''})',
                    style: const TextStyle(
                        color: _cream,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                Text(def.$2,
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed:
                canBuy ? () => setState(() => gs.buyShootUpgrade(key)) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: const Color(0xFF2A2018),
              disabledBackgroundColor: Colors.white12,
            ),
            child: Text(maxed ? 'MAX' : '🔩$cost'),
          ),
        ],
      ),
    );
  }

  Widget _gareCell(GameState gs, int i) {
    final stars = gs.gareStars(i);
    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2018),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: stars > 0 ? _gold : Colors.white12, width: 1),
      ),
      child: Column(
        children: [
          Text('G${i + 1}',
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          Text(stars > 0 ? '⭐' * stars : '·',
              style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
