import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

/// Audio channels for a story: looping BGM, one-shot SFX and voice-over.
/// BGM keeps playing across scenes that use the same track, ducks while a
/// voice line plays, and follows the [AppLifecycleState]. [setVolumes] applies the player's volumes.
class AudioHelper with WidgetsBindingObserver {
  static const _bgmVolume = 0.6;
  static const _duckedVolume = 0.2;

  final AudioPlayer _bgm = createPlayer(holdsFocus: true);
  final AudioPlayer _sfx = createPlayer();
  final AudioPlayer _voice = createPlayer();

  String? _currentBgm;
  int _duckCount = 0;
  double _musicVolume = 1;
  double _soundVolume = 1;
  double _voiceVolume = 1;

  /// Volume for voice notes and videos, which use their own players.
  double get voiceVolume => _voiceVolume;

  double get _bgmLevel => (_duckCount > 0 ? _duckedVolume : _bgmVolume) * _musicVolume;

  /// Players resolve full asset paths (`assets/story/...`) instead of the default `assets/` prefix.
  ///
  /// Only the BGM player should hold Android audio focus. Any other player that requests it makes
  /// the BGM lose focus for good, and audioplayers pauses it without resuming. Those players mix in
  /// and rely on [duck] instead.
  static AudioPlayer createPlayer({bool holdsFocus = false}) {
    final player = AudioPlayer()..audioCache = AudioCache(prefix: "");
    if (!holdsFocus) {
      player.setAudioContext(AudioContext(android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.none)));
    }
    return player;
  }

  AudioHelper() {
    _voice.onPlayerComplete.listen((_) => unduck());
  }

  /// Channel volumes, `0.0` to `1.0`. Ducking lowers the music relative to [music].
  void setVolumes({required double music, required double sound, required double voice}) {
    _musicVolume = music;
    _soundVolume = sound;
    _voiceVolume = voice;
    _bgm.setVolume(_bgmLevel);
    _sfx.setVolume(sound);
    _voice.setVolume(voice);
  }

  void addObserver() {
    WidgetsBinding.instance.addObserver(this);
  }

  void removeObserver() {
    WidgetsBinding.instance.removeObserver(this);
    _bgm.dispose();
    _sfx.dispose();
    _voice.dispose();
  }

  /// Plays [path] on loop. Does nothing if the same track is already playing.
  Future<void> playBgm(String? path) async {
    if (path == _currentBgm) return;
    _currentBgm = path;
    await _bgm.stop();
    if (path == null) return;
    await _bgm.setReleaseMode(ReleaseMode.loop);
    await _safePlay(_bgm, path, _bgmLevel);
  }

  Future<void> playSfx(String path) => _safePlay(_sfx, path, _soundVolume);

  Future<void> playVoice(String path) async {
    await _voice.stop();
    duck();
    await _safePlay(_voice, path, _voiceVolume);
  }

  Future<void> stopVoice() async {
    if (_voice.state == PlayerState.playing) unduck();
    await _voice.stop();
  }

  /// Lowers the BGM while another channel (voice-over, voice note, video) is audible.
  void duck() {
    _duckCount++;
    _bgm.setVolume(_bgmLevel);
  }

  void unduck() {
    if (_duckCount == 0) return;
    _duckCount--;
    if (_duckCount == 0) _bgm.setVolume(_bgmLevel);
  }

  Future<void> stopAll() async {
    _currentBgm = null;
    _duckCount = 0;
    await Future.wait([_bgm.stop(), _sfx.stop(), _voice.stop()]);
  }

  Future<void> _safePlay(AudioPlayer player, String path, double volume) async {
    try {
      await player.play(AssetSource(path), volume: volume);
    } catch (error) {
      // Autoplay restrictions (web) or a missing file should not break the story.
      debugPrint("AudioHelper: can't play $path: $error");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_currentBgm != null) _bgm.resume();
    } else if (state == AppLifecycleState.paused) {
      _bgm.pause();
      _voice.pause();
    }
  }
}
