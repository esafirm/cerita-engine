/// Player preferences. Kept apart from saves and the meta-state, so resetting progress keeps them.
class PlayerSettings {
  /// Typewriter speed. 0 shows lines at once.
  final int textMsPerChar;

  /// Auto mode pause after a line. The per-character reading time scales with it.
  final int autoDelayMs;

  /// Skip mode also fast-forwards lines never seen before.
  final bool skipUnread;

  /// How long chat and call messages type, as a share of the story's own typing time. 1 is the author's pace,
  /// 0 is instant. Never above 1, so players can only speed chats up (CE-04 D2).
  final double chatPacing;

  final double musicVolume;
  final double soundVolume;
  final double voiceVolume;

  /// Voice volume of single characters by profile id, on top of [voiceVolume]. Missing ones play at 1.
  final Map<String, double> voiceVolumes;

  /// The player's language, a story locale code. Null until the player or the device picks one.
  final String? locale;

  /// Shows the developer panel in the in-game menu, in any build. Turned on from the admin sheet, for testers.
  final bool developerTools;

  const PlayerSettings({
    this.textMsPerChar = 40,
    this.autoDelayMs = 1200,
    this.skipUnread = false,
    double chatPacing = 1,
    this.musicVolume = 1,
    this.soundVolume = 1,
    this.voiceVolume = 1,
    this.voiceVolumes = const {},
    this.locale,
    this.developerTools = false,
  }) : chatPacing = chatPacing < 0 ? 0 : (chatPacing > 1 ? 1 : chatPacing);

  /// Voice volume of the character [profileId].
  double voiceVolumeOf(String? profileId) => voiceVolume * (voiceVolumes[profileId] ?? 1);

  /// Reading time of [characters] in auto mode.
  int autoDelayFor(int characters) => autoDelayMs + characters * autoDelayMs * 45 ~/ 1200;

  /// The typing time of a chat message the story types for [ms].
  int chatTypingFor(int ms) => (ms * chatPacing).round();

  PlayerSettings copyWith({
    int? textMsPerChar,
    int? autoDelayMs,
    bool? skipUnread,
    double? chatPacing,
    double? musicVolume,
    double? soundVolume,
    double? voiceVolume,
    Map<String, double>? voiceVolumes,
    String? locale,
    bool? developerTools,
  }) =>
      PlayerSettings(
        textMsPerChar: textMsPerChar ?? this.textMsPerChar,
        autoDelayMs: autoDelayMs ?? this.autoDelayMs,
        skipUnread: skipUnread ?? this.skipUnread,
        chatPacing: chatPacing ?? this.chatPacing,
        musicVolume: musicVolume ?? this.musicVolume,
        soundVolume: soundVolume ?? this.soundVolume,
        voiceVolume: voiceVolume ?? this.voiceVolume,
        voiceVolumes: voiceVolumes ?? this.voiceVolumes,
        locale: locale ?? this.locale,
        developerTools: developerTools ?? this.developerTools,
      );

  factory PlayerSettings.fromJson(Map<String, dynamic> json) {
    const defaults = PlayerSettings();
    double clamp(Object? value, double fallback) => ((value as num?)?.toDouble() ?? fallback).clamp(0.0, 1.0);
    double volume(String key, double fallback) => clamp(json[key], fallback);
    return PlayerSettings(
      textMsPerChar: (json["text_ms_per_char"] as num?)?.toInt() ?? defaults.textMsPerChar,
      autoDelayMs: (json["auto_delay_ms"] as num?)?.toInt() ?? defaults.autoDelayMs,
      skipUnread: json["skip_unread"] as bool? ?? defaults.skipUnread,
      chatPacing: (json["chat_pacing"] as num?)?.toDouble() ?? defaults.chatPacing,
      musicVolume: volume("music_volume", defaults.musicVolume),
      soundVolume: volume("sound_volume", defaults.soundVolume),
      voiceVolume: volume("voice_volume", defaults.voiceVolume),
      voiceVolumes: {
        for (final MapEntry(:key, :value) in Map<String, dynamic>.from(json["voice_volumes"] as Map? ?? const {}).entries)
          key: clamp(value, 1),
      },
      locale: json["locale"] as String?,
      developerTools: json["developer_tools"] as bool? ?? defaults.developerTools,
    );
  }

  Map<String, dynamic> toJson() => {
        "text_ms_per_char": textMsPerChar,
        "auto_delay_ms": autoDelayMs,
        "skip_unread": skipUnread,
        "chat_pacing": chatPacing,
        "music_volume": musicVolume,
        "sound_volume": soundVolume,
        "voice_volume": voiceVolume,
        if (voiceVolumes.isNotEmpty) "voice_volumes": voiceVolumes,
        if (locale != null) "locale": locale,
        if (developerTools) "developer_tools": true,
      };

  @override
  bool operator ==(Object other) =>
      other is PlayerSettings &&
      other.textMsPerChar == textMsPerChar &&
      other.autoDelayMs == autoDelayMs &&
      other.skipUnread == skipUnread &&
      other.chatPacing == chatPacing &&
      other.musicVolume == musicVolume &&
      other.soundVolume == soundVolume &&
      other.voiceVolume == voiceVolume &&
      other.locale == locale &&
      other.developerTools == developerTools &&
      _sameVolumes(other.voiceVolumes, voiceVolumes);

  static bool _sameVolumes(Map<String, double> a, Map<String, double> b) =>
      a.length == b.length && a.entries.every((entry) => b[entry.key] == entry.value);

  @override
  int get hashCode => Object.hash(
        textMsPerChar,
        autoDelayMs,
        skipUnread,
        chatPacing,
        musicVolume,
        soundVolume,
        voiceVolume,
        locale,
        developerTools,
        Object.hashAllUnordered(voiceVolumes.entries.map((entry) => Object.hash(entry.key, entry.value))),
      );
}
