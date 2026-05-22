import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Centralised audio for Train Cosy. Plays best-effort: every method
/// catches errors so a missing or unsupported file silently no-ops
/// (e.g. when the audio assets haven't been dropped in yet).
///
/// Looped layers (ambient train, fire crackle in the cab) are kept on
/// their own players so they can fade independently. One-shot SFX
/// (footstep, log thud, door open) reuse a small pool of throwaway
/// players so several can overlap.
class AudioService {
  AudioService._();
  static final AudioService _instance = AudioService._();
  factory AudioService() => _instance;

  final AudioPlayer _ambient = AudioPlayer(playerId: 'ambient');
  final AudioPlayer _fire = AudioPlayer(playerId: 'fire');
  final AudioPlayer _music = AudioPlayer(playerId: 'music');
  bool _ambientOn = false;
  bool _fireOn = false;
  String? _currentMusic;
  bool _enabled = true;

  void disable() {
    _enabled = false;
    stopAll();
  }

  void enable() {
    _enabled = true;
  }

  Future<void> _safe(Future<void> Function() body) async {
    if (!_enabled) return;
    try {
      await body();
    } catch (e) {
      if (kDebugMode) {
        // Missing assets are expected during dev — just log once.
        // ignore: avoid_print
        print('[audio] $e');
      }
    }
  }

  /// Continuous train-rolling rumble. Started when the train is running,
  /// stopped when it halts. Idempotent.
  Future<void> startAmbientTrain() async {
    if (_ambientOn) return;
    _ambientOn = true;
    await _safe(() async {
      await _ambient.setReleaseMode(ReleaseMode.loop);
      await _ambient.setVolume(0.5);
      await _ambient.play(AssetSource('audio/ambient_train.mp3'));
    });
  }

  Future<void> stopAmbientTrain() async {
    if (!_ambientOn) return;
    _ambientOn = false;
    await _safe(() => _ambient.stop());
  }

  /// Fire crackle loop — plays in the locomotive cab.
  Future<void> startFire() async {
    if (_fireOn) return;
    _fireOn = true;
    await _safe(() async {
      await _fire.setReleaseMode(ReleaseMode.loop);
      await _fire.setVolume(0.6);
      await _fire.play(AssetSource('audio/fire_crackle.mp3'));
    });
  }

  Future<void> stopFire() async {
    if (!_fireOn) return;
    _fireOn = false;
    await _safe(() => _fire.stop());
  }

  /// Background music — call with 'day' or 'night' and the asset swap is
  /// handled transparently. Cross-fade not implemented yet; the simpler
  /// stop-and-restart works for the prototype.
  Future<void> setMusic(String mood) async {
    if (_currentMusic == mood) return;
    _currentMusic = mood;
    await _safe(() async {
      await _music.stop();
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(0.3);
      await _music.play(AssetSource('audio/music_$mood.mp3'));
    });
  }

  /// One-shot SFX with a transient player. Volume and pitch optional.
  Future<void> playSfx(String name, {double volume = 0.8}) async {
    if (!_enabled) return;
    final p = AudioPlayer();
    try {
      await p.setVolume(volume);
      await p.play(AssetSource('audio/sfx_$name.mp3'));
      // Auto-dispose when the clip finishes. Only register AFTER a
      // successful play(): registering before would leave a pending
      // .first listener that fires "Bad state: No element" when we
      // dispose the player in the catch path below. Errors on the
      // stream are swallowed so a torn-down player can't surface as
      // an unhandled exception.
      p.onPlayerComplete.first.then((_) => p.dispose()).catchError((_) {});
    } catch (e) {
      await p.dispose();
      if (kDebugMode) {
        // ignore: avoid_print
        print('[audio] sfx $name failed: $e');
      }
    }
  }

  Future<void> stopAll() async {
    _ambientOn = false;
    _fireOn = false;
    _currentMusic = null;
    await _safe(() async {
      await _ambient.stop();
      await _fire.stop();
      await _music.stop();
    });
  }
}
