import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Service de gestion des effets sonores signatures BeachMatch (Impact raquette, etc.)
class SoundService {
  static final AudioPlayer _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  /// Joue le son sec et dynamique d'un impact de balle sur une raquette de beach tennis ("POC !")
  static Future<void> playRacketPop() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/beach_hit.wav'), volume: 0.7);
    } catch (e) {
      if (kDebugMode) {
        print('SoundService: error playing sound: $e');
      }
    }
  }
}
