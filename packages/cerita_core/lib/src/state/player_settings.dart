/// Player preferences. Kept apart from saves and the meta-state, so resetting progress keeps them.
class PlayerSettings {
  /// Typewriter speed. 0 shows lines at once.
  final int textMsPerChar;

  /// Auto mode pause after a line. The per-character reading time scales with it.
  final int autoDelayMs;

  /// Skip mode also fast-forwards lines never seen before.
  final bool skipUnread;

  final double musicVolume;
  final double soundVolume;
  final double voiceVolume;

  const PlayerSettings({
    this.textMsPerChar = 40,
    this.autoDelayMs = 1200,
    this.skipUnread = false,
    this.musicVolume = 1,
    this.soundVolume = 1,
    this.voiceVolume = 1,
  });

  /// Reading time of [characters] in auto mode.
  int autoDelayFor(int characters) => autoDelayMs + characters * autoDelayMs * 45 ~/ 1200;

  PlayerSettings copyWith({
    int? textMsPerChar,
    int? autoDelayMs,
    bool? skipUnread,
    double? musicVolume,
    double? soundVolume,
    double? voiceVolume,
  }) =>
      PlayerSettings(
        textMsPerChar: textMsPerChar ?? this.textMsPerChar,
        autoDelayMs: autoDelayMs ?? this.autoDelayMs,
        skipUnread: skipUnread ?? this.skipUnread,
        musicVolume: musicVolume ?? this.musicVolume,
        soundVolume: soundVolume ?? this.soundVolume,
        voiceVolume: voiceVolume ?? this.voiceVolume,
      );

  factory PlayerSettings.fromJson(Map<String, dynamic> json) {
    const defaults = PlayerSettings();
    double volume(String key, double fallback) => ((json[key] as num?)?.toDouble() ?? fallback).clamp(0.0, 1.0);
    return PlayerSettings(
      textMsPerChar: (json["text_ms_per_char"] as num?)?.toInt() ?? defaults.textMsPerChar,
      autoDelayMs: (json["auto_delay_ms"] as num?)?.toInt() ?? defaults.autoDelayMs,
      skipUnread: json["skip_unread"] as bool? ?? defaults.skipUnread,
      musicVolume: volume("music_volume", defaults.musicVolume),
      soundVolume: volume("sound_volume", defaults.soundVolume),
      voiceVolume: volume("voice_volume", defaults.voiceVolume),
    );
  }

  Map<String, dynamic> toJson() => {
        "text_ms_per_char": textMsPerChar,
        "auto_delay_ms": autoDelayMs,
        "skip_unread": skipUnread,
        "music_volume": musicVolume,
        "sound_volume": soundVolume,
        "voice_volume": voiceVolume,
      };

  @override
  bool operator ==(Object other) =>
      other is PlayerSettings &&
      other.textMsPerChar == textMsPerChar &&
      other.autoDelayMs == autoDelayMs &&
      other.skipUnread == skipUnread &&
      other.musicVolume == musicVolume &&
      other.soundVolume == soundVolume &&
      other.voiceVolume == voiceVolume;

  @override
  int get hashCode => Object.hash(textMsPerChar, autoDelayMs, skipUnread, musicVolume, soundVolume, voiceVolume);
}
