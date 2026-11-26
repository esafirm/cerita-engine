import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

/// Audio channels for a story: looping BGM and ambience, overlapping SFX and voice-over.
/// BGM keeps playing across scenes that use the same track, fades between tracks, ducks while a
/// voice line plays, and follows the [AppLifecycleState]. [setVolumes] applies the player's volumes.
class AudioHelper with WidgetsBindingObserver {
  static const _bgmVolume = 0.6;
  static const _duckedVolume = 0.2;
  static const _ambienceVolume = 0.5;

  /// Fade of a music or ambience change that sets no `fade_ms`.
  static const defaultFadeMs = 1000;

  /// Sound effects take turns on these, so a few can overlap.
  static const _sfxPlayers = 3;

  final AudioPlayer _bgm = createPlayer(holdsFocus: true);
  final AudioPlayer _ambience = createPlayer();
  final List<AudioPlayer> _sfx = [for (var i = 0; i < _sfxPlayers; i++) createPlayer()];
  final AudioPlayer _voice = createPlayer();

  /// An incoming call's ringtone, on loop until it is answered or declined.
  final AudioPlayer _ring = createPlayer()..setReleaseMode(ReleaseMode.loop);
  bool _ringing = false;

  late final _bgmChannel = _LoopChannel(_bgm, () => _bgmLevel);
  late final _ambienceChannel = _LoopChannel(_ambience, () => _ambienceVolume * _soundVolume);

  int _nextSfx = 0;
  int _duckCount = 0;
  bool _voiceDucked = false;
  int _voiceGeneration = 0;
  bool _disposed = false;
  late final StreamSubscription<void> _voiceComplete;
  double _musicVolume = 1;
  double _soundVolume = 1;
  double _voiceVolume = 1;

  /// Character volume of the voice line playing, on top of [voiceVolume].
  double _voiceCharacter = 1;

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
    _voiceComplete = _voice.onPlayerComplete.listen((_) => _unduckVoice());
  }

  void _unduckVoice() {
    if (!_voiceDucked) return;
    _voiceDucked = false;
    unduck();
  }

  /// Channel volumes, `0.0` to `1.0`. Ducking lowers the music relative to [music]. Ambience follows [sound].
  void setVolumes({required double music, required double sound, required double voice}) {
    if (_disposed) return;
    _musicVolume = music;
    _soundVolume = sound;
    _voiceVolume = voice;
    _bgmChannel.applyVolume();
    _ambienceChannel.applyVolume();
    for (final player in _sfx) {
      player.setVolume(sound);
    }
    _ring.setVolume(sound);
    _voice.setVolume(voice * _voiceCharacter);
  }

  void addObserver() {
    WidgetsBinding.instance.addObserver(this);
  }

  void removeObserver() {
    if (_disposed) return;
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _voiceComplete.cancel();
    _bgmChannel.cancel();
    _ambienceChannel.cancel();
    for (final player in [_bgm, _ambience, ..._sfx, _voice, _ring]) {
      player.dispose();
    }
  }

  /// Plays [path] on loop, fading out the old track and in the new one over [fadeMs] ([defaultFadeMs]
  /// when null, 0 cuts). Does nothing if the same track is already playing. Null stops the music.
  Future<void> playBgm(String? path, {int? fadeMs}) {
    if (_disposed) return Future.value();
    return _bgmChannel.play(path, fadeMs ?? defaultFadeMs);
  }

  /// Plays a looping background sound under the music, faded like [playBgm]. Null stops it.
  Future<void> playAmbience(String? path, {int? fadeMs}) {
    if (_disposed) return Future.value();
    return _ambienceChannel.play(path, fadeMs ?? defaultFadeMs);
  }

  Future<void> playSfx(String path) {
    if (_disposed) return Future.value();
    final player = _sfx[_nextSfx];
    _nextSfx = (_nextSfx + 1) % _sfx.length;
    return _safePlay(player, path, _soundVolume);
  }

  /// Plays a voice line at the voice volume times [character], the speaker's own volume.
  Future<void> playVoice(String path, {double character = 1}) async {
    if (_disposed) return;
    final generation = ++_voiceGeneration;
    await _stopVoiceInternal();
    if (_disposed || generation != _voiceGeneration) return;
    _voiceCharacter = character;
    if (!_voiceDucked) {
      _voiceDucked = true;
      duck();
    }
    final ok = await _safePlay(_voice, path, _voiceVolume * character);
    if (!ok && generation == _voiceGeneration) _unduckVoice();
  }

  Future<void> _stopVoiceInternal() async {
    _unduckVoice();
    if (_disposed) return;
    await _voice.stop();
  }

  Future<void> stopVoice() async {
    _voiceGeneration++;
    await _stopVoiceInternal();
  }

  /// Rings [path] on loop at the sound volume until [stopRing].
  Future<void> startRing(String path) {
    if (_disposed) return Future.value();
    _ringing = true;
    return _safePlay(_ring, path, _soundVolume);
  }

  Future<void> stopRing() {
    _ringing = false;
    if (_disposed) return Future.value();
    return _ring.stop();
  }

  /// Lowers the BGM while another channel (voice-over, voice note, video) is audible.
  void duck() {
    if (_disposed) return;
    _duckCount++;
    _bgmChannel.applyVolume();
  }

  void unduck() {
    if (_disposed || _duckCount == 0) return;
    _duckCount--;
    if (_duckCount == 0) _bgmChannel.applyVolume();
  }

  Future<void> stopAll() async {
    if (_disposed) return;
    _voiceGeneration++;
    _duckCount = 0;
    _voiceDucked = false;
    _ringing = false;
    await Future.wait([
      _bgmChannel.stopNow(),
      _ambienceChannel.stopNow(),
      for (final player in _sfx) player.stop(),
      _voice.stop(),
      _ring.stop(),
    ]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    if (state == AppLifecycleState.resumed) {
      _bgmChannel.resume();
      _ambienceChannel.resume();
      if (_ringing) _ring.resume();
    } else if (state == AppLifecycleState.paused) {
      _bgm.pause();
      _ambience.pause();
      _voice.pause();
      _ring.pause();
    }
  }
}

