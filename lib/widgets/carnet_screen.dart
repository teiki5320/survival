import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/cards_data.dart';
import '../models/game_state.dart';
import '../models/reigns_engine.dart';

/// CARNET DE VOYAGE — la collection VISIBLE des souvenirs vécus cette partie.
/// Ouvert depuis le carnet du salon (après l'anim de lecture). Chaque geste cosy
/// (dormir, bain, lire, radio, s'occuper de la sœur, regarder dehors) y épingle
/// une page. Le carnet se remplit au fil du voyage = résumé émotionnel du run.
/// Aucune stat : c'est la TRACE de ce que tu as vécu.
class CarnetScreen extends StatelessWidget {
  const CarnetScreen({super.key, required this.onClose});

  final VoidCallback onClose;

  // Emblème par ambiance de souvenir (réutilise l'enum CardArt).
  static String _emoji(CardArt art) {
    switch (art) {
      case CardArt.memory:
        return '📖';
      case CardArt.sister:
        return '👧';
      case CardArt.dog:
        return '🐶';
      case CardArt.water:
        return '💧';
      case CardArt.radio:
        return '📻';
      case CardArt.hope:
        return '🌅';
      case CardArt.fire:
        return '🔥';
      case CardArt.cold:
        return '❄️';
      case CardArt.food:
        return '🥫';
      case CardArt.refuge:
        return '🏠';
      default:
        return '🕮';
    }
  }

  @override
  Widget build(BuildContext context) {
    final souvenirs = collectedSouvenirs(GameState.instance.cardFlags);
    return Scaffold(
      body: Container(
        // Parchemin chaud (page de carnet).
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A2018), Color(0xFF1A130D)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Bandeau titre + fermer.
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: onClose,
                    ),
                    const Spacer(),
                    Text(
                      'Le carnet de Shen',
                      style: GoogleFonts.cinzel(
                        color: const Color(0xFFE8B96B),
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Text(
                souvenirs.isEmpty
                    ? ''
                    : '${souvenirs.length} souvenir${souvenirs.length > 1 ? 's' : ''} de voyage',
                style: const TextStyle(color: Color(0xFF9A876E), fontSize: 12),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: souvenirs.isEmpty
                    ? _empty()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        itemCount: souvenirs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (_, i) => _entry(souvenirs[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Text(
          "Ton carnet est encore vierge.\n\nOccupe-toi du train — dors, lave-toi, "
          "lis, écoute la radio, prends soin de ta sœur, regarde le monde "
          "défiler… Chaque moment laissera une page ici.",
          textAlign: TextAlign.center,
          style: GoogleFonts.lora(
              color: Colors.white54, fontSize: 15, height: 1.6),
        ),
      ),
    );
  }

  Widget _entry(StoryCard s) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7ECD4), Color(0xFFE7D0A4)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x55594025), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_emoji(s.art), style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              s.text,
              style: GoogleFonts.lora(
                color: const Color(0xFF42301B),
                fontSize: 14.5,
                height: 1.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
