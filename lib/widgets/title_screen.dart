import 'dart:io';

import 'package:flutter/material.dart';

import '../models/game_state.dart';

/// Écran d'accueil. Affiche le fond title_bg.png + titre + 2 boutons.
class TitleScreen extends StatefulWidget {
  const TitleScreen({
    super.key,
    required this.onStart,
  });
  final void Function({required bool fromScratch}) onStart;

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeIn;
  bool _hasSave = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _fadeIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _checkSave();
  }

  Future<void> _checkSave() async {
    try {
      final docs = Directory('${Platform.environment['HOME'] ?? ''}/Documents');
      final path = '${docs.path}/train_cosy_save.json';
      final exists = await File(path).exists();
      if (!mounted) return;
      setState(() {
        _hasSave = exists;
        _checking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _checking = false);
    }
  }

  Future<void> _newGame() async {
    try {
      final docs =
          Directory('${Platform.environment['HOME'] ?? ''}/Documents');
      final path = '${docs.path}/train_cosy_save.json';
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
    await GameState.instance.load();
    if (!mounted) return;
    widget.onStart(fromScratch: true);
  }

  @override
  void dispose() {
    _fadeIn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1218),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fond.
          Image.asset(
            'assets/background/title_bg.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const ColoredBox(color: Color(0xFF0A1218)),
          ),
          // Voile sombre subtil pour assurer le contraste du texte.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66000000),
                  Color(0x00000000),
                  Color(0x88000000),
                ],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
            child: SizedBox.expand(),
          ),
          // Fade-in global.
          FadeTransition(
            opacity: _fadeIn,
            child: SafeArea(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.vertical,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Titre.
                        const Column(
                          children: [
                            Text(
                              'Train Cosy',
                              style: TextStyle(
                                fontSize: 56,
                                fontWeight: FontWeight.w300,
                                letterSpacing: 8,
                                color: Color(0xFFFFD9A0),
                                shadows: [
                                  Shadow(
                                    color: Colors.black,
                                    blurRadius: 20,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Un voyage dans le monde mort',
                              style: TextStyle(
                                fontSize: 14,
                                letterSpacing: 4,
                                color: Color(0xFFB8945C),
                                shadows: [
                                  Shadow(
                                    color: Colors.black,
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                        // Boutons.
                        if (_checking)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                  Color(0xFFB8945C)),
                            ),
                          )
                        else
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_hasSave)
                                _MenuButton(
                                  label: 'Continuer',
                                  bg: const Color(0xFFB85522),
                                  onPressed: () =>
                                      widget.onStart(fromScratch: false),
                                ),
                              if (_hasSave) const SizedBox(height: 14),
                              // Toujours présent, couleur pleine distincte =
                              // impossible à manquer.
                              _MenuButton(
                                label: _hasSave
                                    ? 'Nouvelle partie'
                                    : 'Commencer',
                                bg: const Color(0xFF2F6E54),
                                onPressed: _newGame,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.onPressed,
    required this.bg,
  });
  final String label;
  final VoidCallback onPressed;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 18, letterSpacing: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
