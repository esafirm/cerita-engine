import 'package:fsse/src/engine/data/items/profile_info.dart';

import 'base.dart';

enum SpritePosition {
  left,
  center,
  right;

  static SpritePosition? fromName(String? name) => values.where((e) => e.name == name).firstOrNull;
}

/// A spoken line in VN mode or a message bubble in chat mode.
class TextItemType extends ItemType {
  static const type = "TEXT";

  final String text;
  final ProfileInfo? profile;
  final SpritePosition? position;
  final int? typingDelayMs;
  final String? sfx;
  final String? voice;

  TextItemType.fromJson(super.json)
      : text = json["text"] as String,
        profile = ProfileInfo.parse(json["profile"]),
        position = SpritePosition.fromName(json["position"] as String?),
        typingDelayMs = (json["typing_delay_ms"] as num?)?.toInt(),
        sfx = json["sfx"] as String?,
        voice = json["voice"] as String?;

  @override
  String getType() => type;

  @override
  String? getText() => text;

  @override
  ProfileInfo? getProfileInfo() => profile;
}
