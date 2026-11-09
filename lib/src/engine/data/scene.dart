enum SceneMode {
  vn("VN"),
  chat("CHAT"),
  call("CALL");

  final String key;

  const SceneMode(this.key);

  static SceneMode fromKey(String? key) => values.where((mode) => mode.key == key).firstOrNull ?? vn;
}

class Scene {
  final SceneMode mode;
  final String? background;
  final String? music;
  final String? channelId;
  final int? day;
  final String? time;

  const Scene({
    this.mode = SceneMode.vn,
    this.background,
    this.music,
    this.channelId,
    this.day,
    this.time,
  });

  factory Scene.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const Scene();
    return Scene(
      mode: SceneMode.fromKey(json["mode"] as String?),
      background: json["background"] as String?,
      music: json["music"] as String?,
      channelId: json["channel_id"] as String?,
      day: (json["day"] as num?)?.toInt(),
      time: json["time"] as String?,
    );
  }
}
