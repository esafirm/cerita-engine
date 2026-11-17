import 'package:cerita_core/src/l10n/localized_text.dart';

enum SceneMode {
  vn("VN"),
  chat("CHAT"),
  call("CALL");

  final String key;

  const SceneMode(this.key);

  static SceneMode fromKey(String? key) => values.where((mode) => mode.key == key).firstOrNull ?? vn;
}

/// How VN lines are shown: one at a time in the dialogue box, or as a full-screen page.
enum TextboxStyle {
  adv,
  nvl;

  static TextboxStyle? fromName(String? name) => values.where((style) => style.name == name).firstOrNull;
}

class Scene {
  final SceneMode mode;
  final String? background;
  final String? music;

  /// Looping background sound under the music.
  final String? ambience;

  /// `CALL` scenes: the call is incoming and rings with this sound until the player answers it.
  final String? ring;

  /// `CALL` scenes: where the story goes when the player declines or hangs up. Without it the call can't be ended,
  /// and trying to shows [stay].
  final String? hangUp;

  /// `CALL` scenes without [hangUp]: what the player's character thinks when they try to end the call. Null uses
  /// the engine's own line.
  final LocalizedText? stay;

  final TextboxStyle textbox;
  final String? channelId;
  final int? day;
  final String? time;

  /// The chat header's status for this scene, in place of the channel's (`"status"` in JSON). Null keeps the
  /// channel's status. Empty text hides it, which `"status": null` and `""` in JSON give.
  final LocalizedText? status;

  const Scene({
    this.mode = SceneMode.vn,
    this.background,
    this.music,
    this.ambience,
    this.ring,
    this.hangUp,
    this.stay,
    this.textbox = TextboxStyle.adv,
    this.channelId,
    this.day,
    this.time,
    this.status,
  });

  factory Scene.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const Scene();
    return Scene(
      mode: SceneMode.fromKey(json["mode"] as String?),
      background: json["background"] as String?,
      music: json["music"] as String?,
      ambience: json["ambience"] as String?,
      ring: json["ring"] as String?,
      hangUp: json["hangup"] as String?,
      stay: LocalizedText.fromJson(json["stay"]),
      textbox: TextboxStyle.fromName(json["textbox"] as String?) ?? TextboxStyle.adv,
      channelId: json["channel_id"] as String?,
      day: (json["day"] as num?)?.toInt(),
      time: json["time"] as String?,
      status: json.containsKey("status") ? LocalizedText.fromJson(json["status"]) ?? const LocalizedText("") : null,
    );
  }

  Map<String, dynamic> toJson() => {
        "mode": mode.key,
        "background": ?background,
        "music": ?music,
        "ambience": ?ambience,
        "ring": ?ring,
        "hangup": ?hangUp,
        if (stay != null) "stay": stay!.toJson(),
        if (textbox != TextboxStyle.adv) "textbox": textbox.name,
        "channel_id": ?channelId,
        "day": ?day,
        "time": ?time,
        if (status != null) "status": status!.toJson(),
      };
}
