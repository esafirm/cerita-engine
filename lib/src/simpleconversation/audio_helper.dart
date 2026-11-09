import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

/// Helper class to handle background music in the widget
/// It automatically stop the last sound and it also
/// react to [AppLifecycleState]
class AudioHelper with WidgetsBindingObserver {
  final AudioPlayer _audioPlayer = AudioPlayer();

  void addObserver() {
    WidgetsBinding.instance.addObserver(this);
  }

  void removeObserver() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
  }

  Future<void> play(String audioFile) async {
    await _audioPlayer.stop();
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource(audioFile));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _audioPlayer.resume();
    } else if (state == AppLifecycleState.paused) {
      _audioPlayer.pause();
    }
  }
}