Future<bool> _safePlay(AudioPlayer player, String path, double volume) async {
  try {
    await player.play(AssetSource(path), volume: volume);
    return true;
  } catch (error) {
    // Autoplay restrictions (web) or a missing file should not break the story.
    debugPrint("AudioHelper: can't play $path: $error");
    return false;
  }
}

/// A looping track that fades out the old file and in the new one.
class _LoopChannel {
  static const _step = Duration(milliseconds: 50);

  final AudioPlayer player;

  /// Full volume of the channel, read on every step so volume changes and ducking apply mid-fade.
  final double Function() level;

  String? _current;

  /// 0 to 1 during a fade, multiplies [level].
  double _gain = 1;

  /// Bumped by every change, so a newer change stops an older fade.
  int _generation = 0;
  Timer? _timer;
  Completer<void>? _fading;

  _LoopChannel(this.player, this.level);

  void applyVolume() => player.setVolume(level() * _gain);

  Future<void> play(String? path, int fadeMs) async {
    if (path == _current) return;
    _stopFade();
    final wasPlaying = _current != null;
    _current = path;
    final generation = ++_generation;
    // Half the fade goes out, half comes in.
    final half = Duration(milliseconds: fadeMs ~/ 2);

    if (wasPlaying && half > Duration.zero) {
      await _fade(to: 0, over: half);
      if (generation != _generation) return;
    }
    await player.stop();
    if (path == null || generation != _generation) return;
    await player.setReleaseMode(ReleaseMode.loop);
    _gain = half > Duration.zero ? 0 : 1;
    final ok = await _safePlay(player, path, level() * _gain);
    if (!ok) {
      if (generation == _generation) _current = null;
      return;
    }
    if (generation != _generation || half == Duration.zero) return;
    await _fade(to: 1, over: half);
  }

  Future<void> _fade({required double to, required Duration over}) {
    _stopFade();
    final done = _fading = Completer<void>();
    final from = _gain;
    final steps = (over.inMilliseconds / _step.inMilliseconds).ceil().clamp(1, 1000);
    var step = 0;
    _timer = Timer.periodic(_step, (timer) {
      step++;
      _gain = from + (to - from) * (step / steps);
      applyVolume();
      if (step >= steps) {
        timer.cancel();
        done.complete();
      }
    });
    return done.future;
  }

  /// Stops a running fade at its current volume. Its caller sees a newer generation and gives up.
  void _stopFade() {
    _timer?.cancel();
    if (_fading case final fading? when !fading.isCompleted) fading.complete();
  }

  void cancel() {
    _generation++;
    _stopFade();
  }

  /// Stops the channel immediately, including any fade-out already in progress.
  Future<void> stopNow() {
    _current = null;
    _generation++;
    _stopFade();
    return player.stop();
  }

  void resume() {
    if (_current != null) player.resume();
  }
}
