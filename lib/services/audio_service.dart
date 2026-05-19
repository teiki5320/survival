import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../models/scene_config.dart';

/// Plays the train ambient loop, day/night background music, and one-shot
/// interaction SFX. Silently no-ops if the matching asset isn't shipped
/// yet — you can drop a real file into assets/audio/ later and it'll work
/// at the next build without code changes.
///
/// Expected files (all optional):
///   assets/audio/ambient_train.mp3
///   assets/audio/music_day.mp3
///   assets/audio/music_night.mp3
///   assets/audio/sfx_<object_id>.mp3   (e.g. sfx_bed.mp3, sfx_lamp.mp3,
///                                            sfx_stove.mp3, ...)
class AudioService {
  AudioService() {
    _ambient.setReleaseMode(ReleaseMode.loop);
    _music.setReleaseMode(ReleaseMode.loop);
  }

  final AudioPlayer _ambient = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  final AudioPlayer _sfx = AudioPlayer();

  bool _ambientEnabled = true;
  bool _musicEnabled = true;
  bool _sfxEnabled = true;

  double _ambientVolume = 0.35;
  double _musicVolume = 0.45;
  double _sfxVolume = 0.7;

  WagonTime? _activeMusicTime;
  bool _started = false;

  bool get isAmbientEnabled => _ambientEnabled;
  bool get isMusicEnabled => _musicEnabled;
  bool get isSfxEnabled => _sfxEnabled;
  double get ambientVolume => _ambientVolume;
  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;

  /// Boot the ambient loop and the music track for the current time of day.
  /// Idempotent.
  Future<void> start(WagonTime initialTime) async {
    if (_started) return;
    _started = true;
    await _startAmbient();
    await playMusicFor(initialTime);
  }

  Future<void> _startAmbient() async {
    if (!_ambientEnabled) return;
    await _tryPlay(_ambient, 'audio/ambient_train.mp3', _ambientVolume);
  }

  Future<void> setAmbientEnabled(bool v) async {
    _ambientEnabled = v;
    if (v) {
      await _startAmbient();
    } else {
      await _ambient.stop();
    }
  }

  Future<void> setMusicEnabled(bool v) async {
    _musicEnabled = v;
    if (v) {
      if (_activeMusicTime != null) await playMusicFor(_activeMusicTime!);
    } else {
      await _music.stop();
    }
  }

  Future<void> setSfxEnabled(bool v) async {
    _sfxEnabled = v;
  }

  Future<void> setAmbientVolume(double v) async {
    _ambientVolume = v.clamp(0.0, 1.0);
    await _ambient.setVolume(_ambientVolume);
  }

  Future<void> setMusicVolume(double v) async {
    _musicVolume = v.clamp(0.0, 1.0);
    await _music.setVolume(_musicVolume);
  }

  void setSfxVolume(double v) {
    _sfxVolume = v.clamp(0.0, 1.0);
  }

  /// Crossfade music tracks when the time of day changes.
  Future<void> playMusicFor(WagonTime time) async {
    _activeMusicTime = time;
    if (!_musicEnabled) return;
    final asset = time == WagonTime.day
        ? 'audio/music_day.mp3'
        : 'audio/music_night.mp3';
    await _tryPlay(_music, asset, _musicVolume);
  }

  /// One-shot SFX for an object interaction. Resolves the asset path from
  /// the object id (e.g. "bed" -> assets/audio/sfx_bed.mp3).
  Future<void> playSfxForObject(String objectId) async {
    if (!_sfxEnabled) return;
    await _tryPlay(_sfx, 'audio/sfx_$objectId.mp3', _sfxVolume);
  }

  /// Dispose all underlying players.
  Future<void> dispose() async {
    await _ambient.dispose();
    await _music.dispose();
    await _sfx.dispose();
  }

  /// Play [asset] on [player] at [volume]. Swallows errors so a missing
  /// asset doesn't crash the app — it just stays silent until the file
  /// is added.
  Future<void> _tryPlay(AudioPlayer player, String asset, double volume) async {
    try {
      await player.stop();
      await player.setVolume(volume);
      await player.play(AssetSource(asset));
    } catch (e) {
      // Asset missing or platform unsupported — silent no-op.
      if (kDebugMode) {
        debugPrint('[AudioService] could not play $asset: $e');
      }
    }
  }
}
